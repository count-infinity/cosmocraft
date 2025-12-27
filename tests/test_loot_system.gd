extends GutTest
## Unit tests for the loot system (LootEntry, LootTable, LootRegistry).


# =============================================================================
# LootEntry Tests
# =============================================================================

func test_loot_entry_creation() -> void:
	var entry := LootEntry.new("iron_ore", 1, 5, 50.0, 2.0)
	assert_eq(entry.item_id, "iron_ore")
	assert_eq(entry.min_quantity, 1)
	assert_eq(entry.max_quantity, 5)
	assert_eq(entry.drop_chance, 50.0)
	assert_eq(entry.weight, 2.0)


func test_loot_entry_defaults() -> void:
	var entry := LootEntry.new()
	assert_eq(entry.item_id, "")
	assert_eq(entry.min_quantity, 1)
	assert_eq(entry.max_quantity, 1)
	assert_eq(entry.drop_chance, 100.0)
	assert_eq(entry.weight, 1.0)


func test_loot_entry_min_clamp() -> void:
	var entry := LootEntry.new("test", -5, -3, -10.0, -2.0)
	assert_eq(entry.min_quantity, 1)  # Min clamp
	assert_eq(entry.max_quantity, 1)  # Max >= min
	assert_eq(entry.drop_chance, 0.0)  # Clamp 0-100
	assert_eq(entry.weight, 0.0)  # Min 0


func test_loot_entry_max_clamp() -> void:
	var entry := LootEntry.new("test", 1, 1, 150.0, 1.0)
	assert_eq(entry.drop_chance, 100.0)  # Clamp max


func test_loot_entry_roll_drop_guaranteed() -> void:
	var entry := LootEntry.new("test", 1, 1, 100.0)
	# 100% should always drop
	for _i in range(10):
		assert_true(entry.roll_drop())


func test_loot_entry_roll_drop_never() -> void:
	var entry := LootEntry.new("test", 1, 1, 0.0)
	# 0% should never drop
	for _i in range(10):
		assert_false(entry.roll_drop())


func test_loot_entry_roll_quantity_fixed() -> void:
	var entry := LootEntry.new("test", 5, 5, 100.0)
	# Fixed quantity should always be 5
	for _i in range(10):
		assert_eq(entry.roll_quantity(), 5)


func test_loot_entry_roll_quantity_range() -> void:
	var entry := LootEntry.new("test", 1, 10, 100.0)
	# Range should be within bounds
	for _i in range(20):
		var qty := entry.roll_quantity()
		assert_gte(qty, 1)
		assert_lte(qty, 10)


func test_loot_entry_is_valid() -> void:
	var valid := LootEntry.new("iron_ore", 1, 1, 100.0)
	var invalid := LootEntry.new("", 1, 1, 100.0)
	assert_true(valid.is_valid())
	assert_false(invalid.is_valid())


func test_loot_entry_quality_range() -> void:
	var entry := LootEntry.new("test")
	entry.set_quality_range(0.8, 1.2)
	assert_eq(entry.min_quality, 0.8)
	assert_eq(entry.max_quality, 1.2)
	# Roll should be in range
	for _i in range(10):
		var quality := entry.roll_quality()
		assert_gte(quality, 0.8)
		assert_lte(quality, 1.2)


func test_loot_entry_quality_clamp() -> void:
	var entry := LootEntry.new("test")
	entry.set_quality_range(0.1, 2.0)
	assert_eq(entry.min_quality, 0.6)  # Clamp min
	assert_eq(entry.max_quality, 1.25)  # Clamp max


func test_loot_entry_serialization() -> void:
	var entry := LootEntry.new("gold", 5, 10, 75.0, 3.0)
	entry.set_quality_range(0.9, 1.1)

	var data := entry.to_dict()
	var restored := LootEntry.from_dict(data)

	assert_eq(restored.item_id, "gold")
	assert_eq(restored.min_quantity, 5)
	assert_eq(restored.max_quantity, 10)
	assert_eq(restored.drop_chance, 75.0)
	assert_eq(restored.weight, 3.0)
	assert_eq(restored.min_quality, 0.9)
	assert_eq(restored.max_quality, 1.1)


