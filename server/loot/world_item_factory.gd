class_name WorldItemFactory
extends RefCounted
## Factory for creating WorldItem instances.
## Centralizes world item creation logic to eliminate duplication.


## Reference to the item registry
var _item_registry: ItemRegistry


func _init(item_registry: ItemRegistry = null) -> void:
	_item_registry = item_registry


## Set the item registry (for late initialization)
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry


## Create a WorldItem from an item ID
## Returns null if the item cannot be created
func create(
	item_id: String,
	quantity: int,
	position: Vector2,
	owner_id: String = "",
	quality: float = 1.0
) -> WorldItem:
	if _item_registry == null:
		push_warning("WorldItemFactory: Item registry is null")
		return null

	var item_def := _item_registry.get_item(item_id)
	if item_def == null:
		push_warning("WorldItemFactory: Unknown item: " + item_id)
		return null

	var item_stack := ItemStack.create_from_definition(item_def, quantity, quality)
	if item_stack == null or item_stack.is_empty():
		push_warning("WorldItemFactory: Failed to create item stack for: " + item_id)
		return null

	return WorldItem.new(
		WorldItem.generate_id(),
		item_stack,
		position,
		owner_id
	)


## Create a WorldItem from an existing ItemStack
## The item stack is used directly (not copied)
func create_from_stack(
	item_stack: ItemStack,
	position: Vector2,
	owner_id: String = ""
) -> WorldItem:
	if item_stack == null or item_stack.is_empty():
		push_warning("WorldItemFactory: Cannot create from empty stack")
		return null

	return WorldItem.new(
		WorldItem.generate_id(),
		item_stack,
		position,
		owner_id
	)


## Create multiple WorldItems from loot drop data
## Returns array of WorldItem (may contain nulls if some items fail to create)
func create_from_drops(
	drops: Array,
	base_position: Vector2,
	owner_id: String = ""
) -> Array:
	var world_items: Array = []
	var positions := _calculate_drop_positions(drops.size(), base_position)

	for i in range(drops.size()):
		var drop: Dictionary = drops[i]
		var item_id: String = drop.get("item_id", "")
		var quantity: int = drop.get("quantity", 1)
		var quality: float = drop.get("quality", 1.0)

		if item_id.is_empty():
			continue

		var pos: Vector2 = positions[i] if i < positions.size() else base_position
		var world_item := create(item_id, quantity, pos, owner_id, quality)

		if world_item != null:
			world_items.append(world_item)

	return world_items


## Calculate spread positions for multiple drops
func _calculate_drop_positions(count: int, center: Vector2) -> Array:
	var positions: Array = []

	if count <= 0:
		return positions

	if count == 1:
		positions.append(center)
		return positions

	# Spread items in a circle around the center
	var angle_step := TAU / float(count)

	for i in range(count):
		var angle := angle_step * float(i)
		var offset := Vector2(
			cos(angle) * GameConstants.LOOT_DROP_SPREAD_RADIUS,
			sin(angle) * GameConstants.LOOT_DROP_SPREAD_RADIUS
		)
		# Add small random variance
		offset += Vector2(
			randf_range(-GameConstants.LOOT_MIN_DROP_SPACING * 0.5, GameConstants.LOOT_MIN_DROP_SPACING * 0.5),
			randf_range(-GameConstants.LOOT_MIN_DROP_SPACING * 0.5, GameConstants.LOOT_MIN_DROP_SPACING * 0.5)
		)
		positions.append(center + offset)

	return positions
