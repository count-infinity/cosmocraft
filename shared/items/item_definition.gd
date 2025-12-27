class_name ItemDefinition
extends Resource
## Static definition of an item type.
## This is the "template" - ItemInstance is the actual item in the world/inventory.


## Unique identifier for this item type
@export var id: String = ""

## Display name
@export var name: String = ""

## Description shown in tooltips
@export_multiline var description: String = ""

## Type of item (determines behavior)
@export var type: ItemEnums.ItemType = ItemEnums.ItemType.MATERIAL

## Which equipment slot this can go in (NONE if not equippable)
@export var equip_slot: ItemEnums.EquipSlot = ItemEnums.EquipSlot.NONE

## Material tier (1-5)
@export_range(1, 5) var tier: int = 1

## Maximum stack size (1 for equipment, higher for materials)
@export_range(1, 999) var max_stack: int = 1

## Weight per unit
@export var weight: float = 1.0

## Base durability (0 = indestructible)
@export var base_durability: int = 0

## Base stats this item provides when equipped
## Keys are StatType enum values, values are the stat amount
@export var base_stats: Dictionary = {}

## Number of enchantment slots
@export_range(0, 4) var enchant_slots: int = 0

## Number of gem sockets
@export_range(0, 3) var socket_count: int = 0

## Set ID for set bonus (empty = no set)
@export var set_id: String = ""

## Icon texture path
@export var icon_path: String = ""

## For tools: what modes are available
@export var available_modes: Array[ItemEnums.ToolMode] = []

## For tools: what tier of materials can this harvest
@export_range(0, 5) var harvest_tier: int = 0

## For weapons: base damage
@export var base_damage: int = 0

## For weapons: attack speed multiplier (1.0 = normal)
@export var attack_speed: float = 1.0

## For weapons: weapon type (determines attack style and visuals)
@export var weapon_type: ItemEnums.WeaponType = ItemEnums.WeaponType.NONE

## For weapons: attack range in pixels
@export var attack_range: float = 0.0

## For weapons: attack arc in radians (for melee arc attacks)
@export var attack_arc: float = 0.0

## For consumables: effects when used
@export var use_effects: Dictionary = {}

## Required material to craft/repair (material ID)
@export var primary_material: String = ""


func _init(
	p_id: String = "",
	p_name: String = "",
	p_type: ItemEnums.ItemType = ItemEnums.ItemType.MATERIAL
) -> void:
	id = p_id
	name = p_name
	type = p_type


## Check if this item can be equipped
func is_equippable() -> bool:
	return equip_slot != ItemEnums.EquipSlot.NONE


## Check if this item is stackable
func is_stackable() -> bool:
	return max_stack > 1


## Check if this item has durability
func has_durability() -> bool:
	return base_durability > 0


## Get a specific base stat value
func get_base_stat(stat: ItemEnums.StatType) -> float:
	return base_stats.get(stat, 0.0)


## Get display text for tier
func get_tier_name() -> String:
	return ItemEnums.get_tier_name(tier)


## Serialize to dictionary for network/save
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": type,
		"equip_slot": equip_slot,
		"tier": tier,
		"max_stack": max_stack,
		"weight": weight,
		"base_durability": base_durability,
		"base_stats": base_stats,
		"enchant_slots": enchant_slots,
		"socket_count": socket_count,
		"set_id": set_id,
		"icon_path": icon_path,
		"available_modes": available_modes,
		"harvest_tier": harvest_tier,
		"base_damage": base_damage,
		"attack_speed": attack_speed,
		"weapon_type": weapon_type,
		"attack_range": attack_range,
		"attack_arc": attack_arc,
		"use_effects": use_effects,
		"primary_material": primary_material,
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = data.get("id", "")
	def.name = data.get("name", "")
	def.description = data.get("description", "")
	def.type = data.get("type", ItemEnums.ItemType.MATERIAL)
	def.equip_slot = data.get("equip_slot", ItemEnums.EquipSlot.NONE)
	def.tier = data.get("tier", 1)
	def.max_stack = data.get("max_stack", 1)
	def.weight = data.get("weight", 1.0)
	def.base_durability = data.get("base_durability", 0)
	def.base_stats = data.get("base_stats", {})
	def.enchant_slots = data.get("enchant_slots", 0)
	def.socket_count = data.get("socket_count", 0)
	def.set_id = data.get("set_id", "")
	def.icon_path = data.get("icon_path", "")
	def.harvest_tier = data.get("harvest_tier", 0)
	def.base_damage = data.get("base_damage", 0)
	def.attack_speed = data.get("attack_speed", 1.0)
	def.weapon_type = data.get("weapon_type", ItemEnums.WeaponType.NONE)
	def.attack_range = data.get("attack_range", 0.0)
	def.attack_arc = data.get("attack_arc", 0.0)
	def.use_effects = data.get("use_effects", {})
	def.primary_material = data.get("primary_material", "")

	# Handle available_modes array
	var modes_data: Array = data.get("available_modes", [])
	def.available_modes = []
	for mode in modes_data:
		def.available_modes.append(mode as ItemEnums.ToolMode)

	return def
