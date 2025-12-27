class_name ServerRegistries
extends RefCounted
## Server-side registries for items, enchantments, enemies, etc.
## Initializes all game data needed for server operations.
## Uses the shared ItemDatabase for item definitions.

const ItemDatabaseClass = preload("res://shared/data/item_database.gd")
const EnemyDatabaseClass = preload("res://shared/data/enemy_database.gd")
const EnemyRegistryScript = preload("res://shared/entities/enemy_registry.gd")


## The item registry with all item definitions
var item_registry: ItemRegistry

## The enchantment registry
var enchantment_registry: EnchantmentRegistry

## The crafting system with all recipes
var crafting_system: CraftingSystem

## The enemy registry with all enemy definitions
var enemy_registry: RefCounted


func _init() -> void:
	item_registry = ItemRegistry.new()
	enchantment_registry = EnchantmentRegistry.new()
	crafting_system = CraftingSystem.new(item_registry)
	enemy_registry = EnemyRegistryScript.new()
	_initialize_registries()


## Initialize registries from shared database
func _initialize_registries() -> void:
	ItemDatabaseClass.register_all_items(item_registry)
	ItemDatabaseClass.register_all_enchantments(enchantment_registry)
	ItemDatabaseClass.register_all_recipes(crafting_system)
	EnemyDatabaseClass.register_all_enemies(enemy_registry)
	print("ServerRegistries: Registered %d items from shared database" % item_registry.get_item_count())
	print("ServerRegistries: Registered %d recipes (%d discovered by default)" % [
		crafting_system.get_recipe_count(),
		crafting_system.get_discovered_count()
	])
	print("ServerRegistries: Registered %d enemy types" % enemy_registry.get_definition_count())


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

	# Add to inventory and track indices for hotbar
	inventory.add_stack(pickaxe_stack)
	var pickaxe_idx := inventory.get_stack_count() - 1

	inventory.add_stack(axe_stack)
	var axe_idx := inventory.get_stack_count() - 1

	inventory.add_stack(sword_stack)
	var sword_idx := inventory.get_stack_count() - 1

	inventory.add_stack(potions_stack)
	var potions_idx := inventory.get_stack_count() - 1

	inventory.add_stack(shirt_stack)
	inventory.add_stack(pants_stack)

	# Auto-equip cloth armor
	if shirt_stack != null and shirt_stack.item != null:
		equipment.equip(shirt_stack.item)
	if pants_stack != null and pants_stack.item != null:
		equipment.equip(pants_stack.item)

	# Assign tools to hotbar with inventory indices for reliable sync
	hotbar.set_slot(0, pickaxe_stack, pickaxe_idx)
	hotbar.set_slot(1, axe_stack, axe_idx)
	hotbar.set_slot(2, sword_stack, sword_idx)
	hotbar.set_slot(3, potions_stack, potions_idx)

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
