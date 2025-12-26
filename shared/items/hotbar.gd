class_name Hotbar
extends RefCounted
## Fixed-slot hotbar for quick item access.
## Contains 8 slots that reference items from inventory.
## Hotbar stores references to ItemStacks, not copies.


## Signal emitted when hotbar selection changes
signal selection_changed(slot: int)

## Signal emitted when a slot's content changes
signal slot_changed(slot: int)


## Number of hotbar slots
const SLOT_COUNT: int = 8

## The hotbar slots (can contain null for empty slots)
var _slots: Array = []

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
	for i in range(SLOT_COUNT):
		_slots[i] = null


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
func set_slot(index: int, stack: ItemStack) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return

	_slots[index] = stack
	slot_changed.emit(index)


## Clear a slot
func clear_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return

	if _slots[index] != null:
		_slots[index] = null
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

	var temp: ItemStack = _slots[index_a]
	_slots[index_a] = _slots[index_b]
	_slots[index_b] = temp

	slot_changed.emit(index_a)
	slot_changed.emit(index_b)


## Move a stack from inventory to hotbar slot
func assign_from_inventory(inventory_stack: ItemStack, slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if inventory_stack == null:
		return false

	_slots[slot] = inventory_stack
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
			slot_changed.emit(i)


## Validate hotbar slots against inventory
## Removes any slots that reference items no longer in inventory
func validate(inventory: Inventory) -> void:
	if inventory == null:
		return

	var inventory_stacks := inventory.get_all_stacks()
	for i in range(SLOT_COUNT):
		var stack: ItemStack = _slots[i]
		if stack != null:
			# Check if this stack is still in inventory
			if stack not in inventory_stacks or stack.is_empty():
				_slots[i] = null
				slot_changed.emit(i)


## Auto-assign newly added item to first empty hotbar slot
## Returns the slot it was assigned to, or -1 if no empty slots
func auto_assign(stack: ItemStack) -> int:
	if stack == null:
		return -1

	var empty_slot := find_empty_slot()
	if empty_slot >= 0:
		_slots[empty_slot] = stack
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
			})
		# Don't include empty slots

	return {
		"selected": selected_slot,
		"slots": slots_data,
	}


## Deserialize from dictionary
## Note: This creates new stacks - after loading, you may want to
## re-link these to the actual inventory stacks using link_to_inventory()
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


## Re-link hotbar slots to matching inventory stacks after loading
## This ensures hotbar references the same objects as inventory
func link_to_inventory(inventory: Inventory) -> void:
	if inventory == null:
		return

	var inv_stacks := inventory.get_all_stacks()

	for i in range(SLOT_COUNT):
		var hotbar_stack: ItemStack = _slots[i]
		if hotbar_stack == null:
			continue

		# Find matching stack in inventory by item ID
		var item_id := ""
		if hotbar_stack.item != null and hotbar_stack.item.definition != null:
			item_id = hotbar_stack.item.definition.id

		if item_id.is_empty():
			_slots[i] = null
			continue

		# Find first matching stack in inventory
		var found := false
		for inv_stack in inv_stacks:
			if inv_stack.item != null and inv_stack.item.definition != null:
				if inv_stack.item.definition.id == item_id:
					_slots[i] = inv_stack
					found = true
					break

		if not found:
			_slots[i] = null
