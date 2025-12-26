class_name GameServer
extends Node

const ServerRegistriesScript = preload("res://server/data/server_registries.gd")

signal server_started(port: int)
signal server_stopped()
signal player_connected(player_id: String, player_name: String)
signal player_disconnected(player_id: String)

var config: ServerConfig
var game_state: GameState
var game_loop: GameLoop
var message_handler: ServerMessageHandler
var chunk_manager: ChunkManager

# Planet configuration
var planet_seed: int = 0
var planet_size: Vector2i = Vector2i(8000, 8000)

# Inventory system
var registries  # ServerRegistries type, loaded via preload
var _player_inventories: Dictionary = {}  # player_id -> Inventory
var _player_equipment: Dictionary = {}  # player_id -> EquipmentSlots
var _player_hotbars: Dictionary = {}  # player_id -> Hotbar

var _tcp_server: TCPServer
var _peers: Dictionary = {}  # peer_id -> WebSocketPeer
var _peer_to_player: Dictionary = {}  # peer_id -> player_id
var _player_to_peer: Dictionary = {}  # player_id -> peer_id

var _running: bool = false

func _init() -> void:
	config = ServerConfig.from_args()
	game_state = GameState.new()
	game_loop = GameLoop.new(game_state)
	message_handler = ServerMessageHandler.new()

	# Initialize planet with random seed
	planet_seed = randi()
	chunk_manager = ChunkManager.new(planet_seed, planet_size)

	# Initialize inventory registries
	registries = ServerRegistriesScript.new()

	# Connect message handler signals
	message_handler.player_connect_requested.connect(_on_player_connect_requested)
	message_handler.player_input_received.connect(_on_player_input_received)
	message_handler.player_ping_received.connect(_on_player_ping_received)
	message_handler.player_disconnect_requested.connect(_on_player_disconnect_requested)
	message_handler.chunk_requested.connect(_on_chunk_requested)
	message_handler.tile_modify_requested.connect(_on_tile_modify_requested)

	# Connect inventory message handler signals
	message_handler.equip_requested.connect(_on_equip_requested)
	message_handler.unequip_requested.connect(_on_unequip_requested)
	message_handler.item_drop_requested.connect(_on_item_drop_requested)
	message_handler.item_use_requested.connect(_on_item_use_requested)

	# Connect game loop signals
	game_loop.tick_completed.connect(_on_tick_completed)

func _ready() -> void:
	start_server()

func start_server() -> bool:
	_tcp_server = TCPServer.new()
	var error := _tcp_server.listen(config.port)
	if error != OK:
		printerr("GameServer: Failed to start server on port %d: %s" % [config.port, error_string(error)])
		return false

	_running = true
	print("GameServer: Server started on port %d" % config.port)
	server_started.emit(config.port)
	return true

func stop_server() -> void:
	_running = false

	# Disconnect all peers
	for peer_id in _peers.keys():
		_disconnect_peer(peer_id)

	_peers.clear()
	_peer_to_player.clear()
	_player_to_peer.clear()

	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null

	print("GameServer: Server stopped")
	server_stopped.emit()

func _process(delta: float) -> void:
	if not _running:
		return

	# Accept new connections
	_accept_new_connections()

	# Poll all WebSocket peers
	_poll_peers()

	# Update game loop
	game_loop.update(delta)

func _accept_new_connections() -> void:
	while _tcp_server.is_connection_available():
		var tcp_peer := _tcp_server.take_connection()
		if tcp_peer:
			var ws_peer := WebSocketPeer.new()
			# Increase buffer sizes for large chunk data transfers
			# Default is 65535 (64KB), increase to 16MB for chunk streaming
			ws_peer.outbound_buffer_size = 16 * 1024 * 1024
			ws_peer.inbound_buffer_size = 1 * 1024 * 1024
			var error := ws_peer.accept_stream(tcp_peer)
			if error == OK:
				var peer_id := tcp_peer.get_instance_id()
				_peers[peer_id] = ws_peer
				print("GameServer: New connection from peer %d" % peer_id)
			else:
				printerr("GameServer: Failed to accept WebSocket connection: %s" % error_string(error))

