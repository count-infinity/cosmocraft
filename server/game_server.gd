class_name GameServer
extends Node

const ServerRegistriesScript = preload("res://server/data/server_registries.gd")
const PlayerCorpseScript = preload("res://shared/entities/player_corpse.gd")
const CombatComponentScript = preload("res://shared/components/combat_component.gd")
const AttackResolverScript = preload("res://server/combat/attack_resolver.gd")
const HealthComponentScript = preload("res://shared/components/health_component.gd")
const EnemyManagerScript = preload("res://server/enemies/enemy_manager.gd")
const EnemyAIScript = preload("res://server/enemies/enemy_ai.gd")
const CombatProcessorScript = preload("res://server/combat/combat_processor.gd")

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

# Ground item despawn timer
var _despawn_check_interval: float = 10.0  # Check every 10 seconds
var _despawn_check_timer: float = 0.0

# Pickup range in pixels
const PICKUP_RANGE: float = 64.0

# Corpse run system
var _player_corpses: Dictionary = {}  # corpse_id -> PlayerCorpseScript
var _player_health_components: Dictionary = {}  # player_id -> HealthComponentScript
var _player_combat_components: Dictionary = {}  # player_id -> CombatComponent

# Enemy system
var _enemy_manager: RefCounted  # EnemyManager

# Combat constants
const RESPAWN_INVULNERABILITY_DURATION: float = 2.0  # Seconds of invuln after respawn
const CORPSE_RECOVERY_RANGE: float = 64.0  # Pixels - distance to recover corpse
const HP_REGEN_RATE: float = 5.0  # HP per second when out of combat

# Default weapon stats (unarmed combat)
const DEFAULT_ATTACK_DAMAGE: float = 5.0
const DEFAULT_ATTACK_SPEED: float = 2.5  # Attacks per second (0.4s cooldown)
const DEFAULT_ATTACK_RANGE: float = 50.0  # Melee range in pixels
const DEFAULT_ATTACK_ARC: float = 90.0  # Melee swing arc in degrees

func _init() -> void:
	config = ServerConfig.from_args()
	game_state = GameState.new()
	message_handler = ServerMessageHandler.new()

	# Initialize planet with random seed
	planet_seed = randi()
	chunk_manager = ChunkManager.new(planet_seed, planet_size)

	# Create game loop with chunk manager for collision checking
	game_loop = GameLoop.new(game_state, chunk_manager)

	# Initialize inventory registries
	registries = ServerRegistriesScript.new()

	# Initialize enemy system
	_enemy_manager = EnemyManagerScript.new(registries.enemy_registry)
	# EnemyAI is a stateless utility class - we just reference the script
	_enemy_manager.enemy_spawned.connect(_on_enemy_spawned)
	_enemy_manager.enemy_died.connect(_on_enemy_died)

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
	message_handler.item_pickup_requested.connect(_on_item_pickup_requested)

	# Connect crafting message handler signals
	message_handler.craft_requested.connect(_on_craft_requested)

	# Connect combat message handler signals
	message_handler.corpse_recover_requested.connect(_on_corpse_recover_requested)
	message_handler.attack_requested.connect(_on_attack_requested)

	# Connect game loop signals
	game_loop.tick_completed.connect(_on_tick_completed)

	# Connect ground item signals from game_state
	game_state.ground_item_spawned.connect(_on_ground_item_spawned)
	game_state.ground_item_removed.connect(_on_ground_item_removed)

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

	# Spawn test enemies near spawn point for combat testing
	_spawn_test_enemies()

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

	# Process ground item despawn timers
	_process_despawn_timer(delta)

	# Process HP regeneration for all players
	_process_hp_regen(delta)

	# Process combat cooldowns for all players
	_process_combat_cooldowns(delta)

	# Process corpse expiration
	_process_corpse_expiration()

func _process_despawn_timer(delta: float) -> void:
	_despawn_check_timer += delta
	if _despawn_check_timer >= _despawn_check_interval:
		_despawn_check_timer = 0.0
		var despawned := game_state.process_despawn_timers()
		if despawned.size() > 0:
			print("GameServer: Despawned %d ground items" % despawned.size())


func _process_hp_regen(delta: float) -> void:
	var current_time := Time.get_unix_time_from_system()

	for player_id in _player_health_components:
		var health: HealthComponentScript = _player_health_components[player_id]
		if health.is_dead:
			continue

		var old_hp := health.current_hp
		health.tick_regen(delta, HP_REGEN_RATE, current_time)

		# Sync to player state if HP changed
		if health.current_hp != old_hp:
			var player := game_state.get_player(player_id)
			if player != null:
				player.current_hp = health.current_hp

				# Send health update to the player
				if _player_to_peer.has(player_id):
					var peer_id: int = _player_to_peer[player_id]
					_send_to_peer(peer_id, Serialization.encode_health_update(
						player_id, health.current_hp, health.max_hp
					))


