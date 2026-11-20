#!/usr/bin/env python3
"""Extrae los textos de la interfaz a translations/ui_en.po (Fase 5, localización ES/EN).

El español es el idioma fuente: msgid = texto en español tal cual está en el código. Se recogen las llamadas
con literales de:  tr("…")  tr("…", "contexto")  tr_n("…", "…", n)  Loc.t("…")  Loc.t("…", "ctx")
Loc.tn("…", "…", n)  en scripts/ui/**/*.gd (salvo scripts/ui/card_text.gd, que es del contenido).

Fusiona con el .po existente: conserva las traducciones, añade los msgid nuevos vacíos y comenta (#~) los que
ya no están en el código. Avisa de msgid sin traducir y de traducciones cuyos marcadores (%s, %d, {x}) no
coinciden con los del original (si no coinciden, el formato fallaría en el juego).

Uso:
  python3 tools/extract_loc.py               # escanea y reescribe translations/ui_en.po
  python3 tools/extract_loc.py --check       # no escribe; sale con 1 si hay algo sin traducir o mal formado
  python3 tools/extract_loc.py --fill X.json # además rellena msgstr desde {msgid: "trad" | ["sing", "plural"]}
  python3 tools/extract_loc.py --candidates  # lista literales con pinta de texto visible SIN tr() (pistas)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIRS = ["scripts/ui"]
EXCLUDE = {"scripts/ui/card_text.gd"}
PO_PATH = os.path.join(ROOT, "translations", "ui_en.po")
HEADER = (
    'msgid ""\n'
    'msgstr ""\n'
    '"Project-Id-Version: Verso de Musas (interfaz)\\n"\n'
    '"Language: en\\n"\n'
    '"MIME-Version: 1.0\\n"\n'
    '"Content-Type: text/plain; charset=UTF-8\\n"\n'
    '"Content-Transfer-Encoding: 8bit\\n"\n'
    '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n'
)

CALL_RE = re.compile(r'(?<![\w.])(tr_n|tr|Loc\.tn|Loc\.t)\(\s*')


# ---------- lectura de literales GDScript ----------
def read_literal(s, i):
    """Lee un literal de cadena GDScript en s[i:]. Devuelve (valor, fin) o (None, i)."""
    if i < len(s) and s[i] in "&^":  # StringName / NodePath
        return None, i
    for q in ('"""', "'''", '"', "'"):
        if s.startswith(q, i):
            j = i + len(q)
            out = []
            while j < len(s):
                if s.startswith(q, j):
                    return "".join(out), j + len(q)
                c = s[j]
                if c == "\\" and j + 1 < len(s):
                    n = s[j + 1]
                    esc = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}
                    if n in esc:
                        out.append(esc[n])
                        j += 2
                        continue
                    if n == "u":
                        out.append(chr(int(s[j + 2:j + 6], 16)))
                        j += 6
                        continue
                    if n == "\n":  # continuación de línea
                        j += 2
                        continue
                    out.append(n)
                    j += 2
                    continue
                if c == "\n" and len(q) == 1:
                    return None, i
                out.append(c)
                j += 1
            return None, i
    return None, i


def skip_ws(s, i):
    while i < len(s) and s[i] in " \t\r\n":
        i += 1
    return i


def in_comment(s, pos):
    """¿La posición cae tras un # de comentario en su línea (fuera de cadenas)?"""
    ls = s.rfind("\n", 0, pos) + 1
    line = s[ls:pos]
    q = None
    k = 0
    while k < len(line):
        c = line[k]
        if q:
            if c == "\\":
                k += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "#":
            return True
        k += 1
    return False


def marked_lines(s):
    """Índices (base 0) de las líneas con marcador «# loc» (al final, o en la línea anterior sola)."""
    lines = s.split("\n")
    offs = [0]
    for ln in lines:
        offs.append(offs[-1] + len(ln) + 1)
    marked = set()
    for idx, ln in enumerate(lines):
        st = ln.strip()
        if st in ("# loc", "## loc"):
            marked.add(idx + 1)
        elif re.search(r"#\s*loc\s*$", ln) and in_comment(s, offs[idx] + ln.rfind("#") + 1):
            marked.add(idx)
    return marked


