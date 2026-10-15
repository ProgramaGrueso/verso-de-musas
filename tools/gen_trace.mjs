// Genera las trazas de referencia (oráculo) del motor web: partidas con semilla y un bot determinista.
// El motor de Godot debe reproducir cada línea exactamente. Uso: node tools/gen_trace.mjs
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const WEB = process.env.VDM_WEB || '/mnt/Datos/IngenieriaInversa/VersoDeMusas';
const OUT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'tests', 'traces.json');
globalThis.localStorage = { getItem: () => null, setItem() {} };
const { Engine: En } = await import(path.join(WEB, 'src/engine/engine.js'));
const { SM } = await import(path.join(WEB, 'src/core/sm.js'));
const { Game: Gm } = await import(path.join(WEB, 'src/run/index.js'));
const { CARDS } = await import(path.join(WEB, 'src/data/cards/index.js'));

const CHARS = ['zafiro', 'lia', 'claudia', 'aurora', 'irene', 'selene'];
const j = (o) => JSON.stringify(Object.keys(o).sort().map((k) => [k, o[k]]));
const fxsig = (type, d) => {
  d = d || {};
  let s = type;
  if (d.e) s += '#' + d.e.uid;
  if (d.who) s += '@' + (d.who.uid ? d.who.uid : 'P');
  if (d.k) s += ':' + d.k;
  for (const k of ['amt', 'blocked', 'ostyAbs', 'n']) if (d[k] !== undefined) s += ',' + k + d[k];
  if (d.t) s += ',t' + d.t;
  if (d.id) s += ',id' + d.id;
  if (d.card) s += ',c' + d.card.id;
  return s;
};
function snap(C, G, tag, fxl) {
  const en = C.enemies.map((e) => `${e.id}:${e.hp}:${e.block}:${e.moveKey}:${j(e.status)}`).join(';');
  const hand = C.hand.map((c) => c.id + (c.up ? '+' : '')).join(',');
  const os = C.osty ? `${C.osty.hp}/${C.osty.max}/${C.osty.pow}` : '-';
  const orbs = C.orbs.map((o) => o.t + o.v).join(',');
  return `${tag} T${C.turn} hp${G.hp}/${G.maxHp} b${C.pl.block} e${C.energy}/${C.maxEnergy} H[${hand}] d${C.draw.length} x${C.discard.length} X${C.exhaust.length} |${en}| P${j(C.pl.status)} O${os} R${orbs} g${G.gold} rs${G.rs} ov${C.over || ''} fx[${fxl.join(' ')}]`;
}
function runCombat(name, char, seed, ids, tier, act, ex) {
  ex = ex || {};
  const G = En.newRun(char, { seed, nm: ex.nm || 0 });
  G.act = act;
  // mazo ampliado con cartas del pool, algunas mejoradas
  for (let i = 0; i < 3; i++) for (const id of En.rewardCards(G, 4, 0.1)) G.deck.push(En.makeCard(G, id));
  for (const c of G.deck) if (En.canUpgrade(c) && En.rnd(G) < 0.5) c.up = true;
  if (ex.relic) En.addRelic(G, ex.relic);
  if (ex.potion) G.potions[0] = ex.potion;
  const lines = [];
  let fxl = [];
  const C = En.startCombat(G, ids, { tier, fx: (t, d) => fxl.push(fxsig(t, d)) });
  lines.push(snap(C, G, 'start', fxl)); fxl = [];
  for (let turn = 0; turn < 30 && !C.over; turn++) {
    if (turn === 1 && G.potions[0]) {
      const lv = En.living(C);
      if (En.usePotion(C, 0, lv[0])) { lines.push(snap(C, G, 'potion', fxl)); fxl = []; }
    }
    for (let guard = 0; guard < 40 && !C.over; guard++) {
      if (C.prompt) { const p = C.prompt; En.resolvePrompt(C, C.hand.map((c) => c.uid)); lines.push(snap(C, G, 'prompt-' + p.kind, fxl)); fxl = []; continue; }
      const inst = C.hand.find((c) => En.canPlay(C, c).ok);
      if (!inst) break;
      const d = En.cardDef(inst);
      const tgt = En.needsTarget(d) ? En.living(C)[0] : undefined;
      const ok = En.playCard(C, inst.uid, tgt);
      lines.push(snap(C, G, 'play-' + inst.id + (inst.up ? '+' : ''), fxl)); fxl = [];
      if (!ok) break;
    }
    if (C.over) break;
    En.endPlayerTurn(C);
    lines.push(snap(C, G, 'end', fxl)); fxl = [];
    if (C.over) break;
    En.enemyPhaseInstant(C);
    lines.push(snap(C, G, 'enemy', fxl)); fxl = [];
  }
  lines.push('final ' + (C.over || 'timeout') + ' hp' + G.hp + ' rs' + G.rs + ' kills' + G.stats.kills);
  return { name, kind: 'combat', params: { char, seed, ids, tier, act, ...ex }, lines };
}
const cases = [];
const ENCS = [
  [['dockrat', 'dockrat', 'dockrat'], 'normal', 1], [['slime'], 'normal', 1], [['jelly', 'dockrat'], 'normal', 1], [['ghostpirate'], 'normal', 1],
  [['chainwarden'], 'elite', 1], [['tentacle'], 'elite', 1], [['crabking'], 'boss', 1],
  [['sporecap', 'vinelasher'], 'normal', 2], [['thornbeast'], 'normal', 2], [['dryad', 'sporecap'], 'normal', 2], [['treant'], 'elite', 2], [['stag'], 'elite', 2], [['rootmother'], 'boss', 2],
  [['drone', 'drone', 'drone'], 'normal', 3], [['nurse', 'wasp'], 'normal', 3], [['beetle'], 'normal', 3], [['hivemind'], 'elite', 3], [['royalguard'], 'elite', 3], [['queen'], 'boss', 3],
];
for (const ch of CHARS) for (let seed = 1; seed <= 4; seed++) for (let k = 0; k < ENCS.length; k++) {
  if ((seed + k) % 3 !== 0 && seed > 1) continue; // reduce el total
  const [ids, tier, act] = ENCS[k];
  cases.push(runCombat(`combat ${ch} s${seed} ${ids.join('+')}`, ch, seed * 101 + k, ids, tier, act));
}
// reliquias y pociones: cada una en un combate
const relIds = Object.keys(SM.RELICS), potIds = Object.keys(SM.POTIONS);
for (const rid of relIds) for (const ch of ['zafiro', 'irene', 'selene', 'claudia', 'aurora']) {
  const r = SM.RELICS[rid]; if (r.char && r.char !== ch) continue; if (r.rarity === 'start' && rid !== SM.CHARACTERS[ch].startRelic) continue;
  cases.push(runCombat(`relic ${rid} ${ch}`, ch, 777 + rid.length * 13, ['wasp', 'drone'], 'normal', 3, (G) => { En.addRelic(G, rid); }));
}
for (const pid of potIds) cases.push(runCombat(`potion ${pid}`, 'lia', 4242 + pid.length, ['crab', 'dockrat'], 'normal', 1, { potion: pid }));
for (const nm of [1, 3, 5, 8, 10]) cases.push(runCombat(`nightmare ${nm}`, 'zafiro', 99 + nm, ['stag'], 'elite', 2, { nm }));
// estructura de partida (mapa, tiendas, recompensas, eventos): mismo orden de RNG
for (const ch of CHARS) for (const seed of [11, 222, 3333]) {
  const G = En.newRun(ch, { seed });
  const lines = [];
  for (let act = 1; act <= 3; act++) {
    G.act = act;
    G.map = Gm.genMap(G);
    lines.push('map' + act + ' ' + G.map.rows.map((row) => row.map((n) => `${n.c}${n.type[0]}>${n.next.map((x) => (x.type === 'boss' ? 'B' : G.map.rows[x.r].indexOf(x))).join('')}`).join(' ')).join(' / ') + ' rs' + G.rs);
    for (const tier of ['normal', 'elite', 'boss']) lines.push(`enc${act}${tier} ` + Gm.encounterFor(G, tier).join('+') + ' rs' + G.rs);
    const sh = Gm.genShop(G);
    lines.push('shop C' + sh.cards.map((x) => x.id + ':' + x.price).join(',') + ' R' + sh.relics.map((x) => x.id + ':' + x.price).join(',') + ' P' + sh.potions.map((x) => x.id + ':' + x.price).join(',') + ' X' + sh.remove.price + ' rs' + G.rs);
    for (const tier of ['normal', 'elite', 'boss']) { const r = En.combatReward(G, tier); lines.push(`rew${tier} g${r.gold} c${r.cards.join(',')} r${r.relic} p${r.potion} b${r.bossRelics ? r.bossRelics.join(',') : ''} rs${G.rs}`); }
    for (let i = 0; i < 3; i++) { const ev = Gm.pickEvent(G); lines.push('event ' + ev.id + ' rs' + G.rs); }
    G.nm = 0;
  }
  cases.push({ name: `run ${ch} s${seed}`, kind: 'run', params: { char: ch, seed }, lines });
}
writeFileSync(OUT, JSON.stringify(cases));
console.log('casos', cases.length, 'líneas', cases.reduce((a, c) => a + c.lines.length, 0));
const done = cases.filter((c) => c.name.startsWith('combat')).map((c) => c.lines[c.lines.length - 1].split(' ')[1]);
console.log('resultados', done.reduce((a, r) => ((a[r] = (a[r] || 0) + 1), a), {}));
