class_name ItemEnums
extends RefCounted
## Enums for the item and equipment system.
## Shared between client and server.


## Type of item - determines behavior and UI
enum ItemType {
	MATERIAL,       # Raw materials, crafting ingredients
	TOOL,           # Pickaxe, axe, hammer - used on world
	WEAPON,         # Sword, bow, staff - used on enemies
	ARMOR,          # Head, chest, legs, boots
	ACCESSORY,      # Rings, amulets, belts
	CONSUMABLE,     # Food, potions, bandages
	PLACEABLE,      # Blocks, furniture, machines
	BLUEPRINT,      # Unlocks recipes
	ENCHANT_CORE,   # Used for enchanting
	GEM,            # Socket into equipment
	KEY,            # Unlocks doors, chests
	QUEST,          # Quest items
}


## Equipment slot where item can be worn
enum EquipSlot {
	NONE,           # Cannot be equipped
	HEAD,
	CHEST,
	LEGS,
	BOOTS,
	MAIN_HAND,
	OFF_HAND,
	ACCESSORY,      # Either accessory slot
}


## Primary stats that affect gameplay
enum StatType {
	MAX_HP,
	HP_REGEN,
	MAX_ENERGY,
	ENERGY_REGEN,
	STRENGTH,
	PRECISION,
	FORTITUDE,
	EFFICIENCY,
	LUCK,
	# Derived/special stats
	MOVE_SPEED,
	ATTACK_SPEED,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	# Resistances
	HEAT_RESIST,
	COLD_RESIST,
	RADIATION_RESIST,
	TOXIC_RESIST,
	PRESSURE_RESIST,
}


## Material tier - determines power level and progression
enum MaterialTier {
	PRIMITIVE = 1,   # Stone, Copper, Fiber
	BASIC = 2,       # Iron, Leather, Glass
	INTERMEDIATE = 3, # Steel, Silver, Titanium
	ADVANCED = 4,    # Plasma Cores, Nanofiber
	EXOTIC = 5,      # Void Shards, Quantum Dust
}


## Tool/weapon modes
enum ToolMode {
	STANDARD,
	PRECISION,
	AREA,
	VEIN,
}


## Get display name for a stat
static func get_stat_name(stat: StatType) -> String:
	match stat:
		StatType.MAX_HP: return "Max HP"
		StatType.HP_REGEN: return "HP Regen"
		StatType.MAX_ENERGY: return "Max Energy"
		StatType.ENERGY_REGEN: return "Energy Regen"
		StatType.STRENGTH: return "Strength"
		StatType.PRECISION: return "Precision"
		StatType.FORTITUDE: return "Fortitude"
		StatType.EFFICIENCY: return "Efficiency"
		StatType.LUCK: return "Luck"
		StatType.MOVE_SPEED: return "Move Speed"
		StatType.ATTACK_SPEED: return "Attack Speed"
		StatType.CRIT_CHANCE: return "Crit Chance"
		StatType.CRIT_DAMAGE: return "Crit Damage"
		StatType.HEAT_RESIST: return "Heat Resist"
		StatType.COLD_RESIST: return "Cold Resist"
		StatType.RADIATION_RESIST: return "Radiation Resist"
		StatType.TOXIC_RESIST: return "Toxic Resist"
		StatType.PRESSURE_RESIST: return "Pressure Resist"
		_: return "Unknown"


## Get display name for material tier
static func get_tier_name(tier: MaterialTier) -> String:
	match tier:
		MaterialTier.PRIMITIVE: return "Primitive"
		MaterialTier.BASIC: return "Basic"
		MaterialTier.INTERMEDIATE: return "Intermediate"
		MaterialTier.ADVANCED: return "Advanced"
		MaterialTier.EXOTIC: return "Exotic"
		_: return "Unknown"


## Get display name for equip slot
static func get_slot_name(slot: EquipSlot) -> String:
	match slot:
		EquipSlot.NONE: return "None"
		EquipSlot.HEAD: return "Head"
		EquipSlot.CHEST: return "Chest"
		EquipSlot.LEGS: return "Legs"
		EquipSlot.BOOTS: return "Boots"
		EquipSlot.MAIN_HAND: return "Main Hand"
		EquipSlot.OFF_HAND: return "Off Hand"
		EquipSlot.ACCESSORY: return "Accessory"
		_: return "Unknown"
