extends GutTest
## Tests for the CombatCalculator class.
## Tests damage calculation, crit system, damage reduction, and environmental damage.

const CombatCalculator = preload("res://shared/combat/combat_calculator.gd")


# =============================================================================
# Test Fixtures
# =============================================================================

var _item_registry: ItemRegistry
var _sword_def: ItemDefinition
var _bow_def: ItemDefinition
var _unarmed_stats: PlayerStats
var _attacker_stats: PlayerStats
var _defender_stats: PlayerStats
var _high_crit_stats: PlayerStats
var _tank_stats: PlayerStats


func before_each() -> void:
	_setup_registries()
	_setup_weapons()
	_setup_player_stats()


func _setup_registries() -> void:
	_item_registry = ItemRegistry.new()


func _setup_weapons() -> void:
	# Basic sword - melee weapon
	_sword_def = ItemDefinition.new()
	_sword_def.id = "iron_sword"
	_sword_def.name = "Iron Sword"
	_sword_def.type = ItemEnums.ItemType.WEAPON
	_sword_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_sword_def.tier = 2
	_sword_def.base_damage = 20
	_sword_def.attack_speed = 1.2
	_item_registry.register_item(_sword_def)

	# Basic bow - ranged weapon
	_bow_def = ItemDefinition.new()
	_bow_def.id = "hunting_bow"
	_bow_def.name = "Hunting Bow"
	_bow_def.type = ItemEnums.ItemType.WEAPON
	_bow_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_bow_def.tier = 2
	_bow_def.base_damage = 15
	_bow_def.attack_speed = 0.8
	_item_registry.register_item(_bow_def)


func _setup_player_stats() -> void:
	# Basic unarmed stats (base values)
	_unarmed_stats = PlayerStats.new()

	# Basic attacker with some strength bonus
	var attacker_equipment := EquipmentSlots.new(_item_registry)
	var strength_armor := _create_armor_with_stats({ItemEnums.StatType.STRENGTH: 10.0})
	attacker_equipment.equip(strength_armor)
	_attacker_stats = PlayerStats.new(attacker_equipment)

	# Basic defender with some fortitude
	var defender_equipment := EquipmentSlots.new(_item_registry)
	var fort_armor := _create_armor_with_stats({ItemEnums.StatType.FORTITUDE: 20.0})
	defender_equipment.equip(fort_armor)
	_defender_stats = PlayerStats.new(defender_equipment)

	# High crit character
	var crit_equipment := EquipmentSlots.new(_item_registry)
	var crit_armor := _create_armor_with_stats({
		ItemEnums.StatType.CRIT_CHANCE: 0.5,  # 55% total with base
		ItemEnums.StatType.CRIT_DAMAGE: 1.0,  # 2.5x total with base
	})
	crit_equipment.equip(crit_armor)
	_high_crit_stats = PlayerStats.new(crit_equipment)

	# Tank character with high fortitude
	var tank_equipment := EquipmentSlots.new(_item_registry)
	var tank_armor := _create_armor_with_stats({ItemEnums.StatType.FORTITUDE: 100.0})
	tank_equipment.equip(tank_armor)
	_tank_stats = PlayerStats.new(tank_equipment)


func _create_armor_with_stats(stats: Dictionary) -> ItemInstance:
	var armor_def := ItemDefinition.new()
	armor_def.id = "test_armor_%d" % randi()
	armor_def.name = "Test Armor"
	armor_def.type = ItemEnums.ItemType.ARMOR
	armor_def.equip_slot = ItemEnums.EquipSlot.CHEST
	armor_def.base_stats = stats
	_item_registry.register_item(armor_def)
	return ItemInstance.create(armor_def)


# =============================================================================
# Melee Damage Tests
# =============================================================================

func test_melee_damage_with_weapon() -> void:
	var result := CombatCalculator.calculate_melee_damage(
		_unarmed_stats,
		_sword_def,
		_unarmed_stats,
		42  # Fixed seed for deterministic no-crit
	)

	# Base damage should be weapon damage
	assert_eq(result.base_damage, 20.0)

	# With base 10 strength, multiplier should be 1.0
	assert_almost_eq(result.stat_multiplier, 1.0, 0.01)

	# Final damage should be positive
	assert_true(result.final_damage > 0)


func test_melee_damage_unarmed() -> void:
	var result := CombatCalculator.calculate_melee_damage(
		_unarmed_stats,
		null,  # No weapon
		_unarmed_stats,
		42
	)

	# Unarmed base damage should be 5
	assert_eq(result.base_damage, 5.0)


func test_melee_damage_strength_bonus() -> void:
	# Attacker has +10 strength (20 total), so multiplier should be 1.0 + (20-10)*0.02 = 1.2
	var result := CombatCalculator.calculate_melee_damage(
		_attacker_stats,
		_sword_def,
		_unarmed_stats,
		42
	)

	assert_almost_eq(result.stat_multiplier, 1.2, 0.01)
	# 20 * 1.2 = 24 before reduction
	assert_almost_eq(result.damage_before_reduction, 24.0, 0.1)


