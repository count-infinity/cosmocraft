extends GutTest
## Unit tests for the LootGenerator and WorldItemManager classes.


# =============================================================================
# Helper Methods
# =============================================================================

func create_item_registry() -> ItemRegistry:
	var registry := ItemRegistry.new()

	# Register some test items
	var gold := ItemDefinition.new("gold", "Gold Coins", ItemEnums.ItemType.MATERIAL)
	gold.max_stack = 999
	registry.register_item(gold)

	var iron := ItemDefinition.new("iron_ore", "Iron Ore", ItemEnums.ItemType.MATERIAL)
	iron.max_stack = 64
	registry.register_item(iron)

	var sword := ItemDefinition.new("iron_sword", "Iron Sword", ItemEnums.ItemType.WEAPON)
	sword.max_stack = 1
	registry.register_item(sword)

	var potion := ItemDefinition.new("health_potion", "Health Potion", ItemEnums.ItemType.CONSUMABLE)
	potion.max_stack = 16
	registry.register_item(potion)

	return registry


func create_loot_registry() -> LootRegistry:
	var registry := LootRegistry.new()

	# Simple guaranteed drop table
	registry.create_individual_table("simple_loot", [
		{"item_id": "gold", "min_quantity": 5, "max_quantity": 10, "drop_chance": 100.0}
	])

	# Multiple items table
	registry.create_individual_table("multi_loot", [
		{"item_id": "gold", "min_quantity": 1, "max_quantity": 5, "drop_chance": 100.0},
		{"item_id": "iron_ore", "min_quantity": 1, "max_quantity": 3, "drop_chance": 100.0},
		{"item_id": "health_potion", "min_quantity": 1, "max_quantity": 1, "drop_chance": 100.0},
	])

	# Rare drop table
	registry.create_individual_table("rare_loot", [
		{"item_id": "iron_sword", "min_quantity": 1, "max_quantity": 1, "drop_chance": 100.0}
	])

	# Empty result table (0% chance)
	registry.create_individual_table("empty_loot", [
		{"item_id": "gold", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.0}
	])

	return registry


# =============================================================================
# LootGenerator Tests
# =============================================================================

func test_loot_generator_creation() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	assert_not_null(generator)


func test_loot_generator_simple_loot() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var drops := generator.generate_loot("simple_loot", Vector2(100, 100), "player_1")

	assert_eq(drops.size(), 1)
	var world_item: WorldItem = drops[0]
	assert_not_null(world_item.item_stack)
	assert_eq(world_item.item_stack.item.definition.id, "gold")
	assert_gte(world_item.item_stack.count, 5)
	assert_lte(world_item.item_stack.count, 10)
	assert_eq(world_item.owner_id, "player_1")


func test_loot_generator_multi_loot() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var drops := generator.generate_loot("multi_loot", Vector2(100, 100), "player_1")

	assert_eq(drops.size(), 3)

	var item_ids: Array[String] = []
	for drop in drops:
		item_ids.append(drop.item_stack.item.definition.id)

	assert_true("gold" in item_ids)
	assert_true("iron_ore" in item_ids)
	assert_true("health_potion" in item_ids)


func test_loot_generator_empty_loot() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var drops := generator.generate_loot("empty_loot", Vector2(100, 100), "")

	assert_eq(drops.size(), 0)


func test_loot_generator_unknown_table() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var drops := generator.generate_loot("nonexistent", Vector2(100, 100), "")

	assert_eq(drops.size(), 0)


func test_loot_generator_single_item() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var world_item: WorldItem = generator.generate_single_item(
		"gold", 50, Vector2(200, 200), "player_2", 1.0
	)

	assert_not_null(world_item)
	assert_eq(world_item.item_stack.item.definition.id, "gold")
	assert_eq(world_item.item_stack.count, 50)
	assert_eq(world_item.position, Vector2(200, 200))
	assert_eq(world_item.owner_id, "player_2")


func test_loot_generator_single_item_unknown() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var world_item: WorldItem = generator.generate_single_item(
		"nonexistent_item", 1, Vector2(0, 0), "", 1.0
	)

	assert_null(world_item)


func test_loot_generator_drop_positions_spread() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var drops := generator.generate_loot("multi_loot", Vector2(100, 100), "")

	# Multiple drops should have different positions
	assert_eq(drops.size(), 3)

	var positions: Array = []
	for drop in drops:
		positions.append(drop.position)

	# Positions should be spread out (not all identical)
	var all_same := true
	for i in range(1, positions.size()):
		if positions[i] != positions[0]:
			all_same = false
			break

	assert_false(all_same, "Drop positions should be spread out")


