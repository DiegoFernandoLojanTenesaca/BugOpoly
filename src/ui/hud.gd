class_name Hud
extends CanvasLayer

const Brand = preload("res://src/ui/palette.gd")

signal roll_pressed
signal property_decision(buy)
signal build_decision(build)
signal challenge_answer(index)
signal ability_used(name)

var debug := false
var _state
var _cards_box: HBoxContainer
var _toast: PanelContainer
var _toast_label: RichTextLabel
var _toast_tw: Tween
var _dice_lbl: Label
var _roll_btn: Button
var _popup: PanelContainer
var _popup_box: VBoxContainer
var _abilities_box: HBoxContainer
var _pause_root: Control

func setup(state) -> void:
	_state = state
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue respondiendo (ESC, botones) durante la pausa

	var pause_btn := Button.new()
	pause_btn.text = "Menú"
	pause_btn.position = Vector2(1168, 14)
	pause_btn.size = Vector2(98, 36)
	pause_btn.add_theme_font_size_override("font_size", 15)
	Brand.style_button(pause_btn, Brand.SURFACE_RAISED, Brand.INK_700, Brand.TEXT_STRONG)
	pause_btn.pressed.connect(_toggle_pause)
	add_child(pause_btn)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _pill(Color(0.08, 0.06, 0.05, 0.92)))
	_toast.custom_minimum_size = Vector2(720, 0)
	_toast.position = Vector2(280, 16)
	add_child(_toast)
	_toast_label = RichTextLabel.new()
	_toast_label.bbcode_enabled = true
	_toast_label.fit_content = true
	_toast_label.scroll_active = false
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size = Vector2(680, 0)
	_toast_label.add_theme_font_size_override("normal_font_size", 19)
	_toast.add_child(_toast_label)
	_toast.visible = false

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 14)
	_cards_box.position = Vector2(20, 612)
	add_child(_cards_box)

	_dice_lbl = Label.new()
	_dice_lbl.add_theme_font_size_override("font_size", 22)
	_dice_lbl.add_theme_color_override("font_color", Brand.TEXT_STRONG)
	_dice_lbl.position = Vector2(1010, 596)
	_dice_lbl.size = Vector2(250, 30)
	_dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_dice_lbl)

	_roll_btn = Button.new()
	_roll_btn.text = "TIRAR DADOS"
	_roll_btn.custom_minimum_size = Vector2(250, 64)
	_roll_btn.position = Vector2(1010, 632)
	_roll_btn.add_theme_font_size_override("font_size", 22)
	Brand.style_button(_roll_btn, Brand.RED, Brand.RED_HOVER, Brand.WHITE)
	_roll_btn.pressed.connect(func(): AudioManager.play("click"); roll_pressed.emit())
	add_child(_roll_btn)

	_popup = PanelContainer.new()
	_popup.position = Vector2(370, 150)
	_popup.custom_minimum_size = Vector2(540, 330)
	_popup.add_theme_stylebox_override("panel", _panel_style(Brand.SURFACE_CARD))
	_popup.visible = false
	add_child(_popup)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 18)
	pm.add_theme_constant_override("margin_right", 18)
	pm.add_theme_constant_override("margin_top", 14)
	pm.add_theme_constant_override("margin_bottom", 14)
	_popup.add_child(pm)
	_popup_box = VBoxContainer.new()
	_popup_box.add_theme_constant_override("separation", 10)
	pm.add_child(_popup_box)

	_abilities_box = HBoxContainer.new()
	_abilities_box.add_theme_constant_override("separation", 8)
	_abilities_box.position = Vector2(20, 562)
	add_child(_abilities_box)

	refresh()

func set_turn(p) -> void:
	enable_roll(not p.is_bot)
	refresh()
	refresh_abilities(p)

func refresh_abilities(p) -> void:
	for c in _abilities_box.get_children():
		c.queue_free()
	if p == null:
		return
	for a in p.abilities:
		var an: String = a
		var b := _btn(_ability_label(an), Brand.GROUP[3])
		b.custom_minimum_size = Vector2(0, 38)
		b.disabled = p.is_bot
		b.pressed.connect(func(): ability_used.emit(an))
		_abilities_box.add_child(b)

