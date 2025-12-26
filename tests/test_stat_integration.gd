extends GutTest
## Tests for complete stat integration (Priority 1).
## Tests enchantment/gem bonuses on items and skill/set bonuses on player stats.


# =============================================================================
# Test Fixtures
# =============================================================================

var _item_registry: ItemRegistry
var _enchant_registry: EnchantmentRegistry
var _set_registry: EquipmentSet.Registry
var _player_skills: PlayerSkills

# Item definitions
var _sword_def: ItemDefinition
var _helmet_def: ItemDefinition
var _chest_def: ItemDefinition
var _gem_def: ItemDefinition

# Enchantment definitions
var _flame_ench: Enchantment
var _frost_ench: Enchantment

# Skill definitions
var _combat_skill: SkillDefinition

# Equipment set
var _iron_set: EquipmentSet


func before_each() -> void:
	_setup_registries()
	_setup_items()
	_setup_enchantments()
	_setup_gems()
	_setup_skills()
	_setup_equipment_sets()


func _setup_registries() -> void:
	_item_registry = ItemRegistry.new()
	_enchant_registry = EnchantmentRegistry.new()
	_set_registry = EquipmentSet.Registry.new()
	_player_skills = PlayerSkills.new()


func _setup_items() -> void:
	# Sword with base stats
	_sword_def = ItemDefinition.new()
	_sword_def.id = "iron_sword"
	_sword_def.name = "Iron Sword"
	_sword_def.type = ItemEnums.ItemType.WEAPON
	_sword_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_sword_def.tier = 2
	_sword_def.base_durability = 100
	_sword_def.enchant_slots = 2
	_sword_def.socket_count = 1
	_sword_def.set_id = "iron_set"
	_sword_def.base_stats = {
		ItemEnums.StatType.STRENGTH: 10.0,
		ItemEnums.StatType.ATTACK_SPEED: 0.1,
	}
	_item_registry.register_item(_sword_def)

	# Helmet with base stats
	_helmet_def = ItemDefinition.new()
	_helmet_def.id = "iron_helmet"
	_helmet_def.name = "Iron Helmet"
	_helmet_def.type = ItemEnums.ItemType.ARMOR
	_helmet_def.equip_slot = ItemEnums.EquipSlot.HEAD
	_helmet_def.tier = 2
	_helmet_def.base_durability = 150
	_helmet_def.enchant_slots = 1
	_helmet_def.socket_count = 1
	_helmet_def.set_id = "iron_set"
	_helmet_def.base_stats = {
		ItemEnums.StatType.FORTITUDE: 8.0,
		ItemEnums.StatType.MAX_HP: 20.0,
	}
	_item_registry.register_item(_helmet_def)

	# Chest with base stats
	_chest_def = ItemDefinition.new()
	_chest_def.id = "iron_chest"
	_chest_def.name = "Iron Chestplate"
	_chest_def.type = ItemEnums.ItemType.ARMOR
	_chest_def.equip_slot = ItemEnums.EquipSlot.CHEST
	_chest_def.tier = 2
	_chest_def.base_durability = 200
	_chest_def.set_id = "iron_set"
	_chest_def.base_stats = {
		ItemEnums.StatType.FORTITUDE: 12.0,
		ItemEnums.StatType.MAX_HP: 30.0,
	}
	_item_registry.register_item(_chest_def)


func _setup_enchantments() -> void:
	# Flame enchantment - adds strength
	_flame_ench = Enchantment.new()
	_flame_ench.id = "flame"
	_flame_ench.name = "Flame"
	_flame_ench.max_level = 5
	_flame_ench.stat_bonuses = {
		ItemEnums.StatType.STRENGTH: 2.0,  # 2 per level
	}
	_enchant_registry.register(_flame_ench)

	# Frost enchantment - adds fortitude and cold resist
	_frost_ench = Enchantment.new()
	_frost_ench.id = "frost"
	_frost_ench.name = "Frost"
	_frost_ench.max_level = 3
	_frost_ench.stat_bonuses = {
		ItemEnums.StatType.FORTITUDE: 3.0,  # 3 per level
		ItemEnums.StatType.COLD_RESIST: 0.05,  # 5% per level
	}
	_enchant_registry.register(_frost_ench)