func test_loot_entry_simple_factory() -> void:
	var entry := LootEntry.simple("test_item", 3)
	assert_eq(entry.item_id, "test_item")
	assert_eq(entry.min_quantity, 3)
	assert_eq(entry.max_quantity, 3)
	assert_eq(entry.drop_chance, 100.0)


func test_loot_entry_with_chance_factory() -> void:
	var entry := LootEntry.with_chance("rare_drop", 5.0, 1)
	assert_eq(entry.item_id, "rare_drop")
	assert_eq(entry.drop_chance, 5.0)


func test_loot_entry_with_range_factory() -> void:
	var entry := LootEntry.with_range("coins", 10, 50, 80.0)
	assert_eq(entry.item_id, "coins")
	assert_eq(entry.min_quantity, 10)
	assert_eq(entry.max_quantity, 50)
	assert_eq(entry.drop_chance, 80.0)


# =============================================================================
# LootTable Tests
# =============================================================================

func test_loot_table_creation() -> void:
	var table := LootTable.new("test_table", LootTable.SelectionMode.INDIVIDUAL)
	assert_eq(table.id, "test_table")
	assert_eq(table.selection_mode, LootTable.SelectionMode.INDIVIDUAL)
	assert_true(table.is_empty())


func test_loot_table_add_entry() -> void:
	var table := LootTable.new("test")
	table.add_entry(LootEntry.simple("item1", 1))
	table.add_entry(LootEntry.simple("item2", 2))
	assert_eq(table.get_entry_count(), 2)
	assert_false(table.is_empty())


func test_loot_table_add_item() -> void:
	var table := LootTable.new("test")
	table.add_item("simple_item", 5)
	assert_eq(table.get_entry_count(), 1)
	var entry: LootEntry = table.get_entry(0)
	assert_eq(entry.item_id, "simple_item")
	assert_eq(entry.min_quantity, 5)
	assert_eq(entry.drop_chance, 100.0)


func test_loot_table_add_item_chance() -> void:
	var table := LootTable.new("test")
	table.add_item_chance("rare_item", 10.0, 1)
	var entry: LootEntry = table.get_entry(0)
	assert_eq(entry.item_id, "rare_item")
	assert_eq(entry.drop_chance, 10.0)


func test_loot_table_add_item_range() -> void:
	var table := LootTable.new("test")
	table.add_item_range("coins", 5, 25, 90.0)
	var entry: LootEntry = table.get_entry(0)
	assert_eq(entry.item_id, "coins")
	assert_eq(entry.min_quantity, 5)
	assert_eq(entry.max_quantity, 25)
	assert_eq(entry.drop_chance, 90.0)


func test_loot_table_add_weighted_item() -> void:
	var table := LootTable.new("test")
	table.add_weighted_item("heavy_weight", 5.0, 1)
	var entry: LootEntry = table.get_entry(0)
	assert_eq(entry.item_id, "heavy_weight")
	assert_eq(entry.weight, 5.0)


func test_loot_table_fluent_api() -> void:
	var table := LootTable.new("test")
	table.add_item("a").add_item("b").add_item("c")
	assert_eq(table.get_entry_count(), 3)


func test_loot_table_roll_individual_guaranteed() -> void:
	var table := LootTable.new("test", LootTable.SelectionMode.INDIVIDUAL)
	table.add_item("item1", 1)
	table.add_item("item2", 2)

	var drops := table.roll()
	assert_eq(drops.size(), 2)
	assert_eq(drops[0].item_id, "item1")
	assert_eq(drops[1].item_id, "item2")


func test_loot_table_roll_individual_zero_chance() -> void:
	var table := LootTable.new("test", LootTable.SelectionMode.INDIVIDUAL)
	table.add_item_chance("never", 0.0, 1)

	var drops := table.roll()
	assert_eq(drops.size(), 0)


