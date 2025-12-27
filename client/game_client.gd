class_name GameClient
extends Node

const ClientRegistriesClass = preload("res://client/data/client_registries.gd")
const WorldItemVisualScript = preload("res://client/world/world_item_visual.gd")
const EnemyVisualScript = preload("res://client/world/enemy_visual.gd")
const DamageNumberScript = preload("res://client/ui/damage_number.gd")
const AttackEffectScript = preload("res://client/ui/attack_effect.gd")

signal connected(player_id: String)
signal disconnected()
signal connection_failed(reason: String)
signal chunk_manager_ready(chunk_manager: ChunkManager)

# Inventory signals (forwarded from message handler for UI)
signal inventory_changed
signal equipment_changed(slot: int)
signal hotbar_changed
signal stats_changed

# Ground item signals
signal ground_item_added(item_id: String)
signal ground_item_removed(item_id: String)

# Crafting signals
signal craft_response_received(success: bool, recipe_id: String, items_created: Array, xp_gained: int, error: String)

# Combat signals
signal health_updated(player_id: String, current_hp: float, max_hp: float)
signal player_died()  # Local player died
signal player_respawned()  # Local player respawned
signal corpse_spawned(corpse_data: Dictionary)
signal corpse_recovered(corpse_id: String)
signal corpse_expired(corpse_id: String)

# Attack signals
signal attack_result_received(success: bool, hits: Array, cooldown: float)
signal entity_damaged(entity_id: String, damage: float, is_crit: bool, current_hp: float, max_hp: float, attacker_id: String)
signal entity_died(entity_id: String, killer_id: String, entity_type: String)

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

# Ground items system
var ground_items: Dictionary = {}  # item_id -> WorldItem
var ground_item_visuals: Dictionary = {}  # item_id -> WorldItemVisual node

# Enemy visual system
var enemy_visuals: Dictionary = {}  # enemy_id -> EnemyVisual node
var enemy_definitions: Dictionary = {}  # definition_id -> Dictionary (cached definitions)

# Pickup interaction
const PICKUP_RANGE: float = 64.0
const PICKUP_KEY: String = "pickup"  # Can be bound in input map or use 'E' key

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

	# Connect ground item message handler signals
	message_handler.ground_item_spawned_received.connect(_on_ground_item_spawned)
	message_handler.ground_item_removed_received.connect(_on_ground_item_removed)
	message_handler.ground_items_sync_received.connect(_on_ground_items_sync)

	# Connect crafting message handler signals
	message_handler.craft_response_received.connect(_on_craft_response)

	# Connect combat message handler signals
	message_handler.player_died_received.connect(_on_player_died)
	message_handler.player_respawn_received.connect(_on_player_respawn)
	message_handler.corpse_spawned_received.connect(_on_corpse_spawned)
	message_handler.corpse_recovered_received.connect(_on_corpse_recovered)
	message_handler.corpse_expired_received.connect(_on_corpse_expired)
	message_handler.health_update_received.connect(_on_health_update)

	# Connect attack message handler signals
	message_handler.attack_result_received.connect(_on_attack_result)
	message_handler.entity_damaged_received.connect(_on_entity_damaged)
	message_handler.entity_died_received.connect(_on_entity_died)

	# Connect enemy message handler signals
	message_handler.enemy_spawn_received.connect(_on_enemy_spawn)
	message_handler.enemy_update_received.connect(_on_enemy_update)
	message_handler.enemy_death_received.connect(_on_enemy_death)
	message_handler.enemy_despawn_received.connect(_on_enemy_despawn)

	# Connect to self to update attack controller when weapon changes
	equipment_changed.connect(_on_weapon_equipment_changed)

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

func _unhandled_input(event: InputEvent) -> void:
	# Handle pickup key press
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_F:
			_try_pickup_nearby_item()

