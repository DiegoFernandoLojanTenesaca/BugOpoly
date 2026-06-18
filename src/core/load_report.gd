class_name LoadReport
extends RefCounted

var errors: Array = []
var warnings: Array = []

func error(msg: String) -> void:
	errors.append(msg)
	push_error("[Bugopoly] " + msg)

func warn(msg: String) -> void:
	warnings.append(msg)
	push_warning("[Bugopoly] " + msg)

func ok() -> bool:
	return errors.is_empty()

func summary() -> String:
	return "%d errores, %d avisos" % [errors.size(), warnings.size()]
