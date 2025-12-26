extends GutTest
## Unit tests for the inventory system (Phase 3).


# =============================================================================
# Test Fixtures
# =============================================================================

var _registry: ItemRegistry
var _ore_def: ItemDefinition
var _sword_def: ItemDefinition
var _potion_def: ItemDefinition


func before_each() -> void:
	_registry = ItemRegistry.new()

	# Create iron ore (stackable, light)
	_ore_def = ItemDefinition.new()
	_ore_def.id = "iron_ore"
	_ore_def.name = "Iron Ore"
	_ore_def.type = ItemEnums.ItemType.MATERIAL
	_ore_def.max_stack = 99
	_ore_def.weight = 0.5
	_registry.register_item(_ore_def)

	# Create sword (non-stackable, heavy)
	_sword_def = ItemDefinition.new()
	_sword_def.id = "iron_sword"
	_sword_def.name = "Iron Sword"
	_sword_def.type = ItemEnums.ItemType.WEAPON
	_sword_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_sword_def.max_stack = 1
	_sword_def.weight = 5.0
	_registry.register_item(_sword_def)

	# Create potion (stackable, medium weight)
	_potion_def = ItemDefinition.new()
	_potion_def.id = "health_potion"
	_potion_def.name = "Health Potion"
	_potion_def.type = ItemEnums.ItemType.CONSUMABLE
	_potion_def.max_stack = 10
	_potion_def.weight = 1.0
	_registry.register_item(_potion_def)


# =============================================================================
# Inventory Basic Tests
# =============================================================================

func test_inventory_initial_state() -> void:
	var inv := Inventory.new(100.0)
	assert_eq(inv.max_weight, 100.0)
	assert_eq(inv.get_current_weight(), 0.0)
	assert_eq(inv.get_remaining_capacity(), 100.0)
	assert_true(inv.is_empty())


func test_inventory_add_stack() -> void:
	var inv := Inventory.new(100.0)
	var stack := ItemStack.create_from_definition(_ore_def, 10)

	var leftover := inv.add_stack(stack)
	assert_null(leftover)
	assert_eq(inv.get_stack_count(), 1)
	assert_eq(inv.get_current_weight(), 5.0)  # 10 * 0.5
	assert_false(inv.is_empty())


func test_inventory_add_items_by_definition() -> void:
	var inv := Inventory.new(100.0)

	var leftover := inv.add_items(_ore_def, 20)
	assert_eq(leftover, 0)
	assert_eq(inv.get_item_count("iron_ore"), 20)


func test_inventory_weight_capacity() -> void:
	var inv := Inventory.new(10.0)  # Small capacity

	# Can add items that fit
	assert_true(inv.can_hold_weight(5.0))
	inv.add_items(_ore_def, 10)  # 5.0 weight
	assert_eq(inv.get_remaining_capacity(), 5.0)

	# Can't add more than remaining capacity
	assert_false(inv.can_hold_weight(10.0))


func test_inventory_partial_add_by_weight() -> void:
	var inv := Inventory.new(10.0)
	var stack := ItemStack.create_from_definition(_ore_def, 30)  # 15.0 weight

	var leftover := inv.add_stack(stack)
	assert_not_null(leftover)
	assert_eq(inv.get_item_count("iron_ore"), 20)  # Only 20 fit (10.0 weight)
	assert_eq(leftover.count, 10)  # 10 left over


func test_inventory_merge_stackables() -> void:
	var inv := Inventory.new(100.0)

	inv.add_items(_ore_def, 30)
	inv.add_items(_ore_def, 20)

	# Should merge into existing stack
	assert_eq(inv.get_stack_count(), 1)
	assert_eq(inv.get_item_count("iron_ore"), 50)


func test_inventory_non_stackable_separate() -> void:
	var inv := Inventory.new(100.0)

	inv.add_items(_sword_def, 1)
	inv.add_items(_sword_def, 1)

	# Swords don't stack, should be 2 separate stacks
	assert_eq(inv.get_stack_count(), 2)


func test_inventory_remove_items() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_ore_def, 50)

	var removed := inv.remove_items_by_id("iron_ore", 20)
	assert_eq(removed, 20)
	assert_eq(inv.get_item_count("iron_ore"), 30)


