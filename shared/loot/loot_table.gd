class_name LootTable
extends RefCounted
## A collection of loot entries that can be rolled for drops.
## Supports both individual roll mode (each entry rolls independently)
## and weighted selection mode (pick N entries based on weight).


## Selection modes for loot tables
enum SelectionMode {
	INDIVIDUAL,  ## Each entry rolls independently based on drop_chance
	WEIGHTED,    ## Pick entries based on weight (weight relative to total)
}


## Unique identifier for this loot table
var id: String = ""

## Display name for debugging/UI
var display_name: String = ""

## How entries are selected for drops
var selection_mode: SelectionMode = SelectionMode.INDIVIDUAL

## Number of rolls for weighted selection mode
var num_rolls: int = 1

## Allow duplicate items when using weighted selection
var allow_duplicates: bool = true

## All entries in this loot table
var entries: Array[LootEntry] = []


func _init(p_id: String = "", p_mode: SelectionMode = SelectionMode.INDIVIDUAL) -> void:
	id = p_id
	selection_mode = p_mode


## Add an entry to the loot table
func add_entry(entry: LootEntry) -> LootTable:
	if entry != null and entry.is_valid():
		entries.append(entry)
	return self


## Add multiple entries
func add_entries(new_entries: Array) -> LootTable:
	for entry in new_entries:
		if entry is LootEntry:
			add_entry(entry)
	return self


## Add a simple item drop (guaranteed, 1 quantity)
func add_item(item_id: String, quantity: int = 1) -> LootTable:
	return add_entry(LootEntry.simple(item_id, quantity))


## Add an item with drop chance
func add_item_chance(item_id: String, chance: float, quantity: int = 1) -> LootTable:
	return add_entry(LootEntry.with_chance(item_id, chance, quantity))


## Add an item with quantity range
func add_item_range(item_id: String, min_qty: int, max_qty: int, chance: float = 100.0) -> LootTable:
	return add_entry(LootEntry.with_range(item_id, min_qty, max_qty, chance))


## Add an item with weight (for weighted selection)
func add_weighted_item(item_id: String, weight: float, quantity: int = 1) -> LootTable:
	var entry := LootEntry.new(item_id, quantity, quantity, 100.0, weight)
	return add_entry(entry)


## Roll the loot table and return dropped entries with quantities
## Returns: Array of {item_id: String, quantity: int, quality: float}
func roll() -> Array:
	match selection_mode:
		SelectionMode.INDIVIDUAL:
			return _roll_individual()
		SelectionMode.WEIGHTED:
			return _roll_weighted()
		_:
			return []


## Get total weight of all entries
func get_total_weight() -> float:
	var total: float = 0.0
	for entry in entries:
		total += entry.weight
	return total


## Get entry count
func get_entry_count() -> int:
	return entries.size()


## Check if table is empty
func is_empty() -> bool:
	return entries.is_empty()


## Check if table is valid (has id and entries)
func is_valid() -> bool:
	return not id.is_empty() and not entries.is_empty()


## Clear all entries
func clear() -> void:
	entries.clear()


## Get entry by index
func get_entry(index: int) -> LootEntry:
	if index < 0 or index >= entries.size():
		return null
	return entries[index]


## Remove entry by index
func remove_entry(index: int) -> bool:
	if index < 0 or index >= entries.size():
		return false
	entries.remove_at(index)
	return true


## Serialize to dictionary
func to_dict() -> Dictionary:
	var entry_dicts: Array = []
	for entry in entries:
		entry_dicts.append(entry.to_dict())

	return {
		"id": id,
		"display_name": display_name,
		"selection_mode": selection_mode,
		"num_rolls": num_rolls,
		"allow_duplicates": allow_duplicates,
		"entries": entry_dicts,
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> LootTable:
	var table := LootTable.new()
	table.id = data.get("id", "")
	table.display_name = data.get("display_name", "")
	table.selection_mode = int(data.get("selection_mode", SelectionMode.INDIVIDUAL))
	table.num_rolls = int(data.get("num_rolls", 1))
	table.allow_duplicates = data.get("allow_duplicates", true)

	var entry_dicts: Array = data.get("entries", [])
	for entry_data in entry_dicts:
		if entry_data is Dictionary:
			var entry := LootEntry.from_dict(entry_data)
			table.entries.append(entry)

	return table


# =============================================================================
# Private Methods
# =============================================================================


## Roll each entry independently based on drop_chance
func _roll_individual() -> Array:
	var drops: Array = []

	for entry in entries:
		if entry.roll_drop():
			drops.append({
				"item_id": entry.item_id,
				"quantity": entry.roll_quantity(),
				"quality": entry.roll_quality(),
			})

	return drops


## Roll using weighted random selection
func _roll_weighted() -> Array:
	var drops: Array = []
	var total_weight := get_total_weight()

	if total_weight <= 0.0 or entries.is_empty():
		return drops

	# Track used indices if duplicates not allowed
	var used_indices: Array[int] = []

	for _i in range(num_rolls):
		var selected_entry := _select_weighted_entry(total_weight, used_indices)
		if selected_entry == null:
			break  # No more valid entries to select

		drops.append({
			"item_id": selected_entry.item_id,
			"quantity": selected_entry.roll_quantity(),
			"quality": selected_entry.roll_quality(),
		})

	return drops


## Select a single entry based on weight
func _select_weighted_entry(total_weight: float, used_indices: Array[int]) -> LootEntry:
	# Calculate effective total weight (excluding used entries if no duplicates)
	var effective_weight := total_weight
	if not allow_duplicates:
		for idx in used_indices:
			if idx >= 0 and idx < entries.size():
				effective_weight -= entries[idx].weight

	if effective_weight <= 0.0:
		return null

	var roll := randf() * effective_weight
	var cumulative: float = 0.0

	for i in range(entries.size()):
		# Skip used entries if duplicates not allowed
		if not allow_duplicates and i in used_indices:
			continue

		cumulative += entries[i].weight
		if roll < cumulative:
			if not allow_duplicates:
				used_indices.append(i)
			return entries[i]

	# Fallback to last valid entry
	for i in range(entries.size() - 1, -1, -1):
		if allow_duplicates or i not in used_indices:
			if not allow_duplicates:
				used_indices.append(i)
			return entries[i]

	return null
