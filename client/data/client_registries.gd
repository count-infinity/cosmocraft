class_name ClientRegistries
extends RefCounted
## Client-side registries for items, enchantments, etc.
## Uses the shared ItemDatabase to ensure client and server data match.

const ItemDatabaseClass = preload("res://shared/data/item_database.gd")


## The item registry with all item definitions
var item_registry: ItemRegistry

## The enchantment registry
var enchantment_registry: EnchantmentRegistry

## The crafting system with all recipes
var crafting_system: CraftingSystem


func _init() -> void:
	item_registry = ItemRegistry.new()
	enchantment_registry = EnchantmentRegistry.new()
	crafting_system = CraftingSystem.new(item_registry)
	_initialize_registries()


## Initialize registries from shared database
func _initialize_registries() -> void:
	ItemDatabaseClass.register_all_items(item_registry)
	ItemDatabaseClass.register_all_enchantments(enchantment_registry)
	ItemDatabaseClass.register_all_recipes(crafting_system)
	print("ClientRegistries: Registered %d items from shared database" % item_registry.get_item_count())
	print("ClientRegistries: Registered %d recipes (%d discovered by default)" % [
		crafting_system.get_recipe_count(),
		crafting_system.get_discovered_count()
	])