func test_inventory_remove_more_than_exists() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_ore_def, 20)

	var removed := inv.remove_items_by_id("iron_ore", 50)
	assert_eq(removed, 20)  # Only 20 existed
	assert_eq(inv.get_item_count("iron_ore"), 0)
	assert_true(inv.is_empty())


func test_inventory_has_item() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_ore_def, 30)

	assert_true(inv.has_item("iron_ore", 1))
	assert_true(inv.has_item("iron_ore", 30))
	assert_false(inv.has_item("iron_ore", 31))
	assert_false(inv.has_item("nonexistent"))


func test_inventory_find_stack() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_ore_def, 30)
	inv.add_items(_sword_def, 1)

	var ore_stack := inv.find_stack_by_id("iron_ore")
	assert_not_null(ore_stack)
	assert_eq(ore_stack.item.definition.id, "iron_ore")

	var nonexistent := inv.find_stack_by_id("nonexistent")
	assert_null(nonexistent)


func test_inventory_find_all_stacks() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_sword_def, 1)
	inv.add_items(_sword_def, 1)
	inv.add_items(_ore_def, 30)

	var swords := inv.find_all_stacks_by_id("iron_sword")
	assert_eq(swords.size(), 2)


func test_inventory_find_by_type() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_ore_def, 30)
	inv.add_items(_sword_def, 1)
	inv.add_items(_potion_def, 5)

	var weapons := inv.find_stacks_by_type(ItemEnums.ItemType.WEAPON)
	assert_eq(weapons.size(), 1)

	var materials := inv.find_stacks_by_type(ItemEnums.ItemType.MATERIAL)
	assert_eq(materials.size(), 1)


func test_inventory_remove_stack() -> void:
	var inv := Inventory.new(100.0)
	var stack := ItemStack.create_from_definition(_ore_def, 30)
	inv.add_stack(stack)

	# Get the actual stack from inventory
	var found := inv.find_stack_by_id("iron_ore")
	var removed := inv.remove_stack(found)

	assert_true(removed)
	assert_true(inv.is_empty())


func test_inventory_split_stack() -> void:
	var inv := Inventory.new(100.0)
	var stack := ItemStack.create_from_definition(_ore_def, 50)
	inv.add_stack(stack)

	var found := inv.find_stack_by_id("iron_ore")
	var split := inv.split_stack(found, 20)

	assert_not_null(split)
	assert_eq(split.count, 20)
	assert_eq(found.count, 30)


func test_inventory_sort() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_potion_def, 5)
	inv.add_items(_ore_def, 30)
	inv.add_items(_sword_def, 1)

	inv.sort()

	# Should be sorted by type (MATERIAL < WEAPON < CONSUMABLE by enum order)
	var stacks := inv.get_all_stacks()
	assert_eq(stacks.size(), 3)


func test_inventory_transfer() -> void:
	var inv1 := Inventory.new(100.0)
	var inv2 := Inventory.new(100.0)

	inv1.add_items(_ore_def, 30)
	var stack := inv1.find_stack_by_id("iron_ore")

	var success := inv1.transfer_to(stack, inv2)
	assert_true(success)
	assert_true(inv1.is_empty())
	assert_eq(inv2.get_item_count("iron_ore"), 30)


func test_inventory_transfer_no_capacity() -> void:
	var inv1 := Inventory.new(100.0)
	var inv2 := Inventory.new(5.0)  # Small capacity

	inv1.add_items(_ore_def, 30)  # 15.0 weight
	var stack := inv1.find_stack_by_id("iron_ore")

	var success := inv1.transfer_to(stack, inv2)
	assert_false(success)  # Can't fit
	assert_eq(inv1.get_item_count("iron_ore"), 30)  # Still in inv1


func test_inventory_clear() -> void:
	var inv := Inventory.new(100.0)
	inv.add_items(_ore_def, 30)
	inv.add_items(_sword_def, 1)

	inv.clear()
	assert_true(inv.is_empty())
	assert_eq(inv.get_current_weight(), 0.0)


