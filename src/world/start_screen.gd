extends Control
## Pantalla de inicio BUGOPOLY. Estilo de marca via Brand (src/ui/palette.gd).

const Brand = preload("res://src/ui/palette.gd")

const PIECES := [["Cíclope", "bugopoly:cyclops"], ["Fantasma", "bugopoly:ghost"], ["Demonio", "bugopoly:demon"], ["Demonio Verde", "bugopoly:greendemon"], ["Cthulhu", "bugopoly:cthulhu"], ["Dragón", "bugopoly:yellowdragon"], ["Yeti", "bugopoly:yeti"], ["Calavera", "bugopoly:skull"], ["Murciélago", "bugopoly:bat"], ["Abeja", "bugopoly:bee"], ["Cangrejo", "bugopoly:crab"], ["Alien", "bugopoly:alien"], ["Alien Alto", "bugopoly:alien_tall"], ["Hongo", "bugopoly:mushroom"], ["Cactus", "bugopoly:cactus"], ["Árbol", "bugopoly:tree"], ["Panda", "bugopoly:panda"], ["Cerdo", "bugopoly:pig"], ["Ciervo", "bugopoly:deer"], ["Pollo", "bugopoly:chicken"], ["Pingüino", "bugopoly:penguin"]]
const NAMES := ["Tú", "Bot Tester", "Jugador 3", "Jugador 4"]

var _rows: Array = []
var _list: VBoxContainer
var _add_btn: Button
var _title: Label
var _title_parts: Array = []
var _sub: Label
var _menu: VBoxContainer
var _players_overlay: Control = null
var _scene_t := 0.0
var _badge_clicks := 0
var _badge_timer: Timer
var _scene_mons: Array = []     # monstruos que giran en el tablero de fondo
var _scene_runners: Array = []  # personajes corriendo de lado a lado

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_window_icon()
	_build_background()
	_build_scene()
	_build_vignette()
	_build_title()
	_build_main_menu()
	_build_props()
	_build_creator_badge()
	_animate_in()

func _apply_window_icon() -> void:
	# Icono del kit (cíclope) en la ventana, rasterizado en runtime.
	var path := "res://assets/bugopoly/icon.svg"
	if not FileAccess.file_exists(path):
		return
	var svg := FileAccess.get_file_as_string(path)
	var img := Image.new()
	if img.load_svg_from_string(svg, 0.5) == OK:
		DisplayServer.set_icon(img)

func _build_background() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Brand.INK_700, Brand.BLACK_COOL])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.40)
	tex.fill_to = Vector2(1.05, 1.05)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	# gradiente que respira lento
	var gtw := create_tween().set_loops()
	gtw.tween_property(tex, "fill_from", Vector2(0.4, 0.34), 7.0).set_trans(Tween.TRANS_SINE)
	gtw.tween_property(tex, "fill_from", Vector2(0.6, 0.46), 7.0).set_trans(Tween.TRANS_SINE)

const GH_USER := "DiegoFernandoLojanTenesaca"
const AVATAR_URL := "https://avatars.githubusercontent.com/u/59341390?s=160"

func _build_creator_badge() -> void:
	# Guiño al creador: avatar de GitHub (dinámico) + nombre. Click abre el perfil; triple-click = easter egg.
	var badge := PanelContainer.new()
	badge.position = Vector2(1032, 16)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.10, 0.08, 0.07, 0.62)
	bsb.set_corner_radius_all(22)
	bsb.set_content_margin_all(7)
	bsb.border_color = Color(Brand.GOLD.r, Brand.GOLD.g, Brand.GOLD.b, 0.4)
	bsb.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", bsb)
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.gui_input.connect(_on_badge_input)
	add_child(badge)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 9)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(hb)

	var avp := Panel.new()
	avp.custom_minimum_size = Vector2(40, 40)
	avp.clip_contents = true
	var asb := StyleBoxFlat.new()
	asb.bg_color = Brand.GOLD
	asb.set_corner_radius_all(20)
	avp.add_theme_stylebox_override("panel", asb)
	avp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(avp)
	var av := TextureRect.new()
	av.set_anchors_preset(Control.PRESET_FULL_RECT)
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avp.add_child(av)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var k := Label.new()
	k.text = "creado por"
	k.add_theme_font_size_override("font_size", 10)
	k.add_theme_color_override("font_color", Brand.TEXT_MUTED)
	vb.add_child(k)
	var nm := Label.new()
	nm.text = "Fernando Loján"
	nm.add_theme_font_override("font", Brand.font_heavy())
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", Brand.TEXT_STRONG)
	vb.add_child(nm)

	_badge_timer = Timer.new()
	_badge_timer.one_shot = true
	_badge_timer.wait_time = 0.45
	_badge_timer.timeout.connect(_badge_resolve)
	add_child(_badge_timer)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_avatar.bind(av))
	http.call_deferred("request", AVATAR_URL)