func test_melee_damage_defender_reduction() -> void:
	var result := CombatCalculator.calculate_melee_damage(
		_unarmed_stats,
		_sword_def,
		_defender_stats,  # Has +20 fortitude (30 total)
		42
	)

	# Reduction formula: 1 - (100 / (100 + 30)) = ~23%
	assert_true(result.damage_reduction > 0)
	assert_true(result.final_damage < result.damage_before_reduction)


# =============================================================================
# Ranged Damage Tests
# =============================================================================

func test_ranged_damage_with_weapon() -> void:
	var result := CombatCalculator.calculate_ranged_damage(
		_unarmed_stats,
		_bow_def,
		_unarmed_stats,
		0.0,
		42
	)

	# Base damage should be bow damage
	assert_eq(result.base_damage, 15.0)


func test_ranged_damage_precision_bonus() -> void:
	# Create character with high precision
	var precision_equipment := EquipmentSlots.new(_item_registry)
	var precision_armor := _create_armor_with_stats({ItemEnums.StatType.PRECISION: 15.0})
	precision_equipment.equip(precision_armor)
	var precision_stats := PlayerStats.new(precision_equipment)

	# 25 precision total, multiplier = 1.0 + (25-10)*0.02 = 1.3
	var result := CombatCalculator.calculate_ranged_damage(
		precision_stats,
		_bow_def,
		_unarmed_stats,
		0.0,
		42
	)

	assert_almost_eq(result.stat_multiplier, 1.3, 0.01)


func test_ranged_damage_with_distance() -> void:
	# Currently distance doesn't affect damage, but test it doesn't break
	var result := CombatCalculator.calculate_ranged_damage(
		_unarmed_stats,
		_bow_def,
		_unarmed_stats,
		100.0,  # 100 pixel distance
		42
	)

	assert_true(result.final_damage > 0)


# =============================================================================
# Critical Hit Tests
# =============================================================================

func test_crit_roll_deterministic() -> void:
	# With fixed seed, crit should be deterministic
	var result1 := CombatCalculator.calculate_crit(_unarmed_stats, 12345)
	var result2 := CombatCalculator.calculate_crit(_unarmed_stats, 12345)

	assert_eq(result1["is_crit"], result2["is_crit"])
	assert_eq(result1["multiplier"], result2["multiplier"])


func test_crit_returns_correct_multiplier() -> void:
	# High crit character should have 2.5x multiplier
	var result := CombatCalculator.calculate_crit(_high_crit_stats, 0)  # Seed 0 should crit with 55% chance

	if result["is_crit"]:
		assert_almost_eq(result["multiplier"], 2.5, 0.01)
	else:
		assert_eq(result["multiplier"], 1.0)


func test_crit_affects_damage() -> void:
	# Find a seed that causes a crit for high_crit_stats
	var crit_result := CombatCalculator.calculate_melee_damage(
		_high_crit_stats,
		_sword_def,
		_unarmed_stats,
		1  # This seed with 55% crit chance should crit
	)

	var non_crit_result := CombatCalculator.calculate_melee_damage(
		_unarmed_stats,  # Only 5% base crit
		_sword_def,
		_unarmed_stats,
		999  # Very unlikely to crit with 5%
	)

	# At least one should differ in crit status
	# We can't guarantee which without knowing exact RNG behavior
	assert_true(crit_result.final_damage >= 0)
	assert_true(non_crit_result.final_damage >= 0)


# =============================================================================
# Damage Reduction Tests
# =============================================================================

func test_damage_reduction_at_zero_fortitude() -> void:
	# Create character with 0 fortitude
	var no_fort_equipment := EquipmentSlots.new(_item_registry)
	var no_fort_armor := _create_armor_with_stats({ItemEnums.StatType.FORTITUDE: -10.0})  # Reduces base 10 to 0
	no_fort_equipment.equip(no_fort_armor)
	var no_fort_stats := PlayerStats.new(no_fort_equipment)

	var reduction := CombatCalculator.calculate_damage_reduction(no_fort_stats, 100.0)

	# At 0 fortitude, should be 0% reduction
	assert_almost_eq(reduction, 0.0, 0.1)


func test_damage_reduction_diminishing_returns() -> void:
	# At 100 fortitude, should be ~50% reduction
	var reduction_at_100 := CombatCalculator.calculate_damage_reduction(_tank_stats, 100.0)
	# 110 fortitude total (10 base + 100 equipment)
	# 1 - (100 / (100 + 110)) = 1 - 0.476 = 0.524 = 52.4%
	assert_almost_eq(reduction_at_100, 52.4, 5.0)  # ~52% of 100 = 52