func _process_combat_cooldowns(delta: float) -> void:
	for player_id in _player_combat_components:
		var combat: CombatComponentScript = _player_combat_components[player_id]
		combat.tick(delta)


func _process_corpse_expiration() -> void:
	var current_time := Time.get_unix_time_from_system()
	var expired_corpses: Array[String] = []

	for corpse_id in _player_corpses:
		var corpse: PlayerCorpseScript = _player_corpses[corpse_id]
		if corpse.is_expired(current_time):
			expired_corpses.append(corpse_id)

	for corpse_id in expired_corpses:
		_player_corpses.erase(corpse_id)
		_broadcast(Serialization.encode_corpse_expired(corpse_id))
		print("GameServer: Corpse %s expired" % corpse_id)


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

	# Send existing ground items near the player
	_send_nearby_ground_items(peer_id, player.position)

	# Send existing enemies to the player
	_send_enemies_to_peer(peer_id)

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
	# Process enemy AI and combat
	_process_enemies()

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
	_player_health_components.erase(player_id)
	_player_combat_components.erase(player_id)

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

	# Initialize health component with max HP from stats
	var player_stats: Dictionary = registries.calculate_player_stats(equipment)
	var max_hp: float = float(player_stats.get(str(ItemEnums.StatType.MAX_HP), 100.0))
	var health := HealthComponentScript.new(max_hp)
	_player_health_components[player_id] = health

	# Initialize combat component with default stats
	var combat := CombatComponentScript.new(
		DEFAULT_ATTACK_DAMAGE,
		DEFAULT_ATTACK_SPEED,
		DEFAULT_ATTACK_RANGE,
		DEFAULT_ATTACK_ARC
	)
	_player_combat_components[player_id] = combat

	# Update combat stats if player already has a weapon equipped
	_update_player_weapon_stats(player_id)

	# Serialize to PlayerState for network sync
	player.inventory = inventory.to_dict()
	player.equipment = equipment.to_dict()
	player.hotbar = hotbar.to_dict()
	player.stats = player_stats

	# Initialize combat state on player
	player.current_hp = health.current_hp
	player.max_hp = health.max_hp
	player.is_dead = health.is_dead
	player.last_damage_time = health.last_damage_time
	player.invulnerable_until = health.invulnerable_until

	print("GameServer: Initialized inventory for player %s:" % player_id)
	print("  - Inventory: %d stacks, %.1f/%.1f weight" % [
		inventory.get_stack_count(),
		inventory.get_current_weight(),
		inventory.max_weight
	])
	print("  - Equipment: %d items equipped" % equipment.get_all_equipped().size())
	print("  - Health: %.0f/%.0f HP" % [health.current_hp, health.max_hp])


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


## Update combat component with equipped weapon stats
func _update_player_weapon_stats(player_id: String) -> void:
	if not _player_equipment.has(player_id) or not _player_combat_components.has(player_id):
		return

	var equipment: EquipmentSlots = _player_equipment[player_id]
	var combat: CombatComponentScript = _player_combat_components[player_id]
	var weapon: ItemInstance = equipment.get_equipped(ItemEnums.EquipSlot.MAIN_HAND)

	if weapon != null and weapon.definition != null:
		# Get weapon stats from definition
		var damage: float = float(weapon.definition.base_damage)
		var speed: float = weapon.definition.attack_speed if weapon.definition.attack_speed > 0 else DEFAULT_ATTACK_SPEED
		var weapon_range: float = weapon.definition.attack_range if weapon.definition.attack_range > 0 else DEFAULT_ATTACK_RANGE
		var arc: float = weapon.definition.attack_arc if weapon.definition.attack_arc > 0 else DEFAULT_ATTACK_ARC

		# Determine attack type from weapon
		var attack_type_int: int = AttackTypes.from_weapon_type(weapon.definition.weapon_type)
		var combat_attack_type: CombatComponentScript.AttackType
		if AttackTypes.is_ranged(attack_type_int):
			combat_attack_type = CombatComponentScript.AttackType.RANGED
		else:
			combat_attack_type = CombatComponentScript.AttackType.MELEE

		combat.configure_from_weapon(damage, speed, weapon_range, arc, combat_attack_type)
		print("GameServer: Updated combat stats for %s - Damage: %.1f, Speed: %.1f, Range: %.1f" % [
			player_id, damage, speed, weapon_range
		])
	else:
		# No weapon equipped - reset to unarmed defaults
		combat.configure_from_weapon(
			DEFAULT_ATTACK_DAMAGE,
			DEFAULT_ATTACK_SPEED,
			DEFAULT_ATTACK_RANGE,
			DEFAULT_ATTACK_ARC,
			CombatComponentScript.AttackType.MELEE
		)
		print("GameServer: Reset to unarmed combat stats for %s" % player_id)


