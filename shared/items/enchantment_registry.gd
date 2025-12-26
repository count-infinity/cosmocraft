class_name EnchantmentRegistry
extends RefCounted
## Registry for enchantment definitions.
## Manages enchantment lookup and application.


## All registered enchantments indexed by ID
var _enchantments: Dictionary = {}

## Enchantments indexed by rarity
var _by_rarity: Dictionary = {}


func _init() -> void:
	# Initialize rarity buckets
	for rarity in Enchantment.Rarity.values():
		_by_rarity[rarity] = []


## Register an enchantment definition
func register(enchantment: Enchantment) -> void:
	if enchantment == null or enchantment.id.is_empty():
		return

	_enchantments[enchantment.id] = enchantment

	# Index by rarity
	var rarity_list: Array = _by_rarity.get(enchantment.rarity, [])
	if enchantment not in rarity_list:
		rarity_list.append(enchantment)
		_by_rarity[enchantment.rarity] = rarity_list


## Get an enchantment by ID
func get_enchantment(id: String) -> Enchantment:
	return _enchantments.get(id, null)


## Get all enchantment IDs
func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _enchantments.keys():
		result.append(id)
	return result


## Get all enchantments
func get_all() -> Array[Enchantment]:
	var result: Array[Enchantment] = []
	for ench in _enchantments.values():
		result.append(ench)
	return result


## Get enchantments by rarity
func get_by_rarity(rarity: Enchantment.Rarity) -> Array[Enchantment]:
	var result: Array[Enchantment] = []
	var list: Array = _by_rarity.get(rarity, [])
	for ench in list:
		result.append(ench)
	return result


## Get enchantments that can be applied to an item
func get_applicable_for(item_def: ItemDefinition) -> Array[Enchantment]:
	var result: Array[Enchantment] = []
	for ench in _enchantments.values():
		if ench.can_apply_to(item_def):
			result.append(ench)
	return result


## Get random enchantment (weighted by rarity)
## rarity_weights: {Rarity: weight} - higher weight = more likely
func get_random(rarity_weights: Dictionary = {}) -> Enchantment:
	if _enchantments.is_empty():
		return null

	# Default weights if not provided
	if rarity_weights.is_empty():
		rarity_weights = {
			Enchantment.Rarity.COMMON: 50,
			Enchantment.Rarity.UNCOMMON: 30,
			Enchantment.Rarity.RARE: 15,
			Enchantment.Rarity.EPIC: 4,
			Enchantment.Rarity.LEGENDARY: 1,
		}

	# Calculate total weight
	var total_weight := 0.0
	for rarity in rarity_weights:
		var ench_list: Array = _by_rarity.get(rarity, [])
		if not ench_list.is_empty():
			total_weight += rarity_weights[rarity]

	if total_weight <= 0:
		return null

	# Pick random rarity
	var roll := randf() * total_weight
	var current := 0.0

	for rarity in rarity_weights:
		var ench_list: Array = _by_rarity.get(rarity, [])
		if ench_list.is_empty():
			continue

		current += rarity_weights[rarity]
		if roll <= current:
			# Pick random enchantment from this rarity
			return ench_list[randi() % ench_list.size()]

	# Fallback to any enchantment
	var all := get_all()
	if all.is_empty():
		return null
	return all[randi() % all.size()]


## Get random enchantment applicable to an item
func get_random_for(item_def: ItemDefinition, rarity_weights: Dictionary = {}) -> Enchantment:
	var applicable := get_applicable_for(item_def)
	if applicable.is_empty():
		return null

	# Filter by rarity weights if provided
	if not rarity_weights.is_empty():
		var weighted: Array[Enchantment] = []
		var weights: Array[float] = []
		var total := 0.0

		for ench in applicable:
			var weight: float = rarity_weights.get(ench.rarity, 0.0)
			if weight > 0:
				weighted.append(ench)
				weights.append(weight)
				total += weight

		if total > 0:
			var roll := randf() * total
			var current := 0.0
			for i in range(weighted.size()):
				current += weights[i]
				if roll <= current:
					return weighted[i]

	# Random from applicable
	return applicable[randi() % applicable.size()]


## Create an enchantment instance at a specific level
func create_enchantment(id: String, level: int = 1) -> Enchantment:
	var base := get_enchantment(id)
	if base == null:
		push_warning("EnchantmentRegistry: Unknown enchantment ID: %s" % id)
		return null
	return base.create_at_level(level)


## Get count of registered enchantments
func get_count() -> int:
	return _enchantments.size()


## Unregister an enchantment
func unregister(id: String) -> void:
	var ench: Enchantment = _enchantments.get(id, null)
	if ench != null:
		_enchantments.erase(id)
		var rarity_list: Array = _by_rarity.get(ench.rarity, [])
		rarity_list.erase(ench)


## Clear all enchantments
func clear() -> void:
	_enchantments.clear()
	for rarity in Enchantment.Rarity.values():
		_by_rarity[rarity] = []
