class_name EquipmentSlots
extends RefCounted
## Manages equipped items for a player.
## Handles equipping, unequipping, and stat aggregation from gear.


## Signal emitted when equipment changes
signal equipment_changed(slot: ItemEnums.EquipSlot)


## Equipped items by slot
## Note: ACCESSORY slot can hold 2 items, stored as accessory_1 and accessory_2
var _slots: Dictionary = {}

## Reference to item registry for deserialization
var _item_registry: ItemRegistry


func _init(item_registry: ItemRegistry = null) -> void:
	_item_registry = item_registry
	_clear_slots()


## Clear all slots to empty
func _clear_slots() -> void:
	_slots = {
		ItemEnums.EquipSlot.HEAD: null,
		ItemEnums.EquipSlot.CHEST: null,
		ItemEnums.EquipSlot.LEGS: null,
		ItemEnums.EquipSlot.BOOTS: null,
		ItemEnums.EquipSlot.MAIN_HAND: null,
		ItemEnums.EquipSlot.OFF_HAND: null,
		"accessory_1": null,
		"accessory_2": null,
	}


## Check if an item can be equipped to a slot
func can_equip(item: ItemInstance, slot: ItemEnums.EquipSlot) -> bool:
	if item == null or item.definition == null:
		return false

	# Item must be equippable to this slot
	if item.definition.equip_slot != slot:
		return false

	# Broken items cannot be equipped
	if item.is_broken():
		return false

	return true


## Equip an item to its designated slot
## Returns the previously equipped item (or null)
func equip(item: ItemInstance) -> ItemInstance:
	if item == null or item.definition == null:
		return null

	var slot := item.definition.equip_slot
	if slot == ItemEnums.EquipSlot.NONE:
		return null

	if item.is_broken():
		return null

	# Handle accessory slots specially
	if slot == ItemEnums.EquipSlot.ACCESSORY:
		return _equip_accessory(item)

	var previous: ItemInstance = _slots.get(slot)
	_slots[slot] = item
	equipment_changed.emit(slot)
	return previous


## Equip an accessory (finds first empty slot or replaces first)
func _equip_accessory(item: ItemInstance) -> ItemInstance:
	# Try first slot
	if _slots["accessory_1"] == null:
		_slots["accessory_1"] = item
		equipment_changed.emit(ItemEnums.EquipSlot.ACCESSORY)
		return null

	# Try second slot
	if _slots["accessory_2"] == null:
		_slots["accessory_2"] = item
		equipment_changed.emit(ItemEnums.EquipSlot.ACCESSORY)
		return null

	# Both full, replace first
	var previous: ItemInstance = _slots["accessory_1"]
	_slots["accessory_1"] = item
	equipment_changed.emit(ItemEnums.EquipSlot.ACCESSORY)
	return previous


## Equip an accessory to a specific slot (1 or 2)
func equip_accessory_to_slot(item: ItemInstance, slot_index: int) -> ItemInstance:
	if item == null or item.definition == null:
		return null
	if item.definition.equip_slot != ItemEnums.EquipSlot.ACCESSORY:
		return null
	if item.is_broken():
		return null
	if slot_index < 1 or slot_index > 2:
		return null

	var key := "accessory_%d" % slot_index
	var previous: ItemInstance = _slots[key]
	_slots[key] = item
	equipment_changed.emit(ItemEnums.EquipSlot.ACCESSORY)
	return previous


## Unequip an item from a slot
## Returns the unequipped item (or null if slot was empty)
func unequip(slot: ItemEnums.EquipSlot) -> ItemInstance:
	if slot == ItemEnums.EquipSlot.NONE:
		return null

	# Handle accessory specially (unequips first occupied)
	if slot == ItemEnums.EquipSlot.ACCESSORY:
		return _unequip_accessory(1)

	var item: ItemInstance = _slots.get(slot)
	if item != null:
		_slots[slot] = null
		equipment_changed.emit(slot)
	return item


## Unequip a specific accessory slot
func unequip_accessory(slot_index: int) -> ItemInstance:
	return _unequip_accessory(slot_index)


func _unequip_accessory(slot_index: int) -> ItemInstance:
	if slot_index < 1 or slot_index > 2:
		return null

	var key := "accessory_%d" % slot_index
	var item: ItemInstance = _slots[key]
	if item != null:
		_slots[key] = null
		equipment_changed.emit(ItemEnums.EquipSlot.ACCESSORY)
	return item