func _setup_gems() -> void:
	# Ruby gem - adds crit damage
	_gem_def = ItemDefinition.new()
	_gem_def.id = "ruby_gem"
	_gem_def.name = "Ruby"
	_gem_def.type = ItemEnums.ItemType.GEM
	_gem_def.max_stack = 99
	_gem_def.base_stats = {
		ItemEnums.StatType.CRIT_DAMAGE: 0.1,
		ItemEnums.StatType.STRENGTH: 3.0,
	}
	_item_registry.register_item(_gem_def)


func _setup_skills() -> void:
	# Combat skill with damage and crit bonuses
	_combat_skill = SkillDefinition.new("combat", "Combat")
	_combat_skill.category = SkillDefinition.SkillCategory.COMBAT
	_combat_skill.max_level = 100
	_combat_skill.base_xp = 100
	_combat_skill.xp_exponent = 1.5
	_combat_skill.unlocked_by_default = true
	_combat_skill.level_bonuses = {
		"damage": 0.5,       # Maps to STRENGTH, 0.5 per level
		"crit_chance": 0.002,  # Maps to CRIT_CHANCE, 0.2% per level
	}
	_player_skills.register_skill(_combat_skill)


func _setup_equipment_sets() -> void:
	# Iron set with 2-piece and 3-piece bonuses
	_iron_set = EquipmentSet.new()
	_iron_set.id = "iron_set"
	_iron_set.name = "Iron Set"
	_iron_set.item_ids = ["iron_sword", "iron_helmet", "iron_chest"]
	_iron_set.bonuses = {
		2: {
			ItemEnums.StatType.FORTITUDE: 5.0,
			ItemEnums.StatType.MAX_HP: 10.0,
		},
		3: {
			ItemEnums.StatType.STRENGTH: 8.0,
			ItemEnums.StatType.ATTACK_SPEED: 0.15,
		},
	}
	_set_registry.register(_iron_set)


# =============================================================================
# ItemInstance Enchantment Tests
# =============================================================================

func test_item_stats_without_registry() -> void:
	# Without registry, enchantments should not affect stats
	var sword := ItemInstance.create(_sword_def)
	sword.add_enchantment("flame", 3)

	var stats := sword.get_effective_stats()

	# Should only have base stats (quality = 1.0)
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 10.0)
	assert_eq(stats[ItemEnums.StatType.ATTACK_SPEED], 0.1)
	assert_false(stats.has(ItemEnums.StatType.FORTITUDE))


func test_item_stats_with_single_enchantment() -> void:
	var sword := ItemInstance.create(_sword_def)
	sword.set_enchantment_registry(_enchant_registry)
	sword.add_enchantment("flame", 3)  # Level 3 = +6 strength

	var stats := sword.get_effective_stats()

	# Base (10) + Enchantment (3 * 2 = 6) = 16
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 16.0)
	assert_eq(stats[ItemEnums.StatType.ATTACK_SPEED], 0.1)


func test_item_stats_with_multiple_enchantments() -> void:
	var sword := ItemInstance.create(_sword_def)
	sword.set_enchantment_registry(_enchant_registry)
	sword.add_enchantment("flame", 2)  # +4 strength
	sword.add_enchantment("frost", 2)  # +6 fortitude, +10% cold resist

	var stats := sword.get_effective_stats()

	# Base (10) + Flame (2 * 2 = 4) = 14
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 14.0)
	# Frost only: 2 * 3 = 6
	assert_eq(stats[ItemEnums.StatType.FORTITUDE], 6.0)
	# Frost cold resist: 2 * 0.05 = 0.1
	assert_eq(stats[ItemEnums.StatType.COLD_RESIST], 0.1)


