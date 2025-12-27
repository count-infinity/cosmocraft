extends GutTest
## Tests for the ToolCalculator class.
## Tests gathering efficiency, durability calculations, and tool modes.

const ToolCalculator = preload("res://shared/combat/tool_calculator.gd")


# =============================================================================
# Test Fixtures
# =============================================================================

var _item_registry: ItemRegistry
var _pickaxe_t1: ItemDefinition
var _pickaxe_t2: ItemDefinition
var _pickaxe_t3: ItemDefinition
var _axe_t2: ItemDefinition
var _base_stats: PlayerStats
var _high_efficiency_stats: PlayerStats
var _high_luck_stats: PlayerStats


func before_each() -> void:
	_setup_registries()
	_setup_tools()
	_setup_player_stats()


func _setup_registries() -> void:
	_item_registry = ItemRegistry.new()


func _setup_tools() -> void:
	# Tier 1 pickaxe
	_pickaxe_t1 = ItemDefinition.new()
	_pickaxe_t1.id = "stone_pickaxe"
	_pickaxe_t1.name = "Stone Pickaxe"
	_pickaxe_t1.type = ItemEnums.ItemType.TOOL
	_pickaxe_t1.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_pickaxe_t1.tier = 1
	_pickaxe_t1.harvest_tier = 1
	_pickaxe_t1.base_durability = 50
	_pickaxe_t1.available_modes = [ItemEnums.ToolMode.STANDARD]
	_item_registry.register_item(_pickaxe_t1)

	# Tier 2 pickaxe with multiple modes
	_pickaxe_t2 = ItemDefinition.new()
	_pickaxe_t2.id = "iron_pickaxe"
	_pickaxe_t2.name = "Iron Pickaxe"
	_pickaxe_t2.type = ItemEnums.ItemType.TOOL
	_pickaxe_t2.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_pickaxe_t2.tier = 2
	_pickaxe_t2.harvest_tier = 2
	_pickaxe_t2.base_durability = 100
	_pickaxe_t2.available_modes = [
		ItemEnums.ToolMode.STANDARD,
		ItemEnums.ToolMode.PRECISION,
		ItemEnums.ToolMode.AREA,
	]
	_item_registry.register_item(_pickaxe_t2)

	# Tier 3 pickaxe with all modes
	_pickaxe_t3 = ItemDefinition.new()
	_pickaxe_t3.id = "steel_pickaxe"
	_pickaxe_t3.name = "Steel Pickaxe"
	_pickaxe_t3.type = ItemEnums.ItemType.TOOL
	_pickaxe_t3.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_pickaxe_t3.tier = 3
	_pickaxe_t3.harvest_tier = 3
	_pickaxe_t3.base_durability = 200
	_pickaxe_t3.available_modes = [
		ItemEnums.ToolMode.STANDARD,
		ItemEnums.ToolMode.PRECISION,
		ItemEnums.ToolMode.AREA,
		ItemEnums.ToolMode.VEIN,
	]
	_item_registry.register_item(_pickaxe_t3)

	# Tier 2 axe (for testing different tool types)
	_axe_t2 = ItemDefinition.new()
	_axe_t2.id = "iron_axe"
	_axe_t2.name = "Iron Axe"
	_axe_t2.type = ItemEnums.ItemType.TOOL
	_axe_t2.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_axe_t2.tier = 2
	_axe_t2.harvest_tier = 2
	_axe_t2.base_durability = 100
	_axe_t2.available_modes = [ItemEnums.ToolMode.STANDARD]
	_item_registry.register_item(_axe_t2)


func _setup_player_stats() -> void:
	# Base stats (efficiency = 10)
	_base_stats = PlayerStats.new()

	# High efficiency character
	var eff_equipment := EquipmentSlots.new(_item_registry)
	var eff_armor := _create_armor_with_stats({ItemEnums.StatType.EFFICIENCY: 20.0})
	eff_equipment.equip(eff_armor)
	_high_efficiency_stats = PlayerStats.new(eff_equipment)

	# High luck character
	var luck_equipment := EquipmentSlots.new(_item_registry)
	var luck_armor := _create_armor_with_stats({ItemEnums.StatType.LUCK: 40.0})
	luck_equipment.equip(luck_armor)
	_high_luck_stats = PlayerStats.new(luck_equipment)


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
# Gathering Efficiency Tests
# =============================================================================

func test_efficiency_with_tool_same_tier() -> void:
	var result := ToolCalculator.calculate_gathering_efficiency(
		_base_stats,
		_pickaxe_t2,
		2  # Same tier as tool
	)

	# Base efficiency should be 1.0
	assert_eq(result.base_efficiency, 1.0)

	# Same tier = no tier bonus/penalty
	assert_eq(result.tool_tier_bonus, 1.0)

	# Base efficiency stat = 10, so multiplier = 1.0
	assert_eq(result.stat_multiplier, 1.0)

	# Total should be 1.0
	assert_eq(result.total_efficiency, 1.0)


