class_name EnemyAI
extends RefCounted
## Server-side AI controller for enemy behavior.
## Processes AI state transitions and movement each tick.
##
## This is a stateless utility class - all state is stored in EnemyState.
## Call process_enemy() for individual enemies, or process_all() to batch
## process all enemies in an EnemyManager.
##
## State Machine:
##   IDLE -> ROAMING (random) or CHASING (target detected)
##   ROAMING -> IDLE (random) or CHASING (target) or RETURNING (leash)
##   CHASING -> ATTACKING (in range) or IDLE (lost target) or RETURNING (leash)
##   ATTACKING -> CHASING (target moved) or IDLE (lost) or RETURNING (leash)
##   RETURNING -> IDLE (reached spawn)

const EnemyStateScript = preload("res://shared/entities/enemy_state.gd")
const EnemyDefinitionScript = preload("res://shared/entities/enemy_definition.gd")
const GameConstants = preload("res://shared/config/game_constants.gd")


## AI configuration constants
const ROAM_INTERVAL_MIN: float = 3.0  # Minimum seconds between roam decisions
const ROAM_INTERVAL_MAX: float = 8.0  # Maximum seconds between roam decisions
const ROAM_DISTANCE: float = 100.0    # Max distance to roam from spawn
const RETURN_THRESHOLD: float = 16.0  # Distance from spawn to stop returning
const ATTACK_RANGE_BUFFER: float = 8.0  # Get slightly closer than attack range
const ATTACK_EXIT_BUFFER: float = 4.0  # Extra distance before chasing again (hysteresis)
const LEASH_HEAL_RATE: float = 0.1    # HP% healed per second while returning

## Random behavior probabilities (per tick at 20 TPS)
const IDLE_TO_ROAM_CHANCE: float = 0.02  # ~2% chance per tick to start roaming
const ROAM_DIRECTION_CHANGE_CHANCE: float = 0.05  # ~5% chance to change direction
const ROAM_TO_IDLE_CHANCE: float = 0.01  # ~1% chance to stop roaming

## Multiplier for aggro range before enemy loses interest in target
## Provides a buffer so enemies don't immediately lose interest at edge of range
const AGGRO_DROP_MULTIPLIER: float = 1.5


## Process AI for a single enemy
## delta: time since last tick
## current_time: Unix timestamp for cooldowns
## player_positions: Dictionary of player_id -> Vector2 positions
## enemy_definition: The enemy's definition resource
## Returns movement vector (velocity to apply)
static func process_enemy(
	enemy: RefCounted,
	delta: float,
	current_time: float,
	player_positions: Dictionary,
	enemy_definition: Resource
) -> Vector2:
	if not enemy.is_alive:
		return Vector2.ZERO

	# Validate move_speed to prevent invalid movement
	if enemy_definition.move_speed <= 0.0:
		push_warning("EnemyAI: Enemy definition has invalid move_speed: %s" % enemy_definition.id)
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	match enemy.state:
		EnemyStateScript.State.IDLE:
			return _process_idle(enemy, delta, current_time, player_positions, enemy_definition)
		EnemyStateScript.State.ROAMING:
			return _process_roaming(enemy, delta, current_time, player_positions, enemy_definition)
		EnemyStateScript.State.CHASING:
			return _process_chasing(enemy, delta, current_time, player_positions, enemy_definition)
		EnemyStateScript.State.ATTACKING:
			return _process_attacking(enemy, delta, current_time, player_positions, enemy_definition)
		EnemyStateScript.State.RETURNING:
			return _process_returning(enemy, delta, current_time, enemy_definition)
		_:
			return Vector2.ZERO


## IDLE state: Wait, occasionally transition to ROAMING or detect targets
static func _process_idle(
	enemy: RefCounted,
	delta: float,
	current_time: float,
	player_positions: Dictionary,
	enemy_definition: Resource
) -> Vector2:
	# Ensure velocity is zero while idle
	enemy.velocity = Vector2.ZERO

	# Aggressive enemies scan for nearby targets
	if enemy_definition.is_aggressive():
		var target_id: String = _find_nearest_target(enemy.position, player_positions, enemy_definition.aggro_range)
		if not target_id.is_empty():
			enemy.set_target(target_id)
			return Vector2.ZERO

	# Random chance to start roaming
	if randf() < IDLE_TO_ROAM_CHANCE:
		enemy.state = EnemyStateScript.State.ROAMING
		# Pick a random facing direction for roaming
		var angle: float = randf() * TAU
		enemy.facing_direction = Vector2(cos(angle), sin(angle))
		enemy.target_id = ""

	return Vector2.ZERO


## ROAMING state: Move randomly near spawn point
static func _process_roaming(
	enemy: RefCounted,
	delta: float,
	current_time: float,
	player_positions: Dictionary,
	enemy_definition: Resource
) -> Vector2:
	# Check for targets while roaming if aggressive
	if enemy_definition.is_aggressive():
		var target_id: String = _find_nearest_target(enemy.position, player_positions, enemy_definition.aggro_range)
		if not target_id.is_empty():
			enemy.set_target(target_id)
			return Vector2.ZERO

	# If too far from spawn, return
	if enemy.is_beyond_leash_range(enemy_definition.leash_range):
		enemy.state = EnemyStateScript.State.RETURNING
		enemy.target_id = ""
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	# Random movement direction (changes occasionally)
	if randf() < ROAM_DIRECTION_CHANGE_CHANCE:
		enemy.facing_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	# Small chance to return to idle
	if randf() < ROAM_TO_IDLE_CHANCE:
		enemy.state = EnemyStateScript.State.IDLE
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	# Move in facing direction
	var velocity: Vector2 = enemy.facing_direction * enemy_definition.move_speed * delta
	enemy.velocity = enemy.facing_direction * enemy_definition.move_speed
	return velocity


