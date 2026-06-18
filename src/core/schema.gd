class_name Schema
extends RefCounted

static func validate(def: Dictionary, schema: Dictionary, id: String) -> Array:
	var errs: Array = []
	for field in schema:
		var rule: Dictionary = schema[field]
		if not def.has(field):
			if bool(rule.get("required", false)):
				errs.append("%s: falta el campo requerido '%s'" % [id, field])
			continue
		var val = def[field]
		var t: String = str(rule.get("type", ""))
		if t != "" and not _type_ok(val, t):
			errs.append("%s: el campo '%s' deberia ser %s" % [id, field, t])
		var values = rule.get("values", [])
		if values is Array and not values.is_empty() and not values.has(val):
			errs.append("%s: '%s'='%s' no esta en %s" % [id, field, str(val), str(values)])
	return errs

static func apply_defaults(def: Dictionary, schema: Dictionary) -> void:
	for field in schema:
		var rule: Dictionary = schema[field]
		if rule.has("default") and not def.has(field):
			def[field] = rule["default"]

static func _type_ok(v, t: String) -> bool:
	match t:
		"string": return v is String
		"int": return v is int or (v is float and v == floor(v))
		"float", "number": return v is float or v is int
		"bool": return v is bool
		"array": return v is Array
		"dict": return v is Dictionary
		_: return true
