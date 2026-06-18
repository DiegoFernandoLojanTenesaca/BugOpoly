class_name BoardView
extends Node3D

const Brand = preload("res://src/ui/palette.gd")

const TILE_H := 0.08
const CORNER := 2.9
const SIDEW := 1.8

# Si existe un modelo en assets/bugopoly/models/pieces/<shape>.gltf se usa; si no, primitiva.
const PIECE_DIR := "res://assets/bugopoly/models/pieces/"
# Escala por modelo (calibrada para ~1.1 de alto desde el bounding box del glTF).
const PIECE_FIT := {
	"alien": 0.54, "alien_tall": 0.52, "bat": 0.63, "bee": 0.58, "cactus": 0.50,
	"chicken": 0.68, "crab": 0.70, "cthulhu": 0.70, "cyclops": 0.66, "deer": 0.58,
	"demon": 0.68, "ghost": 0.79, "greendemon": 0.68, "mushroom": 0.53, "panda": 0.67,
	"penguin": 0.68, "pig": 0.67, "skull": 0.71, "tree": 0.39, "yellowdragon": 0.67,
	"yeti": 0.66,
}

var _state
var _per_side := 6
var _half := 6.0
var _outer := 7.05
var _tokens: Array = []
var _owner_bars: Dictionary = {}
var _ring: MeshInstance3D
var _radar: Node3D
var _beacon: MeshInstance3D
var _beacon_t := 0.0
var _deck_pos: Dictionary = {}
var _house_nodes: Dictionary = {}
var _active_id := -1
var _ring_t := 0.0
var _mat_cache: Dictionary = {}  # color -> material mate compartido (menos instancias)

func build(state) -> void:
	_state = state
	var tiles: Array = state.tiles()
	_per_side = tiles.size() / 4
	_half = (CORNER + (_per_side - 1) * SIDEW) * 0.5
	_outer = _half + CORNER * 0.5 + 0.12

	var table := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(90, 0.5, 90)
	table.mesh = tm
	table.position = Vector3(0, -0.55, 0)
	table.material_override = _wood_table()
	add_child(table)

	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2 * _outer, 0.4, 2 * _outer)
	base.mesh = bm
	base.position = Vector3(0, -0.2, 0)
	base.material_override = _wood()
	add_child(base)

	var inner := MeshInstance3D.new()
	var im := BoxMesh.new()
	im.size = Vector3(2 * (_half - 1.0) + 0.1, 0.42, 2 * (_half - 1.0) + 0.1)
	inner.mesh = im
	inner.position = Vector3(0, -0.19, 0)
	inner.material_override = _mat(Color("d2c3a0"))  # fieltro crema (tablero)
	add_child(inner)

	# Centro oscuro estilo kit: el logo y la ciudad van encima (no sobre crema).
	var center_pad := _part(_box(12.6, 0.04, 12.6), _mat(Color("17120d")), Vector3(0, 0.005, 0))
	add_child(center_pad)

	var logo := Label3D.new()
	logo.text = "BUGOPOLY"
	logo.font = Brand.font_display()
	logo.font_size = 200
	logo.pixel_size = 0.0098
	logo.modulate = Brand.RED
	logo.outline_size = 22
	logo.outline_modulate = Color(0.18, 0.05, 0.045, 0.95)
	logo.position = Vector3(0, 0.05, 0.2)
	logo.rotation_degrees = Vector3(-90, 0, -7)
	add_child(logo)

	# tagline del kit, plano al frente del centro
	var tag := Label3D.new()
	tag.text = "// Construí cobertura  ·  Shipeá el release  ·  Cazá los bugs"
	tag.font = Brand.font_heavy()
	tag.font_size = 40
	tag.pixel_size = 0.0072
	tag.modulate = Brand.CREAM
	tag.outline_size = 8
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.position = Vector3(0, 0.055, 4.4)
	tag.rotation_degrees = Vector3(-90, 0, 0)
	add_child(tag)

	_build_diorama()

	_beacon = MeshInstance3D.new()
	var bsph := SphereMesh.new()
	bsph.radius = 0.22
	bsph.height = 0.44
	_beacon.mesh = bsph
	_beacon.material_override = _emissive(Color(1.0, 0.32, 0.26), 4.5)
	add_child(_beacon)

	for i in tiles.size():
		_build_tile(i, tiles[i])

	_build_frame()
	_build_decks()

	for p in state.players:
		var tok := _make_token(p)
		add_child(tok)
		_tokens.append(tok)
		tok.position = _tile_pos(p.position) + _token_offset(p.id)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.46
	ring_mesh.outer_radius = 0.64
	_ring.mesh = ring_mesh
	_ring.material_override = _emissive(Color(1.0, 0.9, 0.45))
	_ring.visible = false
	add_child(_ring)

func _process(delta: float) -> void:
	if _beacon != null:
		_beacon_t += delta
		var a := _beacon_t * 1.1
		_beacon.position = Vector3(cos(a) * 2.6, 5.6 + sin(_beacon_t * 2.0) * 0.3, sin(a) * 2.6)
	if _radar != null:
		_radar.rotation.y += delta * 0.9
	if _ring != null and _active_id >= 0 and _active_id < _tokens.size():
		_ring_t += delta
		var tok: Node3D = _tokens[_active_id]
		_ring.position = Vector3(tok.position.x, TILE_H + 0.04, tok.position.z)
		var s := 1.0 + sin(_ring_t * 4.5) * 0.09
		_ring.scale = Vector3(s, 1.0, s)

