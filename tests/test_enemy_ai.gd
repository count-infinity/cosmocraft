extends GutTest
## Unit tests for the EnemyAI class.

const EnemyAIScript = preload("res://server/enemies/enemy_ai.gd")
const EnemyStateScript = preload("res://shared/entities/enemy_state.gd")
const EnemyDefinitionScript = preload("res://shared/entities/enemy_definition.gd")
const EnemyManagerScript = preload("res://server/enemies/enemy_manager.gd")


# =============================================================================
# Helper Methods
# =============================================================================

func create_test_definition(behavior: int = EnemyDefinitionScript.BehaviorType.AGGRESSIVE) -> Resource:
	var def = EnemyDefinitionScript.new("test_enemy", "Test Enemy", 100.0, 10.0)
	def.behavior_type = behavior
	def.move_speed = 100.0
	def.attack_range = 50.0
	def.aggro_range = 200.0
	def.leash_range = 300.0
	def.attack_speed = 1.0
	return def


func create_test_enemy(pos: Vector2 = Vector2.ZERO, state: int = EnemyStateScript.State.IDLE) -> RefCounted:
	var enemy = EnemyStateScript.new("test_enemy_1", "test_enemy", pos, 100.0)
	enemy.state = state
	return enemy


# =============================================================================
# State Detection Tests
# =============================================================================

func test_idle_enemy_detects_target() -> void:
	var enemy = create_test_enemy(Vector2(100, 100))
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(150, 100)}  # 50 units away

	# Note: IDLE has random roaming chance, so we may need to call multiple times
	# For deterministic testing, we check that IF detection occurs, state changes
	seed(12345)  # Seed for reproducibility
	for i in range(20):  # Try multiple times to trigger detection
		if enemy.state == EnemyStateScript.State.CHASING:
			break
		EnemyAIScript.process_enemy(enemy, 0.05, 1.0, player_positions, definition)

	# After enough iterations with a nearby player, aggressive enemy should detect
	assert_eq(enemy.state, EnemyStateScript.State.CHASING)
	assert_eq(enemy.target_id, "player_1")


func test_idle_passive_enemy_does_not_detect() -> void:
	var enemy = create_test_enemy(Vector2(100, 100))
	var definition = create_test_definition(EnemyDefinitionScript.BehaviorType.PASSIVE)
	var player_positions := {"player_1": Vector2(110, 100)}  # Very close

	# Run multiple iterations
	seed(12345)
	for i in range(50):
		EnemyAIScript.process_enemy(enemy, 0.05, 1.0, player_positions, definition)

	# Passive enemy should not detect player and enter chasing
	assert_ne(enemy.state, EnemyStateScript.State.CHASING)
	assert_eq(enemy.target_id, "")


func test_idle_neutral_enemy_does_not_detect() -> void:
	var enemy = create_test_enemy(Vector2(100, 100))
	var definition = create_test_definition(EnemyDefinitionScript.BehaviorType.NEUTRAL)
	var player_positions := {"player_1": Vector2(110, 100)}  # Very close

	# Run multiple iterations
	seed(12345)
	for i in range(50):
		EnemyAIScript.process_enemy(enemy, 0.05, 1.0, player_positions, definition)

	# Neutral enemy should not detect player on its own (like passive)
	assert_ne(enemy.state, EnemyStateScript.State.CHASING)
	assert_eq(enemy.target_id, "")


func test_idle_can_transition_to_roaming() -> void:
	var enemy = create_test_enemy(Vector2(100, 100))
	var definition = create_test_definition(EnemyDefinitionScript.BehaviorType.PASSIVE)  # No detection
	var player_positions := {}  # No players

	seed(12345)
	var found_roaming := false
	for i in range(100):
		EnemyAIScript.process_enemy(enemy, 0.05, 1.0, player_positions, definition)
		if enemy.state == EnemyStateScript.State.ROAMING:
			found_roaming = true
			break

	assert_true(found_roaming, "Enemy should eventually transition to roaming")


# =============================================================================
# Chasing Tests
# =============================================================================