func _on_badge_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_badge_clicks += 1
		_badge_timer.start()

func _badge_resolve() -> void:
	if _badge_clicks >= 3:
		_show_egg()
	else:
		OS.shell_open("https://github.com/%s" % GH_USER)
	_badge_clicks = 0

func _on_avatar(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, av: TextureRect) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var img := Image.new()
	if img.load_png_from_buffer(body) != OK and img.load_jpg_from_buffer(body) != OK:
		return
	av.texture = ImageTexture.create_from_image(img)

func _show_egg() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.02, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var l := Label.new()
	l.text = "con amor para BAE"
	l.add_theme_font_override("font", Brand.font_display())
	l.add_theme_font_size_override("font_size", 66)
	l.add_theme_color_override("font_color", Brand.RED)
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color("1c0807"))
	center.add_child(l)
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.6, 0.3)
	tw.parallel().tween_property(root, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.4)
	tw.tween_property(root, "modulate:a", 0.0, 0.7)
	tw.tween_callback(root.queue_free)

func _build_title() -> void:
	_title_parts.clear()
	var base := Vector2(54, 24)
	# extrude 3D: capas rojas oscuras desplazadas detrás del wordmark (a self, no a un holder)
	for layer in [[Vector2(8, 10), Color("2a0a09")], [Vector2(6, 7), Color("3a0e0c")], [Vector2(4, 5), Color("5c1614")], [Vector2(2, 2), Color("7a1f1d")]]:
		var sh := _wordmark(layer[1])
		sh.position = base + layer[0]
		add_child(sh)
		_title_parts.append(sh)
	var main := _wordmark(Brand.RED)
	main.add_theme_constant_override("outline_size", 10)
	main.add_theme_color_override("font_outline_color", Color("1c0807"))
	main.position = base
	add_child(main)
	_title = main
	_title_parts.append(main)

	var sub := Label.new()
	_sub = sub
	sub.text = "Monopoliza el stack antes del deploy"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Brand.TEXT_BODY)
	sub.position = Vector2(62, 134)
	add_child(sub)

	# Sheen: destello blanco que barre el título (arriba-izquierda).
	var sheen := ColorRect.new()
	sheen.color = Color(1, 1, 1, 0.0)
	sheen.size = Vector2(70, 150)
	sheen.position = Vector2(50, 18)
	sheen.rotation_degrees = 16
	sheen.pivot_offset = Vector2(35, 75)
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheen)
	var mv := create_tween().set_loops()
	mv.tween_interval(2.6)
	mv.tween_property(sheen, "position:x", 470, 1.0).from(50).set_trans(Tween.TRANS_SINE)
	var fd := create_tween().set_loops()
	fd.tween_interval(2.6)
	fd.tween_property(sheen, "color:a", 0.16, 0.5).from(0.0)
	fd.tween_property(sheen, "color:a", 0.0, 0.5)

