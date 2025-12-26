extends GutTest
## Tests for the crafting system (Phase 4).
## Tests RecipeDefinition and CraftingSystem classes.


var _item_registry: ItemRegistry
var _crafting_system: CraftingSystem
var _inventory: Inventory


# Test item definitions
var _iron_ore: ItemDefinition
var _iron_ingot: ItemDefinition
var _iron_sword: ItemDefinition
var _coal: ItemDefinition
var _steel_ingot: ItemDefinition
var _advanced_sword: ItemDefinition


func before_each() -> void:
	# Create item registry
	_item_registry = ItemRegistry.new()

	# Create test items
	_iron_ore = ItemDefinition.new()
	_iron_ore.id = "iron_ore"
	_iron_ore.name = "Iron Ore"
	_iron_ore.type = ItemEnums.ItemType.MATERIAL
	_iron_ore.weight = 1.0
	_iron_ore.max_stack = 99
	_item_registry.register_item(_iron_ore)

	_coal = ItemDefinition.new()
	_coal.id = "coal"
	_coal.name = "Coal"
	_coal.type = ItemEnums.ItemType.MATERIAL
	_coal.weight = 0.5
	_coal.max_stack = 99
	_item_registry.register_item(_coal)

	_iron_ingot = ItemDefinition.new()
	_iron_ingot.id = "iron_ingot"
	_iron_ingot.name = "Iron Ingot"
	_iron_ingot.type = ItemEnums.ItemType.MATERIAL
	_iron_ingot.weight = 2.0
	_iron_ingot.max_stack = 50
	_item_registry.register_item(_iron_ingot)

	_steel_ingot = ItemDefinition.new()
	_steel_ingot.id = "steel_ingot"
	_steel_ingot.name = "Steel Ingot"
	_steel_ingot.type = ItemEnums.ItemType.MATERIAL
	_steel_ingot.weight = 2.5
	_steel_ingot.max_stack = 50
	_item_registry.register_item(_steel_ingot)

	_iron_sword = ItemDefinition.new()
	_iron_sword.id = "iron_sword"
	_iron_sword.name = "Iron Sword"
	_iron_sword.type = ItemEnums.ItemType.WEAPON
	_iron_sword.weight = 5.0
	_iron_sword.max_stack = 1
	_item_registry.register_item(_iron_sword)

	_advanced_sword = ItemDefinition.new()
	_advanced_sword.id = "advanced_sword"
	_advanced_sword.name = "Advanced Sword"
	_advanced_sword.type = ItemEnums.ItemType.WEAPON
	_advanced_sword.weight = 4.0
	_advanced_sword.max_stack = 1
	_item_registry.register_item(_advanced_sword)

	# Create crafting system and inventory
	_crafting_system = CraftingSystem.new(_item_registry)
	_inventory = Inventory.new(100.0, _item_registry)


func after_each() -> void:
	_item_registry = null
	_crafting_system = null
	_inventory = null


# ====================
# RecipeDefinition Tests
# ====================

func test_recipe_creation() -> void:
	var recipe := RecipeDefinition.new("smelt_iron", "Smelt Iron")
	assert_eq(recipe.id, "smelt_iron")
	assert_eq(recipe.name, "Smelt Iron")


func test_recipe_add_inputs() -> void:
	var recipe := RecipeDefinition.new()
	recipe.add_input("iron_ore", 2)
	recipe.add_input("coal", 1)

	assert_eq(recipe.inputs.size(), 2)
	assert_eq(recipe.get_input_count("iron_ore"), 2)
	assert_eq(recipe.get_input_count("coal"), 1)
	assert_eq(recipe.get_input_count("unknown"), 0)


func test_recipe_add_outputs() -> void:
	var recipe := RecipeDefinition.new()
	recipe.add_output("iron_ingot", 1)

	assert_eq(recipe.outputs.size(), 1)
	assert_eq(recipe.get_primary_output_id(), "iron_ingot")
	assert_eq(recipe.get_primary_output_count(), 1)


func test_recipe_requires_item() -> void:
	var recipe := RecipeDefinition.new()
	recipe.add_input("iron_ore", 2)
	recipe.add_input("coal", 1)

	assert_true(recipe.requires_item("iron_ore"))
	assert_true(recipe.requires_item("coal"))
	assert_false(recipe.requires_item("gold_ore"))


