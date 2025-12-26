class_name EquipmentSet
extends Resource
## Definition of an equipment set with tiered bonuses.
## Sets provide bonuses when wearing multiple pieces from the same set.


## Unique identifier for this set
@export var id: String = ""

## Display name
@export var name: String = ""

## Description of the set
@export_multiline var description: String = ""

## Item IDs that belong to this set
@export var item_ids: Array[String] = []

## Set bonuses at different piece thresholds
## Key = number of pieces required, Value = bonus dictionary
## Bonus format: {stat_type: bonus_value} or {"effect": effect_id, "magnitude": value}
@export var bonuses: Dictionary = {}


## Create a new equipment set with id and name
static func create(p_id: String, p_name: String) -> EquipmentSet:
	var eq_set := EquipmentSet.new()
	eq_set.id = p_id
	eq_set.name = p_name
	return eq_set


## Add an item to the set
func add_item(item_id: String) -> void:
	if item_id not in item_ids:
		item_ids.append(item_id)


## Check if an item belongs to this set
func contains_item(item_id: String) -> bool:
	return item_id in item_ids


## Get number of items in the set definition
func get_piece_count() -> int:
	return item_ids.size()


## Add a set bonus at a specific piece threshold
func add_bonus(pieces_required: int, bonus_data: Dictionary) -> void:
	bonuses[pieces_required] = bonus_data


## Get bonus at a specific threshold
func get_bonus_at_threshold(pieces: int) -> Dictionary:
	return bonuses.get(pieces, {})


## Get all active bonuses for a given piece count
## Returns array of {threshold: int, bonus: Dictionary}
func get_active_bonuses(equipped_pieces: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	# Get all thresholds that are met
	var thresholds: Array = bonuses.keys()
	thresholds.sort()

	for threshold in thresholds:
		if equipped_pieces >= threshold:
			result.append({
				"threshold": threshold,
				"bonus": bonuses[threshold],
			})

	return result


## Get total stat bonuses for a given piece count
func get_total_stat_bonuses(equipped_pieces: int) -> Dictionary:
	var total: Dictionary = {}

	for threshold in bonuses:
		var threshold_val: int = threshold
		if equipped_pieces >= threshold_val:
			var bonus: Dictionary = bonuses[threshold]
			for key in bonus:
				# Skip effect entries (string keys)
				if key is String:
					continue
				# Accumulate stat bonuses
				if key is int:  # StatType enum
					total[key] = total.get(key, 0.0) + bonus[key]

	return total


## Get active effects for a given piece count
## Returns array of {effect: String, magnitude: float, threshold: int}
func get_active_effects(equipped_pieces: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for threshold in bonuses:
		if equipped_pieces >= threshold:
			var bonus: Dictionary = bonuses[threshold]
			if bonus.has("effect"):
				result.append({
					"effect": bonus["effect"],
					"magnitude": bonus.get("magnitude", 1.0),
					"threshold": threshold,
				})

	return result


## Get the next bonus threshold above current pieces
func get_next_threshold(current_pieces: int) -> int:
	var thresholds: Array = bonuses.keys()
	thresholds.sort()

	for threshold in thresholds:
		if threshold > current_pieces:
			return threshold

	return -1  # No more thresholds


## Get pieces needed for next bonus
func get_pieces_until_next_bonus(current_pieces: int) -> int:
	var next := get_next_threshold(current_pieces)
	if next < 0:
		return 0
	return next - current_pieces


## Get display text for set bonuses
func get_bonus_display(equipped_pieces: int) -> String:
	var lines: Array[String] = []
	lines.append("%s (%d/%d)" % [name, equipped_pieces, get_piece_count()])

	var thresholds: Array = bonuses.keys()
	thresholds.sort()

	for threshold in thresholds:
		var bonus: Dictionary = bonuses[threshold]
		var threshold_int: int = threshold
		var active: bool = equipped_pieces >= threshold_int
		var prefix := "[X]" if active else "[ ]"

		var bonus_text := ""
		for key in bonus:
			if key == "effect":
				bonus_text += "%s " % bonus["effect"]
			elif key == "magnitude":
				continue
			elif key is int:
				var stat_name := ItemEnums.get_stat_name(key)
				var value: float = bonus[key]
				if value >= 0:
					bonus_text += "+%.0f %s " % [value, stat_name]
				else:
					bonus_text += "%.0f %s " % [value, stat_name]

		lines.append("%s %d pc: %s" % [prefix, threshold, bonus_text.strip_edges()])

	return "\n".join(lines)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"item_ids": item_ids,
		"bonuses": bonuses,
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> EquipmentSet:
	var eq_set := EquipmentSet.new()
	eq_set.id = data.get("id", "")
	eq_set.name = data.get("name", "")
	eq_set.description = data.get("description", "")

	var items: Array = data.get("item_ids", [])
	eq_set.item_ids = []
	for item_id in items:
		if item_id is String:
			eq_set.item_ids.append(item_id)

	eq_set.bonuses = data.get("bonuses", {})

	return eq_set


## Equipment Set Registry
class Registry extends RefCounted:
	## All registered sets indexed by ID
	var _sets: Dictionary = {}

	## Items indexed by set they belong to
	var _item_to_set: Dictionary = {}


	## Register a set
	func register(eq_set: EquipmentSet) -> void:
		if eq_set == null or eq_set.id.is_empty():
			return

		_sets[eq_set.id] = eq_set

		# Index items to set
		for item_id in eq_set.item_ids:
			_item_to_set[item_id] = eq_set.id


	## Get a set by ID
	func get_set(id: String) -> EquipmentSet:
		return _sets.get(id, null)


	## Get set that an item belongs to
	func get_set_for_item(item_id: String) -> EquipmentSet:
		var set_id: String = _item_to_set.get(item_id, "")
		if set_id.is_empty():
			return null
		return get_set(set_id)


	## Get all sets
	func get_all() -> Array[EquipmentSet]:
		var result: Array[EquipmentSet] = []
		for eq_set in _sets.values():
			result.append(eq_set)
		return result


	## Count equipped pieces of a set from equipped items
	## equipped_item_ids: Array of item definition IDs currently equipped
	func count_set_pieces(set_id: String, equipped_item_ids: Array) -> int:
		var eq_set := get_set(set_id)
		if eq_set == null:
			return 0

		var count := 0
		for item_id in equipped_item_ids:
			if eq_set.contains_item(item_id):
				count += 1

		return count


	## Get all active set bonuses from equipped items
	## Returns: {set_id: {pieces: int, stat_bonuses: Dictionary, effects: Array}}
	func get_all_active_bonuses(equipped_item_ids: Array) -> Dictionary:
		var result: Dictionary = {}

		# Count pieces per set
		var set_counts: Dictionary = {}
		for item_id in equipped_item_ids:
			var set_id: String = _item_to_set.get(item_id, "")
			if not set_id.is_empty():
				set_counts[set_id] = set_counts.get(set_id, 0) + 1

		# Calculate bonuses for each set
		for set_id in set_counts:
			var eq_set := get_set(set_id)
			if eq_set == null:
				continue

			var pieces: int = set_counts[set_id]
			var stat_bonuses := eq_set.get_total_stat_bonuses(pieces)
			var effects := eq_set.get_active_effects(pieces)

			if not stat_bonuses.is_empty() or not effects.is_empty():
				result[set_id] = {
					"pieces": pieces,
					"stat_bonuses": stat_bonuses,
					"effects": effects,
				}

		return result


	## Get count of registered sets
	func get_count() -> int:
		return _sets.size()


	## Clear all sets
	func clear() -> void:
		_sets.clear()
		_item_to_set.clear()
