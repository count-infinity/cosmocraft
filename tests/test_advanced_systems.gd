extends GutTest
## Tests for advanced systems (Phase 6).
## Tests Enchantment, EquipmentSet, Corpse, and TradeSession.


var _item_registry: ItemRegistry
var _enchantment_registry: EnchantmentRegistry
var _set_registry: EquipmentSet.Registry


# Test items
var _iron_sword: ItemDefinition
var _iron_helmet: ItemDefinition
var _iron_chest: ItemDefinition
var _iron_legs: ItemDefinition
var _iron_boots: ItemDefinition
var _health_potion: ItemDefinition


func before_each() -> void:
	_item_registry = ItemRegistry.new()
	_enchantment_registry = EnchantmentRegistry.new()
	_set_registry = EquipmentSet.Registry.new()

	# Create test items
	_iron_sword = ItemDefinition.new()
	_iron_sword.id = "iron_sword"
	_iron_sword.name = "Iron Sword"
	_iron_sword.type = ItemEnums.ItemType.WEAPON
	_iron_sword.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_iron_sword.weight = 5.0
	_iron_sword.max_stack = 1
	_item_registry.register_item(_iron_sword)

	_iron_helmet = ItemDefinition.new()
	_iron_helmet.id = "iron_helmet"
	_iron_helmet.name = "Iron Helmet"
	_iron_helmet.type = ItemEnums.ItemType.ARMOR
	_iron_helmet.equip_slot = ItemEnums.EquipSlot.HEAD
	_iron_helmet.weight = 3.0
	_iron_helmet.max_stack = 1
	_item_registry.register_item(_iron_helmet)

	_iron_chest = ItemDefinition.new()
	_iron_chest.id = "iron_chest"
	_iron_chest.name = "Iron Chestplate"
	_iron_chest.type = ItemEnums.ItemType.ARMOR
	_iron_chest.equip_slot = ItemEnums.EquipSlot.CHEST
	_iron_chest.weight = 8.0
	_iron_chest.max_stack = 1
	_item_registry.register_item(_iron_chest)

	_iron_legs = ItemDefinition.new()
	_iron_legs.id = "iron_legs"
	_iron_legs.name = "Iron Leggings"
	_iron_legs.type = ItemEnums.ItemType.ARMOR
	_iron_legs.equip_slot = ItemEnums.EquipSlot.LEGS
	_iron_legs.weight = 5.0
	_iron_legs.max_stack = 1
	_item_registry.register_item(_iron_legs)

	_iron_boots = ItemDefinition.new()
	_iron_boots.id = "iron_boots"
	_iron_boots.name = "Iron Boots"
	_iron_boots.type = ItemEnums.ItemType.ARMOR
	_iron_boots.equip_slot = ItemEnums.EquipSlot.BOOTS
	_iron_boots.weight = 2.0
	_iron_boots.max_stack = 1
	_item_registry.register_item(_iron_boots)

	_health_potion = ItemDefinition.new()
	_health_potion.id = "health_potion"
	_health_potion.name = "Health Potion"
	_health_potion.type = ItemEnums.ItemType.CONSUMABLE
	_health_potion.weight = 0.5
	_health_potion.max_stack = 20
	_item_registry.register_item(_health_potion)


func after_each() -> void:
	_item_registry = null
	_enchantment_registry = null
	_set_registry = null


# ====================
# Enchantment Tests
# ====================

func test_enchantment_creation() -> void:
	var ench := Enchantment.create("sharpness", "Sharpness")
	assert_eq(ench.id, "sharpness")
	assert_eq(ench.name, "Sharpness")


func test_enchantment_stat_bonuses() -> void:
	var ench := Enchantment.create("fortify", "Fortify")
	ench.stat_bonuses = {ItemEnums.StatType.FORTITUDE: 5.0}
	ench.level = 3

	assert_eq(ench.get_stat_bonus(ItemEnums.StatType.FORTITUDE), 15.0)  # 5 * 3