func test_recipe_station_requirement() -> void:
	var recipe := RecipeDefinition.new()
	recipe.station_type = "furnace"

	assert_true(recipe.requires_station())
	assert_true(recipe.can_craft_at_station("furnace"))
	assert_false(recipe.can_craft_at_station("anvil"))
	assert_false(recipe.can_craft_at_station(""))


func test_recipe_no_station_required() -> void:
	var recipe := RecipeDefinition.new()
	# station_type is empty by default

	assert_false(recipe.requires_station())
	assert_true(recipe.can_craft_at_station(""))
	assert_true(recipe.can_craft_at_station("anywhere"))


func test_recipe_get_required_item_ids() -> void:
	var recipe := RecipeDefinition.new()
	recipe.add_input("iron_ore", 2)
	recipe.add_input("coal", 1)
	recipe.add_input("iron_ore", 1)  # Duplicate

	var ids := recipe.get_required_item_ids()
	assert_eq(ids.size(), 2)  # Should deduplicate
	assert_true("iron_ore" in ids)
	assert_true("coal" in ids)


func test_recipe_serialization() -> void:
	var recipe := RecipeDefinition.new()
	recipe.id = "test_recipe"
	recipe.name = "Test Recipe"
	recipe.description = "A test recipe"
	recipe.category = "tools"
	recipe.station_type = "workbench"
	recipe.add_input("iron_ore", 2)
	recipe.add_output("iron_ingot", 1)
	recipe.required_skill = "smithing"
	recipe.required_skill_level = 5
	recipe.xp_reward = 25
	recipe.craft_time = 2.5
	recipe.discovered_by_default = false
	recipe.blueprint_id = "blueprint_test"
	recipe.tier = 2

	var data := recipe.to_dict()
	var restored := RecipeDefinition.from_dict(data)

	assert_eq(restored.id, "test_recipe")
	assert_eq(restored.name, "Test Recipe")
	assert_eq(restored.description, "A test recipe")
	assert_eq(restored.category, "tools")
	assert_eq(restored.station_type, "workbench")
	assert_eq(restored.inputs.size(), 1)
	assert_eq(restored.outputs.size(), 1)
	assert_eq(restored.required_skill, "smithing")
	assert_eq(restored.required_skill_level, 5)
	assert_eq(restored.xp_reward, 25)
	assert_eq(restored.craft_time, 2.5)
	assert_eq(restored.discovered_by_default, false)
	assert_eq(restored.blueprint_id, "blueprint_test")
	assert_eq(restored.tier, 2)


# ====================
# CraftingSystem Registration Tests
# ====================

func test_register_recipe() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	assert_eq(_crafting_system.get_recipe_count(), 1)
	assert_eq(_crafting_system.get_recipe("smelt_iron"), recipe)


func test_get_all_recipes() -> void:
	_crafting_system.register_recipe(_create_smelt_iron_recipe())
	_crafting_system.register_recipe(_create_iron_sword_recipe())

	var recipes := _crafting_system.get_all_recipes()
	assert_eq(recipes.size(), 2)


func test_get_recipes_by_category() -> void:
	var smelt := _create_smelt_iron_recipe()
	smelt.category = "smelting"
	_crafting_system.register_recipe(smelt)

	var sword := _create_iron_sword_recipe()
	sword.category = "weapons"
	_crafting_system.register_recipe(sword)

	var smelting_recipes := _crafting_system.get_recipes_by_category("smelting")
	assert_eq(smelting_recipes.size(), 1)
	assert_eq(smelting_recipes[0].id, "smelt_iron")


func test_get_categories() -> void:
	var smelt := _create_smelt_iron_recipe()
	smelt.category = "smelting"
	_crafting_system.register_recipe(smelt)

	var sword := _create_iron_sword_recipe()
	sword.category = "weapons"
	_crafting_system.register_recipe(sword)

	var categories := _crafting_system.get_categories()
	assert_eq(categories.size(), 2)
	assert_true("smelting" in categories)
	assert_true("weapons" in categories)


func test_get_recipes_for_item() -> void:
	_crafting_system.register_recipe(_create_smelt_iron_recipe())
	_crafting_system.register_recipe(_create_iron_sword_recipe())

	var ingot_recipes := _crafting_system.get_recipes_for_item("iron_ingot")
	assert_eq(ingot_recipes.size(), 1)
	assert_eq(ingot_recipes[0].id, "smelt_iron")


