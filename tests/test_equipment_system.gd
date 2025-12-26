extends GutTest
## Unit tests for the equipment system (Phase 2).


# =============================================================================
# Test Fixtures
# =============================================================================

var _registry: ItemRegistry
var _sword_def: ItemDefinition
var _helmet_def: ItemDefinition
var _ring_def: ItemDefinition
var _ore_def: ItemDefinition
var _iron_material: MaterialDefinition


func before_each() -> void:
	_registry = ItemRegistry.new()

	# Create sword (weapon, main hand)
	_sword_def = ItemDefinition.new()
	_sword_def.id = "iron_sword"
	_sword_def.name = "Iron Sword"
	_sword_def.type = ItemEnums.ItemType.WEAPON
	_sword_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_sword_def.tier = 2
	_sword_def.base_durability = 100
	_sword_def.base_damage = 15
	_sword_def.weight = 3.0
	_sword_def.base_stats = {
		ItemEnums.StatType.STRENGTH: 5.0,
		ItemEnums.StatType.ATTACK_SPEED: 0.1,
	}
	_registry.register_item(_sword_def)

	# Create helmet (armor, head)
	_helmet_def = ItemDefinition.new()
	_helmet_def.id = "iron_helmet"
	_helmet_def.name = "Iron Helmet"
	_helmet_def.type = ItemEnums.ItemType.ARMOR
	_helmet_def.equip_slot = ItemEnums.EquipSlot.HEAD
	_helmet_def.tier = 2
	_helmet_def.base_durability = 150
	_helmet_def.weight = 2.0
	_helmet_def.base_stats = {
		ItemEnums.StatType.FORTITUDE: 8.0,
		ItemEnums.StatType.MAX_HP: 20.0,
	}
	_registry.register_item(_helmet_def)

	# Create ring (accessory)
	_ring_def = ItemDefinition.new()
	_ring_def.id = "gold_ring"
	_ring_def.name = "Gold Ring"
	_ring_def.type = ItemEnums.ItemType.ACCESSORY
	_ring_def.equip_slot = ItemEnums.EquipSlot.ACCESSORY
	_ring_def.tier = 2
	_ring_def.weight = 0.1
	_ring_def.base_stats = {
		ItemEnums.StatType.LUCK: 5.0,
	}
	_registry.register_item(_ring_def)

	# Create ore (non-equippable)
	_ore_def = ItemDefinition.new()
	_ore_def.id = "iron_ore"
	_ore_def.name = "Iron Ore"
	_ore_def.type = ItemEnums.ItemType.MATERIAL
	_ore_def.max_stack = 99
	_registry.register_item(_ore_def)

	# Create material
	_iron_material = MaterialDefinition.new("iron", "Iron", 2)
	_iron_material.category = "metal"
	_registry.register_material(_iron_material)


# =============================================================================
# ItemRegistry Tests
# =============================================================================

func test_registry_register_item() -> void:
	assert_true(_registry.has_item("iron_sword"))
	assert_true(_registry.has_item("iron_helmet"))
	assert_false(_registry.has_item("nonexistent"))


func test_registry_register_material() -> void:
	assert_true(_registry.has_material("iron"))
	assert_false(_registry.has_material("nonexistent"))


func test_registry_get_item() -> void:
	var item := _registry.get_item("iron_sword")
	assert_not_null(item)
	assert_eq(item.id, "iron_sword")
	assert_eq(item.name, "Iron Sword")


func test_registry_get_material() -> void:
	var mat := _registry.get_material("iron")
	assert_not_null(mat)
	assert_eq(mat.id, "iron")
	assert_eq(mat.tier, 2)


func test_registry_get_nonexistent() -> void:
	assert_null(_registry.get_item("nonexistent"))
	assert_null(_registry.get_material("nonexistent"))


func test_registry_get_all_ids() -> void:
	var item_ids := _registry.get_all_item_ids()
	assert_eq(item_ids.size(), 4)
	assert_true("iron_sword" in item_ids)
	assert_true("iron_helmet" in item_ids)

	var mat_ids := _registry.get_all_material_ids()
	assert_eq(mat_ids.size(), 1)
	assert_true("iron" in mat_ids)


func test_registry_get_items_by_type() -> void:
	var weapons := _registry.get_items_by_type(ItemEnums.ItemType.WEAPON)
	assert_eq(weapons.size(), 1)
	assert_eq(weapons[0].id, "iron_sword")

	var armor := _registry.get_items_by_type(ItemEnums.ItemType.ARMOR)
	assert_eq(armor.size(), 1)


