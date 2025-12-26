class_name PlayerSkills
extends RefCounted
## Manages a player's skill progression.
## Tracks XP, levels, and unlocked skills.


## Signal emitted when XP is gained
signal xp_gained(skill_id: String, amount: int, new_total: int)

## Signal emitted when a skill levels up
signal level_up(skill_id: String, new_level: int)

## Signal emitted when a skill is unlocked
signal skill_unlocked(skill_id: String)


## Skill data storage: {skill_id: {xp: int, unlocked: bool}}
var _skills: Dictionary = {}

## Reference to skill definitions
var _skill_definitions: Dictionary = {}

## Cached levels (recalculated when XP changes)
var _cached_levels: Dictionary = {}


func _init() -> void:
	pass


## Register a skill definition
func register_skill(skill_def: SkillDefinition) -> void:
	if skill_def == null or skill_def.id.is_empty():
		return

	_skill_definitions[skill_def.id] = skill_def

	# Initialize skill data if not exists
	if not _skills.has(skill_def.id):
		_skills[skill_def.id] = {
			"xp": 0,
			"unlocked": skill_def.unlocked_by_default,
		}
		_cached_levels[skill_def.id] = 1


## Get a skill definition
func get_skill_definition(skill_id: String) -> SkillDefinition:
	return _skill_definitions.get(skill_id, null)


## Get all skill definitions
func get_all_skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for skill_def in _skill_definitions.values():
		result.append(skill_def)
	return result


## Get skill definitions by category
func get_skills_by_category(category: SkillDefinition.SkillCategory) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for skill_def in _skill_definitions.values():
		if skill_def.category == category:
			result.append(skill_def)
	return result


## Check if a skill is unlocked
func is_skill_unlocked(skill_id: String) -> bool:
	if not _skills.has(skill_id):
		return false
	return _skills[skill_id].get("unlocked", false)


## Unlock a skill
func unlock_skill(skill_id: String) -> bool:
	if not _skill_definitions.has(skill_id):
		return false

	if is_skill_unlocked(skill_id):
		return false  # Already unlocked

	var skill_def: SkillDefinition = _skill_definitions[skill_id]

	# Check prerequisite
	if skill_def.has_prerequisite():
		var prereq_level := get_skill_level(skill_def.prerequisite_skill)
		if prereq_level < skill_def.prerequisite_level:
			return false

	if not _skills.has(skill_id):
		_skills[skill_id] = {"xp": 0, "unlocked": true}
		_cached_levels[skill_id] = 1
	else:
		_skills[skill_id]["unlocked"] = true

	skill_unlocked.emit(skill_id)
	return true


## Get current XP for a skill
func get_skill_xp(skill_id: String) -> int:
	if not _skills.has(skill_id):
		return 0
	return _skills[skill_id].get("xp", 0)


## Get current level for a skill
func get_skill_level(skill_id: String) -> int:
	if not _skills.has(skill_id):
		return 0
	if not is_skill_unlocked(skill_id):
		return 0

	# Use cached level
	if _cached_levels.has(skill_id):
		return _cached_levels[skill_id]

	return 1