# ====================
# Recipe Discovery Tests
# ====================

func test_recipe_discovered_by_default() -> void:
	var recipe := _create_smelt_iron_recipe()
	recipe.discovered_by_default = true
	_crafting_system.register_recipe(recipe)

	assert_true(_crafting_system.is_recipe_discovered("smelt_iron"))


func test_recipe_not_discovered_by_default() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.discovered_by_default = false
	_crafting_system.register_recipe(recipe)

	assert_false(_crafting_system.is_recipe_discovered("craft_iron_sword"))


func test_discover_recipe() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.discovered_by_default = false
	_crafting_system.register_recipe(recipe)

	assert_false(_crafting_system.is_recipe_discovered("craft_iron_sword"))

	var success := _crafting_system.discover_recipe("craft_iron_sword")
	assert_true(success)
	assert_true(_crafting_system.is_recipe_discovered("craft_iron_sword"))


func test_discover_from_blueprint() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.discovered_by_default = false
	recipe.blueprint_id = "sword_blueprint"
	_crafting_system.register_recipe(recipe)

	var discovered := _crafting_system.discover_from_blueprint("sword_blueprint")
	assert_eq(discovered, recipe)
	assert_true(_crafting_system.is_recipe_discovered("craft_iron_sword"))


func test_get_discovered_recipes() -> void:
	var smelt := _create_smelt_iron_recipe()
	smelt.discovered_by_default = true
	_crafting_system.register_recipe(smelt)

	var sword := _create_iron_sword_recipe()
	sword.discovered_by_default = false
	_crafting_system.register_recipe(sword)

	var discovered := _crafting_system.get_discovered_recipes()
	assert_eq(discovered.size(), 1)
	assert_eq(discovered[0].id, "smelt_iron")


# ====================
# Crafting Requirement Tests
# ====================

func test_has_materials_true() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 5)
	_inventory.add_items(_coal, 2)

	assert_true(_crafting_system.has_materials(recipe, _inventory))


func test_has_materials_false() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 1)  # Need 2
	_inventory.add_items(_coal, 2)

	assert_false(_crafting_system.has_materials(recipe, _inventory))


func test_has_skill_requirement_no_skill() -> void:
	var recipe := _create_smelt_iron_recipe()
	# No required_skill set

	assert_true(_crafting_system.has_skill_requirement(recipe, {}))


func test_has_skill_requirement_met() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.required_skill = "smithing"
	recipe.required_skill_level = 5

	var skills := {"smithing": 10}
	assert_true(_crafting_system.has_skill_requirement(recipe, skills))


func test_has_skill_requirement_not_met() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.required_skill = "smithing"
	recipe.required_skill_level = 5

	var skills := {"smithing": 3}
	assert_false(_crafting_system.has_skill_requirement(recipe, skills))


func test_at_correct_station_no_requirement() -> void:
	var recipe := _create_smelt_iron_recipe()
	recipe.station_type = ""

	assert_true(_crafting_system.at_correct_station(recipe, ""))
	assert_true(_crafting_system.at_correct_station(recipe, "furnace"))


func test_at_correct_station_match() -> void:
	var recipe := _create_smelt_iron_recipe()
	recipe.station_type = "furnace"

	assert_true(_crafting_system.at_correct_station(recipe, "furnace"))


func test_at_correct_station_mismatch() -> void:
	var recipe := _create_smelt_iron_recipe()
	recipe.station_type = "furnace"

	assert_false(_crafting_system.at_correct_station(recipe, "anvil"))
	assert_false(_crafting_system.at_correct_station(recipe, ""))


func test_get_craft_error_success() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 5)
	_inventory.add_items(_coal, 2)

	var error := _crafting_system.get_craft_error(recipe, _inventory, {}, "")
	assert_eq(error, "")


func test_get_craft_error_not_discovered() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.discovered_by_default = false
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ingot, 5)

	var error := _crafting_system.get_craft_error(recipe, _inventory, {}, "")
	assert_eq(error, "Recipe not discovered")


func test_get_craft_error_wrong_station() -> void:
	var recipe := _create_smelt_iron_recipe()
	recipe.station_type = "furnace"
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 5)
	_inventory.add_items(_coal, 2)

	var error := _crafting_system.get_craft_error(recipe, _inventory, {}, "anvil")
	assert_eq(error, "Requires furnace station")