def scan_file(path, rel):
    s = open(path, encoding="utf-8").read()
    found = []  # (ctx, msgid, plural, line)
    for m in CALL_RE.finditer(s):
        if in_comment(s, m.start()):
            continue
        fn = m.group(1)
        i = m.end()
        a, i2 = read_literal(s, i)
        if a is None:
            continue
        line = s.count("\n", 0, m.start()) + 1
        plural = None
        ctx = ""
        j = skip_ws(s, i2)
        if fn in ("tr_n", "Loc.tn"):
            if j < len(s) and s[j] == ",":
                b, j2 = read_literal(s, skip_ws(s, j + 1))
                if b is None:
                    continue
                plural = b
                # contexto opcional tras n: tr_n(a, b, n, "ctx") — se busca el cierre con cuidado
                depth = 0
                k = j2
                commas = 0
                while k < len(s):
                    c = s[k]
                    if c in "([{":
                        depth += 1
                    elif c in ")]}":
                        if depth == 0:
                            break
                        depth -= 1
                    elif c == "," and depth == 0:
                        commas += 1
                        if commas == 2:
                            cx, _ = read_literal(s, skip_ws(s, k + 1))
                            ctx = cx or ""
                            break
                    elif c in "\"'":
                        _, k2 = read_literal(s, k)
                        if k2 > k:
                            k = k2
                            continue
                    k += 1
            else:
                continue
        else:
            if j < len(s) and s[j] == ",":
                cx, _ = read_literal(s, skip_ws(s, j + 1))
                if cx is not None:
                    ctx = cx
        found.append((ctx, a, plural, "%s:%d" % (rel, line)))
    # Marcador para constantes (en un const no se puede llamar a tr): «# loc» al final de una línea extrae los
    # literales visibles que empiezan en esa línea; una línea que solo dice «# loc» extrae los de la siguiente.
    # El código traduce esas constantes donde las usa: tr(a[1]) / Loc.t(HELP).
    lines = s.split("\n")
    offs = [0]
    for ln in lines:
        offs.append(offs[-1] + len(ln) + 1)
    marked = marked_lines(s)
    for idx in sorted(marked):
        if idx >= len(lines):
            continue
        k = offs[idx]
        end = offs[idx + 1] if idx + 1 < len(offs) else len(s)
        while k < end:
            c = s[k]
            if c == "#" and in_comment(s, k + 1) and not in_comment(s, k):
                break
            if c in "\"'":
                val, e = read_literal(s, k)
                if val is None or e <= k:
                    k += 1
                    continue
                if looks_visible(val):
                    found.append(("", val, None, "%s:%d" % (rel, idx + 1)))
                k = e
                continue
            k += 1
    return found


def source_files():
    for d in SRC_DIRS:
        for base, _, files in os.walk(os.path.join(ROOT, d)):
            for f in sorted(files):
                if f.endswith(".gd"):
                    full = os.path.join(base, f)
                    rel = os.path.relpath(full, ROOT)
                    if rel not in EXCLUDE:
                        yield full, rel


