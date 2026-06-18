extends Node

var _fails := 0

func _ready() -> void:
	print("\n===== VERIFICACION MOD SYSTEM =====")
	var rep := Registry.report()
	_check("carga sin errores", rep.errors.is_empty(), rep.summary())

	var challenges := Registry.ids("challenge")
	_check("retos base+mod (7)", challenges.size() == 7, "size=%d" % challenges.size())

	var pool := Registry.tag("challenge", "bugopoly:pool")
	_check("tag cross-pack incluye el reto del mod (via #c:)",
		pool.has("qa_extras:test_pyramid"), str(pool))

	var bug := Registry.get_def("card", "bugopoly:bug")
	var entries: Array = bug.get("entries", [])
	_check("patch agrego una entrada al mazo de bugs (7)", entries.size() == 7, "size=%d" % entries.size())
	_check("patch agrego la entrada correcta",
		entries.size() == 7 and int(entries[6].get("money", 0)) == -250, "")

	var fe := Registry.get_def("subsystem", "bugopoly:frontend")
	_check("override de color por el mod (#ff4081)", str(fe.get("color")) == "#ff4081", str(fe.get("color")))

	var board := Registry.get_def("board", "bugopoly:main")
	_check("tablero con 24 casillas", board.get("tiles", []).size() == 24, "")

	print("===================================")
	if _fails == 0:
		print("TODO OK ✓  (mod system funcionando)")
	else:
		print("%d FALLO(S) ✗" % _fails)
	get_tree().quit(_fails)

func _check(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("  [OK] ", name)
	else:
		print("  [FALLA] ", name, "  -> ", detail)
		_fails += 1