func test_get_craft_error_missing_skill() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.required_skill = "smithing"
	recipe.required_skill_level = 10
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ingot, 5)

	var error := _crafting_system.get_craft_error(recipe, _inventory, {"smithing": 5}, "")
	assert_eq(error, "Requires smithing level 10")


func test_get_craft_error_missing_materials() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 1)  # Need 2

	var error := _crafting_system.get_craft_error(recipe, _inventory, {}, "")
	assert_eq(error, "Missing materials")


func test_can_craft_true() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 5)
	_inventory.add_items(_coal, 2)

	assert_true(_crafting_system.can_craft(recipe, _inventory, {}, ""))


func test_can_craft_false() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	# Empty inventory
	assert_false(_crafting_system.can_craft(recipe, _inventory, {}, ""))


# ====================
# Crafting Execution Tests
# ====================

func test_craft_success() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 5)
	_inventory.add_items(_coal, 2)

	var outputs := _crafting_system.craft(recipe, _inventory, {}, "")

	assert_eq(outputs.size(), 1)
	assert_eq(outputs[0].item.definition.id, "iron_ingot")
	assert_eq(outputs[0].count, 1)

	# Check materials consumed
	assert_eq(_inventory.get_item_count("iron_ore"), 3)  # 5 - 2
	assert_eq(_inventory.get_item_count("coal"), 1)  # 2 - 1

	# Check output added
	assert_eq(_inventory.get_item_count("iron_ingot"), 1)


func test_craft_failure_no_materials() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	var outputs := _crafting_system.craft(recipe, _inventory, {}, "")
	assert_eq(outputs.size(), 0)


func test_craft_consumes_exact_materials() -> void:
	var recipe := _create_iron_sword_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ingot, 3)  # Exactly what's needed

	var outputs := _crafting_system.craft(recipe, _inventory, {}, "")

	assert_eq(outputs.size(), 1)
	assert_eq(_inventory.get_item_count("iron_ingot"), 0)  # All consumed


func test_craft_multiple_outputs() -> void:
	var recipe := RecipeDefinition.new()
	recipe.id = "multi_output"
	recipe.name = "Multi Output"
	recipe.discovered_by_default = true
	recipe.add_input("iron_ore", 1)
	recipe.add_output("iron_ingot", 2)
	recipe.add_output("coal", 1)  # Byproduct

	_crafting_system.register_recipe(recipe)
	_inventory.add_items(_iron_ore, 1)

	var outputs := _crafting_system.craft(recipe, _inventory, {}, "")

	assert_eq(outputs.size(), 2)
	assert_eq(_inventory.get_item_count("iron_ingot"), 2)
	assert_eq(_inventory.get_item_count("coal"), 1)


func test_craft_emits_signal() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	_inventory.add_items(_iron_ore, 5)
	_inventory.add_items(_coal, 2)

	watch_signals(_crafting_system)

	_crafting_system.craft(recipe, _inventory, {}, "")

	assert_signal_emitted(_crafting_system, "crafted")


func test_craft_failure_emits_signal() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	watch_signals(_crafting_system)

	_crafting_system.craft(recipe, _inventory, {}, "")  # No materials

	assert_signal_emitted(_crafting_system, "craft_failed")


# ====================
# Quality Calculation Tests
# ====================

func test_calculate_quality_no_skill() -> void:
	var recipe := _create_smelt_iron_recipe()
	# No required skill

	var quality := _crafting_system.calculate_quality(recipe, {})
	assert_eq(quality, 1.0)


func test_calculate_quality_at_required_level() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.required_skill = "smithing"
	recipe.required_skill_level = 10

	var quality := _crafting_system.calculate_quality(recipe, {"smithing": 10})

	# At required level, quality should be around 0.8 +/- 0.05
	assert_true(quality >= 0.6 and quality <= 0.9)


func test_calculate_quality_max_overlevel() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.required_skill = "smithing"
	recipe.required_skill_level = 1

	# 26 levels over requirement (25 is max bonus)
	var quality := _crafting_system.calculate_quality(recipe, {"smithing": 27})

	# Should be near max quality (1.25 +/- variance)
	assert_true(quality >= 1.15 and quality <= 1.25)


# ====================
# Available Recipes Tests
# ====================