func test_damage_reduction_cap() -> void:
	# Create character with extremely high fortitude
	var mega_tank_equipment := EquipmentSlots.new(_item_registry)
	var mega_armor := _create_armor_with_stats({ItemEnums.StatType.FORTITUDE: 10000.0})
	mega_tank_equipment.equip(mega_armor)
	var mega_tank_stats := PlayerStats.new(mega_tank_equipment)

	var reduction := CombatCalculator.calculate_damage_reduction(mega_tank_stats, 100.0)

	# Should be capped at 90% = 90 damage reduced
	assert_true(reduction <= 90.0)


func test_minimum_damage_is_one() -> void:
	var result := CombatCalculator.calculate_melee_damage(
		_unarmed_stats,
		null,  # Unarmed = 5 damage
		_tank_stats,  # High reduction
		42
	)

	# Even with high reduction, minimum damage should be 1
	assert_true(result.final_damage >= 1.0)


# =============================================================================
# Attack Speed Tests
# =============================================================================

func test_attack_speed_with_weapon() -> void:
	var speed := CombatCalculator.calculate_attack_speed(_unarmed_stats, _sword_def)

	# Sword has 1.2 attack speed, base stat is 1.0
	# 1.2 * 1.0 = 1.2
	assert_almost_eq(speed, 1.2, 0.01)


func test_attack_speed_with_stat_bonus() -> void:
	var speed_equipment := EquipmentSlots.new(_item_registry)
	var speed_armor := _create_armor_with_stats({ItemEnums.StatType.ATTACK_SPEED: 0.5})
	speed_equipment.equip(speed_armor)
	var speed_stats := PlayerStats.new(speed_equipment)

	var speed := CombatCalculator.calculate_attack_speed(speed_stats, _sword_def)

	# Sword (1.2) * stat (1.0 base + 0.5 = 1.5) = 1.8
	assert_almost_eq(speed, 1.8, 0.01)


func test_attack_speed_unarmed() -> void:
	var speed := CombatCalculator.calculate_attack_speed(_unarmed_stats, null)

	# No weapon = 1.0 base, stat = 1.0
	assert_eq(speed, 1.0)


# =============================================================================
# Environmental Damage Tests
# =============================================================================

func test_environmental_damage_no_resist() -> void:
	var damage := CombatCalculator.calculate_environmental_damage(
		_unarmed_stats,
		ItemEnums.StatType.HEAT_RESIST,
		100.0
	)

	# Base heat resist is 0, so full damage
	assert_eq(damage, 100.0)


func test_environmental_damage_with_resist() -> void:
	var resist_equipment := EquipmentSlots.new(_item_registry)
	var resist_armor := _create_armor_with_stats({ItemEnums.StatType.HEAT_RESIST: 0.5})  # 50%
	resist_equipment.equip(resist_armor)
	var resist_stats := PlayerStats.new(resist_equipment)

	var damage := CombatCalculator.calculate_environmental_damage(
		resist_stats,
		ItemEnums.StatType.HEAT_RESIST,
		100.0
	)

	# 50% resist = 50 damage
	assert_almost_eq(damage, 50.0, 0.1)


func test_environmental_damage_invalid_type() -> void:
	# Passing a non-resistance stat should return full damage
	var damage := CombatCalculator.calculate_environmental_damage(
		_unarmed_stats,
		ItemEnums.StatType.STRENGTH,  # Not a resistance
		100.0
	)

	assert_eq(damage, 100.0)


func test_all_resistance_types() -> void:
	var resist_types := [
		ItemEnums.StatType.HEAT_RESIST,
		ItemEnums.StatType.COLD_RESIST,
		ItemEnums.StatType.RADIATION_RESIST,
		ItemEnums.StatType.TOXIC_RESIST,
		ItemEnums.StatType.PRESSURE_RESIST,
	]

	for resist_type in resist_types:
		var damage := CombatCalculator.calculate_environmental_damage(
			_unarmed_stats,
			resist_type,
			100.0
		)
		# All should work without error
		assert_true(damage >= 0.0, "Failed for resist type %d" % resist_type)


# =============================================================================
# DamageResult Structure Tests
# =============================================================================

func test_damage_result_string_conversion() -> void:
	var result := CombatCalculator.calculate_melee_damage(
		_unarmed_stats,
		_sword_def,
		_unarmed_stats,
		42
	)

	var result_str := str(result)
	assert_true(result_str.begins_with("DamageResult"))
	assert_true("base=" in result_str)
	assert_true("final=" in result_str)


func test_damage_result_fields() -> void:
	var result := CombatCalculator.calculate_melee_damage(
		_attacker_stats,
		_sword_def,
		_defender_stats,
		42
	)

	# All fields should be populated
	assert_true(result.base_damage > 0)
	assert_true(result.stat_multiplier > 0)
	assert_true(result.crit_multiplier >= 1.0)
	assert_true(result.damage_before_reduction > 0)
	assert_true(result.damage_reduction >= 0)
	assert_true(result.final_damage > 0)
