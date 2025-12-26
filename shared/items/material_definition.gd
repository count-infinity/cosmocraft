class_name MaterialDefinition
extends Resource
## Definition for crafting materials.
## Materials are used to craft items and determine base stats.


## Unique identifier
@export var id: String = ""

## Display name
@export var name: String = ""

## Description
@export_multiline var description: String = ""

## Material tier (1-5)
@export_range(1, 5) var tier: int = 1

## Weight per unit
@export var weight_per_unit: float = 0.5

## Base durability when used in crafting
@export var base_durability: int = 100

## Base damage when used for weapons
@export var base_damage: int = 10

## Base armor when used for armor
@export var base_armor: int = 5

## Special properties (e.g., "lightweight", "fire_resistant")
@export var special_properties: Array[String] = []

## Color for UI/visuals
@export var color: Color = Color.WHITE

## Icon path
@export var icon_path: String = ""

## What tool tier is needed to harvest this
@export_range(0, 5) var harvest_tier_required: int = 0

## Category (metal, cloth, wood, gem, etc.)
@export var category: String = "misc"


func _init(
	p_id: String = "",
	p_name: String = "",
	p_tier: int = 1
) -> void:
	id = p_id
	name = p_name
	tier = p_tier


## Check if material has a specific property
func has_property(property: String) -> bool:
	return property in special_properties


## Get tier display name
func get_tier_name() -> String:
	return ItemEnums.get_tier_name(tier)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"tier": tier,
		"weight_per_unit": weight_per_unit,
		"base_durability": base_durability,
		"base_damage": base_damage,
		"base_armor": base_armor,
		"special_properties": special_properties,
		"color": color.to_html(),
		"icon_path": icon_path,
		"harvest_tier_required": harvest_tier_required,
		"category": category,
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> MaterialDefinition:
	var mat := MaterialDefinition.new()
	mat.id = data.get("id", "")
	mat.name = data.get("name", "")
	mat.description = data.get("description", "")
	mat.tier = data.get("tier", 1)
	mat.weight_per_unit = data.get("weight_per_unit", 0.5)
	mat.base_durability = data.get("base_durability", 100)
	mat.base_damage = data.get("base_damage", 10)
	mat.base_armor = data.get("base_armor", 5)
	mat.harvest_tier_required = data.get("harvest_tier_required", 0)
	mat.category = data.get("category", "misc")
	mat.icon_path = data.get("icon_path", "")

	# Handle special properties array
	var props: Array = data.get("special_properties", [])
	mat.special_properties = []
	for prop in props:
		mat.special_properties.append(str(prop))

	# Handle color
	var color_str: String = data.get("color", "#ffffff")
	mat.color = Color.from_string(color_str, Color.WHITE)

	return mat
