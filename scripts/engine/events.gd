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
	var leave := {"t": DB.tl("Marcharte"), "hint": "", "ok": true, "run": func(_ctx): return DB.tl("Sigues tu camino.")}
	match id:
		"altar":
			return [
				{"t": DB.tl("Ofrecer sangre"), "hint": DB.tl("Pierdes 8 PV. Obtienes una reliquia."), "ok": G.hp > 10, "run": func(_ctx):
					G.hp -= 8
					var r = Eng.random_relic(G)
					if r != null:
						Eng.add_relic(G, r)
						return DB.tl("El altar brilla y te concede **%s**.") % DB.relics[r].n
					return DB.tl("El altar guarda silencio.")},
				{"t": DB.tl("Rezar"), "hint": DB.tl("Recuperas 15 PV."), "ok": true, "run": func(_ctx):
					G.hp = mini(G.maxHp, G.hp + 15)
					return DB.tl("Una calidez suave recorre tu cuerpo.")},
				leave]
		"fuente":
			return [
				{"t": DB.tl("Beber"), "hint": DB.tl("Recuperas el 30% de tus PV máx."), "ok": true, "run": func(_ctx):
					var n := ceili(G.maxHp * 0.3)
					G.hp = mini(G.maxHp, G.hp + n)
					return DB.tl("Recuperas %d PV.") % n},
				{"t": DB.tl("Purificar una carta"), "hint": DB.tl("Elimina una carta de tu mazo. Pierdes 5 PV."), "ok": G.hp > 6, "run": func(ctx):
					var c: Array = await ctx.pick_card(DB.tl("Elige una carta para eliminar"), func(_c): return true, 1)
					if c.is_empty():
						return DB.tl("Cambias de idea.")
					G.deck = G.deck.filter(func(x): return x.uid != c[0].uid)
					G.hp -= 5
					return DB.tl("Eliminas **%s** de tu mazo.") % DB.cards[c[0].id].name},
				leave]
		"forjador":
			return [
				{"t": DB.tl("Mejorar una carta"), "hint": DB.tl("Gratis."), "ok": G.deck.any(func(c): return Eng.can_upgrade(c)), "run": func(ctx):
					var c: Array = await ctx.pick_card(DB.tl("Elige una carta para mejorar"), func(x): return Eng.can_upgrade(x), 1, true)
					if c.is_empty():
						return DB.tl("Cambias de idea.")
					var real = G.deck.filter(func(x): return x.uid == c[0].uid)[0]
					real.up = true
					return DB.tl("**%s** ha sido mejorada.") % DB.cards[real.id].name},
				{"t": DB.tl("Regatear"), "hint": DB.tl("Ganas 45 de oro. Pierdes 6 PV."), "ok": G.hp > 7, "run": func(_ctx):
					G.hp -= 6
					Eng.gain_gold(G, 45)
					return DB.tl("El herrero te lanza unas monedas tras un forcejeo.")},
				leave]
		"cofre":
			return [
				{"t": DB.tl("Abrirlo"), "hint": DB.tl("Ganas 80 de oro. Añades la maldición Duda."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 80)
					G.deck.append(Eng.make_card(G, "doubt"))
					return DB.tl("Tomas el oro... y sientes un escalofrío.")},
				{"t": DB.tl("Dejarlo"), "hint": "", "ok": true, "run": func(_ctx): return DB.tl("Es mejor no tentar a la suerte.")}]
		"hongos":
			return [
				{"t": DB.tl("Comerlos"), "hint": DB.tl("+6 PV máx. Añades una Herida."), "ok": true, "run": func(_ctx):
					G.maxHp += 6
					G.hp += 6
					G.deck.append(Eng.make_card(G, "wound"))
					return DB.tl("Te sientes más fuerte, pero con náuseas.")},
				{"t": DB.tl("Recolectarlos"), "hint": DB.tl("Ganas 30 de oro."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 30)
					return DB.tl("Los vendes más adelante.")},
				leave]
		"mercader":
			return [
				{"t": DB.tl("Comprar reliquia (50 de oro)"), "hint": DB.tl("Una reliquia aleatoria."), "ok": G.gold >= 50, "run": func(_ctx):
					G.gold -= 50
					var r = Eng.random_relic(G)
					if r != null:
						Eng.add_relic(G, r)
						return DB.tl("Obtienes **%s**.") % DB.relics[r].n
					return DB.tl("No le quedan reliquias.")},
				{"t": DB.tl("Comprar poción (20 de oro)"), "hint": DB.tl("Una poción aleatoria."), "ok": G.gold >= 20 and G.potions.has(null), "run": func(_ctx):
					G.gold -= 20
					var pid: String = Eng.pick(G, DB.potions.keys())
					G.potions[G.potions.find(null)] = pid
					return DB.tl("Obtienes **%s**.") % DB.potions[pid].n},
				{"t": DB.tl("Marcharte"), "hint": "", "ok": true, "run": func(_ctx): return DB.tl("El fantasma se desvanece.")}]
		"duelo":
			return [
				{"t": DB.tl("Aceptar el duelo"), "hint": DB.tl("Combate contra un élite. Recompensa mejorada."), "ok": true, "fight": "elite"},
				{"t": DB.tl("Rechazarlo"), "hint": "", "ok": true, "run": func(_ctx): return DB.tl("Lo rodeas con cuidado.")}]
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

