#!/usr/bin/env python3
"""Extrae los textos de CONTENIDO (datos y motor) a translations/content_en.po (Fase 5, agente J).

El español es el idioma fuente y el msgid es el propio texto en español. Fuentes:
  * data/*.json  — los mismos campos que traduce DB en su sitio (DB.LOC_FIELDS / LOC_FIELDS_PROGRESS, leídos de
    scripts/core/db.gd para no duplicar la lista), incluidos los ajustes de data/balance_w2.json y las claves del
    glosario (etiquetas de palabra clave).
  * código: literales de DB.tl / DB.tln / Loc.t / Loc.tn / CardText._f / _fn / _kw / EventsLogic._relic_text en
    scripts/engine, scripts/core y scripts/ui/card_text.gd; los diccionarios "name"/"desc" de Daily.MODS y
    Favors.DEFS; y las líneas marcadas con `# loc-strings` (valores de diccionario y segundos de pares [k, v]).

Mezcla con el .po existente: conserva las traducciones, añade los msgids nuevos vacíos y deja los que ya no se usan
como obsoletos (#~). Avisa de lo que falta por traducir y de traducciones cuyos marcadores no cuadran.

Uso:
  python3 tools/extract_content_loc.py            # regenera translations/content_en.po e informa
  python3 tools/extract_content_loc.py --check    # no escribe; sale con 1 si falta algo o hay errores
  python3 tools/extract_content_loc.py --fill X.json [X2.json…]   # incorpora traducciones {msgid: str | [sing, plural]}
  python3 tools/extract_content_loc.py --list-missing             # imprime los msgids sin traducir
"""
import json
import os
import re
import sys
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
PO_PATH = os.path.join(ROOT, "translations", "content_en.po")
UI_PO = os.path.join(ROOT, "translations", "ui_en.po")
DB_GD = os.path.join(ROOT, "scripts", "core", "db.gd")
CODE_DIRS = ["scripts/engine", "scripts/core"]
CODE_FILES = ["scripts/ui/card_text.gd"]

HEADER = (
    'msgid ""\nmsgstr ""\n'
    '"Project-Id-Version: Verso de Musas (contenido)\\n"\n'
    '"Language: en\\n"\n'
    '"MIME-Version: 1.0\\n"\n'
    '"Content-Type: text/plain; charset=UTF-8\\n"\n'
    '"Content-Transfer-Encoding: 8bit\\n"\n'
    '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n'
)

# función -> índices de argumento cuyos literales son msgids (pares = singular, plural)
CALLS = {
    "DB.tl": ("s", [0]), "Loc.t": ("s", [0]), "_f": ("s", [0]), "_kw": ("s", [1, 2]),
    "_relic_text": ("s", [2, 3]),
    "DB.tln": ("p", [0, 1]), "Loc.tn": ("p", [0, 1]), "_fn": ("p", [0, 1]),
}
DICT_KEY_FILES = {"scripts/engine/daily.gd": ("name", "desc"), "scripts/engine/favors.gd": ("name", "desc")}


# ---------------------------------------------------------------- datos
def read_json(name):
    with open(os.path.join(DATA, name + ".json"), encoding="utf-8") as f:
        return json.load(f)


def loc_fields():
    """Lee DB.LOC_FIELDS y DB.LOC_FIELDS_PROGRESS de db.gd (única fuente de la lista de campos)."""
    src = open(DB_GD, encoding="utf-8").read()
    m = re.search(r"const LOC_FIELDS := \{(.*?)\n\}", src, re.S)
    fields = OrderedDict()
    for root, lst in re.findall(r'"(\w+)":\s*\[([^\]]*)\]', m.group(1)):
        fields[root] = re.findall(r'"([^"]+)"', lst)
    m2 = re.search(r"const LOC_FIELDS_PROGRESS := \[([^\]]*)\]", src)
    fields["progress"] = re.findall(r'"([^"]+)"', m2.group(1))
    return fields