## Handle equip request from client
func _on_equip_requested(peer_id: int, inventory_slot: int, equip_slot: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	if not _player_inventories.has(player_id) or not _player_equipment.has(player_id):
		return

	var inventory: Inventory = _player_inventories[player_id]
	var equipment: EquipmentSlots = _player_equipment[player_id]

	# Validate inventory slot bounds
	if inventory_slot < 0 or inventory_slot >= inventory.get_stack_count():
		_send_to_peer(peer_id, Serialization.encode_error("Invalid inventory slot"))
		return

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

	# Handle auto-detect equip slot (-1 means use item's default slot)
	var target_slot: int = equip_slot
	if target_slot == -1:
		target_slot = item.definition.equip_slot

	# Validate equip slot is a valid enum value (NONE=0 through ACCESSORY=7)
	if target_slot < 0 or target_slot > ItemEnums.EquipSlot.ACCESSORY:
		_send_to_peer(peer_id, Serialization.encode_error("Invalid equipment slot"))
		return

	# Equip the item (uses item's default slot)
	var previous := equipment.equip(item)

	# Remove item from inventory
	inventory.remove_stack(stack)

	# If there was a previously equipped item, add it back to inventory
	if previous != null:
		var prev_stack := ItemStack.new(previous, 1)
		inventory.add_stack(prev_stack)

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Update combat component with new weapon stats
	_update_player_weapon_stats(player_id)

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

	# Validate equip slot is a valid enum value (NONE=0 through ACCESSORY=7)
	# Note: NONE is technically invalid for unequip but unequip() handles it gracefully
	if equip_slot < 0 or equip_slot > ItemEnums.EquipSlot.ACCESSORY:
		_send_to_peer(peer_id, Serialization.encode_error("Invalid equipment slot"))
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

	# Update combat component (may revert to unarmed if weapon was unequipped)
	_update_player_weapon_stats(player_id)

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

	# Validate slot bounds
	if slot < 0 or slot >= inventory.get_stack_count():
		_send_to_peer(peer_id, Serialization.encode_item_drop_response(false, slot, "", "Invalid inventory slot"))
		return

	# Validate count is positive
	if count <= 0:
		_send_to_peer(peer_id, Serialization.encode_item_drop_response(false, slot, "", "Invalid drop count"))
		return

	var player := game_state.get_player(player_id)

	# Get the stack at the slot
	var stack := inventory.get_stack_at(slot)
	if stack == null or stack.is_empty():
		_send_to_peer(peer_id, Serialization.encode_item_drop_response(false, slot, "", "No item in that slot"))
		return

	var item_name := stack.item.definition.name if stack.item and stack.item.definition else "Unknown"
	var drop_count := mini(count, stack.count)

	# Create a new stack for the dropped items
	var dropped_stack: ItemStack
	if drop_count >= stack.count:
		# Drop the whole stack
		dropped_stack = stack
		inventory.remove_stack(stack)
	else:
		# Split the stack
		dropped_stack = stack.split(drop_count)
		if dropped_stack == null:
			# Split failed for non-stackable, drop the whole thing
			dropped_stack = stack
			inventory.remove_stack(stack)

	# Spawn the world item at player position with a small offset
	var drop_offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
	var drop_position := player.position + drop_offset
	var world_item := game_state.spawn_ground_item(dropped_stack, drop_position, player_id)

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Send updates to client
	_send_to_peer(peer_id, Serialization.encode_item_drop_response(true, slot, world_item.id))
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	print("GameServer: Player %s dropped %d x %s (world item: %s)" % [player_id, drop_count, item_name, world_item.id])


## Handle item pickup request from client
func _on_item_pickup_requested(peer_id: int, world_item_id: String, position: Vector2) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]
	var player := game_state.get_player(player_id)

	if not _player_inventories.has(player_id):
		return

	var inventory: Inventory = _player_inventories[player_id]

	# Check if the item exists
	var world_item := game_state.get_ground_item(world_item_id)
	if world_item == null:
		_send_to_peer(peer_id, Serialization.encode_item_pickup_response(false, world_item_id, null, "Item not found"))
		return

	# Check if player is in range
	var dist := player.position.distance_to(world_item.position)
	if dist > PICKUP_RANGE:
		_send_to_peer(peer_id, Serialization.encode_item_pickup_response(false, world_item_id, null, "Too far away"))
		return

	# Check loot protection
	if not world_item.can_pickup(player_id):
		_send_to_peer(peer_id, Serialization.encode_item_pickup_response(false, world_item_id, null, "Cannot pick up this item yet"))
		return

	# Try to add to inventory
	var stack := world_item.item_stack
	var leftover := inventory.add_stack(stack)

	if leftover != null and not leftover.is_empty():
		# Couldn't fit all items - put leftover back
		if leftover.count == stack.count:
			# Nothing was picked up
			_send_to_peer(peer_id, Serialization.encode_item_pickup_response(false, world_item_id, null, "Inventory full"))
			return
		# Partial pickup - update world item with leftover
		world_item.item_stack = leftover

	# Remove world item if fully picked up
	if leftover == null or leftover.is_empty():
		game_state.remove_ground_item(world_item_id, "pickup")

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Send updates to client
	_send_to_peer(peer_id, Serialization.encode_item_pickup_response(true, world_item_id, stack.to_dict()))
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	print("GameServer: Player %s picked up %s" % [player_id, stack.get_display_text()])


