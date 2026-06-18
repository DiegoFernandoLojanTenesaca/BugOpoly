extends Node

func _ready() -> void:
	var target := "res://src/world/main.tscn"
	if OS.has_environment("SHOT_TARGET"):
		target = OS.get_environment("SHOT_TARGET")
	var main: Node = load(target).instantiate()
	add_child(main)
	var delay := 3.0
	if OS.has_environment("SHOT_DELAY"):
		delay = float(OS.get_environment("SHOT_DELAY"))
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := "res://.shot.png"
	if OS.has_environment("SHOT_OUT"):
		out = OS.get_environment("SHOT_OUT")
	img.save_png(out)
	print("SHOT saved -> ", ProjectSettings.globalize_path(out))
	get_tree().quit()
