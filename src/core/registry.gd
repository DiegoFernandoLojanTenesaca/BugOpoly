extends Node

var _content: Dictionary = {}
var _tags: Dictionary = {}
var _raw_tags: Dictionary = {}
var _patches: Array = []
var _mods: Dictionary = {}
var _report: LoadReport = LoadReport.new()

const BASE_ROOT := "res://"
const MOD_DIRS := ["res://mods", "user://mods"]
const DEFAULT_LOCALE := "es"
const PATCH_OPS := ["patch", "if", "conditions", "replace", "remove", "merge_by", "add", "mul"]

func _ready() -> void:
	load_content()

func load_content() -> void:
	_content.clear()
	_tags.clear()
	_raw_tags.clear()
	_patches.clear()
	_mods.clear()
	_report = LoadReport.new()
	var packs := _discover_packs()
	for pack in packs:
		_stage_pack(pack)
	var ctx := _build_ctx()
	_resolve_all_tags(ctx)
	ctx["tags"] = _tags
	_filter_conditional_defs(ctx)
	for type in _content.keys():
		InheritanceResolver.resolve(_content[type], _report)
	_apply_patches(ctx)
	_validate_all()
	for pack in packs:
		_load_lang(pack)
	TranslationServer.set_locale(DEFAULT_LOCALE)
	print("[Registry] ", _summary(), " | mods: ", _mods.keys(), " | ", _report.summary())
	EventBus.content_loaded.emit(_report)

# ---------- discovery / staging ----------

func _discover_packs() -> Array:
	var packs: Array = []
	var base_manifest = _read_json(BASE_ROOT.path_join("mod.json"))
	var base_id := "base"
	if base_manifest is Dictionary:
		base_id = str(base_manifest.get("id", "base"))
		_mods[base_id] = base_manifest
	packs.append({"id": base_id, "root": BASE_ROOT})
	for mdir in MOD_DIRS:
		for sub in _list_dirs(mdir):
			var root: String = String(mdir).path_join(sub)
			var manifest = _read_json(root.path_join("mod.json"))
			if not (manifest is Dictionary):
				continue
			var id := str(manifest.get("id", sub))
			_mods[id] = manifest
			packs.append({"id": id, "root": root})
	return packs

func _stage_pack(pack: Dictionary) -> void:
	var data_root: String = String(pack["root"]).path_join("data")
	for ns in _list_dirs(data_root):
		var ns_root := data_root.path_join(ns)
		for type in _list_dirs(ns_root):
			if type == "lang":
				continue
			var type_root := ns_root.path_join(type)
			if type == "tags":
				_stage_tags(ns, type_root)
			else:
				for f in _list_files(type_root, "json"):
					_stage_file(ns, type, type_root.path_join(f), f.get_basename())

func _stage_file(ns: String, type: String, path: String, fname: String) -> void:
	var data = _read_json(path)
	if data == null:
		_report.error("no se pudo leer %s" % path)
		return
	if data is Array:
		for d in data:
			if d is Dictionary:
				_stage_def(ns, type, d, fname)
		return
	if data is Dictionary:
		if data.has("patch"):
			_stage_patch(ns, type, data)
		else:
			_stage_def(ns, type, data, fname)

func _stage_def(ns: String, type: String, def: Dictionary, fname: String) -> void:
	var raw_id := str(def.get("id", fname))
	var full_id := raw_id if ":" in raw_id else ns + ":" + raw_id
	def["id"] = full_id
	def["__ns"] = ns
	def["__type"] = type
	if def.has("base"):
		var b := str(def["base"])
		def["base"] = b if ":" in b else ns + ":" + b
	if not _content.has(type):
		_content[type] = {}
	if _content[type].has(full_id):
		print("[Registry] override: '%s' (pack posterior)" % full_id)
	_content[type][full_id] = def

func _stage_patch(ns: String, type: String, data: Dictionary) -> void:
	var target := str(data.get("patch", ""))
	if not (":" in target):
		target = ns + ":" + target
	_patches.append({"type": type, "target": target, "data": data})