func _try_pickup_nearby_item() -> void:
	if local_player == null or ground_items.is_empty():
		return

	var player_pos := local_player.position
	var closest_item: WorldItem = null
	var closest_dist: float = PICKUP_RANGE

	# Find the closest item within pickup range
	for item_id in ground_items:
		var world_item: WorldItem = ground_items[item_id]
		var dist := player_pos.distance_to(world_item.position)
		if dist < closest_dist:
			closest_dist = dist
			closest_item = world_item

	# Request pickup if we found an item
	if closest_item != null:
		request_pickup_item(closest_item.id, closest_item.position)

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

	# Clean up ground items
	for item_id in ground_item_visuals:
		if is_instance_valid(ground_item_visuals[item_id]):
			ground_item_visuals[item_id].queue_free()
	ground_items.clear()
	ground_item_visuals.clear()

	# Clean up enemy visuals
	for enemy_id in enemy_visuals:
		if is_instance_valid(enemy_visuals[enemy_id]):
			enemy_visuals[enemy_id].queue_free()
	enemy_visuals.clear()
	enemy_definitions.clear()

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
		var p_name: String = player_data.get("name", "Unknown")

		if player_id == _player_id:
			# Create local player
			if local_player == null:
				local_player = LocalPlayerScene.instantiate()
				local_player.initialize(player_id, p_name, pos)
				local_player.input_generated.connect(_on_local_player_input)
				local_player.attack_requested.connect(_on_local_player_attack)
				add_child(local_player)
		else:
			# Create or update remote player
			if not remote_players.has(player_id):
				var remote := RemotePlayerScene.instantiate()
				remote.initialize(player_id, p_name, pos)
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
	var p_name: String = player_data.get("name", "Unknown")
	var pos := Vector2(player_data["position"]["x"], player_data["position"]["y"])

	if player_id != _player_id and not remote_players.has(player_id):
		var remote := RemotePlayerScene.instantiate()
		remote.initialize(player_id, p_name, pos)
		remote_players[player_id] = remote
		add_child(remote)
		print("GameClient: Player joined: %s" % p_name)

func _on_player_left(player_id: String) -> void:
	if remote_players.has(player_id):
		print("GameClient: Player left: %s" % player_id)
		remote_players[player_id].queue_free()
		remote_players.erase(player_id)

func _on_pong(client_time: int, _server_time: int) -> void:
	var now := Time.get_ticks_msec()
	var _rtt := now - client_time
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


func _on_local_player_attack(aim_position: Vector2, attack_type: int) -> void:
	# Send attack request to server
	request_attack(aim_position, attack_type)

func is_connected_to_server() -> bool:
	return _connected and _player_id != ""

func get_player_id() -> String:
	return _player_id

func _on_planet_info(seed_val: int, size_x: int, size_y: int) -> void:
	print("GameClient: Received planet info - seed: %d, size: %dx%d" % [seed_val, size_x, size_y])

	# Initialize chunk manager with same seed as server
	chunk_manager = ChunkManager.new(seed_val, Vector2i(size_x, size_y))

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


## Handle weapon equipment changes to update attack controller
func _on_weapon_equipment_changed(slot: int) -> void:
	# Only care about main hand (weapons) or full refresh (-1)
	if slot != -1 and slot != ItemEnums.EquipSlot.MAIN_HAND:
		return

	if local_player == null or local_player.attack_controller == null:
		return

	if local_equipment == null:
		return

	# Get the equipped weapon
	var weapon: ItemInstance = local_equipment.get_equipped(ItemEnums.EquipSlot.MAIN_HAND)
	if weapon == null:
		# No weapon - reset to unarmed
		local_player.attack_controller.configure_from_item(null)
		return

	# Configure attack controller from weapon's definition
	local_player.attack_controller.configure_from_item(weapon.definition)


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


# =============================================================================
# Ground item handlers
# =============================================================================

func _on_ground_item_spawned(item_data: Dictionary) -> void:
	var world_item := WorldItem.from_dict(item_data, client_registries.item_registry)
	if world_item == null:
		return

	ground_items[world_item.id] = world_item
	_create_ground_item_visual(world_item)
	ground_item_added.emit(world_item.id)

	print("GameClient: Ground item spawned: %s at (%d, %d)" % [
		world_item.get_display_name(),
		int(world_item.position.x),
		int(world_item.position.y)
	])


