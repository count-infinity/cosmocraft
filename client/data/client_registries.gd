class_name ClientRegistries
extends RefCounted
## Client-side registries for items, enchantments, etc.
## Mirrors server registries so client can interpret item data.


## The item registry with all item definitions
var item_registry: ItemRegistry

## The enchantment registry
var enchantment_registry: EnchantmentRegistry


func _init() -> void:
	item_registry = ItemRegistry.new()
	enchantment_registry = EnchantmentRegistry.new()
	_register_items()


## Register all item definitions (must match server)
func _register_items() -> void:
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
	item_registry.register_item(basic_pickaxe)

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
	item_registry.register_item(basic_axe)

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
	item_registry.register_item(basic_sword)

	# Health Potion
	var health_potion := ItemDefinition.new("health_potion", "Health Potion", ItemEnums.ItemType.CONSUMABLE)
	health_potion.description = "Restores 50 HP when consumed."
	health_potion.tier = 1
	health_potion.max_stack = 20
	health_potion.weight = 0.5
	health_potion.use_effects = {
		"heal": 50
	}
	item_registry.register_item(health_potion)

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
	item_registry.register_item(cloth_shirt)

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
	item_registry.register_item(cloth_pants)

	# Stone (basic material)
	var stone := ItemDefinition.new("stone", "Stone", ItemEnums.ItemType.MATERIAL)
	stone.description = "A chunk of common stone."
	stone.tier = 1
	stone.max_stack = 99
	stone.weight = 0.5
	item_registry.register_item(stone)

	# Wood (basic material)
	var wood := ItemDefinition.new("wood", "Wood", ItemEnums.ItemType.MATERIAL)
	wood.description = "A piece of lumber."
	wood.tier = 1
	wood.max_stack = 99
	wood.weight = 0.3
	item_registry.register_item(wood)

	print("ClientRegistries: Registered %d items" % item_registry.get_item_count())