func test_loot_generator_from_table_direct() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	# Create an unregistered table
	var table := LootTable.new("temp_table", LootTable.SelectionMode.INDIVIDUAL)
	table.add_item("gold", 100)

	var drops := generator.generate_from_table(table, Vector2(0, 0), "")

	assert_eq(drops.size(), 1)
	assert_eq(drops[0].item_stack.count, 100)


func test_loot_generator_detailed_result() -> void:
	var item_registry := create_item_registry()
	var loot_registry := create_loot_registry()
	var generator := LootGenerator.new(loot_registry, item_registry)

	var result: LootGenerator.LootResult = generator.generate_loot_detailed("multi_loot", Vector2(100, 100), "player_1")

	assert_eq(result.world_items.size(), 3)
	assert_gt(result.item_count, 0)


# =============================================================================
# WorldItemManager Tests
# =============================================================================

func test_world_item_manager_creation() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	assert_eq(manager.get_item_count(), 0)


func test_world_item_manager_add_item() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	var world_item := WorldItem.new("test_id", stack, Vector2(100, 100), "")

	assert_true(manager.add_item(world_item))
	assert_eq(manager.get_item_count(), 1)
	assert_true(manager.has_item("test_id"))


func test_world_item_manager_add_items() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var items: Array = []
	for i in range(5):
		var stack := item_registry.create_item_stack("gold", i + 1)
		items.append(WorldItem.new("item_%d" % i, stack, Vector2(i * 10, 0), ""))

	var added := manager.add_items(items)
	assert_eq(added, 5)
	assert_eq(manager.get_item_count(), 5)


func test_world_item_manager_remove_item() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	var world_item := WorldItem.new("remove_me", stack, Vector2(0, 0), "")

	manager.add_item(world_item)
	assert_true(manager.has_item("remove_me"))

	var removed: WorldItem = manager.remove_item("remove_me")
	assert_not_null(removed)
	assert_eq(removed.id, "remove_me")
	assert_false(manager.has_item("remove_me"))


func test_world_item_manager_get_item() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("iron_ore", 5)
	var world_item := WorldItem.new("my_item", stack, Vector2(50, 50), "owner_1")

	manager.add_item(world_item)

	var retrieved: WorldItem = manager.get_item("my_item")
	assert_not_null(retrieved)
	assert_eq(retrieved.position, Vector2(50, 50))
	assert_eq(retrieved.owner_id, "owner_1")


func test_world_item_manager_get_all_items() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	for i in range(3):
		var stack := item_registry.create_item_stack("gold", 1)
		manager.add_item(WorldItem.new("item_%d" % i, stack, Vector2.ZERO, ""))

	var all_items := manager.get_all_items()
	assert_eq(all_items.size(), 3)


func test_world_item_manager_get_items_in_radius() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	# Add items at various positions
	for i in range(5):
		var stack := item_registry.create_item_stack("gold", 1)
		var pos := Vector2(i * 30, 0)  # 0, 30, 60, 90, 120
		manager.add_item(WorldItem.new("item_%d" % i, stack, pos, ""))

	# Get items within 50 pixels of origin
	var nearby := manager.get_items_in_radius(Vector2.ZERO, 50.0)
	assert_eq(nearby.size(), 2)  # 0 and 30 are within 50


func test_world_item_manager_get_pickupable_items() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	# Add item within pickup range
	var stack1 := item_registry.create_item_stack("gold", 10)
	var item1 := WorldItem.new("close_item", stack1, Vector2(20, 0), "")
	manager.add_item(item1)

	# Add item outside pickup range
	var stack2 := item_registry.create_item_stack("gold", 10)
	var item2 := WorldItem.new("far_item", stack2, Vector2(100, 0), "")
	manager.add_item(item2)

	var pickupable := manager.get_pickupable_items("player_1", Vector2.ZERO)
	assert_eq(pickupable.size(), 1)
	assert_eq(pickupable[0].id, "close_item")


func test_world_item_manager_try_pickup_success() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 25)
	var world_item := WorldItem.new("pickup_me", stack, Vector2(10, 0), "")
	manager.add_item(world_item)

	var picked: WorldItem = manager.try_pickup("pickup_me", "player_1", Vector2.ZERO)

	assert_not_null(picked)
	assert_eq(picked.id, "pickup_me")
	assert_eq(picked.item_stack.count, 25)
	assert_false(manager.has_item("pickup_me"))


