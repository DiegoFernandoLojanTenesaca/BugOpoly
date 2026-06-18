class_name Decor
extends Node3D

var _items: Array = []
var _heli: Node3D
var _heli_main: Node3D
var _heli_tail: Node3D
var _heli_r := 13.0
var _craft: Node3D
var _craft_r := 15.0
var _vehicles: Array = []
var _t := 0.0
var _drop_t := 0.0
var _runners: Array = []

const MODELS := "res://assets/bugopoly/models/"
const CHARS := "res://assets/bugopoly/models/chars/"

func build(board_half: float) -> void:
	var bh := board_half
	# Escena de fondo DETRÁS del tablero (no tapa la vista): corren de lado a lado.
	var bz := -(bh + 10.0)  # z detrás del tablero, lejos de la cámara
	_chase("shaun", "zombie_basic", bz, 0.55, 0.0, bh + 13.0)
	_fight("sam", "Slash", "zombie_chubby", "Attack", Vector3(bh + 7.0, 0, bz - 2.0))
	_runner(_load_char("pug", "Run", 3.0), bz - 3.0, 0.9, 1.5, bh + 12.0)
	_bob(_cloud(), Vector3(bh + 2.0, 5.6, -4.5), 2.0, 0.45, 0.8)
	_bob(_cloud(), Vector3(-(bh + 4.0), 6.6, 8.5), 1.0, 0.4, 0.7)

func _chase(survivor: String, zombie: String, z: float, speed: float, phase: float, range: float) -> void:
	_runner(_load_char(survivor, "Run", 2.4), z, speed, phase, range)
	_runner(_load_char(zombie, "Run", 2.4), z, speed, phase + 0.35, range)  # zombie detrás

func _fight(a: String, a_anim: String, b: String, b_anim: String, pos: Vector3) -> void:
	# Dos personajes enfrentados pegándose en un punto fijo.
	var na := _load_char(a, a_anim, 2.4)
	if na != null:
		na.position = pos + Vector3(1.0, 0, 0)
		na.rotation.y = PI * 0.5
		add_child(na)
	var nb := _load_char(b, b_anim, 2.4)
	if nb != null:
		nb.position = pos + Vector3(-1.0, 0, 0)
		nb.rotation.y = -PI * 0.5
		add_child(nb)

func _runner(node: Node3D, z: float, speed: float, phase: float, range: float) -> void:
	if node == null:
		return
	add_child(node)
	_runners.append({"node": node, "z": z, "speed": speed, "phase": phase, "range": range})

func _load_char(name: String, anim: String, scale: float) -> Node3D:
	var abs_path := ProjectSettings.globalize_path(CHARS + name + ".gltf")
	if not FileAccess.file_exists(abs_path):
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(abs_path, st) != OK:
		return null
	var inst: Node = doc.generate_scene(st)
	if inst == null:
		return null
	var holder := Node3D.new()
	var wrap := Node3D.new()
	wrap.scale = Vector3(scale, scale, scale)
	wrap.add_child(inst)
	holder.add_child(wrap)
	var aps: Array = inst.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var ap: AnimationPlayer = aps[0]
		var pick := ""
		for a in ap.get_animation_list():
			if anim.to_lower() in str(a).to_lower():
				pick = a
				break
		if pick != "":
			ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
			ap.play(pick)
	return holder

func _build_environment(bh: float) -> void:
	# Pocos árboles/farolas, bien lejos del tablero.
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var ring := bh + 6.0
	for k in 8:
		var ang := k * TAU / 8.0 + rng.randf_range(-0.12, 0.12)
		var rad := ring + rng.randf_range(0.0, 5.0)
		var pos := Vector3(cos(ang) * rad, 0, sin(ang) * rad)
		if abs(pos.x) < bh + 4.0 and abs(pos.z) < bh + 4.0:
			continue
		if rng.randf() < 0.6:
			_bob(_tree(rng), pos, rng.randf_range(0.0, 6.0), 0.08, 0.9)
		else:
			var lp := _lamppost()
			lp.position = pos
			add_child(lp)
	# cohete en plataforma de lanzamiento (deploy)
	var rocket := _rocket()
	rocket.position = Vector3(-(bh + 8.5), 0, -(bh + 2.0))
	add_child(rocket)

func _drive(node: Node3D, radius: float, speed: float, phase: float, y: float) -> void:
	add_child(node)
	_vehicles.append({"node": node, "r": radius, "speed": speed, "phase": phase, "y": y})