# ---------- PO ----------
def po_escape(t):
    return t.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(t):
    out = []
    k = 0
    while k < len(t):
        c = t[k]
        if c == "\\" and k + 1 < len(t):
            n = t[k + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\", "r": "\r"}.get(n, n))
            k += 2
            continue
        out.append(c)
        k += 1
    return "".join(out)


def parse_po(path):
    """Devuelve {(ctx, msgid): {"plural": str|None, "str": [..]}} (sin la cabecera)."""
    entries = {}
    if not os.path.exists(path):
        return entries
    cur = None
    field = None

    def flush():
        if cur and cur.get("msgid"):
            entries[(cur.get("msgctxt", ""), cur["msgid"])] = {
                "plural": cur.get("msgid_plural"),
                "str": [cur.get("msgstr[%d]" % i, "") for i in range(2)] if cur.get("msgid_plural") is not None
                else [cur.get("msgstr", "")],
            }

    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if line.startswith("#~") or line.startswith("#") or not line.strip():
            if not line.strip() and cur is not None:
                flush()
                cur = None
                field = None
            continue
        m = re.match(r'^(msgctxt|msgid_plural|msgid|msgstr\[\d\]|msgstr)\s+"(.*)"\s*$', line)
        if m:
            key = m.group(1)
            if key in ("msgctxt",) or (key == "msgid" and cur is not None and ("msgstr" in cur or "msgstr[0]" in cur)):
                flush()
                cur = {}
            if cur is None:
                cur = {}
            cur[key] = po_unescape(m.group(2))
            field = key
            continue
        m = re.match(r'^"(.*)"\s*$', line)
        if m and cur is not None and field:
            cur[field] += po_unescape(m.group(1))
    if cur is not None:
        flush()
    return entries


PH_RE = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?[sdifxXc%]|\{[A-Za-z_0-9]+\}")


def placeholders(t):
    # {m} y {M} cuentan como el mismo marcador (el código pasa ambos: mes en minúscula y capitalizado).
    return sorted(p.lower() if p.startswith("{") else p for p in PH_RE.findall(t) if p != "%%")


def write_po(path, order, info, old, obsolete):
    out = [HEADER]
    for key in order:
        ctx, msgid = key
        e = info[key]
        prev = old.get(key)
        out.append("")
        for ref in e["refs"][:4]:
            out.append("#: " + ref)
        if ctx:
            out.append('msgctxt "%s"' % po_escape(ctx))
        out.append('msgid "%s"' % po_escape(msgid))
        if e["plural"] is not None:
            out.append('msgid_plural "%s"' % po_escape(e["plural"]))
            strs = prev["str"] if prev and prev["plural"] is not None else ["", ""]
            for i in range(2):
                out.append('msgstr[%d] "%s"' % (i, po_escape(strs[i] if i < len(strs) else "")))
        else:
            st = prev["str"][0] if prev else ""
            out.append('msgstr "%s"' % po_escape(st))
    if obsolete:
        out.append("")
        out.append("# ---- ya no están en el código (se conservan por si vuelven) ----")
        for (ctx, msgid), e in obsolete:
            out.append("")
            if ctx:
                out.append('#~ msgctxt "%s"' % po_escape(ctx))
            out.append('#~ msgid "%s"' % po_escape(msgid))
            if e["plural"] is not None:
                out.append('#~ msgid_plural "%s"' % po_escape(e["plural"]))
                for i, st in enumerate(e["str"]):
                    out.append('#~ msgstr[%d] "%s"' % (i, po_escape(st)))
            else:
                out.append('#~ msgstr "%s"' % po_escape(e["str"][0]))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


def parse_obsolete(path):
    """Entradas #~ del .po (para recuperar traducciones si un texto vuelve al código)."""
    res = {}
    if not os.path.exists(path):
        return res
    cur = {}
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        m = re.match(r'^#~ (msgctxt|msgid_plural|msgid|msgstr\[\d\]|msgstr)\s+"(.*)"\s*$', line)
        if not m:
            continue
        k, v = m.group(1), po_unescape(m.group(2))
        if k in ("msgctxt",) or (k == "msgid" and ("msgstr" in cur or "msgstr[0]" in cur)):
            if cur.get("msgid"):
                res[(cur.get("msgctxt", ""), cur["msgid"])] = cur
            cur = {}
        cur[k] = v
    if cur.get("msgid"):
        res[(cur.get("msgctxt", ""), cur["msgid"])] = cur
    out = {}
    for key, c in res.items():
        pl = c.get("msgid_plural")
        out[key] = {"plural": pl, "str": [c.get("msgstr[0]", ""), c.get("msgstr[1]", "")] if pl is not None else [c.get("msgstr", "")]}
    return out


# ---------- pistas: texto visible sin tr() ----------
LIT_RE = re.compile(r'"(?:[^"\\\n]|\\.)*"')
SKIP_CALLS = re.compile(
    r'(Sfx\.(play|music)|[gs]et_meta|has_meta|has_method|Icons\.\w+|add_theme_\w+|get_theme_\w+|find_child|get_node|'
    r'\.connect|load|preload|UIK\.(tex|font|stylebox|asset_exists)|Color|push_warning|push_error|print|match|'
    r'begins_with|ends_with|split|replace|get_environment|ResourceLoader|OS\.\w+|Input\.\w+|DB\.\w+|Eng\.\w+|'
    r'call|callv|has|get|erase|contains|tween_property|InputMap|is_action\w*|prof_add|\.name\s*=)\s*\(?\s*$'
)  # solo si el literal es el 1.er argumento de esa llamada (antes: cualquier llamada previa sin comillas lo tapaba)


def looks_visible(t):
    if not re.search(r"[A-Za-zÁÉÍÓÚáéíóúñÑ]{2,}", t):
        return False
    if re.fullmatch(r"[a-z0-9_:./\-#]+", t) or t.startswith("res://") or t.startswith("user://"):
        return False
    if re.fullmatch(r"#?[0-9a-fA-F]{6,8}", t):
        return False
    bare = re.sub(r"\[[^\]]*\]|%[-+ 0#]*\d*(\.\d+)?[sdif]|\{[a-z_0-9]+\}", "", t)
    if not re.search(r"[A-Za-zÁÉÍÓÚáéíóúñÑ]{2,}", bare):
        return False
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", bare.strip()) and bare.strip()[0].islower():
        return False
    return True


def candidates():
    n = 0
    for full, rel in source_files():
        s = open(full, encoding="utf-8").read()
        tr_spans = []
        for m in CALL_RE.finditer(s):
            _, e = read_literal(s, m.end())
            tr_spans.append((m.end(), e))
            if m.group(1) in ("tr_n", "Loc.tn"):
                j = skip_ws(s, e)
                if j < len(s) and s[j] == ",":
                    k0 = skip_ws(s, j + 1)
                    _, e2 = read_literal(s, k0)
                    tr_spans.append((k0, e2))
        lines = s.split("\n")
        marked = marked_lines(s)
        pos = 0
        for ln, line in enumerate(lines, 1):
            code = line
            if (ln - 1) in marked or re.search(r"#\s*noloc\b", line):
                pos += len(line) + 1
                continue  # constante ya marcada (se traduce al usarla) o texto que no se traduce a propósito
            for m in LIT_RE.finditer(code):
                a = pos + m.start()
                if any(st <= a < en for st, en in tr_spans):
                    continue
                if in_comment(s, a):
                    continue
                val = m.group(0)[1:-1]
                if not looks_visible(val):
                    continue
                before = code[:m.start()]
                if SKIP_CALLS.search(before):
                    continue
                if re.search(r'\s*:\s*$', code[m.end():m.end() + 3]) and code[m.end():].lstrip().startswith(":"):
                    continue  # clave de diccionario
                print("%s:%d: %s" % (rel, ln, val[:90]))
                n += 1
            pos += len(line) + 1
    print("\n%d candidatos" % n, file=sys.stderr)


def main(argv):
    if "--candidates" in argv:
        candidates()
        return 0
    check = "--check" in argv
    fill = {}
    if "--fill" in argv:
        fill = json.load(open(argv[argv.index("--fill") + 1], encoding="utf-8"))
    order = []
    info = {}
    for full, rel in source_files():
        for ctx, msgid, plural, ref in scan_file(full, rel):
            key = (ctx, msgid)
            if key not in info:
                info[key] = {"plural": plural, "refs": []}
                order.append(key)
            elif plural is not None and info[key]["plural"] is None:
                info[key]["plural"] = plural
            info[key]["refs"].append(ref)
    old = parse_po(PO_PATH)
    old_obs = parse_obsolete(PO_PATH)
    for k, v in old_obs.items():
        old.setdefault(k, v)
    for k, v in fill.items():
        key = ("", k)
        if key not in info:
            continue
        if isinstance(v, list):
            old[key] = {"plural": info[key]["plural"], "str": v}
        else:
            old[key] = {"plural": None, "str": [v]}
    missing = []
    bad = []
    for key in order:
        e = info[key]
        prev = old.get(key)
        strs = (prev["str"] if prev else [])
        if e["plural"] is not None and prev and prev["plural"] is None:
            strs = []
        if not strs or any(not x for x in strs[: (2 if e["plural"] is not None else 1)]):
            missing.append(key)
            continue
        src_ph = placeholders(key[1])
        for i, st in enumerate(strs):
            src = key[1] if i == 0 else (e["plural"] or key[1])
            want = placeholders(src) if e["plural"] is None or i == 1 else None
            if want is not None and placeholders(st) != want:
                bad.append((key, st))
            elif e["plural"] is not None and i == 0:
                # el singular puede omitir el número («1 carta» / «One card»), pero no inventar marcadores
                if not set(placeholders(st)) <= set(src_ph) | set(placeholders(e["plural"])):
                    bad.append((key, st))
    obsolete = [(k, v) for k, v in old.items() if k not in info and (v["str"] and any(v["str"]))]
    if not check:
        write_po(PO_PATH, order, info, old, obsolete)
    print("ui_en.po: %d textos, %d sin traducir, %d con marcadores distintos, %d obsoletos" % (len(order), len(missing), len(bad), len(obsolete)))
    for ctx, msgid in missing[:400]:
        print("  SIN TRADUCIR: %s%s" % (("[%s] " % ctx) if ctx else "", msgid.replace("\n", "\\n")[:120]))
    for (ctx, msgid), st in bad:
        print("  MARCADORES: %r -> %r" % (msgid[:80], st[:80]))
    return 1 if (check and (missing or bad)) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