func set_active(p) -> void:
	_active_id = p.id
	if _ring != null:
		_ring.visible = true

func token_pos(p) -> Vector3:
	return _tokens[p.id].position

func board_half() -> float:
	return _half

const CITY := "res://assets/bugopoly/models/city/"

func _load_model(path: String, scale: float) -> Node3D:
	var ps = load(path)
	var root := Node3D.new()
	if ps != null:
		root.add_child(ps.instantiate())
		root.scale = Vector3(scale, scale, scale)
	return root

func _build_diorama() -> void:
	# Mini "ciudad de software" baja, en fila al FONDO del centro (no tapa el logo).
	var builds := [
		["building-skyscraper-b", Vector2(-4.4, -4.2), 0.55, -6.0, Brand.GROUP[2]],
		["building-skyscraper-a", Vector2(-3.0, -4.8), 0.80, 12.0, Brand.GROUP[0]],
		["building-skyscraper-c", Vector2(-1.3, -5.3), 0.68, -8.0, Brand.RED],
		["building-skyscraper-b", Vector2(0.5, -5.4), 0.92, 6.0, Brand.CREAM],
		["building-skyscraper-d", Vector2(2.3, -5.0), 0.64, -14.0, Brand.GOLD],
		["building-a", Vector2(3.8, -4.3), 0.58, 20.0, Brand.GROUP[5]],
	]
	for b in builds:
		var pv: Vector2 = b[1]
		var node := _load_model(CITY + str(b[0]) + ".glb", float(b[2]))
		node.position = Vector3(pv.x, 0.028, pv.y)
		node.rotation_degrees = Vector3(0, float(b[3]), 0)
		_tint(node, b[4])
		add_child(node)

func _tint(node: Node3D, col: Color) -> void:
	# Velo de color de marca encima del material original (conserva el detalle del modelo).
	var film := StandardMaterial3D.new()
	film.albedo_color = Color(col.r, col.g, col.b, 0.55)
	film.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	film.roughness = 0.5
	for c in node.find_children("*", "MeshInstance3D", true, false):
		c.material_overlay = film

func popup_text(world_pos: Vector3, text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 72
	lbl.pixel_size = 0.009
	lbl.modulate = color
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 0.85)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = world_pos + Vector3(0, 1.1, 0)
	add_child(lbl)
	var up := create_tween()
	up.tween_property(lbl, "position:y", lbl.position.y + 1.5, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade := create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(lbl, "modulate:a", 0.0, 0.7)
	fade.tween_callback(lbl.queue_free)

func _build_decks() -> void:
	_make_deck("bug", Vector3(5.5, 0, -5.5), Color.html("#E08A1E"), "BUG")
	_make_deck("retro", Vector3(-5.5, 0, 5.5), Color.html("#2E6FB0"), "RETRO")

func _make_deck(kind: String, pos: Vector3, color: Color, title: String) -> void:
	_deck_pos[kind] = pos
	for k in 7:
		var top: bool = k == 6
		var card := _part(_box(1.7, 0.05, 1.15), _mat(color if top else Color(0.93, 0.9, 0.82)), pos + Vector3(0, TILE_H + 0.04 + k * 0.05, 0))
		card.rotation_degrees = Vector3(0, k * 2.0 - 6.0, 0)
		add_child(card)
	var lbl := Label3D.new()
	lbl.text = title
	lbl.font_size = 38
	lbl.pixel_size = 0.006
	lbl.modulate = Color(1, 1, 1)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 0.7)
	lbl.position = pos + Vector3(0, TILE_H + 0.45, 0)
	lbl.rotation_degrees = Vector3(-90, 45, 0)
	add_child(lbl)

func draw_card(kind: String, text: String) -> void:
	var pos: Vector3 = _deck_pos.get(kind, Vector3(0, 0, 5))
	var color := Color(0.86, 0.5, 0.2) if kind == "bug" else Color(0.25, 0.46, 0.82)
	var card := _part(_box(2.0, 0.06, 1.35), _mat(Color(0.97, 0.95, 0.89)), pos + Vector3(0, TILE_H + 0.45, 0))
	add_child(card)
	card.add_child(_part(_box(2.0, 0.07, 0.34), _mat(color), Vector3(0, 0, -0.5)))
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 42
	lbl.pixel_size = 0.0055
	lbl.modulate = Color(0.1, 0.1, 0.12)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(1, 1, 1, 0.85)
	lbl.width = 360
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 1.6, 0)
	card.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(card, "position", pos + Vector3(0, 2.8, 1.8), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "rotation_degrees", Vector3(-42, 0, 0), 0.5)
	tw.tween_interval(2.3)
	tw.tween_property(card, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.queue_free)

