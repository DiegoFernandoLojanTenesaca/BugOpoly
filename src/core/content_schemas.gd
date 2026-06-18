class_name ContentSchemas
extends RefCounted

const BY_TYPE := {
	"challenge": {
		"prompt": {"type": "string", "required": true},
		"options": {"type": "array", "required": true},
		"answer": {"type": "int", "required": true},
		"reward": {"type": "int", "default": 120},
		"penalty": {"type": "int", "default": 60},
		"explain": {"type": "string", "default": ""},
		"topic": {"type": "string", "default": ""}
	},
	"card": {
		"name": {"type": "string", "required": true},
		"kind": {"type": "string", "values": ["bug", "retro"], "required": true},
		"entries": {"type": "array", "required": true}
	},
	"board": {
		"name": {"type": "string", "default": ""},
		"tiles": {"type": "array", "required": true},
		"start_budget": {"type": "int", "default": 1500},
		"go_reward": {"type": "int", "default": 200}
	},
	"subsystem": {
		"name": {"type": "string", "required": true},
		"color": {"type": "string", "default": "#cccccc"}
	},
	"piece": {
		"name": {"type": "string", "required": true},
		"color": {"type": "string", "default": "#ffffff"},
		"model": {"type": "string", "default": ""}
	}
}

static func has_type(t: String) -> bool:
	return BY_TYPE.has(t)

static func schema_for(t: String) -> Dictionary:
	return BY_TYPE.get(t, {})

static func types() -> Array:
	return BY_TYPE.keys()