def data_sources():
    cards, cx, ch = read_json("cards"), read_json("cards_extra"), read_json("characters")
    en, en2, bal = read_json("enemies"), read_json("enemies_extra"), read_json("balance_w2")
    rl, rl2 = read_json("relics"), read_json("relics_extra")
    ev, ev2, lo = read_json("events"), read_json("events_extra"), read_json("lore")
    st, st2, pr = read_json("states"), read_json("states_extra"), read_json("progress")
    return {
        "cards": [("cards.json", "cards", cards["cards"]), ("cards_extra.json", "cards", cx["cards"]),
                  ("balance_w2.json", "cards", bal.get("cards", {}))],
        "characters": [("characters.json", "characters", ch["characters"]), ("balance_w2.json", "chars", bal.get("chars", {}))],
        "enemies": [("enemies.json", "enemies", en["enemies"]), ("enemies_extra.json", "enemies", en2["enemies"]),
                    ("balance_w2.json", "enemies", bal.get("enemies", {}))],
        "acts": [("enemies.json", "acts", en["acts"])],
        "relics": [("relics.json", "relics", rl["relics"]), ("relics_extra.json", "relics", rl2["relics"]),
                   ("balance_w2.json", "relics", bal.get("relics", {}))],
        "potions": [("relics.json", "potions", rl["potions"]), ("relics_extra.json", "potions", rl2["potions"])],
        "events": [("events.json", "events", ev["events"]), ("events_extra.json", "events", ev2["events"])],
        "lore": [("lore.json", "lore", lo["lore"])],
        "nm_texts": [("lore.json", "nm", lo["nm"]), ("balance_w2.json", "nm_texts", bal.get("nm_texts", []))],
        "ending": [("lore.json", "ending", lo["ending"])],
        "st": [("states.json", "st", st["st"]), ("states_extra.json", "st", st2["st"])],
        "orb": [("states.json", "orb", st["orb"])],
        "glos": [("states.json", "glos", st["glos"])],
        "progress": [("progress.json", "", pr)],
    }


def walk(obj, segs, path, out):
    if not segs:
        if isinstance(obj, str) and obj != "":
            out.append((path, obj))
        return
    s, rest = segs[0], segs[1:]
    if isinstance(obj, dict):
        keys = list(obj.keys()) if s == "*" else ([s] if s in obj else [])
    elif isinstance(obj, list) and s == "*":
        keys = list(range(len(obj)))
    else:
        keys = []
    for k in keys:
        walk(obj[k], rest, "%s/%s" % (path, k) if path else str(k), out)


def extract_data(add):
    fields, srcs = loc_fields(), data_sources()
    for root, flist in fields.items():
        for fname, base, obj in srcs[root]:
            for f in flist:
                out = []
                walk(obj, f.split("/"), base, out)
                for path, s in out:
                    add(s, None, "data/%s %s" % (fname, path))
    # etiquetas de palabra clave: CardText.glossary_tip muestra DB.tl(clave del glosario)
    for k in read_json("states")["glos"].keys():
        add(k, None, "data/states.json glos (clave)")


# ---------------------------------------------------------------- código GDScript
STR_RE = re.compile(r'[&^]?"((?:[^"\\\n]|\\.)*)"|[&^]?\'((?:[^\'\\\n]|\\.)*)\'')


