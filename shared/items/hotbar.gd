class_name Hotbar
extends RefCounted
## Fixed-slot hotbar for quick item access.
## Contains 8 slots that reference items from inventory.
## Hotbar stores both ItemStack references and inventory slot indices.
## The indices are used to relink references after inventory sync.


## Signal emitted when hotbar selection changes
signal selection_changed(slot: int)

## Signal emitted when a slot's content changes
signal slot_changed(slot: int)


## Number of hotbar slots
const SLOT_COUNT: int = 8

## The hotbar slots (can contain null for empty slots)
var _slots: Array = []

## Inventory slot indices for each hotbar slot (-1 = not linked to inventory)
## Used to reliably relink references after inventory sync
var _inventory_indices: Array[int] = []

## Currently selected slot index
var selected_slot: int = 0

## Reference to the main inventory
var _inventory: Inventory

## Reference to item registry for deserialization
var _item_registry: ItemRegistry


func _init(inventory: Inventory = null, item_registry: ItemRegistry = null) -> void:
	_inventory = inventory
	_item_registry = item_registry
	_slots.resize(SLOT_COUNT)
	_inventory_indices.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		_slots[i] = null
		_inventory_indices[i] = -1


## Set the inventory reference
func set_inventory(inventory: Inventory) -> void:
	_inventory = inventory


## Set the item registry
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry


## Get the item in a slot
func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return _slots[index]


## Set an item in a slot (assigns reference from inventory)
## Optionally specify the inventory slot index for reliable relinking after sync
func set_slot(index: int, stack: ItemStack, inventory_index: int = -1) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return

	_slots[index] = stack
	_inventory_indices[index] = inventory_index

	# If no inventory index provided, try to find it
	if inventory_index < 0 and stack != null and _inventory != null:
		_inventory_indices[index] = _find_inventory_index_for_stack(stack)

	slot_changed.emit(index)


## Clear a slot
func clear_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return

	if _slots[index] != null:
		_slots[index] = null
		_inventory_indices[index] = -1
		slot_changed.emit(index)


