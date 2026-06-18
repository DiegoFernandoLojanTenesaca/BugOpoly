class_name Dice
extends Node3D

const S := 0.95

var _dice: Array = []
var _tex: Array = []

func _ready() -> void:
	for i in 6:
		_tex.append(load("res://assets/bugopoly/textures/dice/dieWhite%d.png" % (i + 1)))
	for d in 2:
		var die := _make_die()
		die.position = Vector3(-0.95 + d * 1.9, 0.7, 0)
		add_child(die)
		_dice.append(die)

func _make_die() -> Node3D:
	var die := Node3D.new()
	var core := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(S * 0.92, S * 0.92, S * 0.92)
	core.mesh = cm
	core.material_override = _white()
	die.add_child(core)
	# value -> (position, rotation_degrees) so that pip face points outward
	var faces := [
		[1, Vector3(0, S * 0.5, 0), Vector3(0, 0, 0)],
		[6, Vector3(0, -S * 0.5, 0), Vector3(180, 0, 0)],
		[2, Vector3(0, 0, S * 0.5), Vector3(90, 0, 0)],
		[5, Vector3(0, 0, -S * 0.5), Vector3(-90, 0, 0)],
		[3, Vector3(S * 0.5, 0, 0), Vector3(0, 0, -90)],
		[4, Vector3(-S * 0.5, 0, 0), Vector3(0, 0, 90)],
	]
	for f in faces:
		var quad := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(S, S)
		quad.mesh = pm
		quad.position = f[1]
		quad.rotation_degrees = f[2]
		quad.material_override = _face(_tex[int(f[0]) - 1])
		die.add_child(quad)
	return die

func roll(values: Array) -> void:
	for d in 2:
		var die: Node3D = _dice[d]
		var rest: Vector3 = die.position
		var tw := create_tween()
		for s in 3:
			tw.tween_property(die, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), 0.14)
		tw.tween_property(die, "rotation", _settle(int(values[d])), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var twp := create_tween()
		twp.tween_property(die, "position:y", rest.y + 2.2, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		twp.tween_property(die, "position:y", rest.y, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		twp.tween_property(die, "position:y", rest.y + 0.22, 0.1).set_ease(Tween.EASE_OUT)
		twp.tween_property(die, "position:y", rest.y, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.82).timeout

func _settle(v: int) -> Vector3:
	match clampi(v, 1, 6):
		1: return Vector3.ZERO
		6: return Vector3(PI, 0, 0)
		2: return Vector3(-PI / 2, 0, 0)
		5: return Vector3(PI / 2, 0, 0)
		3: return Vector3(0, 0, PI / 2)
		_: return Vector3(0, 0, -PI / 2)

func _white() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.97, 0.97, 0.98)
	m.roughness = 0.5
	return m

func _face(tex) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(0.97, 0.97, 0.98)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.5
	return m
