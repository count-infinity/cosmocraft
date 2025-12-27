class_name EnemyManager
extends RefCounted
## Server-side manager for enemy instances.
## Handles spawning, tracking, and respawn logic for all enemies.

const EnemyDatabaseScript = preload("res://shared/data/enemy_database.gd")
const EnemyRegistryScript = preload("res://shared/entities/enemy_registry.gd")
const EnemyStateScript = preload("res://shared/entities/enemy_state.gd")


## Signal emitted when an enemy is spawned
signal enemy_spawned(enemy_state: RefCounted)

## Signal emitted when an enemy dies
signal enemy_died(enemy_id: String, killer_id: String)

## Signal emitted when an enemy respawns
signal enemy_respawned(enemy_state: RefCounted)

## Signal emitted when an enemy is removed from the manager
signal enemy_removed(enemy_id: String)


## Registry of all enemy definitions
var _enemy_registry: RefCounted

## All active enemies by ID
var _enemies: Dictionary = {}

## Spawn points for enemies {spawn_id -> spawn_data}
var _spawn_points: Dictionary = {}

## Counter for generating unique enemy IDs
var _next_enemy_id: int = 0

## Counter for generating unique spawn point IDs
var _next_spawn_id: int = 0

## Default respawn time in seconds
const DEFAULT_RESPAWN_TIME: float = 30.0


## Initialize with optional registry injection for dependency injection
func _init(enemy_registry: RefCounted = null) -> void:
	if enemy_registry != null:
		_enemy_registry = enemy_registry
	else:
		# Fallback for standalone/testing
		_enemy_registry = EnemyRegistryScript.new()
		EnemyDatabaseScript.register_all_enemies(_enemy_registry)


## Get the enemy registry
func get_registry() -> RefCounted:
	return _enemy_registry


## Generate a unique enemy ID
func _generate_enemy_id() -> String:
	_next_enemy_id += 1
	return "enemy_%d" % _next_enemy_id


## Generate a unique spawn point ID
func _generate_spawn_id() -> String:
	_next_spawn_id += 1
	return "spawn_%d" % _next_spawn_id


## Spawn an enemy at a specific position
## Returns the EnemyState or null if the definition doesn't exist
func spawn_enemy(definition_id: String, position: Vector2, spawn_id: String = "") -> RefCounted:
	var enemy_id := _generate_enemy_id()
	var enemy_state = _enemy_registry.create_enemy_state(definition_id, enemy_id, position)

	if enemy_state == null:
		push_warning("EnemyManager: Failed to spawn enemy - unknown definition: " + definition_id)
		return null

	_enemies[enemy_id] = enemy_state

	# Connect to damage/death signals for retaliation
	enemy_state.damaged.connect(_on_enemy_damaged.bind(enemy_id))
	enemy_state.died.connect(_on_enemy_died.bind(enemy_id))

	# If this is a spawner-created enemy, track the spawn point
	if not spawn_id.is_empty():
		if _spawn_points.has(spawn_id):
			_spawn_points[spawn_id]["enemy_id"] = enemy_id

	enemy_spawned.emit(enemy_state)
	return enemy_state


## Register a spawn point for enemies
## Returns the spawn_id, or empty string if definition_id is invalid
func register_spawn_point(
	definition_id: String,
	position: Vector2,
	respawn_time: float = DEFAULT_RESPAWN_TIME
) -> String:
	# Validate definition exists
	if not _enemy_registry.has_definition(definition_id):
		push_warning("EnemyManager: Unknown definition ID for spawn point: " + definition_id)
		return ""

	var spawn_id := _generate_spawn_id()
	_spawn_points[spawn_id] = {
		"definition_id": definition_id,
		"position": position,
		"respawn_time": respawn_time,
		"enemy_id": "",
		"respawn_at": 0.0
	}
	return spawn_id


## Unregister a spawn point
## Returns true if the spawn point was found and removed
func unregister_spawn_point(spawn_id: String) -> bool:
	if not _spawn_points.has(spawn_id):
		return false

	# Remove any associated enemy
	var spawn_data: Dictionary = _spawn_points[spawn_id]
	var enemy_id: String = spawn_data.get("enemy_id", "")
	if not enemy_id.is_empty() and has_enemy(enemy_id):
		remove_enemy(enemy_id)

	_spawn_points.erase(spawn_id)
	return true


## Spawn an enemy at a registered spawn point
func spawn_at_spawn_point(spawn_id: String) -> RefCounted:
	if not _spawn_points.has(spawn_id):
		push_warning("EnemyManager: Unknown spawn point: " + spawn_id)
		return null

	var spawn_data: Dictionary = _spawn_points[spawn_id]
	return spawn_enemy(spawn_data["definition_id"], spawn_data["position"], spawn_id)


## Get an enemy by ID
func get_enemy(enemy_id: String) -> RefCounted:
	return _enemies.get(enemy_id)


## Check if an enemy exists
func has_enemy(enemy_id: String) -> bool:
	return enemy_id in _enemies


## Get all enemies
func get_all_enemies() -> Array:
	return _enemies.values()


## Get all enemy IDs
func get_all_enemy_ids() -> Array:
	return _enemies.keys()