func _build_tile(i: int, tile: Dictionary) -> void:
	var lay := _layout(i)
	var pos: Vector3 = lay["pos"]
	var sx: float = lay["sx"]
	var sz: float = lay["sz"]
	var corner: bool = lay["corner"]
	var side := i / _per_side
	var inward := _inward(side)
	var t := str(tile.get("type", ""))
	var bg := _tile_color(tile)

	# bisel: placa oscura un poco más grande y baja, asoma como borde
	var rim := _part(_box(sx + 0.07, TILE_H * 0.85, sz + 0.07), _mat(Color(0.11, 0.09, 0.07)), pos + Vector3(0, TILE_H * 0.42, 0))
	add_child(rim)

	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(sx, TILE_H, sz)
	box.mesh = bm
	box.position = pos + Vector3(0, TILE_H * 0.5, 0)
	box.material_override = _mat(bg)
	add_child(box)

	if t == "property" and not corner:
		var sub := Registry.get_def("subsystem", str(tile.get("subsystem", "")))
		var along: bool = side == 0 or side == 2
		var band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(sx if along else CORNER * 0.26, 0.05, CORNER * 0.26 if along else sz)
		band.mesh = band_mesh
		band.position = pos + inward * (CORNER * 0.37) + Vector3(0, TILE_H + 0.02, 0)
		band.material_override = _mat(Color.html(str(sub.get("color", "#cccccc"))))
		add_child(band)

	var dark := bg.get_luminance() < 0.5
	var label := Label3D.new()
	label.text = str(tile.get("name", t))
	label.font = Brand.font_heavy()
	label.font_size = 58 if corner else 42
	label.pixel_size = 0.0082
	label.modulate = Color(0.97, 0.95, 0.90) if dark else Color(0.10, 0.08, 0.06)
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 0.85) if dark else Color(1, 0.99, 0.95, 0.95)
	label.position = pos + inward * (CORNER * 0.06) + Vector3(0, TILE_H + 0.08, 0)
	label.rotation_degrees = Vector3(-90, side * 90.0, 0)
	label.width = 340 if corner else 200
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

	if t == "property" and not corner:
		var price_l := Label3D.new()
		price_l.font = Brand.font_heavy()
		price_l.text = "$" + str(int(tile.get("price", 0)))
		price_l.font_size = 30
		price_l.pixel_size = 0.0060
		price_l.modulate = Color(0.10, 0.08, 0.06)
		price_l.outline_size = 10
		price_l.outline_modulate = Color(1, 0.99, 0.95, 0.95)
		price_l.position = pos - inward * (CORNER * 0.34) + Vector3(0, TILE_H + 0.07, 0)
		price_l.rotation_degrees = Vector3(-90, side * 90.0, 0)
		add_child(price_l)

	if not corner and t != "property":
		_tile_icon(t, tile, pos, side, inward, dark)

	if corner:
		_corner_accent(t, pos)

const ICONS := "res://assets/bugopoly/icons/%s.svg"

func _icon_tex(name: String, col: Color) -> Texture2D:
	var path := ICONS % name
	if not FileAccess.file_exists(path):
		return null
	var svg := FileAccess.get_file_as_string(path).replace("currentColor", "#" + col.to_html(false))
	var img := Image.new()
	if img.load_svg_from_string(svg, 7.0) != OK:
		return null
	return ImageTexture.create_from_image(img)

func _tile_icon(type: String, tile: Dictionary, pos: Vector3, side: int, inward: Vector3, dark: bool) -> void:
	var name := ""
	match type:
		"incident": name = "alert"
		"challenge": name = "search"
		"tax": name = "credit-card"
		"coffee": name = "coffee"
		"card": name = "bug" if "bug" in str(tile.get("deck", "")) else "refresh"
	if name == "":
		return
	var tex := _icon_tex(name, Color(0.97, 0.95, 0.90) if dark else Color(0.13, 0.10, 0.07))
	if tex == null:
		return
	var spr := Sprite3D.new()
	spr.texture = tex
	spr.pixel_size = 0.0055
	spr.rotation_degrees = Vector3(-90, side * 90.0, 0)
	spr.position = pos - inward * (CORNER * 0.30) + Vector3(0, TILE_H + 0.09, 0)
	add_child(spr)

func tile_world(idx: int) -> Vector3:
	return _tile_pos(idx) + Vector3(0, TILE_H + 0.3, 0)

func _corner_accent(type: String, pos: Vector3) -> void:
	var y := TILE_H + 0.06
	match type:
		"go":
			var gold := _emissive(Color(0.96, 0.78, 0.22), 1.8)
			var shaft := _part(_box(1.3, 0.14, 0.34), gold, pos + Vector3(0.6, y, 0))
			add_child(shaft)
			var head := _part(_cyl(0.0, 0.55, 1.0), gold, pos + Vector3(-0.45, y, 0))
			head.rotation_degrees = Vector3(0, 0, 90)
			add_child(head)
		"blocked":
			_build_jail(pos, y)
		"incident":
			add_child(_part(_box(0.16, 0.7, 0.16), _emissive(Color(0.95, 0.3, 0.2), 2.5), pos + Vector3(0, y + 0.45, 0)))
			add_child(_part(_sphere(0.12), _emissive(Color(0.95, 0.3, 0.2), 2.5), pos + Vector3(0, y + 0.95, 0)))

