class_name GameClient
extends Node

const ClientRegistriesClass = preload("res://client/data/client_registries.gd")

signal connected(player_id: String)
signal disconnected()
signal connection_failed(reason: String)
signal chunk_manager_ready(chunk_manager: ChunkManager)

# Inventory signals (forwarded from message handler for UI)
signal inventory_changed
signal equipment_changed(slot: int)
signal hotbar_changed
signal stats_changed

var config: ClientConfig
var message_handler: ClientMessageHandler

var _ws: WebSocketPeer
var _connected: bool = false
var _player_id: String = ""
var _server_tick: int = 0

# Scene references
var world: TestWorld
var local_player: LocalPlayer
var remote_players: Dictionary = {}  # player_id -> RemotePlayer

# Chunk system
var chunk_manager: ChunkManager
var chunk_renderer: ChunkRenderer
var _last_chunk_request_pos: Vector2i = Vector2i(-9999, -9999)
var _chunk_request_interval: float = 0.5
var _chunk_request_timer: float = 0.0

# Inventory system
var client_registries: ClientRegistriesClass
var local_inventory: Inventory
var local_equipment: EquipmentSlots
var local_hotbar: Hotbar
var local_stats: PlayerStats

# Preloaded scenes
var LocalPlayerScene: PackedScene = preload("res://client/player/local_player.tscn")
var RemotePlayerScene: PackedScene = preload("res://client/player/remote_player.tscn")
var TestWorldScene: PackedScene = preload("res://client/world/test_world.tscn")

func _init() -> void:
	config = ClientConfig.new()
	message_handler = ClientMessageHandler.new()

	# Initialize client registries
	client_registries = ClientRegistriesClass.new()

	# Connect message handler signals
	message_handler.connect_response_received.connect(_on_connect_response)
	message_handler.game_state_received.connect(_on_game_state)
	message_handler.state_delta_received.connect(_on_state_delta)
	message_handler.player_joined_received.connect(_on_player_joined)
	message_handler.player_left_received.connect(_on_player_left)
	message_handler.pong_received.connect(_on_pong)
	message_handler.error_received.connect(_on_error)
	message_handler.planet_info_received.connect(_on_planet_info)
	message_handler.chunk_data_received.connect(_on_chunk_data)
	message_handler.chunk_delta_received.connect(_on_chunk_delta)

	# Connect inventory message handler signals
	message_handler.inventory_sync_received.connect(_on_inventory_sync)
	message_handler.inventory_update_received.connect(_on_inventory_update)
	message_handler.equipment_update_received.connect(_on_equipment_update)
	message_handler.stats_update_received.connect(_on_stats_update)

func connect_to_server(address: String, port: int, player_name: String) -> void:
	config.server_address = address
	config.server_port = port
	config.player_name = player_name

	_ws = WebSocketPeer.new()
	var url := config.get_websocket_url()
	var error := _ws.connect_to_url(url)

	if error != OK:
		connection_failed.emit("Failed to initiate connection: %s" % error_string(error))
		return

	print("GameClient: Connecting to %s..." % url)

func disconnect_from_server() -> void:
	if _ws:
		_send(Serialization.encode_message(MessageTypes.DISCONNECT, {}))
		_ws.close()
	_cleanup()
	disconnected.emit()

func _process(delta: float) -> void:
	if _ws == null:
		return

	_ws.poll()

	var state := _ws.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				# Send connect request
				_send(Serialization.encode_connect_request(config.player_name))

			# Receive messages
			while _ws.get_available_packet_count() > 0:
				var packet := _ws.get_packet()
				var message := packet.get_string_from_utf8()
				message_handler.handle_message(message)

			# Update chunk streaming
			_update_chunk_streaming(delta)

		WebSocketPeer.STATE_CLOSING:
			pass

		WebSocketPeer.STATE_CLOSED:
			var code := _ws.get_close_code()
			var reason := _ws.get_close_reason()
			print("GameClient: Connection closed. Code: %d, Reason: %s" % [code, reason])
			_cleanup()
			disconnected.emit()

		WebSocketPeer.STATE_CONNECTING:
			pass

func _update_chunk_streaming(delta: float) -> void:
	if local_player == null or chunk_manager == null:
		return

	_chunk_request_timer += delta
	if _chunk_request_timer < _chunk_request_interval:
		return
	_chunk_request_timer = 0.0

	# Get player position in tile coordinates
	var player_pos := local_player.position
	var tile_x := int(player_pos.x / GameConstants.TILE_SIZE)
	var tile_y := int(player_pos.y / GameConstants.TILE_SIZE)
	var current_chunk := chunk_manager.world_to_chunk_coords(tile_x, tile_y)

	# Only request if moved to a new chunk
	if current_chunk != _last_chunk_request_pos:
		_last_chunk_request_pos = current_chunk
		request_chunks_around(tile_x, tile_y, 3)

	# Update chunk renderer focus
	if chunk_renderer:
		chunk_renderer.set_focus(player_pos)

func _send(message: String) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(message)

