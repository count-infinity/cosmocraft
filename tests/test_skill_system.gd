extends GutTest
## Tests for the skill system (Phase 5).
## Tests SkillDefinition and PlayerSkills classes.


var _player_skills: PlayerSkills


# Test skill definitions
var _smithing: SkillDefinition
var _mining: SkillDefinition
var _combat: SkillDefinition
var _advanced_smithing: SkillDefinition


func before_each() -> void:
	_player_skills = PlayerSkills.new()

	# Create test skills
	_smithing = SkillDefinition.new("smithing", "Smithing")
	_smithing.description = "Craft metal items"
	_smithing.category = SkillDefinition.SkillCategory.CRAFTING
	_smithing.max_level = 100
	_smithing.base_xp = 100
	_smithing.xp_exponent = 1.5
	_smithing.unlocked_by_default = true
	_smithing.level_bonuses = {"craft_quality": 0.01, "craft_speed": 0.5}

	_mining = SkillDefinition.new("mining", "Mining")
	_mining.description = "Extract ore from rocks"
	_mining.category = SkillDefinition.SkillCategory.GATHERING
	_mining.max_level = 100
	_mining.base_xp = 100
	_mining.xp_exponent = 1.5
	_mining.unlocked_by_default = true
	_mining.level_bonuses = {"ore_yield": 0.02}

	_combat = SkillDefinition.new("combat", "Combat")
	_combat.description = "Fighting prowess"
	_combat.category = SkillDefinition.SkillCategory.COMBAT
	_combat.max_level = 50
	_combat.base_xp = 150
	_combat.xp_exponent = 1.8
	_combat.unlocked_by_default = true
	_combat.level_bonuses = {"damage": 1.0, "crit_chance": 0.2}

	_advanced_smithing = SkillDefinition.new("advanced_smithing", "Advanced Smithing")
	_advanced_smithing.description = "Craft exotic items"
	_advanced_smithing.category = SkillDefinition.SkillCategory.CRAFTING
	_advanced_smithing.max_level = 50
	_advanced_smithing.base_xp = 200
	_advanced_smithing.xp_exponent = 2.0
	_advanced_smithing.unlocked_by_default = false
	_advanced_smithing.prerequisite_skill = "smithing"
	_advanced_smithing.prerequisite_level = 25


func after_each() -> void:
	_player_skills = null


# ====================
# SkillDefinition Tests
# ====================

func test_skill_definition_creation() -> void:
	var skill := SkillDefinition.new("test_skill", "Test Skill")
	assert_eq(skill.id, "test_skill")
	assert_eq(skill.name, "Test Skill")


func test_skill_definition_defaults() -> void:
	var skill := SkillDefinition.new()
	assert_eq(skill.max_level, 100)
	assert_eq(skill.base_xp, 100)
	assert_eq(skill.xp_exponent, 1.5)
	assert_true(skill.unlocked_by_default)


func test_skill_xp_for_level() -> void:
	var skill := SkillDefinition.new()
	skill.base_xp = 100
	skill.xp_exponent = 1.5

	assert_eq(skill.get_xp_for_level(1), 0)  # Level 1 is free
	assert_eq(skill.get_xp_for_level(2), 282)  # 100 * 2^1.5 = 282.8
	assert_eq(skill.get_xp_for_level(3), 519)  # 100 * 3^1.5 = 519.6


func test_skill_total_xp_for_level() -> void:
	var skill := SkillDefinition.new()
	skill.base_xp = 100
	skill.xp_exponent = 1.5

	assert_eq(skill.get_total_xp_for_level(1), 0)
	assert_eq(skill.get_total_xp_for_level(2), 282)  # XP for level 2
	assert_eq(skill.get_total_xp_for_level(3), 282 + 519)  # XP for 2 + 3