func test_inventory_serialization() -> void:
	var inv := Inventory.new(150.0, _registry)
	inv.add_items(_ore_def, 30)
	inv.add_items(_sword_def, 1)

	var dict := inv.to_dict()
	assert_eq(dict["max_weight"], 150.0)
	assert_eq(dict["stacks"].size(), 2)

	var inv2 := Inventory.new(100.0, _registry)
	inv2.from_dict(dict)
	assert_eq(inv2.max_weight, 150.0)
	assert_eq(inv2.get_item_count("iron_ore"), 30)
	assert_eq(inv2.get_item_count("iron_sword"), 1)


func test_inventory_signal() -> void:
	var inv := Inventory.new(100.0)
	watch_signals(inv)

	inv.add_items(_ore_def, 10)
	assert_signal_emitted(inv, "inventory_changed")


# =============================================================================
# Hotbar Tests
# =============================================================================

func test_hotbar_initial_state() -> void:
	var hotbar := Hotbar.new()
	assert_eq(hotbar.SLOT_COUNT, 8)
	assert_eq(hotbar.selected_slot, 0)
	assert_eq(hotbar.get_occupied_count(), 0)


func test_hotbar_set_slot() -> void:
	var hotbar := Hotbar.new()
	var stack := ItemStack.create_from_definition(_sword_def, 1)

	hotbar.set_slot(0, stack)
	assert_eq(hotbar.get_slot(0), stack)
	assert_false(hotbar.is_slot_empty(0))


func test_hotbar_clear_slot() -> void:
	var hotbar := Hotbar.new()
	var stack := ItemStack.create_from_definition(_sword_def, 1)

	hotbar.set_slot(0, stack)
	hotbar.clear_slot(0)
	assert_true(hotbar.is_slot_empty(0))


func test_hotbar_selection() -> void:
	var hotbar := Hotbar.new()

	hotbar.select_slot(3)
	assert_eq(hotbar.selected_slot, 3)

	hotbar.select_next()
	assert_eq(hotbar.selected_slot, 4)

	hotbar.select_previous()
	assert_eq(hotbar.selected_slot, 3)


func test_hotbar_selection_wrap() -> void:
	var hotbar := Hotbar.new()

	hotbar.select_slot(7)
	hotbar.select_next()
	assert_eq(hotbar.selected_slot, 0)  # Wrapped

	hotbar.select_slot(0)
	hotbar.select_previous()
	assert_eq(hotbar.selected_slot, 7)  # Wrapped


func test_hotbar_get_selected() -> void:
	var hotbar := Hotbar.new()
	var stack := ItemStack.create_from_definition(_sword_def, 1)

	hotbar.set_slot(2, stack)
	hotbar.select_slot(2)

	assert_eq(hotbar.get_selected_item(), stack)


func test_hotbar_swap_slots() -> void:
	var hotbar := Hotbar.new()
	var stack1 := ItemStack.create_from_definition(_sword_def, 1)
	var stack2 := ItemStack.create_from_definition(_ore_def, 10)

	hotbar.set_slot(0, stack1)
	hotbar.set_slot(1, stack2)

	hotbar.swap_slots(0, 1)
	assert_eq(hotbar.get_slot(0), stack2)
	assert_eq(hotbar.get_slot(1), stack1)


func test_hotbar_use_slot() -> void:
	var hotbar := Hotbar.new()
	var stack := ItemStack.create_from_definition(_ore_def, 5)

	hotbar.set_slot(0, stack)
	var used := hotbar.use_slot(0)

	assert_not_null(used)
	assert_eq(stack.count, 4)  # One used


func test_hotbar_use_slot_empties() -> void:
	var hotbar := Hotbar.new()
	var stack := ItemStack.create_from_definition(_ore_def, 1)

	hotbar.set_slot(0, stack)
	var used := hotbar.use_slot(0)

	assert_not_null(used)
	assert_true(hotbar.is_slot_empty(0))  # Slot cleared


func test_hotbar_find_slot() -> void:
	var hotbar := Hotbar.new()
	var stack := ItemStack.create_from_definition(_sword_def, 1)

	hotbar.set_slot(3, stack)
	var found := hotbar.find_slot_by_id("iron_sword")

	assert_eq(found, 3)


func test_hotbar_find_empty_slot() -> void:
	var hotbar := Hotbar.new()
	hotbar.set_slot(0, ItemStack.create_from_definition(_sword_def, 1))
	hotbar.set_slot(1, ItemStack.create_from_definition(_ore_def, 10))

	var empty := hotbar.find_empty_slot()
	assert_eq(empty, 2)  # First empty is slot 2