func test_chasing_moves_toward_target() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.CHASING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(200, 0)}  # 200 units to the right

	var movement := EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	# Should move toward player
	assert_gt(movement.x, 0)
	assert_almost_eq(movement.y, 0.0, 0.01)


func test_chasing_enters_attack_range() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.CHASING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(40, 0)}  # Within attack range (50)

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(enemy.state, EnemyStateScript.State.ATTACKING)


func test_chasing_loses_target_when_out_of_range() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.CHASING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(500, 0)}  # Way beyond detection range * 1.5

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(enemy.state, EnemyStateScript.State.IDLE)
	assert_eq(enemy.target_id, "")


func test_chasing_loses_target_when_target_disconnects() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.CHASING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	var player_positions := {}  # Player left the game

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(enemy.state, EnemyStateScript.State.IDLE)
	assert_eq(enemy.target_id, "")


func test_chasing_returns_when_beyond_leash() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.CHASING)
	enemy.target_id = "player_1"
	enemy.position = Vector2(400, 0)  # Beyond leash range (300)
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(500, 0)}

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(enemy.state, EnemyStateScript.State.RETURNING)
	assert_eq(enemy.target_id, "")


# =============================================================================
# Attacking Tests
# =============================================================================

func test_attacking_stays_in_place() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.ATTACKING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(30, 0)}  # In attack range

	var movement := EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(movement, Vector2.ZERO)
	assert_eq(enemy.velocity, Vector2.ZERO)


func test_attacking_records_attack_when_ready() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.ATTACKING)
	enemy.target_id = "player_1"
	enemy.last_attack_time = 0.0
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(30, 0)}

	var current_time := 5.0  # Well past cooldown (1 second)
	EnemyAIScript.process_enemy(enemy, 0.1, current_time, player_positions, definition)

	assert_eq(enemy.last_attack_time, current_time)


func test_attacking_chases_when_target_moves_away() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.ATTACKING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	# Must be beyond attack_range + ATTACK_EXIT_BUFFER (50 + 4 = 54) for hysteresis
	var player_positions := {"player_1": Vector2(100, 0)}  # Well outside attack range

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(enemy.state, EnemyStateScript.State.CHASING)


func test_attacking_returns_when_beyond_leash() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.ATTACKING)
	enemy.target_id = "player_1"
	enemy.position = Vector2(350, 0)  # Beyond leash
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(380, 0)}

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(enemy.state, EnemyStateScript.State.RETURNING)


# =============================================================================
# Returning Tests
# =============================================================================

func test_returning_moves_toward_spawn() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.RETURNING)
	enemy.position = Vector2(200, 100)  # Away from spawn
	var definition = create_test_definition()

	var movement := EnemyAIScript.process_enemy(enemy, 0.1, 1.0, {}, definition)

	# Should move toward spawn (negative x direction)
	assert_lt(movement.x, 0)


func test_returning_heals() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.RETURNING)
	enemy.position = Vector2(200, 100)
	enemy.current_hp = 50.0  # Half health
	var definition = create_test_definition()

	EnemyAIScript.process_enemy(enemy, 1.0, 1.0, {}, definition)

	# Should have healed (10% of max HP per second = 10 HP)
	assert_gt(enemy.current_hp, 50.0)


func test_returning_transitions_to_idle_at_spawn() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.RETURNING)
	enemy.position = Vector2(105, 100)  # Very close to spawn
	var definition = create_test_definition()

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, {}, definition)

	assert_eq(enemy.state, EnemyStateScript.State.IDLE)


# =============================================================================
# Roaming Tests
# =============================================================================

func test_roaming_moves() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.ROAMING)
	enemy.facing_direction = Vector2(1, 0)  # Facing right
	var definition = create_test_definition(EnemyDefinitionScript.BehaviorType.PASSIVE)

	var movement := EnemyAIScript.process_enemy(enemy, 0.1, 1.0, {}, definition)

	# Should move in facing direction
	assert_gt(movement.length(), 0)