static func _remove_one(ctx, G, title: String = "") -> String:
	var c: Array = await ctx.pick_card(title if title != "" else DB.tl("Elige una carta para eliminar"), func(_c): return true, 1)
	if c.is_empty():
		return ""
	G.deck = G.deck.filter(func(x): return x.uid != c[0].uid)
	return DB.cards[c[0].id].name

static func _upgrade_one(ctx, G) -> String:
	var c: Array = await ctx.pick_card(DB.tl("Elige una carta para mejorar"), func(x): return Eng.can_upgrade(x), 1, true)
	if c.is_empty():
		return ""
	var real = G.deck.filter(func(x): return x.uid == c[0].uid)[0]
	real.up = true
	return DB.cards[real.id].name

## Resultado con reliquia: frase completa con {r} si la hay (found) u otra frase si ya no queda ninguna (none).
static func _relic_text(G, r, found: String, none: String) -> String:
	if r == null:
		return DB.tl(none)
	Eng.add_relic(G, r)
	return DB.tl(found).format({"r": DB.relics[r].n})


## «A y B y C» en el idioma activo (listas cortas de nombres de cartas).
static func _and_list(names: Array) -> String:
	var out := ""
	for n in names:
		out = str(n) if out == "" else DB.tl("{a} y {b}").format({"a": out, "b": n})
	return out