func _process(delta: float) -> void:
	_t += delta
	for it in _items:
		var n: Node3D = it["node"]
		if it["amp"] > 0.0:
			n.position.y = it["base_y"] + sin(_t * it["freq"] + it["phase"]) * it["amp"]
		var spin: Vector3 = it["spin"]
		if spin != Vector3.ZERO:
			n.rotation += spin * delta
	if _heli != null:
		var a := _t * 0.4
		_heli.position = Vector3(cos(a) * _heli_r, 6.2 + sin(_t * 0.7) * 0.5, sin(a) * _heli_r)
		_heli.rotation.y = -a
		_heli.rotation.z = sin(a) * 0.12
		_heli_main.rotation.y += delta * 32.0
		_heli_tail.rotation.x += delta * 28.0
		_drop_t += delta
		if _drop_t > 3.5:
			_drop_t = 0.0
			_drop_bug(_heli.position)
	if _craft != null:
		var ca := -_t * 0.26 + 2.0
		_craft.position = Vector3(cos(ca) * _craft_r, 7.6 + sin(_t * 0.5) * 0.6, sin(ca) * _craft_r)
		_craft.rotation.y = -ca + PI * 0.5
		_craft.rotation.z = sin(ca) * 0.1
	for v in _vehicles:
		var n: Node3D = v["node"]
		var va: float = _t * v["speed"] + v["phase"]
		n.position = Vector3(cos(va) * v["r"], v["y"], sin(va) * v["r"])
		var sgn: float = 1.0 if v["speed"] >= 0.0 else -1.0
		n.rotation.y = -va + PI * 0.5 * sgn
	for ru in _runners:
		var rn: Node3D = ru["node"]
		var ph: float = _t * ru["speed"] + ru["phase"]
		rn.position = Vector3(sin(ph) * ru["range"], 0.0, ru["z"])  # van de lado a lado al fondo
		rn.rotation.y = PI * 0.5 if cos(ph) >= 0.0 else -PI * 0.5  # miran hacia donde van

