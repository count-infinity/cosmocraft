class_name LootRegistry
extends RefCounted
## Central registry for all loot tables.
## Used to look up loot tables by ID for drop generation.


## All registered loot tables by ID
var _tables: Dictionary = {}


## Register a loot table
func register(table: LootTable) -> void:
	if table == null:
		push_warning("LootRegistry: Cannot register null loot table")
		return
	if table.id.is_empty():
		push_warning("LootRegistry: Cannot register loot table with empty ID")
		return
	_tables[table.id] = table


## Unregister a loot table by ID
func unregister(id: String) -> bool:
	return _tables.erase(id)


## Get a loot table by ID
func get_table(id: String) -> LootTable:
	return _tables.get(id, null)


## Check if a loot table exists
func has_table(id: String) -> bool:
	return id in _tables


## Get all registered table IDs
func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _tables.keys():
		ids.append(id)
	return ids


## Get count of registered tables
func get_table_count() -> int:
	return _tables.size()


## Clear all registrations
func clear() -> void:
	_tables.clear()


## Roll a loot table by ID and return drops
## Returns empty array if table not found
func roll_table(id: String) -> Array:
	var table := get_table(id)
	if table == null:
		push_warning("LootRegistry: Unknown loot table ID: " + id)
		return []
	return table.roll()


## Create and register a simple loot table with individual entries
func create_individual_table(id: String, items: Array) -> LootTable:
	var table := LootTable.new(id, LootTable.SelectionMode.INDIVIDUAL)

	for item_data in items:
		if item_data is Dictionary:
			var entry := LootEntry.new(
				item_data.get("item_id", ""),
				int(item_data.get("min_quantity", 1)),
				int(item_data.get("max_quantity", 1)),
				float(item_data.get("drop_chance", 100.0)),
				float(item_data.get("weight", 1.0))
			)
			if item_data.has("min_quality"):
				entry.set_quality_range(
					float(item_data.get("min_quality", 1.0)),
					float(item_data.get("max_quality", 1.0))
				)
			table.add_entry(entry)

	register(table)
	return table


## Create and register a weighted loot table
func create_weighted_table(
	id: String,
	items: Array,
	num_rolls: int = 1,
	allow_duplicates: bool = true
) -> LootTable:
	var table := LootTable.new(id, LootTable.SelectionMode.WEIGHTED)
	table.num_rolls = num_rolls
	table.allow_duplicates = allow_duplicates

	for item_data in items:
		if item_data is Dictionary:
			var entry := LootEntry.new(
				item_data.get("item_id", ""),
				int(item_data.get("min_quantity", 1)),
				int(item_data.get("max_quantity", 1)),
				100.0,  # Drop chance not used in weighted mode
				float(item_data.get("weight", 1.0))
			)
			if item_data.has("min_quality"):
				entry.set_quality_range(
					float(item_data.get("min_quality", 1.0)),
					float(item_data.get("max_quality", 1.0))
				)
			table.add_entry(entry)

	register(table)
	return table


## Register default enemy loot tables
## Call this to set up standard loot tables for enemies
func register_default_tables() -> void:
	# Rabbit loot - common materials
	create_individual_table("rabbit_loot", [
		{"item_id": "raw_rabbit", "min_quantity": 1, "max_quantity": 1, "drop_chance": 100.0},
		{"item_id": "rabbit_hide", "min_quantity": 1, "max_quantity": 1, "drop_chance": 50.0},
		{"item_id": "rabbit_foot", "min_quantity": 1, "max_quantity": 1, "drop_chance": 5.0},
	])

	# Wolf loot - uncommon materials
	create_individual_table("wolf_loot", [
		{"item_id": "raw_meat", "min_quantity": 1, "max_quantity": 2, "drop_chance": 100.0},
		{"item_id": "wolf_pelt", "min_quantity": 1, "max_quantity": 1, "drop_chance": 75.0},
		{"item_id": "wolf_fang", "min_quantity": 1, "max_quantity": 2, "drop_chance": 30.0},
	])

	# Bear loot - rare materials
	create_individual_table("bear_loot", [
		{"item_id": "raw_meat", "min_quantity": 2, "max_quantity": 4, "drop_chance": 100.0},
		{"item_id": "bear_pelt", "min_quantity": 1, "max_quantity": 1, "drop_chance": 80.0},
		{"item_id": "bear_claw", "min_quantity": 1, "max_quantity": 2, "drop_chance": 40.0},
	])

	# Treasure chest loot - weighted selection
	create_weighted_table("common_chest", [
		{"item_id": "gold_coins", "min_quantity": 5, "max_quantity": 20, "weight": 50.0},
		{"item_id": "iron_ore", "min_quantity": 1, "max_quantity": 3, "weight": 30.0},
		{"item_id": "copper_ore", "min_quantity": 2, "max_quantity": 5, "weight": 40.0},
		{"item_id": "health_potion", "min_quantity": 1, "max_quantity": 1, "weight": 20.0},
	], 2, true)  # 2 rolls, allow duplicates


## Serialize all tables to dictionary (for save/load)
func to_dict() -> Dictionary:
	var tables_data: Dictionary = {}
	for id in _tables:
		tables_data[id] = _tables[id].to_dict()
	return {"tables": tables_data}


## Load tables from dictionary
func from_dict(data: Dictionary) -> void:
	var tables_data: Dictionary = data.get("tables", {})
	for id in tables_data:
		var table := LootTable.from_dict(tables_data[id])
		if table != null:
			register(table)
