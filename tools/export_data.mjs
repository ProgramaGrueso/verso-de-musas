// Exporta los datos del juego web (Verso de Musas) a JSON para Godot.
// Uso: node tools/export_data.mjs  (desde la carpeta del proyecto Godot)
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const WEB = process.env.VDM_WEB || '/mnt/Datos/IngenieriaInversa/VersoDeMusas';
const OUT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data');
mkdirSync(OUT, { recursive: true });
const imp = (p) => import(path.join(WEB, 'src', p));

globalThis.localStorage = { getItem: () => null, setItem() {} };
const { CARDS, POOL, STARTERS } = await imp('data/cards/index.js');
const { CHARACTERS } = await imp('data/characters.js');
const { SPRITES } = await imp('data/sprites.js');
const { ENEMIES, ENCOUNTERS, ACTS } = await imp('data/enemies.js');
const { RELICS, POTIONS } = await imp('data/relics.js');
const { EVENTS } = await imp('data/events.js');
const { LORE, NM, ENDING } = await imp('data/lore.js');
const { MUSIC_GAINS } = await imp('data/music_gains.js');
await imp('engine/engine.js');
const { SM } = await imp('core/sm.js');

// --- IA de enemigos: las repetitivas se declaran como datos; las demás se portan a mano (ai.t = "custom") ---
const AI = {
  dockrat: { t: 'rnd', keys: ['bite', 'gnaw', 'squeak'], w: [3, 2, 1] },
  drone: { t: 'rnd', keys: ['sting', 'buzz'], w: [3, 1] },
  minicrab: { t: 'fixed', key: 'nip' }, sprout: { t: 'fixed', key: 'poke' },
  slime: { t: 'cyc', seq: ['spit', 'tackle', 'glop', 'spit'] }, crab: { t: 'cyc', seq: ['claw', 'shell', 'crush'] },
  jelly: { t: 'cyc', seq: ['sting', 'pulse', 'drift'] }, chainwarden: { t: 'cyc', seq: ['bulwark', 'chain', 'lash', 'chain'] },
  tentacle: { t: 'cyc', seq: ['whip', 'drain', 'drown'] }, crabking: { t: 'cyc', seq: ['roar', 'pincer', 'summon', 'spin', 'twin', 'shell'] },
  sporecap: { t: 'cyc', seq: ['spores', 'hit', 'cloud', 'hit'] }, vinelasher: { t: 'cyc', seq: ['lash', 'tangle', 'choke'] },
  mossgolem: { t: 'cyc', seq: ['charge', 'smash', 'punch'] }, dryad: { t: 'cyc', seq: ['hex', 'whip', 'mend', 'whip'] },
  treant: { t: 'cyc', seq: ['roots', 'slam', 'splinter', 'vines'] }, stag: { t: 'cyc', seq: ['bellow', 'gore', 'gallop', 'gore'] },
  wasp: { t: 'cyc', seq: ['rush', 'stab', 'venom'] }, honeyslime: { t: 'cyc', seq: ['sticky', 'jet', 'harden'] },
  beetle: { t: 'cyc', seq: ['plate', 'ram', 'horn'] }, royalguard: { t: 'cyc', seq: ['guard', 'thrust', 'sweep', 'charge'] },
  ghostpirate: { t: 'first_alt', first: 'howl', odd: 'slash', even: 'volley' },
  thornbeast: { t: 'first_alt', first: 'bristle', odd: 'charge', even: 'stomp' },
  rootmother: { t: 'custom' }, nurse: { t: 'custom' }, hivemind: { t: 'custom' }, queen: { t: 'custom' },
};
const enemies = {};
for (const [id, e] of Object.entries(ENEMIES)) {
  if (!AI[id]) throw new Error('falta IA de ' + id);
  const { ai, ...rest } = e; enemies[id] = { ...rest, ai: AI[id] };
}
// verificación de las IA declaradas contra las originales (misma secuencia durante 14 turnos)
for (const [id, e] of Object.entries(ENEMIES)) {
  const a = AI[id]; if (a.t === 'custom' || a.t === 'rnd') continue;
  const dummy = { turn: 0, hist: [], hp: 10, maxHp: 10 };
  for (let t = 0; t < 14; t++) {
    dummy.turn = t;
    const real = e.ai(dummy, { rng: () => 0.5, enemies: [] });
    const mine = a.t === 'fixed' ? a.key : a.t === 'cyc' ? a.seq[t % a.seq.length] : t === 0 ? a.first : t % 2 === 1 ? a.odd : a.even;
    if (real !== mine) throw new Error(`IA ${id} difiere en turno ${t}: ${real} vs ${mine}`);
  }
}
const stripFn = (o) => JSON.parse(JSON.stringify(o, (k, v) => (typeof v === 'function' ? undefined : v)));
const relics = {}; for (const [id, r] of Object.entries(RELICS)) relics[id] = stripFn(r);
const potions = {}; for (const [id, p] of Object.entries(POTIONS)) potions[id] = stripFn(p);
const events = EVENTS.map((e) => ({ id: e.id, title: e.title, img: e.img, text: e.text }));
// Retos de la Galería: cómo se calcula el valor de cada uno (las funciones del web no se serializan)
const W = (...c) => ({ min: c.map((x) => 'win_' + x) });
const VSPEC = {
  canto: { stat: 'runs' }, aguja: { stat: 'kills' }, movimientos: { stat: 'floors' }, muelles: { stat: 'boss_crabking' }, oro1: { stat: 'gold' },
  maleza: { stat: 'boss_rootmother' }, savia: { stat: 'elites' }, colmena: { stat: 'act3' }, reina: { stat: 'wins' },
  zafiro: { stat: 'win_zafiro' }, lia: { stat: 'win_lia' }, claudia: { stat: 'win_claudia' }, aurora: { stat: 'win_aurora' }, irene: { stat: 'win_irene' }, selene: { stat: 'win_selene' },
  osty: { stat: 'ostyHits' }, veneno: { stat: 'poison' }, escudo: { stat: 'block' }, engranajes: { stat: 'windSpent' }, mareas: { stat: 'orbEvokes' }, notas: { stat: 'cards' },
  oro2: { stat: 'gold' }, pociones: { stat: 'potions' }, reliquias: { relics: true }, leyenda: { stat: 'maxHit' }, matanza: { stat: 'kills' }, sinrasguno: { stat: 'flawlessElite' },
  pesadilla1: { stat: 'nm' }, pesadilla3: { stat: 'nm' }, pesadilla6: { stat: 'nm' }, pesadilla10: { stat: 'nm' },
  tres: W('zafiro', 'lia', 'claudia'), cuatro: W('zafiro', 'lia', 'claudia', 'aurora'), seis: W('zafiro', 'lia', 'claudia', 'aurora', 'irene', 'selene'), constructos: W('irene', 'selene'),
  ultima: { unlocked: true },
};
const lore = LORE.map((l) => { if (!VSPEC[l.id]) throw new Error('falta v de ' + l.id); return { id: l.id, title: l.title, ch: l.ch, t: l.t, ico: l.ico, text: l.text, ap: l.ap, v: VSPEC[l.id] }; });
const sprites = stripFn(SPRITES);
writeFileSync(path.join(OUT, 'cards.json'), JSON.stringify({ cards: CARDS, pool: POOL, starters: STARTERS }));
writeFileSync(path.join(OUT, 'characters.json'), JSON.stringify({ characters: CHARACTERS, sprites }));
writeFileSync(path.join(OUT, 'enemies.json'), JSON.stringify({ enemies, encounters: ENCOUNTERS, acts: ACTS }));
writeFileSync(path.join(OUT, 'relics.json'), JSON.stringify({ relics, potions }));
writeFileSync(path.join(OUT, 'events.json'), JSON.stringify({ events }));
writeFileSync(path.join(OUT, 'lore.json'), JSON.stringify({ lore, nm: NM, ending: ENDING }));
writeFileSync(path.join(OUT, 'music.json'), JSON.stringify({ gains: MUSIC_GAINS }));
// Estados (buffs/debuffs), orbes y glosario de la interfaz
const engSrc = await import(path.join(WEB, 'src/engine/engine.js'));
const ST = {};
for (const [k, s] of Object.entries(engSrc.Engine.ST)) ST[k] = { n: s.n, i: s.i, d: s.d('{n}'), negp: !!s.neg(1), negn: !!s.neg(-1) };
const ORB = {};
for (const [k, o] of Object.entries(engSrc.Engine.ORB)) ORB[k] = { n: o.n, i: o.i, pas: o.pas, evo: o.evo, d: o.d('{p}', '{e}') };
import { readFileSync } from 'node:fs';
const coreSrc = readFileSync(path.join(WEB, 'src/ui/core.js'), 'utf8');
const gm = coreSrc.match(/const GLOS = \{([\s\S]*?)\n\};/);
const GLOS = {};
for (const m of gm[1].matchAll(/^\s*([A-Za-zÁ-ú]+): '((?:[^'\\]|\\.)*)',?\s*$/gm)) GLOS[m[1]] = m[2].replace(/\\'/g, "'");
writeFileSync(path.join(OUT, 'states.json'), JSON.stringify({ st: ST, orb: ORB, glos: GLOS }));
console.log('ok', Object.keys(ST).length, 'estados', Object.keys(GLOS).length, 'glosario');
console.log('ok', Object.keys(CARDS).length, 'cartas;', Object.keys(enemies).length, 'enemigos;', Object.keys(relics).length, 'reliquias;', lore.length, 'retos');