func test_item_stats_with_quality_and_enchantment() -> void:
	var sword := ItemInstance.create(_sword_def, 1.2)  # 120% quality
	sword.set_enchantment_registry(_enchant_registry)
	sword.add_enchantment("flame", 5)  # +10 strength

	var stats := sword.get_effective_stats()

	# Base (10 * 1.2 = 12) + Enchantment (5 * 2 = 10) = 22
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 22.0)
	# Base (0.1 * 1.2 = 0.12)
	assert_almost_eq(stats[ItemEnums.StatType.ATTACK_SPEED], 0.12, 0.001)


func test_item_stats_with_unknown_enchantment() -> void:
	var sword := ItemInstance.create(_sword_def)
	sword.set_enchantment_registry(_enchant_registry)
	sword.add_enchantment("nonexistent", 3)

	var stats := sword.get_effective_stats()

	# Should gracefully handle unknown enchantment - just base stats
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 10.0)


# =============================================================================
# ItemInstance Gem Tests
# =============================================================================

func test_item_stats_with_gem() -> void:
	var sword := ItemInstance.create(_sword_def)
	sword.set_item_registry(_item_registry)
	sword.add_gem("ruby_gem")

	var stats := sword.get_effective_stats()

	# Base (10) + Gem (3) = 13
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 13.0)
	# Gem crit damage: 0.1
	assert_eq(stats[ItemEnums.StatType.CRIT_DAMAGE], 0.1)


func test_item_stats_with_multiple_gems() -> void:
	# Create helmet with 2 sockets for this test
	var helmet_2_socket := ItemDefinition.new()
	helmet_2_socket.id = "test_helmet"
	helmet_2_socket.type = ItemEnums.ItemType.ARMOR
	helmet_2_socket.equip_slot = ItemEnums.EquipSlot.HEAD
	helmet_2_socket.socket_count = 2
	helmet_2_socket.base_stats = {
		ItemEnums.StatType.FORTITUDE: 5.0,
	}
	_item_registry.register_item(helmet_2_socket)

	var helmet := ItemInstance.create(helmet_2_socket)
	helmet.set_item_registry(_item_registry)
	helmet.add_gem("ruby_gem")
	helmet.add_gem("ruby_gem")

	var stats := helmet.get_effective_stats()

	# Base (5) fortitude
	assert_eq(stats[ItemEnums.StatType.FORTITUDE], 5.0)
	# 2x Ruby strength: 3 + 3 = 6
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 6.0)
	# 2x Ruby crit damage: 0.1 + 0.1 = 0.2
	assert_eq(stats[ItemEnums.StatType.CRIT_DAMAGE], 0.2)


func test_item_stats_with_unknown_gem() -> void:
	var sword := ItemInstance.create(_sword_def)
	sword.set_item_registry(_item_registry)
	sword.add_gem("nonexistent_gem")

	var stats := sword.get_effective_stats()

	# Should gracefully handle unknown gem - just base stats
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 10.0)


func test_item_stats_non_gem_item_in_socket() -> void:
	# If somehow a non-gem item ID is in socketed_gems, it should be ignored
	var sword := ItemInstance.create(_sword_def)
	sword.set_item_registry(_item_registry)
	sword.socketed_gems.append("iron_sword")  # Not a gem type

	var stats := sword.get_effective_stats()

	# Should ignore non-gem items - just base stats
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 10.0)


# =============================================================================
# ItemInstance Combined Tests
# =============================================================================

func test_item_stats_with_enchantment_and_gem() -> void:
	var sword := ItemInstance.create(_sword_def)
	sword.set_registries(_enchant_registry, _item_registry)
	sword.add_enchantment("flame", 3)  # +6 strength
	sword.add_gem("ruby_gem")  # +3 strength, +0.1 crit damage

	var stats := sword.get_effective_stats()

	# Base (10) + Enchantment (6) + Gem (3) = 19
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 19.0)
	# Gem crit damage: 0.1
	assert_eq(stats[ItemEnums.StatType.CRIT_DAMAGE], 0.1)


