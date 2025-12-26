class_name Serialization
extends RefCounted

# Encode a message to JSON string
static func encode_message(type: String, data: Dictionary) -> String:
	var message := {
		"type": type,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	}
	return JSON.stringify(message)

# Decode a JSON string to message dictionary
# Returns null if invalid
static func decode_message(json_string: String) -> Variant:
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		printerr("Serialization: Failed to parse JSON: " + json.get_error_message())
		return null

	var result = json.get_data()
	if not result is Dictionary:
		printerr("Serialization: Expected Dictionary, got " + str(typeof(result)))
		return null

	if not result.has("type"):
		printerr("Serialization: Missing 'type' field")
		return null

	if not result.has("data"):
		printerr("Serialization: Missing 'data' field")
		return null

	return result

# Helper to create a connect_request message
static func encode_connect_request(player_name: String) -> String:
	return encode_message(MessageTypes.CONNECT_REQUEST, {
		"player_name": player_name
	})

# Helper to create a player_input message
static func encode_player_input(sequence: int, move_direction: Vector2, aim_angle: float, actions: Array = []) -> String:
	return encode_message(MessageTypes.PLAYER_INPUT, {
		"sequence": sequence,
		"move_direction": {"x": move_direction.x, "y": move_direction.y},
		"aim_angle": aim_angle,
		"actions": actions
	})

# Helper to create a ping message
static func encode_ping() -> String:
	return encode_message(MessageTypes.PING, {
		"client_time": Time.get_ticks_msec()
	})

# Helper to create a connect_response message
static func encode_connect_response(success: bool, player_id: String, server_tick: int, error_message: String = "") -> String:
	return encode_message(MessageTypes.CONNECT_RESPONSE, {
		"success": success,
		"player_id": player_id,
		"server_tick": server_tick,
		"tick_rate": GameConstants.TICK_RATE,
		"error": error_message
	})

# Helper to create a game_state message (full snapshot)
static func encode_game_state(tick: int, players: Dictionary) -> String:
	var players_data := {}
	for player_id in players:
		var player: PlayerState = players[player_id]
		players_data[player_id] = player.to_dict()

	return encode_message(MessageTypes.GAME_STATE, {
		"tick": tick,
		"players": players_data
	})

# Helper to create a state_delta message
static func encode_state_delta(tick: int, last_processed_input: int, players: Dictionary) -> String:
	var players_data := {}
	for player_id in players:
		var player: PlayerState = players[player_id]
		players_data[player_id] = {
			"position": {"x": player.position.x, "y": player.position.y},
			"velocity": {"x": player.velocity.x, "y": player.velocity.y},
			"aim_angle": player.aim_angle
		}

	return encode_message(MessageTypes.STATE_DELTA, {
		"tick": tick,
		"last_processed_input": last_processed_input,
		"players": players_data
	})

# Helper to create a player_joined message
static func encode_player_joined(player: PlayerState) -> String:
	return encode_message(MessageTypes.PLAYER_JOINED, player.to_dict())

# Helper to create a player_left message
static func encode_player_left(player_id: String) -> String:
	return encode_message(MessageTypes.PLAYER_LEFT, {
		"player_id": player_id
	})

# Helper to create a pong message
static func encode_pong(client_time: int) -> String:
	return encode_message(MessageTypes.PONG, {
		"client_time": client_time,
		"server_time": Time.get_ticks_msec()
	})

# Helper to create an error message
static func encode_error(error_message: String) -> String:
	return encode_message(MessageTypes.ERROR, {
		"message": error_message
	})

# Parse player input from decoded message data
static func parse_player_input(data: Dictionary) -> Dictionary:
	var move_dir = data.get("move_direction", {})
	return {
		"sequence": data.get("sequence", 0),
		"move_direction": Vector2(move_dir.get("x", 0.0), move_dir.get("y", 0.0)),
		"aim_angle": data.get("aim_angle", 0.0),
		"actions": data.get("actions", [])
	}

# ===== Chunk Network Messages =====