func test_skill_level_from_xp() -> void:
	var skill := SkillDefinition.new()
	skill.base_xp = 100
	skill.xp_exponent = 1.5

	assert_eq(skill.get_level_from_total_xp(0), 1)
	assert_eq(skill.get_level_from_total_xp(100), 1)  # Not enough for level 2
	assert_eq(skill.get_level_from_total_xp(282), 2)  # Exactly level 2
	assert_eq(skill.get_level_from_total_xp(500), 2)  # Between 2 and 3
	assert_eq(skill.get_level_from_total_xp(282 + 519), 3)  # Exactly level 3


func test_skill_level_progress() -> void:
	var skill := SkillDefinition.new()
	skill.base_xp = 100
	skill.xp_exponent = 1.5

	assert_eq(skill.get_level_progress(0), 0.0)
	assert_almost_eq(skill.get_level_progress(141), 0.5, 0.01)  # Half to level 2
	assert_eq(skill.get_level_progress(282), 0.0)  # Just hit level 2


func test_skill_level_progress_max() -> void:
	var skill := SkillDefinition.new()
	skill.max_level = 10

	var max_xp := skill.get_total_xp_for_level(10) + 10000
	assert_eq(skill.get_level_progress(max_xp), 1.0)


func test_skill_bonus_at_level() -> void:
	assert_eq(_smithing.get_bonus_at_level("craft_quality", 10), 0.1)  # 10 * 0.01
	assert_eq(_smithing.get_bonus_at_level("craft_speed", 10), 5.0)   # 10 * 0.5
	assert_eq(_smithing.get_bonus_at_level("unknown", 10), 0.0)


func test_skill_all_bonuses_at_level() -> void:
	var bonuses := _smithing.get_all_bonuses_at_level(20)
	assert_eq(bonuses["craft_quality"], 0.2)  # 20 * 0.01
	assert_eq(bonuses["craft_speed"], 10.0)   # 20 * 0.5


func test_skill_has_prerequisite() -> void:
	assert_false(_smithing.has_prerequisite())
	assert_true(_advanced_smithing.has_prerequisite())


func test_skill_category_name() -> void:
	assert_eq(_smithing.get_category_name(), "Crafting")
	assert_eq(_mining.get_category_name(), "Gathering")
	assert_eq(_combat.get_category_name(), "Combat")


func test_skill_serialization() -> void:
	var data := _smithing.to_dict()
	var restored := SkillDefinition.from_dict(data)

	assert_eq(restored.id, "smithing")
	assert_eq(restored.name, "Smithing")
	assert_eq(restored.category, SkillDefinition.SkillCategory.CRAFTING)
	assert_eq(restored.max_level, 100)
	assert_eq(restored.base_xp, 100)


# ====================
# PlayerSkills Registration Tests
# ====================

func test_register_skill() -> void:
	_player_skills.register_skill(_smithing)

	assert_eq(_player_skills.get_skill_count(), 1)
	assert_eq(_player_skills.get_skill_definition("smithing"), _smithing)


func test_register_multiple_skills() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_mining)
	_player_skills.register_skill(_combat)

	assert_eq(_player_skills.get_skill_count(), 3)


func test_get_all_skill_definitions() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_mining)

	var all := _player_skills.get_all_skill_definitions()
	assert_eq(all.size(), 2)


func test_get_skills_by_category() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_mining)
	_player_skills.register_skill(_combat)

	var crafting := _player_skills.get_skills_by_category(SkillDefinition.SkillCategory.CRAFTING)
	assert_eq(crafting.size(), 1)
	assert_eq(crafting[0].id, "smithing")


# ====================
# Skill Unlock Tests
# ====================

func test_skill_unlocked_by_default() -> void:
	_player_skills.register_skill(_smithing)

	assert_true(_player_skills.is_skill_unlocked("smithing"))


func test_skill_locked_by_default() -> void:
	_player_skills.register_skill(_advanced_smithing)

	assert_false(_player_skills.is_skill_unlocked("advanced_smithing"))


func test_unlock_skill() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_advanced_smithing)

	# Need smithing level 25 first
	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(25))

	var success := _player_skills.unlock_skill("advanced_smithing")
	assert_true(success)
	assert_true(_player_skills.is_skill_unlocked("advanced_smithing"))


