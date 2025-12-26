extends GutTest
## Unit tests for the item system core classes.


# =============================================================================
# Test Fixtures
# =============================================================================

var _sword_def: ItemDefinition
var _iron_ore_def: ItemDefinition
var _iron_material: MaterialDefinition


func before_each() -> void:
	# Create a sword definition (non-stackable equipment)
	_sword_def = ItemDefinition.new()
	_sword_def.id = "iron_sword"
	_sword_def.name = "Iron Sword"
	_sword_def.type = ItemEnums.ItemType.WEAPON
	_sword_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_sword_def.tier = 2
	_sword_def.max_stack = 1
	_sword_def.weight = 3.0
	_sword_def.base_durability = 100
	_sword_def.base_damage = 15
	_sword_def.attack_speed = 1.0
	_sword_def.enchant_slots = 2
	_sword_def.socket_count = 1
	_sword_def.base_stats = {
		ItemEnums.StatType.STRENGTH: 5.0,
		ItemEnums.StatType.ATTACK_SPEED: 0.1,
	}

	# Create iron ore definition (stackable material)
	_iron_ore_def = ItemDefinition.new()
	_iron_ore_def.id = "iron_ore"
	_iron_ore_def.name = "Iron Ore"
	_iron_ore_def.type = ItemEnums.ItemType.MATERIAL
	_iron_ore_def.tier = 2
	_iron_ore_def.max_stack = 99
	_iron_ore_def.weight = 0.5

	# Create iron material definition
	_iron_material = MaterialDefinition.new("iron", "Iron", 2)
	_iron_material.base_durability = 150
	_iron_material.base_damage = 12
	_iron_material.base_armor = 8
	_iron_material.weight_per_unit = 1.0
	_iron_material.category = "metal"
	_iron_material.harvest_tier_required = 1


# =============================================================================
# ItemEnums Tests
# =============================================================================

func test_get_stat_name() -> void:
	assert_eq(ItemEnums.get_stat_name(ItemEnums.StatType.MAX_HP), "Max HP")
	assert_eq(ItemEnums.get_stat_name(ItemEnums.StatType.STRENGTH), "Strength")
	assert_eq(ItemEnums.get_stat_name(ItemEnums.StatType.CRIT_CHANCE), "Crit Chance")
	assert_eq(ItemEnums.get_stat_name(ItemEnums.StatType.HEAT_RESIST), "Heat Resist")


func test_get_tier_name() -> void:
	assert_eq(ItemEnums.get_tier_name(ItemEnums.MaterialTier.PRIMITIVE), "Primitive")
	assert_eq(ItemEnums.get_tier_name(ItemEnums.MaterialTier.BASIC), "Basic")
	assert_eq(ItemEnums.get_tier_name(ItemEnums.MaterialTier.INTERMEDIATE), "Intermediate")
	assert_eq(ItemEnums.get_tier_name(ItemEnums.MaterialTier.ADVANCED), "Advanced")
	assert_eq(ItemEnums.get_tier_name(ItemEnums.MaterialTier.EXOTIC), "Exotic")


func test_get_slot_name() -> void:
	assert_eq(ItemEnums.get_slot_name(ItemEnums.EquipSlot.HEAD), "Head")
	assert_eq(ItemEnums.get_slot_name(ItemEnums.EquipSlot.MAIN_HAND), "Main Hand")
	assert_eq(ItemEnums.get_slot_name(ItemEnums.EquipSlot.NONE), "None")


# =============================================================================
# ItemDefinition Tests
# =============================================================================

func test_item_definition_init() -> void:
	var def := ItemDefinition.new("test_item", "Test Item", ItemEnums.ItemType.TOOL)
	assert_eq(def.id, "test_item")
	assert_eq(def.name, "Test Item")
	assert_eq(def.type, ItemEnums.ItemType.TOOL)


func test_item_definition_is_equippable() -> void:
	assert_true(_sword_def.is_equippable())
	assert_false(_iron_ore_def.is_equippable())


func test_item_definition_is_stackable() -> void:
	assert_false(_sword_def.is_stackable())
	assert_true(_iron_ore_def.is_stackable())


func test_item_definition_has_durability() -> void:
	assert_true(_sword_def.has_durability())
	assert_false(_iron_ore_def.has_durability())


func test_item_definition_get_base_stat() -> void:
	assert_eq(_sword_def.get_base_stat(ItemEnums.StatType.STRENGTH), 5.0)
	assert_eq(_sword_def.get_base_stat(ItemEnums.StatType.MAX_HP), 0.0)