def unescape(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n == "u" and i + 5 < len(s):
                out.append(chr(int(s[i + 2:i + 6], 16)))
                i += 6
                continue
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\"}.get(n, "\\" + n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def tokens(src):
    """Recorre el fuente quitando comentarios: devuelve (texto_sin_cadenas, lista de (ini, fin, valor, línea))."""
    strs, buf, i, line = [], [], 0, 1
    while i < len(src):
        c = src[i]
        if c == "#":
            j = src.find("\n", i)
            j = len(src) if j < 0 else j
            buf.append(" " * (j - i))
            i = j
            continue
        if c in "\"'" or (c in "&^" and i + 1 < len(src) and src[i + 1] in "\"'"):
            m = STR_RE.match(src, i)
            if m:
                val = m.group(1) if m.group(1) is not None else m.group(2)
                strs.append((i, m.end(), unescape(val), line))
                buf.append('"' + " " * (m.end() - i - 2) + '"')
                i = m.end()
                continue
        if c == "\n":
            line += 1
        buf.append(c)
        i += 1
    return "".join(buf), strs


def call_args(clean, start):
    """Desde el '(' en start, devuelve [(ini, fin)] de cada argumento al nivel 0."""
    depth, args, a0, i = 0, [], start + 1, start
    while i < len(clean):
        c = clean[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                args.append((a0, i))
                return args
        elif c == "," and depth == 1:
            args.append((a0, i))
            a0 = i + 1
        i += 1
    return args


def extract_code(add, problems):
    files = []
    for d in CODE_DIRS:
        for fn in sorted(os.listdir(os.path.join(ROOT, d))):
            if fn.endswith(".gd"):
                files.append("%s/%s" % (d, fn))
    files += CODE_FILES
    call_re = re.compile(r"(?<![\w.])(%s)\s*\(" % "|".join(re.escape(k) for k in CALLS))
    for rel in files:
        src = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        clean, strs = tokens(src)
        for m in call_re.finditer(clean):
            name = m.group(1)
            if clean[max(0, m.start() - 5):m.start()].endswith("func "):
                continue   # la definición de la función, no una llamada
            kind, idxs = CALLS[name]
            args = call_args(clean, m.end() - 1)
            lits = []
            for k in idxs:
                if k < len(args):
                    a, b = args[k]
                    # fuera los literales que son operandos de una comparación (f.add.to == "hand")
                    lits.append([s for s in strs if s[0] >= a and s[1] <= b and s[2] != ""
                                 and not re.search(r"(==|!=)\s*$", clean[a:s[0]])
                                 and not re.match(r"\s*(==|!=)", clean[s[1]:s[1] + 4])])
                else:
                    lits.append([])
            if kind == "s":
                for group in lits:
                    for s in group:
                        add(s[2], None, "%s:%d" % (rel, s[3]))
            else:
                sing, plur = lits[0], lits[1] if len(lits) > 1 else []
                if len(sing) != len(plur):
                    if sing or plur:
                        problems.append("%s: %s con singular/plural desparejados" % (rel, name))
                    continue
                for s, p in zip(sing, plur):
                    add(s[2], p[2], "%s:%d" % (rel, s[3]))
        lines = src.split("\n")
        for ln, text in enumerate(lines, 1):
            if "# loc-strings" in text:
                code = text.split("# loc-strings")[0]
                for v in re.findall(r':\s*"((?:[^"\\]|\\.)*)"', code):
                    add(unescape(v), None, "%s:%d" % (rel, ln))
                for v in re.findall(r'\[\s*"(?:[^"\\]|\\.)*"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\]', code):
                    add(unescape(v), None, "%s:%d" % (rel, ln))
        if rel in DICT_KEY_FILES:
            keys = "|".join(DICT_KEY_FILES[rel])
            for ln, text in enumerate(lines, 1):
                for v in re.findall(r'"(?:%s)":\s*"((?:[^"\\]|\\.)*)"' % keys, text):
                    add(unescape(v), None, "%s:%d" % (rel, ln))


# ---------------------------------------------------------------- PO
def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s):
    return unescape(s)


def parse_po(path):
    """{msgid: {"plural": str|None, "str": [..]}}; ignora la cabecera y los obsoletos."""
    out = OrderedDict()
    if not os.path.exists(path):
        return out
    cur, field = None, None

    def flush():
        if cur and cur.get("msgid"):
            strs = cur.get("strs", {})
            n = (max(strs) + 1) if strs else 1
            out[cur["msgid"]] = {"plural": cur.get("msgid_plural"), "str": [strs.get(i, "") for i in range(n)],
                                 "fuzzy": cur.get("fuzzy", False)}

    for raw in open(path, encoding="utf-8").read().split("\n"):
        line = raw.strip()
        if line.startswith("#~"):
            continue
        if line == "" or (line.startswith("#") and not line.startswith("#,")):
            if line == "":
                flush()
                cur, field = None, None
            continue
        if cur is None:
            cur = {"strs": {}}
        if line.startswith("#,"):
            cur["fuzzy"] = "fuzzy" in line
            continue
        m = re.match(r'(msgid|msgid_plural|msgstr(?:\[(\d+)\])?)\s+"(.*)"$', line)
        if m:
            key, idx, val = m.group(1), m.group(2), po_unescape(m.group(3))
            if key.startswith("msgstr"):
                field = ("s", int(idx) if idx else 0)
                cur["strs"][field[1]] = val
            else:
                field = key
                cur[key] = val
            continue
        m = re.match(r'"(.*)"$', line)
        if m and field is not None:
            val = po_unescape(m.group(1))
            if isinstance(field, tuple):
                cur["strs"][field[1]] += val
            else:
                cur[field] += val
    flush()
    return out


def markers(s):
    toks = re.findall(r"\{[A-Za-z_]\w*\}|%[sd]|\*\*|\[/?[a-z]+[^\]]*\]", s)
    return sorted(toks)


def write_po(path, entries, old):
    parts = [HEADER]
    for msgid, e in entries.items():
        block = []
        for ref in e["refs"][:4]:
            block.append("#: " + ref)
        if len(e["refs"]) > 4:
            block.append("#: … (+%d)" % (len(e["refs"]) - 4))
        prev = old.get(msgid)
        if e["plural"] is not None:
            strs = prev["str"] if prev and prev["plural"] is not None and len(prev["str"]) == 2 else ["", ""]
            block.append('msgid "%s"' % po_escape(msgid))
            block.append('msgid_plural "%s"' % po_escape(e["plural"]))
            block.append('msgstr[0] "%s"' % po_escape(strs[0]))
            block.append('msgstr[1] "%s"' % po_escape(strs[1]))
        else:
            s = prev["str"][0] if prev and prev["plural"] is None else ""
            block.append('msgid "%s"' % po_escape(msgid))
            block.append('msgstr "%s"' % po_escape(s))
        parts.append("\n".join(block) + "\n")
    obsolete = [k for k in old if k not in entries and any(old[k]["str"])]
    for k in obsolete:
        parts.append('#~ msgid "%s"\n#~ msgstr "%s"\n' % (po_escape(k), po_escape(old[k]["str"][0])))
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    return obsolete


def main():
    args = sys.argv[1:]
    check, list_missing = "--check" in args, "--list-missing" in args
    fills = []
    if "--fill" in args:
        fills = [a for a in args[args.index("--fill") + 1:] if not a.startswith("--")]
    entries, problems = OrderedDict(), []

    def add(s, plural, ref):
        e = entries.get(s)
        if e is None:
            entries[s] = {"plural": plural, "refs": [ref]}
            return
        if (e["plural"] is None) != (plural is None):
            problems.append("msgid usado con y sin plural: %r (%s)" % (s, ref))
        if ref not in e["refs"]:
            e["refs"].append(ref)

    extract_data(add)
    extract_code(add, problems)
    old = parse_po(PO_PATH)
    new_ids = [k for k in entries if k not in old]
    # incorporar traducciones de archivos JSON
    unknown = 0
    for fp in fills:
        with open(fp, encoding="utf-8") as f:
            tr = json.load(f)
        for k, v in tr.items():
            if k not in entries:
                unknown += 1
                print("  --fill: msgid desconocido (se ignora): %r" % k[:90])
                continue
            plural = entries[k]["plural"]
            if plural is not None:
                v = v if isinstance(v, list) else [v, v]
            else:
                v = [v[0] if isinstance(v, list) else v]
            old[k] = {"plural": plural, "str": v, "fuzzy": False}
    # comprobaciones
    missing, bad = [], []
    for k, e in entries.items():
        o = old.get(k)
        strs = o["str"] if o else []
        ok_shape = o is not None and ((e["plural"] is None) == (o["plural"] is None))
        if not ok_shape or not strs or any(s == "" for s in strs) or o.get("fuzzy"):
            missing.append(k)
            continue
        srcs = [k] if e["plural"] is None else [k, e["plural"]]
        for i, s in enumerate(strs):
            want = markers(srcs[min(i, len(srcs) - 1)])
            if markers(s) != want:
                # con plural, el singular inglés puede omitir {n} solo si el español también lo hace en esa forma
                bad.append("%r -> %r (marcadores %s vs %s)" % (k[:70], s[:70], want, markers(s)))
    ui = parse_po(UI_PO)
    clash = [k for k in entries if k in ui and any(ui[k]["str"]) and old.get(k) and ui[k]["str"] != old[k]["str"]]
    obsolete = []
    if not check:
        os.makedirs(os.path.dirname(PO_PATH), exist_ok=True)
        obsolete = write_po(PO_PATH, entries, old)
    print("content_en.po: %d msgids (%d plurales) · %d traducidos · %d sin traducir · %d nuevos · %d obsoletos"
          % (len(entries), sum(1 for e in entries.values() if e["plural"] is not None),
             len(entries) - len(missing), len(missing), len(new_ids), len(obsolete)))
    for p in problems:
        print("  AVISO:", p)
    for b in bad:
        print("  MARCADORES:", b)
    for k in clash:
        print("  CHOQUE con ui_en.po (mismo msgid, otra traducción): %r" % k[:90])
    if list_missing:
        for k in missing:
            print("  FALTA: %r" % k)
    elif missing:
        for k in missing[:15]:
            print("  FALTA: %r" % k[:100])
        if len(missing) > 15:
            print("  … y %d más (--list-missing)" % (len(missing) - 15))
    if check and (missing or bad or problems or clash or new_ids):
        sys.exit(1)


if __name__ == "__main__":
    main()