func test_enchantment_effect_at_level() -> void:
	var ench := Enchantment.create("lifesteal", "Life Steal")
	ench.effect_id = "life_steal"
	ench.effect_magnitude = 2.0
	ench.level = 2

	assert_eq(ench.get_effect_at_level(), 4.0)  # 2 * 2


func test_enchantment_can_apply_to_weapon() -> void:
	var ench := Enchantment.create("sharpness", "Sharpness")
	ench.valid_types = [ItemEnums.ItemType.WEAPON]

	assert_true(ench.can_apply_to(_iron_sword))
	assert_false(ench.can_apply_to(_iron_helmet))


func test_enchantment_can_apply_to_slot() -> void:
	var ench := Enchantment.create("protection", "Protection")
	ench.valid_slots = [ItemEnums.EquipSlot.HEAD, ItemEnums.EquipSlot.CHEST]

	assert_true(ench.can_apply_to(_iron_helmet))
	assert_true(ench.can_apply_to(_iron_chest))
	assert_false(ench.can_apply_to(_iron_boots))


func test_enchantment_rarity_name() -> void:
	var ench := Enchantment.new()
	ench.rarity = Enchantment.Rarity.EPIC

	assert_eq(ench.get_rarity_name(), "Epic")


func test_enchantment_display_text() -> void:
	var ench := Enchantment.create("sharpness", "Sharpness")
	ench.max_level = 5
	ench.level = 3

	assert_eq(ench.get_display_text(), "Sharpness III")


func test_enchantment_create_at_level() -> void:
	var base := Enchantment.create("test", "Test")
	base.max_level = 5
	base.stat_bonuses = {ItemEnums.StatType.STRENGTH: 2.0}

	var copy := base.create_at_level(3)

	assert_eq(copy.level, 3)
	assert_eq(copy.get_stat_bonus(ItemEnums.StatType.STRENGTH), 6.0)


func test_enchantment_serialization() -> void:
	var ench := Enchantment.create("test", "Test Enchantment")
	ench.rarity = Enchantment.Rarity.RARE
	ench.stat_bonuses = {ItemEnums.StatType.FORTITUDE: 3.0}
	ench.level = 2

	var data := ench.to_full_dict()
	var restored := Enchantment.from_full_dict(data)

	assert_eq(restored.id, "test")
	assert_eq(restored.name, "Test Enchantment")
	assert_eq(restored.rarity, Enchantment.Rarity.RARE)
	assert_eq(restored.level, 2)


# ====================
# Enchantment Registry Tests
# ====================

func test_registry_register_enchantment() -> void:
	var ench := _create_sharpness_enchantment()
	_enchantment_registry.register(ench)

	assert_eq(_enchantment_registry.get_count(), 1)
	assert_eq(_enchantment_registry.get_enchantment("sharpness"), ench)


func test_registry_get_by_rarity() -> void:
	var common := Enchantment.create("common_ench", "Common")
	common.rarity = Enchantment.Rarity.COMMON
	_enchantment_registry.register(common)

	var rare := Enchantment.create("rare_ench", "Rare")
	rare.rarity = Enchantment.Rarity.RARE
	_enchantment_registry.register(rare)

	var commons := _enchantment_registry.get_by_rarity(Enchantment.Rarity.COMMON)
	assert_eq(commons.size(), 1)
	assert_eq(commons[0].id, "common_ench")


func test_registry_get_applicable_for() -> void:
	var weapon_ench := Enchantment.create("sharpness", "Sharpness")
	weapon_ench.valid_types = [ItemEnums.ItemType.WEAPON]
	_enchantment_registry.register(weapon_ench)

	var armor_ench := Enchantment.create("protection", "Protection")
	armor_ench.valid_types = [ItemEnums.ItemType.ARMOR]
	_enchantment_registry.register(armor_ench)

	var for_sword := _enchantment_registry.get_applicable_for(_iron_sword)
	assert_eq(for_sword.size(), 1)
	assert_eq(for_sword[0].id, "sharpness")