func test_registry_get_items_by_slot() -> void:
	var main_hand := _registry.get_items_by_slot(ItemEnums.EquipSlot.MAIN_HAND)
	assert_eq(main_hand.size(), 1)
	assert_eq(main_hand[0].id, "iron_sword")

	var accessories := _registry.get_items_by_slot(ItemEnums.EquipSlot.ACCESSORY)
	assert_eq(accessories.size(), 1)


func test_registry_get_materials_by_tier() -> void:
	var tier2 := _registry.get_materials_by_tier(2)
	assert_eq(tier2.size(), 1)
	assert_eq(tier2[0].id, "iron")

	var tier5 := _registry.get_materials_by_tier(5)
	assert_eq(tier5.size(), 0)


func test_registry_get_materials_by_category() -> void:
	var metals := _registry.get_materials_by_category("metal")
	assert_eq(metals.size(), 1)


func test_registry_counts() -> void:
	assert_eq(_registry.get_item_count(), 4)
	assert_eq(_registry.get_material_count(), 1)


func test_registry_unregister() -> void:
	assert_true(_registry.unregister_item("iron_sword"))
	assert_false(_registry.has_item("iron_sword"))
	assert_eq(_registry.get_item_count(), 3)

	assert_false(_registry.unregister_item("iron_sword"))  # Already removed


func test_registry_clear() -> void:
	_registry.clear()
	assert_eq(_registry.get_item_count(), 0)
	assert_eq(_registry.get_material_count(), 0)


func test_registry_create_item_instance() -> void:
	var instance := _registry.create_item_instance("iron_sword", 1.1)
	assert_not_null(instance)
	assert_eq(instance.definition.id, "iron_sword")
	assert_eq(instance.quality, 1.1)


func test_registry_create_item_stack() -> void:
	var stack := _registry.create_item_stack("iron_ore", 50)
	assert_not_null(stack)
	assert_eq(stack.count, 50)
	assert_eq(stack.item.definition.id, "iron_ore")


func test_registry_create_nonexistent() -> void:
	assert_null(_registry.create_item_instance("nonexistent"))
	assert_null(_registry.create_item_stack("nonexistent"))


# =============================================================================
# EquipmentSlots Tests
# =============================================================================

func test_equipment_initial_empty() -> void:
	var equipment := EquipmentSlots.new()
	assert_false(equipment.is_slot_occupied(ItemEnums.EquipSlot.HEAD))
	assert_false(equipment.is_slot_occupied(ItemEnums.EquipSlot.MAIN_HAND))
	assert_eq(equipment.get_all_equipped().size(), 0)


func test_equipment_equip_weapon() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)

	var previous := equipment.equip(sword)
	assert_null(previous)
	assert_true(equipment.is_slot_occupied(ItemEnums.EquipSlot.MAIN_HAND))
	assert_eq(equipment.get_equipped(ItemEnums.EquipSlot.MAIN_HAND), sword)


func test_equipment_equip_replaces() -> void:
	var equipment := EquipmentSlots.new()
	var sword1 := ItemInstance.create(_sword_def)
	var sword2 := ItemInstance.create(_sword_def)

	equipment.equip(sword1)
	var previous := equipment.equip(sword2)

	assert_eq(previous, sword1)
	assert_eq(equipment.get_equipped(ItemEnums.EquipSlot.MAIN_HAND), sword2)


func test_equipment_cannot_equip_non_equippable() -> void:
	var equipment := EquipmentSlots.new()
	var ore := ItemInstance.create(_ore_def)

	var previous := equipment.equip(ore)
	assert_null(previous)
	assert_eq(equipment.get_all_equipped().size(), 0)


func test_equipment_cannot_equip_broken() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	sword.current_durability = 0  # Break it

	var previous := equipment.equip(sword)
	assert_null(previous)
	assert_false(equipment.is_slot_occupied(ItemEnums.EquipSlot.MAIN_HAND))


func test_equipment_unequip() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	equipment.equip(sword)

	var removed := equipment.unequip(ItemEnums.EquipSlot.MAIN_HAND)
	assert_eq(removed, sword)
	assert_false(equipment.is_slot_occupied(ItemEnums.EquipSlot.MAIN_HAND))


func test_equipment_unequip_empty() -> void:
	var equipment := EquipmentSlots.new()
	var removed := equipment.unequip(ItemEnums.EquipSlot.HEAD)
	assert_null(removed)