# Client requests chunks around a position
static func encode_chunk_request(world_x: int, world_y: int, radius: int = 2) -> String:
	return encode_message(MessageTypes.CHUNK_REQUEST, {
		"world_x": world_x,
		"world_y": world_y,
		"radius": radius
	})

# Client requests to modify a tile
static func encode_tile_modify(world_x: int, world_y: int, tile_type: int) -> String:
	return encode_message(MessageTypes.TILE_MODIFY, {
		"world_x": world_x,
		"world_y": world_y,
		"tile_type": tile_type
	})

# Server sends planet info (seed, size)
static func encode_planet_info(seed: int, size_x: int, size_y: int) -> String:
	return encode_message(MessageTypes.PLANET_INFO, {
		"seed": seed,
		"size_x": size_x,
		"size_y": size_y
	})

# Server sends full chunk data
# Uses base64 encoding for compact tile data
static func encode_chunk_data(chunk: Chunk) -> String:
	# Convert tile array to bytes for compact transfer
	var tile_bytes := PackedByteArray()
	tile_bytes.resize(Chunk.TILE_COUNT * 4)  # 4 bytes per tile (int32)
	for i in range(Chunk.TILE_COUNT):
		var value: int = chunk.tiles[i]
		tile_bytes.encode_s32(i * 4, value)

	return encode_message(MessageTypes.CHUNK_DATA, {
		"chunk_x": chunk.chunk_x,
		"chunk_y": chunk.chunk_y,
		"tiles": Marshalls.raw_to_base64(tile_bytes),
		"elevation": Marshalls.raw_to_base64(chunk.elevation)
	})

# Server sends tile changes within a chunk
static func encode_chunk_delta(chunk_x: int, chunk_y: int, changes: Dictionary) -> String:
	# changes is a dict of "local_x,local_y" -> {type, variant, liquid}
	return encode_message(MessageTypes.CHUNK_DELTA, {
		"chunk_x": chunk_x,
		"chunk_y": chunk_y,
		"changes": changes
	})

# Parse chunk data from message
static func parse_chunk_data(data: Dictionary) -> Dictionary:
	var chunk_x: int = int(data.get("chunk_x", 0))
	var chunk_y: int = int(data.get("chunk_y", 0))

	# Decode tile bytes
	var tile_bytes: PackedByteArray = Marshalls.base64_to_raw(data.get("tiles", ""))
	var tiles := PackedInt32Array()
	tiles.resize(Chunk.TILE_COUNT)
	for i in range(Chunk.TILE_COUNT):
		if i * 4 + 3 < tile_bytes.size():
			tiles[i] = tile_bytes.decode_s32(i * 4)

	# Decode elevation
	var elevation: PackedByteArray = Marshalls.base64_to_raw(data.get("elevation", ""))

	return {
		"chunk_x": chunk_x,
		"chunk_y": chunk_y,
		"tiles": tiles,
		"elevation": elevation
	}


# ===== Inventory Network Messages =====

# Encode a full inventory sync message (sent on player join)
static func encode_inventory_sync(
	player_id: String,
	inventory: Dictionary,
	equipment: Dictionary,
	hotbar: Dictionary,
	stats: Dictionary = {}
) -> String:
	return encode_message(MessageTypes.INVENTORY_SYNC, {
		"player_id": player_id,
		"inventory": inventory,
		"equipment": equipment,
		"hotbar": hotbar,
		"stats": stats
	})


# Encode an inventory update message (delta changes)
static func encode_inventory_update(player_id: String, changes: Dictionary) -> String:
	# changes format: {"action": "add|remove|update", "slot": int, "stack": stack_data}
	return encode_message(MessageTypes.INVENTORY_UPDATE, {
		"player_id": player_id,
		"changes": changes
	})


# Encode an equipment update message
static func encode_equipment_update(player_id: String, slot: int, item_data: Variant) -> String:
	# item_data is Dictionary for equipped item or null for unequipped
	return encode_message(MessageTypes.EQUIPMENT_UPDATE, {
		"player_id": player_id,
		"slot": slot,
		"item": item_data
	})


# Encode an item pickup request (client -> server)
static func encode_item_pickup_request(world_item_id: String, world_position: Vector2) -> String:
	return encode_message(MessageTypes.ITEM_PICKUP_REQUEST, {
		"item_id": world_item_id,
		"position": {"x": world_position.x, "y": world_position.y}
	})


