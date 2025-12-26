class_name ItemInstance
extends RefCounted
## Runtime instance of an item.
## This represents an actual item in the world/inventory with specific state.


## Reference to the item's static definition
var definition: ItemDefinition

## Unique ID for this specific item instance
var instance_id: String = ""

## Current durability (if applicable)
var current_durability: int = 0

## Enchantments applied to this item (array of Enchantment IDs with tiers)
## Format: [{"id": "flame", "tier": 2}, ...]
var enchantments: Array[Dictionary] = []

## Gems socketed in this item (array of Gem IDs)
var socketed_gems: Array[String] = []

## Optional registry references for stat calculations
## These can be set to enable enchantment/gem stat bonuses
var _enchantment_registry: EnchantmentRegistry = null
var _item_registry: ItemRegistry = null

## Player ID who crafted this item (empty if not crafted)
var crafted_by: String = ""

## Quality multiplier from crafting (0.6 - 1.25)
var quality: float = 1.0

## Current tool mode (for tools with multiple modes)
var current_mode: ItemEnums.ToolMode = ItemEnums.ToolMode.STANDARD


## Create a new item instance from a definition
static func create(item_def: ItemDefinition, p_quality: float = 1.0) -> ItemInstance:
	var instance := ItemInstance.new()
	instance.definition = item_def
	instance.instance_id = _generate_instance_id()
	instance.quality = clampf(p_quality, 0.6, 1.25)

	# Set initial durability
	if item_def.has_durability():
		instance.current_durability = int(item_def.base_durability * instance.quality)

	# Set default mode if tool has modes
	if item_def.available_modes.size() > 0:
		instance.current_mode = item_def.available_modes[0]

	return instance


## Generate a unique instance ID
static func _generate_instance_id() -> String:
	# Combine timestamp with random for uniqueness
	var time := Time.get_unix_time_from_system()
	var rand := randi()
	return "%d_%d" % [time, rand]


## Get the display name (with enchant prefix if applicable)
func get_display_name() -> String:
	if definition == null:
		return "Unknown Item"

	var prefix := ""
	if enchantments.size() > 0:
		# Use first enchantment for name prefix
		# TODO: Look up enchantment definition for prefix
		prefix = ""

	var quality_prefix := ""
	if quality < 0.8:
		quality_prefix = "Crude "
	elif quality >= 1.15:
		quality_prefix = "Masterwork "
	elif quality >= 1.05:
		quality_prefix = "Fine "

	return quality_prefix + prefix + definition.name


## Set the enchantment registry for stat calculations
func set_enchantment_registry(registry: EnchantmentRegistry) -> void:
	_enchantment_registry = registry


## Set the item registry for gem stat calculations
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry


## Set both registries at once (convenience method)
func set_registries(enchant_registry: EnchantmentRegistry, item_registry: ItemRegistry) -> void:
	_enchantment_registry = enchant_registry
	_item_registry = item_registry


## Get effective stats after quality, enchantments, and gems
func get_effective_stats() -> Dictionary:
	if definition == null:
		return {}

	var stats := {}

	# Apply base stats with quality modifier
	for stat_key in definition.base_stats:
		var base_value: float = definition.base_stats[stat_key]
		stats[stat_key] = base_value * quality

	# Apply enchantment bonuses (requires registry)
	if _enchantment_registry != null:
		for enchant_data in enchantments:
			var enchant_id: String = enchant_data.get("id", "")
			var enchant_tier: int = enchant_data.get("tier", 1)

			if enchant_id.is_empty():
				continue

			# Create enchantment at the stored tier/level
			var enchant := _enchantment_registry.create_enchantment(enchant_id, enchant_tier)
			if enchant == null:
				continue

			# Add all stat bonuses from this enchantment
			var enchant_bonuses := enchant.get_all_stat_bonuses()
			for stat in enchant_bonuses:
				stats[stat] = stats.get(stat, 0.0) + enchant_bonuses[stat]

	# Apply gem bonuses (requires item registry)
	if _item_registry != null:
		for gem_id in socketed_gems:
			var gem_def := _item_registry.get_item(gem_id)
			if gem_def == null:
				continue

			# Gems must be of type GEM to provide stat bonuses
			if gem_def.type != ItemEnums.ItemType.GEM:
				continue

			# Add gem's base stats as bonuses
			for stat in gem_def.base_stats:
				stats[stat] = stats.get(stat, 0.0) + gem_def.base_stats[stat]

	return stats