func _drop_bug(pos: Vector3) -> void:
	var bug := Node3D.new()
	bug.add_child(_p(_sphere(0.2), _glossy(Color(0.85, 0.2, 0.2)), Vector3.ZERO))
	bug.add_child(_p(_sphere(0.11), _glossy(Color(0.1, 0.1, 0.12)), Vector3(0, 0.02, 0.18)))
	bug.add_child(_p(_box(0.04, 0.04, 0.28), _glossy(Color(0.1, 0.1, 0.12)), Vector3(0, 0.18, 0)))
	bug.position = pos + Vector3(0, -0.4, 0)
	add_child(bug)
	var fall := create_tween()
	fall.tween_property(bug, "position:y", 0.35, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(bug, "position:y", 0.55, 0.12).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(bug, "position:y", 0.35, 0.1)
	var life := create_tween()
	life.tween_interval(1.4)
	life.tween_property(bug, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	life.tween_callback(bug.queue_free)

# ---------- registration ----------

func _bob(node: Node3D, pos: Vector3, phase: float, amp := 0.2, freq := 1.4) -> void:
	node.position = pos
	add_child(node)
	_items.append({"node": node, "base_y": pos.y, "amp": amp, "freq": freq, "phase": phase, "spin": Vector3.ZERO})

func _spin(node: Node3D, pos: Vector3, spin: Vector3) -> void:
	node.position = pos
	add_child(node)
	_items.append({"node": node, "base_y": pos.y, "amp": 0.0, "freq": 0.0, "phase": 0.0, "spin": spin})

# ---------- props ----------

func _terminal() -> Node3D:
	var n := Node3D.new()
	n.add_child(_p(_cyl(0.12, 0.16, 0.7), _glossy(Color(0.2, 0.2, 0.24)), Vector3(0, 0.35, 0)))
	n.add_child(_p(_box(1.7, 1.15, 0.14), _glossy(Color(0.12, 0.13, 0.16)), Vector3(0, 1.05, 0)))
	n.add_child(_p(_box(1.5, 0.95, 0.02), _emissive(Color(0.05, 0.09, 0.10), 1.0), Vector3(0, 1.05, 0.08)))
	var cols := [Color(0.35, 0.9, 0.5), Color(0.4, 0.7, 1.0), Color(0.95, 0.8, 0.35), Color(0.85, 0.5, 0.9)]
	var widths := [1.1, 0.7, 0.95, 0.5]
	for i in 4:
		n.add_child(_p(_box(widths[i], 0.1, 0.01), _emissive(cols[i], 2.2), Vector3(-0.75 + widths[i] * 0.5, 1.38 - i * 0.22, 0.1)))
	n.scale = Vector3(1.5, 1.5, 1.5)
	return n

func _server() -> Node3D:
	var n := Node3D.new()
	n.add_child(_p(_box(0.9, 2.3, 0.7), _glossy(Color(0.13, 0.14, 0.17)), Vector3(0, 1.15, 0)))
	for k in 7:
		var c := Color(0.3, 0.9, 0.45) if k % 3 != 0 else Color(0.95, 0.6, 0.2)
		n.add_child(_p(_box(0.6, 0.05, 0.02), _emissive(c, 2.4), Vector3(0, 0.4 + k * 0.26, 0.36)))
	n.scale = Vector3(1.4, 1.4, 1.4)
	return n

func _cloud() -> Node3D:
	var n := Node3D.new()
	var m := _glossy(Color(0.92, 0.94, 0.98))
	n.add_child(_p(_sphere(0.8), m, Vector3(0, 0, 0)))
	n.add_child(_p(_sphere(0.6), m, Vector3(-0.85, -0.1, 0.1)))
	n.add_child(_p(_sphere(0.62), m, Vector3(0.85, -0.05, -0.1)))
	n.add_child(_p(_sphere(0.5), m, Vector3(0.3, 0.35, 0.2)))
	n.add_child(_p(_sphere(0.48), m, Vector3(-0.35, 0.3, -0.2)))
	n.scale = Vector3(1.6, 1.6, 1.6)
	return n

func _penguin() -> Node3D:
	var n := Node3D.new()
	var body := _p(_sphere(0.6), _glossy(Color(0.10, 0.11, 0.14)), Vector3(0, 0.62, 0))
	body.scale = Vector3(1.0, 1.25, 0.92)
	n.add_child(body)
	var belly := _p(_sphere(0.42), _glossy(Color(0.95, 0.95, 0.96)), Vector3(0, 0.56, 0.34))
	belly.scale = Vector3(1.0, 1.2, 0.5)
	n.add_child(belly)
	n.add_child(_p(_cyl(0.0, 0.14, 0.28), _glossy(Color(0.95, 0.62, 0.15)), Vector3(0, 0.62, 0.62), Vector3(90, 0, 0)))
	n.add_child(_p(_sphere(0.1), _glossy(Color(0.95, 0.95, 0.96)), Vector3(0.2, 0.95, 0.45)))
	n.add_child(_p(_sphere(0.1), _glossy(Color(0.95, 0.95, 0.96)), Vector3(-0.2, 0.95, 0.45)))
	n.add_child(_p(_box(0.28, 0.06, 0.3), _glossy(Color(0.95, 0.62, 0.15)), Vector3(0.2, 0.03, 0.25)))
	n.add_child(_p(_box(0.28, 0.06, 0.3), _glossy(Color(0.95, 0.62, 0.15)), Vector3(-0.2, 0.03, 0.25)))
	n.scale = Vector3(1.5, 1.5, 1.5)
	return n

func _mug() -> Node3D:
	var n := Node3D.new()
	var col := Color(0.85, 0.3, 0.25)
	n.add_child(_p(_cyl(0.45, 0.4, 0.8), _glossy(col), Vector3(0, 0.4, 0)))
	n.add_child(_p(_cyl(0.4, 0.4, 0.06), _glossy(Color(0.20, 0.12, 0.06)), Vector3(0, 0.8, 0)))
	n.add_child(_p(_torus(0.07, 0.15), _glossy(col), Vector3(0.48, 0.42, 0), Vector3(0, 0, 90)))
	n.scale = Vector3(1.8, 1.8, 1.8)
	return n

func _gear() -> Node3D:
	var n := Node3D.new()
	var col := _glossy(Color(0.55, 0.58, 0.64))
	n.add_child(_p(_cyl(0.55, 0.55, 0.3), col, Vector3.ZERO))
	n.add_child(_p(_cyl(0.2, 0.2, 0.34), _glossy(Color(0.18, 0.19, 0.22)), Vector3.ZERO))
	for k in 8:
		var ang := k * TAU / 8.0
		var tooth := _p(_box(0.22, 0.34, 0.22), col, Vector3(cos(ang) * 0.62, 0, sin(ang) * 0.62))
		tooth.rotation.y = -ang
		n.add_child(tooth)
	n.scale = Vector3(1.4, 1.4, 1.4)
	return n

func _build_heli() -> void:
	_heli = Node3D.new()
	var col := _glossy(Color(0.85, 0.78, 0.2))
	_heli.add_child(_p(_sphere(0.55), col, Vector3(0, 0, 0)))
	var body := _p(_cyl(0.3, 0.45, 1.3), col, Vector3(0, 0, 0.2), Vector3(90, 0, 0))
	_heli.add_child(body)
	_heli.add_child(_p(_box(0.18, 0.18, 1.6), col, Vector3(0, 0.15, -1.0)))
	_heli.add_child(_p(_sphere(0.32), _glass(Color(0.5, 0.75, 0.95)), Vector3(0, 0.05, 0.55)))
	_heli.add_child(_p(_cyl(0.06, 0.06, 0.5), _glossy(Color(0.2, 0.2, 0.22)), Vector3(0, 0.4, 0)))
	_heli_main = Node3D.new()
	_heli_main.position = Vector3(0, 0.65, 0)
	_heli_main.add_child(_p(_box(3.4, 0.05, 0.18), _glossy(Color(0.15, 0.15, 0.18)), Vector3.ZERO))
	_heli_main.add_child(_p(_box(0.18, 0.05, 3.4), _glossy(Color(0.15, 0.15, 0.18)), Vector3.ZERO))
	_heli.add_child(_heli_main)
	_heli_tail = Node3D.new()
	_heli_tail.position = Vector3(0.18, 0.15, -1.75)
	_heli_tail.add_child(_p(_box(0.08, 0.7, 0.05), _glossy(Color(0.15, 0.15, 0.18)), Vector3.ZERO))
	_heli.add_child(_heli_tail)
	_heli.scale = Vector3(1.2, 1.2, 1.2)
	add_child(_heli)

func _model(path: String, scale: float, fallback: Callable) -> Node3D:
	var ps = load(path)
	if ps == null:
		return fallback.call()
	var root := Node3D.new()
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	root.scale = Vector3(scale, scale, scale)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var ap: AnimationPlayer = aps[0]
		var anims := ap.get_animation_list()
		if anims.size() > 0:
			var an := ap.get_animation(anims[0])
			an.loop_mode = Animation.LOOP_LINEAR
			ap.play(anims[0])
	return root

func _tree(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(1.4, 2.4)
	n.add_child(_p(_cyl(0.13, 0.18, h), _glossy(Color(0.34, 0.24, 0.15)), Vector3(0, h * 0.5, 0)))
	var green := _glossy(Color(0.20, 0.36, 0.22).lightened(rng.randf_range(0.0, 0.10)))
	n.add_child(_p(_sphere(0.75), green, Vector3(0, h + 0.4, 0)))
	n.add_child(_p(_sphere(0.55), green, Vector3(0.35, h + 0.1, 0.2)))
	n.add_child(_p(_sphere(0.5), green, Vector3(-0.3, h + 0.2, -0.25)))
	n.scale = Vector3(0.82, 0.82, 0.82)
	return n

func _bush(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var green := _glossy(Color(0.21, 0.36, 0.23).lightened(rng.randf_range(0.0, 0.10)))
	n.add_child(_p(_sphere(0.5), green, Vector3(0, 0.35, 0)))
	n.add_child(_p(_sphere(0.4), green, Vector3(0.4, 0.3, 0.1)))
	n.add_child(_p(_sphere(0.38), green, Vector3(-0.35, 0.28, -0.1)))
	n.scale = Vector3(0.82, 0.82, 0.82)
	return n

func _lamppost() -> Node3D:
	var n := Node3D.new()
	var metal := _glossy(Color(0.24, 0.25, 0.3))
	n.add_child(_p(_cyl(0.08, 0.12, 2.6), metal, Vector3(0, 1.3, 0)))
	n.add_child(_p(_box(0.7, 0.08, 0.08), metal, Vector3(0.3, 2.55, 0)))
	n.add_child(_p(_sphere(0.16), _emissive(Color(1.0, 0.86, 0.5), 3.5), Vector3(0.6, 2.5, 0)))
	n.scale = Vector3(1.2, 1.2, 1.2)
	return n

func _rocket() -> Node3D:
	var n := Node3D.new()
	n.add_child(_p(_cyl(1.0, 1.0, 0.3), _glossy(Color(0.3, 0.31, 0.36)), Vector3(0, 0.15, 0)))
	for part in ["rocket_baseA", "rocket_finsA", "rocket_topA"]:
		var m: PackedScene = load(MODELS + part + ".glb")
		if m != null:
			n.add_child(m.instantiate())
	n.scale = Vector3(3.0, 3.0, 3.0)
	return n

func _gitgraph() -> Node3D:
	var n := Node3D.new()
	var line := _glossy(Color(0.55, 0.58, 0.64))
	var prev := Vector3.ZERO
	for k in 4:
		var pt := Vector3(0, k * 0.55, 0)
		n.add_child(_p(_sphere(0.16), _glossy(Color(0.9, 0.55, 0.2)), pt))
		if k > 0:
			n.add_child(_link(prev, pt, line))
		prev = pt
	var br := Vector3(0.7, 0.55 * 2.0, 0)
	n.add_child(_p(_sphere(0.14), _glossy(Color(0.4, 0.82, 0.5)), br))
	n.add_child(_link(Vector3(0, 0.55, 0), br, _glossy(Color(0.4, 0.82, 0.5))))
	n.add_child(_link(br, Vector3(0, 0.55 * 3.0, 0), line))
	n.scale = Vector3(1.7, 1.7, 1.7)
	return n

func _monitor() -> Node3D:
	var n := Node3D.new()
	n.add_child(_p(_cyl(0.12, 0.2, 0.5), _glossy(Color(0.2, 0.2, 0.24)), Vector3(0, 0.25, 0)))
	n.add_child(_p(_box(1.9, 1.25, 0.12), _glossy(Color(0.1, 0.11, 0.14)), Vector3(0, 1.05, 0)))
	n.add_child(_p(_box(1.7, 1.05, 0.02), _emissive(Color(0.12, 0.14, 0.18), 1.0), Vector3(0, 1.05, 0.08)))
	n.add_child(_p(_box(1.5, 0.16, 0.01), _emissive(Color(0.3, 0.6, 0.95), 2.2), Vector3(0, 1.42, 0.1)))
	n.add_child(_p(_box(0.5, 0.5, 0.01), _emissive(Color(0.95, 0.6, 0.3), 2.0), Vector3(-0.48, 0.95, 0.1)))
	for k in 3:
		n.add_child(_p(_box(0.7, 0.08, 0.01), _emissive(Color(0.72, 0.74, 0.8), 1.6), Vector3(0.32, 1.12 - k * 0.2, 0.1)))
	n.add_child(_p(_box(0.42, 0.18, 0.01), _emissive(Color(0.4, 0.85, 0.5), 2.4), Vector3(0.32, 0.62, 0.1)))
	n.scale = Vector3(1.4, 1.4, 1.4)
	return n

func _robot() -> Node3D:
	var n := Node3D.new()
	var body := _glossy(Color(0.72, 0.74, 0.8))
	var eye := _emissive(Color(0.3, 0.9, 1.0), 3.2)
	n.add_child(_p(_box(0.9, 1.0, 0.6), body, Vector3(0, 0.85, 0)))
	n.add_child(_p(_box(0.7, 0.6, 0.55), _glossy(Color(0.56, 0.58, 0.64)), Vector3(0, 1.6, 0)))
	n.add_child(_p(_sphere(0.1), eye, Vector3(-0.16, 1.62, 0.3)))
	n.add_child(_p(_sphere(0.1), eye, Vector3(0.16, 1.62, 0.3)))
	n.add_child(_p(_cyl(0.04, 0.04, 0.3), _glossy(Color(0.3, 0.3, 0.34)), Vector3(0, 2.05, 0)))
	n.add_child(_p(_sphere(0.08), _emissive(Color(1.0, 0.3, 0.3), 3.2), Vector3(0, 2.25, 0)))
	n.add_child(_p(_box(0.2, 0.75, 0.2), body, Vector3(-0.6, 0.8, 0)))
	n.add_child(_p(_box(0.2, 0.75, 0.2), body, Vector3(0.6, 0.8, 0)))
	n.add_child(_p(_box(0.3, 0.45, 0.35), _glossy(Color(0.5, 0.52, 0.58)), Vector3(-0.25, 0.22, 0)))
	n.add_child(_p(_box(0.3, 0.45, 0.35), _glossy(Color(0.5, 0.52, 0.58)), Vector3(0.25, 0.22, 0)))
	n.scale = Vector3(1.3, 1.3, 1.3)
	return n

func _link(a: Vector3, b: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var mi := _p(_cyl(0.045, 0.045, length), mat, mid)
	var d := (b - a).normalized()
	var axis := Vector3.UP.cross(d)
	if axis.length() > 0.001:
		mi.rotate(axis.normalized(), Vector3.UP.angle_to(d))
	return mi

# ---------- mesh helpers ----------

func _p(mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
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

func _glossy(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	m.metallic = 0.1
	return m

func _glass(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	return m

func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m
