extends Node3D

var board_view: BoardView
var dice: Dice
var hud: Hud
var _rig: CameraRig
var _busy := false

func _ready() -> void:
	_setup_world()
	var autoplay := OS.get_environment("BUGOPOLY_AUTOPLAY") == "1"
	var configs: Array = GameState.pending_configs
	if configs.is_empty():
		configs = [
			{"name": "Tú", "is_bot": false, "color": Color(0.30, 0.69, 1.0), "piece": "bugopoly:cyclops"},
			{"name": "Bot Tester", "is_bot": true, "color": Color(0.91, 0.45, 0.45), "piece": "bugopoly:ghost"},
		]
	if autoplay:
		for c in configs:
			c["is_bot"] = true
	GameState.setup(configs, "bugopoly:main")

	board_view = BoardView.new()
	add_child(board_view)
	board_view.build(GameState)

	var decor := Decor.new()
	add_child(decor)
	decor.build(board_view.board_half())

	dice = Dice.new()
	dice.position = Vector3(0, 0.4, 5.0)
	add_child(dice)

	hud = Hud.new()
	add_child(hud)
	hud.setup(GameState)
	hud.debug = autoplay
	hud.roll_pressed.connect(_on_roll_pressed)
	hud.ability_used.connect(_on_ability)

	hud.log_line("[b]Bugopoly[/b] — empieza la partida.")
	_begin_turn()

func _setup_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Cielo en gradiente cálido oscuro (en vez de fondo plano) + ambiente del cielo.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.05, 0.05, 0.08)
	sky_mat.sky_horizon_color = Color(0.17, 0.13, 0.12)
	sky_mat.ground_bottom_color = Color(0.04, 0.04, 0.06)
	sky_mat.ground_horizon_color = Color(0.17, 0.13, 0.12)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.35
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.5
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.10
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -40, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.light_angular_distance = 1.2
	light.shadow_blur = 1.4
	add_child(light)

	# Relleno frío suave (da volumen sin aplanar las sombras).
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 135, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.72, 0.82, 1.0)
	add_child(fill)

	# Contraluz cálido (recorta las siluetas de las piezas).
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-14, 205, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.84, 0.58)
	add_child(rim)

	GfxSettings.env = env
	GfxSettings.light = light
	GfxSettings.apply()

	_rig = CameraRig.new()
	add_child(_rig)
	_add_vignette()

func _add_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 8
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	cl.add_child(tr)
	add_child(cl)

func _begin_turn() -> void:
	var p := GameState.current_player()
	hud.set_turn(p)
	hud.refresh()
	board_view.set_active(p)
	if p.debt > 0:
		var interest := maxi(5, int(round(p.debt * 0.12)))
		p.budget -= interest
		board_view.flash(board_view.token_pos(p), Color(0.92, 0.30, 0.22))
		hud.log_line("%s paga $%d de interés de deuda técnica (deuda $%d)." % [p.pname, interest, p.debt])
		hud.refresh()
		if p.budget < 0 and not p.bankrupt:
			p.bankrupt = true
			hud.log_line("[color=red]%s quiebra por la deuda técnica y queda fuera.[/color]" % p.pname)
			if GameState.active_players() <= 1:
				_game_over()
				return
			GameState.advance_turn()
			_begin_turn()
			return
	if p.jailed > 0:
		p.jailed -= 1
		hud.log_line("%s está bloqueado, pierde el turno. ⛔" % p.pname)
		await _wait(1.2)
		GameState.advance_turn()
		_begin_turn()
		return
	if p.is_bot:
		_take_turn(p)

func _game_over() -> void:
	var w := GameState.winner()
	hud.log_line("[b]%s gana la partida! 🏆[/b]" % w.pname)
	AudioManager.play("win")
	AudioManager.voice("v_mission_completed")
	hud.enable_roll(false)
	hud.show_gameover(GameState)

func _ability_name(a: String) -> String:
	match a:
		"hotfix": return "Hotfix"
		"rollback": return "Rollback"
		"feature_flag": return "Feature Flag"
	return a

func _on_ability(name: String) -> void:
	_apply_ability(GameState.current_player(), name)

func _apply_ability(p, name: String) -> void:
	if not name in p.abilities:
		return
	var consumed := true
	match name:
		"hotfix":
			if p.debt > 0:
				hud.log_line("%s aplica un Hotfix: limpia $%d de deuda técnica." % [p.pname, p.debt])
				board_view.flash(board_view.token_pos(p), Color(0.30, 0.72, 0.40))
				p.debt = 0
			else:
				consumed = false
		"rollback":
			if p.last_expense > 0:
				p.budget += p.last_expense
				hud.log_line("%s hace un Rollback y recupera $%d." % [p.pname, p.last_expense])
				board_view.flash(board_view.token_pos(p), Color(0.30, 0.72, 0.40))
				p.last_expense = 0
			else:
				consumed = false
		"feature_flag":
			p.flag_active = true
			hud.log_line("%s arma un Feature Flag: su próxima renta es gratis." % p.pname)
	if consumed:
		p.abilities.erase(name)
	hud.refresh()
	if p == GameState.current_player():
		hud.refresh_abilities(p)