func _ability_label(a: String) -> String:
	match a:
		"hotfix": return "Hotfix"
		"rollback": return "Rollback"
		"feature_flag": return "Feature Flag"
	return a

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if _pause_root != null:
		_resume()
	else:
		_show_pause()

func _resume() -> void:
	get_tree().paused = false
	if _pause_root != null:
		_pause_root.queue_free()
		_pause_root = null

func _show_pause() -> void:
	get_tree().paused = true
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_pause_root = root
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Brand.SURFACE_CARD))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var t := _title("PAUSA")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(HSeparator.new())

	var audio_l := Label.new()
	audio_l.text = "AUDIO"
	audio_l.add_theme_font_override("font", Brand.font_heavy())
	audio_l.add_theme_font_size_override("font_size", 15)
	audio_l.add_theme_color_override("font_color", Brand.TEXT_MUTED)
	vb.add_child(audio_l)
	vb.add_child(AudioManager.build_volume_panel())
	vb.add_child(HSeparator.new())

	var gfx_l := Label.new()
	gfx_l.text = "GRÁFICOS"
	gfx_l.add_theme_font_override("font", Brand.font_heavy())
	gfx_l.add_theme_font_size_override("font_size", 15)
	gfx_l.add_theme_color_override("font_color", Brand.TEXT_MUTED)
	vb.add_child(gfx_l)
	vb.add_child(GfxSettings.build_panel())
	vb.add_child(HSeparator.new())

	var resume := _btn("REANUDAR", Brand.GROUP[1])
	resume.pressed.connect(_resume)
	vb.add_child(resume)
	var quit := _btn("SALIR AL MENÚ", Brand.RED)
	quit.pressed.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file("res://src/world/start_screen.tscn"))
	vb.add_child(quit)

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)

func enable_roll(on: bool) -> void:
	_roll_btn.disabled = not on
	_roll_btn.visible = on

func show_dice(d1: int, d2: int) -> void:
	_dice_lbl.text = "Dados:  %d + %d = %d" % [d1, d2, d1 + d2]

func log_line(text: String) -> void:
	if debug:
		print(text)
	_toast_label.text = "[center]" + text + "[/center]"
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.8)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

func refresh() -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	for p in _state.players:
		_cards_box.add_child(_make_card(p))

func _make_card(p) -> Control:
	var active: bool = p == _state.current_player()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(196, 84)
	var bg := Brand.SURFACE_RAISED if active else Brand.SURFACE_CARD
	var sb := _panel_style(bg)
	sb.border_color = p.color if active else Brand.BORDER_SOFT
	sb.set_border_width_all(3 if active else 1)
	if active:
		sb.border_width_top = 5
		sb.border_color = p.color
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(16, 16)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = p.color
	dsb.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", dsb)
	head.add_child(dot)
	var name_l := Label.new()
	name_l.text = str(p.pname)
	name_l.add_theme_font_override("font", Brand.font_heavy())
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", Brand.TEXT_STRONG if active else Brand.TEXT_BODY)
	head.add_child(name_l)
	var money := Label.new()
	money.text = "$%d%s" % [p.budget, "  QUIEBRA" if p.bankrupt else ""]
	money.add_theme_font_override("font", Brand.font_heavy())
	money.add_theme_font_size_override("font_size", 24)
	money.add_theme_color_override("font_color", Brand.GOLD if active else Brand.TEXT_BODY)
	vb.add_child(money)
	if p.debt > 0:
		var dl := Label.new()
		dl.text = "deuda técnica  $%d" % p.debt
		dl.add_theme_font_override("font", Brand.font_heavy())
		dl.add_theme_font_size_override("font_size", 12)
		dl.add_theme_color_override("font_color", Brand.GROUP[4])
		vb.add_child(dl)
	return card

