class_name SkillDefinition
extends Resource
## Definition of a skill type.
## Specifies skill properties, XP curve, and level bonuses.


## Skill category for organization
enum SkillCategory {
	COMBAT,      ## Fighting skills (melee, ranged, defense)
	CRAFTING,    ## Making items (smithing, tailoring, cooking)
	GATHERING,   ## Resource collection (mining, logging, harvesting)
	SURVIVAL,    ## Staying alive (first aid, athletics, resilience)
	UTILITY,     ## General skills (repair, navigation, bartering)
}


## Unique identifier for this skill
@export var id: String = ""

## Display name
@export var name: String = ""

## Description
@export_multiline var description: String = ""

## Category for UI organization
@export var category: SkillCategory = SkillCategory.UTILITY

## Maximum level for this skill
@export var max_level: int = 100

## Base XP required for level 2 (scales from here)
@export var base_xp: int = 100

## XP scaling factor per level (exponential growth)
## Formula: xp_for_level = base_xp * (level ^ xp_exponent)
@export var xp_exponent: float = 1.5

## Icon path for UI
@export var icon_path: String = ""

## Whether this skill is discoverable from the start
@export var unlocked_by_default: bool = true

## Item ID that unlocks this skill (if not unlocked by default)
@export var unlock_item_id: String = ""

## Parent skill that must be at a certain level to unlock
@export var prerequisite_skill: String = ""
@export var prerequisite_level: int = 0

## Bonuses granted per level (key = bonus type, value = amount per level)
## e.g., {"damage": 0.5, "crit_chance": 0.1}
@export var level_bonuses: Dictionary = {}


func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	name = p_name


## Calculate XP required to reach a specific level
func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level > max_level:
		level = max_level

	# Exponential curve: base_xp * level^exponent
	return int(base_xp * pow(level, xp_exponent))


## Calculate total XP required from level 1 to target level
func get_total_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0

	var total := 0
	for i in range(2, mini(level + 1, max_level + 1)):
		total += get_xp_for_level(i)
	return total


## Calculate level from total XP
func get_level_from_total_xp(total_xp: int) -> int:
	if total_xp <= 0:
		return 1

	var level := 1
	var xp_remaining := total_xp

	while level < max_level:
		var xp_needed := get_xp_for_level(level + 1)
		if xp_remaining < xp_needed:
			break
		xp_remaining -= xp_needed
		level += 1

	return level


## Get XP progress towards next level (0.0 to 1.0)
func get_level_progress(total_xp: int) -> float:
	var level := get_level_from_total_xp(total_xp)
	if level >= max_level:
		return 1.0

	var xp_for_current := get_total_xp_for_level(level)
	var xp_for_next := get_xp_for_level(level + 1)

	if xp_for_next <= 0:
		return 1.0

	var xp_into_level := total_xp - xp_for_current
	return clampf(float(xp_into_level) / float(xp_for_next), 0.0, 1.0)


## Get bonus value at a specific level
func get_bonus_at_level(bonus_type: String, level: int) -> float:
	var per_level: float = level_bonuses.get(bonus_type, 0.0)
	return per_level * level


## Get all bonuses at a specific level
func get_all_bonuses_at_level(level: int) -> Dictionary:
	var result: Dictionary = {}
	for bonus_type in level_bonuses:
		result[bonus_type] = get_bonus_at_level(bonus_type, level)
	return result


## Check if skill has a prerequisite
func has_prerequisite() -> bool:
	return not prerequisite_skill.is_empty()


## Get category name as string
func get_category_name() -> String:
	match category:
		SkillCategory.COMBAT:
			return "Combat"
		SkillCategory.CRAFTING:
			return "Crafting"
		SkillCategory.GATHERING:
			return "Gathering"
		SkillCategory.SURVIVAL:
			return "Survival"
		SkillCategory.UTILITY:
			return "Utility"
		_:
			return "Unknown"


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"category": category,
		"max_level": max_level,
		"base_xp": base_xp,
		"xp_exponent": xp_exponent,
		"icon_path": icon_path,
		"unlocked_by_default": unlocked_by_default,
		"unlock_item_id": unlock_item_id,
		"prerequisite_skill": prerequisite_skill,
		"prerequisite_level": prerequisite_level,
		"level_bonuses": level_bonuses,
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.id = data.get("id", "")
	skill.name = data.get("name", "")
	skill.description = data.get("description", "")
	skill.category = data.get("category", SkillCategory.UTILITY)
	skill.max_level = data.get("max_level", 100)
	skill.base_xp = data.get("base_xp", 100)
	skill.xp_exponent = data.get("xp_exponent", 1.5)
	skill.icon_path = data.get("icon_path", "")
	skill.unlocked_by_default = data.get("unlocked_by_default", true)
	skill.unlock_item_id = data.get("unlock_item_id", "")
	skill.prerequisite_skill = data.get("prerequisite_skill", "")
	skill.prerequisite_level = data.get("prerequisite_level", 0)
	skill.level_bonuses = data.get("level_bonuses", {})
	return skill


## Get static category name
static func get_category_name_static(cat: SkillCategory) -> String:
	match cat:
		SkillCategory.COMBAT:
			return "Combat"
		SkillCategory.CRAFTING:
			return "Crafting"
		SkillCategory.GATHERING:
			return "Gathering"
		SkillCategory.SURVIVAL:
			return "Survival"
		SkillCategory.UTILITY:
			return "Utility"
		_:
			return "Unknown"
