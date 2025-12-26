class_name Inventory
extends RefCounted
## Weight-based inventory system.
## Stores ItemStacks with a maximum weight capacity.
## Automatically merges stackable items.


## Signal emitted when inventory contents change
signal inventory_changed

## Signal emitted when an item is added
signal item_added(stack: ItemStack)

## Signal emitted when an item is removed
signal item_removed(stack: ItemStack)


## Maximum weight capacity
var max_weight: float = 100.0

## All item stacks in the inventory
var _stacks: Array[ItemStack] = []

## Reference to item registry for deserialization
var _item_registry: ItemRegistry


func _init(p_max_weight: float = 100.0, item_registry: ItemRegistry = null) -> void:
	max_weight = p_max_weight
	_item_registry = item_registry


## Get current total weight
func get_current_weight() -> float:
	var total := 0.0
	for stack in _stacks:
		total += stack.get_weight()
	return total


## Get remaining weight capacity
func get_remaining_capacity() -> float:
	return maxf(0.0, max_weight - get_current_weight())


## Check if inventory can hold additional weight
func can_hold_weight(weight: float) -> bool:
	return get_remaining_capacity() >= weight


## Check if inventory can hold an item stack
func can_add_stack(stack: ItemStack) -> bool:
	if stack == null or stack.is_empty():
		return false
	return can_hold_weight(stack.get_weight())


## Add an item stack to inventory
## Returns the leftover stack that couldn't fit (or null if all fit)
func add_stack(stack: ItemStack) -> ItemStack:
	if stack == null or stack.is_empty():
		return null

	# Check weight capacity
	var stack_weight := stack.get_weight()
	if not can_hold_weight(stack_weight):
		# Calculate how many items we can fit by weight
		var remaining_capacity := get_remaining_capacity()
		if remaining_capacity <= 0:
			return stack  # Can't fit anything

		var weight_per_item: float = stack.item.definition.weight
		if weight_per_item <= 0:
			weight_per_item = 0.001  # Avoid division by zero

		var items_that_fit := int(remaining_capacity / weight_per_item)
		if items_that_fit <= 0:
			return stack  # Can't fit even one item

		# Split the stack
		var leftover := stack.split(stack.count - items_that_fit)
		if leftover != null:
			# Add what fits, return leftover
			_add_stack_internal(stack)
			return leftover
		else:
			return stack  # Couldn't split

	# Try to merge with existing stacks first
	if stack.item.definition.is_stackable():
		for existing in _stacks:
			if existing.can_merge_with(stack):
				var leftover := existing.merge_from(stack)
				if leftover == 0:
					inventory_changed.emit()
					return null  # All merged
				# Continue trying to merge remaining

	# If there's still items left, add as new stack
	if not stack.is_empty():
		_add_stack_internal(stack)

	return null


## Internal add without weight check (used after validation)
func _add_stack_internal(stack: ItemStack) -> void:
	_stacks.append(stack)
	item_added.emit(stack)
	inventory_changed.emit()


## Add items by definition (convenience method)
## Returns how many items couldn't be added
func add_items(item_def: ItemDefinition, count: int, quality: float = 1.0) -> int:
	if item_def == null or count <= 0:
		return count

	var stack := ItemStack.create_from_definition(item_def, count, quality)
	var leftover := add_stack(stack)
	return leftover.count if leftover != null else 0


## Remove a specific stack from inventory
func remove_stack(stack: ItemStack) -> bool:
	var idx := _stacks.find(stack)
	if idx < 0:
		return false

	_stacks.remove_at(idx)
	item_removed.emit(stack)
	inventory_changed.emit()
	return true


## Remove items by definition ID
## Returns how many were actually removed
func remove_items_by_id(item_id: String, count: int) -> int:
	if count <= 0:
		return 0

	var removed := 0
	var stacks_to_remove: Array[ItemStack] = []

	for stack in _stacks:
		if stack.item == null or stack.item.definition == null:
			continue
		if stack.item.definition.id != item_id:
			continue

		var to_take := mini(count - removed, stack.count)
		stack.count -= to_take
		removed += to_take

		if stack.is_empty():
			stacks_to_remove.append(stack)

		if removed >= count:
			break

	# Remove empty stacks
	for stack in stacks_to_remove:
		_stacks.erase(stack)
		item_removed.emit(stack)

	if removed > 0:
		inventory_changed.emit()

	return removed


