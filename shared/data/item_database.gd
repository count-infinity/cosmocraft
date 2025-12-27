class_name ItemDatabase
extends RefCounted
## Shared item database containing all item, enchantment, and recipe definitions.
## This is the single source of truth for game data, used by both server and client.


## Register all items into the provided registry
static func register_all_items(registry: ItemRegistry) -> void:
	_register_tools(registry)
	_register_weapons(registry)
	_register_armor(registry)
	_register_consumables(registry)
	_register_materials(registry)


## Register all tool items
static func _register_tools(registry: ItemRegistry) -> void:
	# Basic Pickaxe
	var basic_pickaxe := ItemDefinition.new("basic_pickaxe", "Basic Pickaxe", ItemEnums.ItemType.TOOL)
	basic_pickaxe.description = "A simple pickaxe for mining stone and ore."
	basic_pickaxe.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	basic_pickaxe.tier = 1
	basic_pickaxe.max_stack = 1
	basic_pickaxe.weight = 3.0
	basic_pickaxe.base_durability = 100
	basic_pickaxe.harvest_tier = 1
	basic_pickaxe.available_modes = [ItemEnums.ToolMode.STANDARD, ItemEnums.ToolMode.PRECISION]
	basic_pickaxe.base_stats = {
		ItemEnums.StatType.EFFICIENCY: 5.0
	}
	registry.register_item(basic_pickaxe)

	# Basic Axe
	var basic_axe := ItemDefinition.new("basic_axe", "Basic Axe", ItemEnums.ItemType.TOOL)
	basic_axe.description = "A simple axe for chopping wood."
	basic_axe.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	basic_axe.tier = 1
	basic_axe.max_stack = 1
	basic_axe.weight = 3.0
	basic_axe.base_durability = 100
	basic_axe.harvest_tier = 1
	basic_axe.available_modes = [ItemEnums.ToolMode.STANDARD]
	basic_axe.base_stats = {
		ItemEnums.StatType.EFFICIENCY: 5.0
	}
	registry.register_item(basic_axe)


## Register all weapon items
static func _register_weapons(registry: ItemRegistry) -> void:
	# Basic Sword
	var basic_sword := ItemDefinition.new("basic_sword", "Basic Sword", ItemEnums.ItemType.WEAPON)
	basic_sword.description = "A simple sword for combat."
	basic_sword.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	basic_sword.tier = 1
	basic_sword.max_stack = 1
	basic_sword.weight = 2.5
	basic_sword.base_durability = 80
	basic_sword.base_damage = 10
	basic_sword.attack_speed = 1.0
	basic_sword.enchant_slots = 1
	basic_sword.base_stats = {
		ItemEnums.StatType.STRENGTH: 3.0
	}
	registry.register_item(basic_sword)


## Register all armor items
static func _register_armor(registry: ItemRegistry) -> void:
	# Cloth Shirt (Chest armor)
	var cloth_shirt := ItemDefinition.new("cloth_shirt", "Cloth Shirt", ItemEnums.ItemType.ARMOR)
	cloth_shirt.description = "A simple cloth shirt providing minimal protection."
	cloth_shirt.equip_slot = ItemEnums.EquipSlot.CHEST
	cloth_shirt.tier = 1
	cloth_shirt.max_stack = 1
	cloth_shirt.weight = 1.0
	cloth_shirt.base_durability = 50
	cloth_shirt.base_stats = {
		ItemEnums.StatType.FORTITUDE: 2.0,
		ItemEnums.StatType.MAX_HP: 5.0
	}
	registry.register_item(cloth_shirt)

	# Cloth Pants (Legs armor)
	var cloth_pants := ItemDefinition.new("cloth_pants", "Cloth Pants", ItemEnums.ItemType.ARMOR)
	cloth_pants.description = "Simple cloth pants providing minimal protection."
	cloth_pants.equip_slot = ItemEnums.EquipSlot.LEGS
	cloth_pants.tier = 1
	cloth_pants.max_stack = 1
	cloth_pants.weight = 0.8
	cloth_pants.base_durability = 50
	cloth_pants.base_stats = {
		ItemEnums.StatType.FORTITUDE: 1.0,
		ItemEnums.StatType.MAX_HP: 3.0
	}
	registry.register_item(cloth_pants)