func _wordmark(col: Color) -> Label:
	var l := Label.new()
	l.text = "BUGOPOLY"
	l.add_theme_font_override("font", Brand.font_display())
	l.add_theme_font_size_override("font_size", 84)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _show_players() -> void:
	if _players_overlay != null:
		return
	_rows.clear()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_players_overlay = root
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", Brand.card_box())
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var accent := Panel.new()
	accent.custom_minimum_size = Vector2(6, 22)
	var ab := StyleBoxFlat.new()
	ab.bg_color = Brand.GOLD
	ab.set_corner_radius_all(3)
	accent.add_theme_stylebox_override("panel", ab)
	head.add_child(accent)
	var lbl := Label.new()
	lbl.text = "JUGADORES"
	lbl.add_theme_font_override("font", Brand.font_heavy())
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Brand.TEXT_STRONG)
	head.add_child(lbl)
	vb.add_child(head)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	vb.add_child(_list)

	_add_btn = Button.new()
	_add_btn.text = "+  Agregar jugador"
	_add_btn.add_theme_font_size_override("font_size", 17)
	Brand.style_button(_add_btn, Brand.SURFACE_RAISED, Brand.INK_700, Brand.TEXT_STRONG)
	_add_btn.pressed.connect(_on_add)
	vb.add_child(_add_btn)

	vb.add_child(HSeparator.new())
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 14)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btns)
	var back := Button.new()
	back.text = "VOLVER"
	back.add_theme_font_size_override("font_size", 18)
	Brand.style_button(back, Brand.SURFACE_RAISED, Brand.INK_700, Brand.TEXT_STRONG)
	back.pressed.connect(_close_players)
	btns.add_child(back)
	var start := Button.new()
	start.text = "EMPEZAR"
	start.add_theme_font_size_override("font_size", 20)
	Brand.style_button(start, Brand.RED, Brand.RED_HOVER, Brand.WHITE)
	start.pressed.connect(_on_play)
	btns.add_child(start)

	_add_row(false, 0)
	_add_row(true, 1)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)

func _close_players() -> void:
	if _players_overlay != null:
		_players_overlay.queue_free()
		_players_overlay = null

func _show_help() -> void:
	_show_info("CÓMO JUGAR", "•  Tirá los dados y avanzá por el tablero.\n•  Comprá módulos de software (propiedades) y cobrá renta a quien caiga ahí.\n•  Construí cobertura de tests → CI/CD para subir la renta (los edificios crecen).\n•  Cuidado con la Deuda Técnica: acumula interés cada turno; refactorizá en el Coffee Break.\n•  Acertá los Retos QA para ganar cartas: Hotfix (limpia deuda), Rollback (recupera tu último gasto), Feature Flag (próxima renta gratis).\n•  El último jugador en pie shipea el release y gana.")

func _show_credits() -> void:
	_show_info("CRÉDITOS", "BUGOPOLY — juego de mesa digital de QA y programación.\n\nCreado por Fernando Loján.\nHecho con Godot Engine 4.6.\n\nAssets (todos libres / CC0):\n• Monstruos y personajes — Quaternius\n• Edificios y props — Kenney\n• Texturas de madera — Poly Haven (CC0)\n• Música de menú — OpenGameArt (CC0)\n• Sonidos y voces — Kenney (CC0)\n• Fuentes — Bungee y Archivo Black (Google Fonts, OFL)")

func _show_info(title_text: String, body: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.03, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", Brand.card_box())
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_override("font", Brand.font_heavy())
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Brand.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(HSeparator.new())
	var b := Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Brand.TEXT_BODY)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(560, 0)
	vb.add_child(b)
	vb.add_child(HSeparator.new())
	var close := Button.new()
	close.text = "CERRAR"
	close.add_theme_font_size_override("font_size", 18)
	Brand.style_button(close, Brand.RED, Brand.RED_HOVER, Brand.WHITE)
	close.pressed.connect(root.queue_free)
	vb.add_child(close)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.2)

func _build_main_menu() -> void:
	# Menú minimalista abajo-izquierda (estilo ARCO/ALONE).
	var menu := VBoxContainer.new()
	_menu = menu
	menu.position = Vector2(60, 432)
	menu.add_theme_constant_override("separation", 4)
	add_child(menu)
	menu.add_child(_menu_item("JUGAR", _show_players, Brand.RED, 40))
	menu.add_child(_menu_item("OPCIONES", _show_options, Brand.TEXT_BODY, 28))
	menu.add_child(_menu_item("AYUDA", _show_help, Brand.TEXT_BODY, 28))
	menu.add_child(_menu_item("CRÉDITOS", _show_credits, Brand.TEXT_BODY, 28))
	menu.add_child(_menu_item("SALIR", get_tree().quit, Brand.TEXT_MUTED, 28))