## Get enemy count
func get_enemy_count() -> int:
	return _enemies.size()


## Get enemies near a position
func get_enemies_near(position: Vector2, radius: float) -> Array:
	var nearby: Array = []
	var radius_sq := radius * radius

	for enemy_id in _enemies:
		var enemy: RefCounted = _enemies[enemy_id]
		if not enemy.is_alive:
			continue
		var dist_sq := position.distance_squared_to(enemy.position)
		if dist_sq <= radius_sq:
			nearby.append(enemy)

	return nearby


## Get alive enemies only
func get_alive_enemies() -> Array:
	var alive: Array = []
	for enemy in _enemies.values():
		if enemy.is_alive:
			alive.append(enemy)
	return alive


## Remove an enemy and disconnect its signals properly
func remove_enemy(enemy_id: String) -> bool:
	if not _enemies.has(enemy_id):
		return false

	var enemy = _enemies[enemy_id]

	# Disconnect all signal connections from this enemy to this manager
	# Must iterate through connections because .bind() creates new callables
	for connection in enemy.damaged.get_connections():
		if connection["callable"].get_object() == self:
			enemy.damaged.disconnect(connection["callable"])
	for connection in enemy.died.get_connections():
		if connection["callable"].get_object() == self:
			enemy.died.disconnect(connection["callable"])

	_enemies.erase(enemy_id)
	enemy_removed.emit(enemy_id)
	return true


## Process respawn timers
## Call this periodically (e.g., every tick or every second)
## current_time: Unix timestamp from Time.get_unix_time_from_system()
## Returns array of respawned enemy states
func process_respawns(current_time: float) -> Array:
	var respawned: Array = []

	for spawn_id in _spawn_points:
		var spawn_data: Dictionary = _spawn_points[spawn_id]

		# Check if this spawn point has an active enemy
		var enemy_id: String = spawn_data.get("enemy_id", "")
		if not enemy_id.is_empty():
			var enemy = _enemies.get(enemy_id)
			if enemy != null and enemy.is_alive:
				continue  # Enemy still alive, skip
			elif enemy != null and not enemy.is_alive:
				# Enemy died, schedule respawn if not already scheduled
				if spawn_data["respawn_at"] <= 0.0:
					spawn_data["respawn_at"] = current_time + spawn_data["respawn_time"]
					remove_enemy(enemy_id)
					spawn_data["enemy_id"] = ""

		# Check if it's time to respawn
		if spawn_data["respawn_at"] > 0.0 and current_time >= spawn_data["respawn_at"]:
			spawn_data["respawn_at"] = 0.0
			var new_enemy = spawn_at_spawn_point(spawn_id)
			if new_enemy != null:
				respawned.append(new_enemy)
				enemy_respawned.emit(new_enemy)

	return respawned


## Apply damage to an enemy
## Returns actual damage taken, or -1 if enemy not found
func damage_enemy(enemy_id: String, amount: float, attacker_id: String = "") -> float:
	var enemy = _enemies.get(enemy_id)
	if enemy == null:
		return -1.0

	return enemy.take_damage(amount, attacker_id)


## Handle enemy damaged (for AI retaliation)
func _on_enemy_damaged(amount: float, attacker_id: String, enemy_id: String) -> void:
	var enemy = _enemies.get(enemy_id)
	if enemy == null:
		return

	# Get the enemy's definition to check behavior type
	var definition = _enemy_registry.get_definition(enemy.definition_id)
	if definition == null:
		return

	# Only retaliate if not passive
	if definition.will_retaliate():
		enemy.handle_retaliation(attacker_id)


## Handle enemy death
func _on_enemy_died(enemy_id: String) -> void:
	var enemy = _enemies.get(enemy_id)
	if enemy == null:
		return

	# Use last_attacker_id for accurate kill attribution
	var killer_id: String = enemy.last_attacker_id
	enemy_died.emit(enemy_id, killer_id)


## Serialize all enemy states for network sync
func serialize_all() -> Array:
	var result: Array = []
	for enemy in _enemies.values():
		result.append(enemy.to_dict())
	return result


## Serialize enemies near a position (for client streaming)
func serialize_near(position: Vector2, radius: float) -> Array:
	var result: Array = []
	var nearby := get_enemies_near(position, radius)
	for enemy in nearby:
		result.append(enemy.to_dict())
	return result


## Clear all enemies and spawn points, disconnecting all signals
func clear() -> void:
	# Disconnect all enemy signals properly
	for enemy_id in _enemies.keys():
		var enemy = _enemies[enemy_id]
		for connection in enemy.damaged.get_connections():
			if connection["callable"].get_object() == self:
				enemy.damaged.disconnect(connection["callable"])
		for connection in enemy.died.get_connections():
			if connection["callable"].get_object() == self:
				enemy.died.disconnect(connection["callable"])

	_enemies.clear()
	_spawn_points.clear()
	_next_enemy_id = 0
	_next_spawn_id = 0


## Get spawn point count
func get_spawn_point_count() -> int:
	return _spawn_points.size()


## Spawn all registered spawn points
func spawn_all_spawn_points() -> int:
	var count := 0
	for spawn_id in _spawn_points:
		if spawn_at_spawn_point(spawn_id) != null:
			count += 1
	return count