## Handle item use request from client
func _on_item_use_requested(peer_id: int, slot: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	if not _player_inventories.has(player_id):
		return

	var inventory: Inventory = _player_inventories[player_id]

	# Validate slot bounds
	if slot < 0 or slot >= inventory.get_stack_count():
		_send_to_peer(peer_id, Serialization.encode_error("Invalid inventory slot"))
		return

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


# ===== Ground Item Broadcasting =====

## Called when a ground item is spawned - broadcast to nearby players
func _on_ground_item_spawned(world_item: WorldItem) -> void:
	# Broadcast to all players (could optimize to only nearby players later)
	var message := Serialization.encode_ground_item_spawned(world_item)
	_broadcast(message)


## Called when a ground item is removed - broadcast to all players
func _on_ground_item_removed(item_id: String, reason: String) -> void:
	var message := Serialization.encode_ground_item_removed(item_id, reason)
	_broadcast(message)


## Send nearby ground items to a specific peer (on connect)
func _send_nearby_ground_items(peer_id: int, position: Vector2) -> void:
	# For now, send all ground items. Could optimize with spatial queries.
	var all_items := game_state.get_all_ground_items()
	if all_items.size() > 0:
		_send_to_peer(peer_id, Serialization.encode_ground_items_sync(all_items))


# ===== Crafting System =====

## Handle craft request from client
func _on_craft_requested(peer_id: int, recipe_id: String) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]

	if not _player_inventories.has(player_id):
		_send_to_peer(peer_id, Serialization.encode_craft_response(
			false, recipe_id, [], 0, "", "Player inventory not found"
		))
		return

	var inventory: Inventory = _player_inventories[player_id]
	var crafting: CraftingSystem = registries.crafting_system

	# Get the recipe
	var recipe: RecipeDefinition = crafting.get_recipe(recipe_id)
	if recipe == null:
		_send_to_peer(peer_id, Serialization.encode_craft_response(
			false, recipe_id, [], 0, "", "Recipe not found"
		))
		return

	# For now, use empty skill levels and no station requirement
	# TODO: Add player skills system and station proximity check
	var skill_levels: Dictionary = {}
	var current_station: String = ""  # Empty means "anywhere" crafting

	# Check if recipe can be crafted
	var error: String = crafting.get_craft_error(recipe, inventory, skill_levels, current_station)
	if not error.is_empty():
		_send_to_peer(peer_id, Serialization.encode_craft_response(
			false, recipe_id, [], 0, "", error
		))
		return

	# Execute crafting
	var outputs: Array[ItemStack] = crafting.craft(recipe, inventory, skill_levels, current_station)
	if outputs.is_empty():
		_send_to_peer(peer_id, Serialization.encode_craft_response(
			false, recipe_id, [], 0, "", "Crafting failed"
		))
		return

	# Get XP reward info
	var xp_gained: int = crafting.get_xp_reward(recipe)
	var skill_name: String = crafting.get_xp_skill(recipe)

	# TODO: Apply XP to player's skill when skill system is implemented

	# Serialize created items for response
	var items_created: Array = []
	for stack in outputs:
		items_created.append(stack.to_dict())

	# Sync to PlayerState
	_sync_player_inventory_to_state(player_id)

	# Send craft response
	_send_to_peer(peer_id, Serialization.encode_craft_response(
		true, recipe_id, items_created, xp_gained, skill_name
	))

	# Send updated inventory
	var player := game_state.get_player(player_id)
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	# Log the crafting action
	var output_names: Array[String] = []
	for stack in outputs:
		output_names.append(stack.get_display_text())
	print("GameServer: Player %s crafted %s (XP: %d %s)" % [
		player_id,
		", ".join(output_names),
		xp_gained,
		skill_name if not skill_name.is_empty() else "general"
	])


# ===== Combat System =====

## Handle a player dying - create corpse, respawn at spawn point
func _handle_player_death(player_id: String, killer_id: String) -> void:
	var player := game_state.get_player(player_id)
	if player == null:
		return

	if not _player_health_components.has(player_id):
		return

	var health: HealthComponentScript = _player_health_components[player_id]

	# Create corpse with player's inventory data
	var corpse := PlayerCorpseScript.new()
	corpse.init_from_death(
		player_id,
		player.name,
		player.position,
		player.inventory,
		Time.get_unix_time_from_system()
	)
	_player_corpses[corpse.id] = corpse

	# Clear player's inventory (keep equipped gear)
	if _player_inventories.has(player_id):
		_player_inventories[player_id].clear()
		player.inventory = _player_inventories[player_id].to_dict()

	# Update player state
	player.is_dead = true
	player.current_hp = 0.0

	# Broadcast death to all clients
	_broadcast(Serialization.encode_player_died(player_id, killer_id, corpse.to_dict()))

	# Also broadcast corpse spawn
	_broadcast(Serialization.encode_corpse_spawned(corpse.to_dict()))

	print("GameServer: Player %s died (killed by %s), corpse created: %s" % [
		player.name, killer_id if killer_id else "unknown", corpse.id
	])

	# Respawn the player after a short delay (handled immediately for now)
	_respawn_player(player_id)