# Encode an item pickup response (server -> client)
static func encode_item_pickup_response(
	success: bool,
	world_item_id: String,
	stack_data: Variant = null,
	error_message: String = ""
) -> String:
	return encode_message(MessageTypes.ITEM_PICKUP_RESPONSE, {
		"success": success,
		"item_id": world_item_id,
		"stack": stack_data,
		"error": error_message
	})


# Encode an item drop request (client -> server)
static func encode_item_drop_request(inventory_slot: int, count: int = 1) -> String:
	return encode_message(MessageTypes.ITEM_DROP_REQUEST, {
		"slot": inventory_slot,
		"count": count
	})


# Encode an item drop response (server -> client)
static func encode_item_drop_response(
	success: bool,
	inventory_slot: int,
	world_item_id: String = "",
	error_message: String = ""
) -> String:
	return encode_message(MessageTypes.ITEM_DROP_RESPONSE, {
		"success": success,
		"slot": inventory_slot,
		"world_item_id": world_item_id,
		"error": error_message
	})


# Encode an item use request (client -> server)
static func encode_item_use_request(inventory_slot: int) -> String:
	return encode_message(MessageTypes.ITEM_USE_REQUEST, {
		"slot": inventory_slot
	})


# Encode an equip request (client -> server)
static func encode_equip_request(inventory_slot: int, equip_slot: int = -1) -> String:
	# equip_slot of -1 means auto-detect from item definition
	return encode_message(MessageTypes.EQUIP_REQUEST, {
		"inventory_slot": inventory_slot,
		"equip_slot": equip_slot
	})


# Encode an unequip request (client -> server)
static func encode_unequip_request(equip_slot: int) -> String:
	return encode_message(MessageTypes.UNEQUIP_REQUEST, {
		"equip_slot": equip_slot
	})


# Encode a stats update message (server -> client)
static func encode_stats_update(player_id: String, stats: Dictionary) -> String:
	return encode_message(MessageTypes.STATS_UPDATE, {
		"player_id": player_id,
		"stats": stats
	})


# Parse an inventory sync message
static func parse_inventory_sync(data: Dictionary) -> Dictionary:
	return {
		"player_id": data.get("player_id", ""),
		"inventory": data.get("inventory", {}),
		"equipment": data.get("equipment", {}),
		"hotbar": data.get("hotbar", {}),
		"stats": data.get("stats", {})
	}


# Parse an inventory update message
static func parse_inventory_update(data: Dictionary) -> Dictionary:
	return {
		"player_id": data.get("player_id", ""),
		"changes": data.get("changes", {})
	}


# Parse an equipment update message
static func parse_equipment_update(data: Dictionary) -> Dictionary:
	return {
		"player_id": data.get("player_id", ""),
		"slot": data.get("slot", 0),
		"item": data.get("item")  # Can be null
	}


# Parse a stats update message
static func parse_stats_update(data: Dictionary) -> Dictionary:
	return {
		"player_id": data.get("player_id", ""),
		"stats": data.get("stats", {})
	}


# Parse an item pickup request
static func parse_item_pickup_request(data: Dictionary) -> Dictionary:
	var pos_data = data.get("position", {})
	return {
		"item_id": data.get("item_id", ""),
		"position": Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
	}


# Parse an item drop request
static func parse_item_drop_request(data: Dictionary) -> Dictionary:
	return {
		"slot": data.get("slot", 0),
		"count": data.get("count", 1)
	}


# Parse an equip request
static func parse_equip_request(data: Dictionary) -> Dictionary:
	return {
		"inventory_slot": data.get("inventory_slot", 0),
		"equip_slot": data.get("equip_slot", -1)
	}


# Parse an unequip request
static func parse_unequip_request(data: Dictionary) -> Dictionary:
	return {
		"equip_slot": data.get("equip_slot", 0)
	}


# Parse an item use request
static func parse_item_use_request(data: Dictionary) -> Dictionary:
	return {
		"slot": data.get("slot", 0)
	}