func _cleanup() -> void:
	_connected = false
	_player_id = ""

	if local_player:
		local_player.queue_free()
		local_player = null

	for player_id in remote_players:
		remote_players[player_id].queue_free()
	remote_players.clear()

	if chunk_renderer:
		chunk_renderer.queue_free()
		chunk_renderer = null

	chunk_manager = null
	_last_chunk_request_pos = Vector2i(-9999, -9999)

	if world:
		world.queue_free()
		world = null

	# Clean up inventory state
	local_inventory = null
	local_equipment = null
	local_hotbar = null
	local_stats = null

	_ws = null

func _on_connect_response(success: bool, player_id: String, server_tick: int, error: String) -> void:
	if success:
		_player_id = player_id
		_server_tick = server_tick
		print("GameClient: Connected as %s (ID: %s)" % [config.player_name, player_id])
		connected.emit(player_id)
	else:
		print("GameClient: Connection rejected: %s" % error)
		connection_failed.emit(error)
		_ws.close()

func _on_game_state(tick: int, players: Dictionary) -> void:
	_server_tick = tick

	# Create world if not exists
	if world == null:
		world = TestWorldScene.instantiate()
		add_child(world)

	# Process all players
	for player_id in players:
		var player_data: Dictionary = players[player_id]
		var pos := Vector2(player_data["position"]["x"], player_data["position"]["y"])
		var aim: float = player_data.get("aim_angle", 0.0)
		var name: String = player_data.get("name", "Unknown")

		if player_id == _player_id:
			# Create local player
			if local_player == null:
				local_player = LocalPlayerScene.instantiate()
				local_player.initialize(player_id, name, pos)
				local_player.input_generated.connect(_on_local_player_input)
				add_child(local_player)
		else:
			# Create or update remote player
			if not remote_players.has(player_id):
				var remote := RemotePlayerScene.instantiate()
				remote.initialize(player_id, name, pos)
				remote_players[player_id] = remote
				add_child(remote)
			else:
				remote_players[player_id].update_state(pos, aim)

func _on_state_delta(tick: int, last_processed_input: int, players: Dictionary) -> void:
	_server_tick = tick

	for player_id in players:
		var player_data: Dictionary = players[player_id]
		var pos := Vector2(player_data["position"]["x"], player_data["position"]["y"])
		var aim: float = player_data.get("aim_angle", 0.0)

		if player_id == _player_id:
			# Reconcile local player
			if local_player:
				local_player.apply_server_state(pos, aim, last_processed_input, GameConstants.TICK_INTERVAL)
		else:
			# Update remote player
			if remote_players.has(player_id):
				remote_players[player_id].update_state(pos, aim)

func _on_player_joined(player_data: Dictionary) -> void:
	var player_id: String = player_data.get("id", "")
	var name: String = player_data.get("name", "Unknown")
	var pos := Vector2(player_data["position"]["x"], player_data["position"]["y"])

	if player_id != _player_id and not remote_players.has(player_id):
		var remote := RemotePlayerScene.instantiate()
		remote.initialize(player_id, name, pos)
		remote_players[player_id] = remote
		add_child(remote)
		print("GameClient: Player joined: %s" % name)

func _on_player_left(player_id: String) -> void:
	if remote_players.has(player_id):
		print("GameClient: Player left: %s" % player_id)
		remote_players[player_id].queue_free()
		remote_players.erase(player_id)

func _on_pong(client_time: int, _server_time: int) -> void:
	var now := Time.get_ticks_msec()
	var rtt := now - client_time
	# Could display this in HUD
	pass

func _on_error(message: String) -> void:
	print("GameClient: Server error: %s" % message)

func _on_local_player_input(input_data: Dictionary) -> void:
	# Send input to server
	var message := Serialization.encode_player_input(
		input_data["sequence"],
		input_data["move_direction"],
		input_data["aim_angle"],
		input_data["actions"]
	)
	_send(message)

func is_connected_to_server() -> bool:
	return _connected and _player_id != ""

func get_player_id() -> String:
	return _player_id

func _on_planet_info(seed: int, size_x: int, size_y: int) -> void:
	print("GameClient: Received planet info - seed: %d, size: %dx%d" % [seed, size_x, size_y])

	# Initialize chunk manager with same seed as server
	chunk_manager = ChunkManager.new(seed, Vector2i(size_x, size_y))

	# Create chunk renderer and add to world
	if world:
		chunk_renderer = ChunkRenderer.new()
		chunk_renderer.initialize(chunk_manager)
		world.add_child(chunk_renderer)

		# Move renderer below players in z-order
		world.move_child(chunk_renderer, 0)

	# Notify that chunk manager is ready (for minimap, etc.)
	chunk_manager_ready.emit(chunk_manager)

func _on_chunk_data(chunk_x: int, chunk_y: int, tiles: PackedInt32Array, elevation: PackedByteArray) -> void:
	if chunk_manager == null:
		return

	# Create chunk from received data
	var chunk := Chunk.new(chunk_x, chunk_y)
	chunk.tiles = tiles
	chunk.elevation = elevation

	# Add to chunk manager (will overwrite any existing)
	chunk_manager.chunks[chunk.get_key()] = chunk
	chunk_manager.chunk_loaded.emit(chunk)