## Get the item in a slot
func get_equipped(slot: ItemEnums.EquipSlot) -> ItemInstance:
	if slot == ItemEnums.EquipSlot.ACCESSORY:
		# Return first accessory
		return _slots.get("accessory_1")
	return _slots.get(slot)


## Get accessory by slot index (1 or 2)
func get_accessory(slot_index: int) -> ItemInstance:
	if slot_index < 1 or slot_index > 2:
		return null
	return _slots.get("accessory_%d" % slot_index)


## Check if a slot is occupied
func is_slot_occupied(slot: ItemEnums.EquipSlot) -> bool:
	if slot == ItemEnums.EquipSlot.ACCESSORY:
		return _slots["accessory_1"] != null or _slots["accessory_2"] != null
	return _slots.get(slot) != null


## Get all equipped items as an array
func get_all_equipped() -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for key in _slots:
		var item: ItemInstance = _slots[key]
		if item != null:
			items.append(item)
	return items


## Get total stats from all equipped items
func get_total_stats() -> Dictionary:
	var stats: Dictionary = {}

	for key in _slots:
		var item: ItemInstance = _slots[key]
		if item == null:
			continue

		var item_stats := item.get_effective_stats()
		for stat_key in item_stats:
			var value: float = item_stats[stat_key]
			stats[stat_key] = stats.get(stat_key, 0.0) + value

	return stats


## Get a specific total stat from all equipment
func get_total_stat(stat: ItemEnums.StatType) -> float:
	var total := 0.0
	for key in _slots:
		var item: ItemInstance = _slots[key]
		if item != null:
			total += item.get_stat(stat)
	return total


## Get total weight of all equipped items
func get_total_weight() -> float:
	var weight := 0.0
	for key in _slots:
		var item: ItemInstance = _slots[key]
		if item != null and item.definition != null:
			weight += item.definition.weight
	return weight


## Get set bonuses (returns dict of set_id -> count)
func get_set_counts() -> Dictionary:
	var counts: Dictionary = {}
	for key in _slots:
		var item: ItemInstance = _slots[key]
		if item != null and item.definition != null:
			var set_id := item.definition.set_id
			if not set_id.is_empty():
				counts[set_id] = counts.get(set_id, 0) + 1
	return counts


## Use durability on all equipped items (e.g., on death or combat)
## Returns array of items that broke
func use_durability_all(amount: int = 1) -> Array[ItemInstance]:
	var broken: Array[ItemInstance] = []
	for key in _slots:
		var item: ItemInstance = _slots[key]
		if item != null and item.use_durability(amount):
			broken.append(item)
	return broken


## Clear all equipment
func clear() -> void:
	_clear_slots()


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {}

	for slot in [ItemEnums.EquipSlot.HEAD, ItemEnums.EquipSlot.CHEST,
				 ItemEnums.EquipSlot.LEGS, ItemEnums.EquipSlot.BOOTS,
				 ItemEnums.EquipSlot.MAIN_HAND, ItemEnums.EquipSlot.OFF_HAND]:
		var item: ItemInstance = _slots.get(slot)
		if item != null:
			data[str(slot)] = item.to_dict()

	# Handle accessories
	var acc1: ItemInstance = _slots.get("accessory_1")
	var acc2: ItemInstance = _slots.get("accessory_2")
	if acc1 != null:
		data["accessory_1"] = acc1.to_dict()
	if acc2 != null:
		data["accessory_2"] = acc2.to_dict()

	return data


## Deserialize from dictionary
func from_dict(data: Dictionary) -> void:
	_clear_slots()

	if _item_registry == null:
		push_warning("EquipmentSlots: No item registry set, cannot deserialize")
		return

	# Load standard slots
	for slot in [ItemEnums.EquipSlot.HEAD, ItemEnums.EquipSlot.CHEST,
				 ItemEnums.EquipSlot.LEGS, ItemEnums.EquipSlot.BOOTS,
				 ItemEnums.EquipSlot.MAIN_HAND, ItemEnums.EquipSlot.OFF_HAND]:
		var key := str(slot)
		if data.has(key):
			var item := ItemInstance.from_dict(data[key], _item_registry)
			_slots[slot] = item

	# Load accessories
	if data.has("accessory_1"):
		_slots["accessory_1"] = ItemInstance.from_dict(data["accessory_1"], _item_registry)
	if data.has("accessory_2"):
		_slots["accessory_2"] = ItemInstance.from_dict(data["accessory_2"], _item_registry)


## Set the item registry (for deserialization)
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry
