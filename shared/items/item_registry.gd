class_name ItemRegistry
extends RefCounted
## Central registry for all item and material definitions.
## Used to look up definitions by ID for deserialization.


## All registered item definitions by ID
var _items: Dictionary = {}

## All registered material definitions by ID
var _materials: Dictionary = {}


## Register an item definition
func register_item(item_def: ItemDefinition) -> void:
	if item_def.id.is_empty():
		push_warning("ItemRegistry: Cannot register item with empty ID")
		return
	_items[item_def.id] = item_def


## Register a material definition
func register_material(material_def: MaterialDefinition) -> void:
	if material_def.id.is_empty():
		push_warning("ItemRegistry: Cannot register material with empty ID")
		return
	_materials[material_def.id] = material_def


## Get an item definition by ID
func get_item(id: String) -> ItemDefinition:
	return _items.get(id, null)


## Get a material definition by ID
func get_material(id: String) -> MaterialDefinition:
	return _materials.get(id, null)


## Check if an item exists
func has_item(id: String) -> bool:
	return id in _items


## Check if a material exists
func has_material(id: String) -> bool:
	return id in _materials


## Get all item IDs
func get_all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _items.keys():
		ids.append(id)
	return ids


## Get all material IDs
func get_all_material_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _materials.keys():
		ids.append(id)
	return ids


## Get items by type
func get_items_by_type(type: ItemEnums.ItemType) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item_def: ItemDefinition in _items.values():
		if item_def.type == type:
			result.append(item_def)
	return result


## Get items by equip slot
func get_items_by_slot(slot: ItemEnums.EquipSlot) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item_def: ItemDefinition in _items.values():
		if item_def.equip_slot == slot:
			result.append(item_def)
	return result


## Get materials by tier
func get_materials_by_tier(tier: int) -> Array[MaterialDefinition]:
	var result: Array[MaterialDefinition] = []
	for mat_def: MaterialDefinition in _materials.values():
		if mat_def.tier == tier:
			result.append(mat_def)
	return result


## Get materials by category
func get_materials_by_category(category: String) -> Array[MaterialDefinition]:
	var result: Array[MaterialDefinition] = []
	for mat_def: MaterialDefinition in _materials.values():
		if mat_def.category == category:
			result.append(mat_def)
	return result


## Get count of registered items
func get_item_count() -> int:
	return _items.size()


## Get count of registered materials
func get_material_count() -> int:
	return _materials.size()


## Clear all registrations
func clear() -> void:
	_items.clear()
	_materials.clear()


## Unregister an item
func unregister_item(id: String) -> bool:
	return _items.erase(id)


## Unregister a material
func unregister_material(id: String) -> bool:
	return _materials.erase(id)


## Create an ItemInstance from an item ID
func create_item_instance(id: String, quality: float = 1.0) -> ItemInstance:
	var item_def := get_item(id)
	if item_def == null:
		push_warning("ItemRegistry: Unknown item ID: " + id)
		return null
	return ItemInstance.create(item_def, quality)


## Create an ItemStack from an item ID
func create_item_stack(id: String, count: int = 1, quality: float = 1.0) -> ItemStack:
	var item_def := get_item(id)
	if item_def == null:
		push_warning("ItemRegistry: Unknown item ID: " + id)
		return null
	return ItemStack.create_from_definition(item_def, count, quality)