func show_property(tile: Dictionary, can_afford: bool) -> void:
	_clear_popup()
	var sub := Registry.get_def("subsystem", str(tile.get("subsystem", "")))
	var col := Color.html(str(sub.get("color", "#888888")))
	var price := int(tile.get("price", 0))
	var base := int(tile.get("rent", int(price * 0.1)))

	# ---- Escritura / title deed estilo juego de mesa ----
	var deed := VBoxContainer.new()
	deed.add_theme_constant_override("separation", 0)
	deed.custom_minimum_size = Vector2(440, 0)

	var band := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = col
	bsb.corner_radius_top_left = 14
	bsb.corner_radius_top_right = 14
	bsb.content_margin_left = 18
	bsb.content_margin_right = 18
	bsb.content_margin_top = 14
	bsb.content_margin_bottom = 14
	band.add_theme_stylebox_override("panel", bsb)
	var bandv := VBoxContainer.new()
	bandv.add_theme_constant_override("separation", 1)
	var kicker := Label.new()
	kicker.text = "MÓDULO · %s" % str(sub.get("name", "")).to_upper()
	kicker.add_theme_font_override("font", Brand.font_heavy())
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandv.add_child(kicker)
	var nm := Label.new()
	nm.text = str(tile.get("name", "Propiedad")).to_upper()
	nm.add_theme_font_override("font", Brand.font_heavy())
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", Brand.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandv.add_child(nm)
	band.add_child(bandv)
	deed.add_child(band)

	var body := PanelContainer.new()
	var ysb := StyleBoxFlat.new()
	ysb.bg_color = Brand.CREAM
	ysb.corner_radius_bottom_left = 14
	ysb.corner_radius_bottom_right = 14
	ysb.content_margin_left = 22
	ysb.content_margin_right = 22
	ysb.content_margin_top = 14
	ysb.content_margin_bottom = 16
	body.add_theme_stylebox_override("panel", ysb)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 5)
	bv.add_child(_deed_row("RENTA", "$%d" % base, true))
	var mult := [2.0, 3.0, 4.5, 6.0]
	for i in 4:
		bv.add_child(_deed_row("con cobertura %d" % (i + 1), "$%d" % int(base * mult[i]), false))
	bv.add_child(_deed_row("con CI/CD (release)", "$%d" % int(base * 9.0), false))
	var sep := HSeparator.new()
	bv.add_child(sep)
	bv.add_child(_deed_row("Mejora de cobertura", "$%d c/u" % int(price * 0.5), false))
	body.add_child(bv)
	deed.add_child(body)
	_popup_box.add_child(deed)

	var price_l := Label.new()
	price_l.text = "PRECIO   $%d" % price
	price_l.add_theme_font_override("font", Brand.font_heavy())
	price_l.add_theme_font_size_override("font_size", 22)
	price_l.add_theme_color_override("font_color", Brand.GOLD)
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_box.add_child(price_l)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_box.add_child(row)
	var buy := _btn("COMPRAR" if can_afford else "SIN FONDOS", Brand.GROUP[1])
	buy.disabled = not can_afford
	buy.pressed.connect(func(): _popup.visible = false; property_decision.emit(true))
	row.add_child(buy)
	var skip := _btn("PASAR", Brand.SURFACE_RAISED)
	skip.pressed.connect(func(): _popup.visible = false; property_decision.emit(false))
	row.add_child(skip)
	_popup.visible = true

func _deed_row(label: String, value: String, strong: bool) -> HBoxContainer:
	var ink := Brand.INK_700 if strong else Color(0.32, 0.27, 0.18)
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", ink)
	l.add_theme_font_size_override("font_size", 17 if strong else 15)
	if strong:
		l.add_theme_font_override("font", Brand.font_heavy())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", Brand.font_heavy())
	v.add_theme_font_size_override("font_size", 17 if strong else 15)
	v.add_theme_color_override("font_color", ink)
	h.add_child(v)
	return h

func show_build(tile: Dictionary, houses: int, cost: int, can_afford: bool) -> void:
	_clear_popup()
	var what := "Hotel (CI/CD)" if houses + 1 >= 5 else "Casa #%d (cobertura)" % (houses + 1)
	_popup_box.add_child(_title("Construir " + what))
	var info := Label.new()
	info.text = "%s — Costo: $%d   (sube la renta)" % [str(tile.get("name", "")), cost]
	info.add_theme_font_size_override("font_size", 18)
	_popup_box.add_child(info)
	_popup_box.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_popup_box.add_child(row)
	var b := _btn("Construir" if can_afford else "Sin fondos", Color(0.20, 0.55, 0.30))
	b.disabled = not can_afford
	b.pressed.connect(func(): _popup.visible = false; build_decision.emit(true))
	row.add_child(b)
	var s := _btn("Ahora no", Color(0.40, 0.42, 0.48))
	s.pressed.connect(func(): _popup.visible = false; build_decision.emit(false))
	row.add_child(s)
	_popup.visible = true

