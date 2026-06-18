class_name CameraRig
extends Node3D

const FOV := 36.0
const PITCH := 54.0
const DIST_OVERVIEW := 38.0
const DIST_FOCUS := 22.0
const LOOK_OFFSET := Vector3(0, 0, 2.0)

var _cam: Camera3D
var _dir: Vector3
var _center := Vector3.ZERO
var _dist := DIST_OVERVIEW
var _t_center := Vector3.ZERO
var _t_dist := DIST_OVERVIEW
var _shake := 0.0

func shake(amt := 0.2) -> void:
	_shake = maxf(_shake, amt)

func _ready() -> void:
	_dir = Vector3(0, sin(deg_to_rad(PITCH)), cos(deg_to_rad(PITCH))).normalized()
	_cam = Camera3D.new()
	_cam.fov = FOV
	add_child(_cam)
	_apply()

func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta / 1.1)
	_center = _center.lerp(_t_center, k)
	_dist = lerpf(_dist, _t_dist, k)
	_shake = move_toward(_shake, 0.0, delta * 0.9)
	_apply()

func _apply() -> void:
	var look := _center + LOOK_OFFSET
	var off := Vector3.ZERO
	if _shake > 0.001:
		off = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_cam.global_position = look + _dir * _dist + off
	_cam.look_at(look, Vector3.UP)

func overview() -> void:
	_t_center = Vector3.ZERO
	_t_dist = DIST_OVERVIEW

func focus(pos: Vector3) -> void:
	_t_center = Vector3(pos.x, 0, pos.z)
	_t_dist = DIST_FOCUS
