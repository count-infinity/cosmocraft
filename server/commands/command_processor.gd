class_name CommandProcessor
extends RefCounted
## Server-side command parser and executor for admin commands.
## Handles /spawn, /help, and other admin commands.


var _enemy_manager: RefCounted


func _init(enemy_manager: RefCounted) -> void:
	_enemy_manager = enemy_manager


## Execute a command and return result dictionary
## Returns: {"success": bool, "message": String}
func execute(command_text: String, player_position: Vector2) -> Dictionary:
	var parts := command_text.strip_edges().split(" ", false)
	if parts.is_empty():
		return {"success": false, "message": "Empty command"}

	var cmd := parts[0].to_lower()
	if not cmd.begins_with("/"):
		return {"success": false, "message": "Commands must start with /"}

	match cmd:
		"/spawn":
			return _spawn(parts, player_position)
		"/help":
			return {"success": true, "message": "Commands: /spawn <type>, /help"}
		_:
			return {"success": false, "message": "Unknown command: " + cmd}


## Handle /spawn <enemy_type> command
func _spawn(parts: Array, player_pos: Vector2) -> Dictionary:
	if parts.size() < 2:
		return {"success": false, "message": "Usage: /spawn <enemy_type>"}

	var enemy_type: String = parts[1].to_lower()
	var offset := Vector2(randf_range(-80, 80), randf_range(-80, 80))
	var spawn_pos := player_pos + offset

	var enemy = _enemy_manager.spawn_enemy(enemy_type, spawn_pos)
	if enemy == null:
		var types := _get_enemy_types()
		return {"success": false, "message": "Unknown type. Valid: " + ", ".join(types)}

	return {"success": true, "message": "Spawned %s at (%.0f, %.0f)" % [enemy_type, spawn_pos.x, spawn_pos.y]}


## Get list of valid enemy type IDs from registry
func _get_enemy_types() -> Array:
	var types: Array = []
	var registry = _enemy_manager.get_registry()
	for def in registry.get_all_definitions():
		types.append(def.id)
	return types
