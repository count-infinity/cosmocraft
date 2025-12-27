extends GutTest
## Unit tests for the CombatProcessor class.

const CombatProcessorScript = preload("res://server/combat/combat_processor.gd")
const EnemyManagerScript = preload("res://server/enemies/enemy_manager.gd")
const EnemyStateScript = preload("res://shared/entities/enemy_state.gd")
const HealthComponentScript = preload("res://shared/components/health_component.gd")
const TargetDataScript = preload("res://shared/combat/target_data.gd")


# =============================================================================
# Helper Methods
# =============================================================================

func create_enemy_manager() -> RefCounted:
	return EnemyManagerScript.new()


func create_health_component(max_hp: float = 100.0) -> RefCounted:
	return HealthComponentScript.new(max_hp)


# =============================================================================
# Player Attack Tests - Melee Arc
# =============================================================================

func test_player_melee_arc_hit() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(50, 0))

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),  # Aiming right
		"melee_arc",
		100.0,  # Range
		90.0,   # 90 degree arc
		25.0,   # Base damage
		manager
	)

	assert_eq(result.hits.size(), 1)
	assert_eq(result.damage_dealt.size(), 1)
	assert_gt(result.damage_dealt[0], 0.0)


func test_player_melee_arc_miss_behind() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(-50, 0))  # Behind attacker

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),  # Aiming right
		"melee_arc",
		100.0,
		90.0,
		25.0,
		manager
	)

	assert_eq(result.hits.size(), 0)


func test_player_melee_arc_miss_out_of_range() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(200, 0))  # Far away

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_arc",
		50.0,  # Short range
		90.0,
		25.0,
		manager
	)

	assert_eq(result.hits.size(), 0)


func test_player_melee_arc_multiple_hits() -> void:
	var manager = create_enemy_manager()
	manager.spawn_enemy("wolf", Vector2(40, -10))
	manager.spawn_enemy("wolf", Vector2(40, 10))
	manager.spawn_enemy("wolf", Vector2(-40, 0))  # Behind, should miss

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_arc",
		100.0,
		180.0,  # Wide arc
		10.0,
		manager
	)

	assert_eq(result.hits.size(), 2)
	assert_eq(result.damage_dealt.size(), 2)


# =============================================================================
# Player Attack Tests - Melee Thrust
# =============================================================================

func test_player_melee_thrust_hit() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_thrust",
		50.0,
		0.0,  # No arc for thrust
		20.0,
		manager
	)

	assert_eq(result.hits.size(), 1)


func test_player_melee_thrust_miss_off_line() -> void:
	var manager = create_enemy_manager()
	# Enemy far off to the side
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 50))

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_thrust",
		50.0,
		0.0,
		20.0,
		manager
	)

	assert_eq(result.hits.size(), 0)


# =============================================================================
# Player Attack Tests - Ranged
# =============================================================================

func test_player_ranged_hit() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(100, 0))

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"ranged",
		200.0,
		0.0,
		15.0,
		manager
	)

	assert_eq(result.hits.size(), 1)


func test_player_ranged_hits_closest() -> void:
	var manager = create_enemy_manager()
	manager.spawn_enemy("wolf", Vector2(100, 0))  # Far
	manager.spawn_enemy("wolf", Vector2(50, 0))   # Close

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"ranged",
		200.0,
		0.0,
		15.0,
		manager
	)

	# Ranged only hits closest target
	assert_eq(result.hits.size(), 1)
	assert_lt(result.hits[0].distance, 60.0)


func test_player_ranged_miss_out_of_range() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(300, 0))

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"ranged",
		100.0,  # Short range
		0.0,
		15.0,
		manager
	)

	assert_eq(result.hits.size(), 0)


# =============================================================================
# Player Attack - Kill Enemy
# =============================================================================

func test_player_attack_kills_enemy() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("rabbit", Vector2(30, 0))  # Rabbit has low HP
	var initial_hp: float = enemy.current_hp

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_arc",
		50.0,
		90.0,
		1000.0,  # Massive damage
		manager
	)

	assert_eq(result.hits.size(), 1)
	assert_eq(result.enemies_killed.size(), 1)
	assert_eq(result.enemies_killed[0], enemy.id)
	assert_false(enemy.is_alive)


func test_player_attack_triggers_retaliation() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))
	assert_eq(enemy.target_id, "")

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_arc",
		50.0,
		90.0,
		10.0,
		manager
	)

	# Wolf is aggressive and should retaliate
	assert_eq(result.hits.size(), 1)
	assert_eq(enemy.target_id, "player_1")
	assert_eq(enemy.state, EnemyStateScript.State.CHASING)


# =============================================================================
# Enemy Attack Tests
# =============================================================================

func test_enemy_attack_damages_player() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))

	# Set up enemy to attack
	enemy.state = EnemyStateScript.State.ATTACKING
	enemy.target_id = "player_1"
	enemy.last_attack_time = 1.0

	var player_health = create_health_component(100.0)
	var initial_hp: float = player_health.current_hp

	var player_healths := {"player_1": player_health}
	var player_positions := {"player_1": Vector2(30, 0)}

	var results = CombatProcessorScript.process_enemy_attacks(
		manager,
		player_positions,
		player_healths,
		1.0  # current_time matches last_attack_time
	)

	assert_eq(results.size(), 1)
	assert_lt(player_health.current_hp, initial_hp)