## CHASING state: Pursue target until in attack range or target lost
static func _process_chasing(
	enemy: RefCounted,
	delta: float,
	current_time: float,
	player_positions: Dictionary,
	enemy_definition: Resource
) -> Vector2:
	# Check leash range
	if enemy.is_beyond_leash_range(enemy_definition.leash_range):
		enemy.state = EnemyStateScript.State.RETURNING
		enemy.target_id = ""
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	# Get target position
	var target_pos: Vector2 = player_positions.get(enemy.target_id, Vector2.INF)
	if target_pos == Vector2.INF:
		# Target lost, return to idle
		enemy.clear_target()
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	var distance: float = enemy.position.distance_to(target_pos)
	var attack_range: float = enemy_definition.attack_range - ATTACK_RANGE_BUFFER

	# In attack range - switch to attacking
	if distance <= attack_range:
		enemy.state = EnemyStateScript.State.ATTACKING
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	# Target out of aggro range - lose interest
	if distance > enemy_definition.aggro_range * AGGRO_DROP_MULTIPLIER:
		enemy.clear_target()
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	# Move toward target
	var direction: Vector2 = _direction_to(enemy.position, target_pos)
	enemy.facing_direction = direction
	enemy.velocity = direction * enemy_definition.move_speed
	return direction * enemy_definition.move_speed * delta


## ATTACKING state: Attack target when cooldown ready, chase if too far
static func _process_attacking(
	enemy: RefCounted,
	delta: float,
	current_time: float,
	player_positions: Dictionary,
	enemy_definition: Resource
) -> Vector2:
	# Check leash
	if enemy.is_beyond_leash_range(enemy_definition.leash_range):
		enemy.state = EnemyStateScript.State.RETURNING
		enemy.target_id = ""
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	# Get target position
	var target_pos: Vector2 = player_positions.get(enemy.target_id, Vector2.INF)
	if target_pos == Vector2.INF:
		enemy.clear_target()
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	var distance: float = enemy.position.distance_to(target_pos)

	# Target moved out of attack range - chase again (with hysteresis buffer)
	if distance > enemy_definition.attack_range + ATTACK_EXIT_BUFFER:
		enemy.state = EnemyStateScript.State.CHASING
		var direction: Vector2 = _direction_to(enemy.position, target_pos)
		enemy.facing_direction = direction
		enemy.velocity = direction * enemy_definition.move_speed
		return direction * enemy_definition.move_speed * delta

	# Face target
	enemy.facing_direction = _direction_to(enemy.position, target_pos)
	enemy.velocity = Vector2.ZERO

	# Attack if cooldown ready (actual damage is handled by combat system)
	if enemy.can_attack(enemy_definition.get_attack_cooldown(), current_time):
		enemy.record_attack(current_time)
		# The combat system will check this state and apply damage

	return Vector2.ZERO


## RETURNING state: Return to spawn point, healing along the way
static func _process_returning(
	enemy: RefCounted,
	delta: float,
	current_time: float,
	enemy_definition: Resource
) -> Vector2:
	# Heal while returning
	var heal_amount: float = enemy.max_hp * LEASH_HEAL_RATE * delta
	enemy.heal(heal_amount)

	# Check if we've reached spawn
	if enemy.is_near_spawn(RETURN_THRESHOLD):
		enemy.state = EnemyStateScript.State.IDLE
		enemy.velocity = Vector2.ZERO
		return Vector2.ZERO

	# Move toward spawn
	var direction: Vector2 = _direction_to(enemy.position, enemy.spawn_point)
	enemy.facing_direction = direction
	enemy.velocity = direction * enemy_definition.move_speed
	return direction * enemy_definition.move_speed * delta


## Find the nearest target within range
## Returns target_id or empty string if no target found
static func _find_nearest_target(
	position: Vector2,
	player_positions: Dictionary,
	aggro_range: float
) -> String:
	var nearest_id: String = ""
	var nearest_dist: float = aggro_range

	for player_id in player_positions:
		var player_pos: Vector2 = player_positions[player_id]
		var dist: float = position.distance_to(player_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = player_id

	return nearest_id


## Calculate normalized direction from one point to another
static func _direction_to(from: Vector2, to: Vector2) -> Vector2:
	var diff: Vector2 = to - from
	if diff.length_squared() < 0.01:
		return Vector2.ZERO
	return diff.normalized()


## Process AI for all enemies in a manager
## This is a convenience method for batch processing
static func process_all(
	enemy_manager: RefCounted,
	delta: float,
	current_time: float,
	player_positions: Dictionary
) -> void:
	for enemy in enemy_manager.get_alive_enemies():
		var definition = enemy_manager.get_registry().get_definition(enemy.definition_id)
		if definition == null:
			continue

		var movement: Vector2 = process_enemy(enemy, delta, current_time, player_positions, definition)
		enemy.position += movement

		# Clamp position to world bounds
		enemy.position.x = clampf(enemy.position.x, 0, GameConstants.WORLD_WIDTH)
		enemy.position.y = clampf(enemy.position.y, 0, GameConstants.WORLD_HEIGHT)
