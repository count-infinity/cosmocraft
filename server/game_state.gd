class_name GameState
extends RefCounted

# All connected players by ID
var players: Dictionary = {}

# Current server tick
var current_tick: int = 0

# Track last processed input sequence per player
var last_processed_input: Dictionary = {}

# All ground items by ID
var ground_items: Dictionary = {}  # id -> WorldItem

# Signal for ground item events (for broadcasting)
signal ground_item_spawned(world_item: WorldItem)
signal ground_item_removed(item_id: String, reason: String)

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


# ===== Ground Item Management =====

## Spawn a new item on the ground
## Returns the WorldItem instance
func spawn_ground_item(item_stack: ItemStack, position: Vector2, owner_id: String = "") -> WorldItem:
	var item_id := WorldItem.generate_id()
	var world_item := WorldItem.new(item_id, item_stack, position, owner_id)

	ground_items[item_id] = world_item
	ground_item_spawned.emit(world_item)

	return world_item


## Remove a ground item by ID
## Returns true if the item existed and was removed
func remove_ground_item(item_id: String, reason: String = "pickup") -> bool:
	if not ground_items.has(item_id):
		return false

	ground_items.erase(item_id)
	ground_item_removed.emit(item_id, reason)
	return true


## Get a ground item by ID
func get_ground_item(item_id: String) -> WorldItem:
	return ground_items.get(item_id)


## Check if a ground item exists
func has_ground_item(item_id: String) -> bool:
	return ground_items.has(item_id)


## Get all ground items within a radius of a position
func get_ground_items_near(position: Vector2, radius: float) -> Array:
	var nearby: Array = []
	var radius_sq := radius * radius

	for item_id in ground_items:
		var world_item: WorldItem = ground_items[item_id]
		var dist_sq := position.distance_squared_to(world_item.position)
		if dist_sq <= radius_sq:
			nearby.append(world_item)

	return nearby


## Get all ground items (for initial sync)
func get_all_ground_items() -> Array:
	return ground_items.values()


## Process despawn timers - call this periodically
## Returns an array of item IDs that were despawned
func process_despawn_timers() -> Array:
	var despawned: Array = []

	for item_id in ground_items.keys():
		var world_item: WorldItem = ground_items[item_id]
		if world_item.is_despawned():
			despawned.append(item_id)

	# Remove despawned items
	for item_id in despawned:
		remove_ground_item(item_id, "despawn")

	return despawned