func test_equipment_accessories() -> void:
	var equipment := EquipmentSlots.new()
	var ring1 := ItemInstance.create(_ring_def)
	var ring2 := ItemInstance.create(_ring_def)

	# First ring goes to slot 1
	equipment.equip(ring1)
	assert_eq(equipment.get_accessory(1), ring1)
	assert_null(equipment.get_accessory(2))

	# Second ring goes to slot 2
	equipment.equip(ring2)
	assert_eq(equipment.get_accessory(1), ring1)
	assert_eq(equipment.get_accessory(2), ring2)


func test_equipment_accessory_replaces_when_full() -> void:
	var equipment := EquipmentSlots.new()
	var ring1 := ItemInstance.create(_ring_def)
	var ring2 := ItemInstance.create(_ring_def)
	var ring3 := ItemInstance.create(_ring_def)

	equipment.equip(ring1)
	equipment.equip(ring2)
	var previous := equipment.equip(ring3)

	assert_eq(previous, ring1)  # First slot was replaced
	assert_eq(equipment.get_accessory(1), ring3)
	assert_eq(equipment.get_accessory(2), ring2)


func test_equipment_accessory_specific_slot() -> void:
	var equipment := EquipmentSlots.new()
	var ring := ItemInstance.create(_ring_def)

	var previous := equipment.equip_accessory_to_slot(ring, 2)
	assert_null(previous)
	assert_null(equipment.get_accessory(1))
	assert_eq(equipment.get_accessory(2), ring)


func test_equipment_unequip_accessory() -> void:
	var equipment := EquipmentSlots.new()
	var ring := ItemInstance.create(_ring_def)
	equipment.equip_accessory_to_slot(ring, 2)

	var removed := equipment.unequip_accessory(2)
	assert_eq(removed, ring)
	assert_null(equipment.get_accessory(2))


func test_equipment_get_all_equipped() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	var helmet := ItemInstance.create(_helmet_def)
	var ring := ItemInstance.create(_ring_def)

	equipment.equip(sword)
	equipment.equip(helmet)
	equipment.equip(ring)

	var all := equipment.get_all_equipped()
	assert_eq(all.size(), 3)


func test_equipment_total_stats() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)  # +5 STR, +0.1 ATK SPD
	var helmet := ItemInstance.create(_helmet_def)  # +8 FORT, +20 HP

	equipment.equip(sword)
	equipment.equip(helmet)

	var stats := equipment.get_total_stats()
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 5.0)
	assert_eq(stats[ItemEnums.StatType.ATTACK_SPEED], 0.1)
	assert_eq(stats[ItemEnums.StatType.FORTITUDE], 8.0)
	assert_eq(stats[ItemEnums.StatType.MAX_HP], 20.0)


func test_equipment_total_stat_single() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	equipment.equip(sword)

	assert_eq(equipment.get_total_stat(ItemEnums.StatType.STRENGTH), 5.0)
	assert_eq(equipment.get_total_stat(ItemEnums.StatType.MAX_HP), 0.0)


func test_equipment_total_weight() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)  # 3.0
	var helmet := ItemInstance.create(_helmet_def)  # 2.0

	equipment.equip(sword)
	equipment.equip(helmet)

	assert_eq(equipment.get_total_weight(), 5.0)


func test_equipment_set_counts() -> void:
	var equipment := EquipmentSlots.new()

	# Create items with set IDs
	var set_sword := ItemInstance.create(_sword_def)
	set_sword.definition.set_id = "iron_set"
	var set_helmet := ItemInstance.create(_helmet_def)
	set_helmet.definition.set_id = "iron_set"

	equipment.equip(set_sword)
	equipment.equip(set_helmet)

	var counts := equipment.get_set_counts()
	assert_eq(counts.get("iron_set", 0), 2)


func test_equipment_use_durability_all() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)  # 100 durability
	var helmet := ItemInstance.create(_helmet_def)  # 150 durability

	equipment.equip(sword)
	equipment.equip(helmet)

	var broken := equipment.use_durability_all(50)
	assert_eq(broken.size(), 0)
	assert_eq(sword.current_durability, 50)
	assert_eq(helmet.current_durability, 100)

	# Use more to break sword
	broken = equipment.use_durability_all(60)
	assert_eq(broken.size(), 1)
	assert_eq(broken[0], sword)


func test_equipment_clear() -> void:
	var equipment := EquipmentSlots.new()
	equipment.equip(ItemInstance.create(_sword_def))
	equipment.equip(ItemInstance.create(_helmet_def))

	equipment.clear()
	assert_eq(equipment.get_all_equipped().size(), 0)


func test_equipment_signal() -> void:
	var equipment := EquipmentSlots.new()

	# Use watch_signals to track signal emissions
	watch_signals(equipment)

	equipment.equip(ItemInstance.create(_sword_def))

	assert_signal_emitted(equipment, "equipment_changed")


