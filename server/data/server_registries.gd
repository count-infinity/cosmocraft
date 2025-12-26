class_name ServerRegistries
extends RefCounted
## Server-side registries for items, enchantments, etc.
## Initializes all game data needed for server operations.


## The item registry with all item definitions
var item_registry: ItemRegistry

## The enchantment registry
var enchantment_registry: EnchantmentRegistry


func _init() -> void:
	item_registry = ItemRegistry.new()
	enchantment_registry = EnchantmentRegistry.new()
	_register_starter_items()


## Register all starter/base item definitions
func _register_starter_items() -> void:
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

	# Stone (basic material for testing)
	var stone := ItemDefinition.new("stone", "Stone", ItemEnums.ItemType.MATERIAL)
	stone.description = "A chunk of common stone."
	stone.tier = 1
	stone.max_stack = 99
	stone.weight = 0.5
	item_registry.register_item(stone)

	# Wood (basic material for testing)
	var wood := ItemDefinition.new("wood", "Wood", ItemEnums.ItemType.MATERIAL)
	wood.description = "A piece of lumber."
	wood.tier = 1
	wood.max_stack = 99
	wood.weight = 0.3
	item_registry.register_item(wood)

	print("ServerRegistries: Registered %d starter items" % item_registry.get_item_count())


## Create starting inventory for a new player
## Returns a dictionary with inventory, equipment, and hotbar objects
func create_starter_loadout() -> Dictionary:
	var inventory := Inventory.new(100.0, item_registry)
	var equipment := EquipmentSlots.new(item_registry)
	var hotbar := Hotbar.new(inventory, item_registry)

	# Add starter items to inventory
	var pickaxe_stack := item_registry.create_item_stack("basic_pickaxe", 1, 1.0)
	var axe_stack := item_registry.create_item_stack("basic_axe", 1, 1.0)
	var sword_stack := item_registry.create_item_stack("basic_sword", 1, 1.0)
	var potions_stack := item_registry.create_item_stack("health_potion", 3, 1.0)
	var shirt_stack := item_registry.create_item_stack("cloth_shirt", 1, 1.0)
	var pants_stack := item_registry.create_item_stack("cloth_pants", 1, 1.0)

	# Add to inventory
	inventory.add_stack(pickaxe_stack)
	inventory.add_stack(axe_stack)
	inventory.add_stack(sword_stack)
	inventory.add_stack(potions_stack)
	inventory.add_stack(shirt_stack)
	inventory.add_stack(pants_stack)

	# Auto-equip cloth armor
	if shirt_stack != null and shirt_stack.item != null:
		equipment.equip(shirt_stack.item)
	if pants_stack != null and pants_stack.item != null:
		equipment.equip(pants_stack.item)

	# Assign tools to hotbar
	hotbar.set_slot(0, pickaxe_stack)
	hotbar.set_slot(1, axe_stack)
	hotbar.set_slot(2, sword_stack)
	hotbar.set_slot(3, potions_stack)

	return {
		"inventory": inventory,
		"equipment": equipment,
		"hotbar": hotbar
	}


## Calculate player stats from equipment
func calculate_player_stats(equipment: EquipmentSlots) -> Dictionary:
	var stats := {}

	# Base stats
	stats[ItemEnums.StatType.MAX_HP] = 100.0
	stats[ItemEnums.StatType.HP_REGEN] = 1.0
	stats[ItemEnums.StatType.MAX_ENERGY] = 100.0
	stats[ItemEnums.StatType.ENERGY_REGEN] = 5.0
	stats[ItemEnums.StatType.STRENGTH] = 10.0
	stats[ItemEnums.StatType.PRECISION] = 10.0
	stats[ItemEnums.StatType.FORTITUDE] = 10.0
	stats[ItemEnums.StatType.EFFICIENCY] = 10.0
	stats[ItemEnums.StatType.LUCK] = 10.0
	stats[ItemEnums.StatType.MOVE_SPEED] = 1.0
	stats[ItemEnums.StatType.ATTACK_SPEED] = 1.0
	stats[ItemEnums.StatType.CRIT_CHANCE] = 0.05
	stats[ItemEnums.StatType.CRIT_DAMAGE] = 1.5

	# Add equipment bonuses
	var equipment_stats := equipment.get_total_stats()
	for stat_key in equipment_stats:
		stats[stat_key] = stats.get(stat_key, 0.0) + equipment_stats[stat_key]

	return stats