func test_item_definition_serialization() -> void:
	var dict := _sword_def.to_dict()
	assert_eq(dict["id"], "iron_sword")
	assert_eq(dict["name"], "Iron Sword")
	assert_eq(dict["type"], ItemEnums.ItemType.WEAPON)
	assert_eq(dict["base_durability"], 100)

	var restored := ItemDefinition.from_dict(dict)
	assert_eq(restored.id, _sword_def.id)
	assert_eq(restored.name, _sword_def.name)
	assert_eq(restored.type, _sword_def.type)
	assert_eq(restored.base_durability, _sword_def.base_durability)


# =============================================================================
# MaterialDefinition Tests
# =============================================================================

func test_material_definition_init() -> void:
	var mat := MaterialDefinition.new("copper", "Copper", 1)
	assert_eq(mat.id, "copper")
	assert_eq(mat.name, "Copper")
	assert_eq(mat.tier, 1)


func test_material_definition_has_property() -> void:
	_iron_material.special_properties = ["magnetic", "conductive"]
	assert_true(_iron_material.has_property("magnetic"))
	assert_true(_iron_material.has_property("conductive"))
	assert_false(_iron_material.has_property("lightweight"))


func test_material_definition_serialization() -> void:
	_iron_material.special_properties = ["magnetic"]
	_iron_material.color = Color.GRAY

	var dict := _iron_material.to_dict()
	assert_eq(dict["id"], "iron")
	assert_eq(dict["tier"], 2)
	assert_eq(dict["category"], "metal")
	assert_true("magnetic" in dict["special_properties"])

	var restored := MaterialDefinition.from_dict(dict)
	assert_eq(restored.id, "iron")
	assert_eq(restored.tier, 2)
	assert_true(restored.has_property("magnetic"))


# =============================================================================
# ItemInstance Tests
# =============================================================================

func test_item_instance_create() -> void:
	var instance := ItemInstance.create(_sword_def)
	assert_eq(instance.definition, _sword_def)
	assert_ne(instance.instance_id, "")
	assert_eq(instance.quality, 1.0)
	assert_eq(instance.current_durability, 100)


func test_item_instance_create_with_quality() -> void:
	var high_quality := ItemInstance.create(_sword_def, 1.2)
	assert_eq(high_quality.quality, 1.2)
	assert_eq(high_quality.current_durability, 120)  # 100 * 1.2

	var low_quality := ItemInstance.create(_sword_def, 0.7)
	assert_eq(low_quality.quality, 0.7)
	assert_eq(low_quality.current_durability, 70)  # 100 * 0.7


func test_item_instance_quality_clamping() -> void:
	var too_high := ItemInstance.create(_sword_def, 2.0)
	assert_eq(too_high.quality, 1.25)  # Clamped to max

	var too_low := ItemInstance.create(_sword_def, 0.1)
	assert_eq(too_low.quality, 0.6)  # Clamped to min


func test_item_instance_display_name_quality_prefixes() -> void:
	var crude := ItemInstance.create(_sword_def, 0.7)
	assert_true(crude.get_display_name().begins_with("Crude"))

	var normal := ItemInstance.create(_sword_def, 1.0)
	assert_eq(normal.get_display_name(), "Iron Sword")

	var fine := ItemInstance.create(_sword_def, 1.1)
	assert_true(fine.get_display_name().begins_with("Fine"))

	var masterwork := ItemInstance.create(_sword_def, 1.2)
	assert_true(masterwork.get_display_name().begins_with("Masterwork"))


func test_item_instance_durability() -> void:
	var instance := ItemInstance.create(_sword_def)
	assert_eq(instance.current_durability, 100)
	assert_eq(instance.get_max_durability(), 100)
	assert_false(instance.is_broken())

	# Use durability
	var broke := instance.use_durability(50)
	assert_false(broke)
	assert_eq(instance.current_durability, 50)

	# Use remaining durability
	broke = instance.use_durability(50)
	assert_true(broke)
	assert_eq(instance.current_durability, 0)
	assert_true(instance.is_broken())


func test_item_instance_repair() -> void:
	var instance := ItemInstance.create(_sword_def)
	instance.use_durability(80)
	assert_eq(instance.current_durability, 20)

	var repaired := instance.repair(50)
	assert_eq(repaired, 50)
	assert_eq(instance.current_durability, 70)

	# Repair beyond max
	repaired = instance.repair(100)
	assert_eq(repaired, 30)  # Only 30 more was needed
	assert_eq(instance.current_durability, 100)