# =============================================================================
# PlayerStats Tests
# =============================================================================

func test_player_stats_base_values() -> void:
	var stats := PlayerStats.new()

	assert_eq(stats.get_max_hp(), 100.0)
	assert_eq(stats.get_max_energy(), 100.0)
	assert_eq(stats.get_move_speed(), 1.0)
	assert_eq(stats.get_attack_speed(), 1.0)
	assert_eq(stats.get_crit_chance(), 0.05)


func test_player_stats_with_equipment() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)  # +5 STR
	var helmet := ItemInstance.create(_helmet_def)  # +20 HP, +8 FORT
	equipment.equip(sword)
	equipment.equip(helmet)

	var stats := PlayerStats.new(equipment)

	# Base HP (100) + equipment (20)
	assert_eq(stats.get_max_hp(), 120.0)
	# Base strength (10) + equipment (5)
	assert_eq(stats.get_stat(ItemEnums.StatType.STRENGTH), 15.0)
	# Base fortitude (10) + equipment (8)
	assert_eq(stats.get_stat(ItemEnums.StatType.FORTITUDE), 18.0)


func test_player_stats_updates_on_equipment_change() -> void:
	var equipment := EquipmentSlots.new()
	var stats := PlayerStats.new(equipment)

	assert_eq(stats.get_max_hp(), 100.0)

	var helmet := ItemInstance.create(_helmet_def)  # +20 HP
	equipment.equip(helmet)

	assert_eq(stats.get_max_hp(), 120.0)


func test_player_stats_signal() -> void:
	var equipment := EquipmentSlots.new()
	var stats := PlayerStats.new(equipment)

	# Use watch_signals to track signal emissions
	watch_signals(stats)

	equipment.equip(ItemInstance.create(_sword_def))

	assert_signal_emitted(stats, "stats_changed")


func test_player_stats_stat_limits() -> void:
	var equipment := EquipmentSlots.new()
	var stats := PlayerStats.new(equipment)

	# Test that crit chance is capped at 100%
	var all_stats := stats.get_all_stats()
	assert_true(all_stats[ItemEnums.StatType.CRIT_CHANCE] <= 1.0)

	# Move speed minimum
	assert_true(stats.get_move_speed() >= 0.1)


func test_player_stats_calculate_melee_damage() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)  # +5 STR
	equipment.equip(sword)

	var stats := PlayerStats.new(equipment)

	# Base damage 100, strength 15 (base 10 + 5 from sword)
	# Multiplier = 1.0 + (15 - 10) * 0.02 = 1.1
	var damage := stats.calculate_melee_damage(100.0)
	assert_almost_eq(damage, 110.0, 0.01)


func test_player_stats_calculate_damage_reduction() -> void:
	var equipment := EquipmentSlots.new()
	var helmet := ItemInstance.create(_helmet_def)  # +8 FORT
	equipment.equip(helmet)

	var stats := PlayerStats.new(equipment)

	# Fortitude = 18 (10 + 8)
	# Reduction = 1 - (100 / (100 + 18)) = 0.1525...
	var reduction := stats.calculate_damage_reduction()
	assert_almost_eq(reduction, 0.1525, 0.01)


func test_player_stats_calculate_tool_efficiency() -> void:
	var stats := PlayerStats.new()

	# Base efficiency = 10
	# Multiplier = 1.0 + (10 - 10) * 0.02 = 1.0
	var efficiency := stats.calculate_tool_efficiency()
	assert_eq(efficiency, 1.0)


func test_player_stats_to_dict() -> void:
	var equipment := EquipmentSlots.new()
	var sword := ItemInstance.create(_sword_def)
	equipment.equip(sword)

	var stats := PlayerStats.new(equipment)
	var dict := stats.to_dict()

	assert_true(dict.size() > 0)
	assert_eq(dict[str(ItemEnums.StatType.STRENGTH)], 15.0)


func test_player_stats_set_equipment() -> void:
	var stats := PlayerStats.new()
	assert_eq(stats.get_max_hp(), 100.0)

	var equipment := EquipmentSlots.new()
	var helmet := ItemInstance.create(_helmet_def)  # +20 HP
	equipment.equip(helmet)

	stats.set_equipment(equipment)
	assert_eq(stats.get_max_hp(), 120.0)


func test_player_stats_recalculate() -> void:
	var equipment := EquipmentSlots.new()
	var stats := PlayerStats.new(equipment)

	var initial_hp := stats.get_max_hp()
	stats.recalculate()
	assert_eq(stats.get_max_hp(), initial_hp)