func show_challenge(ch: Dictionary) -> void:
	_clear_popup()
	_popup_box.add_child(_title("Reto QA"))
	var topic := str(ch.get("topic", ""))
	if topic != "":
		_popup_box.add_child(_subtitle(topic))
	var prompt := Label.new()
	prompt.text = str(ch.get("prompt", ""))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(500, 0)
	prompt.add_theme_font_size_override("font_size", 17)
	_popup_box.add_child(prompt)
	var opts: Array = ch.get("options", [])
	for i in opts.size():
		var b := _btn("%d)  %s" % [i + 1, str(opts[i])], Color(0.22, 0.34, 0.5))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(500, 40)
		b.pressed.connect(func(): _popup.visible = false; challenge_answer.emit(i))
		_popup_box.add_child(b)
	_popup.visible = true

func show_gameover(state) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.03, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Brand.SURFACE_CARD))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var kicker := Label.new()
	kicker.text = "FIN DE LA PARTIDA"
	kicker.add_theme_font_override("font", Brand.font_heavy())
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.add_theme_color_override("font_color", Brand.TEXT_MUTED)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(kicker)

	var w = state.winner()
	var win_l := Label.new()
	win_l.text = "%s\nSHIPEÓ EL RELEASE" % str(w.pname).to_upper()
	win_l.add_theme_font_override("font", Brand.font_display())
	win_l.add_theme_font_size_override("font_size", 26)
	win_l.add_theme_color_override("font_color", Brand.GOLD)
	win_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_l.custom_minimum_size = Vector2(620, 0)
	vb.add_child(win_l)

	vb.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for h in ["Jugador", "Dinero", "Módulos", "Cobertura", "Retos"]:
		grid.add_child(_gcell(h, true, Brand.TEXT_STRONG))
	for p in state.players:
		grid.add_child(_gcell(str(p.pname) + ("  (quiebra)" if p.bankrupt else ""), false, p.color))
		grid.add_child(_gcell("$%d" % p.budget, false, Brand.GOLD))
		grid.add_child(_gcell(str(p.stat_props), false, Brand.TEXT_BODY))
		grid.add_child(_gcell(str(p.stat_builds), false, Brand.TEXT_BODY))
		grid.add_child(_gcell(str(p.stat_challenges), false, Brand.TEXT_BODY))
	vb.add_child(grid)

	vb.add_child(HSeparator.new())

	for badge in [
		["Imperio (más módulos)", "stat_props"],
		["Casero (más renta cobrada)", "stat_rent_got"],
		["Cazabugs (más retos QA)", "stat_challenges"],
		["Refactor (más deuda saldada)", "stat_debt_paid"],
	]:
		var bl := Label.new()
		bl.text = "%s:  %s" % [badge[0], _top(state.players, badge[1])]
		bl.add_theme_font_size_override("font_size", 14)
		bl.add_theme_color_override("font_color", Brand.TEXT_BODY)
		vb.add_child(bl)

	var back := _btn("VOLVER AL MENÚ", Brand.RED)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://src/world/start_screen.tscn"))
	vb.add_child(back)

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.45)

func _gcell(text: String, strong: bool, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	if strong:
		l.add_theme_font_override("font", Brand.font_heavy())
	l.add_theme_font_size_override("font_size", 16 if strong else 15)
	l.add_theme_color_override("font_color", col)
	return l

func _top(players: Array, field: String) -> String:
	var best = null
	var bestv := -1
	for p in players:
		var v: int = p.get(field)
		if v > bestv:
			bestv = v
			best = p
	return "%s (%d)" % [str(best.pname), bestv] if best != null and bestv > 0 else "—"

func _clear_popup() -> void:
	for c in _popup_box.get_children():
		c.queue_free()

func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Brand.font_heavy())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Brand.TEXT_STRONG)
	return l

func _subtitle(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	l.add_theme_font_size_override("font_size", 15)
	return l

func _btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 46)
	b.add_theme_font_size_override("font_size", 17)
	Brand.style_button(b, color, color.darkened(0.32))
	b.pressed.connect(func(): AudioManager.play("click"))
	return b

func _panel_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	sb.border_color = Brand.BORDER_SOFT
	sb.set_border_width_all(1)
	return sb

func _pill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _btn_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