func test_registry_create_enchantment() -> void:
	var base := _create_sharpness_enchantment()
	_enchantment_registry.register(base)

	var instance := _enchantment_registry.create_enchantment("sharpness", 3)

	assert_not_null(instance)
	assert_eq(instance.level, 3)


# ====================
# Equipment Set Tests
# ====================

func test_equipment_set_creation() -> void:
	var eq_set := EquipmentSet.create("iron_set", "Iron Set")
	assert_eq(eq_set.id, "iron_set")
	assert_eq(eq_set.name, "Iron Set")


func test_equipment_set_add_items() -> void:
	var eq_set := _create_iron_set()

	assert_true(eq_set.contains_item("iron_helmet"))
	assert_true(eq_set.contains_item("iron_chest"))
	assert_false(eq_set.contains_item("gold_helmet"))


func test_equipment_set_piece_count() -> void:
	var eq_set := _create_iron_set()

	assert_eq(eq_set.get_piece_count(), 4)


func test_equipment_set_bonuses() -> void:
	var eq_set := _create_iron_set()

	var bonus_2 := eq_set.get_bonus_at_threshold(2)
	assert_true(bonus_2.has(ItemEnums.StatType.FORTITUDE))

	var bonus_4 := eq_set.get_bonus_at_threshold(4)
	assert_true(bonus_4.has("effect"))


func test_equipment_set_active_bonuses() -> void:
	var eq_set := _create_iron_set()

	var bonuses_1 := eq_set.get_active_bonuses(1)
	assert_eq(bonuses_1.size(), 0)

	var bonuses_2 := eq_set.get_active_bonuses(2)
	assert_eq(bonuses_2.size(), 1)

	var bonuses_4 := eq_set.get_active_bonuses(4)
	assert_eq(bonuses_4.size(), 2)


func test_equipment_set_total_stat_bonuses() -> void:
	var eq_set := _create_iron_set()

	var stats := eq_set.get_total_stat_bonuses(4)
	assert_eq(stats[ItemEnums.StatType.FORTITUDE], 15.0)  # 5 + 10


func test_equipment_set_active_effects() -> void:
	var eq_set := _create_iron_set()

	var effects := eq_set.get_active_effects(4)
	assert_eq(effects.size(), 1)
	assert_eq(effects[0]["effect"], "damage_reflect")


func test_equipment_set_next_threshold() -> void:
	var eq_set := _create_iron_set()

	assert_eq(eq_set.get_next_threshold(0), 2)
	assert_eq(eq_set.get_next_threshold(2), 4)
	assert_eq(eq_set.get_next_threshold(4), -1)


func test_equipment_set_registry() -> void:
	var eq_set := _create_iron_set()
	_set_registry.register(eq_set)

	assert_eq(_set_registry.get_count(), 1)
	assert_eq(_set_registry.get_set("iron_set"), eq_set)
	assert_eq(_set_registry.get_set_for_item("iron_helmet"), eq_set)


func test_equipment_set_registry_count_pieces() -> void:
	var eq_set := _create_iron_set()
	_set_registry.register(eq_set)

	var equipped := ["iron_helmet", "iron_chest", "iron_sword"]
	var count := _set_registry.count_set_pieces("iron_set", equipped)

	assert_eq(count, 2)  # helmet and chest


func test_equipment_set_registry_all_active_bonuses() -> void:
	var eq_set := _create_iron_set()
	_set_registry.register(eq_set)

	var equipped := ["iron_helmet", "iron_chest", "iron_legs", "iron_boots"]
	var bonuses := _set_registry.get_all_active_bonuses(equipped)

	assert_true(bonuses.has("iron_set"))
	assert_eq(bonuses["iron_set"]["pieces"], 4)


# ====================
# Corpse Tests
# ====================

func test_corpse_creation() -> void:
	var corpse := Corpse.new(_item_registry)

	assert_not_null(corpse.id)
	assert_false(corpse.is_looted)