## Add XP to a skill
## Returns true if skill leveled up
func add_xp(skill_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	if not _skill_definitions.has(skill_id):
		return false

	if not is_skill_unlocked(skill_id):
		return false

	var skill_def: SkillDefinition = _skill_definitions[skill_id]
	var old_level := get_skill_level(skill_id)

	# Add XP
	if not _skills.has(skill_id):
		_skills[skill_id] = {"xp": 0, "unlocked": true}

	_skills[skill_id]["xp"] = _skills[skill_id].get("xp", 0) + amount
	var new_xp: int = _skills[skill_id]["xp"]

	# Recalculate level
	var new_level := skill_def.get_level_from_total_xp(new_xp)
	new_level = mini(new_level, skill_def.max_level)
	_cached_levels[skill_id] = new_level

	xp_gained.emit(skill_id, amount, new_xp)

	# Check for level up
	if new_level > old_level:
		level_up.emit(skill_id, new_level)
		return true

	return false


## Set XP directly (for loading saves)
func set_skill_xp(skill_id: String, xp: int) -> void:
	if not _skill_definitions.has(skill_id):
		return

	if not _skills.has(skill_id):
		_skills[skill_id] = {"xp": 0, "unlocked": false}

	_skills[skill_id]["xp"] = maxi(0, xp)

	# Recalculate level
	var skill_def: SkillDefinition = _skill_definitions[skill_id]
	var level := skill_def.get_level_from_total_xp(xp)
	_cached_levels[skill_id] = mini(level, skill_def.max_level)


## Get XP progress towards next level (0.0 to 1.0)
func get_level_progress(skill_id: String) -> float:
	if not _skill_definitions.has(skill_id):
		return 0.0

	var skill_def: SkillDefinition = _skill_definitions[skill_id]
	var xp := get_skill_xp(skill_id)
	return skill_def.get_level_progress(xp)


## Get XP needed for next level
func get_xp_for_next_level(skill_id: String) -> int:
	if not _skill_definitions.has(skill_id):
		return 0

	var skill_def: SkillDefinition = _skill_definitions[skill_id]
	var level := get_skill_level(skill_id)

	if level >= skill_def.max_level:
		return 0

	return skill_def.get_xp_for_level(level + 1)


## Get XP remaining until next level
func get_xp_remaining(skill_id: String) -> int:
	if not _skill_definitions.has(skill_id):
		return 0

	var skill_def: SkillDefinition = _skill_definitions[skill_id]
	var level := get_skill_level(skill_id)

	if level >= skill_def.max_level:
		return 0

	var xp := get_skill_xp(skill_id)
	var xp_for_current := skill_def.get_total_xp_for_level(level)
	var xp_for_next := skill_def.get_xp_for_level(level + 1)

	return xp_for_next - (xp - xp_for_current)


## Check if skill is at max level
func is_max_level(skill_id: String) -> bool:
	if not _skill_definitions.has(skill_id):
		return false

	var skill_def: SkillDefinition = _skill_definitions[skill_id]
	return get_skill_level(skill_id) >= skill_def.max_level


## Get bonus value from a skill
func get_skill_bonus(skill_id: String, bonus_type: String) -> float:
	if not _skill_definitions.has(skill_id):
		return 0.0

	var skill_def: SkillDefinition = _skill_definitions[skill_id]
	var level := get_skill_level(skill_id)
	return skill_def.get_bonus_at_level(bonus_type, level)


## Get total bonus from all skills for a bonus type
func get_total_bonus(bonus_type: String) -> float:
	var total := 0.0
	for skill_id in _skill_definitions:
		total += get_skill_bonus(skill_id, bonus_type)
	return total


## Get all skill levels as a dictionary (for crafting system integration)
func get_all_levels() -> Dictionary:
	var result: Dictionary = {}
	for skill_id in _skills:
		if is_skill_unlocked(skill_id):
			result[skill_id] = get_skill_level(skill_id)
	return result


## Get unlocked skills
func get_unlocked_skills() -> Array[String]:
	var result: Array[String] = []
	for skill_id in _skills:
		if is_skill_unlocked(skill_id):
			result.append(skill_id)
	return result


## Get skill count
func get_skill_count() -> int:
	return _skill_definitions.size()


## Get unlocked skill count
func get_unlocked_count() -> int:
	var count := 0
	for skill_id in _skills:
		if is_skill_unlocked(skill_id):
			count += 1
	return count


## Calculate total level across all skills
func get_total_level() -> int:
	var total := 0
	for skill_id in _skills:
		if is_skill_unlocked(skill_id):
			total += get_skill_level(skill_id)
	return total


## Clear all progress (for testing)
func clear() -> void:
	_skills.clear()
	_cached_levels.clear()

	# Re-initialize with defaults
	for skill_id in _skill_definitions:
		var skill_def: SkillDefinition = _skill_definitions[skill_id]
		_skills[skill_id] = {
			"xp": 0,
			"unlocked": skill_def.unlocked_by_default,
		}
		_cached_levels[skill_id] = 1


## Serialize to dictionary
func to_dict() -> Dictionary:
	var skills_data: Dictionary = {}
	for skill_id in _skills:
		skills_data[skill_id] = {
			"xp": _skills[skill_id].get("xp", 0),
			"unlocked": _skills[skill_id].get("unlocked", false),
		}

	return {
		"skills": skills_data,
	}


## Deserialize from dictionary
func from_dict(data: Dictionary) -> void:
	var skills_data: Dictionary = data.get("skills", {})

	for skill_id in skills_data:
		if skill_id is String:
			var skill_data: Dictionary = skills_data[skill_id]
			var xp: int = skill_data.get("xp", 0)
			var unlocked: bool = skill_data.get("unlocked", false)

			_skills[skill_id] = {
				"xp": xp,
				"unlocked": unlocked,
			}

			# Recalculate cached level
			if _skill_definitions.has(skill_id):
				var skill_def: SkillDefinition = _skill_definitions[skill_id]
				var level := skill_def.get_level_from_total_xp(xp)
				_cached_levels[skill_id] = mini(level, skill_def.max_level)
			else:
				_cached_levels[skill_id] = 1


## Get summary string (for debugging)
func get_summary() -> String:
	var lines: Array[String] = []
	lines.append("Skills (%d unlocked):" % get_unlocked_count())

	for skill_id in _skill_definitions:
		var skill_def: SkillDefinition = _skill_definitions[skill_id]
		if is_skill_unlocked(skill_id):
			var level := get_skill_level(skill_id)
			var xp := get_skill_xp(skill_id)
			var progress := get_level_progress(skill_id)
			lines.append("  %s: Lv.%d (%d XP, %.0f%%)" % [
				skill_def.name,
				level,
				xp,
				progress * 100
			])
		else:
			lines.append("  %s: [Locked]" % skill_def.name)

	return "\n".join(lines)