func _menu_item(text: String, cb: Callable, col: Color, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", Brand.font_heavy())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Brand.GOLD)
	b.add_theme_color_override("font_pressed_color", Brand.GOLD_HI)
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", empty)
	b.add_theme_stylebox_override("pressed", empty)
	b.add_theme_stylebox_override("focus", empty)
	b.pressed.connect(cb)
	return b

func _show_options() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.03, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	panel.add_theme_stylebox_override("panel", Brand.card_box())
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var t := Label.new()
	t.text = "OPCIONES"
	t.add_theme_font_override("font", Brand.font_heavy())
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Brand.TEXT_STRONG)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(HSeparator.new())
	var al := Label.new()
	al.text = "AUDIO"
	al.add_theme_font_override("font", Brand.font_heavy())
	al.add_theme_font_size_override("font_size", 14)
	al.add_theme_color_override("font_color", Brand.TEXT_MUTED)
	vb.add_child(al)
	vb.add_child(AudioManager.build_volume_panel())
	vb.add_child(HSeparator.new())
	var gl := Label.new()
	gl.text = "GRÁFICOS"
	gl.add_theme_font_override("font", Brand.font_heavy())
	gl.add_theme_font_size_override("font_size", 14)
	gl.add_theme_color_override("font_color", Brand.TEXT_MUTED)
	vb.add_child(gl)
	vb.add_child(GfxSettings.build_panel())
	vb.add_child(HSeparator.new())
	var close := Button.new()
	close.text = "CERRAR"
	close.add_theme_font_size_override("font_size", 18)
	Brand.style_button(close, Brand.RED, Brand.RED_HOVER, Brand.WHITE)
	close.pressed.connect(root.queue_free)
	vb.add_child(close)

# ---------- cinemática / animaciones ----------

func _build_scene() -> void:
	# Fondo 3D: tablero con monstruos girando + persecución, en un viewport transparente.
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)

	var cam := Camera3D.new()
	cam.fov = 40
	cam.transform = Transform3D(Basis(), Vector3(0, 5.5, 9.0)).looking_at(Vector3(0, 0.4, 0), Vector3.UP)
	vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_energy = 1.1
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-16, 205, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.84, 0.58)
	vp.add_child(rim)

	# plataforma tipo tablero + logo
	var plat := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(7.0, 0.3, 7.0)
	plat.mesh = pm
	plat.position = Vector3(0, -0.15, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Brand.CREAM
	pmat.roughness = 0.9
	plat.material_override = pmat
	vp.add_child(plat)

	# centro oscuro + logo en la plataforma (que no quede blanca/plana)
	var pcenter := MeshInstance3D.new()
	var pcm := BoxMesh.new()
	pcm.size = Vector3(6.0, 0.04, 5.6)
	pcenter.mesh = pcm
	pcenter.position = Vector3(0, 0.01, 0)
	var pcmat := StandardMaterial3D.new()
	pcmat.albedo_color = Color("17120d")
	pcmat.roughness = 0.7
	pcenter.material_override = pcmat
	vp.add_child(pcenter)
	# monstruos bailando, mirando a la cámara (+Z al frente)
	var bv := BoardView.new()
	# dos filas que llenan el tablero; corridas a la izquierda para no taparse con las cartas (derecha)
	var mons := [
		["cyclops", -2.6, -1.7], ["ghost", -0.9, -1.7], ["demon", 0.7, -1.7], ["skull", 2.3, -1.7],
		["bee", -2.2, 0.9], ["crab", -0.5, 0.9], ["panda", 1.1, 0.9],
	]
	for mi in mons.size():
		var d: Array = mons[mi]
		var pos := Vector3(d[1], 0, d[2])
		var m: Node3D = bv._load_piece_model(d[0], Brand.RED, false, "dance")
		if m != null:
			m.position = pos
			m.rotation.y = atan2(-pos.x, 9.0 - pos.z)  # mira a la cámara
			vp.add_child(m)
			_scene_mons.append({"node": m, "y0": pos.y, "phase": float(mi) * 1.3})
	bv.free()

func _build_props() -> void:
	# Baraja (Bug/Retro) + billete QA Credits como props a la derecha, con balanceo.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var retro := _prop_card("RETRO", Color.html("#2E6FB0"), Brand.WHITE, Color.html("#bcd8f2"), "SACA · APRENDE")
	retro.position = Vector2(900, 350)
	retro.pivot_offset = retro.custom_minimum_size * 0.5
	retro.rotation = deg_to_rad(-8)
	root.add_child(retro)
	_sway(retro, 11.0, 3.4)

	var bug := _prop_card("BUG", Color.html("#E08A1E"), Color.html("#14110E"), Color.html("#5e3708"), "REPORT")
	bug.position = Vector2(1024, 384)
	bug.pivot_offset = bug.custom_minimum_size * 0.5
	bug.rotation = deg_to_rad(7)
	root.add_child(bug)
	_sway(bug, 13.0, 4.1)

	var bill := _prop_bill()
	bill.position = Vector2(902, 566)
	bill.pivot_offset = bill.custom_minimum_size * 0.5
	bill.rotation = deg_to_rad(-3)
	root.add_child(bill)
	_sway(bill, 8.0, 4.7)

	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_property(root, "modulate:a", 1.0, 0.5)

func _prop_card(title: String, base: Color, ink: Color, kicker_col: Color, sub: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(162, 224)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0, 0, 0, 0.42)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var k := Label.new()
	k.text = "BUGOPOLY · MAZO"
	k.add_theme_font_override("font", Brand.font_heavy())
	k.add_theme_font_size_override("font_size", 9)
	k.add_theme_color_override("font_color", kicker_col)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(k)
	var s1 := Control.new()
	s1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(s1)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_override("font", Brand.font_display())
	tl.add_theme_font_size_override("font_size", 44)
	tl.add_theme_color_override("font_color", ink)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var sl := Label.new()
	sl.text = sub
	sl.add_theme_font_override("font", Brand.font_heavy())
	sl.add_theme_font_size_override("font_size", 11)
	sl.add_theme_color_override("font_color", kicker_col)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sl)
	var s2 := Control.new()
	s2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(s2)
	return card