func test_enemy_attack_no_target() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))

	# Enemy in attacking state but no target
	enemy.state = EnemyStateScript.State.ATTACKING
	enemy.target_id = ""
	enemy.last_attack_time = 1.0

	var player_healths := {"player_1": create_health_component()}
	var player_positions := {"player_1": Vector2(30, 0)}

	var results = CombatProcessorScript.process_enemy_attacks(
		manager,
		player_positions,
		player_healths,
		1.0
	)

	assert_eq(results.size(), 0)


func test_enemy_attack_not_in_attacking_state() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))

	# Enemy chasing, not attacking
	enemy.state = EnemyStateScript.State.CHASING
	enemy.target_id = "player_1"

	var player_healths := {"player_1": create_health_component()}
	var player_positions := {"player_1": Vector2(30, 0)}

	var results = CombatProcessorScript.process_enemy_attacks(
		manager,
		player_positions,
		player_healths,
		1.0
	)

	assert_eq(results.size(), 0)


func test_single_enemy_attack() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))
	var definition = manager.get_registry().get_definition("wolf")
	var player_health = create_health_component(100.0)

	var result = CombatProcessorScript.process_single_enemy_attack(
		enemy,
		definition,
		"player_1",
		player_health,
		1.0  # current_time
	)

	assert_eq(result.enemy_id, enemy.id)
	assert_eq(result.target_id, "player_1")
	assert_gt(result.damage, 0.0)
	assert_lt(player_health.current_hp, 100.0)


func test_single_enemy_attack_kills_player() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))
	var definition = manager.get_registry().get_definition("wolf")
	var player_health = create_health_component(1.0)  # Very low HP

	var result = CombatProcessorScript.process_single_enemy_attack(
		enemy,
		definition,
		"player_1",
		player_health,
		1.0  # current_time
	)

	assert_true(result.target_killed)
	assert_true(player_health.is_dead)


# =============================================================================
# Target Building Tests
# =============================================================================

func test_build_enemy_targets() -> void:
	var manager = create_enemy_manager()
	manager.spawn_enemy("wolf", Vector2(100, 100))
	manager.spawn_enemy("rabbit", Vector2(200, 200))

	var targets = CombatProcessorScript.build_enemy_targets(manager)

	assert_eq(targets.size(), 2)
	assert_true(targets[0].is_enemy())


func test_build_enemy_targets_excludes_dead() -> void:
	var manager = create_enemy_manager()
	var alive = manager.spawn_enemy("wolf", Vector2(100, 100))
	var dead = manager.spawn_enemy("wolf", Vector2(200, 200))
	dead.is_alive = false

	var targets = CombatProcessorScript.build_enemy_targets(manager)

	assert_eq(targets.size(), 1)


func test_build_player_targets() -> void:
	var player_positions := {
		"player_1": Vector2(0, 0),
		"player_2": Vector2(100, 100)
	}

	var targets = CombatProcessorScript.build_player_targets(player_positions)

	assert_eq(targets.size(), 2)
	assert_true(targets[0].is_player())


# =============================================================================
# Unknown Attack Type
# =============================================================================

func test_unknown_attack_type() -> void:
	var manager = create_enemy_manager()
	manager.spawn_enemy("wolf", Vector2(50, 0))

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"magic_beam",  # Unknown type
		100.0,
		90.0,
		25.0,
		manager
	)

	# Should return empty result with warning
	assert_eq(result.hits.size(), 0)


# =============================================================================
# Edge Cases
# =============================================================================

func test_attack_no_enemies() -> void:
	var manager = create_enemy_manager()

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_arc",
		100.0,
		90.0,
		25.0,
		manager
	)

	assert_eq(result.hits.size(), 0)
	assert_eq(result.damage_dealt.size(), 0)
	assert_eq(result.enemies_killed.size(), 0)


func test_attack_all_enemies_dead() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(50, 0))
	enemy.is_alive = false

	var result = CombatProcessorScript.process_player_attack(
		"player_1",
		Vector2(0, 0),
		Vector2(1, 0),
		"melee_arc",
		100.0,
		90.0,
		25.0,
		manager
	)

	assert_eq(result.hits.size(), 0)


func test_enemy_attacks_target_not_in_positions() -> void:
	var manager = create_enemy_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2(30, 0))
	enemy.state = EnemyStateScript.State.ATTACKING
	enemy.target_id = "disconnected_player"
	enemy.last_attack_time = 1.0

	var player_healths := {"player_1": create_health_component()}
	var player_positions := {"player_1": Vector2(30, 0)}  # No disconnected_player

	var results = CombatProcessorScript.process_enemy_attacks(
		manager,
		player_positions,
		player_healths,
		1.0
	)

	assert_eq(results.size(), 0)
