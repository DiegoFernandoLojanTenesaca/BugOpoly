extends Node
## Configuración de gráficos: guarda los valores y los aplica en vivo.
## Autoload (GfxSettings). El panel de UI lo construye build_panel().

const Brand = preload("res://src/ui/palette.gd")

const CFG := "user://settings.cfg"

var aa := 1            # 0 off · 1 FXAA · 2 MSAA 2x · 3 MSAA 4x
var render_scale := 1.0
var shadows := true
var glow := true
var fullscreen := false
var vsync := true

# Referencias de la escena de juego (las setea main.gd) para sombras/glow en vivo.
var env: Environment = null
var light: DirectionalLight3D = null

func _ready() -> void:
	_load()
	call_deferred("apply")

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) != OK:
		return
	aa = c.get_value("gfx", "aa", aa)
	render_scale = c.get_value("gfx", "render_scale", render_scale)
	shadows = c.get_value("gfx", "shadows", shadows)
	glow = c.get_value("gfx", "glow", glow)
	fullscreen = c.get_value("gfx", "fullscreen", fullscreen)
	vsync = c.get_value("gfx", "vsync", vsync)

func _save() -> void:
	var c := ConfigFile.new()
	c.load(CFG)  # preserva la sección [audio]
	c.set_value("gfx", "aa", aa)
	c.set_value("gfx", "render_scale", render_scale)
	c.set_value("gfx", "shadows", shadows)
	c.set_value("gfx", "glow", glow)
	c.set_value("gfx", "fullscreen", fullscreen)
	c.set_value("gfx", "vsync", vsync)
	c.save(CFG)

func apply() -> void:
	var vp := get_viewport()
	match aa:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		1:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		3:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = render_scale
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if light != null and is_instance_valid(light):
		light.shadow_enabled = shadows
	if env != null and is_instance_valid(env):
		env.glow_enabled = glow
	_save()

# ---------- setters (conectados a la UI) ----------

func _set_aa(i: int) -> void:
	aa = i
	apply()

func _set_scale(i: int) -> void:
	render_scale = [0.5, 0.75, 1.0][i]
	apply()

func _set_shadows(on: bool) -> void:
	shadows = on
	apply()

func _set_glow(on: bool) -> void:
	glow = on
	apply()

func _set_fs(on: bool) -> void:
	fullscreen = on
	apply()

func _set_vsync(on: bool) -> void:
	vsync = on
	apply()

func _scale_idx() -> int:
	if render_scale <= 0.55:
		return 0
	elif render_scale <= 0.8:
		return 1
	return 2

# ---------- panel de UI reusable ----------

func build_panel() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(_row_option("Antialiasing", ["Desactivado", "FXAA", "MSAA 2x", "MSAA 4x"], aa, _set_aa))
	vb.add_child(_row_option("Escala de render", ["50%", "75%", "100%"], _scale_idx(), _set_scale))
	vb.add_child(_row_check("Sombras", shadows, _set_shadows))
	vb.add_child(_row_check("Brillo (glow)", glow, _set_glow))
	vb.add_child(_row_check("Pantalla completa", fullscreen, _set_fs))
	vb.add_child(_row_check("VSync", vsync, _set_vsync))
	return vb

func _row_option(label: String, options: Array, selected: int, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	l.add_theme_color_override("font_color", Brand.TEXT_BODY)
	h.add_child(l)
	var o := OptionButton.new()
	for opt in options:
		o.add_item(str(opt))
	o.select(selected)
	o.custom_minimum_size = Vector2(170, 0)
	o.item_selected.connect(cb)
	h.add_child(o)
	return h

func _row_check(label: String, value: bool, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	l.add_theme_color_override("font_color", Brand.TEXT_BODY)
	h.add_child(l)
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(cb)
	h.add_child(c)
	return h