func test_corpse_init_from_death() -> void:
	var player_inv := Inventory.new(100.0, _item_registry)
	player_inv.add_items(_health_potion, 5)

	var player_equip := EquipmentSlots.new()
	var sword := ItemInstance.create(_iron_sword)
	player_equip.equip(sword)

	var corpse := Corpse.new(_item_registry)
	corpse.init_from_death(
		"player_1", "TestPlayer",
		Vector2(100, 200), player_inv, player_equip, 1000.0
	)

	assert_eq(corpse.owner_id, "player_1")
	assert_eq(corpse.owner_name, "TestPlayer")
	assert_eq(corpse.position, Vector2(100, 200))
	assert_eq(corpse.inventory.get_item_count("health_potion"), 5)


func test_corpse_expiration() -> void:
	var corpse := Corpse.new(_item_registry)
	corpse.created_at = 1000.0
	corpse.expire_duration = 300.0

	assert_false(corpse.is_expired(1100.0))
	assert_true(corpse.is_expired(1400.0))


func test_corpse_time_remaining() -> void:
	var corpse := Corpse.new(_item_registry)
	corpse.created_at = 1000.0
	corpse.expire_duration = 300.0

	assert_eq(corpse.get_time_remaining(1100.0), 200.0)
	assert_eq(corpse.get_time_remaining(1400.0), 0.0)


func test_corpse_can_loot_owner() -> void:
	var corpse := Corpse.new(_item_registry)
	corpse.owner_id = "player_1"
	corpse.created_at = 1000.0

	# Owner can always loot
	assert_true(corpse.can_loot("player_1", 1000.0))
	assert_true(corpse.can_loot("player_1", 1010.0))


func test_corpse_can_loot_other_protection() -> void:
	var corpse := Corpse.new(_item_registry)
	corpse.owner_id = "player_1"
	corpse.created_at = 1000.0

	# Others cannot loot during protection (60 seconds default)
	assert_false(corpse.can_loot("player_2", 1030.0))
	assert_true(corpse.can_loot("player_2", 1100.0))


func test_corpse_manager() -> void:
	var manager := Corpse.Manager.new(_item_registry)

	var player_inv := Inventory.new(100.0, _item_registry)
	var player_equip := EquipmentSlots.new()

	var corpse := manager.create_corpse(
		"player_1", "TestPlayer",
		Vector2(50, 50), player_inv, player_equip, 1000.0
	)

	assert_not_null(corpse)
	assert_eq(manager.get_count(), 1)
	assert_eq(manager.get_player_corpse("player_1"), corpse)


func test_corpse_manager_cleanup() -> void:
	var manager := Corpse.Manager.new(_item_registry)

	var player_inv := Inventory.new(100.0, _item_registry)
	var player_equip := EquipmentSlots.new()

	var corpse := manager.create_corpse(
		"player_1", "TestPlayer",
		Vector2(50, 50), player_inv, player_equip, 1000.0, 100.0
	)

	var expired := manager.cleanup_expired(1200.0)

	assert_eq(expired.size(), 1)
	assert_eq(manager.get_count(), 0)


# ====================
# Trade Session Tests
# ====================

func test_trade_creation() -> void:
	var trade := TradeSession.new(_item_registry)

	assert_not_null(trade.id)
	assert_eq(trade.state, TradeSession.State.PENDING)


func test_trade_init() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	assert_eq(trade.player_a_id, "p1")
	assert_eq(trade.player_b_id, "p2")
	assert_true(trade.has_player("p1"))
	assert_true(trade.has_player("p2"))
	assert_false(trade.has_player("p3"))


func test_trade_get_other_player() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	assert_eq(trade.get_other_player("p1"), "p2")
	assert_eq(trade.get_other_player("p2"), "p1")


func test_trade_add_item() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	var stack := _item_registry.create_item_stack("health_potion", 5)
	var success := trade.add_item("p1", stack)

	assert_true(success)
	assert_eq(trade.get_items("p1").size(), 1)


func test_trade_remove_item() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	var stack := _item_registry.create_item_stack("health_potion", 5)
	trade.add_item("p1", stack)

	var success := trade.remove_item("p1", stack)

	assert_true(success)
	assert_eq(trade.get_items("p1").size(), 0)


