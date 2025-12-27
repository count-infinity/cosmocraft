extends GutTest
## Unit tests for the CombatComponent class (Phase 2 Combat System).


const CombatComponentScript = preload("res://shared/components/combat_component.gd")


# =============================================================================
# Test Fixtures
# =============================================================================

var _combat: CombatComponentScript


func before_each() -> void:
	_combat = CombatComponentScript.new(
		10.0,   # base_damage
		2.0,    # attack_speed (2 attacks per second = 0.5s cooldown)
		100.0,  # attack_range
		90.0    # attack_arc
	)


# =============================================================================
# Initialization Tests
# =============================================================================

func test_initial_state() -> void:
	assert_eq(_combat.base_damage, 10.0)
	assert_eq(_combat.attack_speed, 2.0)
	assert_eq(_combat.attack_range, 100.0)
	assert_eq(_combat.attack_arc, 90.0)
	assert_eq(_combat.attack_cooldown, 0.0)
	assert_false(_combat.is_attacking)
	assert_eq(_combat.current_attack_type, CombatComponentScript.AttackType.MELEE)


func test_default_constructor() -> void:
	var combat := CombatComponentScript.new()
	assert_eq(combat.base_damage, 5.0)
	assert_eq(combat.attack_speed, 1.0)
	assert_eq(combat.attack_range, 50.0)
	assert_eq(combat.attack_arc, 90.0)


# =============================================================================
# Can Attack Tests
# =============================================================================

func test_can_attack_initially() -> void:
	assert_true(_combat.can_attack())


func test_cannot_attack_on_cooldown() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	assert_false(_combat.can_attack())


func test_cannot_attack_while_attacking() -> void:
	_combat.is_attacking = true
	assert_false(_combat.can_attack())


func test_can_attack_after_cooldown_expires() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()

	# Tick past the cooldown (0.5 seconds for 2 attacks/sec)
	_combat.tick(0.5)
	assert_true(_combat.can_attack())


# =============================================================================
# Start Attack Tests
# =============================================================================

func test_start_attack_success() -> void:
	var result: bool = _combat.start_attack(CombatComponentScript.AttackType.MELEE, Vector2.RIGHT)
	assert_true(result)
	assert_true(_combat.is_attacking)
	assert_eq(_combat.current_attack_type, CombatComponentScript.AttackType.MELEE)
	assert_gt(_combat.attack_cooldown, 0.0)


func test_start_attack_sets_cooldown() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	# 2 attacks per second = 0.5 second cooldown
	assert_almost_eq(_combat.attack_cooldown, 0.5, 0.001)


func test_start_attack_fails_on_cooldown() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()

	var result: bool = _combat.start_attack(CombatComponentScript.AttackType.MELEE)
	assert_false(result)


func test_start_attack_emits_signal() -> void:
	watch_signals(_combat)
	_combat.start_attack(CombatComponentScript.AttackType.RANGED, Vector2.UP)
	assert_signal_emitted(_combat, "attack_started")


func test_start_attack_ranged_type() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.RANGED)
	assert_eq(_combat.current_attack_type, CombatComponentScript.AttackType.RANGED)


# =============================================================================
# Complete Attack Tests
# =============================================================================

func test_complete_attack() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	assert_true(_combat.is_attacking)

	_combat.complete_attack()
	assert_false(_combat.is_attacking)


func test_complete_attack_emits_signal() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	watch_signals(_combat)

	_combat.complete_attack()
	assert_signal_emitted(_combat, "attack_completed")


func test_complete_attack_when_not_attacking() -> void:
	watch_signals(_combat)
	_combat.complete_attack()
	# Should not emit signal if not attacking
	assert_signal_not_emitted(_combat, "attack_completed")


# =============================================================================
# Tick Tests
# =============================================================================

func test_tick_reduces_cooldown() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()
	var initial_cooldown: float = _combat.attack_cooldown

	_combat.tick(0.1)
	assert_almost_eq(_combat.attack_cooldown, initial_cooldown - 0.1, 0.001)


func test_tick_cooldown_stops_at_zero() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()

	_combat.tick(10.0)  # More than cooldown duration
	assert_eq(_combat.attack_cooldown, 0.0)


func test_tick_emits_cooldown_ready() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()
	watch_signals(_combat)

	_combat.tick(1.0)  # Enough time to complete cooldown
	assert_signal_emitted(_combat, "cooldown_ready")