func _on_ground_item_removed(item_id: String, reason: String) -> void:
	if not ground_items.has(item_id):
		return

	var world_item: WorldItem = ground_items[item_id]
	print("GameClient: Ground item removed: %s (%s)" % [world_item.get_display_name(), reason])

	# Remove visual
	if ground_item_visuals.has(item_id):
		var visual = ground_item_visuals[item_id]
		if is_instance_valid(visual):
			visual.queue_free()
		ground_item_visuals.erase(item_id)

	ground_items.erase(item_id)
	ground_item_removed.emit(item_id)


func _on_ground_items_sync(items: Array) -> void:
	print("GameClient: Syncing %d ground items" % items.size())

	# Clear existing items first
	for item_id in ground_item_visuals.keys():
		if is_instance_valid(ground_item_visuals[item_id]):
			ground_item_visuals[item_id].queue_free()
	ground_items.clear()
	ground_item_visuals.clear()

	# Add all received items
	for item_data in items:
		if item_data is Dictionary:
			var world_item := WorldItem.from_dict(item_data, client_registries.item_registry)
			if world_item != null:
				ground_items[world_item.id] = world_item
				_create_ground_item_visual(world_item)


func _create_ground_item_visual(world_item: WorldItem) -> void:
	if world == null:
		return

	var visual := WorldItemVisualScript.new()
	visual.initialize(world_item, client_registries.item_registry)
	world.add_child(visual)
	ground_item_visuals[world_item.id] = visual


## Get all ground items within a certain range of a position
func get_nearby_ground_items(position: Vector2, radius: float) -> Array:
	var nearby: Array = []
	var radius_sq := radius * radius

	for item_id in ground_items:
		var world_item: WorldItem = ground_items[item_id]
		var dist_sq := position.distance_squared_to(world_item.position)
		if dist_sq <= radius_sq:
			nearby.append(world_item)

	return nearby


## Get the closest ground item to a position within a max range
func get_closest_ground_item(position: Vector2, max_range: float) -> WorldItem:
	var closest: WorldItem = null
	var closest_dist_sq: float = max_range * max_range

	for item_id in ground_items:
		var world_item: WorldItem = ground_items[item_id]
		var dist_sq := position.distance_squared_to(world_item.position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = world_item

	return closest


# =============================================================================
# Crafting request functions (client -> server)
# =============================================================================

## Request to craft a recipe
func request_craft(recipe_id: String) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_craft_request(recipe_id))


# =============================================================================
# Crafting response handlers
# =============================================================================

func _on_craft_response(
	success: bool,
	recipe_id: String,
	items_created: Array,
	xp_gained: int,
	skill_name: String,
	error: String
) -> void:
	if success:
		var recipe := client_registries.crafting_system.get_recipe(recipe_id)
		var recipe_name := recipe.name if recipe != null else recipe_id
		print("GameClient: Crafted %s successfully! (+%d XP)" % [recipe_name, xp_gained])
	else:
		print("GameClient: Crafting failed: %s" % error)

	# Emit signal for UI to handle
	craft_response_received.emit(success, recipe_id, items_created, xp_gained, error)


# =============================================================================
# Combat handlers
# =============================================================================

## Accessor for local player ID (used by health bar and other UI)
var local_player_id: String:
	get:
		return _player_id


## Get the local player state from game client's tracked state
func get_local_player_state() -> PlayerState:
	if local_player == null:
		return null
	# The local player tracks its own state through prediction
	# For HP display, we need the authoritative state from remote_players or the initial state
	# Since the client doesn't track PlayerState objects directly, return null for now
	# The health bar will rely on health_updated signals instead
	return null


func _on_player_died(player_id: String, killer_id: String, corpse_data: Dictionary) -> void:
	print("GameClient: Player %s died (killed by %s)" % [player_id, killer_id])

	if player_id == _player_id:
		# Local player died
		print("GameClient: You died!")
		player_died.emit()

	corpse_spawned.emit(corpse_data)