func _prop_bill() -> Control:
	var bill := PanelContainer.new()
	bill.custom_minimum_size = Vector2(236, 108)
	bill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Brand.CREAM
	sb.set_corner_radius_all(10)
	sb.border_color = Brand.GOLD
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(12)
	bill.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bill.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	hb.add_child(left)
	var nm := Label.new()
	nm.text = "BUGOPOLY"
	nm.add_theme_font_override("font", Brand.font_display())
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", Brand.RED)
	left.add_child(nm)
	var val := Label.new()
	val.text = "1000"
	val.add_theme_font_override("font", Brand.font_display())
	val.add_theme_font_size_override("font_size", 36)
	val.add_theme_color_override("font_color", Color.html("#8a6f08"))
	left.add_child(val)
	var cr := Label.new()
	cr.text = "QA CREDITS"
	cr.add_theme_font_override("font", Brand.font_heavy())
	cr.add_theme_font_size_override("font_size", 11)
	cr.add_theme_color_override("font_color", Color.html("#8a6f08"))
	left.add_child(cr)
	var seal := Panel.new()
	seal.custom_minimum_size = Vector2(66, 66)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(Brand.GOLD.r, Brand.GOLD.g, Brand.GOLD.b, 0.26)
	ssb.set_corner_radius_all(33)
	ssb.border_color = Color.html("#8a6f08")
	ssb.set_border_width_all(2)
	seal.add_theme_stylebox_override("panel", ssb)
	var medal := _kit_icon("trophy", Color.html("#8a6f08"), 38)
	medal.set_anchors_preset(Control.PRESET_FULL_RECT)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(medal)
	hb.add_child(seal)
	return bill

