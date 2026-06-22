extends SceneTree
# Construye el APK de Android. En Godot 4.6.3 el `can_export` del CLI tiene un bug que
# rechaza el preset Android sin decir el motivo; export_project() directo lo esquiva y SÍ funciona.
# Uso:  ANDROID_HOME=~/Android/Sdk DISPLAY=:0 .godot-bin/godot --editor --path . -s tools/export_android.gd
func _initialize():
	var p = ClassDB.instantiate("EditorExportPlatformAndroid")
	if p == null:
		printerr("No se pudo instanciar EditorExportPlatformAndroid"); quit(1); return
	var preset = p.create_preset()
	preset.set("gradle_build/use_gradle_build", false)  # prebuilt: no necesita android/build
	preset.set("architectures/arm64-v8a", true)
	preset.set("package/unique_name", "com.bugopoly.game")
	preset.set("package/name", "Bugopoly")
	preset.set("version/code", 1)
	preset.set("version/name", "1.0")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var outp = ProjectSettings.globalize_path("res://build/bugopoly.apk")
	p.clear_messages()
	var err = p.export_project(preset, true, outp, 0)  # debug=true -> firmado con la debug key
	print(">> APK err=", err, " msgs=", p.get_message_count())
	for i in p.get_message_count(): print("   ", p.get_message_text(i))
	if err == OK: print(">> OK: ", outp)
	quit(0 if err == OK else 1)
