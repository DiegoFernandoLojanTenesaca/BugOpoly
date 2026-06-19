class_name Decor
extends Node3D
## Personajes alrededor/detrás del tablero: persecución al fondo + espectadores
## que entran caminando y luego saludan/pelean/idle. Modelos gltf cargados en runtime.

const CHARS := "res://assets/bugopoly/models/chars/"

var _runners: Array = []
var _t := 0.0

func build(board_half: float) -> void:
	var bh := board_half
	# Escena de fondo DETRÁS del tablero (no tapa la vista): corren de lado a lado.
	var bz := -(bh + 10.0)
	_chase("shaun", "zombie_basic", bz, 0.55, 0.0, bh + 13.0)
	_fight("sam", "Slash", "zombie_chubby", "Attack", Vector3(bh + 7.0, 0, bz - 2.0))
	_runner(_load_char("pug", "Run", 3.0), bz - 3.0, 0.9, 1.5, bh + 12.0)
	# espectadores que entran caminando y enmarcan el tablero
	var bh2 := bh + 6.0
	_spectator("sam", "Wave", Vector3(-bh2, 0, 3.0))
	_spectator("shaun", "Yes", Vector3(bh2, 0, -2.0))
	_spectator("zombie_basic", "Idle_Attack", Vector3(-3.5, 0, -bh2))
	_spectator("zombie_chubby", "Wave", Vector3(3.5, 0, -bh2))
	_spectator("sam", "Punch", Vector3(-bh2, 0, -3.5))
	_spectator("shaun", "Wave", Vector3(bh2, 0, 4.0))
	_spectator("zombie_basic", "Idle", Vector3(bh2, 0, -5.2))
	_spectator("zombie_chubby", "Idle_Attack", Vector3(-bh2, 0, -0.5))
	_spectator("pug", "Idle_2", Vector3(0.0, 0, -bh2))

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

func _spectator(name: String, anim: String, pos: Vector3) -> void:
	var n := _load_char(name, "Walk", 2.2)  # entra caminando
	if n == null:
		return
	n.position = pos * 1.5  # arranca afuera de cámara
	n.rotation.y = atan2(-pos.x, -pos.z)  # camina hacia el tablero
	add_child(n)
	var tw := create_tween()
	tw.tween_interval(randf_range(0.1, 1.0))
	tw.tween_property(n, "position", pos, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_spectator_arrive.bind(n, anim))

func _spectator_arrive(node: Node3D, anim: String) -> void:
	if is_instance_valid(node):
		_play_anim(node, anim)

func _play_anim(node: Node3D, anim: String) -> void:
	for ap in node.find_children("*", "AnimationPlayer", true, false):
		var list: PackedStringArray = ap.get_animation_list()
		var pick := ""
		for a in list:
			if anim in str(a).to_lower():
				pick = a
				break
		if pick == "" and not list.is_empty():
			pick = list[0]
		if pick != "":
			ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
			ap.play(pick)
		return

func _load_char(name: String, anim: String, scale: float) -> Node3D:
	return _load_gltf(CHARS + name + ".gltf", anim, scale)

func _load_gltf(path: String, anim: String, scale: float) -> Node3D:
	var abs_path := ProjectSettings.globalize_path(path)
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
		var list := ap.get_animation_list()
		var pick := ""
		for a in list:
			if anim.to_lower() in str(a).to_lower():
				pick = a
				break
		if pick == "":
			for a in list:
				if "idle" in str(a).to_lower():
					pick = a
					break
		if pick == "" and list.size() > 0:
			pick = list[0]
		if pick != "":
			ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
			ap.play(pick)
	return holder

func _process(delta: float) -> void:
	_t += delta
	for ru in _runners:
		var rn: Node3D = ru["node"]
		var ph: float = _t * ru["speed"] + ru["phase"]
		rn.position = Vector3(sin(ph) * ru["range"], 0.0, ru["z"])  # van de lado a lado al fondo
		rn.rotation.y = PI * 0.5 if cos(ph) >= 0.0 else -PI * 0.5  # miran hacia donde van
