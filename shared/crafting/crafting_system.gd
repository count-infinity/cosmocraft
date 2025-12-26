class_name CraftingSystem
extends RefCounted
## Crafting system that manages recipes and crafting operations.
## Handles recipe registration, crafting checks, and execution.


## Signal emitted when a recipe is successfully crafted
signal crafted(recipe: RecipeDefinition, outputs: Array[ItemStack])

## Signal emitted when crafting fails
signal craft_failed(recipe: RecipeDefinition, reason: String)


## All registered recipes indexed by ID
var _recipes: Dictionary = {}

## Recipes indexed by category for quick lookup
var _recipes_by_category: Dictionary = {}

## Recipes indexed by output item ID
var _recipes_by_output: Dictionary = {}

## Reference to item registry for creating outputs
var _item_registry: ItemRegistry

## Discovered recipes (for recipes that need to be learned)
var _discovered_recipes: Dictionary = {}


func _init(item_registry: ItemRegistry = null) -> void:
	_item_registry = item_registry


## Set the item registry
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry


## Register a recipe
func register_recipe(recipe: RecipeDefinition) -> void:
	if recipe == null or recipe.id.is_empty():
		return

	_recipes[recipe.id] = recipe

	# Index by category
	if not _recipes_by_category.has(recipe.category):
		_recipes_by_category[recipe.category] = []
	_recipes_by_category[recipe.category].append(recipe)

	# Index by output
	var output_id := recipe.get_primary_output_id()
	if not output_id.is_empty():
		if not _recipes_by_output.has(output_id):
			_recipes_by_output[output_id] = []
		_recipes_by_output[output_id].append(recipe)

	# Auto-discover if default
	if recipe.discovered_by_default:
		_discovered_recipes[recipe.id] = true


## Get a recipe by ID
func get_recipe(id: String) -> RecipeDefinition:
	return _recipes.get(id, null)


## Get all recipes
func get_all_recipes() -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	for recipe in _recipes.values():
		result.append(recipe)
	return result


## Get recipes by category
func get_recipes_by_category(category: String) -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	var recipes: Array = _recipes_by_category.get(category, [])
	for recipe in recipes:
		result.append(recipe)
	return result


## Get all categories
func get_categories() -> Array[String]:
	var result: Array[String] = []
	for category in _recipes_by_category.keys():
		result.append(category)
	return result


## Get recipes that produce a specific item
func get_recipes_for_item(item_id: String) -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	var recipes: Array = _recipes_by_output.get(item_id, [])
	for recipe in recipes:
		result.append(recipe)
	return result


## Check if a recipe is discovered
func is_recipe_discovered(recipe_id: String) -> bool:
	return _discovered_recipes.get(recipe_id, false)


## Discover a recipe (learn it)
func discover_recipe(recipe_id: String) -> bool:
	if not _recipes.has(recipe_id):
		return false
	_discovered_recipes[recipe_id] = true
	return true


## Discover a recipe from a blueprint item ID
func discover_from_blueprint(blueprint_id: String) -> RecipeDefinition:
	for recipe in _recipes.values():
		if recipe.blueprint_id == blueprint_id:
			_discovered_recipes[recipe.id] = true
			return recipe
	return null


## Get all discovered recipes
func get_discovered_recipes() -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	for recipe_id in _discovered_recipes.keys():
		if _discovered_recipes[recipe_id]:
			var recipe: RecipeDefinition = _recipes.get(recipe_id, null)
			if recipe != null:
				result.append(recipe)
	return result


## Check if player has required materials in inventory
func has_materials(recipe: RecipeDefinition, inventory: Inventory) -> bool:
	if recipe == null or inventory == null:
		return false

	for input in recipe.inputs:
		var item_id: String = input.get("item_id", "")
		var count: int = input.get("count", 1)
		if not inventory.has_item(item_id, count):
			return false

	return true


## Check if player has required skill level
## skill_levels is a Dictionary of {skill_name: level}
func has_skill_requirement(recipe: RecipeDefinition, skill_levels: Dictionary) -> bool:
	if recipe == null:
		return false

	if recipe.required_skill.is_empty():
		return true  # No skill required

	var player_level: int = skill_levels.get(recipe.required_skill, 0)
	return player_level >= recipe.required_skill_level


## Check if player is at the correct station
func at_correct_station(recipe: RecipeDefinition, current_station: String) -> bool:
	if recipe == null:
		return false

	if recipe.station_type.is_empty():
		return true  # Can craft anywhere

	return recipe.station_type == current_station


## Full check if recipe can be crafted
## Returns empty string if can craft, or error message if cannot
func get_craft_error(
	recipe: RecipeDefinition,
	inventory: Inventory,
	skill_levels: Dictionary,
	current_station: String
) -> String:
	if recipe == null:
		return "Invalid recipe"

	if not is_recipe_discovered(recipe.id):
		return "Recipe not discovered"

	if not at_correct_station(recipe, current_station):
		if recipe.station_type.is_empty():
			return "Requires no station"
		return "Requires %s station" % recipe.station_type

	if not has_skill_requirement(recipe, skill_levels):
		return "Requires %s level %d" % [recipe.required_skill, recipe.required_skill_level]

	if not has_materials(recipe, inventory):
		return "Missing materials"

	return ""