func _poll_peers() -> void:
	var peers_to_remove: Array = []

	for peer_id in _peers:
		var ws_peer: WebSocketPeer = _peers[peer_id]
		ws_peer.poll()

		var state := ws_peer.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				# Receive messages
				while ws_peer.get_available_packet_count() > 0:
					var packet := ws_peer.get_packet()
					var message := packet.get_string_from_utf8()
					message_handler.handle_message(peer_id, message)

			WebSocketPeer.STATE_CLOSING:
				# Still closing, wait
				pass

			WebSocketPeer.STATE_CLOSED:
				peers_to_remove.append(peer_id)

	# Remove disconnected peers
	for peer_id in peers_to_remove:
		_handle_peer_disconnected(peer_id)

func _handle_peer_disconnected(peer_id: int) -> void:
	if _peer_to_player.has(peer_id):
		var player_id: String = _peer_to_player[peer_id]
		_remove_player(player_id)

	_peers.erase(peer_id)
	print("GameServer: Peer %d disconnected" % peer_id)

func _disconnect_peer(peer_id: int) -> void:
	if _peers.has(peer_id):
		var ws_peer: WebSocketPeer = _peers[peer_id]
		ws_peer.close()

func _on_player_connect_requested(peer_id: int, player_name: String) -> void:
	if _peer_to_player.has(peer_id):
		# Already connected
		_send_to_peer(peer_id, Serialization.encode_connect_response(false, "", 0, "Already connected"))
		return

	if game_state.get_player_count() >= config.max_players:
		_send_to_peer(peer_id, Serialization.encode_connect_response(false, "", 0, "Server full"))
		return

	# Generate unique player ID
	var player_id := _generate_player_id()

	# Add player to game state
	var player := game_state.add_player(player_id, player_name)

	# Initialize player inventory with starter items
	_initialize_player_inventory(player_id, player)

	# Map peer to player
	_peer_to_player[peer_id] = player_id
	_player_to_peer[player_id] = peer_id

	# Send success response with current game state
	_send_to_peer(peer_id, Serialization.encode_connect_response(true, player_id, game_state.current_tick))
	_send_to_peer(peer_id, Serialization.encode_game_state(game_state.current_tick, game_state.players))

	# Send planet info so client can generate terrain locally
	_send_to_peer(peer_id, Serialization.encode_planet_info(planet_seed, planet_size.x, planet_size.y))

	# Send full inventory sync
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	# Notify other players
	_broadcast_except(peer_id, Serialization.encode_player_joined(player))

	print("GameServer: Player '%s' (ID: %s) connected from peer %d" % [player_name, player_id, peer_id])
	print("GameServer: Player '%s' received starter inventory" % player_name)
	player_connected.emit(player_id, player_name)

func _on_player_input_received(peer_id: int, input_data: Dictionary) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	# Update last processed input sequence
	var sequence: int = input_data.get("sequence", 0)
	game_state.set_last_processed_input(player_id, sequence)

	# Queue input for next tick
	game_loop.queue_input(player_id, input_data)

func _on_player_ping_received(peer_id: int, client_time: int) -> void:
	_send_to_peer(peer_id, Serialization.encode_pong(client_time))

func _on_player_disconnect_requested(peer_id: int) -> void:
	_disconnect_peer(peer_id)

func _on_tick_completed(_tick: int) -> void:
	# Broadcast state delta to all connected players
	_broadcast_state_delta()

func _broadcast_state_delta() -> void:
	for player_id in _player_to_peer:
		var peer_id: int = _player_to_peer[player_id]
		var last_input: int = game_state.get_last_processed_input(player_id)
		var message := Serialization.encode_state_delta(game_state.current_tick, last_input, game_state.players)
		_send_to_peer(peer_id, message)

func _remove_player(player_id: String) -> void:
	if not game_state.has_player(player_id):
		return

	game_state.remove_player(player_id)

	# Clean up inventory data
	_player_inventories.erase(player_id)
	_player_equipment.erase(player_id)
	_player_hotbars.erase(player_id)

	var peer_id: int = _player_to_peer.get(player_id, -1)
	if peer_id >= 0:
		_peer_to_player.erase(peer_id)
	_player_to_peer.erase(player_id)

	# Notify other players
	_broadcast(Serialization.encode_player_left(player_id))

	player_disconnected.emit(player_id)

func _send_to_peer(peer_id: int, message: String) -> void:
	if _peers.has(peer_id):
		var ws_peer: WebSocketPeer = _peers[peer_id]
		if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws_peer.send_text(message)

