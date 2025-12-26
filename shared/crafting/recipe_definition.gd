class_name RecipeDefinition
extends Resource
## Definition of a crafting recipe.
## Specifies inputs, outputs, station requirements, and skill requirements.


## Unique identifier for this recipe
@export var id: String = ""

## Display name
@export var name: String = ""

## Description
@export_multiline var description: String = ""

## Category for UI organization (e.g., "weapons", "armor", "tools", "consumables")
@export var category: String = "misc"

## Required crafting station type (empty = can craft anywhere)
@export var station_type: String = ""

## Input ingredients: Array of {item_id: String, count: int}
@export var inputs: Array[Dictionary] = []

## Output items: Array of {item_id: String, count: int}
## Most recipes have one output, but some may have multiple
@export var outputs: Array[Dictionary] = []

## Required skill and minimum level to craft
@export var required_skill: String = ""
@export var required_skill_level: int = 0

## XP granted when crafting (to the relevant skill)
@export var xp_reward: int = 10

## Base crafting time in seconds (0 = instant)
@export var craft_time: float = 0.0

## Whether this recipe is discovered by default or needs to be learned
@export var discovered_by_default: bool = true

## Blueprint item ID that unlocks this recipe (if not discovered by default)
@export var blueprint_id: String = ""

## Tier of the output (for display purposes)
@export var tier: int = 1


func _init(
	p_id: String = "",
	p_name: String = ""
) -> void:
	id = p_id
	name = p_name


## Add an input requirement
func add_input(item_id: String, count: int) -> void:
	inputs.append({"item_id": item_id, "count": count})


## Add an output item
func add_output(item_id: String, count: int) -> void:
	outputs.append({"item_id": item_id, "count": count})


## Get total input count for a specific item
func get_input_count(item_id: String) -> int:
	for input in inputs:
		if input.get("item_id", "") == item_id:
			return input.get("count", 0)
	return 0


## Check if recipe requires a specific item
func requires_item(item_id: String) -> bool:
	for input in inputs:
		if input.get("item_id", "") == item_id:
			return true
	return false


## Get primary output item ID (first output)
func get_primary_output_id() -> String:
	if outputs.is_empty():
		return ""
	return outputs[0].get("item_id", "")


## Get primary output count
func get_primary_output_count() -> int:
	if outputs.is_empty():
		return 0
	return outputs[0].get("count", 1)


## Check if recipe can be crafted at a station type
func can_craft_at_station(station: String) -> bool:
	if station_type.is_empty():
		return true  # Can craft anywhere
	return station_type == station


## Check if recipe requires a crafting station
func requires_station() -> bool:
	return not station_type.is_empty()


## Get a list of all required item IDs
func get_required_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for input in inputs:
		var item_id: String = input.get("item_id", "")
		if not item_id.is_empty() and item_id not in ids:
			ids.append(item_id)
	return ids


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"category": category,
		"station_type": station_type,
		"inputs": inputs,
		"outputs": outputs,
		"required_skill": required_skill,
		"required_skill_level": required_skill_level,
		"xp_reward": xp_reward,
		"craft_time": craft_time,
		"discovered_by_default": discovered_by_default,
		"blueprint_id": blueprint_id,
		"tier": tier,
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> RecipeDefinition:
	var recipe := RecipeDefinition.new()
	recipe.id = data.get("id", "")
	recipe.name = data.get("name", "")
	recipe.description = data.get("description", "")
	recipe.category = data.get("category", "misc")
	recipe.station_type = data.get("station_type", "")
	recipe.required_skill = data.get("required_skill", "")
	recipe.required_skill_level = data.get("required_skill_level", 0)
	recipe.xp_reward = data.get("xp_reward", 10)
	recipe.craft_time = data.get("craft_time", 0.0)
	recipe.discovered_by_default = data.get("discovered_by_default", true)
	recipe.blueprint_id = data.get("blueprint_id", "")
	recipe.tier = data.get("tier", 1)

	# Handle inputs array
	var inputs_data: Array = data.get("inputs", [])
	recipe.inputs = []
	for input_data in inputs_data:
		if input_data is Dictionary:
			recipe.inputs.append(input_data)

	# Handle outputs array
	var outputs_data: Array = data.get("outputs", [])
	recipe.outputs = []
	for output_data in outputs_data:
		if output_data is Dictionary:
			recipe.outputs.append(output_data)

	return recipe
