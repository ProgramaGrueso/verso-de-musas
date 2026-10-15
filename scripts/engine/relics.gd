class_name Relics
extends RefCounted
## Efectos de reliquias y pociones (los datos —nombre, icono, texto— viven en data/relics.json).


static func _solar(C) -> void:
	for e in Eng.living(C):
		Eng.deal_to_enemy(C, e, 4, {"noReflect": true})


## Ejecuta el gancho `hook` de la reliquia `id`. ctx es C (combate) o G (onCombatEnd/onPickup).
static func run(id: String, hook: String, ctx, a = null) -> void:
	match hook:
		"onCombatStart": _on_combat_start(id, ctx)
		"onTurnStart": _on_turn_start(id, ctx)
		"onTurnEnd": _on_turn_end(id, ctx)
		"onCardPlayed":
			if id == "prisma_solar" and ctx.playedThisTurn % 3 == 0:
				_solar(ctx)
		"onCombatEnd":
			if id == "brasa_carmesi":
				ctx.hp = mini(ctx.maxHp, ctx.hp + 6)
		"onPickup":
			if id == "fresa":
				ctx.maxHp += 7
				ctx.hp += 7
			elif id == "pozo":
				ctx.maxHp += 25
				ctx.hp = ctx.maxHp


static func _on_combat_start(id: String, C) -> void:
	match id:
		"anillo_cazadora": C.firstTurnDraw += 2
		"sello_osty":
			if C.osty != null:
				C.osty.max += 6
				C.osty.hp += 6
				C.osty.pow += 1
		"prisma_solar": _solar(C)
		"llave_maestra": Eng.gain_wind(C, 4)
		"concha_marea": Eng.channel_orb(C, "ola")
		"ancla": C.pl.block += 10
		"vajra": Eng.add_status(C, C.pl, "strength", 1)
		"canicas":
			for e in C.enemies:
				Eng.add_status(C, e, "vulnerable", 1)
		"piedra": Eng.add_status(C, C.pl, "dexterity", 1)
		"escamas": Eng.add_status(C, C.pl, "thorns", 3)
		"cuerno": C.firstTurnDraw += 1
		"lupa_relojero": Eng.add_status(C, C.pl, "precision", 2)
		"perla_negra": Eng.add_status(C, C.pl, "resonancia", 1)
		"cuenco_marea": C.orbMax += 1
		"corazon_laton": C.maxEnergy += 1
		"cetro_maremoto":
			for t in ["ola", "bruma", "perla"]:
				Eng.channel_orb(C, t)
			Eng.add_cards(C, "wound", 1, "draw")
		"nucleo":
			C.maxEnergy += 1
			Eng.add_cards(C, "wound", 1, "draw")
		"ojo":
			C.extraDraw += 1
			Eng.add_cards(C, "doubt", 1, "draw")


static func _on_turn_start(id: String, C) -> void:
	match id:
		"linterna":
			if C.turn == 1:
				C.energy += 1
		"flor":
			if C.turn % 3 == 0:
				C.energy += 1
		"vela": C.pl.block += 1
		"resorte_reserva":
			if not Eng.get_s(C.pl, "cuerda"):
				Eng.gain_wind(C, 2)


static func _on_turn_end(id: String, C) -> void:
	match id:
		"orichalcum":
			if C.pl.block == 0:
				C.pl.block += 6
		"corazon_laton":
			var n := mini(2, Eng.get_s(C.pl, "cuerda"))
			if n:
				Eng.add_status(C, C.pl, "cuerda", -n)


static func use_potion(id: String, C, t) -> void:
	match id:
		"fuego": Eng.deal_to_enemy(C, t, 20, {"noReflect": true})
		"escudo":
			C.pl.block += 12
			Eng._fx(C, "block", {"n": 12})
		"fuerza": Eng.add_status(C, C.pl, "strength", 2)
		"energia": C.energy += 2
		"curacion":
			var n := ceili(C.G.maxHp * 0.25)
			C.G.hp = mini(C.G.maxHp, C.G.hp + n)
			Eng._fx(C, "heal", {"n": n})
		"veneno": Eng.add_status(C, t, "poison", 8)
		"niebla":
			Eng.add_status(C, t, "weak", 3)
			Eng.add_status(C, t, "vulnerable", 3)
		"rapidez": Eng.draw_cards(C, 3)