## Respawn a dead player at the spawn point
func _respawn_player(player_id: String) -> void:
	var player := game_state.get_player(player_id)
	if player == null:
		return

	if not _player_health_components.has(player_id):
		return

	var health: HealthComponentScript = _player_health_components[player_id]
	var current_time := Time.get_unix_time_from_system()

	# Respawn at world spawn point (for now - later use nearest safe zone)
	var respawn_pos := Vector2(GameConstants.PLAYER_SPAWN_X, GameConstants.PLAYER_SPAWN_Y)

	# Revive with full HP and invulnerability
	health.revive()
	health.set_invulnerable(RESPAWN_INVULNERABILITY_DURATION, current_time)

	# Update player state
	player.position = respawn_pos
	player.velocity = Vector2.ZERO
	player.is_dead = false
	player.current_hp = health.current_hp
	player.max_hp = health.max_hp
	player.invulnerable_until = health.invulnerable_until

	# Broadcast respawn to all clients
	_broadcast(Serialization.encode_player_respawn(
		player_id, respawn_pos, health.current_hp, health.max_hp
	))

	print("GameServer: Player %s respawned at spawn point with %.0f HP, %.1fs invulnerability" % [
		player.name, health.current_hp, RESPAWN_INVULNERABILITY_DURATION
	])


## Handle corpse recovery request from client
func _on_corpse_recover_requested(peer_id: int, corpse_id: String) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]
	var player := game_state.get_player(player_id)
	if player == null:
		return

	# Check if corpse exists
	if not _player_corpses.has(corpse_id):
		_send_to_peer(peer_id, Serialization.encode_error("Corpse not found"))
		return

	var corpse: PlayerCorpseScript = _player_corpses[corpse_id]

	# Check if this is the player's own corpse
	if corpse.player_id != player_id:
		_send_to_peer(peer_id, Serialization.encode_error("This is not your corpse"))
		return

	# Check if player is in range
	var distance := player.position.distance_to(corpse.position)
	if distance > CORPSE_RECOVERY_RANGE:
		_send_to_peer(peer_id, Serialization.encode_error("Too far from corpse"))
		return

	# Check if corpse has already been recovered
	if corpse.recovered:
		_send_to_peer(peer_id, Serialization.encode_error("Corpse already recovered"))
		return

	# Recover inventory items
	if _player_inventories.has(player_id):
		var inventory: Inventory = _player_inventories[player_id]

		# Restore items from corpse to player inventory
		# The inventory_data is in dictionary form, we need to restore it
		var inv_data: Dictionary = corpse.inventory_data
		var old_inventory := Inventory.new(inventory.max_weight, registries.item_registry)
		old_inventory.from_dict(inv_data)

		for stack in old_inventory.get_all_stacks():
			var leftover := inventory.add_stack(stack)
			if leftover != null and not leftover.is_empty():
				# Couldn't fit all items, spawn as ground item
				var drop_offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
				game_state.spawn_ground_item(leftover, player.position + drop_offset, player_id)

		# Sync inventory
		_sync_player_inventory_to_state(player_id)

	# Mark corpse as recovered and remove it
	corpse.mark_recovered()
	_player_corpses.erase(corpse_id)

	# Broadcast corpse recovery
	_broadcast(Serialization.encode_corpse_recovered(player_id, corpse_id))

	# Send updated inventory to player
	_send_to_peer(peer_id, Serialization.encode_inventory_sync(
		player_id,
		player.inventory,
		player.equipment,
		player.hotbar,
		player.stats
	))

	print("GameServer: Player %s recovered corpse %s" % [player.name, corpse_id])


## Apply damage to a player (called by combat system)
## Returns true if damage was applied, false if player is dead/invulnerable
func apply_damage_to_player(player_id: String, amount: float, source_id: String = "") -> bool:
	if not _player_health_components.has(player_id):
		return false

	var health: HealthComponentScript = _player_health_components[player_id]
	var current_time := Time.get_unix_time_from_system()

	var actual_damage := health.take_damage(amount, current_time, source_id)
	if actual_damage <= 0.0:
		return false

	# Update player state
	var player := game_state.get_player(player_id)
	if player != null:
		player.current_hp = health.current_hp
		player.last_damage_time = health.last_damage_time

		# Send health update
		if _player_to_peer.has(player_id):
			var peer_id: int = _player_to_peer[player_id]
			_send_to_peer(peer_id, Serialization.encode_health_update(
				player_id, health.current_hp, health.max_hp
			))

	# Check for death
	if health.is_dead:
		_handle_player_death(player_id, source_id)

	return true