func test_efficiency_higher_tier_tool() -> void:
	var result := ToolCalculator.calculate_gathering_efficiency(
		_base_stats,
		_pickaxe_t3,  # Tier 3 tool
		1  # Tier 1 material
	)

	# 2 tiers higher = 20% * 2 = 40% bonus
	assert_almost_eq(result.tool_tier_bonus, 1.4, 0.01)


func test_efficiency_lower_tier_tool() -> void:
	var result := ToolCalculator.calculate_gathering_efficiency(
		_base_stats,
		_pickaxe_t1,  # Tier 1 tool
		2  # Tier 2 material
	)

	# 1 tier lower = 50% penalty
	assert_almost_eq(result.tool_tier_bonus, 0.5, 0.01)


func test_efficiency_bare_hands() -> void:
	var result := ToolCalculator.calculate_gathering_efficiency(
		_base_stats,
		null,  # No tool
		1
	)

	# Bare hands = 50% base efficiency
	assert_eq(result.base_efficiency, 0.5)


func test_efficiency_bare_hands_higher_tier() -> void:
	var result := ToolCalculator.calculate_gathering_efficiency(
		_base_stats,
		null,  # No tool
		2  # Tier 2 material
	)

	# Bare hands can't effectively gather higher tier
	assert_almost_eq(result.tool_tier_bonus, 0.1, 0.01)


func test_efficiency_stat_bonus() -> void:
	# High efficiency player (30 total) = 1.0 + (30-10)*0.02 = 1.4
	var result := ToolCalculator.calculate_gathering_efficiency(
		_high_efficiency_stats,
		_pickaxe_t2,
		2
	)

	assert_almost_eq(result.stat_multiplier, 1.4, 0.01)
	assert_almost_eq(result.total_efficiency, 1.4, 0.01)


func test_efficiency_result_string() -> void:
	var result := ToolCalculator.calculate_gathering_efficiency(
		_base_stats,
		_pickaxe_t2,
		2
	)

	var result_str := str(result)
	assert_true(result_str.begins_with("EfficiencyResult"))
	assert_true("total=" in result_str)


# =============================================================================
# Durability Tests
# =============================================================================

func test_durability_basic_use() -> void:
	var tool_instance := ItemInstance.create(_pickaxe_t2)

	var result := ToolCalculator.calculate_durability_use(
		_base_stats,
		tool_instance,
		1  # Base cost
	)

	assert_eq(result.base_cost, 1)
	assert_eq(result.final_cost, 1)


func test_durability_no_tool() -> void:
	var result := ToolCalculator.calculate_durability_use(
		_base_stats,
		null,  # No tool
		1
	)

	# No tool = no durability cost
	assert_eq(result.final_cost, 0)


func test_durability_efficiency_reduction() -> void:
	var tool_instance := ItemInstance.create(_pickaxe_t2)

	# High efficiency (30) reduces cost: 1.0 - (30-10)*0.01 = 0.8
	var result := ToolCalculator.calculate_durability_use(
		_high_efficiency_stats,
		tool_instance,
		10  # Higher base cost
	)

	# 10 * 0.8 = 8
	assert_eq(result.final_cost, 8)


func test_durability_minimum_one() -> void:
	var tool_instance := ItemInstance.create(_pickaxe_t2)

	# Even with high reduction, minimum should be 1
	var result := ToolCalculator.calculate_durability_use(
		_high_efficiency_stats,
		tool_instance,
		1
	)

	assert_true(result.final_cost >= 1)


func test_durability_indestructible_tool() -> void:
	# Create tool with no durability (indestructible)
	var indestructible_def := ItemDefinition.new()
	indestructible_def.id = "magic_pick"
	indestructible_def.name = "Magic Pickaxe"
	indestructible_def.type = ItemEnums.ItemType.TOOL
	indestructible_def.tier = 5
	indestructible_def.base_durability = 0  # Indestructible
	_item_registry.register_item(indestructible_def)

	var tool_instance := ItemInstance.create(indestructible_def)

	var result := ToolCalculator.calculate_durability_use(
		_base_stats,
		tool_instance,
		5
	)

	# Indestructible = no cost
	assert_eq(result.final_cost, 0)


func test_durability_result_string() -> void:
	var tool_instance := ItemInstance.create(_pickaxe_t2)

	var result := ToolCalculator.calculate_durability_use(
		_base_stats,
		tool_instance,
		1
	)

	var result_str := str(result)
	assert_true(result_str.begins_with("DurabilityResult"))


# =============================================================================
# Tier Check Tests
# =============================================================================

func test_can_harvest_same_tier() -> void:
	assert_true(ToolCalculator.can_harvest_tier(_pickaxe_t2, 2))


func test_can_harvest_lower_tier() -> void:
	assert_true(ToolCalculator.can_harvest_tier(_pickaxe_t3, 1))


func test_cannot_harvest_higher_tier() -> void:
	assert_false(ToolCalculator.can_harvest_tier(_pickaxe_t1, 2))


func test_bare_hands_tier_limit() -> void:
	# Bare hands can only harvest tier 1
	assert_true(ToolCalculator.can_harvest_tier(null, 1))
	assert_false(ToolCalculator.can_harvest_tier(null, 2))