func _build_jail(pos: Vector3, y: float) -> void:
	var frame := _glossy(Color(0.30, 0.31, 0.36))
	var bars := _glossy(Color(0.60, 0.63, 0.69))
	var s := 0.78   # media-anchura de la celda
	var h := 1.05   # alto de los barrotes
	var base := pos + Vector3(0, y, 0)
	# losa de la celda
	add_child(_part(_box(s * 2 + 0.2, 0.08, s * 2 + 0.2), frame, base + Vector3(0, 0.04, 0)))
	# 4 postes de esquina
	for px in [-s, s]:
		for pz in [-s, s]:
			add_child(_part(_box(0.12, h, 0.12), frame, base + Vector3(px, h * 0.5, pz)))
	# marco superior
	add_child(_part(_box(s * 2, 0.12, 0.12), frame, base + Vector3(0, h, -s)))
	add_child(_part(_box(s * 2, 0.12, 0.12), frame, base + Vector3(0, h, s)))
	add_child(_part(_box(0.12, 0.12, s * 2), frame, base + Vector3(-s, h, 0)))
	add_child(_part(_box(0.12, 0.12, s * 2), frame, base + Vector3(s, h, 0)))
	# barrotes verticales en los 4 lados
	for i in 4:
		var f := -s + 0.06 + i * (2.0 * s - 0.12) / 3.0
		add_child(_part(_box(0.05, h, 0.05), bars, base + Vector3(f, h * 0.5, s)))
		add_child(_part(_box(0.05, h, 0.05), bars, base + Vector3(f, h * 0.5, -s)))
		add_child(_part(_box(0.05, h, 0.05), bars, base + Vector3(s, h * 0.5, f)))
		add_child(_part(_box(0.05, h, 0.05), bars, base + Vector3(-s, h * 0.5, f)))
	# baliza roja de alerta
	add_child(_part(_sphere(0.12), _emissive(Color(0.95, 0.28, 0.22), 2.4), base + Vector3(0, h + 0.18, 0)))

func _layout(i: int) -> Dictionary:
	var side := i / _per_side
	var t := i % _per_side
	var h := _half
	if t == 0:
		var corners := [Vector3(h, 0, h), Vector3(-h, 0, h), Vector3(-h, 0, -h), Vector3(h, 0, -h)]
		return {"pos": corners[side], "sx": CORNER, "sz": CORNER, "corner": true}
	var off := CORNER * 0.5 + (t - 0.5) * SIDEW
	match side:
		0: return {"pos": Vector3(h - off, 0, h), "sx": SIDEW, "sz": CORNER, "corner": false}
		1: return {"pos": Vector3(-h, 0, h - off), "sx": CORNER, "sz": SIDEW, "corner": false}
		2: return {"pos": Vector3(-h + off, 0, -h), "sx": SIDEW, "sz": CORNER, "corner": false}
		_: return {"pos": Vector3(h, 0, -h + off), "sx": CORNER, "sz": SIDEW, "corner": false}

func _tile_pos(i: int) -> Vector3:
	return _layout(i)["pos"]

func _inward(side: int) -> Vector3:
	match side:
		0: return Vector3(0, 0, -1)
		1: return Vector3(1, 0, 0)
		2: return Vector3(0, 0, 1)
		_: return Vector3(-1, 0, 0)

func _token_offset(id: int) -> Vector3:
	return Vector3((id % 2) * 0.6 - 0.3, TILE_H, (id / 2) * 0.6 - 0.3)

func hop_step(p) -> void:
	var tok: Node3D = _tokens[p.id]
	var target: Vector3 = _tile_pos(p.position) + _token_offset(p.id)
	var mid: Vector3 = (tok.position + target) * 0.5 + Vector3(0, 1.1, 0)
	var tw := create_tween()
	tw.tween_property(tok, "scale", Vector3(0.86, 1.18, 0.86), 0.05)  # estira al despegar
	tw.parallel().tween_property(tok, "position", mid, 0.11)
	tw.tween_property(tok, "scale", Vector3.ONE, 0.06)
	tw.parallel().tween_property(tok, "position", target, 0.11)
	tw.tween_property(tok, "scale", Vector3(1.18, 0.78, 1.18), 0.05)  # aplasta al caer
	tw.tween_property(tok, "scale", Vector3.ONE, 0.08)
	tw.tween_callback(puff_dust.bind(target))
	await tw.finished

func place_token(p) -> void:
	var tok: Node3D = _tokens[p.id]
	tok.position = _tile_pos(p.position) + _token_offset(p.id)

func mark_owner(idx: int, color: Color) -> void:
	set_houses(idx, 0, color)

func set_houses(idx: int, count: int, color: Color) -> void:
	var side := idx / _per_side
	if _house_nodes.has(idx):
		_house_nodes[idx].queue_free()
	var holder := Node3D.new()
	add_child(holder)
	_house_nodes[idx] = holder
	var inward := _inward(side)
	var along := inward.cross(Vector3.UP).normalized()
	var center := _tile_pos(idx) - inward * (CORNER * 0.24) + Vector3(0, TILE_H, 0)

	var flag := _make_flag(color)
	flag.position = _tile_pos(idx) - inward * (CORNER * 0.36) + along * (CORNER * 0.32) + Vector3(0, TILE_H, 0)
	holder.add_child(flag)
	_pop(flag)

	if count >= 5:
		# CI/CD → rascacielos
		var hotel := _load_model(CITY + "building-skyscraper-c.glb", 1.1)
		hotel.position = center
		holder.add_child(hotel)
		_pop(hotel)
	elif count >= 1:
		# cobertura → un edificio que crece (small → big) con cada nivel
		var b := _load_model(CITY + "building-c.glb", 0.35 + count * 0.16)
		b.position = center
		holder.add_child(b)
		_pop(b)