## Heal a player (called by item use, etc.)
## Returns actual amount healed
func heal_player(player_id: String, amount: float) -> float:
	if not _player_health_components.has(player_id):
		return 0.0

	var health: HealthComponentScript = _player_health_components[player_id]
	var actual_heal := health.heal(amount)

	if actual_heal > 0.0:
		# Update player state
		var player := game_state.get_player(player_id)
		if player != null:
			player.current_hp = health.current_hp

			# Send health update
			if _player_to_peer.has(player_id):
				var peer_id: int = _player_to_peer[player_id]
				_send_to_peer(peer_id, Serialization.encode_health_update(
					player_id, health.current_hp, health.max_hp
				))

	return actual_heal


## Get a player's current health component (for testing/debugging)
func get_player_health(player_id: String) -> HealthComponentScript:
	return _player_health_components.get(player_id, null)


## Get a player's current combat component (for testing/debugging)
func get_player_combat(player_id: String) -> CombatComponentScript:
	return _player_combat_components.get(player_id, null)


# ===== Attack System =====

## Handle attack request from a client
func _on_attack_requested(peer_id: int, aim_position: Vector2, attack_type: int) -> void:
	if not _peer_to_player.has(peer_id):
		return

	var player_id: String = _peer_to_player[peer_id]
	var player := game_state.get_player(player_id)
	if player == null:
		return

	# Cannot attack while dead
	if player.is_dead:
		return

	# Check if player has combat component
	if not _player_combat_components.has(player_id):
		return

	var combat: CombatComponentScript = _player_combat_components[player_id]

	# Check cooldown
	if not combat.can_attack():
		# Still on cooldown, ignore request
		return

	# Calculate aim direction from player position to aim position
	# Check for zero-length BEFORE normalizing to avoid NaN
	var to_target: Vector2 = aim_position - player.position
	var aim_direction: Vector2
	if to_target.length_squared() < 0.001:
		aim_direction = Vector2.RIGHT
	else:
		aim_direction = to_target.normalized()

	# Start the attack (sets cooldown)
	var attack_type_enum: CombatComponentScript.AttackType = attack_type as CombatComponentScript.AttackType
	if not combat.start_attack(attack_type_enum, aim_direction):
		return

	# Complete attack immediately (instant attacks)
	combat.complete_attack()

	# Find targets in attack range/arc
	var hits: Array = _find_attack_targets(player, aim_direction, attack_type_enum, combat)

	# Apply damage to each target
	var hit_results: Array = []
	for hit in hits:
		var hit_data: Dictionary = _apply_attack_damage(player_id, hit, combat)
		if not hit_data.is_empty():
			hit_results.append(hit_data)

	# Send attack result to the attacker
	_send_to_peer(peer_id, Serialization.encode_attack_result(
		true,
		hit_results,
		combat.attack_cooldown
	))

	# Broadcast damage to all players for each hit
	for hit_data in hit_results:
		_broadcast_entity_damaged(hit_data, player_id)


## Get all attackable entities as TargetData
## Excludes the attacker, dead entities, and invulnerable entities
## Returns an array of TargetData for use with AttackResolver
func _get_all_attackable_entities(attacker_id: String) -> Array:
	var targets: Array = []
	var current_time := Time.get_unix_time_from_system()

	# Add all attackable players
	for other_id in game_state.players:
		if other_id == attacker_id:
			continue  # Cannot attack self

		var other_player := game_state.get_player(other_id)
		if other_player == null or other_player.is_dead:
			continue

		# Check invulnerability
		if _player_health_components.has(other_id):
			var health: HealthComponentScript = _player_health_components[other_id]
			if health.is_invulnerable(current_time):
				continue

		# Create target data for hit detection
		var target := AttackResolverScript.create_target_from_player(other_id, other_player.position)
		targets.append(target)

	# Add all attackable enemies
	var enemy_registry: RefCounted = _enemy_manager.get_registry()
	for enemy in _enemy_manager.get_all_enemies():
		if not enemy.is_alive:
			continue

		# Get hitbox radius from definition
		var definition: Resource = enemy_registry.get_definition(enemy.definition_id)
		var hitbox_radius: float = 16.0  # Default
		if definition != null:
			hitbox_radius = definition.hitbox_radius

		var target := AttackResolverScript.create_target_from_enemy(enemy.id, enemy.position, hitbox_radius)
		targets.append(target)

	return targets


## Get the health component for any entity (player or enemy)
## Returns null if entity not found or has no health
func _get_entity_health(entity_id: String) -> HealthComponentScript:
	# Check if it's a player
	if _player_health_components.has(entity_id):
		return _player_health_components[entity_id]

	# TODO: Check if it's an enemy when enemy system is implemented
	# if _enemy_health_components.has(entity_id):
	#     return _enemy_health_components[entity_id]

	return null


## Check if an entity ID belongs to a player
func _is_player_entity(entity_id: String) -> bool:
	return game_state.has_player(entity_id)


