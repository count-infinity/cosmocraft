class_name ClientMessageHandler
extends RefCounted

signal connect_response_received(success: bool, player_id: String, server_tick: int, error: String)
signal game_state_received(tick: int, players: Dictionary)
signal state_delta_received(tick: int, last_processed_input: int, players: Dictionary)
signal player_joined_received(player_data: Dictionary)
signal player_left_received(player_id: String)
signal pong_received(client_time: int, server_time: int)
signal error_received(message: String)
signal planet_info_received(seed: int, size_x: int, size_y: int)
signal chunk_data_received(chunk_x: int, chunk_y: int, tiles: PackedInt32Array, elevation: PackedByteArray)
signal chunk_delta_received(chunk_x: int, chunk_y: int, changes: Dictionary)

# Inventory signals
signal inventory_sync_received(player_id: String, inventory_data: Dictionary, equipment_data: Dictionary, hotbar_data: Dictionary, stats_data: Dictionary)
signal inventory_update_received(player_id: String, changes: Dictionary)
signal equipment_update_received(player_id: String, slot: int, item_data: Variant)
signal stats_update_received(player_id: String, stats: Dictionary)
signal item_pickup_response_received(success: bool, item_id: String, stack_data: Variant, error: String)
signal item_drop_response_received(success: bool, slot: int, world_item_id: String, error: String)

func handle_message(json_string: String) -> void:
	@warning_ignore("inference_on_variant")
	var message := Serialization.decode_message(json_string)
	if message == null:
		printerr("ClientMessageHandler: Failed to decode message")
		return

	var msg_type: String = message["type"]
	var data: Dictionary = message["data"]

	match msg_type:
		MessageTypes.CONNECT_RESPONSE:
			_handle_connect_response(data)
		MessageTypes.GAME_STATE:
			_handle_game_state(data)
		MessageTypes.STATE_DELTA:
			_handle_state_delta(data)
		MessageTypes.PLAYER_JOINED:
			_handle_player_joined(data)
		MessageTypes.PLAYER_LEFT:
			_handle_player_left(data)
		MessageTypes.PONG:
			_handle_pong(data)
		MessageTypes.ERROR:
			_handle_error(data)
		MessageTypes.PLANET_INFO:
			_handle_planet_info(data)
		MessageTypes.CHUNK_DATA:
			_handle_chunk_data(data)
		MessageTypes.CHUNK_DELTA:
			_handle_chunk_delta(data)
		# Inventory messages
		MessageTypes.INVENTORY_SYNC:
			_handle_inventory_sync(data)
		MessageTypes.INVENTORY_UPDATE:
			_handle_inventory_update(data)
		MessageTypes.EQUIPMENT_UPDATE:
			_handle_equipment_update(data)
		MessageTypes.STATS_UPDATE:
			_handle_stats_update(data)
		MessageTypes.ITEM_PICKUP_RESPONSE:
			_handle_item_pickup_response(data)
		MessageTypes.ITEM_DROP_RESPONSE:
			_handle_item_drop_response(data)
		_:
			printerr("ClientMessageHandler: Unknown message type '%s'" % msg_type)

func _handle_connect_response(data: Dictionary) -> void:
	var success: bool = data.get("success", false)
	var player_id: String = data.get("player_id", "")
	var server_tick: int = int(data.get("server_tick", 0))
	var error: String = data.get("error", "")
	connect_response_received.emit(success, player_id, server_tick, error)

func _handle_game_state(data: Dictionary) -> void:
	var tick: int = int(data.get("tick", 0))
	var players: Dictionary = data.get("players", {})
	game_state_received.emit(tick, players)

func _handle_state_delta(data: Dictionary) -> void:
	var tick: int = int(data.get("tick", 0))
	var last_processed_input: int = int(data.get("last_processed_input", 0))
	var players: Dictionary = data.get("players", {})
	state_delta_received.emit(tick, last_processed_input, players)

func _handle_player_joined(data: Dictionary) -> void:
	player_joined_received.emit(data)

func _handle_player_left(data: Dictionary) -> void:
	var player_id: String = data.get("player_id", "")
	player_left_received.emit(player_id)

func _handle_pong(data: Dictionary) -> void:
	var client_time: int = int(data.get("client_time", 0))
	var server_time: int = int(data.get("server_time", 0))
	pong_received.emit(client_time, server_time)

func _handle_error(data: Dictionary) -> void:
	var message: String = data.get("message", "Unknown error")
	error_received.emit(message)

func _handle_planet_info(data: Dictionary) -> void:
	var seed_val: int = int(data.get("seed", 0))
	var size_x: int = int(data.get("size_x", 8000))
	var size_y: int = int(data.get("size_y", 8000))
	planet_info_received.emit(seed_val, size_x, size_y)

func _handle_chunk_data(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_chunk_data(data)
	chunk_data_received.emit(
		parsed.chunk_x,
		parsed.chunk_y,
		parsed.tiles,
		parsed.elevation
	)

func _handle_chunk_delta(data: Dictionary) -> void:
	var chunk_x: int = int(data.get("chunk_x", 0))
	var chunk_y: int = int(data.get("chunk_y", 0))
	var changes: Dictionary = data.get("changes", {})
	chunk_delta_received.emit(chunk_x, chunk_y, changes)


# =============================================================================
# Inventory message handlers
# =============================================================================

func _handle_inventory_sync(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_inventory_sync(data)
	inventory_sync_received.emit(
		parsed.player_id,
		parsed.inventory,
		parsed.equipment,
		parsed.hotbar,
		parsed.stats
	)


func _handle_inventory_update(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_inventory_update(data)
	inventory_update_received.emit(parsed.player_id, parsed.changes)


func _handle_equipment_update(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_equipment_update(data)
	equipment_update_received.emit(parsed.player_id, parsed.slot, parsed.item)


func _handle_stats_update(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_stats_update(data)
	stats_update_received.emit(parsed.player_id, parsed.stats)


func _handle_item_pickup_response(data: Dictionary) -> void:
	var success: bool = data.get("success", false)
	var item_id: String = data.get("item_id", "")
	var stack_data: Variant = data.get("stack")
	var error: String = data.get("error", "")
	item_pickup_response_received.emit(success, item_id, stack_data, error)


func _handle_item_drop_response(data: Dictionary) -> void:
	var success: bool = data.get("success", false)
	var slot: int = int(data.get("slot", 0))
	var world_item_id: String = data.get("world_item_id", "")
	var error: String = data.get("error", "")
	item_drop_response_received.emit(success, slot, world_item_id, error)
