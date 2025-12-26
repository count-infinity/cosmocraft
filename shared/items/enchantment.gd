class_name Enchantment
extends Resource
## Definition and instance of an enchantment that can be applied to items.
## Enchantments provide stat bonuses or special effects.


## Enchantment rarity affects power and application difficulty
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}


## Unique identifier for this enchantment type
@export var id: String = ""

## Display name
@export var name: String = ""

## Description of the effect
@export_multiline var description: String = ""

## Rarity level
@export var rarity: Rarity = Rarity.COMMON

## Which equipment slots this enchantment can be applied to
## Empty = can apply to any equippable item
@export var valid_slots: Array[ItemEnums.EquipSlot] = []

## Which item types this enchantment can be applied to
## Empty = can apply to any item
@export var valid_types: Array[ItemEnums.ItemType] = []

## Stat bonuses provided (key = StatType, value = bonus amount)
@export var stat_bonuses: Dictionary = {}

## Special effect ID (for effects beyond simple stat bonuses)
## e.g., "life_steal", "fire_damage", "speed_boost"
@export var effect_id: String = ""

## Effect magnitude (interpretation depends on effect_id)
@export var effect_magnitude: float = 0.0

## Maximum level for this enchantment
@export var max_level: int = 5

## Current level of this enchantment instance
var level: int = 1

## Whether this is a curse (negative enchantment)
@export var is_curse: bool = false

## Skill required to apply this enchantment
@export var required_skill: String = ""
@export var required_skill_level: int = 0


## Create a new enchantment with id and name
static func create(p_id: String, p_name: String) -> Enchantment:
	var ench := Enchantment.new()
	ench.id = p_id
	ench.name = p_name
	return ench


## Get stat bonus at current level
func get_stat_bonus(stat: ItemEnums.StatType) -> float:
	var base_bonus: float = stat_bonuses.get(stat, 0.0)
	return base_bonus * level


## Get all stat bonuses at current level
func get_all_stat_bonuses() -> Dictionary:
	var result: Dictionary = {}
	for stat in stat_bonuses:
		result[stat] = stat_bonuses[stat] * level
	return result


## Get effect magnitude at current level
func get_effect_at_level() -> float:
	return effect_magnitude * level


## Check if this enchantment can be applied to an item
func can_apply_to(item_def: ItemDefinition) -> bool:
	if item_def == null:
		return false

	# Check item type restriction
	if not valid_types.is_empty():
		if item_def.type not in valid_types:
			return false

	# Check slot restriction (only for equippable items)
	if not valid_slots.is_empty():
		if item_def.equip_slot == ItemEnums.EquipSlot.NONE:
			return false
		if item_def.equip_slot not in valid_slots:
			return false

	return true


## Get rarity name
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


## Get display text for this enchantment
func get_display_text() -> String:
	var text := name
	if max_level > 1:
		text += " " + _int_to_roman(level)
	return text


## Get full description with current stats
func get_full_description() -> String:
	var lines: Array[String] = []
	lines.append(get_display_text())
	lines.append("[%s]" % get_rarity_name())

	if not description.is_empty():
		lines.append(description)

	# List stat bonuses
	for stat in stat_bonuses:
		var bonus := get_stat_bonus(stat)
		var stat_name := ItemEnums.get_stat_name(stat)
		if bonus >= 0:
			lines.append("+%.1f %s" % [bonus, stat_name])
		else:
			lines.append("%.1f %s" % [bonus, stat_name])

	# Show effect if present
	if not effect_id.is_empty():
		lines.append("%s: %.1f" % [effect_id, get_effect_at_level()])

	return "\n".join(lines)


## Create a copy at a specific level
func create_at_level(target_level: int) -> Enchantment:
	var copy := Enchantment.new()
	copy.id = id
	copy.name = name
	copy.description = description
	copy.rarity = rarity
	copy.valid_slots = valid_slots.duplicate()
	copy.valid_types = valid_types.duplicate()
	copy.stat_bonuses = stat_bonuses.duplicate()
	copy.effect_id = effect_id
	copy.effect_magnitude = effect_magnitude
	copy.max_level = max_level
	copy.level = clampi(target_level, 1, max_level)
	copy.is_curse = is_curse
	copy.required_skill = required_skill
	copy.required_skill_level = required_skill_level
	return copy


## Convert integer to roman numerals (for level display)
func _int_to_roman(num: int) -> String:
	if num <= 0 or num > 10:
		return str(num)

	var numerals := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return numerals[num - 1]


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"level": level,
	}


## Deserialize from dictionary (requires registry for full data)
static func from_dict(data: Dictionary, registry: EnchantmentRegistry) -> Enchantment:
	var ench_id: String = data.get("id", "")
	var ench_level: int = data.get("level", 1)

	if registry == null:
		return null

	var base := registry.get_enchantment(ench_id)
	if base == null:
		return null

	return base.create_at_level(ench_level)


## Full serialization (includes all definition data)
func to_full_dict() -> Dictionary:
	var slots_array: Array = []
	for slot in valid_slots:
		slots_array.append(slot)

	var types_array: Array = []
	for item_type in valid_types:
		types_array.append(item_type)

	return {
		"id": id,
		"name": name,
		"description": description,
		"rarity": rarity,
		"valid_slots": slots_array,
		"valid_types": types_array,
		"stat_bonuses": stat_bonuses,
		"effect_id": effect_id,
		"effect_magnitude": effect_magnitude,
		"max_level": max_level,
		"level": level,
		"is_curse": is_curse,
		"required_skill": required_skill,
		"required_skill_level": required_skill_level,
	}


## Create from full dictionary (no registry needed)
static func from_full_dict(data: Dictionary) -> Enchantment:
	var ench := Enchantment.new()
	ench.id = data.get("id", "")
	ench.name = data.get("name", "")
	ench.description = data.get("description", "")
	ench.rarity = data.get("rarity", Rarity.COMMON)
	ench.effect_id = data.get("effect_id", "")
	ench.effect_magnitude = data.get("effect_magnitude", 0.0)
	ench.max_level = data.get("max_level", 5)
	ench.level = data.get("level", 1)
	ench.is_curse = data.get("is_curse", false)
	ench.required_skill = data.get("required_skill", "")
	ench.required_skill_level = data.get("required_skill_level", 0)
	ench.stat_bonuses = data.get("stat_bonuses", {})

	# Restore arrays
	var slots_data: Array = data.get("valid_slots", [])
	ench.valid_slots = []
	for slot in slots_data:
		ench.valid_slots.append(slot)

	var types_data: Array = data.get("valid_types", [])
	ench.valid_types = []
	for item_type in types_data:
		ench.valid_types.append(item_type)

	return ench