func _stage_tags(ns: String, tags_root: String) -> void:
	for type in _list_dirs(tags_root):
		var type_root := tags_root.path_join(type)
		for f in _list_files(type_root, "json"):
			var data = _read_json(type_root.path_join(f))
			if not (data is Dictionary):
				continue
			var tag_id: String = ns + ":" + f.get_basename()
			if not _raw_tags.has(type):
				_raw_tags[type] = {}
			if not _raw_tags[type].has(tag_id):
				_raw_tags[type][tag_id] = []
			_raw_tags[type][tag_id].append(data)

# ---------- resolution ----------

func _build_ctx() -> Dictionary:
	var defs := {}
	for type in _content:
		defs[type] = {}
		for id in _content[type]:
			defs[type][id] = true
	var mods := {}
	for id in _mods:
		mods[id] = true
	return {"mods": mods, "defs": defs, "tags": {}}

func _resolve_all_tags(ctx: Dictionary) -> void:
	for type in _raw_tags:
		_tags[type] = {}
		for tag_id in _raw_tags[type]:
			_tags[type][tag_id] = _resolve_tag(type, tag_id, [], ctx)

func _resolve_tag(type: String, tag_id: String, visiting: Array, ctx: Dictionary) -> Array:
	if visiting.has(tag_id):
		_report.warn("ciclo de tag en %s" % tag_id)
		return []
	visiting.append(tag_id)
	var out: Array = []
	for contrib in _raw_tags.get(type, {}).get(tag_id, []):
		if not LoadConditions.passes(LoadConditions.of(contrib), ctx):
			continue
		if bool(contrib.get("replace", false)):
			out.clear()
		for v in contrib.get("values", []):
			_add_tag_value(type, v, out, visiting, ctx)
	visiting.pop_back()
	return out

func _add_tag_value(type: String, v, out: Array, visiting: Array, ctx: Dictionary) -> void:
	if v is String:
		if v.begins_with("#"):
			for id in _resolve_tag(type, v.substr(1), visiting, ctx):
				if not out.has(id):
					out.append(id)
		elif not out.has(v):
			out.append(v)
	elif v is Dictionary:
		if not LoadConditions.passes(LoadConditions.of(v), ctx):
			return
		var id := str(v.get("id", ""))
		var required := bool(v.get("required", true))
		if (required or _content.get(type, {}).has(id)) and not out.has(id):
			out.append(id)

func _filter_conditional_defs(ctx: Dictionary) -> void:
	for type in _content:
		var drop: Array = []
		for id in _content[type]:
			var def: Dictionary = _content[type][id]
			var cond = LoadConditions.of(def)
			if cond != null and not LoadConditions.passes(cond, ctx):
				drop.append(id)
			else:
				def.erase("if")
				def.erase("conditions")
		for id in drop:
			_content[type].erase(id)

func _apply_patches(ctx: Dictionary) -> void:
	for patch in _patches:
		var data: Dictionary = patch["data"]
		var cond = LoadConditions.of(data)
		if cond != null and not LoadConditions.passes(cond, ctx):
			continue
		var type: String = patch["type"]
		var target: String = patch["target"]
		if not _content.get(type, {}).has(target):
			_report.warn("patch sin objetivo: '%s'" % target)
			continue
		_patch_def(_content[type][target], data)

func _patch_def(def: Dictionary, p: Dictionary) -> void:
	var merge_by: Dictionary = p.get("merge_by", {})
	for f in p:
		if f in PATCH_OPS:
			continue
		if merge_by.has(f):
			_patch_merge_by(def, f, p[f], str(merge_by[f]))
		else:
			_patch_merge(def, f, p[f])
	for f in p.get("remove", {}):
		_patch_remove(def, f, p["remove"][f])
	for f in p.get("add", {}):
		def[f] = _num(def.get(f, 0)) + _num(p["add"][f])
	for f in p.get("mul", {}):
		def[f] = _num(def.get(f, 0)) * _num(p["mul"][f])
	for f in p.get("replace", {}):
		def[f] = p["replace"][f]