## Get a specific effective stat
func get_stat(stat: ItemEnums.StatType) -> float:
	var stats := get_effective_stats()
	return stats.get(stat, 0.0)


## Get effective durability (with quality applied)
func get_max_durability() -> int:
	if definition == null or not definition.has_durability():
		return 0
	return int(definition.base_durability * quality)


## Check if item is broken (0 durability)
func is_broken() -> bool:
	if definition == null or not definition.has_durability():
		return false
	return current_durability <= 0


## Use durability (returns true if item broke)
func use_durability(amount: int = 1) -> bool:
	if definition == null or not definition.has_durability():
		return false

	# TODO: Check for Unbreaking enchantment
	current_durability = maxi(0, current_durability - amount)
	return current_durability <= 0


## Repair item (returns amount actually repaired)
func repair(amount: int) -> int:
	if definition == null or not definition.has_durability():
		return 0

	var max_dur := get_max_durability()
	var old_dur := current_durability
	current_durability = mini(current_durability + amount, max_dur)
	return current_durability - old_dur


## Get repair cost as percentage (0.0 - 1.0)
func get_repair_percentage() -> float:
	var max_dur := get_max_durability()
	if max_dur <= 0:
		return 0.0
	return 1.0 - (float(current_durability) / float(max_dur))


## Check if item can have more enchantments
func can_add_enchantment() -> bool:
	if definition == null:
		return false
	return enchantments.size() < definition.enchant_slots


## Add an enchantment (returns true if successful)
func add_enchantment(enchant_id: String, tier: int) -> bool:
	if not can_add_enchantment():
		return false

	# TODO: Check mutex groups
	enchantments.append({"id": enchant_id, "tier": tier})
	return true


## Remove an enchantment by index
func remove_enchantment(index: int) -> bool:
	if index < 0 or index >= enchantments.size():
		return false
	enchantments.remove_at(index)
	return true


## Check if item can have more gems
func can_add_gem() -> bool:
	if definition == null:
		return false
	return socketed_gems.size() < definition.socket_count


## Add a gem (returns true if successful)
func add_gem(gem_id: String) -> bool:
	if not can_add_gem():
		return false
	socketed_gems.append(gem_id)
	return true


## Remove a gem by index
func remove_gem(index: int) -> bool:
	if index < 0 or index >= socketed_gems.size():
		return false
	socketed_gems.remove_at(index)
	return true


## Cycle to next tool mode (for multi-mode tools)
func cycle_mode() -> void:
	if definition == null or definition.available_modes.size() <= 1:
		return

	var current_idx := definition.available_modes.find(current_mode)
	if current_idx < 0:
		current_mode = definition.available_modes[0]
	else:
		current_idx = (current_idx + 1) % definition.available_modes.size()
		current_mode = definition.available_modes[current_idx]


## Serialize to dictionary for network/save
func to_dict() -> Dictionary:
	return {
		"definition_id": definition.id if definition else "",
		"instance_id": instance_id,
		"current_durability": current_durability,
		"enchantments": enchantments,
		"socketed_gems": socketed_gems,
		"crafted_by": crafted_by,
		"quality": quality,
		"current_mode": current_mode,
	}


## Create from dictionary (requires item registry to look up definition)
static func from_dict(data: Dictionary, item_registry: Object) -> ItemInstance:
	var instance := ItemInstance.new()

	var def_id: String = data.get("definition_id", "")
	if def_id != "" and item_registry != null:
		instance.definition = item_registry.get_item(def_id)

	instance.instance_id = data.get("instance_id", _generate_instance_id())
	instance.current_durability = data.get("current_durability", 0)
	instance.crafted_by = data.get("crafted_by", "")
	instance.quality = data.get("quality", 1.0)
	instance.current_mode = data.get("current_mode", ItemEnums.ToolMode.STANDARD)

	# Handle enchantments array
	var ench_data: Array = data.get("enchantments", [])
	instance.enchantments = []
	for ench in ench_data:
		if ench is Dictionary:
			instance.enchantments.append(ench)

	# Handle gems array
	var gem_data: Array = data.get("socketed_gems", [])
	instance.socketed_gems = []
	for gem in gem_data:
		instance.socketed_gems.append(str(gem))

	return instance
