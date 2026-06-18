class_name InheritanceResolver
extends RefCounted

static func resolve(defs: Dictionary, report: LoadReport) -> void:
	var done: Dictionary = {}
	for id in defs.keys():
		_resolve_one(id, defs, done, [], report)

static func _resolve_one(id: String, defs: Dictionary, done: Dictionary, stack: Array, report: LoadReport) -> Dictionary:
	if done.has(id):
		return defs.get(id, {})
	if not defs.has(id):
		return {}
	var def: Dictionary = defs[id]
	var base_id := str(def.get("base", ""))
	if base_id == "":
		done[id] = true
		return def
	if stack.has(id):
		report.warn("ciclo de herencia en '%s'" % id)
		def.erase("base")
		done[id] = true
		return def
	if not defs.has(base_id):
		report.warn("'%s': base '%s' no existe" % [id, base_id])
		def.erase("base")
		done[id] = true
		return def
	stack.append(id)
	var parent := _resolve_one(base_id, defs, done, stack, report).duplicate(true)
	stack.pop_back()
	for k in def:
		if k == "base":
			continue
		parent[k] = def[k]
	defs[id] = parent
	done[id] = true
	return parent