func test_unlock_skill_prerequisite_not_met() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_advanced_smithing)

	# Smithing only at level 10
	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(10))

	var success := _player_skills.unlock_skill("advanced_smithing")
	assert_false(success)
	assert_false(_player_skills.is_skill_unlocked("advanced_smithing"))


func test_unlock_skill_emits_signal() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_advanced_smithing)

	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(25))

	watch_signals(_player_skills)

	_player_skills.unlock_skill("advanced_smithing")

	assert_signal_emitted(_player_skills, "skill_unlocked")


# ====================
# XP and Leveling Tests
# ====================

func test_initial_level() -> void:
	_player_skills.register_skill(_smithing)

	assert_eq(_player_skills.get_skill_level("smithing"), 1)
	assert_eq(_player_skills.get_skill_xp("smithing"), 0)


func test_add_xp() -> void:
	_player_skills.register_skill(_smithing)

	_player_skills.add_xp("smithing", 100)

	assert_eq(_player_skills.get_skill_xp("smithing"), 100)


func test_add_xp_level_up() -> void:
	_player_skills.register_skill(_smithing)

	# Need 282 XP for level 2
	var leveled := _player_skills.add_xp("smithing", 300)

	assert_true(leveled)
	assert_eq(_player_skills.get_skill_level("smithing"), 2)


func test_add_xp_multiple_levels() -> void:
	_player_skills.register_skill(_smithing)

	# Add enough for level 5
	var xp_for_5 := _smithing.get_total_xp_for_level(5)
	_player_skills.add_xp("smithing", xp_for_5 + 100)

	assert_eq(_player_skills.get_skill_level("smithing"), 5)


func test_add_xp_locked_skill() -> void:
	_player_skills.register_skill(_advanced_smithing)

	var success := _player_skills.add_xp("advanced_smithing", 1000)

	assert_false(success)
	assert_eq(_player_skills.get_skill_xp("advanced_smithing"), 0)


func test_add_xp_emits_signal() -> void:
	_player_skills.register_skill(_smithing)

	watch_signals(_player_skills)

	_player_skills.add_xp("smithing", 50)

	assert_signal_emitted(_player_skills, "xp_gained")


func test_level_up_emits_signal() -> void:
	_player_skills.register_skill(_smithing)

	watch_signals(_player_skills)

	_player_skills.add_xp("smithing", 300)  # Enough for level 2

	assert_signal_emitted(_player_skills, "level_up")


func test_set_skill_xp() -> void:
	_player_skills.register_skill(_smithing)

	_player_skills.set_skill_xp("smithing", 1000)

	assert_eq(_player_skills.get_skill_xp("smithing"), 1000)
	assert_true(_player_skills.get_skill_level("smithing") > 1)


func test_max_level() -> void:
	_player_skills.register_skill(_combat)  # max_level = 50

	var huge_xp := _combat.get_total_xp_for_level(50) + 100000
	_player_skills.set_skill_xp("combat", huge_xp)

	assert_eq(_player_skills.get_skill_level("combat"), 50)
	assert_true(_player_skills.is_max_level("combat"))


func test_is_not_max_level() -> void:
	_player_skills.register_skill(_smithing)

	_player_skills.add_xp("smithing", 100)

	assert_false(_player_skills.is_max_level("smithing"))


# ====================
# Progress and Remaining XP Tests
# ====================

func test_get_level_progress() -> void:
	_player_skills.register_skill(_smithing)

	# Half way to level 2
	_player_skills.add_xp("smithing", 141)

	var progress := _player_skills.get_level_progress("smithing")
	assert_almost_eq(progress, 0.5, 0.01)


func test_get_xp_for_next_level() -> void:
	_player_skills.register_skill(_smithing)

	var xp_needed := _player_skills.get_xp_for_next_level("smithing")
	assert_eq(xp_needed, _smithing.get_xp_for_level(2))


func test_get_xp_remaining() -> void:
	_player_skills.register_skill(_smithing)

	_player_skills.add_xp("smithing", 100)

	var remaining := _player_skills.get_xp_remaining("smithing")
	assert_eq(remaining, 282 - 100)  # 182 more needed for level 2