func test_item_stats_with_quality_enchantment_and_gem() -> void:
	var sword := ItemInstance.create(_sword_def, 0.8)  # 80% quality
	sword.set_registries(_enchant_registry, _item_registry)
	sword.add_enchantment("flame", 2)  # +4 strength
	sword.add_gem("ruby_gem")  # +3 strength

	var stats := sword.get_effective_stats()

	# Base (10 * 0.8 = 8) + Enchantment (4) + Gem (3) = 15
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 15.0)


# =============================================================================
# PlayerStats Skill Bonus Tests
# =============================================================================

func test_player_stats_without_skills() -> void:
	var stats := PlayerStats.new()

	# Should just have base stats
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 10.0)
	assert_eq(stats.get_stat(ItemEnums.StatType.CRIT_CHANCE), 0.05)


func test_player_stats_with_skill_bonuses() -> void:
	var stats := PlayerStats.new()
	stats.set_player_skills(_player_skills)

	# Level up combat skill to level 10
	_player_skills.set_skill_xp("combat", _combat_skill.get_total_xp_for_level(10))

	stats.recalculate()

	# Base strength (10) + combat damage bonus (10 * 0.5 = 5) = 15
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 15.0)

	# Base crit (0.05) + combat crit bonus (10 * 0.002 = 0.02) = 0.07
	assert_almost_eq(stats.get_stat(ItemEnums.StatType.CRIT_CHANCE), 0.07, 0.001)


func test_player_stats_skill_level_change_updates_stats() -> void:
	var stats := PlayerStats.new()
	stats.set_player_skills(_player_skills)

	watch_signals(stats)

	# Level up combat skill
	_player_skills.add_xp("combat", 1000)

	# Should emit stats_changed signal
	assert_signal_emitted(stats, "stats_changed")


func test_player_stats_locked_skills_ignored() -> void:
	# Create a locked skill
	var locked_skill := SkillDefinition.new("advanced_combat", "Advanced Combat")
	locked_skill.unlocked_by_default = false
	locked_skill.level_bonuses = {"damage": 10.0}
	_player_skills.register_skill(locked_skill)

	var stats := PlayerStats.new()
	stats.set_player_skills(_player_skills)

	# Locked skill should not contribute
	# Only combat skill at level 1 contributes: 1 * 0.5 = 0.5
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 10.5)


# =============================================================================
# PlayerStats Set Bonus Tests
# =============================================================================

func test_player_stats_without_set_registry() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	var helmet := ItemInstance.create(_helmet_def)
	equipment.equip(sword)
	equipment.equip(helmet)

	var stats := PlayerStats.new(equipment)

	# Without set registry, only equipment stats should apply
	# Base strength (10) + sword (10) = 20
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 20.0)


func test_player_stats_with_2_piece_set_bonus() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	var helmet := ItemInstance.create(_helmet_def)
	equipment.equip(sword)
	equipment.equip(helmet)

	var stats := PlayerStats.new(equipment)
	stats.set_set_registry(_set_registry)

	# Base strength (10) + sword (10) = 20 (no set bonus for strength at 2pc)
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 20.0)

	# Base fortitude (10) + helmet (8) + 2pc bonus (5) = 23
	assert_eq(stats.get_stat(ItemEnums.StatType.FORTITUDE), 23.0)

	# Base HP (100) + helmet (20) + 2pc bonus (10) = 130
	assert_eq(stats.get_stat(ItemEnums.StatType.MAX_HP), 130.0)


func test_player_stats_with_3_piece_set_bonus() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	var helmet := ItemInstance.create(_helmet_def)
	var chest := ItemInstance.create(_chest_def)
	equipment.equip(sword)
	equipment.equip(helmet)
	equipment.equip(chest)

	var stats := PlayerStats.new(equipment)
	stats.set_set_registry(_set_registry)

	# Base (10) + sword (10) + 3pc bonus (8) = 28
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 28.0)

	# Base (10) + helmet (8) + chest (12) + 2pc bonus (5) = 35
	assert_eq(stats.get_stat(ItemEnums.StatType.FORTITUDE), 35.0)

	# Base attack speed (1.0) + sword (0.1) + 3pc bonus (0.15) = 1.25
	assert_almost_eq(stats.get_stat(ItemEnums.StatType.ATTACK_SPEED), 1.25, 0.001)


