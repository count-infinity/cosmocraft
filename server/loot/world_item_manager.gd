class_name WorldItemManager
extends RefCounted
## Server-side manager for items dropped in the world.
## Handles spawning, pickup, despawning, and synchronization of world items.


## Emitted when a world item is added
signal item_added(world_item: WorldItem)

## Emitted when a world item is removed (for any reason)
signal item_removed(item_id: String, reason: String)

## Emitted when a player picks up an item
signal item_picked_up(world_item: WorldItem, player_id: String)

## Emitted when items despawn due to timeout
signal items_despawned(item_ids: Array)


## All world items currently in the game, keyed by ID
var _items: Dictionary = {}

## Reference to the item registry for creating items
var _item_registry: ItemRegistry

## World item factory for creating items
var _factory: WorldItemFactory

## Time tracking for despawn checks
var _time_since_despawn_check: float = 0.0


func _init(item_registry: ItemRegistry = null) -> void:
	_item_registry = item_registry
	if item_registry != null:
		_factory = WorldItemFactory.new(item_registry)


## Set the item registry (for late initialization)
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry
	_factory = WorldItemFactory.new(registry)


## Add a world item to tracking
func add_item(world_item: WorldItem) -> bool:
	if world_item == null:
		return false
	if world_item.id.is_empty():
		world_item.id = WorldItem.generate_id()
	_items[world_item.id] = world_item
	item_added.emit(world_item)
	return true


## Add multiple world items
func add_items(world_items: Array) -> int:
	var added := 0
	for item in world_items:
		if item is WorldItem and add_item(item):
			added += 1
	return added


## Remove a world item by ID
func remove_item(item_id: String, reason: String = "removed") -> WorldItem:
	if not _items.has(item_id):
		return null
	var item: WorldItem = _items[item_id]
	_items.erase(item_id)
	item_removed.emit(item_id, reason)
	return item


## Get a world item by ID
func get_item(item_id: String) -> WorldItem:
	return _items.get(item_id, null)


## Check if an item exists
func has_item(item_id: String) -> bool:
	return item_id in _items


## Get all world items
func get_all_items() -> Array:
	return _items.values()


## Get all item IDs
func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _items.keys():
		ids.append(id)
	return ids


## Get item count
func get_item_count() -> int:
	return _items.size()


## Clear all items
func clear() -> void:
	_items.clear()


## Get items within a radius of a position
func get_items_in_radius(position: Vector2, radius: float) -> Array:
	var nearby: Array = []
	for item: WorldItem in _items.values():
		if item.position.distance_to(position) <= radius:
			nearby.append(item)
	return nearby


## Get items that a player can pick up (within pickup radius and not protected)
func get_pickupable_items(player_id: String, player_position: Vector2) -> Array:
	var pickupable: Array = []

	for item: WorldItem in _items.values():
		if not item.can_pickup(player_id):
			continue
		if item.position.distance_to(player_position) > GameConstants.LOOT_PICKUP_RADIUS:
			continue
		pickupable.append(item)

	return pickupable


## Attempt to pick up an item for a player
## Returns the WorldItem if successful, null if failed
func try_pickup(item_id: String, player_id: String, player_position: Vector2) -> WorldItem:
	var item := get_item(item_id)
	if item == null:
		return null

	if not item.can_pickup(player_id):
		return null

	if item.position.distance_to(player_position) > GameConstants.LOOT_PICKUP_RADIUS:
		return null

	# Remove without signal, then emit pickup signal
	_items.erase(item_id)
	item_picked_up.emit(item, player_id)
	item_removed.emit(item_id, "picked_up")
	return item


## Update manager state (call each tick)
## Returns array of item IDs that were despawned
func update(delta: float) -> Array[String]:
	_time_since_despawn_check += delta

	if _time_since_despawn_check < GameConstants.LOOT_DESPAWN_CHECK_INTERVAL:
		return []

	_time_since_despawn_check = 0.0
	return _check_despawns()


## Spawn an item at a position
## Returns the created WorldItem or null on failure
func spawn_item(
	item_id: String,
	quantity: int,
	position: Vector2,
	owner_id: String = "",
	quality: float = 1.0
) -> WorldItem:
	if _factory == null:
		push_warning("WorldItemManager: Factory not initialized")
		return null

	var world_item := _factory.create(item_id, quantity, position, owner_id, quality)
	if world_item == null:
		return null

	add_item(world_item)
	return world_item


## Get serialized data for all items (for full state sync)
func get_state_data() -> Array:
	var data: Array = []
	for item: WorldItem in _items.values():
		data.append(item.to_dict())
	return data


## Get serialized data for items in a region (for chunked sync)
func get_state_data_in_region(center: Vector2, radius: float) -> Array:
	var data: Array = []
	for item: WorldItem in _items.values():
		if item.position.distance_to(center) <= radius:
			data.append(item.to_dict())
	return data


## Result of a pickup attempt
class PickupResult:
	var success: bool = false
	var item: WorldItem = null
	var reason: String = ""

	static func succeeded(p_item: WorldItem) -> PickupResult:
		var result := PickupResult.new()
		result.success = true
		result.item = p_item
		return result

	static func failed(p_reason: String) -> PickupResult:
		var result := PickupResult.new()
		result.success = false
		result.reason = p_reason
		return result


## Attempt pickup with detailed result
func try_pickup_detailed(
	item_id: String,
	player_id: String,
	player_position: Vector2
) -> PickupResult:
	var item := get_item(item_id)
	if item == null:
		return PickupResult.failed("Item not found")

	if not item.can_pickup(player_id):
		return PickupResult.failed("Item is protected")

	if item.position.distance_to(player_position) > GameConstants.LOOT_PICKUP_RADIUS:
		return PickupResult.failed("Too far away")

	# Remove without generic signal, use pickup-specific signals
	_items.erase(item_id)
	item_picked_up.emit(item, player_id)
	item_removed.emit(item_id, "picked_up")

	return PickupResult.succeeded(item)


# =============================================================================
# Private Methods
# =============================================================================


## Check for and remove despawned items
func _check_despawns() -> Array[String]:
	var despawned: Array[String] = []

	var ids_to_remove: Array[String] = []
	for item: WorldItem in _items.values():
		if item.is_despawned():
			ids_to_remove.append(item.id)

	for id in ids_to_remove:
		_items.erase(id)
		despawned.append(id)
		item_removed.emit(id, "despawned")

	if not despawned.is_empty():
		items_despawned.emit(despawned)

	return despawned