## Check if recipe can be crafted (boolean version)
func can_craft(
	recipe: RecipeDefinition,
	inventory: Inventory,
	skill_levels: Dictionary,
	current_station: String
) -> bool:
	return get_craft_error(recipe, inventory, skill_levels, current_station).is_empty()


## Calculate output quality based on crafting skill
## Higher skill = better quality (range: 0.6 to 1.25)
func calculate_quality(recipe: RecipeDefinition, skill_levels: Dictionary) -> float:
	if recipe.required_skill.is_empty():
		return 1.0  # Default quality for skill-less recipes

	var skill_level: int = skill_levels.get(recipe.required_skill, 0)
	var required_level: int = recipe.required_skill_level

	# Calculate bonus for over-leveling (max 25 levels over)
	var over_level := clampi(skill_level - required_level, 0, 25)

	# Base quality is 0.8, can go up to 1.25 with max over-leveling
	# Formula: 0.8 + (over_level * 0.018) = 0.8 to 1.25
	var quality := 0.8 + (over_level * 0.018)

	# Add small random variance (-0.05 to +0.05)
	quality += randf_range(-0.05, 0.05)

	return clampf(quality, 0.6, 1.25)


## Execute crafting - consume materials and produce outputs
## Returns the output stacks, or empty array if failed
func craft(
	recipe: RecipeDefinition,
	inventory: Inventory,
	skill_levels: Dictionary,
	current_station: String
) -> Array[ItemStack]:
	var error := get_craft_error(recipe, inventory, skill_levels, current_station)
	if not error.is_empty():
		craft_failed.emit(recipe, error)
		return []

	if _item_registry == null:
		craft_failed.emit(recipe, "No item registry")
		return []

	# Consume input materials
	for input in recipe.inputs:
		var item_id: String = input.get("item_id", "")
		var count: int = input.get("count", 1)
		inventory.remove_items_by_id(item_id, count)

	# Calculate quality based on skill
	var quality := calculate_quality(recipe, skill_levels)

	# Create output items
	var outputs: Array[ItemStack] = []
	for output in recipe.outputs:
		var item_id: String = output.get("item_id", "")
		var count: int = output.get("count", 1)

		var stack := _item_registry.create_item_stack(item_id, count, quality)
		if stack != null:
			outputs.append(stack)

	# Add outputs to inventory (handle overflow)
	var added_outputs: Array[ItemStack] = []
	for stack in outputs:
		var leftover := inventory.add_stack(stack)
		if leftover == null or leftover.is_empty():
			added_outputs.append(stack)
		else:
			# Partial add - still count it
			added_outputs.append(stack)

	crafted.emit(recipe, added_outputs)
	return added_outputs


## Get XP reward for crafting (to be applied by caller)
func get_xp_reward(recipe: RecipeDefinition) -> int:
	if recipe == null:
		return 0
	return recipe.xp_reward


## Get the skill that receives XP
func get_xp_skill(recipe: RecipeDefinition) -> String:
	if recipe == null:
		return ""
	return recipe.required_skill


## Get craftable recipes for current situation
## Filters by station, discovery, and optionally by materials
func get_available_recipes(
	inventory: Inventory,
	skill_levels: Dictionary,
	current_station: String,
	only_craftable: bool = false
) -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []

	for recipe in _recipes.values():
		# Must be discovered
		if not is_recipe_discovered(recipe.id):
			continue

		# Must be at correct station
		if not at_correct_station(recipe, current_station):
			continue

		# Optional: must have materials and skill
		if only_craftable:
			if not can_craft(recipe, inventory, skill_levels, current_station):
				continue

		result.append(recipe)

	return result


## Serialize discovered recipes
func to_dict() -> Dictionary:
	var discovered: Array[String] = []
	for recipe_id in _discovered_recipes.keys():
		if _discovered_recipes[recipe_id]:
			discovered.append(recipe_id)

	return {
		"discovered": discovered,
	}


## Deserialize discovered recipes
func from_dict(data: Dictionary) -> void:
	_discovered_recipes.clear()

	var discovered: Array = data.get("discovered", [])
	for recipe_id in discovered:
		if recipe_id is String:
			_discovered_recipes[recipe_id] = true


## Clear all recipes (for testing)
func clear() -> void:
	_recipes.clear()
	_recipes_by_category.clear()
	_recipes_by_output.clear()
	_discovered_recipes.clear()


## Get recipe count
func get_recipe_count() -> int:
	return _recipes.size()


## Get discovered recipe count
func get_discovered_count() -> int:
	var count := 0
	for discovered in _discovered_recipes.values():
		if discovered:
			count += 1
	return count
