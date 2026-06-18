extends Node

var players: Array = []
var board: Dictionary = {}
var ownership: Dictionary = {}
var houses: Dictionary = {}
var current: int = 0
var turn: int = 0
var pending_configs: Array = []

func setup(configs: Array, board_id: String) -> void:
	board = Registry.get_def("board", board_id)
	players.clear()
	ownership.clear()
	houses.clear()
	current = 0
	turn = 0
	var start := int(board.get("start_budget", 1500))
	var i := 0
	for c in configs:
		var p := BPlayer.new()
		p.id = i
		p.pname = str(c.get("name", "J%d" % (i + 1)))
		p.is_bot = bool(c.get("is_bot", false))
		p.color = c.get("color", Color.WHITE)
		p.piece = str(c.get("piece", ""))
		p.budget = start
		players.append(p)
		i += 1

func tiles() -> Array:
	return board.get("tiles", [])

func tile_count() -> int:
	return tiles().size()

func tile_at(idx: int) -> Dictionary:
	return tiles()[posmod(idx, tile_count())]

func current_player() -> BPlayer:
	return players[current]

func owner_of(idx: int) -> int:
	return int(ownership.get(idx, -1))

func house_count(idx: int) -> int:
	return int(houses.get(idx, 0))

func go_reward() -> int:
	return int(board.get("go_reward", 200))

func find_tile_type(type: String) -> int:
	var t := tiles()
	for i in t.size():
		if str(t[i].get("type", "")) == type:
			return i
	return -1

func advance_turn() -> void:
	for _i in players.size():
		current = (current + 1) % players.size()
		if not players[current].bankrupt:
			break
	turn += 1

func active_players() -> int:
	var c := 0
	for p in players:
		if not p.bankrupt:
			c += 1
	return c

func winner() -> BPlayer:
	for p in players:
		if not p.bankrupt:
			return p
	return players[0]