func _broadcast(message: String) -> void:
	for peer_id in _peers:
		_send_to_peer(peer_id, message)

func _broadcast_except(except_peer_id: int, message: String) -> void:
	for peer_id in _peers:
		if peer_id != except_peer_id:
			_send_to_peer(peer_id, message)

func _generate_player_id() -> String:
	# Simple unique ID using timestamp and random
	var timestamp := Time.get_unix_time_from_system()
	var random := randi()
	return "%d_%d" % [int(timestamp * 1000) % 1000000, random % 10000]

func _on_chunk_requested(peer_id: int, world_x: int, world_y: int, radius: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	# Clamp radius to prevent abuse
	radius = clampi(radius, 1, 5)

	# Convert world position to chunk coordinates
	var center_chunk := chunk_manager.world_to_chunk_coords(world_x, world_y)

	# Send chunks around the requested position
	for cy in range(center_chunk.y - radius, center_chunk.y + radius + 1):
		for cx in range(center_chunk.x - radius, center_chunk.x + radius + 1):
			# Skip if out of bounds
			if cx < 0 or cy < 0:
				continue
			if cx >= chunk_manager.planet_size_chunks.x or cy >= chunk_manager.planet_size_chunks.y:
				continue

			var chunk := chunk_manager.get_chunk(cx, cy)
			_send_to_peer(peer_id, Serialization.encode_chunk_data(chunk))

func _on_tile_modify_requested(peer_id: int, world_x: int, world_y: int, tile_type: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	# Validate tile type
	if tile_type < 0 or tile_type >= TileTypes.Type.MAX:
		return

	# Apply the modification on server
	chunk_manager.set_tile(world_x, world_y, tile_type)

	# Get chunk coordinates for broadcasting
	var chunk_coords := chunk_manager.world_to_chunk_coords(world_x, world_y)
	var local_coords := chunk_manager.world_to_local_coords(world_x, world_y)

	# Broadcast delta to all connected players
	var changes := {
		"%d,%d" % [local_coords.x, local_coords.y]: {
			"type": tile_type,
			"variant": 0,
			"liquid": 0
		}
	}
	_broadcast(Serialization.encode_chunk_delta(chunk_coords.x, chunk_coords.y, changes))


# ===== Inventory System =====

## Initialize a new player's inventory with starter items
func _initialize_player_inventory(player_id: String, player: PlayerState) -> void:
	# Create starter loadout using registries
	var loadout: Dictionary = registries.create_starter_loadout()

	var inventory: Inventory = loadout["inventory"]
	var equipment: EquipmentSlots = loadout["equipment"]
	var hotbar: Hotbar = loadout["hotbar"]

	# Store live objects
	_player_inventories[player_id] = inventory
	_player_equipment[player_id] = equipment
	_player_hotbars[player_id] = hotbar

	# Serialize to PlayerState for network sync
	player.inventory = inventory.to_dict()
	player.equipment = equipment.to_dict()
	player.hotbar = hotbar.to_dict()
	player.stats = registries.calculate_player_stats(equipment)

	print("GameServer: Initialized inventory for player %s:" % player_id)
	print("  - Inventory: %d stacks, %.1f/%.1f weight" % [
		inventory.get_stack_count(),
		inventory.get_current_weight(),
		inventory.max_weight
	])
	print("  - Equipment: %d items equipped" % equipment.get_all_equipped().size())


## Sync player's inventory state to PlayerState for network
func _sync_player_inventory_to_state(player_id: String) -> void:
	var player := game_state.get_player(player_id)
	if player == null:
		return

	if _player_inventories.has(player_id):
		player.inventory = _player_inventories[player_id].to_dict()
	if _player_equipment.has(player_id):
		player.equipment = _player_equipment[player_id].to_dict()
		player.stats = registries.calculate_player_stats(_player_equipment[player_id])
	if _player_hotbars.has(player_id):
		player.hotbar = _player_hotbars[player_id].to_dict()


## Handle equip request from client
func _on_equip_requested(peer_id: int, inventory_slot: int, equip_slot: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	if not _player_inventories.has(player_id) or not _player_equipment.has(player_id):
		return

	var inventory: Inventory = _player_inventories[player_id]
	var equipment: EquipmentSlots = _player_equipment[player_id]

	# Get the stack at the inventory slot
	var stack := inventory.get_stack_at(inventory_slot)
	if stack == null or stack.is_empty():
		_send_to_peer(peer_id, Serialization.encode_error("No item in that slot"))
		return

	var item := stack.item
	if item == null or item.definition == null:
		_send_to_peer(peer_id, Serialization.encode_error("Invalid item"))
		return

	# Check if item is equippable
	if not item.definition.is_equippable():
		_send_to_peer(peer_id, Serialization.encode_error("Item cannot be equipped"))
		return

	# Equip the item (returns previously equipped item)
	var previous := equipment.equip(item)

	# Remove item from inventory
	inventory.remove_stack(stack)

	# If there was a previously equipped item, add it back to inventory
	if previous != null:
		var prev_stack := ItemStack.new(previous, 1)
		inventory.add_stack(prev_stack)

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Send updates to client
	var player := game_state.get_player(player_id)
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	print("GameServer: Player %s equipped %s" % [player_id, item.definition.name])


## Handle unequip request from client
func _on_unequip_requested(peer_id: int, equip_slot: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	if not _player_inventories.has(player_id) or not _player_equipment.has(player_id):
		return

	var inventory: Inventory = _player_inventories[player_id]
	var equipment: EquipmentSlots = _player_equipment[player_id]

	# Unequip the item
	var item := equipment.unequip(equip_slot)
	if item == null:
		_send_to_peer(peer_id, Serialization.encode_error("No item in that slot"))
		return

	# Add to inventory
	var stack := ItemStack.new(item, 1)
	var leftover := inventory.add_stack(stack)
	if leftover != null and not leftover.is_empty():
		# Couldn't fit in inventory, re-equip
		equipment.equip(item)
		_send_to_peer(peer_id, Serialization.encode_error("Inventory full"))
		return

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Send updates to client
	var player := game_state.get_player(player_id)
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	print("GameServer: Player %s unequipped %s" % [player_id, item.definition.name])


## Handle item drop request from client
func _on_item_drop_requested(peer_id: int, slot: int, count: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	if not _player_inventories.has(player_id):
		return

	var inventory: Inventory = _player_inventories[player_id]

	# Get the stack at the slot
	var stack := inventory.get_stack_at(slot)
	if stack == null or stack.is_empty():
		_send_to_peer(peer_id, Serialization.encode_item_drop_response(false, slot, "", "No item in that slot"))
		return

	# For now, just remove from inventory
	# TODO: Spawn world item when Phase 6 is implemented
	var item_name := stack.item.definition.name if stack.item and stack.item.definition else "Unknown"
	var drop_count := mini(count, stack.count)

	if drop_count >= stack.count:
		inventory.remove_stack(stack)
	else:
		stack.count -= drop_count

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Send updates to client
	var player := game_state.get_player(player_id)
	_send_to_peer(peer_id, Serialization.encode_item_drop_response(true, slot, ""))
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	print("GameServer: Player %s dropped %d x %s" % [player_id, drop_count, item_name])


## Handle item use request from client
func _on_item_use_requested(peer_id: int, slot: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	if not _player_inventories.has(player_id):
		return

	var inventory: Inventory = _player_inventories[player_id]

	# Get the stack at the slot
	var stack := inventory.get_stack_at(slot)
	if stack == null or stack.is_empty():
		_send_to_peer(peer_id, Serialization.encode_error("No item in that slot"))
		return

	var item := stack.item
	if item == null or item.definition == null:
		_send_to_peer(peer_id, Serialization.encode_error("Invalid item"))
		return

	# Check if item is consumable
	if item.definition.type != ItemEnums.ItemType.CONSUMABLE:
		_send_to_peer(peer_id, Serialization.encode_error("Item cannot be used"))
		return

	# Apply use effects (simplified for now)
	var effects := item.definition.use_effects
	if effects.has("heal"):
		# TODO: Apply healing when health system is implemented
		print("GameServer: Player %s used %s (heal: %d)" % [player_id, item.definition.name, effects["heal"]])

	# Consume the item
	stack.count -= 1
	if stack.is_empty():
		inventory.remove_stack(stack)

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Send updates to client
	var player := game_state.get_player(player_id)
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))
