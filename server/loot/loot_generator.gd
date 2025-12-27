class_name LootGenerator
extends RefCounted
## Server-side loot generator.
## Converts loot table rolls into actual WorldItem drops.
##
## This class bridges the loot table system with the item system,
## creating actual item instances from loot table drops.


## Reference to the loot registry
var _loot_registry: LootRegistry

## Reference to the item registry
var _item_registry: ItemRegistry

## World item factory for creating items
var _factory: WorldItemFactory


func _init(loot_registry: LootRegistry, item_registry: ItemRegistry) -> void:
	_loot_registry = loot_registry
	_item_registry = item_registry
	if item_registry != null:
		_factory = WorldItemFactory.new(item_registry)


## Generate loot drops from an enemy death.
## Returns an array of WorldItem ready to be added to the world.
##
## Parameters:
## - enemy_definition_id: The enemy's definition ID (to look up loot_table_id)
## - position: World position where loot should drop
## - killer_id: Player ID who killed the enemy (for loot protection)
## - enemy_registry: Registry to look up enemy definitions
func generate_enemy_loot(
	enemy_definition_id: String,
	position: Vector2,
	killer_id: String,
	enemy_registry: RefCounted
) -> Array:
	if enemy_registry == null:
		push_warning("LootGenerator: Enemy registry is null")
		return []

	var definition: Resource = enemy_registry.get_definition(enemy_definition_id)
	if definition == null:
		push_warning("LootGenerator: Unknown enemy definition: " + enemy_definition_id)
		return []

	var loot_table_id: String = definition.loot_table_id
	if loot_table_id.is_empty():
		return []  # No loot table = no drops

	return generate_loot(loot_table_id, position, killer_id)


## Generate loot drops from a specific loot table.
## Returns an array of WorldItem ready to be added to the world.
##
## Parameters:
## - loot_table_id: ID of the loot table to roll
## - position: World position where loot should drop
## - owner_id: Player ID who "owns" this loot (for loot protection)
func generate_loot(
	loot_table_id: String,
	position: Vector2,
	owner_id: String = ""
) -> Array:
	if _loot_registry == null:
		push_warning("LootGenerator: Loot registry is null")
		return []

	var table := _loot_registry.get_table(loot_table_id)
	if table == null:
		push_warning("LootGenerator: Unknown loot table: " + loot_table_id)
		return []

	var drops: Array = table.roll()
	return _create_world_items(drops, position, owner_id)


## Generate loot directly from a LootTable object.
## Useful for one-off loot generation without registering the table.
func generate_from_table(
	table: LootTable,
	position: Vector2,
	owner_id: String = ""
) -> Array:
	if table == null:
		return []

	var drops: Array = table.roll()
	return _create_world_items(drops, position, owner_id)


## Generate a single item drop (not from a loot table).
## Useful for special drops like boss rewards.
func generate_single_item(
	item_id: String,
	quantity: int,
	position: Vector2,
	owner_id: String = "",
	quality: float = 1.0
) -> WorldItem:
	if _factory == null:
		push_warning("LootGenerator: Factory not initialized")
		return null

	return _factory.create(item_id, quantity, position, owner_id, quality)


## Result of loot generation with metadata
class LootResult:
	var world_items: Array = []  # Array of WorldItem
	var total_value: int = 0  # Estimated value (if items have value)
	var item_count: int = 0  # Total number of items

	func add_item(item: WorldItem) -> void:
		if item != null:
			world_items.append(item)
			if item.item_stack != null:
				item_count += item.item_stack.count


## Generate loot with detailed result metadata.
## Returns a LootResult with all drops and statistics.
func generate_loot_detailed(
	loot_table_id: String,
	position: Vector2,
	owner_id: String = ""
) -> LootResult:
	var result := LootResult.new()

	if _loot_registry == null:
		return result

	var table := _loot_registry.get_table(loot_table_id)
	if table == null:
		return result

	var drops: Array = table.roll()
	result.world_items = _create_world_items(drops, position, owner_id)

	for world_item in result.world_items:
		if world_item.item_stack != null:
			result.item_count += world_item.item_stack.count

	return result


# =============================================================================
# Private Methods
# =============================================================================


## Create WorldItem instances from loot table drops
## Delegates to WorldItemFactory for consistent item creation
func _create_world_items(drops: Array, base_position: Vector2, owner_id: String) -> Array:
	if _factory == null:
		push_warning("LootGenerator: Factory not initialized")
		return []

	return _factory.create_from_drops(drops, base_position, owner_id)
