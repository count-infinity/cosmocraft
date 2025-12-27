class_name EnemyRegistry
extends RefCounted
## Central registry for all enemy definitions.
## Used to look up definitions by ID for spawning and network deserialization.


## All registered enemy definitions by ID
var _definitions: Dictionary = {}


## Register an enemy definition
## Uses Resource type for headless mode compatibility
func register_definition(definition: Resource) -> void:
	if definition.id.is_empty():
		push_warning("EnemyRegistry: Cannot register definition with empty ID")
		return
	if _definitions.has(definition.id):
		push_warning("EnemyRegistry: Overwriting existing definition with ID: " + definition.id)
	_definitions[definition.id] = definition


## Get an enemy definition by ID
## Returns null if not found
func get_definition(id: String) -> Resource:
	return _definitions.get(id, null)


## Check if a definition exists
func has_definition(id: String) -> bool:
	return id in _definitions


## Get all registered definition IDs
func get_all_ids() -> Array:
	var ids: Array = []
	for id in _definitions.keys():
		ids.append(id)
	return ids


## Get all definitions
func get_all_definitions() -> Array:
	var defs: Array = []
	for def in _definitions.values():
		defs.append(def)
	return defs


## Get definitions by behavior type
func get_definitions_by_behavior(behavior: int) -> Array:
	var result: Array = []
	for def in _definitions.values():
		if def.behavior_type == behavior:
			result.append(def)
	return result


## Get definitions by tier
func get_definitions_by_tier(tier: int) -> Array:
	var result: Array = []
	for def in _definitions.values():
		if def.tier == tier:
			result.append(def)
	return result


## Get the count of registered definitions
func get_definition_count() -> int:
	return _definitions.size()


## Unregister a definition
func unregister_definition(id: String) -> bool:
	return _definitions.erase(id)


## Clear all registrations
func clear() -> void:
	_definitions.clear()


## Create an EnemyState from a definition ID
## Returns null if the definition doesn't exist
func create_enemy_state(
	definition_id: String,
	instance_id: String,
	spawn_position: Vector2
) -> RefCounted:
	var definition = get_definition(definition_id)
	if definition == null:
		push_warning("EnemyRegistry: Unknown enemy definition ID: " + definition_id)
		return null

	var EnemyStateScript: GDScript = load("res://shared/entities/enemy_state.gd")
	return EnemyStateScript.create_from_definition(instance_id, definition, spawn_position)