## Check if an entity ID belongs to an enemy
func _is_enemy_entity(entity_id: String) -> bool:
	return _enemy_manager.has_enemy(entity_id)


## Find all valid targets for an attack
func _find_attack_targets(
	player: PlayerState,
	aim_direction: Vector2,
	attack_type: CombatComponentScript.AttackType,
	combat: CombatComponentScript
) -> Array:
	# Get all attackable targets
	var targets: Array = _get_all_attackable_entities(player.id)

	# Use attack resolver to find hits based on attack type
	var hits: Array = []
	if attack_type == CombatComponentScript.AttackType.MELEE:
		hits = AttackResolverScript.find_melee_targets(
			player.position,
			aim_direction,
			combat.attack_range,
			combat.attack_arc,
			targets
		)
	else:  # RANGED
		hits = AttackResolverScript.find_ranged_targets(
			player.position,
			aim_direction,
			combat.attack_range,
			targets
		)

	return hits


## Apply damage from an attack to a target
## Returns hit data dictionary for network sync
func _apply_attack_damage(
	attacker_id: String,
	hit: AttackResolverScript.HitResult,
	combat: CombatComponentScript
) -> Dictionary:
	var target_id: String = hit.target_id

	# Calculate damage (using base damage for now)
	# TODO: Use CombatCalculator when weapons have full stats
	var damage: float = combat.base_damage
	var is_crit: bool = false  # TODO: Implement crit chance

	var actual_damage: float = 0.0
	var remaining_hp: float = 0.0

	# Handle player targets (using HealthComponent)
	if _is_player_entity(target_id):
		var target_health: HealthComponentScript = _get_entity_health(target_id)
		if target_health == null:
			return {}

		var current_time := Time.get_unix_time_from_system()
		actual_damage = target_health.take_damage(damage, current_time, attacker_id)

		if actual_damage <= 0.0:
			return {}

		remaining_hp = target_health.current_hp
		_update_player_after_damage(target_id, target_health, attacker_id)

	# Handle enemy targets (using EnemyState.take_damage via EnemyManager)
	elif _is_enemy_entity(target_id):
		actual_damage = _enemy_manager.damage_enemy(target_id, damage, attacker_id)

		if actual_damage <= 0.0:
			return {}

		var enemy = _enemy_manager.get_enemy(target_id)
		if enemy != null:
			remaining_hp = enemy.current_hp
		# Note: EnemyManager handles the damaged/died signals internally

	else:
		return {}

	return {
		"target_id": target_id,
		"damage": actual_damage,
		"is_crit": is_crit,
		"remaining_hp": remaining_hp
	}


## Update player state after taking damage
func _update_player_after_damage(player_id: String, health: HealthComponentScript, attacker_id: String) -> void:
	var target_player := game_state.get_player(player_id)
	if target_player != null:
		target_player.current_hp = health.current_hp
		target_player.last_damage_time = health.last_damage_time

	# Check for death
	if health.is_dead:
		_handle_player_death(player_id, attacker_id)


## Note: Enemy damage is now handled directly in _apply_attack_damage via EnemyManager.damage_enemy()
## The EnemyManager's _on_enemy_damaged and _on_enemy_died callbacks handle retaliation and death


## Broadcast entity damage to all players
func _broadcast_entity_damaged(hit_data: Dictionary, attacker_id: String) -> void:
	if hit_data.is_empty():
		return

	var target_id: String = hit_data.get("target_id", "")
	if target_id.is_empty():
		return

	var target_player := game_state.get_player(target_id)
	var max_hp: float = 100.0
	if target_player != null:
		max_hp = target_player.max_hp

	_broadcast(Serialization.encode_entity_damaged(
		target_id,
		hit_data.get("damage", 0.0),
		hit_data.get("is_crit", false),
		hit_data.get("remaining_hp", 0.0),
		max_hp,
		attacker_id
	))


# =============================================================================
# Enemy System Integration
# =============================================================================

## Process enemy AI and combat each tick
func _process_enemies() -> void:
	var delta: float = GameConstants.TICK_INTERVAL
	var current_time: float = Time.get_unix_time_from_system()

	# Build player positions for AI
	var player_positions: Dictionary = {}
	for player_id in game_state.players:
		var player: PlayerState = game_state.players[player_id]
		if not player.is_dead:
			player_positions[player_id] = player.position

	# Process AI for all enemies (movement, state transitions, attack timing)
	_process_enemy_ai(delta, current_time, player_positions)

	# Process enemy attacks (damage dealing)
	_process_enemy_combat(current_time, player_positions)

	# Process respawns
	_enemy_manager.process_respawns(current_time)

	# Broadcast enemy state updates
	_broadcast_enemy_updates()