func test_world_item_manager_try_pickup_too_far() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	var world_item := WorldItem.new("far_item", stack, Vector2(100, 100), "")
	manager.add_item(world_item)

	var picked: WorldItem = manager.try_pickup("far_item", "player_1", Vector2.ZERO)

	assert_null(picked)
	assert_true(manager.has_item("far_item"))


func test_world_item_manager_try_pickup_protected() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	var world_item := WorldItem.new("protected_item", stack, Vector2(10, 0), "owner_player")
	manager.add_item(world_item)

	# Different player tries to pick up
	var picked: WorldItem = manager.try_pickup("protected_item", "other_player", Vector2.ZERO)

	assert_null(picked)
	assert_true(manager.has_item("protected_item"))


func test_world_item_manager_try_pickup_owner_success() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	var world_item := WorldItem.new("my_item", stack, Vector2(10, 0), "owner_player")
	manager.add_item(world_item)

	# Owner can pick up
	var picked: WorldItem = manager.try_pickup("my_item", "owner_player", Vector2.ZERO)

	assert_not_null(picked)
	assert_eq(picked.id, "my_item")


func test_world_item_manager_spawn_item() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var world_item: WorldItem = manager.spawn_item("gold", 50, Vector2(200, 200), "spawner", 1.0)

	assert_not_null(world_item)
	assert_eq(world_item.item_stack.count, 50)
	assert_eq(world_item.position, Vector2(200, 200))
	assert_eq(world_item.owner_id, "spawner")
	assert_true(manager.has_item(world_item.id))


func test_world_item_manager_spawn_unknown_item() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var world_item: WorldItem = manager.spawn_item("nonexistent", 1, Vector2.ZERO, "", 1.0)

	assert_null(world_item)
	assert_eq(manager.get_item_count(), 0)


func test_world_item_manager_clear() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	for i in range(5):
		var stack := item_registry.create_item_stack("gold", 1)
		manager.add_item(WorldItem.new("item_%d" % i, stack, Vector2.ZERO, ""))

	assert_eq(manager.get_item_count(), 5)

	manager.clear()

	assert_eq(manager.get_item_count(), 0)


func test_world_item_manager_get_state_data() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	for i in range(3):
		var stack := item_registry.create_item_stack("gold", i + 1)
		manager.add_item(WorldItem.new("item_%d" % i, stack, Vector2(i * 10, 0), ""))

	var state := manager.get_state_data()
	assert_eq(state.size(), 3)

	# Each entry should be a dictionary
	for entry in state:
		assert_true(entry is Dictionary)
		assert_true(entry.has("id"))
		assert_true(entry.has("position"))


func test_world_item_manager_detailed_pickup_success() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	manager.add_item(WorldItem.new("test_item", stack, Vector2(10, 0), ""))

	var result: WorldItemManager.PickupResult = manager.try_pickup_detailed("test_item", "player_1", Vector2.ZERO)

	assert_true(result.success)
	assert_not_null(result.item)
	assert_eq(result.item.id, "test_item")


func test_world_item_manager_detailed_pickup_not_found() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var result: WorldItemManager.PickupResult = manager.try_pickup_detailed("nonexistent", "player_1", Vector2.ZERO)

	assert_false(result.success)
	assert_null(result.item)
	assert_eq(result.reason, "Item not found")


func test_world_item_manager_detailed_pickup_protected() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	manager.add_item(WorldItem.new("protected", stack, Vector2(10, 0), "owner"))

	var result: WorldItemManager.PickupResult = manager.try_pickup_detailed("protected", "other_player", Vector2.ZERO)

	assert_false(result.success)
	assert_eq(result.reason, "Item is protected")


func test_world_item_manager_detailed_pickup_too_far() -> void:
	var item_registry := create_item_registry()
	var manager := WorldItemManager.new(item_registry)

	var stack := item_registry.create_item_stack("gold", 10)
	manager.add_item(WorldItem.new("far", stack, Vector2(100, 100), ""))

	var result: WorldItemManager.PickupResult = manager.try_pickup_detailed("far", "player_1", Vector2.ZERO)

	assert_false(result.success)
	assert_eq(result.reason, "Too far away")