func test_trade_confirm() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	trade.confirm("p1")
	assert_true(trade.is_confirmed("p1"))
	assert_eq(trade.state, TradeSession.State.PENDING)

	trade.confirm("p2")
	assert_eq(trade.state, TradeSession.State.CONFIRMED)


func test_trade_adding_item_resets_confirmation() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	trade.confirm("p1")
	assert_true(trade.is_confirmed("p1"))

	var stack := _item_registry.create_item_stack("health_potion", 5)
	trade.add_item("p1", stack)

	assert_false(trade.is_confirmed("p1"))


func test_trade_execute() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	var inv_a := Inventory.new(100.0, _item_registry)
	inv_a.add_items(_health_potion, 10)

	var inv_b := Inventory.new(100.0, _item_registry)

	var stack := _item_registry.create_item_stack("health_potion", 5)
	trade.add_item("p1", stack)

	trade.confirm("p1")
	trade.confirm("p2")

	var success := trade.execute(inv_a, inv_b)

	assert_true(success)
	assert_eq(trade.state, TradeSession.State.COMPLETED)
	assert_eq(inv_a.get_item_count("health_potion"), 5)  # 10 - 5
	assert_eq(inv_b.get_item_count("health_potion"), 5)  # Received 5


func test_trade_cancel() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)

	trade.cancel("Test cancel")

	assert_eq(trade.state, TradeSession.State.CANCELLED)


func test_trade_timeout() -> void:
	var trade := TradeSession.new(_item_registry)
	trade.init_trade("p1", "Player1", "p2", "Player2", 1000.0)
	trade.timeout_duration = 120.0

	assert_false(trade.is_timed_out(1050.0))
	assert_true(trade.is_timed_out(1200.0))


func test_trade_manager() -> void:
	var manager := TradeSession.Manager.new(_item_registry)

	var trade := manager.create_trade("p1", "Player1", "p2", "Player2", 1000.0)

	assert_not_null(trade)
	assert_eq(manager.get_count(), 1)
	assert_true(manager.has_active_trade("p1"))
	assert_true(manager.has_active_trade("p2"))


func test_trade_manager_prevents_double_trade() -> void:
	var manager := TradeSession.Manager.new(_item_registry)

	manager.create_trade("p1", "Player1", "p2", "Player2", 1000.0)
	var second := manager.create_trade("p1", "Player1", "p3", "Player3", 1000.0)

	assert_null(second)


func test_trade_manager_cleanup() -> void:
	var manager := TradeSession.Manager.new(_item_registry)

	var trade := manager.create_trade("p1", "Player1", "p2", "Player2", 1000.0)
	trade.timeout_duration = 60.0

	var cleaned := manager.cleanup(1100.0)

	assert_eq(cleaned.size(), 1)
	assert_eq(manager.get_count(), 0)


# ====================
# Helper Methods
# ====================

func _create_sharpness_enchantment() -> Enchantment:
	var ench := Enchantment.create("sharpness", "Sharpness")
	ench.rarity = Enchantment.Rarity.COMMON
	ench.valid_types = [ItemEnums.ItemType.WEAPON]
	ench.stat_bonuses = {ItemEnums.StatType.STRENGTH: 2.0}
	ench.max_level = 5
	return ench


func _create_iron_set() -> EquipmentSet:
	var eq_set := EquipmentSet.create("iron_set", "Iron Set")
	eq_set.add_item("iron_helmet")
	eq_set.add_item("iron_chest")
	eq_set.add_item("iron_legs")
	eq_set.add_item("iron_boots")

	# 2 piece bonus: +5 fortitude
	eq_set.add_bonus(2, {ItemEnums.StatType.FORTITUDE: 5.0})

	# 4 piece bonus: +10 fortitude, damage reflect effect
	eq_set.add_bonus(4, {
		ItemEnums.StatType.FORTITUDE: 10.0,
		"effect": "damage_reflect",
		"magnitude": 0.1,
	})

	return eq_set