## Check if a slot is empty
func is_slot_empty(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return true
	var stack: ItemStack = _slots[index]
	return stack == null or stack.is_empty()


## Get the currently selected item
func get_selected_item() -> ItemStack:
	return get_slot(selected_slot)


## Select a slot by index
func select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	if index == selected_slot:
		return

	selected_slot = index
	selection_changed.emit(selected_slot)


## Select next slot (wraps around)
func select_next() -> void:
	select_slot((selected_slot + 1) % SLOT_COUNT)


## Select previous slot (wraps around)
func select_previous() -> void:
	select_slot((selected_slot - 1 + SLOT_COUNT) % SLOT_COUNT)


## Swap two slots
func swap_slots(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= SLOT_COUNT:
		return
	if index_b < 0 or index_b >= SLOT_COUNT:
		return
	if index_a == index_b:
		return

	var temp_stack: ItemStack = _slots[index_a]
	var temp_index: int = _inventory_indices[index_a]

	_slots[index_a] = _slots[index_b]
	_inventory_indices[index_a] = _inventory_indices[index_b]

	_slots[index_b] = temp_stack
	_inventory_indices[index_b] = temp_index

	slot_changed.emit(index_a)
	slot_changed.emit(index_b)


## Move a stack from inventory to hotbar slot
func assign_from_inventory(inventory_stack: ItemStack, slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if inventory_stack == null:
		return false

	_slots[slot] = inventory_stack
	_inventory_indices[slot] = _find_inventory_index_for_stack(inventory_stack)
	slot_changed.emit(slot)
	return true


## Use one item from the selected slot
## Returns the item used, or null if slot is empty
func use_selected() -> ItemInstance:
	return use_slot(selected_slot)


## Use one item from a specific slot
## Returns the item used, or null if slot is empty
func use_slot(index: int) -> ItemInstance:
	if index < 0 or index >= SLOT_COUNT:
		return null

	var stack: ItemStack = _slots[index]
	if stack == null or stack.is_empty():
		return null

	var item := stack.take_one()

	# If stack is now empty, clear the slot reference
	if stack.is_empty():
		_slots[index] = null
		_inventory_indices[index] = -1
		slot_changed.emit(index)

	return item


## Find first slot containing a specific item ID
func find_slot_by_id(item_id: String) -> int:
	for i in range(SLOT_COUNT):
		var stack: ItemStack = _slots[i]
		if stack != null and stack.item != null and stack.item.definition != null:
			if stack.item.definition.id == item_id:
				return i
	return -1


## Find first empty slot
func find_empty_slot() -> int:
	for i in range(SLOT_COUNT):
		if is_slot_empty(i):
			return i
	return -1


## Check how many slots are occupied
func get_occupied_count() -> int:
	var count := 0
	for i in range(SLOT_COUNT):
		if not is_slot_empty(i):
			count += 1
	return count


## Clear all slots
func clear() -> void:
	for i in range(SLOT_COUNT):
		if _slots[i] != null:
			_slots[i] = null
			_inventory_indices[i] = -1
			slot_changed.emit(i)


## Validate hotbar slots against inventory
## Removes any slots that reference items no longer in inventory
## Also refreshes references if inventory index is valid
func validate(inventory: Inventory) -> void:
	if inventory == null:
		return

	var inventory_stacks := inventory.get_all_stacks()
	for i in range(SLOT_COUNT):
		var stack: ItemStack = _slots[i]
		if stack != null:
			# First try to refresh reference using stored inventory index
			var inv_idx := _inventory_indices[i]
			if inv_idx >= 0 and inv_idx < inventory.get_stack_count():
				var inv_stack := inventory.get_stack_at(inv_idx)
				if inv_stack != null and not inv_stack.is_empty():
					# Verify it's the same item type
					if _stacks_match_type(stack, inv_stack):
						_slots[i] = inv_stack
						continue

			# Fallback: Check if current reference is still valid
			if stack not in inventory_stacks or stack.is_empty():
				_slots[i] = null
				_inventory_indices[i] = -1
				slot_changed.emit(i)


## Auto-assign newly added item to first empty hotbar slot
## Returns the slot it was assigned to, or -1 if no empty slots
func auto_assign(stack: ItemStack) -> int:
	if stack == null:
		return -1

	var empty_slot := find_empty_slot()
	if empty_slot >= 0:
		_slots[empty_slot] = stack
		_inventory_indices[empty_slot] = _find_inventory_index_for_stack(stack)
		slot_changed.emit(empty_slot)

	return empty_slot


## Serialize to dictionary
func to_dict() -> Dictionary:
	var slots_data: Array = []
	for i in range(SLOT_COUNT):
		var stack: ItemStack = _slots[i]
		if stack != null and not stack.is_empty():
			slots_data.append({
				"slot": i,
				"stack": stack.to_dict(),
				"inv_idx": _inventory_indices[i],
			})
		# Don't include empty slots

	return {
		"selected": selected_slot,
		"slots": slots_data,
	}


## Deserialize from dictionary
## Note: This creates new stacks - after loading, you should call
## link_to_inventory() to re-link these to the actual inventory stacks
func from_dict(data: Dictionary) -> void:
	clear()

	selected_slot = clampi(data.get("selected", 0), 0, SLOT_COUNT - 1)

	if _item_registry == null:
		push_warning("Hotbar: No item registry set, cannot deserialize")
		return

	var slots_data: Array = data.get("slots", [])
	for slot_data in slots_data:
		if slot_data is Dictionary:
			var slot_idx: int = slot_data.get("slot", -1)
			if slot_idx >= 0 and slot_idx < SLOT_COUNT:
				var stack_data: Dictionary = slot_data.get("stack", {})
				var stack := ItemStack.from_dict(stack_data, _item_registry)
				if stack != null and not stack.is_empty():
					_slots[slot_idx] = stack
					_inventory_indices[slot_idx] = int(slot_data.get("inv_idx", -1))


## Re-link hotbar slots to matching inventory stacks after loading
## This ensures hotbar references the same objects as inventory
## Uses stored inventory indices for reliable matching, falls back to item ID match
func link_to_inventory(inventory: Inventory) -> void:
	if inventory == null:
		return

	_inventory = inventory

	for i in range(SLOT_COUNT):
		var hotbar_stack: ItemStack = _slots[i]
		if hotbar_stack == null:
			continue

		# First try using stored inventory index
		var inv_idx := _inventory_indices[i]
		if inv_idx >= 0 and inv_idx < inventory.get_stack_count():
			var inv_stack := inventory.get_stack_at(inv_idx)
			if inv_stack != null and not inv_stack.is_empty():
				# Verify it's the same item type to prevent mismatches after inventory changes
				if _stacks_match_type(hotbar_stack, inv_stack):
					_slots[i] = inv_stack
					continue

		# Fallback: Find matching stack by item ID
		var item_id := ""
		if hotbar_stack.item != null and hotbar_stack.item.definition != null:
			item_id = hotbar_stack.item.definition.id

		if item_id.is_empty():
			_slots[i] = null
			_inventory_indices[i] = -1
			continue

		# Find matching stack in inventory and update the index
		var found := false
		var inv_stacks := inventory.get_all_stacks()
		for j in range(inv_stacks.size()):
			var inv_stack: ItemStack = inv_stacks[j]
			if inv_stack.item != null and inv_stack.item.definition != null:
				if inv_stack.item.definition.id == item_id:
					_slots[i] = inv_stack
					_inventory_indices[i] = j
					found = true
					break

		if not found:
			_slots[i] = null
			_inventory_indices[i] = -1


## Check if two stacks have matching item types
func _stacks_match_type(stack_a: ItemStack, stack_b: ItemStack) -> bool:
	if stack_a == null or stack_b == null:
		return false
	if stack_a.item == null or stack_b.item == null:
		return false
	if stack_a.item.definition == null or stack_b.item.definition == null:
		return false
	return stack_a.item.definition.id == stack_b.item.definition.id


## Find the inventory index for a given stack
func _find_inventory_index_for_stack(stack: ItemStack) -> int:
	if _inventory == null or stack == null:
		return -1

	var stacks := _inventory.get_all_stacks()
	for i in range(stacks.size()):
		if stacks[i] == stack:
			return i
	return -1


## Get the inventory index for a hotbar slot
func get_inventory_index(hotbar_slot: int) -> int:
	if hotbar_slot < 0 or hotbar_slot >= SLOT_COUNT:
		return -1
	return _inventory_indices[hotbar_slot]


## Refresh all hotbar references from inventory using stored indices
## Call this after inventory sync to update stale references
func refresh_from_inventory(inventory: Inventory) -> void:
	if inventory == null:
		return

	_inventory = inventory

	for i in range(SLOT_COUNT):
		if _slots[i] == null:
			continue

		var inv_idx := _inventory_indices[i]
		if inv_idx >= 0 and inv_idx < inventory.get_stack_count():
			var inv_stack := inventory.get_stack_at(inv_idx)
			if inv_stack != null and not inv_stack.is_empty():
				if _stacks_match_type(_slots[i], inv_stack):
					_slots[i] = inv_stack
					continue

		# Index invalid or type mismatch - clear the slot
		_slots[i] = null
		_inventory_indices[i] = -1
		slot_changed.emit(i)