func test_item_instance_effective_stats() -> void:
	var normal := ItemInstance.create(_sword_def, 1.0)
	var stats := normal.get_effective_stats()
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 5.0)

	var high_quality := ItemInstance.create(_sword_def, 1.2)
	stats = high_quality.get_effective_stats()
	assert_eq(stats[ItemEnums.StatType.STRENGTH], 6.0)  # 5.0 * 1.2


func test_item_instance_enchantments() -> void:
	var instance := ItemInstance.create(_sword_def)
	assert_true(instance.can_add_enchantment())
	assert_eq(instance.enchantments.size(), 0)

	# Add first enchantment
	var added := instance.add_enchantment("flame", 2)
	assert_true(added)
	assert_eq(instance.enchantments.size(), 1)
	assert_eq(instance.enchantments[0]["id"], "flame")
	assert_eq(instance.enchantments[0]["tier"], 2)

	# Add second enchantment
	added = instance.add_enchantment("sharpness", 1)
	assert_true(added)
	assert_eq(instance.enchantments.size(), 2)

	# Try to add third (should fail - only 2 slots)
	assert_false(instance.can_add_enchantment())
	added = instance.add_enchantment("lifesteal", 1)
	assert_false(added)
	assert_eq(instance.enchantments.size(), 2)

	# Remove enchantment
	var removed := instance.remove_enchantment(0)
	assert_true(removed)
	assert_eq(instance.enchantments.size(), 1)
	assert_eq(instance.enchantments[0]["id"], "sharpness")


func test_item_instance_gems() -> void:
	var instance := ItemInstance.create(_sword_def)
	assert_true(instance.can_add_gem())

	var added := instance.add_gem("ruby")
	assert_true(added)
	assert_eq(instance.socketed_gems.size(), 1)

	# Can't add more (only 1 socket)
	assert_false(instance.can_add_gem())
	added = instance.add_gem("emerald")
	assert_false(added)

	# Remove gem
	var removed := instance.remove_gem(0)
	assert_true(removed)
	assert_eq(instance.socketed_gems.size(), 0)


func test_item_instance_serialization() -> void:
	var instance := ItemInstance.create(_sword_def, 1.1)
	instance.crafted_by = "player123"
	instance.add_enchantment("flame", 2)
	instance.add_gem("ruby")
	instance.use_durability(20)

	var dict := instance.to_dict()
	assert_eq(dict["definition_id"], "iron_sword")
	assert_eq(dict["quality"], 1.1)
	assert_eq(dict["crafted_by"], "player123")
	assert_eq(dict["current_durability"], 90)
	assert_eq(dict["enchantments"].size(), 1)
	assert_eq(dict["socketed_gems"].size(), 1)


# =============================================================================
# ItemStack Tests
# =============================================================================

func test_item_stack_create() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 10)
	assert_eq(stack.item, instance)
	assert_eq(stack.count, 10)
	assert_false(stack.is_empty())


func test_item_stack_empty() -> void:
	var empty := ItemStack.new()
	assert_true(empty.is_empty())
	assert_eq(empty.count, 0)


func test_item_stack_is_full() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 50)
	assert_false(stack.is_full())

	stack.count = 99
	assert_true(stack.is_full())


func test_item_stack_remaining_space() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 50)
	assert_eq(stack.get_remaining_space(), 49)

	stack.count = 99
	assert_eq(stack.get_remaining_space(), 0)


func test_item_stack_weight() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 10)
	assert_eq(stack.get_weight(), 5.0)  # 0.5 * 10


func test_item_stack_display_text() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 10)
	assert_eq(stack.get_display_text(), "Iron Ore x10")

	stack.count = 1
	assert_eq(stack.get_display_text(), "Iron Ore")


func test_item_stack_can_merge_same_item() -> void:
	var instance1 := ItemInstance.create(_iron_ore_def)
	var instance2 := ItemInstance.create(_iron_ore_def)
	var stack1 := ItemStack.new(instance1, 50)
	var stack2 := ItemStack.new(instance2, 30)

	assert_true(stack1.can_merge_with(stack2))


func test_item_stack_cannot_merge_different_items() -> void:
	var iron := ItemInstance.create(_iron_ore_def)

	var copper_def := ItemDefinition.new()
	copper_def.id = "copper_ore"
	copper_def.max_stack = 99
	var copper := ItemInstance.create(copper_def)

	var iron_stack := ItemStack.new(iron, 50)
	var copper_stack := ItemStack.new(copper, 30)

	assert_false(iron_stack.can_merge_with(copper_stack))