func test_hotbar_auto_assign() -> void:
	var hotbar := Hotbar.new()
	var stack := ItemStack.create_from_definition(_sword_def, 1)

	var slot := hotbar.auto_assign(stack)
	assert_eq(slot, 0)  # First empty slot
	assert_eq(hotbar.get_slot(0), stack)


func test_hotbar_auto_assign_full() -> void:
	var hotbar := Hotbar.new()

	# Fill all slots
	for i in range(Hotbar.SLOT_COUNT):
		hotbar.set_slot(i, ItemStack.create_from_definition(_ore_def, 1))

	var stack := ItemStack.create_from_definition(_sword_def, 1)
	var slot := hotbar.auto_assign(stack)
	assert_eq(slot, -1)  # No empty slots


func test_hotbar_assign_from_inventory() -> void:
	var inv := Inventory.new(100.0)
	var hotbar := Hotbar.new(inv)

	inv.add_items(_sword_def, 1)
	var stack := inv.find_stack_by_id("iron_sword")

	var success := hotbar.assign_from_inventory(stack, 0)
	assert_true(success)
	assert_eq(hotbar.get_slot(0), stack)


func test_hotbar_validate() -> void:
	var inv := Inventory.new(100.0)
	var hotbar := Hotbar.new(inv)

	inv.add_items(_sword_def, 1)
	var stack := inv.find_stack_by_id("iron_sword")
	hotbar.set_slot(0, stack)

	# Remove from inventory
	inv.remove_stack(stack)

	# Validate should clear the slot
	hotbar.validate(inv)
	assert_true(hotbar.is_slot_empty(0))


func test_hotbar_clear() -> void:
	var hotbar := Hotbar.new()

	for i in range(4):
		hotbar.set_slot(i, ItemStack.create_from_definition(_ore_def, 10))

	hotbar.clear()
	assert_eq(hotbar.get_occupied_count(), 0)


func test_hotbar_serialization() -> void:
	var hotbar := Hotbar.new(null, _registry)
	hotbar.set_slot(0, ItemStack.create_from_definition(_sword_def, 1))
	hotbar.set_slot(3, ItemStack.create_from_definition(_ore_def, 20))
	hotbar.select_slot(3)

	var dict := hotbar.to_dict()
	assert_eq(dict["selected"], 3)
	assert_eq(dict["slots"].size(), 2)

	var hotbar2 := Hotbar.new(null, _registry)
	hotbar2.from_dict(dict)
	assert_eq(hotbar2.selected_slot, 3)
	assert_false(hotbar2.is_slot_empty(0))
	assert_false(hotbar2.is_slot_empty(3))
	assert_true(hotbar2.is_slot_empty(1))


func test_hotbar_signal_selection() -> void:
	var hotbar := Hotbar.new()
	watch_signals(hotbar)

	hotbar.select_slot(5)
	assert_signal_emitted(hotbar, "selection_changed")


func test_hotbar_signal_slot_changed() -> void:
	var hotbar := Hotbar.new()
	watch_signals(hotbar)

	hotbar.set_slot(0, ItemStack.create_from_definition(_sword_def, 1))
	assert_signal_emitted(hotbar, "slot_changed")


# =============================================================================
# Integration Tests
# =============================================================================

func test_inventory_hotbar_integration() -> void:
	var inv := Inventory.new(100.0)
	var hotbar := Hotbar.new(inv)

	# Add items to inventory
	inv.add_items(_sword_def, 1)
	inv.add_items(_ore_def, 50)
	inv.add_items(_potion_def, 5)

	# Assign to hotbar
	var sword := inv.find_stack_by_id("iron_sword")
	var ore := inv.find_stack_by_id("iron_ore")
	var potion := inv.find_stack_by_id("health_potion")

	hotbar.set_slot(0, sword)
	hotbar.set_slot(1, ore)
	hotbar.set_slot(2, potion)

	# Use potion from hotbar
	hotbar.select_slot(2)
	var used := hotbar.use_selected()
	assert_not_null(used)
	assert_eq(inv.get_item_count("health_potion"), 4)  # One used

	# Hotbar slot should still reference the same stack
	assert_eq(hotbar.get_slot(2).count, 4)