## Process AI for all enemies
func _process_enemy_ai(delta: float, current_time: float, player_positions: Dictionary) -> void:
	# Use the EnemyAI static methods to process each enemy
	for enemy in _enemy_manager.get_alive_enemies():
		var definition = _enemy_manager.get_registry().get_definition(enemy.definition_id)
		if definition == null:
			continue

		var movement: Vector2 = EnemyAIScript.process_enemy(
			enemy, delta, current_time, player_positions, definition
		)

		# Apply movement with collision checking
		if movement.length_squared() > 0:
			if chunk_manager != null:
				enemy.position = CollisionHelper.apply_movement_with_collision(
					enemy.position, movement, chunk_manager
				)
			else:
				enemy.position += movement

		# Clamp to world bounds
		enemy.position.x = clampf(enemy.position.x, 0, GameConstants.WORLD_WIDTH)
		enemy.position.y = clampf(enemy.position.y, 0, GameConstants.WORLD_HEIGHT)

	# Alert pack members - wolves that detect a player will alert nearby wolves
	EnemyAIScript.alert_pack_members(_enemy_manager, player_positions)


## Process enemy attacks and apply damage to players
func _process_enemy_combat(current_time: float, player_positions: Dictionary) -> void:
	var attack_results: Array = CombatProcessorScript.process_enemy_attacks(
		_enemy_manager,
		player_positions,
		_player_health_components,
		current_time
	)

	# Handle attack results
	for result in attack_results:
		var target_id: String = result.target_id
		var damage: float = result.damage

		# Update player state from health component
		if _player_health_components.has(target_id):
			var health: HealthComponentScript = _player_health_components[target_id]
			var player := game_state.get_player(target_id)
			if player != null:
				player.current_hp = health.current_hp
				player.last_damage_time = health.last_damage_time

				# Send damage update to target
				if _player_to_peer.has(target_id):
					var peer_id: int = _player_to_peer[target_id]
					_send_to_peer(peer_id, Serialization.encode_health_update(
						target_id, health.current_hp, health.max_hp
					))

				# Broadcast damage to all players
				_broadcast(Serialization.encode_entity_damaged(
					target_id, damage, false, health.current_hp, health.max_hp, result.enemy_id
				))

				# Handle death
				if health.is_dead:
					_handle_player_death(target_id, result.enemy_id)


## Broadcast enemy position/state updates to all players
func _broadcast_enemy_updates() -> void:
	for enemy in _enemy_manager.get_all_enemies():
		# Send update for all alive enemies
		if enemy.is_alive:
			_broadcast(Serialization.encode_enemy_update(
				enemy.id,
				enemy.position,
				enemy.velocity,
				enemy.current_hp,
				enemy.state
			))


## Spawn test enemies near the player spawn point for combat testing
func _spawn_test_enemies() -> void:
	# Player spawn point from GameConstants (512, 512)
	var spawn_center := Vector2(GameConstants.PLAYER_SPAWN_X, GameConstants.PLAYER_SPAWN_Y)

	# Spawn some rabbits nearby (passive, for target practice)
	_enemy_manager.spawn_enemy("rabbit", spawn_center + Vector2(200, 100))
	_enemy_manager.spawn_enemy("rabbit", spawn_center + Vector2(-150, 200))
	_enemy_manager.spawn_enemy("rabbit", spawn_center + Vector2(100, -180))

	# Spawn a wolf pack (aggressive, will chase player and alert pack members)
	_enemy_manager.spawn_enemy("wolf", spawn_center + Vector2(350, 350))
	_enemy_manager.spawn_enemy("wolf", spawn_center + Vector2(400, 320))
	_enemy_manager.spawn_enemy("wolf", spawn_center + Vector2(380, 400))

	print("GameServer: Spawned %d test enemies near player spawn" % _enemy_manager.get_enemy_count())


## Send all existing enemies to a specific peer (on connect)
func _send_enemies_to_peer(peer_id: int) -> void:
	var all_enemies: Array = _enemy_manager.get_all_enemies()
	for enemy_state in all_enemies:
		var definition: Resource = registries.enemy_registry.get_definition(enemy_state.definition_id)
		_send_to_peer(peer_id, Serialization.encode_enemy_spawn(enemy_state, definition))


## Handle enemy spawned signal
func _on_enemy_spawned(enemy_state: RefCounted) -> void:
	# Get the definition to include in the spawn message
	var definition: Resource = registries.enemy_registry.get_definition(enemy_state.definition_id)
	# Broadcast to all connected players
	_broadcast(Serialization.encode_enemy_spawn(enemy_state, definition))


## Handle enemy died signal
func _on_enemy_died(enemy_id: String, killer_id: String) -> void:
	# Get the enemy before it might be removed
	var enemy = _enemy_manager.get_enemy(enemy_id)
	if enemy == null:
		return

	# Broadcast death to all players
	_broadcast(Serialization.encode_enemy_death(enemy_id, killer_id, enemy.position, []))

	# TODO: Generate loot drops from enemy's loot table
	# var loot_table_id: String = enemy.definition_id + "_loot"
	# if registries.loot_registry.has_table(loot_table_id):
	#     var drops := registries.loot_generator.generate_loot(loot_table_id, enemy.position)
	#     for drop in drops:
	#         game_state.add_ground_item(drop)