func _on_player_respawn(player_id: String, position: Vector2, current_hp: float, max_hp: float) -> void:
	print("GameClient: Player %s respawned at %s with %.0f/%.0f HP" % [player_id, position, current_hp, max_hp])

	if player_id == _player_id:
		# Local player respawned - update local player position
		if local_player != null:
			local_player.position = position

		player_respawned.emit()
		health_updated.emit(player_id, current_hp, max_hp)


func _on_corpse_spawned(corpse_data: Dictionary) -> void:
	corpse_spawned.emit(corpse_data)


func _on_corpse_recovered(player_id: String, corpse_id: String) -> void:
	print("GameClient: Player %s recovered corpse %s" % [player_id, corpse_id])
	corpse_recovered.emit(corpse_id)


func _on_corpse_expired(corpse_id: String) -> void:
	print("GameClient: Corpse %s expired" % corpse_id)
	corpse_expired.emit(corpse_id)


func _on_health_update(player_id: String, current_hp: float, max_hp: float) -> void:
	# Forward to UI
	health_updated.emit(player_id, current_hp, max_hp)


## Send a corpse recovery request to the server
func request_corpse_recovery(corpse_id: String) -> void:
	if not _connected:
		return
	_send(Serialization.encode_corpse_recover_request(corpse_id))


# =============================================================================
# Attack request functions (client -> server)
# =============================================================================

## Request an attack at the given aim position
func request_attack(aim_position: Vector2, attack_type: int) -> void:
	if not is_connected_to_server():
		return

	_send(Serialization.encode_attack_request(aim_position, attack_type))


# =============================================================================
# Attack response handlers
# =============================================================================

func _on_attack_result(success: bool, hits: Array, cooldown: float) -> void:
	if success and hits.size() > 0:
		print("GameClient: Attack hit %d targets" % hits.size())

	# Sync cooldown to local attack controller
	if local_player != null and local_player.attack_controller != null:
		local_player.attack_controller.apply_server_cooldown(cooldown)

	# Forward to UI/feedback systems
	attack_result_received.emit(success, hits, cooldown)


func _on_entity_damaged(
	entity_id: String,
	damage: float,
	is_crit: bool,
	current_hp: float,
	max_hp: float,
	attacker_id: String
) -> void:
	# Log damage events
	if damage > 0:
		var crit_text := " (CRIT)" if is_crit else ""
		print("GameClient: Entity %s took %.0f damage%s from %s (HP: %.0f/%.0f)" % [
			entity_id, damage, crit_text, attacker_id, current_hp, max_hp
		])

	# Show damage number and update enemy visual
	if enemy_visuals.has(entity_id):
		var enemy_visual: EnemyVisual = enemy_visuals[entity_id]
		enemy_visual.show_damage(damage, is_crit)

		# Update health only (don't add to interpolation buffer)
		enemy_visual.update_health(current_hp, max_hp, current_hp > 0)

		# Show attack effect from attacker to enemy
		_show_attack_effect(attacker_id, entity_id, is_crit)

	# Forward to UI for damage numbers, health bar updates, etc.
	entity_damaged.emit(entity_id, damage, is_crit, current_hp, max_hp, attacker_id)


func _on_entity_died(entity_id: String, killer_id: String, entity_type: String) -> void:
	print("GameClient: Entity %s (%s) killed by %s" % [entity_id, entity_type, killer_id])

	# Forward to UI
	entity_died.emit(entity_id, killer_id, entity_type)


# =============================================================================
# Enemy handlers
# =============================================================================

func _on_enemy_spawn(enemy_data: Dictionary, definition_data: Dictionary) -> void:
	var enemy_id: String = enemy_data.get("id", "")
	if enemy_id.is_empty():
		return

	# Cache the definition if provided
	var def_id: String = enemy_data.get("definition_id", "")
	if not definition_data.is_empty() and not def_id.is_empty():
		enemy_definitions[def_id] = definition_data

	# Create visual
	_create_enemy_visual(enemy_data, definition_data)

	print("GameClient: Enemy spawned: %s (%s)" % [enemy_id, def_id])