func _make_flag(color: Color) -> Node3D:
	var n := Node3D.new()
	n.add_child(_part(_cyl(0.03, 0.03, 0.6), _glossy(Color(0.3, 0.3, 0.34)), Vector3(0, 0.3, 0)))
	n.add_child(_part(_box(0.3, 0.2, 0.02), _glossy(color), Vector3(0.16, 0.5, 0)))
	return n

func _pop(node: Node3D) -> void:
	var target: Vector3 = node.scale
	node.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(node, "scale", target, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func fly_bills(from: Vector3, to: Vector3, count: int) -> void:
	for k in count:
		var value: int = [10, 50, 100, 500, 1000][randi() % 5]
		var bill := _make_bill(value)
		bill.scale = Vector3(1.7, 1.7, 1.7)
		bill.position = from + Vector3(0, 0.8, 0)
		add_child(bill)
		# suben alto sobre el centro del tablero (bien visibles), pausan y caen al destino
		var apex := Vector3(randf_range(-1.3, 1.3), 5.0 + k * 0.35, 1.2 + randf_range(-0.7, 0.7))
		var tw := create_tween()
		tw.tween_interval(k * 0.08)
		tw.tween_property(bill, "position", apex, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(bill, "rotation_degrees", bill.rotation_degrees + Vector3(0, 180, 0), 0.5)
		tw.tween_interval(0.4)
		tw.tween_property(bill, "position", to + Vector3(0, 0.5, 0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(bill, "scale", Vector3.ZERO, 0.5)
		tw.tween_callback(bill.queue_free)

func _make_bill(value: int = 100) -> Node3D:
	# Billete QA Credits con denominación (paleta del kit por valor).
	var st := _bill_style(value)
	var paper: Color = st[0]
	var ink: Color = st[1]
	var n := Node3D.new()
	n.add_child(_part(_box(1.15, 0.03, 0.6), _mat(paper), Vector3.ZERO))
	n.add_child(_part(_box(1.02, 0.032, 0.48), _mat(Color(ink.r, ink.g, ink.b, 0.16)), Vector3(0, 0.002, 0)))
	n.add_child(_part(_box(0.2, 0.034, 0.2), _mat(ink), Vector3(0.38, 0.006, 0)))
	var lbl := Label3D.new()
	lbl.text = str(value)
	lbl.font = Brand.font_display()
	lbl.font_size = 64
	lbl.pixel_size = 0.0055
	lbl.modulate = ink
	lbl.position = Vector3(-0.1, 0.02, 0)
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	n.add_child(lbl)
	n.rotation_degrees = Vector3(0, randf() * 360.0, 0)
	return n

func _bill_style(value: int) -> Array:
	match value:
		10: return [Color.html("#eceae4"), Color.html("#4f4f4f")]
		50: return [Color.html("#dce8f4"), Color.html("#1f5286")]
		100: return [Color.html("#dcecdf"), Color.html("#1a5e30")]
		500: return [Color.html("#f6e7cf"), Color.html("#a5620f")]
		_: return [Color.html("#fbf1c9"), Color.html("#8a6f08")]

# ---------- juice / pulido ----------

func _add_outline(root: Node3D) -> void:
	# Contorno toon (next_pass que crece e invierte caras) en cada parte de la ficha.
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override is StandardMaterial3D:
			var ol := StandardMaterial3D.new()
			ol.albedo_color = Color(0.05, 0.04, 0.05)
			ol.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ol.cull_mode = BaseMaterial3D.CULL_FRONT
			ol.grow = true
			ol.grow_amount = 0.022
			mi.material_override.next_pass = ol

func _blob_shadow() -> MeshInstance3D:
	# Sombra de contacto suave para asentar la pieza en la mesa.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.30)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := _cyl(0.34, 0.34, 0.01)
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = m
	mi.position = Vector3(0, 0.012, 0)
	return mi

func _build_frame() -> void:
	# Marco de madera elevado alrededor del tablero (lo hace sentir físico).
	var w := 0.55
	var ext := _half + CORNER * 0.5 + w * 0.5
	var mat := _glossy(Color(0.26, 0.17, 0.10))
	var l := 2.0 * ext + w
	var spots := [Vector3(0, 0.07, ext), Vector3(ext, 0.07, 0), Vector3(0, 0.07, -ext), Vector3(-ext, 0.07, 0)]
	for s in 4:
		var horiz: bool = s % 2 == 0
		var bar := _part(_box(l if horiz else w, 0.24, w if horiz else l), mat, spots[s])
		add_child(bar)

func puff_dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, -2.2, 0)
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.14
	p.color = Color(0.82, 0.77, 0.66, 0.55)
	p.mesh = _sphere(0.5)
	p.position = at + Vector3(0, 0.05, 0)
	add_child(p)
	_autofree(p, 1.1)

func burst_confetti(at: Vector3, tint: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 26
	p.lifetime = 1.0
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -6.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.12
	p.color = tint
	p.mesh = _box(1.0, 0.06, 0.6)
	p.position = at + Vector3(0, 0.3, 0)
	add_child(p)
	_autofree(p, 1.8)

func flash(at: Vector3, color: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.85)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s := _part(_sphere(0.22), m, at + Vector3(0, 0.35, 0))
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3(5, 5, 5), 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(s.queue_free)

func _autofree(n: Node, secs: float) -> void:
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(n.queue_free)

func _make_house(color: Color) -> Node3D:
	var root := Node3D.new()
	var walls := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.46, 0.34, 0.46)
	walls.mesh = wm
	walls.position = Vector3(0, 0.17, 0)
	walls.material_override = _glossy(Color(0.92, 0.90, 0.84))
	root.add_child(walls)
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.0
	rm.bottom_radius = 0.42
	rm.height = 0.28
	rm.radial_segments = 4
	roof.mesh = rm
	roof.position = Vector3(0, 0.48, 0)
	roof.rotation_degrees = Vector3(0, 45, 0)
	roof.material_override = _glossy(color)
	root.add_child(roof)
	return root

func _make_token(p) -> Node3D:
	var shape := "pawn"
	if p.piece != "":
		shape = str(Registry.get_def("piece", p.piece).get("shape", "pawn"))
	var root := _load_piece_model(shape, p.color)
	if root == null:
		root = _build_piece(shape, p.color)
		_add_outline(root)
	root.add_child(_blob_shadow())
	return root

func _load_piece_model(shape: String, color: Color, with_pedestal := true) -> Node3D:
	var inst: Node = null
	# 1) si Godot lo tiene importado, usar la escena (rápido)
	for ext in [".glb", ".gltf"]:
		var p: String = PIECE_DIR + shape + ext
		if ResourceLoader.exists(p):
			var ps = load(p)
			if ps != null:
				inst = ps.instantiate()
				break
	# 2) si no, cargar el .gltf en runtime (NO requiere importarlo en Godot)
	if inst == null:
		var abs_path: String = ProjectSettings.globalize_path(PIECE_DIR + shape + ".gltf")
		if FileAccess.file_exists(abs_path):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(abs_path, st) == OK:
				inst = doc.generate_scene(st)
	if inst == null:
		return null
	var holder := Node3D.new()
	var s: float = float(PIECE_FIT.get(shape, 1.0))
	var wrap := Node3D.new()
	wrap.scale = Vector3(s, s, s)
	wrap.add_child(inst)
	holder.add_child(wrap)
	# reproducir Idle si el modelo está animado
	var aps: Array = inst.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var ap: AnimationPlayer = aps[0]
		var list := ap.get_animation_list()
		var pick := ""
		for a in list:
			if "idle" in str(a).to_lower():
				pick = a
				break
		if pick == "" and not list.is_empty():
			pick = list[0]
		if pick != "":
			ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
			ap.play(pick)
	if with_pedestal:
		# pedestal (sin escalar) con el color del jugador para identificar la ficha
		holder.add_child(_part(_cyl(0.30, 0.36, 0.08), _glossy(color), Vector3(0, 0.04, 0)))
	return holder

func _build_piece(shape: String, color: Color) -> Node3D:
	var root := Node3D.new()
	match shape:
		"ladybug":
			var lb := _part(_sphere(0.42), _glossy(color), Vector3(0, 0.34, -0.02))
			lb.scale = Vector3(1.0, 0.6, 1.2)
			root.add_child(lb)
			root.add_child(_part(_sphere(0.18), _glossy(Color(0.07, 0.07, 0.09)), Vector3(0, 0.32, 0.40)))
			root.add_child(_part(_box(0.03, 0.05, 0.5), _glossy(Color(0.07, 0.07, 0.09)), Vector3(0, 0.55, -0.02)))
			for sp in [Vector3(0.17, 0.5, 0.04), Vector3(-0.17, 0.5, 0.04), Vector3(0.12, 0.46, -0.22), Vector3(-0.12, 0.46, -0.22)]:
				root.add_child(_part(_sphere(0.07), _glossy(Color(0.07, 0.07, 0.09)), sp))
		"owl":
			var ob := _part(_sphere(0.36), _glossy(color), Vector3(0, 0.42, 0))
			ob.scale = Vector3(1.0, 1.25, 0.9)
			root.add_child(ob)
			root.add_child(_part(_sphere(0.26), _glossy(color.lightened(0.2)), Vector3(0, 0.34, 0.2)))
			for sx in [-0.15, 0.15]:
				root.add_child(_part(_sphere(0.13), _glossy(Color(0.96, 0.95, 0.92)), Vector3(sx, 0.6, 0.26)))
				root.add_child(_part(_sphere(0.06), _glossy(Color(0.06, 0.06, 0.08)), Vector3(sx, 0.6, 0.36)))
			root.add_child(_part(_sphere(0.06), _glossy(Brand.GOLD), Vector3(0, 0.5, 0.34)))
			var ot1 := _part(_cyl(0.0, 0.09, 0.22), _glossy(color), Vector3(-0.17, 0.86, 0))
			ot1.rotation_degrees = Vector3(0, 0, 16)
			root.add_child(ot1)
			var ot2 := _part(_cyl(0.0, 0.09, 0.22), _glossy(color), Vector3(0.17, 0.86, 0))
			ot2.rotation_degrees = Vector3(0, 0, -16)
			root.add_child(ot2)
		"fox":
			root.add_child(_part(_sphere(0.32), _glossy(color), Vector3(0, 0.32, -0.05)))
			root.add_child(_part(_sphere(0.25), _glossy(color), Vector3(0, 0.5, 0.2)))
			var snout := _part(_sphere(0.13), _glossy(Color(0.97, 0.96, 0.92)), Vector3(0, 0.44, 0.42))
			snout.scale = Vector3(0.8, 0.8, 1.4)
			root.add_child(snout)
			root.add_child(_part(_sphere(0.05), _glossy(Color(0.06, 0.06, 0.08)), Vector3(0, 0.45, 0.56)))
			root.add_child(_part(_cyl(0.0, 0.1, 0.26), _glossy(color), Vector3(-0.16, 0.74, 0.14)))
			root.add_child(_part(_cyl(0.0, 0.1, 0.26), _glossy(color), Vector3(0.16, 0.74, 0.14)))
			root.add_child(_part(_sphere(0.04), _glossy(Color(0.06, 0.06, 0.08)), Vector3(-0.1, 0.56, 0.38)))
			root.add_child(_part(_sphere(0.04), _glossy(Color(0.06, 0.06, 0.08)), Vector3(0.1, 0.56, 0.38)))
			var tail := _part(_cyl(0.05, 0.2, 0.5), _glossy(color), Vector3(0, 0.34, -0.46))
			tail.rotation_degrees = Vector3(55, 0, 0)
			root.add_child(tail)
			root.add_child(_part(_sphere(0.13), _glossy(Color(0.97, 0.96, 0.92)), Vector3(0, 0.56, -0.62)))
		"spider":
			var sm := _glossy(Color(0.12, 0.11, 0.13))
			var sbody := _part(_sphere(0.34), _glossy(color.darkened(0.25)), Vector3(0, 0.36, -0.04))
			sbody.scale = Vector3(1.0, 0.8, 1.15)
			root.add_child(sbody)
			root.add_child(_part(_sphere(0.2), _glossy(color.darkened(0.1)), Vector3(0, 0.36, 0.3)))
			root.add_child(_part(_sphere(0.05), _glossy(Color(0.95, 0.95, 0.95)), Vector3(-0.08, 0.44, 0.46)))
			root.add_child(_part(_sphere(0.05), _glossy(Color(0.95, 0.95, 0.95)), Vector3(0.08, 0.44, 0.46)))
			for k in 8:
				var ang := k * TAU / 8.0
				var dir := Vector3(cos(ang), -0.5, sin(ang)).normalized()
				var leg := _part(_cyl(0.02, 0.03, 0.6), sm, Vector3(cos(ang) * 0.30, 0.26, sin(ang) * 0.30))
				leg.quaternion = Quaternion(Vector3.UP, dir)
				root.add_child(leg)
		"octopus":
			var oh := _part(_sphere(0.4), _glossy(color), Vector3(0, 0.5, 0))
			oh.scale = Vector3(1.0, 1.1, 1.0)
			root.add_child(oh)
			for sx2 in [-0.15, 0.15]:
				root.add_child(_part(_sphere(0.09), _glossy(Color(0.96, 0.95, 0.92)), Vector3(sx2, 0.56, 0.32)))
				root.add_child(_part(_sphere(0.05), _glossy(Color(0.06, 0.06, 0.08)), Vector3(sx2, 0.56, 0.4)))
			for k2 in 8:
				var ang2 := k2 * TAU / 8.0
				var dir2 := Vector3(cos(ang2), -1.4, sin(ang2)).normalized()
				var tent := _part(_cyl(0.03, 0.08, 0.5), _glossy(color), Vector3(cos(ang2) * 0.22, 0.24, sin(ang2) * 0.22))
				tent.quaternion = Quaternion(Vector3.UP, dir2)
				root.add_child(tent)
		"penguin":
			var pb := _part(_sphere(0.34), _glossy(color), Vector3(0, 0.44, 0))
			pb.scale = Vector3(1.0, 1.3, 0.9)
			root.add_child(pb)
			var belly := _part(_sphere(0.24), _glossy(Color(0.96, 0.96, 0.97)), Vector3(0, 0.4, 0.22))
			belly.scale = Vector3(1.0, 1.25, 0.5)
			root.add_child(belly)
			root.add_child(_part(_sphere(0.05), _glossy(Color(0.06, 0.06, 0.08)), Vector3(-0.1, 0.66, 0.28)))
			root.add_child(_part(_sphere(0.05), _glossy(Color(0.06, 0.06, 0.08)), Vector3(0.1, 0.66, 0.28)))
			var beak := _part(_cyl(0.0, 0.08, 0.18), _glossy(Brand.GOLD), Vector3(0, 0.56, 0.3))
			beak.rotation_degrees = Vector3(90, 0, 0)
			root.add_child(beak)
			root.add_child(_part(_box(0.2, 0.05, 0.22), _glossy(Brand.GOLD), Vector3(-0.12, 0.04, 0.06)))
			root.add_child(_part(_box(0.2, 0.05, 0.22), _glossy(Brand.GOLD), Vector3(0.12, 0.04, 0.06)))
		"monkey":
			var mbody := _part(_sphere(0.32), _glossy(color), Vector3(0, 0.34, 0))
			mbody.scale = Vector3(1.0, 1.1, 0.9)
			root.add_child(mbody)
			root.add_child(_part(_sphere(0.18), _glossy(Color(0.93, 0.86, 0.72)), Vector3(0, 0.32, 0.22)))  # panza crema
			root.add_child(_part(_sphere(0.29), _glossy(color), Vector3(0, 0.74, 0.04)))  # cabeza
			var mface := _part(_sphere(0.19), _glossy(Color(0.93, 0.86, 0.72)), Vector3(0, 0.72, 0.21))
			mface.scale = Vector3(1.0, 1.1, 0.6)
			root.add_child(mface)
			root.add_child(_part(_sphere(0.10), _glossy(color), Vector3(-0.27, 0.76, 0.0)))  # orejas
			root.add_child(_part(_sphere(0.10), _glossy(color), Vector3(0.27, 0.76, 0.0)))
			root.add_child(_part(_sphere(0.04), _glossy(Color(0.08, 0.06, 0.05)), Vector3(-0.08, 0.76, 0.35)))  # ojos
			root.add_child(_part(_sphere(0.04), _glossy(Color(0.08, 0.06, 0.05)), Vector3(0.08, 0.76, 0.35)))
			root.add_child(_part(_sphere(0.05), _glossy(Color(0.58, 0.42, 0.32)), Vector3(0, 0.66, 0.37)))  # hocico
			root.add_child(_part(_cyl(0.055, 0.055, 0.34), _glossy(color), Vector3(-0.30, 0.34, 0.04)))  # brazos
			root.add_child(_part(_cyl(0.055, 0.055, 0.34), _glossy(color), Vector3(0.30, 0.34, 0.04)))
			var mtail := _part(_cyl(0.04, 0.05, 0.5), _glossy(color), Vector3(0, 0.30, -0.30))
			mtail.rotation_degrees = Vector3(48, 0, 0)
			root.add_child(mtail)
			root.add_child(_part(_sphere(0.06), _glossy(color), Vector3(0, 0.12, -0.55)))  # punta cola
		"mug":
			var body := _part(_cyl(0.30, 0.27, 0.55), _glossy(color), Vector3(0, 0.28, 0))
			root.add_child(body)
			root.add_child(_part(_cyl(0.26, 0.26, 0.05), _mat(Color(0.20, 0.12, 0.06)), Vector3(0, 0.55, 0)))
			var handle := _part(_torus(0.05, 0.10), _glossy(color), Vector3(0.32, 0.30, 0))
			handle.rotation_degrees = Vector3(0, 0, 90)
			root.add_child(handle)
		"bug":
			var body := _part(_sphere(0.42), _glossy(color), Vector3(0, 0.34, -0.04))
			body.scale = Vector3(1.0, 0.62, 1.25)
			root.add_child(body)
			root.add_child(_part(_sphere(0.20), _glossy(Color(0.08, 0.08, 0.10)), Vector3(0, 0.34, 0.40)))
			var seam := _part(_box(0.04, 0.04, 0.55), _glossy(Color(0.08, 0.08, 0.10)), Vector3(0, 0.56, -0.04))
			root.add_child(seam)
		"magnifier":
			var ring := _part(_torus(0.07, 0.20), _glossy(color), Vector3(0, 0.66, 0))
			ring.rotation_degrees = Vector3(90, 0, 0)
			root.add_child(ring)
			var lens := _part(_cyl(0.19, 0.19, 0.03), _glass(Color(0.6, 0.8, 0.95)), Vector3(0, 0.66, 0))
			lens.rotation_degrees = Vector3(90, 0, 0)
			root.add_child(lens)
			var handle := _part(_cyl(0.06, 0.06, 0.5), _glossy(color.darkened(0.1)), Vector3(0.0, 0.22, 0))
			root.add_child(handle)
		"server":
			root.add_child(_part(_box(0.5, 0.72, 0.42), _glossy(Color(0.16, 0.17, 0.20)), Vector3(0, 0.36, 0)))
			for k in 3:
				root.add_child(_part(_box(0.34, 0.04, 0.02), _emissive(color), Vector3(0, 0.22 + k * 0.18, 0.22)))
		_:
			root.add_child(_part(_cyl(0.16, 0.42, 0.7), _glossy(color), Vector3(0, 0.35, 0)))
			root.add_child(_part(_sphere(0.32), _glossy(color.lightened(0.12)), Vector3(0, 0.92, 0)))
	return root

func _part(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	return m

func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2
	return m

func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m

func _glass(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.2
	return m

func _emissive(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _tile_color(tile: Dictionary) -> Color:
	match str(tile.get("type", "")):
		"go": return Brand.RED
		"blocked": return Brand.SURFACE_CARD
		"incident": return Brand.GROUP[4]   # rojo bug / peligro
		"coffee": return Brand.GROUP[5]     # teal
		"challenge": return Brand.GROUP[0]  # azul
		"card": return Brand.GOLD
		"tax": return Brand.BLACK_WARM
		_: return Brand.CREAM               # propiedad = fieltro crema

func _mat(c: Color) -> StandardMaterial3D:
	# Material mate compartido por color (no se mutan después de creados).
	if _mat_cache.has(c):
		return _mat_cache[c]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	_mat_cache[c] = m
	return m

func _wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/bugopoly/textures/board/wood_diff.jpg")
	m.albedo_color = Color(0.62, 0.46, 0.32)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/bugopoly/textures/board/wood_nor.jpg")
	m.roughness_texture = load("res://assets/bugopoly/textures/board/wood_rough.jpg")
	m.uv1_scale = Vector3(4, 4, 4)
	return m

func _wood_table() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/bugopoly/textures/board/wood_diff.jpg")
	m.albedo_color = Color(0.42, 0.30, 0.20)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/bugopoly/textures/board/wood_nor.jpg")
	m.roughness_texture = load("res://assets/bugopoly/textures/board/wood_rough.jpg")
	m.uv1_scale = Vector3(10, 10, 10)
	return m

func _glossy(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	m.metallic = 0.1
	return m
