class_name ServerMessageHandler
extends RefCounted

signal player_connect_requested(peer_id: int, player_name: String)
signal player_input_received(peer_id: int, input_data: Dictionary)
signal player_ping_received(peer_id: int, client_time: int)
signal player_disconnect_requested(peer_id: int)
signal chunk_requested(peer_id: int, world_x: int, world_y: int, radius: int)
signal tile_modify_requested(peer_id: int, world_x: int, world_y: int, tile_type: int)

# Inventory signals
signal equip_requested(peer_id: int, inventory_slot: int, equip_slot: int)
signal unequip_requested(peer_id: int, equip_slot: int)
signal item_drop_requested(peer_id: int, slot: int, count: int)
signal item_use_requested(peer_id: int, slot: int)
signal item_pickup_requested(peer_id: int, world_item_id: String, position: Vector2)

# Crafting signals
signal craft_requested(peer_id: int, recipe_id: String)

# Combat signals
signal corpse_recover_requested(peer_id: int, corpse_id: String)
signal attack_requested(peer_id: int, aim_position: Vector2, attack_type: int)

# Process an incoming message from a client
func handle_message(peer_id: int, json_string: String) -> void:
	@warning_ignore("inference_on_variant")
	var message := Serialization.decode_message(json_string)
	if message == null:
		printerr("ServerMessageHandler: Failed to decode message from peer %d" % peer_id)
		return

	var msg_type: String = message["type"]
	var data: Dictionary = message["data"]

	match msg_type:
		MessageTypes.CONNECT_REQUEST:
			_handle_connect_request(peer_id, data)
		MessageTypes.PLAYER_INPUT:
			_handle_player_input(peer_id, data)
		MessageTypes.PING:
			_handle_ping(peer_id, data)
		MessageTypes.DISCONNECT:
			_handle_disconnect(peer_id)
		MessageTypes.CHUNK_REQUEST:
			_handle_chunk_request(peer_id, data)
		MessageTypes.TILE_MODIFY:
			_handle_tile_modify(peer_id, data)
		# Inventory messages
		MessageTypes.EQUIP_REQUEST:
			_handle_equip_request(peer_id, data)
		MessageTypes.UNEQUIP_REQUEST:
			_handle_unequip_request(peer_id, data)
		MessageTypes.ITEM_DROP_REQUEST:
			_handle_item_drop_request(peer_id, data)
		MessageTypes.ITEM_USE_REQUEST:
			_handle_item_use_request(peer_id, data)
		MessageTypes.ITEM_PICKUP_REQUEST:
			_handle_item_pickup_request(peer_id, data)
		# Crafting messages
		MessageTypes.CRAFT_REQUEST:
			_handle_craft_request(peer_id, data)
		# Combat messages
		MessageTypes.CORPSE_RECOVER_REQUEST:
			_handle_corpse_recover_request(peer_id, data)
		MessageTypes.ATTACK_REQUEST:
			_handle_attack_request(peer_id, data)
		_:
			printerr("ServerMessageHandler: Unknown message type '%s' from peer %d" % [msg_type, peer_id])

func _handle_connect_request(peer_id: int, data: Dictionary) -> void:
	var player_name: String = data.get("player_name", "Unknown")
	player_connect_requested.emit(peer_id, player_name)

func _handle_player_input(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var input_data := Serialization.parse_player_input(data)
	player_input_received.emit(peer_id, input_data)

func _handle_ping(peer_id: int, data: Dictionary) -> void:
	var client_time: int = data.get("client_time", 0)
	player_ping_received.emit(peer_id, client_time)

func _handle_disconnect(peer_id: int) -> void:
	player_disconnect_requested.emit(peer_id)

func _handle_chunk_request(peer_id: int, data: Dictionary) -> void:
	var world_x: int = int(data.get("world_x", 0))
	var world_y: int = int(data.get("world_y", 0))
	var radius: int = int(data.get("radius", 2))
	chunk_requested.emit(peer_id, world_x, world_y, radius)

func _handle_tile_modify(peer_id: int, data: Dictionary) -> void:
	var world_x: int = int(data.get("world_x", 0))
	var world_y: int = int(data.get("world_y", 0))
	var tile_type: int = int(data.get("tile_type", 0))
	tile_modify_requested.emit(peer_id, world_x, world_y, tile_type)


# ===== Inventory Message Handlers =====

func _handle_equip_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_equip_request(data)
	var inventory_slot: int = parsed["inventory_slot"]
	var equip_slot: int = parsed["equip_slot"]
	equip_requested.emit(peer_id, inventory_slot, equip_slot)


func _handle_unequip_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_unequip_request(data)
	var equip_slot: int = parsed["equip_slot"]
	unequip_requested.emit(peer_id, equip_slot)


func _handle_item_drop_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_item_drop_request(data)
	var slot: int = parsed["slot"]
	var count: int = parsed["count"]
	item_drop_requested.emit(peer_id, slot, count)


func _handle_item_use_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_item_use_request(data)
	var slot: int = parsed["slot"]
	item_use_requested.emit(peer_id, slot)


func _handle_item_pickup_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_item_pickup_request(data)
	var world_item_id: String = parsed["item_id"]
	var position: Vector2 = parsed["position"]
	item_pickup_requested.emit(peer_id, world_item_id, position)


# ===== Crafting Message Handlers =====

func _handle_craft_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_craft_request(data)
	var recipe_id: String = parsed["recipe_id"]
	craft_requested.emit(peer_id, recipe_id)


# ===== Combat Message Handlers =====

func _handle_corpse_recover_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_corpse_recover_request(data)
	var corpse_id: String = parsed["corpse_id"]
	corpse_recover_requested.emit(peer_id, corpse_id)


func _handle_attack_request(peer_id: int, data: Dictionary) -> void:
	@warning_ignore("inference_on_variant")
	var parsed := Serialization.parse_attack_request(data)
	var aim_position: Vector2 = parsed["aim_position"]
	var attack_type: int = parsed["attack_type"]
	attack_requested.emit(peer_id, aim_position, attack_type)