func _patch_merge(def: Dictionary, f: String, v) -> void:
	if def.has(f) and def[f] is Array and v is Array:
		def[f] = def[f] + v
	elif def.has(f) and def[f] is Dictionary and v is Dictionary:
		_deep_merge(def[f], v)
	else:
		def[f] = v

func _patch_merge_by(def: Dictionary, f: String, arr, key: String) -> void:
	var existing: Array = def.get(f, [])
	for item in arr:
		var hit := false
		for e in existing:
			if e is Dictionary and item is Dictionary and e.get(key) == item.get(key):
				_deep_merge(e, item)
				hit = true
				break
		if not hit:
			existing.append(item)
	def[f] = existing

func _patch_remove(def: Dictionary, f: String, matchers) -> void:
	if not (def.get(f) is Array):
		return
	var kept: Array = []
	for e in def[f]:
		var drop := false
		for m in matchers:
			if _matches(e, m):
				drop = true
				break
		if not drop:
			kept.append(e)
	def[f] = kept

func _validate_all() -> void:
	for type in _content:
		if not ContentSchemas.has_type(type):
			continue
		var schema := ContentSchemas.schema_for(type)
		var drop: Array = []
		for id in _content[type]:
			var def: Dictionary = _content[type][id]
			Schema.apply_defaults(def, schema)
			var errs := Schema.validate(def, schema, id)
			if not errs.is_empty():
				for e in errs:
					_report.error(e)
				drop.append(id)
		for id in drop:
			_content[type].erase(id)

func _load_lang(pack: Dictionary) -> void:
	var data_root: String = String(pack["root"]).path_join("data")
	for ns in _list_dirs(data_root):
		var lang_root := data_root.path_join(ns).path_join("lang")
		for f in _list_files(lang_root, "json"):
			var dict = _read_json(lang_root.path_join(f))
			if not (dict is Dictionary):
				continue
			var tr := Translation.new()
			tr.locale = f.get_basename()
			for k in dict:
				tr.add_message(k, str(dict[k]))
			TranslationServer.add_translation(tr)

# ---------- public API ----------

func get_def(type: String, id: String) -> Dictionary:
	return _content.get(type, {}).get(id, {})

func get_all(type: String) -> Array:
	return _content.get(type, {}).values()

func ids(type: String) -> Array:
	return _content.get(type, {}).keys()

func has(type: String, id: String) -> bool:
	return _content.get(type, {}).has(id)

func tag(type: String, id: String) -> Array:
	return _tags.get(type, {}).get(id, [])

func expand(type: String, list: Array) -> Array:
	var out: Array = []
	for v in list:
		if v is String and v.begins_with("#"):
			for id in tag(type, v.substr(1)):
				if not out.has(id):
					out.append(id)
		elif not out.has(v):
			out.append(v)
	return out

func mods() -> Dictionary:
	return _mods

func report() -> LoadReport:
	return _report

# ---------- helpers ----------

func _deep_merge(a: Dictionary, b: Dictionary) -> void:
	for k in b:
		if a.has(k) and a[k] is Dictionary and b[k] is Dictionary:
			_deep_merge(a[k], b[k])
		else:
			a[k] = b[k]

func _matches(elem, matcher) -> bool:
	if matcher is Dictionary and elem is Dictionary:
		for k in matcher:
			if elem.get(k) != matcher[k]:
				return false
		return true
	return elem == matcher

func _num(v) -> float:
	if v is float or v is int:
		return float(v)
	return 0.0

func _summary() -> String:
	var parts: Array = []
	for type in _content:
		parts.append("%s:%d" % [type, _content[type].size()])
	parts.sort()
	return ", ".join(parts)

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var res = JSON.parse_string(f.get_as_text())
	if res == null:
		_report.warn("JSON invalido: %s" % path)
	return res

func _list_dirs(path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir() and not n.begins_with("."):
			out.append(n)
		n = d.get_next()
	out.sort()
	return out

func _list_files(path: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.to_lower().ends_with("." + ext):
			out.append(n)
		n = d.get_next()
	out.sort()
	return out
