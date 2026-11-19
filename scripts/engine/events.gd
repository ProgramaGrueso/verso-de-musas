class_name EventsLogic
extends RefCounted
## Opciones y efectos de los eventos (port de data/events.js). Las opciones devuelven el texto del resultado.
## ctx.pick_card(titulo, filtro, n) es una corrutina que devuelve las cartas elegidas.


static func _md(t: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\*\\*(.+?)\\*\\*")
	return rx.sub(t, "[b][color=#f0cf7a]$1[/color][/b]", true)


static func md(t: String) -> String:
	return _md(t)


## Devuelve [{t, hint, ok, run: Callable | fight: String}]
static func options(G, id: String) -> Array:
	var leave := {"t": "Marcharte", "hint": "", "ok": true, "run": func(_ctx): return "Sigues tu camino."}
	match id:
		"altar":
			return [
				{"t": "Ofrecer sangre", "hint": "Pierdes 8 PV. Obtienes una reliquia.", "ok": G.hp > 10, "run": func(_ctx):
					G.hp -= 8
					var r = Eng.random_relic(G)
					if r != null:
						Eng.add_relic(G, r)
						return "El altar brilla y te concede **%s**." % DB.relics[r].n
					return "El altar guarda silencio."},
				{"t": "Rezar", "hint": "Recuperas 15 PV.", "ok": true, "run": func(_ctx):
					G.hp = mini(G.maxHp, G.hp + 15)
					return "Una calidez suave recorre tu cuerpo."},
				leave]
		"fuente":
			return [
				{"t": "Beber", "hint": "Recuperas el 30% de tus PV máx.", "ok": true, "run": func(_ctx):
					var n := ceili(G.maxHp * 0.3)
					G.hp = mini(G.maxHp, G.hp + n)
					return "Recuperas %d PV." % n},
				{"t": "Purificar una carta", "hint": "Elimina una carta de tu mazo. Pierdes 5 PV.", "ok": G.hp > 6, "run": func(ctx):
					var c: Array = await ctx.pick_card("Elige una carta para eliminar", func(_c): return true, 1)
					if c.is_empty():
						return "Cambias de idea."
					G.deck = G.deck.filter(func(x): return x.uid != c[0].uid)
					G.hp -= 5
					return "Eliminas **%s** de tu mazo." % DB.cards[c[0].id].name},
				leave]
		"forjador":
			return [
				{"t": "Mejorar una carta", "hint": "Gratis.", "ok": G.deck.any(func(c): return Eng.can_upgrade(c)), "run": func(ctx):
					var c: Array = await ctx.pick_card("Elige una carta para mejorar", func(x): return Eng.can_upgrade(x), 1, true)
					if c.is_empty():
						return "Cambias de idea."
					var real = G.deck.filter(func(x): return x.uid == c[0].uid)[0]
					real.up = true
					return "**%s** ha sido mejorada." % DB.cards[real.id].name},
				{"t": "Regatear", "hint": "Ganas 45 de oro. Pierdes 6 PV.", "ok": G.hp > 7, "run": func(_ctx):
					G.hp -= 6
					Eng.gain_gold(G, 45)
					return "El herrero te lanza unas monedas tras un forcejeo."},
				leave]
		"cofre":
			return [
				{"t": "Abrirlo", "hint": "Ganas 80 de oro. Añades la maldición Duda.", "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 80)
					G.deck.append(Eng.make_card(G, "doubt"))
					return "Tomas el oro... y sientes un escalofrío."},
				{"t": "Dejarlo", "hint": "", "ok": true, "run": func(_ctx): return "Es mejor no tentar a la suerte."}]
		"hongos":
			return [
				{"t": "Comerlos", "hint": "+6 PV máx. Añades una Herida.", "ok": true, "run": func(_ctx):
					G.maxHp += 6
					G.hp += 6
					G.deck.append(Eng.make_card(G, "wound"))
					return "Te sientes más fuerte, pero con náuseas."},
				{"t": "Recolectarlos", "hint": "Ganas 30 de oro.", "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 30)
					return "Los vendes más adelante."},
				leave]
		"mercader":
			return [
				{"t": "Comprar reliquia (50 de oro)", "hint": "Una reliquia aleatoria.", "ok": G.gold >= 50, "run": func(_ctx):
					G.gold -= 50
					var r = Eng.random_relic(G)
					if r != null:
						Eng.add_relic(G, r)
						return "Obtienes **%s**." % DB.relics[r].n
					return "No le quedan reliquias."},
				{"t": "Comprar poción (20 de oro)", "hint": "Una poción aleatoria.", "ok": G.gold >= 20 and G.potions.has(null), "run": func(_ctx):
					G.gold -= 20
					var pid: String = Eng.pick(G, DB.potions.keys())
					G.potions[G.potions.find(null)] = pid
					return "Obtienes **%s**." % DB.potions[pid].n},
				{"t": "Marcharte", "hint": "", "ok": true, "run": func(_ctx): return "El fantasma se desvanece."}]
		"duelo":
			return [
				{"t": "Aceptar el duelo", "hint": "Combate contra un élite. Recompensa mejorada.", "ok": true, "fight": "elite"},
				{"t": "Rechazarlo", "hint": "", "ok": true, "run": func(_ctx): return "Lo rodeas con cuidado."}]
	return _options_w2(G, id, leave)


# ============================== Oleada 2 ==============================
static func _playable_card(c) -> bool:
	return not (DB.cards[c.id].type in ["curse", "status"])

static func _is_curse(c) -> bool:
	return DB.cards[c.id].type == "curse"

## Hasta n cartas distintas de la musa con alguna de esas rarezas.
static func _muse_cards(G, rarities: Array, n: int) -> Array:
	var pl: Array = Eng.unlocked(G, DB.pool[G.char]).filter(func(id): return DB.cards[id].rarity in rarities)
	return Eng.shuffle(G, pl.duplicate()).slice(0, n)

## Mejora n cartas al azar; devuelve sus nombres.
static func _rand_upgrade(G, n: int) -> Array:
	var ups: Array = G.deck.filter(func(c): return Eng.can_upgrade(c))
	var out := []
	for c in Eng.shuffle(G, ups).slice(0, n):
		c.up = true
		out.append(DB.cards[c.id].name)
	return out

## Sustituye la carta por otra aleatoria de la musa; devuelve el nombre de la nueva.
static func _transform(G, inst: Dictionary) -> String:
	G.deck = G.deck.filter(func(x): return x.uid != inst.uid)
	var pl: Array = Eng.unlocked(G, DB.pool[G.char]).filter(func(id): return id != inst.id)
	var nid: String = Eng.pick(G, pl)
	Eng.gain_card(G, nid)
	return DB.cards[nid].name

static func _give_potion(G, pid = null):
	var i: int = G.potions.find(null)
	if i < 0:
		return null
	if pid == null:
		pid = Eng.pick(G, DB.potions.keys())
	G.potions[i] = pid
	return pid

static func _remove_one(ctx, G, title: String = "Elige una carta para eliminar") -> String:
	var c: Array = await ctx.pick_card(title, func(_c): return true, 1)
	if c.is_empty():
		return ""
	G.deck = G.deck.filter(func(x): return x.uid != c[0].uid)
	return DB.cards[c[0].id].name

static func _upgrade_one(ctx, G) -> String:
	var c: Array = await ctx.pick_card("Elige una carta para mejorar", func(x): return Eng.can_upgrade(x), 1, true)
	if c.is_empty():
		return ""
	var real = G.deck.filter(func(x): return x.uid == c[0].uid)[0]
	real.up = true
	return DB.cards[real.id].name

static func _relic_text(G, r) -> String:
	if r == null:
		return "pero no queda ninguna reliquia que encontrar."
	Eng.add_relic(G, r)
	return "obtienes **%s**." % DB.relics[r].n


static func _options_w2(G, id: String, leave: Dictionary) -> Array:
	var has_potion: bool = G.potions.any(func(p): return p != null)
	var can_up: bool = G.deck.any(func(c): return Eng.can_upgrade(c))
	match id:
		"biblioteca":
			return [
				{"t": "Estudiar un tomo", "hint": "Elige 1 de 3 cartas poco comunes o raras de tu musa.", "ok": true, "run": func(ctx):
					var pick: Array = await ctx.choose_new("Elige una carta del tomo", _muse_cards(G, ["uncommon", "rare"], 3))
					if pick.is_empty():
						return "Cierras el libro sin terminar de leerlo."
					var c := Eng.gain_card(G, pick[0].id)
					return "Memorizas cada palabra: aprendes **%s**." % DB.cards[c.id].name},
				{"t": "Arrancar páginas doradas", "hint": "Ganas 60 de oro. Añades la maldición Duda.", "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 60)
					G.deck.append(Eng.make_card(G, "doubt"))
					return "Las páginas valen su peso en oro... pero las palabras arrancadas te persiguen."},
				leave]
		"jugador":
			return [
				{"t": "Apostar 40 de oro", "hint": "50%: ganas 100 de oro.", "ok": G.gold >= 40, "run": func(_ctx):
					G.gold -= 40
					if Eng.rnd(G) < 0.5:
						Eng.gain_gold(G, 100)
						return "¡Los dados te sonríen! Ganas **100 de oro**."
					return "Los dados ruedan... y pierdes. El hombrecillo guarda tus monedas con una reverencia."},
				{"t": "Apostar tu sangre", "hint": "Pierdes 8 PV. 50%: obtienes una reliquia.", "ok": G.hp > 9, "run": func(_ctx):
					G.hp -= 8
					if Eng.rnd(G) < 0.5:
						return "Doble seis. Pagas con sangre y " + _relic_text(G, Eng.random_relic(G))
					return "Un uno y un dos. La sangre cae en el polvo y el hombrecillo sonríe."},
				leave]
		"espejo":
			return [
				{"t": "Reflejar una carta", "hint": "Duplica una carta de tu mazo.", "ok": G.deck.any(func(c): return _playable_card(c)), "run": func(ctx):
					var c: Array = await ctx.pick_card("Elige una carta para duplicar", func(x): return _playable_card(x), 1)
					if c.is_empty():
						return "Apartas la mirada."
					G.deck.append(Eng.make_card(G, c[0].id, c[0].up))
					return "Del espejo sale una copia exacta de **%s**." % DB.cards[c[0].id].name},
				{"t": "Atravesar el espejo", "hint": "Transforma una carta de tu mazo en otra aleatoria de tu musa.", "ok": not G.deck.is_empty(), "run": func(ctx):
					var c: Array = await ctx.pick_card("Elige una carta para transformar", func(_x): return true, 1)
					if c.is_empty():
						return "Apartas la mirada."
					var old_name: String = DB.cards[c[0].id].name
					return "Al otro lado, **%s** se ha convertido en **%s**." % [old_name, _transform(G, c[0])]},
				leave]
		"peregrina":
			return [
				{"t": "Darle una poción", "hint": "Pierdes una poción al azar. Obtienes una reliquia.", "ok": has_potion, "run": func(_ctx):
					var slots := []
					for i in G.potions.size():
						if G.potions[i] != null:
							slots.append(i)
					G.potions[Eng.pick(G, slots)] = null
					return "La peregrina bebe y recupera el color. Agradecida, te da un objeto y " + _relic_text(G, Eng.random_relic(G))},
				{"t": "Darle 35 de oro", "hint": "Recuperas 12 PV y mejoras una carta al azar.", "ok": G.gold >= 35, "run": func(_ctx):
					G.gold -= 35
					G.hp = mini(G.maxHp, G.hp + 12)
					var ups := _rand_upgrade(G, 1)
					return "La peregrina te bendice. Recuperas 12 PV%s." % ((" y **%s** mejora" % ups[0]) if not ups.is_empty() else "")},
				{"t": "Marcharte", "hint": "", "ok": true, "run": func(_ctx): return "Le deseas suerte y sigues tu camino."}]
		"recuerdo":
			return [
				{"t": "Abrazar el recuerdo", "hint": "Pierdes 5 PV. Elige 1 de 2 cartas raras de tu musa.", "ok": G.hp > 6, "run": func(ctx):
					G.hp -= 5
					var pick: Array = await ctx.choose_new("El recuerdo toma forma", _muse_cards(G, ["rare"], 2))
					if pick.is_empty():
						return "El recuerdo se desvanece antes de que puedas alcanzarlo."
					var c := Eng.gain_card(G, pick[0].id)
					return "Duele, pero ahora lo recuerdas: obtienes **%s**." % DB.cards[c.id].name},
				{"t": "Dejarlo ir", "hint": "Elimina una carta de tu mazo.", "ok": not G.deck.is_empty(), "run": func(ctx):
					var n: String = await _remove_one(ctx, G)
					return ("Sueltas el pasado y, con él, **%s**." % n) if n != "" else "Te quedas un rato en silencio."},
				leave]
		"naufragio":
			return [
				{"t": "Saquear la bodega", "hint": "Ganas 55 de oro. 30%: una rata te muerde y pierdes 6 PV.", "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 55)
					if Eng.rnd(G) < 0.3:
						G.hp -= 6
						return "Llenas los bolsillos de monedas... y una rata enorme te muerde la mano."
					return "Llenas los bolsillos de monedas mohosas."},
				{"t": "Bucear hasta el camarote", "hint": "Pierdes 9 PV. Obtienes una reliquia.", "ok": G.hp > 10, "run": func(_ctx):
					G.hp -= 9
					return "El agua helada te corta la respiración, pero en el cofre del capitán " + _relic_text(G, Eng.random_relic(G))},
				leave]
		"kraken":
			return [
				{"t": "Desafiar a la criatura", "hint": "Combate contra el Tentáculo Abisal (élite). Recompensa de élite.", "ok": true, "fight": "elite", "fight_ids": ["tentacle"]},
				{"t": "Arrojar 30 de oro al agua", "hint": "Recuperas el 25% de tus PV máx. y eliminas una maldición si tienes.", "ok": G.gold >= 30, "run": func(_ctx):
					G.gold -= 30
					var n := ceili(G.maxHp * 0.25)
					G.hp = mini(G.maxHp, G.hp + n)
					var curses: Array = G.deck.filter(func(c): return _is_curse(c))
					if not curses.is_empty():
						var cu = curses[0]
						G.deck = G.deck.filter(func(x): return x.uid != cu.uid)
						return "El ojo se cierra, satisfecho. Recuperas %d PV y la maldición **%s** se disuelve en la marea." % [n, DB.cards[cu.id].name]
					return "El ojo se cierra, satisfecho. Recuperas %d PV." % n},
				leave]
		"susurros":
			return [
				{"t": "Escuchar sus secretos", "hint": "Mejoras 2 cartas al azar. Añades la maldición Duda.", "ok": can_up, "run": func(_ctx):
					var ups := _rand_upgrade(G, 2)
					G.deck.append(Eng.make_card(G, "doubt"))
					return "Los secretos te enseñan a mejorar **%s**, pero dejan una duda en tu corazón." % " y ".join(ups)},
				{"t": "Tomar un fruto", "hint": "Obtienes una poción aleatoria y recuperas 10 PV.", "ok": G.potions.has(null), "run": func(_ctx):
					var pid = _give_potion(G)
					G.hp = mini(G.maxHp, G.hp + 10)
					return "El fruto sabe a miel y a tierra. Recuperas 10 PV y guardas **%s**." % DB.potions[pid].n},
				leave]
		"hadas":
			return [
				{"t": "Bailar con ellas", "hint": "Transforma 2 cartas al azar de tu mazo.", "ok": G.deck.size() >= 2, "run": func(_ctx):
					var names := []
					for c in Eng.shuffle(G, G.deck.duplicate()).slice(0, 2):
						names.append("%s → %s" % [DB.cards[c.id].name, _transform(G, c)])
					return "Bailas hasta el amanecer. Al despertar, tu mazo ha cambiado: **%s**." % ", ".join(names)},
				{"t": "Atrapar una", "hint": "50%: obtienes una reliquia. Si no, pierdes 10 PV y añades Duda.", "ok": G.hp > 10, "run": func(_ctx):
					if Eng.rnd(G) < 0.5:
						return "¡La atrapas! A cambio de su libertad " + _relic_text(G, Eng.random_relic(G))
					G.hp -= 10
					G.deck.append(Eng.make_card(G, "doubt"))
					return "Se escapa entre risas y te deja un hechizo de mala suerte."},
				leave]
		"panal":
			return [
				{"t": "Probar la miel real", "hint": "Recuperas el 40% de tus PV máx. Añades 2 Babas a tu mazo.", "ok": true, "run": func(_ctx):
					var n := ceili(G.maxHp * 0.4)
					G.hp = mini(G.maxHp, G.hp + n)
					for i in 2:
						G.deck.append(Eng.make_card(G, "slime"))
					return "Recuperas %d PV. La miel es deliciosa... y muy, muy pegajosa." % n},
				{"t": "Llevarte la cera", "hint": "Ganas 70 de oro. Pierdes 9 PV.", "ok": G.hp > 10, "run": func(_ctx):
					Eng.gain_gold(G, 70)
					G.hp -= 9
					return "Arrancas un buen trozo de cera dorada mientras el enjambre te pica sin piedad."},
				leave]
		"trono":
			return [
				{"t": "Sentarte en el trono", "hint": "Obtienes una reliquia de jefe. Añades 2 maldiciones Duda.", "ok": true, "run": func(_ctx):
					var rs: Array = Eng.boss_relics(G)
					for i in 2:
						G.deck.append(Eng.make_card(G, "doubt"))
					if rs.is_empty():
						return "La corona pesa demasiado y no te concede nada... salvo dudas."
					return "La corona se ajusta a tu cabeza: " + _relic_text(G, rs[0])},
				{"t": "Arrodillarte", "hint": "Elimina una carta de tu mazo. Recuperas 15 PV.", "ok": not G.deck.is_empty(), "run": func(ctx):
					var n: String = await _remove_one(ctx, G)
					G.hp = mini(G.maxHp, G.hp + 15)
					return ("Rindes homenaje y dejas atrás **%s**. Recuperas 15 PV." % n) if n != "" else "Rindes homenaje en silencio. Recuperas 15 PV."},
				leave]
		# --- exclusivos de cada musa
		"coliseo":
			return [
				{"t": "Entrenar hasta el amanecer", "hint": "Pierdes 8 PV máx. +1 de Fuerza permanente en cada combate.", "ok": G.maxHp > 20, "run": func(_ctx):
					G.maxHp -= 8
					G.hp = mini(G.hp, G.maxHp)
					Eng.add_perm(G, "strength", 1)
					return "Golpeas los muñecos hasta que tus brazos arden. **+1 de Fuerza** en cada combate."},
				{"t": "Afilar la espada", "hint": "Mejora una carta de tu mazo.", "ok": can_up, "run": func(ctx):
					var n: String = await _upgrade_one(ctx, G)
					return ("**%s** ha sido mejorada." % n) if n != "" else "Guardas la piedra de afilar."},
				leave]
		"madriguera":
			return [
				{"t": "Afilar tus cuchillas", "hint": "+2 de Precisión permanente: tus Cuchillas infligen 2 de daño más.", "ok": true, "run": func(_ctx):
					Eng.add_perm(G, "accuracy", 2)
					return "La piedra del zorro deja tus cuchillas con un filo perfecto. **+2 de Precisión** en cada combate."},
				{"t": "Tomar su alijo", "hint": "Obtienes un Frasco de Veneno y 40 de oro.", "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 40)
					var pid = _give_potion(G, "veneno")
					return "Te llevas 40 monedas%s. El zorro no parece molesto." % (" y un **Frasco de Veneno**" if pid != null else "")},
				leave]
		"osario":
			return [
				{"t": "Despertar a los huesos", "hint": "Pierdes 6 PV. Osty gana +5 PV máx. y +1 de Poder permanentes.", "ok": G.hp > 7, "run": func(_ctx):
					G.hp -= 6
					Eng.add_perm(G, "ostyMax", 5)
					Eng.add_perm(G, "ostyPow", 1)
					return "Los huesos se unen a Osty, que crece y se fortalece. **Osty +5 PV máx. y +1 de Poder** en cada combate."},
				{"t": "Saquear las tumbas", "hint": "Ganas 50 de oro. Añades una Herida.", "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 50)
					G.deck.append(Eng.make_card(G, "wound"))
					return "Las monedas de los muertos tintinean en tu bolsa. Algo te ha arañado al salir."},
				leave]
		"templo_sol":
			return [
				{"t": "Danzar ante la llama", "hint": "Pierdes 8 PV. +1 de Destreza permanente.", "ok": G.hp > 9, "run": func(_ctx):
					G.hp -= 8
					Eng.add_perm(G, "dexterity", 1)
					return "Danzas hasta que la llama se inclina ante ti. **+1 de Destreza** en cada combate."},
				{"t": "Recoger las ofrendas", "hint": "Ganas 50 de oro. Recuperas 10 PV.", "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 50)
					G.hp = mini(G.maxHp, G.hp + 10)
					return "Las ofrendas del solio son tuyas por derecho. Recuperas 10 PV."},
				leave]
		"taller":
			return [
				{"t": "Ajustar tus engranajes", "hint": "+2 de Precisión de Relojero permanente: tus Engranajes infligen 2 de daño más.", "ok": true, "run": func(_ctx):
					Eng.add_perm(G, "precision", 2)
					return "Cada engranaje encaja con un clic perfecto. **+2 de Precisión de Relojero** en cada combate."},
				{"t": "Cambiar tu muelle", "hint": "+10 PV máx. Pierdes 50 de oro (o todo el que tengas).", "ok": true, "run": func(_ctx):
					G.maxHp += 10
					G.hp += 10
					G.gold = maxi(0, G.gold - 50)
					return "Un muelle nuevo, firme y brillante. Te sientes más resistente."},
				leave]
		"poza_lunar":
			return [
				{"t": "Cantar a la luna", "hint": "Pierdes 6 PV máx. +1 de Resonancia permanente.", "ok": G.maxHp > 20, "run": func(_ctx):
					G.maxHp -= 6
					G.hp = mini(G.hp, G.maxHp)
					Eng.add_perm(G, "resonancia", 1)
					return "La poza responde a tu canción. **+1 de Resonancia** en cada combate."},
				{"t": "Bañarte en la poza", "hint": "Recuperas todos tus PV.", "ok": G.hp < G.maxHp, "run": func(_ctx):
					G.hp = G.maxHp
					return "El agua lunar cierra todas tus heridas."},
				leave]
	return [leave]


## Texto del evento (algunos cambian según la musa).
static func text_for(G, ev: Dictionary) -> String:
	if ev.has("textBy") and ev.textBy.has(G.char):
		return ev.textBy[G.char]
	return ev.text