## Register all consumable items
static func _register_consumables(registry: ItemRegistry) -> void:
	# Health Potion
	var health_potion := ItemDefinition.new("health_potion", "Health Potion", ItemEnums.ItemType.CONSUMABLE)
	health_potion.description = "Restores 50 HP when consumed."
	health_potion.tier = 1
	health_potion.max_stack = 20
	health_potion.weight = 0.5
	health_potion.use_effects = {
		"heal": 50
	}
	registry.register_item(health_potion)


## Register all material items
static func _register_materials(registry: ItemRegistry) -> void:
	# Stone (basic material)
	var stone := ItemDefinition.new("stone", "Stone", ItemEnums.ItemType.MATERIAL)
	stone.description = "A chunk of common stone."
	stone.tier = 1
	stone.max_stack = 99
	stone.weight = 0.5
	registry.register_item(stone)

	# Wood (basic material)
	var wood := ItemDefinition.new("wood", "Wood", ItemEnums.ItemType.MATERIAL)
	wood.description = "A piece of lumber."
	wood.tier = 1
	wood.max_stack = 99
	wood.weight = 0.3
	registry.register_item(wood)


## Register all enchantments into the provided registry
static func register_all_enchantments(_registry: EnchantmentRegistry) -> void:
	# TODO: Add enchantment definitions here when needed
	pass


## Register all recipes into the provided crafting system
static func register_all_recipes(crafting: CraftingSystem) -> void:
	_register_tool_recipes(crafting)
	_register_weapon_recipes(crafting)
	_register_consumable_recipes(crafting)


## Register tool crafting recipes
static func _register_tool_recipes(crafting: CraftingSystem) -> void:
	# Basic Pickaxe: 3 stone + 2 wood
	var pickaxe_recipe := RecipeDefinition.new("recipe_basic_pickaxe", "Basic Pickaxe")
	pickaxe_recipe.description = "Craft a basic pickaxe for mining."
	pickaxe_recipe.category = "tools"
	pickaxe_recipe.add_input("stone", 3)
	pickaxe_recipe.add_input("wood", 2)
	pickaxe_recipe.add_output("basic_pickaxe", 1)
	pickaxe_recipe.xp_reward = 15
	pickaxe_recipe.discovered_by_default = true
	crafting.register_recipe(pickaxe_recipe)

	# Basic Axe: 3 stone + 2 wood
	var axe_recipe := RecipeDefinition.new("recipe_basic_axe", "Basic Axe")
	axe_recipe.description = "Craft a basic axe for chopping wood."
	axe_recipe.category = "tools"
	axe_recipe.add_input("stone", 3)
	axe_recipe.add_input("wood", 2)
	axe_recipe.add_output("basic_axe", 1)
	axe_recipe.xp_reward = 15
	axe_recipe.discovered_by_default = true
	crafting.register_recipe(axe_recipe)


## Register weapon crafting recipes
static func _register_weapon_recipes(crafting: CraftingSystem) -> void:
	# Basic Sword: 5 stone + 1 wood
	var sword_recipe := RecipeDefinition.new("recipe_basic_sword", "Basic Sword")
	sword_recipe.description = "Craft a basic sword for combat."
	sword_recipe.category = "weapons"
	sword_recipe.add_input("stone", 5)
	sword_recipe.add_input("wood", 1)
	sword_recipe.add_output("basic_sword", 1)
	sword_recipe.xp_reward = 20
	sword_recipe.discovered_by_default = true
	crafting.register_recipe(sword_recipe)


## Register consumable crafting recipes
static func _register_consumable_recipes(crafting: CraftingSystem) -> void:
	# Health Potion: for now, no recipe (obtained elsewhere)
	# Could add crafting later when herbs/alchemy is implemented
	pass


## Get the count of items that will be registered
static func get_item_count() -> int:
	# Update this when adding new items
	return 8