func _on_chunk_delta(chunk_x: int, chunk_y: int, changes: Dictionary) -> void:
	if chunk_manager == null:
		return

	var key := Chunk.make_key(chunk_x, chunk_y)
	if not chunk_manager.chunks.has(key):
		return

	var chunk: Chunk = chunk_manager.chunks[key]
	chunk.apply_delta(changes)

	# Update renderer for each changed tile
	for tile_key in changes:
		var parts: PackedStringArray = tile_key.split(",")
		if parts.size() == 2:
			var local_x := int(parts[0])
			var local_y := int(parts[1])
			chunk_manager.chunk_modified.emit(chunk, local_x, local_y)

func request_chunks_around(world_x: int, world_y: int, radius: int = 3) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_chunk_request(world_x, world_y, radius))

func request_tile_modify(world_x: int, world_y: int, tile_type: int) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_tile_modify(world_x, world_y, tile_type))


# =============================================================================
# Inventory message handlers
# =============================================================================

func _on_inventory_sync(
	player_id: String,
	inventory_data: Dictionary,
	equipment_data: Dictionary,
	hotbar_data: Dictionary,
	stats_data: Dictionary
) -> void:
	# Only process our own inventory
	if player_id != _player_id:
		return

	print("GameClient: Received inventory sync")

	# Initialize local inventory from server data
	var item_registry := client_registries.item_registry

	# Create and populate inventory
	local_inventory = Inventory.new(100.0, item_registry)
	local_inventory.from_dict(inventory_data)

	# Create and populate equipment
	local_equipment = EquipmentSlots.new(item_registry)
	local_equipment.from_dict(equipment_data)

	# Create and populate hotbar
	local_hotbar = Hotbar.new(local_inventory, item_registry)
	local_hotbar.from_dict(hotbar_data)
	local_hotbar.link_to_inventory(local_inventory)

	# Create stats object
	local_stats = PlayerStats.new(local_equipment)

	# Emit signals to update UI
	inventory_changed.emit()
	equipment_changed.emit(-1)  # -1 indicates full refresh
	hotbar_changed.emit()
	stats_changed.emit()

	print("GameClient: Inventory initialized - %d stacks, weight: %.1f/%.1f" % [
		local_inventory.get_stack_count(),
		local_inventory.get_current_weight(),
		local_inventory.max_weight
	])


func _on_inventory_update(player_id: String, changes: Dictionary) -> void:
	if player_id != _player_id or local_inventory == null:
		return

	# Apply delta changes to local inventory
	var action: String = changes.get("action", "")
	var slot: int = changes.get("slot", -1)
	var stack_data: Dictionary = changes.get("stack", {})

	match action:
		"add":
			if not stack_data.is_empty():
				var stack := ItemStack.from_dict(stack_data, client_registries.item_registry)
				if stack != null and not stack.is_empty():
					local_inventory.add_stack(stack)
		"remove":
			if slot >= 0 and slot < local_inventory.get_stack_count():
				var stack := local_inventory.get_stack_at(slot)
				if stack != null:
					local_inventory.remove_stack(stack)
		"update":
			# Full slot update - replace the stack at this slot
			if slot >= 0 and slot < local_inventory.get_stack_count():
				# For now, we rebuild from full sync
				pass

	# Update hotbar references
	if local_hotbar != null:
		local_hotbar.validate(local_inventory)

	inventory_changed.emit()
	hotbar_changed.emit()


func _on_equipment_update(player_id: String, slot: int, item_data: Variant) -> void:
	if player_id != _player_id or local_equipment == null:
		return

	var slot_enum := slot as ItemEnums.EquipSlot

	if item_data == null:
		# Unequip
		local_equipment.unequip(slot_enum)
	else:
		# Equip new item
		if item_data is Dictionary:
			var item := ItemInstance.from_dict(item_data, client_registries.item_registry)
			if item != null:
				local_equipment.equip(item)

	equipment_changed.emit(slot)
	stats_changed.emit()


func _on_stats_update(player_id: String, stats: Dictionary) -> void:
	if player_id != _player_id:
		return

	# Stats are automatically calculated from equipment
	# This signal is mainly for when server overrides or modifies stats
	if local_stats != null:
		local_stats.recalculate()

	stats_changed.emit()


# =============================================================================
# Inventory request functions (client -> server)
# =============================================================================

## Request to equip an item from inventory
func request_equip(inventory_slot: int, equip_slot: int = -1) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_equip_request(inventory_slot, equip_slot))


## Request to unequip an item to inventory
func request_unequip(equip_slot: int) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_unequip_request(equip_slot))


## Request to drop an item from inventory
func request_drop_item(inventory_slot: int, count: int = 1) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_item_drop_request(inventory_slot, count))


## Request to use an item from inventory (consumables)
func request_use_item(inventory_slot: int) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_item_use_request(inventory_slot))


## Request to pick up a world item
func request_pickup_item(world_item_id: String, position: Vector2) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_item_pickup_request(world_item_id, position))
