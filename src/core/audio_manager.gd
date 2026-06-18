extends Node

const Brand = preload("res://src/ui/palette.gd")
const DIR := "res://assets/bugopoly/sounds/"
const SOUNDS := [
	"dice1", "dice2", "dice3", "coin1", "coin2", "buy", "build", "card", "shuffle", "click", "win",
	"deploy", "zap", "blip",
	"v_go", "v_correct", "v_wrong", "v_game_over",
	"v_mission_completed", "v_mission_failed", "v_power_up", "v_new_highscore",
]

var _sfx: Dictionary = {}
var _players: Array = []
var _next := 0
var _music: AudioStreamPlayer

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	for s in SOUNDS:
		var stream = _load_sound(s)
		if stream != null:
			_sfx[s] = stream
	for i in 12:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_players.append(pl)
	_start_music()

func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")

func _start_music() -> void:
	var path := "res://assets/bugopoly/music/bg.ogg"
	var stream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	else:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			stream = AudioStreamOggVorbis.load_from_file(abs_path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -10.0
	_music.bus = "Music"
	add_child(_music)
	_music.play()

func _load_sound(s: String):
	# Carga importada si existe; si no, en runtime (no requiere importar).
	var p := DIR + s + ".ogg"
	if ResourceLoader.exists(p):
		return load(p)
	var abs_path := ProjectSettings.globalize_path(p)
	if FileAccess.file_exists(abs_path):
		var st = AudioStreamOggVorbis.load_from_file(abs_path)
		if st != null:
			st.loop = false
		return st
	return null

func play(name: String, vol_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if not _sfx.has(name):
		return
	var pl: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = _sfx[name]
	pl.volume_db = vol_db
	pl.pitch_scale = pitch
	pl.bus = bus
	pl.play()

func dice() -> void:
	play(["dice1", "dice2", "dice3"][randi() % 3], -1.0, randf_range(0.95, 1.08))

func coin() -> void:
	play(["coin1", "coin2"][randi() % 2], -3.0, randf_range(0.96, 1.06))

func voice(name: String) -> void:
	play(name, 1.0, 1.0, "Voice")

# ---------- panel de volumen (música / sonidos / voces) ----------

func build_volume_panel() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(_vol_row("Música", "Music"))
	vb.add_child(_vol_row("Sonidos", "SFX"))
	vb.add_child(_vol_row("Voces", "Voice"))
	return vb

func _vol_row(label: String, bus: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(130, 0)
	l.add_theme_color_override("font_color", Brand.TEXT_BODY)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(210, 0)
	var idx := AudioServer.get_bus_index(bus)
	s.value = db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx >= 0 else 1.0
	s.value_changed.connect(_set_bus_vol.bind(bus))
	h.add_child(s)
	return h

func _set_bus_vol(v: float, bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
