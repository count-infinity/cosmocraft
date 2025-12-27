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

# Ground item signals
signal ground_item_spawned_received(item_data: Dictionary)
signal ground_item_removed_received(item_id: String, reason: String)
signal ground_items_sync_received(items: Array)

# Crafting signals
signal craft_response_received(success: bool, recipe_id: String, items_created: Array, xp_gained: int, skill_name: String, error: String)

# Combat signals
signal player_died_received(player_id: String, killer_id: String, corpse_data: Dictionary)
signal player_respawn_received(player_id: String, position: Vector2, current_hp: float, max_hp: float)
signal corpse_spawned_received(corpse_data: Dictionary)
signal corpse_recovered_received(player_id: String, corpse_id: String)
signal corpse_expired_received(corpse_id: String)
signal health_update_received(player_id: String, current_hp: float, max_hp: float)

# Attack signals
signal attack_result_received(success: bool, hits: Array, cooldown: float)
signal entity_damaged_received(entity_id: String, damage: float, is_crit: bool, current_hp: float, max_hp: float, attacker_id: String)
signal entity_died_received(entity_id: String, killer_id: String, entity_type: String)

# Enemy signals
signal enemy_spawn_received(enemy_data: Dictionary, definition_data: Dictionary)
signal enemy_update_received(enemy_id: String, state_data: Dictionary)
signal enemy_death_received(enemy_id: String, killer_id: String, loot_items: Array)
signal enemy_despawn_received(enemy_id: String)
signal enemies_sync_received(enemies: Array, definitions: Dictionary)

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
		# Ground item messages
		MessageTypes.GROUND_ITEM_SPAWNED:
			_handle_ground_item_spawned(data)
		MessageTypes.GROUND_ITEM_REMOVED:
			_handle_ground_item_removed(data)
		MessageTypes.GROUND_ITEMS_SYNC:
			_handle_ground_items_sync(data)
		# Crafting messages
		MessageTypes.CRAFT_RESPONSE:
			_handle_craft_response(data)
		# Combat messages
		MessageTypes.PLAYER_DIED:
			_handle_player_died(data)
		MessageTypes.PLAYER_RESPAWN:
			_handle_player_respawn(data)
		MessageTypes.CORPSE_SPAWNED:
			_handle_corpse_spawned(data)
		MessageTypes.CORPSE_RECOVERED:
			_handle_corpse_recovered(data)
		MessageTypes.CORPSE_EXPIRED:
			_handle_corpse_expired(data)
		MessageTypes.HEALTH_UPDATE:
			_handle_health_update(data)
		# Attack messages
		MessageTypes.ATTACK_RESULT:
			_handle_attack_result(data)
		MessageTypes.ENTITY_DAMAGED:
			_handle_entity_damaged(data)
		MessageTypes.ENTITY_DIED:
			_handle_entity_died(data)
		# Enemy messages
		MessageTypes.ENEMY_SPAWN:
			_handle_enemy_spawn(data)
		MessageTypes.ENEMY_UPDATE:
			_handle_enemy_update(data)
		MessageTypes.ENEMY_DEATH:
			_handle_enemy_death(data)
		MessageTypes.ENEMY_DESPAWN:
			_handle_enemy_despawn(data)
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


# =============================================================================
# Ground item message handlers
# =============================================================================

func _handle_ground_item_spawned(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_ground_item_spawned(data)
	ground_item_spawned_received.emit(parsed)


func _handle_ground_item_removed(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_ground_item_removed(data)
	ground_item_removed_received.emit(parsed["id"], parsed["reason"])


func _handle_ground_items_sync(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var items := Serialization.parse_ground_items_sync(data)
	ground_items_sync_received.emit(items)


# =============================================================================
# Crafting message handlers
# =============================================================================

func _handle_craft_response(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_craft_response(data)
	craft_response_received.emit(
		parsed["success"],
		parsed["recipe_id"],
		parsed["items_created"],
		parsed["xp_gained"],
		parsed["skill_name"],
		parsed["error"]
	)


# =============================================================================
# Combat message handlers
# =============================================================================

func _handle_player_died(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_player_died(data)
	player_died_received.emit(parsed["player_id"], parsed["killer_id"], parsed["corpse"])


func _handle_player_respawn(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_player_respawn(data)
	player_respawn_received.emit(
		parsed["player_id"],
		parsed["position"],
		parsed["current_hp"],
		parsed["max_hp"]
	)


func _handle_corpse_spawned(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_corpse_spawned(data)
	corpse_spawned_received.emit(parsed)


func _handle_corpse_recovered(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_corpse_recovered(data)
	corpse_recovered_received.emit(parsed["player_id"], parsed["corpse_id"])


func _handle_corpse_expired(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_corpse_expired(data)
	corpse_expired_received.emit(parsed["corpse_id"])


func _handle_health_update(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_health_update(data)
	health_update_received.emit(parsed["player_id"], parsed["current_hp"], parsed["max_hp"])


# =============================================================================
# Attack message handlers
# =============================================================================

func _handle_attack_result(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_attack_result(data)
	attack_result_received.emit(
		parsed["success"],
		parsed["hits"],
		parsed["cooldown"]
	)


func _handle_entity_damaged(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_entity_damaged(data)
	entity_damaged_received.emit(
		parsed["entity_id"],
		parsed["damage"],
		parsed["is_crit"],
		parsed["current_hp"],
		parsed["max_hp"],
		parsed["attacker_id"]
	)


func _handle_entity_died(data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_entity_died(data)
	entity_died_received.emit(
		parsed["entity_id"],
		parsed["killer_id"],
		parsed["entity_type"]
	)


# =============================================================================
# Enemy message handlers
# =============================================================================

func _handle_enemy_spawn(data: Dictionary) -> void:
	var enemy_data: Dictionary = data.get("enemy", {})
	var definition_data: Dictionary = data.get("definition", {})
	enemy_spawn_received.emit(enemy_data, definition_data)


func _handle_enemy_update(data: Dictionary) -> void:
	var enemy_id: String = data.get("id", "")
	var state_data: Dictionary = data.get("state", data)  # Fallback to full data
	enemy_update_received.emit(enemy_id, state_data)


func _handle_enemy_death(data: Dictionary) -> void:
	var enemy_id: String = data.get("id", "")
	var killer_id: String = data.get("killer_id", "")
	var loot_items: Array = data.get("loot", [])
	enemy_death_received.emit(enemy_id, killer_id, loot_items)


func _handle_enemy_despawn(data: Dictionary) -> void:
	var enemy_id: String = data.get("id", "")
	enemy_despawn_received.emit(enemy_id)