func test_tick_auto_completes_attack() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	assert_true(_combat.is_attacking)

	# Tick past cooldown - should auto-complete
	_combat.tick(1.0)
	assert_false(_combat.is_attacking)


# =============================================================================
# Cooldown Methods Tests
# =============================================================================

func test_get_cooldown_remaining() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()

	assert_almost_eq(_combat.get_cooldown_remaining(), 0.5, 0.001)


func test_get_cooldown_remaining_capped_at_zero() -> void:
	assert_eq(_combat.get_cooldown_remaining(), 0.0)

	_combat.attack_cooldown = -1.0  # Simulate underflow
	assert_eq(_combat.get_cooldown_remaining(), 0.0)


func test_get_cooldown_percent_full() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()

	# Just started cooldown, should be at 100%
	assert_almost_eq(_combat.get_cooldown_percent(), 1.0, 0.001)


func test_get_cooldown_percent_half() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.complete_attack()
	_combat.tick(0.25)  # Half of 0.5 second cooldown

	assert_almost_eq(_combat.get_cooldown_percent(), 0.5, 0.001)


func test_get_cooldown_percent_zero() -> void:
	assert_eq(_combat.get_cooldown_percent(), 0.0)


func test_get_cooldown_percent_zero_attack_speed() -> void:
	_combat.attack_speed = 0.0
	assert_eq(_combat.get_cooldown_percent(), 0.0)


# =============================================================================
# Attack Type Helper Tests
# =============================================================================

func test_is_melee() -> void:
	_combat.current_attack_type = CombatComponentScript.AttackType.MELEE
	assert_true(_combat.is_melee())
	assert_false(_combat.is_ranged())


func test_is_ranged() -> void:
	_combat.current_attack_type = CombatComponentScript.AttackType.RANGED
	assert_false(_combat.is_melee())
	assert_true(_combat.is_ranged())


# =============================================================================
# Movement Pause Tests
# =============================================================================

func test_should_pause_movement_not_attacking() -> void:
	assert_false(_combat.should_pause_movement())


func test_should_pause_movement_ranged() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.RANGED)
	# Ranged attacks don't pause movement
	assert_false(_combat.should_pause_movement())


func test_should_pause_movement_melee_initial() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	# Should pause during initial phase
	assert_true(_combat.should_pause_movement())


func test_should_pause_movement_melee_after_pause_duration() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	# Tick past the pause duration but not past cooldown
	_combat.tick(CombatComponentScript.MELEE_PAUSE_DURATION + 0.01)

	# Should no longer pause after pause duration
	assert_false(_combat.should_pause_movement())


# =============================================================================
# Configure Weapon Tests
# =============================================================================

func test_configure_from_weapon() -> void:
	_combat.configure_from_weapon(
		25.0,  # damage
		3.0,   # speed
		150.0, # range
		45.0,  # arc
		CombatComponentScript.AttackType.RANGED
	)

	assert_eq(_combat.base_damage, 25.0)
	assert_eq(_combat.attack_speed, 3.0)
	assert_eq(_combat.attack_range, 150.0)
	assert_eq(_combat.attack_arc, 45.0)
	assert_eq(_combat.current_attack_type, CombatComponentScript.AttackType.RANGED)


# =============================================================================
# Reset Tests
# =============================================================================

func test_reset() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	assert_true(_combat.is_attacking)
	assert_gt(_combat.attack_cooldown, 0.0)

	_combat.reset()

	assert_eq(_combat.attack_cooldown, 0.0)
	assert_false(_combat.is_attacking)


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.RANGED, Vector2.RIGHT)
	_combat.tick(0.1)

	var dict: Dictionary = _combat.to_dict()

	assert_true(dict.has("attack_cooldown"))
	assert_true(dict.has("is_attacking"))
	assert_true(dict.has("current_attack_type"))
	assert_true(dict.has("base_damage"))
	assert_true(dict.has("attack_speed"))
	assert_true(dict.has("attack_range"))
	assert_true(dict.has("attack_arc"))

	assert_eq(dict["base_damage"], 10.0)
	assert_eq(dict["attack_speed"], 2.0)
	assert_eq(dict["current_attack_type"], CombatComponentScript.AttackType.RANGED)


