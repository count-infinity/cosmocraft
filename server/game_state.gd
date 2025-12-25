class_name GameState
extends RefCounted

# All connected players by ID
var players: Dictionary = {}

# Current server tick
var current_tick: int = 0

# Track last processed input sequence per player
var last_processed_input: Dictionary = {}

func add_player(player_id: String, player_name: String) -> PlayerState:
	var player := PlayerState.new(player_id, player_name)
	# Spawn near chunk 0,0
	player.position = Vector2(
		GameConstants.PLAYER_SPAWN_X,
		GameConstants.PLAYER_SPAWN_Y
	)
	players[player_id] = player
	last_processed_input[player_id] = 0
	return player

func remove_player(player_id: String) -> bool:
	if players.has(player_id):
		players.erase(player_id)
		last_processed_input.erase(player_id)
		return true
	return false

func get_player(player_id: String) -> PlayerState:
	return players.get(player_id)

func has_player(player_id: String) -> bool:
	return players.has(player_id)

func get_player_count() -> int:
	return players.size()

func get_all_player_ids() -> Array:
	return players.keys()

func set_last_processed_input(player_id: String, sequence: int) -> void:
	last_processed_input[player_id] = sequence

func get_last_processed_input(player_id: String) -> int:
	return last_processed_input.get(player_id, 0)

func increment_tick() -> void:
	current_tick += 1

# Generate a full snapshot of the game state
func get_snapshot() -> Dictionary:
	var players_data := {}
	for player_id in players:
		players_data[player_id] = players[player_id].to_dict()

	return {
		"tick": current_tick,
		"players": players_data
	}

# Generate a delta update (currently same as snapshot, can optimize later)
func get_delta() -> Dictionary:
	var players_data := {}
	for player_id in players:
		var player: PlayerState = players[player_id]
		players_data[player_id] = {
			"position": {"x": player.position.x, "y": player.position.y},
			"velocity": {"x": player.velocity.x, "y": player.velocity.y},
			"aim_angle": player.aim_angle
		}

	return {
		"tick": current_tick,
		"players": players_data
	}