func _bot_abilities(p) -> void:
	if "hotfix" in p.abilities and p.debt > 200:
		_apply_ability(p, "hotfix")
	if "rollback" in p.abilities and p.budget < 120 and p.last_expense > 0:
		_apply_ability(p, "rollback")

func _on_roll_pressed() -> void:
	if _busy:
		return
	_take_turn(GameState.current_player())

func _take_turn(p) -> void:
	if _busy:
		return
	_busy = true
	hud.enable_roll(false)
	_rig.overview()
	if p.is_bot:
		_bot_abilities(p)
		await _wait(0.5)

	var d1 := randi() % 6 + 1
	var d2 := randi() % 6 + 1
	hud.show_dice(d1, d2)
	AudioManager.dice()
	await dice.roll([d1, d2])

	for s in d1 + d2:
		p.position = posmod(p.position + 1, GameState.tile_count())
		if p.position == 0:
			p.budget += GameState.go_reward()
			_float(p, GameState.go_reward())
			board_view.flash(board_view.token_pos(p), Color(0.94, 0.77, 0.10))
			AudioManager.coin()
			hud.log_line("%s pasa por Salida (+$%d)" % [p.pname, GameState.go_reward()])
		await board_view.hop_step(p)
	hud.refresh()

	_rig.focus(board_view.token_pos(p))
	await _wait(0.7)
	await _resolve(p, GameState.tile_at(p.position))
	hud.refresh()

	_busy = false
	if GameState.active_players() <= 1:
		_game_over()
		return
	GameState.advance_turn()
	_begin_turn()

func _resolve(p, tile: Dictionary) -> void:
	match str(tile.get("type", "")):
		"go":
			hud.log_line("%s cae en Salida." % p.pname)
		"tax":
			var amt := int(tile.get("amount", 50))
			if bool(tile.get("debt", false)):
				p.debt += amt
				board_view.flash(board_view.token_pos(p), Color(0.92, 0.30, 0.22))
				_rig.shake(0.18)
				hud.log_line("%s suma $%d de deuda técnica (total $%d). Cobra interés cada turno hasta refactorizar." % [p.pname, amt, p.debt])
			else:
				p.budget -= amt
				p.last_expense = amt
				board_view.fly_bills(board_view.token_pos(p), Vector3(0, 1, 0), 2)
				AudioManager.coin()
				_float(p, -amt)
				hud.log_line("%s paga $%d de impuesto." % [p.pname, amt])
		"card":
			await _resolve_card(p, tile)
		"challenge":
			await _resolve_challenge(p, tile)
		"property":
			await _resolve_property(p, tile)
		"incident":
			var bi := GameState.find_tile_type("blocked")
			if bi >= 0:
				p.position = bi
				board_view.place_token(p)
			p.jailed = 1
			hud.log_line("%s: incidente en prod → Bloqueado (pierde el próximo turno). ⛔" % p.pname)
		"coffee":
			if p.debt > 0:
				var pay := mini(maxi(0, p.budget - 100), p.debt)
				if pay > 0:
					p.budget -= pay
					p.debt -= pay
					p.stat_debt_paid += pay
					AudioManager.coin()
					board_view.flash(board_view.token_pos(p), Color(0.30, 0.72, 0.40))
					hud.log_line("%s refactoriza en el coffee break: baja $%d de deuda (queda $%d)." % [p.pname, pay, p.debt])
				else:
					hud.log_line("%s toma un café, pero no le alcanza para refactorizar." % p.pname)
			else:
				hud.log_line("%s descansa en el coffee break." % p.pname)
		"blocked":
			hud.log_line("%s descansa en %s." % [p.pname, str(tile.get("name", ""))])
	if p.budget < 0 and not p.bankrupt:
		p.bankrupt = true
		hud.log_line("[color=red]%s quiebra y queda fuera.[/color]" % p.pname)