func test_non_tool_cannot_harvest() -> void:
	# Create a weapon (not a tool)
	var sword_def := ItemDefinition.new()
	sword_def.id = "test_sword"
	sword_def.type = ItemEnums.ItemType.WEAPON
	sword_def.harvest_tier = 2  # Has harvest tier but wrong type
	_item_registry.register_item(sword_def)

	assert_false(ToolCalculator.can_harvest_tier(sword_def, 1))


# =============================================================================
# Gather Time Tests
# =============================================================================

func test_gather_time_base() -> void:
	var time := ToolCalculator.calculate_gather_time(
		_base_stats,
		_pickaxe_t2,
		2.0,  # Base time in seconds
		2
	)

	# Efficiency 1.0, so time should be 2.0
	assert_almost_eq(time, 2.0, 0.01)


func test_gather_time_with_efficiency() -> void:
	var time := ToolCalculator.calculate_gather_time(
		_high_efficiency_stats,
		_pickaxe_t2,
		2.0,
		2
	)

	# Efficiency 1.4, so time should be 2.0 / 1.4 = ~1.43
	assert_almost_eq(time, 2.0 / 1.4, 0.01)


func test_gather_time_minimum() -> void:
	# Create extremely efficient character
	var super_eff_equipment := EquipmentSlots.new(_item_registry)
	var super_armor := _create_armor_with_stats({ItemEnums.StatType.EFFICIENCY: 1000.0})
	super_eff_equipment.equip(super_armor)
	var super_stats := PlayerStats.new(super_eff_equipment)

	var time := ToolCalculator.calculate_gather_time(
		super_stats,
		_pickaxe_t3,
		1.0,
		1
	)

	# Should have minimum of 0.1 seconds
	assert_true(time >= 0.1)


# =============================================================================
# Bonus Drops Tests
# =============================================================================

func test_bonus_drops_base_luck() -> void:
	# Base luck (10) = no bonus
	var drops := ToolCalculator.calculate_bonus_drops(_base_stats, 5, 42)
	assert_eq(drops, 5)


func test_bonus_drops_high_luck() -> void:
	# High luck (50) = 40% bonus chance per item
	# With fixed seed, should be deterministic
	var drops1 := ToolCalculator.calculate_bonus_drops(_high_luck_stats, 5, 12345)
	var drops2 := ToolCalculator.calculate_bonus_drops(_high_luck_stats, 5, 12345)

	assert_eq(drops1, drops2)
	assert_true(drops1 >= 5)  # Should be at least base drops


func test_bonus_drops_deterministic() -> void:
	var drops1 := ToolCalculator.calculate_bonus_drops(_high_luck_stats, 10, 99999)
	var drops2 := ToolCalculator.calculate_bonus_drops(_high_luck_stats, 10, 99999)

	assert_eq(drops1, drops2)


# =============================================================================
# Tool Mode Tests
# =============================================================================

func test_mode_standard() -> void:
	var mods := ToolCalculator.get_mode_modifiers(_pickaxe_t2, ItemEnums.ToolMode.STANDARD)

	assert_eq(mods["efficiency_mult"], 1.0)
	assert_eq(mods["durability_mult"], 1.0)
	assert_eq(mods["area"], 1)


func test_mode_precision() -> void:
	var mods := ToolCalculator.get_mode_modifiers(_pickaxe_t2, ItemEnums.ToolMode.PRECISION)

	# Precision: slower but less durability use
	assert_almost_eq(mods["efficiency_mult"], 0.7, 0.01)
	assert_almost_eq(mods["durability_mult"], 0.8, 0.01)
	assert_eq(mods["area"], 1)


func test_mode_area() -> void:
	var mods := ToolCalculator.get_mode_modifiers(_pickaxe_t2, ItemEnums.ToolMode.AREA)

	# Area: hits 3x3 but uses more durability
	assert_almost_eq(mods["efficiency_mult"], 0.8, 0.01)
	assert_almost_eq(mods["durability_mult"], 2.0, 0.01)
	assert_eq(mods["area"], 9)


func test_mode_vein() -> void:
	var mods := ToolCalculator.get_mode_modifiers(_pickaxe_t3, ItemEnums.ToolMode.VEIN)

	# Vein: follows connected blocks
	assert_almost_eq(mods["efficiency_mult"], 0.9, 0.01)
	assert_eq(mods["area"], -1)  # Special marker for vein mining


func test_mode_unavailable() -> void:
	# T1 pickaxe doesn't have AREA mode
	var mods := ToolCalculator.get_mode_modifiers(_pickaxe_t1, ItemEnums.ToolMode.AREA)

	# Should return default values when mode not available
	assert_eq(mods["efficiency_mult"], 1.0)
	assert_eq(mods["durability_mult"], 1.0)


func test_mode_null_tool() -> void:
	var mods := ToolCalculator.get_mode_modifiers(null, ItemEnums.ToolMode.STANDARD)

	# Null tool should return defaults
	assert_eq(mods["efficiency_mult"], 1.0)
	assert_eq(mods["durability_mult"], 1.0)
	assert_eq(mods["area"], 1)