func test_get_available_recipes_filters_undiscovered() -> void:
	var smelt := _create_smelt_iron_recipe()
	smelt.discovered_by_default = true
	_crafting_system.register_recipe(smelt)

	var sword := _create_iron_sword_recipe()
	sword.discovered_by_default = false
	_crafting_system.register_recipe(sword)

	var available := _crafting_system.get_available_recipes(_inventory, {}, "", false)
	assert_eq(available.size(), 1)
	assert_eq(available[0].id, "smelt_iron")


func test_get_available_recipes_filters_station() -> void:
	var smelt := _create_smelt_iron_recipe()
	smelt.station_type = "furnace"
	_crafting_system.register_recipe(smelt)

	var sword := _create_iron_sword_recipe()
	sword.station_type = ""  # Craft anywhere
	_crafting_system.register_recipe(sword)

	# At anvil - only sword should be available
	var at_anvil := _crafting_system.get_available_recipes(_inventory, {}, "anvil", false)
	assert_eq(at_anvil.size(), 1)
	assert_eq(at_anvil[0].id, "craft_iron_sword")

	# At furnace - both available
	var at_furnace := _crafting_system.get_available_recipes(_inventory, {}, "furnace", false)
	assert_eq(at_furnace.size(), 2)


func test_get_available_recipes_only_craftable() -> void:
	var recipe := _create_smelt_iron_recipe()
	_crafting_system.register_recipe(recipe)

	# No materials - not craftable
	var craftable := _crafting_system.get_available_recipes(_inventory, {}, "", true)
	assert_eq(craftable.size(), 0)

	# Add materials
	_inventory.add_items(_iron_ore, 5)
	_inventory.add_items(_coal, 2)

	craftable = _crafting_system.get_available_recipes(_inventory, {}, "", true)
	assert_eq(craftable.size(), 1)


# ====================
# XP Reward Tests
# ====================

func test_get_xp_reward() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.xp_reward = 50

	assert_eq(_crafting_system.get_xp_reward(recipe), 50)


func test_get_xp_skill() -> void:
	var recipe := _create_iron_sword_recipe()
	recipe.required_skill = "smithing"

	assert_eq(_crafting_system.get_xp_skill(recipe), "smithing")


# ====================
# Serialization Tests
# ====================

func test_crafting_system_serialization() -> void:
	var smelt := _create_smelt_iron_recipe()
	smelt.discovered_by_default = true
	_crafting_system.register_recipe(smelt)

	var sword := _create_iron_sword_recipe()
	sword.discovered_by_default = false
	_crafting_system.register_recipe(sword)

	# Discover sword
	_crafting_system.discover_recipe("craft_iron_sword")

	var data := _crafting_system.to_dict()

	# Create new system and restore
	var restored := CraftingSystem.new(_item_registry)
	restored.register_recipe(_create_smelt_iron_recipe())
	restored.register_recipe(_create_iron_sword_recipe())
	restored.from_dict(data)

	assert_true(restored.is_recipe_discovered("smelt_iron"))
	assert_true(restored.is_recipe_discovered("craft_iron_sword"))


func test_clear_crafting_system() -> void:
	_crafting_system.register_recipe(_create_smelt_iron_recipe())
	_crafting_system.register_recipe(_create_iron_sword_recipe())

	assert_eq(_crafting_system.get_recipe_count(), 2)

	_crafting_system.clear()

	assert_eq(_crafting_system.get_recipe_count(), 0)
	assert_eq(_crafting_system.get_discovered_count(), 0)


# ====================
# Helper Methods
# ====================

func _create_smelt_iron_recipe() -> RecipeDefinition:
	var recipe := RecipeDefinition.new()
	recipe.id = "smelt_iron"
	recipe.name = "Smelt Iron"
	recipe.category = "smelting"
	recipe.discovered_by_default = true
	recipe.add_input("iron_ore", 2)
	recipe.add_input("coal", 1)
	recipe.add_output("iron_ingot", 1)
	recipe.xp_reward = 10
	return recipe


func _create_iron_sword_recipe() -> RecipeDefinition:
	var recipe := RecipeDefinition.new()
	recipe.id = "craft_iron_sword"
	recipe.name = "Craft Iron Sword"
	recipe.category = "weapons"
	recipe.discovered_by_default = true
	recipe.add_input("iron_ingot", 3)
	recipe.add_output("iron_sword", 1)
	recipe.xp_reward = 25
	return recipe