func test_from_dict() -> void:
	var dict := {
		"attack_cooldown": 0.25,
		"is_attacking": false,
		"current_attack_type": CombatComponentScript.AttackType.RANGED,
		"base_damage": 15.0,
		"attack_speed": 2.5,
		"attack_range": 200.0,
		"attack_arc": 60.0
	}

	var combat := CombatComponentScript.from_dict(dict)

	assert_almost_eq(combat.attack_cooldown, 0.25, 0.001)
	assert_false(combat.is_attacking)
	assert_eq(combat.current_attack_type, CombatComponentScript.AttackType.RANGED)
	assert_eq(combat.base_damage, 15.0)
	assert_eq(combat.attack_speed, 2.5)
	assert_eq(combat.attack_range, 200.0)
	assert_eq(combat.attack_arc, 60.0)


func test_from_dict_defaults() -> void:
	var combat := CombatComponentScript.from_dict({})

	assert_eq(combat.attack_cooldown, 0.0)
	assert_false(combat.is_attacking)
	assert_eq(combat.current_attack_type, CombatComponentScript.AttackType.MELEE)
	assert_eq(combat.base_damage, 5.0)
	assert_eq(combat.attack_speed, 1.0)
	assert_eq(combat.attack_range, 50.0)
	assert_eq(combat.attack_arc, 90.0)


func test_serialization_roundtrip() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.tick(0.1)
	_combat.complete_attack()

	var dict: Dictionary = _combat.to_dict()
	var restored := CombatComponentScript.from_dict(dict)

	assert_almost_eq(restored.attack_cooldown, _combat.attack_cooldown, 0.001)
	assert_eq(restored.is_attacking, _combat.is_attacking)
	assert_eq(restored.current_attack_type, _combat.current_attack_type)
	assert_eq(restored.base_damage, _combat.base_damage)
	assert_eq(restored.attack_speed, _combat.attack_speed)
	assert_eq(restored.attack_range, _combat.attack_range)
	assert_eq(restored.attack_arc, _combat.attack_arc)


# =============================================================================
# Clone Tests
# =============================================================================

func test_clone() -> void:
	_combat.start_attack(CombatComponentScript.AttackType.RANGED)
	_combat.tick(0.2)

	var cloned := _combat.clone()

	assert_almost_eq(cloned.attack_cooldown, _combat.attack_cooldown, 0.001)
	assert_eq(cloned.is_attacking, _combat.is_attacking)
	assert_eq(cloned.current_attack_type, _combat.current_attack_type)
	assert_eq(cloned.base_damage, _combat.base_damage)
	assert_eq(cloned.attack_speed, _combat.attack_speed)
	assert_eq(cloned.attack_range, _combat.attack_range)
	assert_eq(cloned.attack_arc, _combat.attack_arc)


func test_clone_is_independent() -> void:
	var cloned := _combat.clone()

	_combat.start_attack(CombatComponentScript.AttackType.MELEE)
	_combat.base_damage = 999.0

	# Clone should be unaffected
	assert_true(cloned.can_attack())
	assert_eq(cloned.base_damage, 10.0)


# =============================================================================
# Edge Case Tests
# =============================================================================

func test_zero_attack_speed_cooldown() -> void:
	_combat.attack_speed = 0.0
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)

	# Should default to 1 second cooldown when speed is 0
	assert_eq(_combat.attack_cooldown, 1.0)


func test_negative_attack_speed_cooldown() -> void:
	_combat.attack_speed = -1.0
	_combat.start_attack(CombatComponentScript.AttackType.MELEE)

	# Should default to 1 second cooldown when speed is negative
	assert_eq(_combat.attack_cooldown, 1.0)


func test_multiple_attacks_in_sequence() -> void:
	# First attack
	assert_true(_combat.start_attack(CombatComponentScript.AttackType.MELEE))
	_combat.complete_attack()
	assert_false(_combat.can_attack())

	# Wait for cooldown
	_combat.tick(0.5)
	assert_true(_combat.can_attack())

	# Second attack
	assert_true(_combat.start_attack(CombatComponentScript.AttackType.MELEE))
	_combat.complete_attack()
	assert_false(_combat.can_attack())

	# Wait for cooldown
	_combat.tick(0.5)
	assert_true(_combat.can_attack())

	# Third attack
	assert_true(_combat.start_attack(CombatComponentScript.AttackType.RANGED))
	assert_eq(_combat.current_attack_type, CombatComponentScript.AttackType.RANGED)