# ====================
# Bonus Tests
# ====================

func test_get_skill_bonus() -> void:
	_player_skills.register_skill(_smithing)

	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(10))

	var bonus := _player_skills.get_skill_bonus("smithing", "craft_quality")
	assert_eq(bonus, 0.1)  # 10 * 0.01


func test_get_total_bonus() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_combat)

	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(10))
	_player_skills.set_skill_xp("combat", _combat.get_total_xp_for_level(10))

	# Only combat has "damage" bonus
	var damage := _player_skills.get_total_bonus("damage")
	assert_eq(damage, 10.0)  # 10 * 1.0


# ====================
# Level Dictionary Tests
# ====================

func test_get_all_levels() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_mining)

	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(5))
	_player_skills.set_skill_xp("mining", _mining.get_total_xp_for_level(3))

	var levels := _player_skills.get_all_levels()

	assert_eq(levels["smithing"], 5)
	assert_eq(levels["mining"], 3)


func test_get_all_levels_excludes_locked() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_advanced_smithing)

	var levels := _player_skills.get_all_levels()

	assert_true(levels.has("smithing"))
	assert_false(levels.has("advanced_smithing"))


func test_get_unlocked_skills() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_mining)
	_player_skills.register_skill(_advanced_smithing)

	var unlocked := _player_skills.get_unlocked_skills()

	assert_eq(unlocked.size(), 2)
	assert_true("smithing" in unlocked)
	assert_true("mining" in unlocked)
	assert_false("advanced_smithing" in unlocked)


func test_get_total_level() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_mining)

	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(5))
	_player_skills.set_skill_xp("mining", _mining.get_total_xp_for_level(3))

	assert_eq(_player_skills.get_total_level(), 8)  # 5 + 3


# ====================
# Serialization Tests
# ====================

func test_player_skills_serialization() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_mining)
	_player_skills.register_skill(_advanced_smithing)

	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(25))
	_player_skills.set_skill_xp("mining", 500)
	_player_skills.unlock_skill("advanced_smithing")
	_player_skills.add_xp("advanced_smithing", 100)

	var data := _player_skills.to_dict()

	# Create new player skills and restore
	var restored := PlayerSkills.new()
	restored.register_skill(_smithing)
	restored.register_skill(_mining)
	restored.register_skill(_advanced_smithing)
	restored.from_dict(data)

	assert_eq(restored.get_skill_level("smithing"), 25)
	assert_eq(restored.get_skill_xp("mining"), 500)
	assert_true(restored.is_skill_unlocked("advanced_smithing"))
	assert_eq(restored.get_skill_xp("advanced_smithing"), 100)


func test_clear_player_skills() -> void:
	_player_skills.register_skill(_smithing)
	_player_skills.register_skill(_advanced_smithing)

	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(25))
	_player_skills.unlock_skill("advanced_smithing")

	_player_skills.clear()

	assert_eq(_player_skills.get_skill_level("smithing"), 1)
	assert_eq(_player_skills.get_skill_xp("smithing"), 0)
	assert_false(_player_skills.is_skill_unlocked("advanced_smithing"))


# ====================
# Integration with Crafting Tests
# ====================

func test_skills_integrate_with_crafting() -> void:
	# This tests that PlayerSkills.get_all_levels() returns the format
	# expected by CraftingSystem.can_craft()
	_player_skills.register_skill(_smithing)
	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(10))

	var levels := _player_skills.get_all_levels()

	# Format should be {skill_id: level}
	assert_true(levels is Dictionary)
	assert_true(levels.has("smithing"))
	assert_eq(levels["smithing"], 10)


func test_skill_bonus_for_crafting_quality() -> void:
	# Test that skills provide bonuses that could affect craft quality
	_player_skills.register_skill(_smithing)
	_player_skills.set_skill_xp("smithing", _smithing.get_total_xp_for_level(50))

	var quality_bonus := _player_skills.get_skill_bonus("smithing", "craft_quality")
	assert_eq(quality_bonus, 0.5)  # 50 * 0.01 = 0.5