func _kit_icon(name: String, col: Color, size: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(size, size)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/bugopoly/icons/%s.svg" % name
	if FileAccess.file_exists(path):
		var svg := FileAccess.get_file_as_string(path).replace("currentColor", "#" + col.to_html(false))
		var img := Image.new()
		if img.load_svg_from_string(svg, float(size) / 24.0 * 2.0) == OK:
			tr.texture = ImageTexture.create_from_image(img)
	return tr

func _sway(c: Control, amp: float, dur: float) -> void:
	var y0 := c.position.y
	var tw := create_tween().set_loops()
	tw.tween_property(c, "position:y", y0 - amp, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position:y", y0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_vignette() -> void:
	# Velo oscuro radial sobre la escena (la UI se lee mejor).
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0.05, 0.04, 0.06, 0.20), Color(0.05, 0.04, 0.06, 0.45), Color(0.03, 0.02, 0.03, 0.86)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.45)
	tex.fill_to = Vector2(1.0, 1.0)
	var v := TextureRect.new()
	v.texture = tex
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)

func _process(delta: float) -> void:
	_scene_t += delta
	for entry in _scene_mons:
		var mm: Node3D = entry["node"]
		mm.position.y = entry["y0"] + sin(_scene_t * 1.6 + entry["phase"]) * 0.12
	for ru in _scene_runners:
		var rn: Node3D = ru["node"]
		var ph: float = _scene_t * 0.7 + ru["phase"]
		rn.position = Vector3(sin(ph) * 5.0, 0.0, -3.6)
		rn.rotation.y = PI * 0.5 if cos(ph) >= 0.0 else -PI * 0.5

func _animate_in() -> void:
	for p in _title_parts:
		p.modulate.a = 0.0
	_sub.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_menu.position.x = 24

	var t := create_tween()
	t.tween_interval(0.15)
	t.tween_property(_title_parts[0], "modulate:a", 1.0, 0.45)
	for i in range(1, _title_parts.size()):
		t.parallel().tween_property(_title_parts[i], "modulate:a", 1.0, 0.45)
	t.parallel().tween_property(_sub, "modulate:a", 1.0, 0.45)
	t.tween_property(_menu, "position:x", 60, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_menu, "modulate:a", 1.0, 0.45)

func _on_add() -> void:
	if _rows.size() < 4:
		_add_row(_rows.size() != 0, _rows.size())

func _add_row(is_bot: bool, idx: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(30, 30)
	swatch.add_theme_stylebox_override("panel", Brand.swatch_box(idx))
	row.add_child(swatch)

	var ne := LineEdit.new()
	ne.text = NAMES[idx]
	ne.custom_minimum_size = Vector2(200, 0)
	Brand.style_line_edit(ne)
	row.add_child(ne)

	var bot := CheckButton.new()
	bot.text = "Bot"
	bot.button_pressed = is_bot
	bot.add_theme_color_override("font_color", Brand.TEXT_BODY)
	row.add_child(bot)

	var po := OptionButton.new()
	for pp in PIECES:
		po.add_item(str(pp[0]))
	po.select(idx % PIECES.size())
	row.add_child(po)

	var rm := Button.new()
	rm.text = "✕"
	Brand.style_button(rm, Brand.SURFACE_RAISED, Brand.INK_700, Brand.RED_TINT)
	rm.custom_minimum_size = Vector2(42, 0)
	rm.pressed.connect(_on_remove.bind(row))
	row.add_child(rm)

	_list.add_child(row)
	_rows.append({"name": ne, "bot": bot, "piece": po, "row": row})
	_add_btn.disabled = _rows.size() >= 4

func _on_remove(row: Node) -> void:
	if _rows.size() <= 2:
		return
	for i in _rows.size():
		if _rows[i]["row"] == row:
			_rows.remove_at(i)
			break
	row.queue_free()
	_add_btn.disabled = _rows.size() >= 4

func _on_play() -> void:
	GameState.pending_configs = []
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var nm: String = r["name"].text
		GameState.pending_configs.append({
			"name": nm if nm != "" else "J%d" % (i + 1),
			"is_bot": r["bot"].button_pressed,
			"color": Brand.GROUP[i % Brand.GROUP.size()],
			"piece": PIECES[r["piece"].selected][1],
		})
	# Transición cinemática: fundido a negro y entra al tablero.
	var fade := ColorRect.new()
	fade.color = Color(0.055, 0.04, 0.035, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func(): get_tree().change_scene_to_file("res://src/world/main.tscn"))