func test_item_stack_cannot_merge_non_stackable() -> void:
	var sword1 := ItemInstance.create(_sword_def)
	var sword2 := ItemInstance.create(_sword_def)
	var stack1 := ItemStack.new(sword1, 1)
	var stack2 := ItemStack.new(sword2, 1)

	assert_false(stack1.can_merge_with(stack2))


func test_item_stack_merge_partial() -> void:
	var instance1 := ItemInstance.create(_iron_ore_def)
	var instance2 := ItemInstance.create(_iron_ore_def)
	var stack1 := ItemStack.new(instance1, 80)
	var stack2 := ItemStack.new(instance2, 30)

	var leftover := stack1.merge_from(stack2)
	assert_eq(stack1.count, 99)  # Full
	assert_eq(leftover, 11)  # 30 - 19 that fit
	assert_eq(stack2.count, 11)


func test_item_stack_merge_complete() -> void:
	var instance1 := ItemInstance.create(_iron_ore_def)
	var instance2 := ItemInstance.create(_iron_ore_def)
	var stack1 := ItemStack.new(instance1, 50)
	var stack2 := ItemStack.new(instance2, 30)

	var leftover := stack1.merge_from(stack2)
	assert_eq(stack1.count, 80)
	assert_eq(leftover, 0)
	assert_true(stack2.is_empty())


func test_item_stack_merge_into_empty() -> void:
	var empty := ItemStack.new()
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 30)

	var leftover := empty.merge_from(stack)
	assert_eq(leftover, 0)
	assert_eq(empty.count, 30)
	assert_eq(empty.item.definition.id, "iron_ore")
	assert_true(stack.is_empty())


func test_item_stack_split() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 50)

	var split := stack.split(20)
	assert_not_null(split)
	assert_eq(split.count, 20)
	assert_eq(stack.count, 30)


func test_item_stack_split_invalid() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 50)

	# Can't split 0
	assert_null(stack.split(0))

	# Can't split entire stack
	assert_null(stack.split(50))

	# Can't split more than stack
	assert_null(stack.split(60))


func test_item_stack_split_non_stackable() -> void:
	var instance := ItemInstance.create(_sword_def)
	var stack := ItemStack.new(instance, 1)

	# Can't split non-stackable
	assert_null(stack.split(1))


func test_item_stack_take_one() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 5)

	var taken := stack.take_one()
	assert_not_null(taken)
	assert_eq(stack.count, 4)

	# Take until empty
	stack.take_one()
	stack.take_one()
	stack.take_one()
	taken = stack.take_one()
	assert_not_null(taken)
	assert_true(stack.is_empty())

	# Can't take from empty
	taken = stack.take_one()
	assert_null(taken)


func test_item_stack_add() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 50)

	var overflow := stack.add(30)
	assert_eq(overflow, 0)
	assert_eq(stack.count, 80)

	# Add with overflow
	overflow = stack.add(30)
	assert_eq(overflow, 11)  # 30 - 19 that fit
	assert_eq(stack.count, 99)


func test_item_stack_serialization() -> void:
	var instance := ItemInstance.create(_iron_ore_def)
	var stack := ItemStack.new(instance, 25)

	var dict := stack.to_dict()
	assert_eq(dict["count"], 25)
	assert_true(dict.has("item"))
	assert_false(dict.get("empty", false))


func test_item_stack_empty_serialization() -> void:
	var empty := ItemStack.new()
	var dict := empty.to_dict()
	assert_true(dict.get("empty", false))


func test_item_stack_create_from_definition() -> void:
	var stack := ItemStack.create_from_definition(_iron_ore_def, 50)
	assert_eq(stack.count, 50)
	assert_eq(stack.item.definition, _iron_ore_def)
	assert_eq(stack.item.quality, 1.0)


func test_item_stack_create_from_definition_with_quality() -> void:
	var stack := ItemStack.create_from_definition(_sword_def, 1, 1.15)
	assert_eq(stack.count, 1)
	assert_eq(stack.item.quality, 1.15)


func test_item_stack_create_from_definition_clamps_count() -> void:
	# Try to create more than max_stack
	var stack := ItemStack.create_from_definition(_iron_ore_def, 200)
	assert_eq(stack.count, 99)  # Clamped to max_stack