func test_roaming_detects_target_if_aggressive() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.ROAMING)
	var definition = create_test_definition()  # Aggressive
	var player_positions := {"player_1": Vector2(150, 100)}

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(enemy.state, EnemyStateScript.State.CHASING)
	assert_eq(enemy.target_id, "player_1")


func test_roaming_returns_when_too_far() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.ROAMING)
	enemy.position = Vector2(500, 100)  # Beyond leash range
	var definition = create_test_definition(EnemyDefinitionScript.BehaviorType.PASSIVE)

	EnemyAIScript.process_enemy(enemy, 0.1, 1.0, {}, definition)

	assert_eq(enemy.state, EnemyStateScript.State.RETURNING)


# =============================================================================
# Utility Tests
# =============================================================================

func test_find_nearest_target() -> void:
	var position := Vector2(0, 0)
	var player_positions := {
		"player_1": Vector2(100, 0),
		"player_2": Vector2(50, 0),  # Closer
		"player_3": Vector2(200, 0)
	}

	var nearest := EnemyAIScript._find_nearest_target(position, player_positions, 150.0)

	assert_eq(nearest, "player_2")


func test_find_nearest_target_none_in_range() -> void:
	var position := Vector2(0, 0)
	var player_positions := {
		"player_1": Vector2(300, 0),
		"player_2": Vector2(400, 0)
	}

	var nearest := EnemyAIScript._find_nearest_target(position, player_positions, 100.0)

	assert_eq(nearest, "")


func test_direction_to() -> void:
	var from := Vector2(0, 0)
	var to := Vector2(100, 0)

	var direction := EnemyAIScript._direction_to(from, to)

	assert_eq(direction, Vector2(1, 0))


func test_direction_to_same_point() -> void:
	var pos := Vector2(50, 50)

	var direction := EnemyAIScript._direction_to(pos, pos)

	assert_eq(direction, Vector2.ZERO)


# =============================================================================
# Dead Enemy Tests
# =============================================================================

func test_dead_enemy_does_not_process() -> void:
	var enemy = create_test_enemy(Vector2(0, 0), EnemyStateScript.State.DEAD)
	enemy.is_alive = false
	var definition = create_test_definition()
	var player_positions := {"player_1": Vector2(50, 0)}

	var movement := EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(movement, Vector2.ZERO)
	assert_eq(enemy.state, EnemyStateScript.State.DEAD)


# =============================================================================
# Batch Processing Tests
# =============================================================================

func test_process_all_updates_enemies() -> void:
	var manager = EnemyManagerScript.new()
	var enemy1 = manager.spawn_enemy("wolf", Vector2(100, 100))
	var enemy2 = manager.spawn_enemy("wolf", Vector2(200, 200))

	# Set them both to chase
	enemy1.state = EnemyStateScript.State.CHASING
	enemy1.target_id = "player_1"
	enemy2.state = EnemyStateScript.State.CHASING
	enemy2.target_id = "player_1"

	var player_positions := {"player_1": Vector2(300, 300)}

	EnemyAIScript.process_all(manager, 0.1, 1.0, player_positions)

	# Both enemies should have moved
	assert_gt(enemy1.position.x, 100)
	assert_gt(enemy2.position.x, 200)


# =============================================================================
# Validation Tests
# =============================================================================

func test_invalid_move_speed_returns_zero() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.CHASING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	definition.move_speed = 0.0  # Invalid move speed
	var player_positions := {"player_1": Vector2(200, 100)}

	var movement := EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(movement, Vector2.ZERO)
	assert_eq(enemy.velocity, Vector2.ZERO)


func test_negative_move_speed_returns_zero() -> void:
	var enemy = create_test_enemy(Vector2(100, 100), EnemyStateScript.State.CHASING)
	enemy.target_id = "player_1"
	var definition = create_test_definition()
	definition.move_speed = -50.0  # Negative move speed
	var player_positions := {"player_1": Vector2(200, 100)}

	var movement := EnemyAIScript.process_enemy(enemy, 0.1, 1.0, player_positions, definition)

	assert_eq(movement, Vector2.ZERO)
	assert_eq(enemy.velocity, Vector2.ZERO)