func _resolve_property(p, tile: Dictionary) -> void:
	var idx: int = p.position
	var owner := GameState.owner_of(idx)
	var price := int(tile.get("price", 0))
	var tname := str(tile.get("name", "Propiedad"))
	if owner == -1:
		var buy := false
		if p.is_bot:
			await _wait(0.5)
			buy = p.budget >= price + 200
		else:
			hud.show_property(tile, p.budget >= price)
			buy = await hud.property_decision
		if buy and p.budget >= price:
			p.budget -= price
			p.last_expense = price
			GameState.ownership[idx] = p.id
			p.owned.append(idx)
			p.stat_props += 1
			board_view.mark_owner(idx, p.color)
			board_view.fly_bills(board_view.token_pos(p), board_view.tile_world(idx), 4)
			board_view.burst_confetti(board_view.tile_world(idx), p.color)
			_rig.shake(0.16)
			AudioManager.play("buy")
			_float(p, -price)
			hud.log_line("%s compra %s (-$%d)." % [p.pname, tname, price])
	elif owner == p.id:
		var h := GameState.house_count(idx)
		if h < 5:
			var cost := int(price * 0.5)
			var build := false
			if p.is_bot:
				await _wait(0.4)
				build = p.budget >= cost + 400 and randf() < 0.75
			else:
				hud.show_build(tile, h, cost, p.budget >= cost)
				build = await hud.build_decision
			if build and p.budget >= cost:
				p.budget -= cost
				p.last_expense = cost
				GameState.houses[idx] = h + 1
				p.stat_builds += 1
				board_view.set_houses(idx, h + 1, p.color)
				board_view.fly_bills(board_view.token_pos(p), board_view.tile_world(idx), 3)
				board_view.burst_confetti(board_view.tile_world(idx), Color(0.94, 0.77, 0.10))
				AudioManager.play("build")
				AudioManager.play("deploy", -4.0, 1.0)
				_float(p, -cost)
				var what := "un hotel (CI/CD)" if h + 1 >= 5 else "una casa (cobertura %d)" % (h + 1)
				hud.log_line("%s construye %s en %s (-$%d)." % [p.pname, what, tname, cost])
	else:
		var rent := _rent(tile, idx)
		var o = GameState.players[owner]
		if p.flag_active:
			p.flag_active = false
			board_view.flash(board_view.token_pos(p), Color(0.48, 0.30, 0.72))
			hud.log_line("%s activa un Feature Flag y no paga renta en %s." % [p.pname, tname])
		else:
			p.budget -= rent
			p.last_expense = rent
			o.budget += rent
			p.stat_rent_paid += rent
			o.stat_rent_got += rent
			board_view.fly_bills(board_view.token_pos(p), board_view.token_pos(o), 3)
			board_view.flash(board_view.token_pos(o), Color(0.94, 0.77, 0.10))
			AudioManager.coin()
			_float(p, -rent)
			_float(o, rent)
			hud.log_line("%s paga $%d de renta a %s por %s." % [p.pname, rent, o.pname, tname])

func _rent(tile: Dictionary, idx: int) -> int:
	var base := int(tile.get("rent", int(int(tile.get("price", 0)) * 0.1)))
	var mult := [1.0, 2.0, 3.0, 4.5, 6.0, 9.0]
	return int(base * mult[clampi(GameState.house_count(idx), 0, 5)])

func _resolve_card(p, tile: Dictionary) -> void:
	var deck := Registry.get_def("card", str(tile.get("deck", "")))
	var entries: Array = deck.get("entries", [])
	if entries.is_empty():
		return
	var e: Dictionary = entries[randi() % entries.size()]
	var money := int(e.get("money", 0))
	board_view.draw_card(str(deck.get("kind", "bug")), str(e.get("text", "")))
	AudioManager.play("card")
	await _wait(1.0)
	p.budget += money
	_float(p, money)
	hud.log_line("%s — %s (%s$%d)" % [p.pname, str(e.get("text", "")), "+" if money >= 0 else "-", abs(money)])
	await _wait(1.8)

func _resolve_challenge(p, tile: Dictionary) -> void:
	var pool := Registry.tag("challenge", "bugopoly:pool")
	if pool.is_empty():
		pool = Registry.ids("challenge")
	if pool.is_empty():
		return
	var ch := Registry.get_def("challenge", str(pool[randi() % pool.size()]))
	var chosen := -1
	if p.is_bot:
		await _wait(0.7)
		chosen = randi() % int(ch.get("options", []).size())
	else:
		hud.show_challenge(ch)
		chosen = await hud.challenge_answer
	var correct := chosen == int(ch.get("answer", -1))
	if correct:
		p.budget += int(ch.get("reward", 0))
		p.stat_challenges += 1
		_float(p, int(ch.get("reward", 0)))
		if randf() < 0.5:
			var keys := ["hotfix", "rollback", "feature_flag"]
			var ab: String = keys[randi() % keys.size()]
			p.abilities.append(ab)
			hud.log_line("%s gana una carta de habilidad: %s." % [p.pname, _ability_name(ab)])
	else:
		p.budget -= int(ch.get("penalty", 0))
		_float(p, -int(ch.get("penalty", 0)))
	if correct:
		AudioManager.play("blip", -4.0, 1.0)
		AudioManager.voice("v_correct")
	else:
		AudioManager.play("zap", -6.0, 0.8)
		AudioManager.voice("v_wrong")
	var verdict := "✓ Correcto" if correct else "✗ Incorrecto"
	hud.log_line("%s, reto QA: %s. [i]%s[/i]" % [p.pname, verdict, str(ch.get("explain", ""))])
	await _wait(0.5)

func _float(p, amount: int) -> void:
	if amount == 0:
		return
	var col := Color(0.45, 0.92, 0.5) if amount > 0 else Color(0.97, 0.42, 0.42)
	var txt := ("+$%d" % amount) if amount > 0 else ("-$%d" % -amount)
	board_view.popup_text(board_view.token_pos(p), txt, col)

func _wait(secs: float) -> void:
	# process_always = false → el timer se detiene cuando el árbol está en pausa.
	await get_tree().create_timer(secs, false).timeout
