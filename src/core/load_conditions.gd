class_name LoadConditions
extends RefCounted

static func of(data: Dictionary):
	if data.has("if"):
		return data["if"]
	if data.has("conditions"):
		return data["conditions"]
	return null

static func passes(cond, ctx: Dictionary) -> bool:
	if cond == null:
		return true
	if cond is Array:
		for c in cond:
			if not passes(c, ctx):
				return false
		return true
	if cond is Dictionary:
		if cond.has("mod"):
			return ctx.get("mods", {}).has(cond["mod"])
		if cond.has("not"):
			return not passes(cond["not"], ctx)
		if cond.has("and"):
			for c in cond["and"]:
				if not passes(c, ctx):
					return false
			return true
		if cond.has("or"):
			for c in cond["or"]:
				if passes(c, ctx):
					return true
			return false
		if cond.has("def"):
			var d = cond["def"]
			return ctx.get("defs", {}).get(str(d.get("type", "")), {}).has(str(d.get("id", "")))
		if cond.has("tag_empty"):
			var tg = cond["tag_empty"]
			var ids = ctx.get("tags", {}).get(str(tg.get("type", "")), {}).get(str(tg.get("id", "")), [])
			return ids.is_empty()
	return true
