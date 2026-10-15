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
	return [leave]
