extends RefCounted
## Paleta y estilos de marca BUGOPOLY.
## Uso: const Brand = preload("res://src/ui/palette.gd")  (preload evita depender
## del registro global de class_name, que no corre headless).
## Valores exactos tomados de "Design System/tokens/colors.css".
## ponytail: una sola fuente de verdad para colores/estilos; la usan menú y HUD.

# ---- Brand core ----
const RED        := Color("b3322f")  # insignia
const RED_HOVER  := Color("93211f")
const RED_TINT   := Color("cb4a45")
const GOLD       := Color("f0c419")  # dinero / brillos
const GOLD_EDGE  := Color("c99f08")
const GOLD_HI    := Color("f8db6b")
const WHITE      := Color("ffffff")
const BLACK_WARM := Color("14110e")  # fondo de app
const BLACK_COOL := Color("0e1014")  # profundidad
const CREAM      := Color("e6d9bd")  # tablero / secundario

# ---- Superficies ----
const SURFACE_CARD   := Color("1c1812")
const SURFACE_RAISED := Color("262019")
const INK_700        := Color("211c16")

# ---- Texto ----
const TEXT_STRONG := Color("f7f1e5")
const TEXT_BODY   := Color("d4c9b4")
const TEXT_MUTED  := Color("7a6e5c")
const BORDER_SOFT := Color(0.902, 0.851, 0.741, 0.14)  # rgba(230,217,189,.14)

# ---- 6 colores de grupo (subsistemas / fichas-animal) ----
const GROUP := [
	Color("2e6fb0"), Color("1f7a3d"), Color("e08a1e"),
	Color("7b3aa0"), Color("c0271f"), Color("16a0a0"),
]
const GROUP_EDGE := [
	Color("214f7e"), Color("155628"), Color("a66112"),
	Color("582872"), Color("8e1813"), Color("0e7373"),
]


# ---- Fuentes (Design System: Bungee display + Archivo Black para UI) ----
static func font_display() -> Font:
	return load("res://assets/fonts/Bungee-Regular.ttf")

static func font_heavy() -> Font:
	return load("res://assets/fonts/ArchivoBlack-Regular.ttf")


# ============ Estilos reutilizables ============

## Tarjeta oscura: superficie card, hairline crema 14%, sombra cálida, esquinas 18.
static func card_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE_CARD
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	sb.border_color = BORDER_SOFT
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 8)
	return sb

## Pieza física: borde inferior 3px más oscuro (canto moldeado).
static func _piece_box(base: Color, edge: Color, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.border_color = edge
	sb.border_width_bottom = 3
	return sb

## Aplica el look de botón-pieza a un Button (normal/hover/pressed/disabled/focus).
static func style_button(b: Button, base: Color, edge: Color, font_col := WHITE) -> void:
	var hf := font_heavy()
	if hf != null:
		b.add_theme_font_override("font", hf)
	b.add_theme_color_override("font_color", font_col)
	b.add_theme_color_override("font_hover_color", font_col)
	b.add_theme_color_override("font_pressed_color", font_col)
	b.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	b.add_theme_stylebox_override("normal", _piece_box(base, edge))
	b.add_theme_stylebox_override("hover", _piece_box(base.lightened(0.07), edge))
	# pressed: la pieza se hunde en la mesa (sin canto inferior, +2px arriba)
	var p := _piece_box(base.darkened(0.12), edge)
	p.border_width_bottom = 0
	p.content_margin_top = 14
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", _piece_box(SURFACE_RAISED, INK_700))
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0, 0, 0, 0)
	f.set_corner_radius_all(10)
	f.border_color = GOLD
	f.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", f)

## Disco de color de jugador con canto biselado.
static func swatch_box(i: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GROUP[i % GROUP.size()]
	sb.set_corner_radius_all(8)
	sb.border_color = GROUP_EDGE[i % GROUP_EDGE.size()]
	sb.border_width_bottom = 3
	return sb

## Campo de texto sobre superficie elevada.
static func style_line_edit(le: LineEdit) -> void:
	le.add_theme_color_override("font_color", TEXT_STRONG)
	le.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	le.add_theme_color_override("caret_color", GOLD)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE_RAISED
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	sb.border_color = BORDER_SOFT
	sb.set_border_width_all(1)
	le.add_theme_stylebox_override("normal", sb)
	var sf := sb.duplicate()
	sf.border_color = GOLD
	le.add_theme_stylebox_override("focus", sf)