func test_player_stats_set_bonus_updates_on_equipment_change() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	equipment.equip(sword)

	var stats := PlayerStats.new(equipment)
	stats.set_set_registry(_set_registry)

	# 1 piece - no set bonus
	var initial_fortitude := stats.get_stat(ItemEnums.StatType.FORTITUDE)

	# Add second piece
	var helmet := ItemInstance.create(_helmet_def)
	equipment.equip(helmet)

	# Should now have 2pc bonus
	var new_fortitude := stats.get_stat(ItemEnums.StatType.FORTITUDE)
	assert_true(new_fortitude > initial_fortitude)


# =============================================================================
# PlayerStats Combined Integration Tests
# =============================================================================

func test_player_stats_full_integration() -> void:
	# Set up equipment with enchantments and gems
	var equipment := EquipmentSlots.new()

	var sword := ItemInstance.create(_sword_def)
	sword.set_registries(_enchant_registry, _item_registry)
	sword.add_enchantment("flame", 3)  # +6 strength
	sword.add_gem("ruby_gem")  # +3 strength, +0.1 crit damage

	var helmet := ItemInstance.create(_helmet_def)
	helmet.set_registries(_enchant_registry, _item_registry)
	helmet.add_enchantment("frost", 2)  # +6 fortitude, +10% cold resist

	equipment.equip(sword)
	equipment.equip(helmet)

	# Set up player stats with all bonuses
	var stats := PlayerStats.new(equipment)
	stats.set_set_registry(_set_registry)
	stats.set_player_skills(_player_skills)

	# Level up combat skill to level 20
	_player_skills.set_skill_xp("combat", _combat_skill.get_total_xp_for_level(20))

	stats.recalculate()

	# Strength calculation:
	# Base (10) + sword base (10) + flame (6) + ruby gem (3) + combat skill (20 * 0.5 = 10)
	# = 39
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 39.0)

	# Fortitude calculation:
	# Base (10) + helmet base (8) + frost (6) + 2pc set bonus (5) = 29
	assert_eq(stats.get_stat(ItemEnums.StatType.FORTITUDE), 29.0)

	# Crit damage calculation:
	# Base (1.5) + ruby gem (0.1) = 1.6
	assert_almost_eq(stats.get_stat(ItemEnums.StatType.CRIT_DAMAGE), 1.6, 0.001)

	# Cold resist calculation:
	# Base (0) + frost (0.1) = 0.1
	assert_eq(stats.get_stat(ItemEnums.StatType.COLD_RESIST), 0.1)


func test_player_stats_respects_stat_limits() -> void:
	# Create an extreme enchantment that would exceed crit chance cap
	var op_ench := Enchantment.new()
	op_ench.id = "overpowered"
	op_ench.name = "Overpowered"
	op_ench.max_level = 10
	op_ench.stat_bonuses = {
		ItemEnums.StatType.CRIT_CHANCE: 0.5,  # 50% per level!
	}
	_enchant_registry.register(op_ench)

	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	sword.set_enchantment_registry(_enchant_registry)
	sword.add_enchantment("overpowered", 5)  # +250% crit chance

	equipment.equip(sword)

	var stats := PlayerStats.new(equipment)

	# Crit chance should be capped at 1.0 (100%)
	assert_eq(stats.get_stat(ItemEnums.StatType.CRIT_CHANCE), 1.0)


func test_backwards_compatibility_no_registries() -> void:
	# Ensure existing code without registries still works
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	equipment.equip(sword)

	var stats := PlayerStats.new(equipment)

	# Should work with just base stats from equipment
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 20.0)  # Base 10 + sword 10
	assert_eq(stats.get_max_hp(), 100.0)  # Base only