func test_loot_table_roll_weighted_single() -> void:
	var table := LootTable.new("test", LootTable.SelectionMode.WEIGHTED)
	table.num_rolls = 1
	table.add_weighted_item("only_item", 1.0, 1)

	var drops := table.roll()
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].item_id, "only_item")


func test_loot_table_roll_weighted_multiple() -> void:
	var table := LootTable.new("test", LootTable.SelectionMode.WEIGHTED)
	table.num_rolls = 3
	table.allow_duplicates = true
	table.add_weighted_item("item1", 1.0, 1)
	table.add_weighted_item("item2", 1.0, 1)

	var drops := table.roll()
	assert_eq(drops.size(), 3)
	for drop in drops:
		assert_true(drop.item_id in ["item1", "item2"])


func test_loot_table_roll_weighted_no_duplicates() -> void:
	var table := LootTable.new("test", LootTable.SelectionMode.WEIGHTED)
	table.num_rolls = 3
	table.allow_duplicates = false
	table.add_weighted_item("item1", 1.0, 1)
	table.add_weighted_item("item2", 1.0, 1)
	table.add_weighted_item("item3", 1.0, 1)

	var drops := table.roll()
	assert_eq(drops.size(), 3)

	# Check all unique
	var ids: Array[String] = []
	for drop in drops:
		assert_false(drop.item_id in ids, "Duplicate found: " + drop.item_id)
		ids.append(drop.item_id)


func test_loot_table_roll_weighted_limited_by_entries() -> void:
	var table := LootTable.new("test", LootTable.SelectionMode.WEIGHTED)
	table.num_rolls = 5
	table.allow_duplicates = false
	table.add_weighted_item("item1", 1.0, 1)
	table.add_weighted_item("item2", 1.0, 1)

	var drops := table.roll()
	# Only 2 unique items available, so max 2 drops
	assert_eq(drops.size(), 2)


func test_loot_table_total_weight() -> void:
	var table := LootTable.new("test")
	table.add_weighted_item("a", 1.0, 1)
	table.add_weighted_item("b", 2.5, 1)
	table.add_weighted_item("c", 0.5, 1)
	assert_eq(table.get_total_weight(), 4.0)


func test_loot_table_remove_entry() -> void:
	var table := LootTable.new("test")
	table.add_item("a").add_item("b").add_item("c")
	assert_eq(table.get_entry_count(), 3)

	assert_true(table.remove_entry(1))
	assert_eq(table.get_entry_count(), 2)
	assert_eq(table.get_entry(0).item_id, "a")
	assert_eq(table.get_entry(1).item_id, "c")


func test_loot_table_is_valid() -> void:
	var empty := LootTable.new("empty")
	var no_id := LootTable.new("")
	no_id.add_item("test")
	var valid := LootTable.new("valid")
	valid.add_item("test")

	assert_false(empty.is_valid())
	assert_false(no_id.is_valid())
	assert_true(valid.is_valid())


func test_loot_table_serialization() -> void:
	var table := LootTable.new("test_table", LootTable.SelectionMode.WEIGHTED)
	table.display_name = "Test Table"
	table.num_rolls = 3
	table.allow_duplicates = false
	table.add_weighted_item("item1", 2.0, 1)
	table.add_weighted_item("item2", 3.0, 5)

	var data := table.to_dict()
	var restored := LootTable.from_dict(data)

	assert_eq(restored.id, "test_table")
	assert_eq(restored.display_name, "Test Table")
	assert_eq(restored.selection_mode, LootTable.SelectionMode.WEIGHTED)
	assert_eq(restored.num_rolls, 3)
	assert_false(restored.allow_duplicates)
	assert_eq(restored.get_entry_count(), 2)
	assert_eq(restored.get_entry(0).item_id, "item1")
	assert_eq(restored.get_entry(1).weight, 3.0)


# =============================================================================
# LootRegistry Tests
# =============================================================================

func test_loot_registry_register() -> void:
	var registry := LootRegistry.new()
	var table := LootTable.new("test_table")
	table.add_item("item")

	registry.register(table)
	assert_true(registry.has_table("test_table"))
	assert_eq(registry.get_table_count(), 1)