static func _options_w2(G, id: String, leave: Dictionary) -> Array:
	var has_potion: bool = G.potions.any(func(p): return p != null)
	var can_up: bool = G.deck.any(func(c): return Eng.can_upgrade(c))
	match id:
		"biblioteca":
			return [
				{"t": DB.tl("Estudiar un tomo"), "hint": DB.tl("Elige 1 de 3 cartas poco comunes o raras de tu musa."), "ok": true, "run": func(ctx):
					var pick: Array = await ctx.choose_new(DB.tl("Elige una carta del tomo"), _muse_cards(G, ["uncommon", "rare"], 3))
					if pick.is_empty():
						return DB.tl("Cierras el libro sin terminar de leerlo.")
					var c := Eng.gain_card(G, pick[0].id)
					return DB.tl("Memorizas cada palabra: aprendes **%s**.") % DB.cards[c.id].name},
				{"t": DB.tl("Arrancar páginas doradas"), "hint": DB.tl("Ganas 60 de oro. Añades la maldición Duda."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 60)
					G.deck.append(Eng.make_card(G, "doubt"))
					return DB.tl("Las páginas valen su peso en oro... pero las palabras arrancadas te persiguen.")},
				leave]
		"jugador":
			return [
				{"t": DB.tl("Apostar 40 de oro"), "hint": DB.tl("50%: ganas 100 de oro."), "ok": G.gold >= 40, "run": func(_ctx):
					G.gold -= 40
					if Eng.rnd(G) < 0.5:
						Eng.gain_gold(G, 100)
						return DB.tl("¡Los dados te sonríen! Ganas **100 de oro**.")
					return DB.tl("Los dados ruedan... y pierdes. El hombrecillo guarda tus monedas con una reverencia.")},
				{"t": DB.tl("Apostar tu sangre"), "hint": DB.tl("Pierdes 8 PV. 50%: obtienes una reliquia."), "ok": G.hp > 9, "run": func(_ctx):
					G.hp -= 8
					if Eng.rnd(G) < 0.5:
						return _relic_text(G, Eng.random_relic(G), "Doble seis. Pagas con sangre y obtienes **{r}**.", "Doble seis. Pagas con sangre y pero no queda ninguna reliquia que encontrar.")
					return DB.tl("Un uno y un dos. La sangre cae en el polvo y el hombrecillo sonríe.")},
				leave]
		"espejo":
			return [
				{"t": DB.tl("Reflejar una carta"), "hint": DB.tl("Duplica una carta de tu mazo."), "ok": G.deck.any(func(c): return _playable_card(c)), "run": func(ctx):
					var c: Array = await ctx.pick_card(DB.tl("Elige una carta para duplicar"), func(x): return _playable_card(x), 1)
					if c.is_empty():
						return DB.tl("Apartas la mirada.")
					G.deck.append(Eng.make_card(G, c[0].id, c[0].up))
					return DB.tl("Del espejo sale una copia exacta de **%s**.") % DB.cards[c[0].id].name},
				{"t": DB.tl("Atravesar el espejo"), "hint": DB.tl("Transforma una carta de tu mazo en otra aleatoria de tu musa."), "ok": not G.deck.is_empty(), "run": func(ctx):
					var c: Array = await ctx.pick_card(DB.tl("Elige una carta para transformar"), func(_x): return true, 1)
					if c.is_empty():
						return DB.tl("Apartas la mirada.")
					var old_name: String = DB.cards[c[0].id].name
					return DB.tl("Al otro lado, **%s** se ha convertido en **%s**.") % [old_name, _transform(G, c[0])]},
				leave]
		"peregrina":
			return [
				{"t": DB.tl("Darle una poción"), "hint": DB.tl("Pierdes una poción al azar. Obtienes una reliquia."), "ok": has_potion, "run": func(_ctx):
					var slots := []
					for i in G.potions.size():
						if G.potions[i] != null:
							slots.append(i)
					G.potions[Eng.pick(G, slots)] = null
					return _relic_text(G, Eng.random_relic(G), "La peregrina bebe y recupera el color. Agradecida, te da un objeto y obtienes **{r}**.", "La peregrina bebe y recupera el color. Agradecida, te da un objeto y pero no queda ninguna reliquia que encontrar.")},
				{"t": DB.tl("Darle 35 de oro"), "hint": DB.tl("Recuperas 12 PV y mejoras una carta al azar."), "ok": G.gold >= 35, "run": func(_ctx):
					G.gold -= 35
					G.hp = mini(G.maxHp, G.hp + 12)
					var ups := _rand_upgrade(G, 1)
					return DB.tl("La peregrina te bendice. Recuperas 12 PV y **{c}** mejora.").format({"c": ups[0]}) if not ups.is_empty() else DB.tl("La peregrina te bendice. Recuperas 12 PV.")},
				{"t": DB.tl("Marcharte"), "hint": "", "ok": true, "run": func(_ctx): return DB.tl("Le deseas suerte y sigues tu camino.")}]
		"recuerdo":
			return [
				{"t": DB.tl("Abrazar el recuerdo"), "hint": DB.tl("Pierdes 5 PV. Elige 1 de 2 cartas raras de tu musa."), "ok": G.hp > 6, "run": func(ctx):
					G.hp -= 5
					var pick: Array = await ctx.choose_new(DB.tl("El recuerdo toma forma"), _muse_cards(G, ["rare"], 2))
					if pick.is_empty():
						return DB.tl("El recuerdo se desvanece antes de que puedas alcanzarlo.")
					var c := Eng.gain_card(G, pick[0].id)
					return DB.tl("Duele, pero ahora lo recuerdas: obtienes **%s**.") % DB.cards[c.id].name},
				{"t": DB.tl("Dejarlo ir"), "hint": DB.tl("Elimina una carta de tu mazo."), "ok": not G.deck.is_empty(), "run": func(ctx):
					var n: String = await _remove_one(ctx, G)
					return (DB.tl("Sueltas el pasado y, con él, **%s**.") % n) if n != "" else DB.tl("Te quedas un rato en silencio.")},
				leave]
		"naufragio":
			return [
				{"t": DB.tl("Saquear la bodega"), "hint": DB.tl("Ganas 55 de oro. 30%: una rata te muerde y pierdes 6 PV."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 55)
					if Eng.rnd(G) < 0.3:
						G.hp -= 6
						return DB.tl("Llenas los bolsillos de monedas... y una rata enorme te muerde la mano.")
					return DB.tl("Llenas los bolsillos de monedas mohosas.")},
				{"t": DB.tl("Bucear hasta el camarote"), "hint": DB.tl("Pierdes 9 PV. Obtienes una reliquia."), "ok": G.hp > 10, "run": func(_ctx):
					G.hp -= 9
					return _relic_text(G, Eng.random_relic(G), "El agua helada te corta la respiración, pero en el cofre del capitán obtienes **{r}**.", "El agua helada te corta la respiración, pero en el cofre del capitán pero no queda ninguna reliquia que encontrar.")},
				leave]
		"kraken":
			return [
				{"t": DB.tl("Desafiar a la criatura"), "hint": DB.tl("Combate contra el Tentáculo Abisal (élite). Recompensa de élite."), "ok": true, "fight": "elite", "fight_ids": ["tentacle"]},
				{"t": DB.tl("Arrojar 30 de oro al agua"), "hint": DB.tl("Recuperas el 25% de tus PV máx. y eliminas una maldición si tienes."), "ok": G.gold >= 30, "run": func(_ctx):
					G.gold -= 30
					var n := ceili(G.maxHp * 0.25)
					G.hp = mini(G.maxHp, G.hp + n)
					var curses: Array = G.deck.filter(func(c): return _is_curse(c))
					if not curses.is_empty():
						var cu = curses[0]
						G.deck = G.deck.filter(func(x): return x.uid != cu.uid)
						return DB.tl("El ojo se cierra, satisfecho. Recuperas %d PV y la maldición **%s** se disuelve en la marea.") % [n, DB.cards[cu.id].name]
					return DB.tl("El ojo se cierra, satisfecho. Recuperas %d PV.") % n},
				leave]
		"susurros":
			return [
				{"t": DB.tl("Escuchar sus secretos"), "hint": DB.tl("Mejoras 2 cartas al azar. Añades la maldición Duda."), "ok": can_up, "run": func(_ctx):
					var ups := _rand_upgrade(G, 2)
					G.deck.append(Eng.make_card(G, "doubt"))
					return DB.tl("Los secretos te enseñan a mejorar **%s**, pero dejan una duda en tu corazón.") % _and_list(ups)},
				{"t": DB.tl("Tomar un fruto"), "hint": DB.tl("Obtienes una poción aleatoria y recuperas 10 PV."), "ok": G.potions.has(null), "run": func(_ctx):
					var pid = _give_potion(G)
					G.hp = mini(G.maxHp, G.hp + 10)
					return DB.tl("El fruto sabe a miel y a tierra. Recuperas 10 PV y guardas **%s**.") % DB.potions[pid].n},
				leave]
		"hadas":
			return [
				{"t": DB.tl("Bailar con ellas"), "hint": DB.tl("Transforma 2 cartas al azar de tu mazo."), "ok": G.deck.size() >= 2, "run": func(_ctx):
					var names := []
					for c in Eng.shuffle(G, G.deck.duplicate()).slice(0, 2):
						names.append("%s → %s" % [DB.cards[c.id].name, _transform(G, c)])
					return DB.tl("Bailas hasta el amanecer. Al despertar, tu mazo ha cambiado: **%s**.") % ", ".join(names)},
				{"t": DB.tl("Atrapar una"), "hint": DB.tl("50%: obtienes una reliquia. Si no, pierdes 10 PV y añades Duda."), "ok": G.hp > 10, "run": func(_ctx):
					if Eng.rnd(G) < 0.5:
						return _relic_text(G, Eng.random_relic(G), "¡La atrapas! A cambio de su libertad obtienes **{r}**.", "¡La atrapas! A cambio de su libertad pero no queda ninguna reliquia que encontrar.")
					G.hp -= 10
					G.deck.append(Eng.make_card(G, "doubt"))
					return DB.tl("Se escapa entre risas y te deja un hechizo de mala suerte.")},
				leave]
		"panal":
			return [
				{"t": DB.tl("Probar la miel real"), "hint": DB.tl("Recuperas el 40% de tus PV máx. Añades 2 Babas a tu mazo."), "ok": true, "run": func(_ctx):
					var n := ceili(G.maxHp * 0.4)
					G.hp = mini(G.maxHp, G.hp + n)
					for i in 2:
						G.deck.append(Eng.make_card(G, "slime"))
					return DB.tl("Recuperas %d PV. La miel es deliciosa... y muy, muy pegajosa.") % n},
				{"t": DB.tl("Llevarte la cera"), "hint": DB.tl("Ganas 70 de oro. Pierdes 9 PV."), "ok": G.hp > 10, "run": func(_ctx):
					Eng.gain_gold(G, 70)
					G.hp -= 9
					return DB.tl("Arrancas un buen trozo de cera dorada mientras el enjambre te pica sin piedad.")},
				leave]
		"trono":
			return [
				{"t": DB.tl("Sentarte en el trono"), "hint": DB.tl("Obtienes una reliquia de jefe. Añades 2 maldiciones Duda."), "ok": true, "run": func(_ctx):
					var rs: Array = Eng.boss_relics(G)
					for i in 2:
						G.deck.append(Eng.make_card(G, "doubt"))
					if rs.is_empty():
						return DB.tl("La corona pesa demasiado y no te concede nada... salvo dudas.")
					return _relic_text(G, rs[0], "La corona se ajusta a tu cabeza: obtienes **{r}**.", "La corona se ajusta a tu cabeza: pero no queda ninguna reliquia que encontrar.")},
				{"t": DB.tl("Arrodillarte"), "hint": DB.tl("Elimina una carta de tu mazo. Recuperas 15 PV."), "ok": not G.deck.is_empty(), "run": func(ctx):
					var n: String = await _remove_one(ctx, G)
					G.hp = mini(G.maxHp, G.hp + 15)
					return (DB.tl("Rindes homenaje y dejas atrás **%s**. Recuperas 15 PV.") % n) if n != "" else DB.tl("Rindes homenaje en silencio. Recuperas 15 PV.")},
				leave]
		# --- Fase 4B: encuentros raros, una vez por partida
		"campana_bruma":
			return [
				{"t": DB.tl("Tocar la campana"), "hint": DB.tl("Pierdes 7 PV. Obtienes una reliquia."), "ok": G.hp > 7, "run": func(_ctx):
					G.hp -= 7
					return _relic_text(G, Eng.random_relic_tiered(G, 0.15), "La nota atraviesa la niebla. Entre los ecos obtienes **{r}**.", "La nota atraviesa la niebla. Entre los ecos pero no queda ninguna reliquia que encontrar.")},
				{"t": DB.tl("Arrancar el badajo"), "hint": DB.tl("Ganas 90 de oro. Añades la maldición Duda."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 90)
					G.deck.append(Eng.make_card(G, "doubt"))
					return DB.tl("La campana queda muda. El badajo se convierte en monedas, pero su última nota se queda contigo.")},
				leave]
		"corazon_hueco":
			return [
				{"t": DB.tl("Abrazar el corazón"), "hint": DB.tl("+8 PV máx. Añades 2 Heridas."), "ok": true, "run": func(_ctx):
					G.maxHp += 8
					G.hp += 8
					for i in 2:
						G.deck.append(Eng.make_card(G, "wound"))
					return DB.tl("La savia fortalece tu pecho. Dos espinas se desprenden y se enredan en tu mazo.")},
				{"t": DB.tl("Cortar el corazón"), "hint": DB.tl("Ganas 110 de oro. Pierdes 10 PV."), "ok": G.hp > 10, "run": func(_ctx):
					G.hp -= 10
					Eng.gain_gold(G, 110)
					return DB.tl("La madera se abre como un cofre. Recoges sus monedas semilla; el roble exhala un largo suspiro.")},
				leave]
		"cera_memoria":
			return [
				{"t": DB.tl("Esculpir tus recuerdos"), "hint": DB.tl("Pierdes 12 PV. Mejora hasta 2 cartas al azar."), "ok": G.hp > 12 and can_up, "run": func(_ctx):
					G.hp -= 12
					var ups := _rand_upgrade(G, 2)
					return DB.tl("La cera se enfría con una forma más nítida: **%s** mejora.") % _and_list(ups)},
				{"t": DB.tl("Trocar una forma"), "hint": DB.tl("Transforma una carta en otra aleatoria de tu musa. Ganas 75 de oro."), "ok": not G.deck.is_empty(), "run": func(ctx):
					var c: Array = await ctx.pick_card(DB.tl("Elige una carta para transformar"), func(_x): return true, 1)
					if c.is_empty():
						return DB.tl("La cera recupera su forma. Decides no cambiar la tuya.")
					var old_name: String = DB.cards[c[0].id].name
					var new_name: String = _transform(G, c[0])
					Eng.gain_gold(G, 75)
					return DB.tl("**%s** se funde y reaparece como **%s**. El molde sobrante se convierte en 75 de oro.") % [old_name, new_name]},
				leave]
		# --- exclusivos de cada musa
		"coliseo":
			return [
				{"t": DB.tl("Entrenar hasta el amanecer"), "hint": DB.tl("Pierdes 8 PV máx. +1 de Fuerza permanente en cada combate."), "ok": G.maxHp > 20, "run": func(_ctx):
					G.maxHp -= 8
					G.hp = mini(G.hp, G.maxHp)
					Eng.add_perm(G, "strength", 1)
					return DB.tl("Golpeas los muñecos hasta que tus brazos arden. **+1 de Fuerza** en cada combate.")},
				{"t": DB.tl("Afilar la espada"), "hint": DB.tl("Mejora una carta de tu mazo."), "ok": can_up, "run": func(ctx):
					var n: String = await _upgrade_one(ctx, G)
					return (DB.tl("**%s** ha sido mejorada.") % n) if n != "" else DB.tl("Guardas la piedra de afilar.")},
				leave]
		"madriguera":
			return [
				{"t": DB.tl("Afilar tus cuchillas"), "hint": DB.tl("+2 de Precisión permanente: tus Cuchillas infligen 2 de daño más."), "ok": true, "run": func(_ctx):
					Eng.add_perm(G, "accuracy", 2)
					return DB.tl("La piedra del zorro deja tus cuchillas con un filo perfecto. **+2 de Precisión** en cada combate.")},
				{"t": DB.tl("Tomar su alijo"), "hint": DB.tl("Obtienes un Frasco de Veneno y 40 de oro."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 40)
					var pid = _give_potion(G, "veneno")
					return DB.tl("Te llevas 40 monedas y un **{p}**. El zorro no parece molesto.").format({"p": DB.potions["veneno"].n}) if pid != null else DB.tl("Te llevas 40 monedas. El zorro no parece molesto.")},
				leave]
		"osario":
			return [
				{"t": DB.tl("Despertar a los huesos"), "hint": DB.tl("Pierdes 6 PV. Osty gana +5 PV máx. y +1 de Poder permanentes."), "ok": G.hp > 7, "run": func(_ctx):
					G.hp -= 6
					Eng.add_perm(G, "ostyMax", 5)
					Eng.add_perm(G, "ostyPow", 1)
					return DB.tl("Los huesos se unen a Osty, que crece y se fortalece. **Osty +5 PV máx. y +1 de Poder** en cada combate.")},
				{"t": DB.tl("Saquear las tumbas"), "hint": DB.tl("Ganas 50 de oro. Añades una Herida."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 50)
					G.deck.append(Eng.make_card(G, "wound"))
					return DB.tl("Las monedas de los muertos tintinean en tu bolsa. Algo te ha arañado al salir.")},
				leave]
		"templo_sol":
			return [
				{"t": DB.tl("Danzar ante la llama"), "hint": DB.tl("Pierdes 8 PV. +1 de Destreza permanente."), "ok": G.hp > 9, "run": func(_ctx):
					G.hp -= 8
					Eng.add_perm(G, "dexterity", 1)
					return DB.tl("Danzas hasta que la llama se inclina ante ti. **+1 de Destreza** en cada combate.")},
				{"t": DB.tl("Recoger las ofrendas"), "hint": DB.tl("Ganas 50 de oro. Recuperas 10 PV."), "ok": true, "run": func(_ctx):
					Eng.gain_gold(G, 50)
					G.hp = mini(G.maxHp, G.hp + 10)
					return DB.tl("Las ofrendas del solio son tuyas por derecho. Recuperas 10 PV.")},
				leave]
		"taller":
			return [
				{"t": DB.tl("Ajustar tus engranajes"), "hint": DB.tl("+2 de Precisión de Relojero permanente: tus Engranajes infligen 2 de daño más."), "ok": true, "run": func(_ctx):
					Eng.add_perm(G, "precision", 2)
					return DB.tl("Cada engranaje encaja con un clic perfecto. **+2 de Precisión de Relojero** en cada combate.")},
				{"t": DB.tl("Cambiar tu muelle"), "hint": DB.tl("+10 PV máx. Pierdes 50 de oro (o todo el que tengas)."), "ok": true, "run": func(_ctx):
					G.maxHp += 10
					G.hp += 10
					G.gold = maxi(0, G.gold - 50)
					return DB.tl("Un muelle nuevo, firme y brillante. Te sientes más resistente.")},
				leave]
		"poza_lunar":
			return [
				{"t": DB.tl("Cantar a la luna"), "hint": DB.tl("Pierdes 6 PV máx. +1 de Resonancia permanente."), "ok": G.maxHp > 20, "run": func(_ctx):
					G.maxHp -= 6
					G.hp = mini(G.hp, G.maxHp)
					Eng.add_perm(G, "resonancia", 1)
					return DB.tl("La poza responde a tu canción. **+1 de Resonancia** en cada combate.")},
				{"t": DB.tl("Bañarte en la poza"), "hint": DB.tl("Recuperas todos tus PV."), "ok": G.hp < G.maxHp, "run": func(_ctx):
					G.hp = G.maxHp
					return DB.tl("El agua lunar cierra todas tus heridas.")},
				leave]
	return [leave]


## Texto del evento (algunos cambian según la musa).
static func text_for(G, ev: Dictionary) -> String:
	if ev.has("textBy") and ev.textBy.has(G.char):
		return ev.textBy[G.char]
	return ev.text