## Get total count of a specific item by ID
func get_item_count(item_id: String) -> int:
	var total := 0
	for stack in _stacks:
		if stack.item != null and stack.item.definition != null:
			if stack.item.definition.id == item_id:
				total += stack.count
	return total


## Check if inventory has at least a certain amount of an item
func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count


## Get all stacks (read-only copy)
func get_all_stacks() -> Array[ItemStack]:
	return _stacks.duplicate()


## Get stack at index
func get_stack_at(index: int) -> ItemStack:
	if index < 0 or index >= _stacks.size():
		return null
	return _stacks[index]


## Get number of stacks
func get_stack_count() -> int:
	return _stacks.size()


## Find first stack containing an item by ID
func find_stack_by_id(item_id: String) -> ItemStack:
	for stack in _stacks:
		if stack.item != null and stack.item.definition != null:
			if stack.item.definition.id == item_id:
				return stack
	return null


## Find all stacks containing an item by ID
func find_all_stacks_by_id(item_id: String) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack in _stacks:
		if stack.item != null and stack.item.definition != null:
			if stack.item.definition.id == item_id:
				result.append(stack)
	return result


## Find stacks by item type
func find_stacks_by_type(type: ItemEnums.ItemType) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack in _stacks:
		if stack.item != null and stack.item.definition != null:
			if stack.item.definition.type == type:
				result.append(stack)
	return result


## Sort inventory (groups same items, sorts by name)
func sort() -> void:
	# First, merge all stackable items
	_merge_all_stackables()

	# Then sort by type, then name
	_stacks.sort_custom(func(a: ItemStack, b: ItemStack) -> bool:
		if a.item == null or a.item.definition == null:
			return false
		if b.item == null or b.item.definition == null:
			return true

		# Sort by type first
		if a.item.definition.type != b.item.definition.type:
			return a.item.definition.type < b.item.definition.type

		# Then by name
		return a.item.definition.name < b.item.definition.name
	)

	inventory_changed.emit()


## Merge all stackable items together
func _merge_all_stackables() -> void:
	var merged := true
	while merged:
		merged = false
		for i in range(_stacks.size()):
			for j in range(i + 1, _stacks.size()):
				if _stacks[i].can_merge_with(_stacks[j]):
					_stacks[i].merge_from(_stacks[j])
					if _stacks[j].is_empty():
						_stacks.remove_at(j)
						merged = true
						break
			if merged:
				break


## Transfer a stack to another inventory
## Returns true if successful
func transfer_to(stack: ItemStack, target: Inventory) -> bool:
	if stack == null or target == null:
		return false

	var idx := _stacks.find(stack)
	if idx < 0:
		return false

	if not target.can_add_stack(stack):
		return false

	_stacks.remove_at(idx)
	var leftover := target.add_stack(stack)

	if leftover != null and not leftover.is_empty():
		# Put leftover back
		_stacks.append(leftover)

	item_removed.emit(stack)
	inventory_changed.emit()
	return true


## Split a stack and get a portion
## Returns the split portion (or null if can't split)
func split_stack(stack: ItemStack, amount: int) -> ItemStack:
	var idx := _stacks.find(stack)
	if idx < 0:
		return null

	var split := stack.split(amount)
	if split != null:
		inventory_changed.emit()

	return split


## Clear all items
func clear() -> void:
	_stacks.clear()
	inventory_changed.emit()


## Check if inventory is empty
func is_empty() -> bool:
	return _stacks.is_empty()


## Serialize to dictionary
func to_dict() -> Dictionary:
	var stacks_data: Array = []
	for stack in _stacks:
		stacks_data.append(stack.to_dict())

	return {
		"max_weight": max_weight,
		"stacks": stacks_data,
	}


## Deserialize from dictionary
func from_dict(data: Dictionary) -> void:
	clear()

	max_weight = data.get("max_weight", 100.0)

	if _item_registry == null:
		push_warning("Inventory: No item registry set, cannot deserialize stacks")
		return

	var stacks_data: Array = data.get("stacks", [])
	for stack_data in stacks_data:
		if stack_data is Dictionary:
			var stack := ItemStack.from_dict(stack_data, _item_registry)
			if stack != null and not stack.is_empty():
				_stacks.append(stack)


## Set the item registry
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry


## Get a summary of inventory contents (for debugging)
func get_summary() -> String:
	var lines: Array[String] = []
	lines.append("Inventory: %.1f / %.1f weight" % [get_current_weight(), max_weight])
	for stack in _stacks:
		lines.append("  - %s" % stack.get_display_text())
	return "\n".join(lines)