func _on_enemy_update(enemy_id: String, state_data: Dictionary) -> void:
	if not enemy_visuals.has(enemy_id):
		return

	var enemy_visual: EnemyVisual = enemy_visuals[enemy_id]

	# Extract position
	var pos_data: Dictionary = state_data.get("position", {})
	var pos := Vector2(
		float(pos_data.get("x", enemy_visual.position.x)),
		float(pos_data.get("y", enemy_visual.position.y))
	)

	# Extract facing direction
	var facing_data: Dictionary = state_data.get("facing_direction", {})
	var facing := Vector2(
		float(facing_data.get("x", 1.0)),
		float(facing_data.get("y", 0.0))
	)

	var current_hp := float(state_data.get("current_hp", enemy_visual.current_hp))
	var max_hp := float(state_data.get("max_hp", enemy_visual.max_hp))
	var is_alive: bool = state_data.get("is_alive", enemy_visual.is_alive)

	enemy_visual.update_state(pos, facing, current_hp, max_hp, is_alive)


func _on_enemy_death(enemy_id: String, killer_id: String, _loot_items: Array) -> void:
	print("GameClient: Enemy died: %s (killed by %s)" % [enemy_id, killer_id])

	if enemy_visuals.has(enemy_id):
		var enemy_visual: EnemyVisual = enemy_visuals[enemy_id]
		# Mark as dead (visual handles death animation)
		enemy_visual.update_health(0.0, enemy_visual.max_hp, false)


func _on_enemy_despawn(enemy_id: String) -> void:
	if not enemy_visuals.has(enemy_id):
		return

	var enemy_visual = enemy_visuals[enemy_id]
	if is_instance_valid(enemy_visual):
		enemy_visual.queue_free()

	enemy_visuals.erase(enemy_id)
	print("GameClient: Enemy despawned: %s" % enemy_id)


func _create_enemy_visual(enemy_data: Dictionary, definition_data: Dictionary) -> void:
	if world == null:
		return

	var enemy_id: String = enemy_data.get("id", "")
	if enemy_id.is_empty() or enemy_visuals.has(enemy_id):
		return

	# Try to get cached definition if not provided
	var def_id: String = enemy_data.get("definition_id", "")
	if definition_data.is_empty() and enemy_definitions.has(def_id):
		definition_data = enemy_definitions[def_id]

	var visual := EnemyVisualScript.create_from_state(enemy_data, definition_data)
	world.add_child(visual)
	enemy_visuals[enemy_id] = visual


# =============================================================================
# Attack effect helpers
# =============================================================================

func _show_attack_effect(attacker_id: String, target_id: String, is_crit: bool) -> void:
	if world == null:
		return

	# Get attacker position
	var attacker_pos: Vector2 = Vector2.ZERO
	if attacker_id == _player_id and local_player != null:
		attacker_pos = local_player.position
	elif remote_players.has(attacker_id):
		attacker_pos = remote_players[attacker_id].position
	elif enemy_visuals.has(attacker_id):
		attacker_pos = enemy_visuals[attacker_id].position
	else:
		return  # Unknown attacker, skip effect

	# Get target position
	var target_pos: Vector2 = Vector2.ZERO
	if enemy_visuals.has(target_id):
		target_pos = enemy_visuals[target_id].position
	elif target_id == _player_id and local_player != null:
		target_pos = local_player.position
	elif remote_players.has(target_id):
		target_pos = remote_players[target_id].position
	else:
		return  # Unknown target, skip effect

	# Get weapon effect type from attacker
	var effect_type: String = "melee"  # Default
	if attacker_id == _player_id and local_player != null and local_player.attack_controller != null:
		effect_type = local_player.attack_controller.get_effect_type()

	# Create attack effect based on weapon type
	var effect := AttackEffectScript.create_for_weapon(effect_type, attacker_pos, target_pos, is_crit)
	world.add_child(effect)

	# Also create impact effect at target
	var impact := AttackEffectScript.create_impact(target_pos, is_crit)
	world.add_child(impact)