func test_loot_registry_register_empty_id() -> void:
	var registry := LootRegistry.new()
	var table := LootTable.new("")

	registry.register(table)
	assert_eq(registry.get_table_count(), 0)


func test_loot_registry_unregister() -> void:
	var registry := LootRegistry.new()
	var table := LootTable.new("test")
	table.add_item("item")

	registry.register(table)
	assert_true(registry.has_table("test"))

	assert_true(registry.unregister("test"))
	assert_false(registry.has_table("test"))


func test_loot_registry_get_table() -> void:
	var registry := LootRegistry.new()
	var table := LootTable.new("my_table")
	table.add_item("gold")

	registry.register(table)

	var retrieved: LootTable = registry.get_table("my_table")
	assert_not_null(retrieved)
	assert_eq(retrieved.id, "my_table")
	assert_eq(retrieved.get_entry(0).item_id, "gold")


func test_loot_registry_get_all_ids() -> void:
	var registry := LootRegistry.new()
	registry.register(LootTable.new("table_a"))
	registry.register(LootTable.new("table_b"))
	registry.register(LootTable.new("table_c"))

	# Need to add items for tables to be valid
	registry.get_table("table_a").add_item("a")
	registry.get_table("table_b").add_item("b")
	registry.get_table("table_c").add_item("c")

	var ids := registry.get_all_ids()
	assert_eq(ids.size(), 3)
	assert_true("table_a" in ids)
	assert_true("table_b" in ids)
	assert_true("table_c" in ids)


func test_loot_registry_roll_table() -> void:
	var registry := LootRegistry.new()
	var table := LootTable.new("test", LootTable.SelectionMode.INDIVIDUAL)
	table.add_item("guaranteed_item", 1)

	registry.register(table)

	var drops := registry.roll_table("test")
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].item_id, "guaranteed_item")


func test_loot_registry_roll_unknown_table() -> void:
	var registry := LootRegistry.new()
	var drops := registry.roll_table("nonexistent")
	assert_eq(drops.size(), 0)


func test_loot_registry_create_individual_table() -> void:
	var registry := LootRegistry.new()

	var items := [
		{"item_id": "gold", "min_quantity": 5, "max_quantity": 10, "drop_chance": 100.0},
		{"item_id": "gem", "min_quantity": 1, "max_quantity": 1, "drop_chance": 10.0},
	]

	var table: LootTable = registry.create_individual_table("treasure", items)

	assert_true(registry.has_table("treasure"))
	assert_eq(table.get_entry_count(), 2)
	assert_eq(table.selection_mode, LootTable.SelectionMode.INDIVIDUAL)


func test_loot_registry_create_weighted_table() -> void:
	var registry := LootRegistry.new()

	var items := [
		{"item_id": "common", "weight": 10.0},
		{"item_id": "rare", "weight": 1.0},
	]

	var table: LootTable = registry.create_weighted_table("loot_pool", items, 2, false)

	assert_true(registry.has_table("loot_pool"))
	assert_eq(table.get_entry_count(), 2)
	assert_eq(table.selection_mode, LootTable.SelectionMode.WEIGHTED)
	assert_eq(table.num_rolls, 2)
	assert_false(table.allow_duplicates)


func test_loot_registry_clear() -> void:
	var registry := LootRegistry.new()
	registry.register(LootTable.new("a"))
	registry.register(LootTable.new("b"))

	registry.clear()

	assert_eq(registry.get_table_count(), 0)


func test_loot_registry_serialization() -> void:
	var registry := LootRegistry.new()
	registry.create_individual_table("table1", [
		{"item_id": "item1", "drop_chance": 100.0}
	])
	registry.create_individual_table("table2", [
		{"item_id": "item2", "drop_chance": 50.0}
	])

	var data := registry.to_dict()

	var restored := LootRegistry.new()
	restored.from_dict(data)

	assert_eq(restored.get_table_count(), 2)
	assert_true(restored.has_table("table1"))
	assert_true(restored.has_table("table2"))
