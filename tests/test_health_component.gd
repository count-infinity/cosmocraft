extends GutTest
## Unit tests for the HealthComponent class (Phase 1 Combat System).


const HealthComponentScript = preload("res://shared/components/health_component.gd")


# =============================================================================
# Test Fixtures
# =============================================================================

var _health: HealthComponentScript
var _current_time: float


func before_each() -> void:
	_health = HealthComponentScript.new(100.0)
	_current_time = Time.get_unix_time_from_system()


# =============================================================================
# Initialization Tests
# =============================================================================

func test_initial_state() -> void:
	assert_eq(_health.current_hp, 100.0)
	assert_eq(_health.max_hp, 100.0)
	assert_false(_health.is_dead)
	assert_eq(_health.last_damage_time, 0.0)
	assert_eq(_health.invulnerable_until, 0.0)


func test_custom_max_hp() -> void:
	var health := HealthComponentScript.new(150.0)
	assert_eq(health.max_hp, 150.0)
	assert_eq(health.current_hp, 150.0)


# =============================================================================
# Damage Tests
# =============================================================================

func test_take_damage() -> void:
	var actual: float = _health.take_damage(30.0, _current_time, "enemy_1")
	assert_eq(actual, 30.0)
	assert_eq(_health.current_hp, 70.0)
	assert_false(_health.is_dead)


func test_take_damage_updates_last_damage_time() -> void:
	_health.take_damage(10.0, _current_time, "")
	assert_eq(_health.last_damage_time, _current_time)


func test_take_damage_signal() -> void:
	watch_signals(_health)
	_health.take_damage(25.0, _current_time, "test_source")
	assert_signal_emitted(_health, "damaged")


func test_take_damage_zero() -> void:
	var actual: float = _health.take_damage(0.0, _current_time)
	assert_eq(actual, 0.0)
	assert_eq(_health.current_hp, 100.0)


func test_take_damage_negative() -> void:
	var actual: float = _health.take_damage(-10.0, _current_time)
	assert_eq(actual, 0.0)
	assert_eq(_health.current_hp, 100.0)


func test_take_damage_overkill() -> void:
	# Damage more than HP - should cap at current HP
	var actual: float = _health.take_damage(150.0, _current_time)
	assert_eq(actual, 100.0)
	assert_eq(_health.current_hp, 0.0)
	assert_true(_health.is_dead)


func test_take_damage_when_dead() -> void:
	_health.take_damage(100.0, _current_time)
	assert_true(_health.is_dead)

	var actual: float = _health.take_damage(50.0, _current_time)
	assert_eq(actual, 0.0)
	assert_eq(_health.current_hp, 0.0)


# =============================================================================
# Death Tests
# =============================================================================

func test_death_on_zero_hp() -> void:
	watch_signals(_health)
	_health.take_damage(100.0, _current_time, "killer_id")

	assert_true(_health.is_dead)
	assert_eq(_health.current_hp, 0.0)
	assert_signal_emitted(_health, "died")


func test_death_signal_includes_killer_id() -> void:
	watch_signals(_health)
	_health.take_damage(100.0, _current_time, "boss_1")
	assert_signal_emitted_with_parameters(_health, "died", ["boss_1"])


# =============================================================================
# Healing Tests
# =============================================================================

func test_heal() -> void:
	_health.take_damage(50.0, _current_time)
	var actual: float = _health.heal(30.0)
	assert_eq(actual, 30.0)
	assert_eq(_health.current_hp, 80.0)


func test_heal_signal() -> void:
	_health.take_damage(50.0, _current_time)
	watch_signals(_health)
	_health.heal(20.0)
	assert_signal_emitted(_health, "healed")


func test_heal_at_full_hp() -> void:
	var actual: float = _health.heal(50.0)
	assert_eq(actual, 0.0)
	assert_eq(_health.current_hp, 100.0)


func test_heal_overheal() -> void:
	# Healing more than missing HP caps at max
	_health.take_damage(30.0, _current_time)
	var actual: float = _health.heal(50.0)
	assert_eq(actual, 30.0)  # Only 30 was missing
	assert_eq(_health.current_hp, 100.0)


func test_heal_zero() -> void:
	_health.take_damage(50.0, _current_time)
	var actual: float = _health.heal(0.0)
	assert_eq(actual, 0.0)


func test_heal_negative() -> void:
	_health.take_damage(50.0, _current_time)
	var actual: float = _health.heal(-20.0)
	assert_eq(actual, 0.0)
	assert_eq(_health.current_hp, 50.0)


func test_heal_when_dead() -> void:
	_health.take_damage(100.0, _current_time)
	var actual: float = _health.heal(50.0)
	assert_eq(actual, 0.0)
	assert_true(_health.is_dead)


# =============================================================================
# Out of Combat Tests
# =============================================================================

func test_is_out_of_combat_initially() -> void:
	assert_true(_health.is_out_of_combat(_current_time))


func test_is_in_combat_after_damage() -> void:
	_health.take_damage(10.0, _current_time)
	assert_false(_health.is_out_of_combat(_current_time))


func test_returns_to_out_of_combat() -> void:
	_health.take_damage(10.0, _current_time)
	assert_false(_health.is_out_of_combat(_current_time))

	# After OUT_OF_COMBAT_DELAY seconds, should be out of combat
	var future_time: float = _current_time + HealthComponentScript.OUT_OF_COMBAT_DELAY + 0.1
	assert_true(_health.is_out_of_combat(future_time))


func test_out_of_combat_delay_constant() -> void:
	# Verify the constant is 5 seconds as specified
	assert_eq(HealthComponentScript.OUT_OF_COMBAT_DELAY, 5.0)


# =============================================================================
# Regeneration Tests
# =============================================================================

func test_tick_regen_out_of_combat() -> void:
	_health.take_damage(50.0, _current_time)

	# Move time forward past out of combat delay
	var future_time: float = _current_time + HealthComponentScript.OUT_OF_COMBAT_DELAY + 1.0
	_health.last_damage_time = _current_time  # Reset damage time

	# Regenerate at 5 HP/sec for 1 second
	_health.tick_regen(1.0, 5.0, future_time)
	assert_eq(_health.current_hp, 55.0)


func test_tick_regen_in_combat() -> void:
	_health.take_damage(50.0, _current_time)

	# Still in combat, should not regen
	_health.tick_regen(1.0, 5.0, _current_time)
	assert_eq(_health.current_hp, 50.0)


func test_tick_regen_caps_at_max() -> void:
	_health.take_damage(5.0, _current_time)

	var future_time: float = _current_time + HealthComponentScript.OUT_OF_COMBAT_DELAY + 1.0
	_health.last_damage_time = _current_time

	# Try to regen more than missing
	_health.tick_regen(10.0, 10.0, future_time)  # Would add 100 HP
	assert_eq(_health.current_hp, 100.0)  # Capped at max


func test_tick_regen_when_dead() -> void:
	_health.take_damage(100.0, _current_time)
	var future_time: float = _current_time + 10.0
	_health.tick_regen(1.0, 5.0, future_time)
	assert_eq(_health.current_hp, 0.0)  # Dead, no regen


func test_tick_regen_zero_rate() -> void:
	_health.take_damage(50.0, _current_time)
	var future_time: float = _current_time + HealthComponentScript.OUT_OF_COMBAT_DELAY + 1.0
	_health.last_damage_time = _current_time

	_health.tick_regen(1.0, 0.0, future_time)
	assert_eq(_health.current_hp, 50.0)


# =============================================================================
# Invulnerability Tests
# =============================================================================

func test_set_invulnerable() -> void:
	_health.set_invulnerable(2.0, _current_time)
	assert_eq(_health.invulnerable_until, _current_time + 2.0)


func test_is_invulnerable() -> void:
	_health.set_invulnerable(2.0, _current_time)
	assert_true(_health.is_invulnerable(_current_time))
	assert_true(_health.is_invulnerable(_current_time + 1.0))
	assert_false(_health.is_invulnerable(_current_time + 2.0))
	assert_false(_health.is_invulnerable(_current_time + 3.0))


func test_damage_blocked_when_invulnerable() -> void:
	_health.set_invulnerable(2.0, _current_time)
	var actual: float = _health.take_damage(50.0, _current_time, "enemy")
	assert_eq(actual, 0.0)
	assert_eq(_health.current_hp, 100.0)


func test_damage_after_invulnerability_expires() -> void:
	_health.set_invulnerable(2.0, _current_time)
	var future_time: float = _current_time + 3.0
	var actual: float = _health.take_damage(50.0, future_time, "enemy")
	assert_eq(actual, 50.0)
	assert_eq(_health.current_hp, 50.0)


# =============================================================================
# Revive Tests
# =============================================================================

func test_revive_from_death() -> void:
	_health.take_damage(100.0, _current_time)
	assert_true(_health.is_dead)

	watch_signals(_health)
	_health.revive()

	assert_false(_health.is_dead)
	assert_eq(_health.current_hp, 100.0)  # Full HP by default
	assert_signal_emitted(_health, "revived")


func test_revive_with_specific_hp() -> void:
	_health.take_damage(100.0, _current_time)
	_health.revive(50.0)

	assert_false(_health.is_dead)
	assert_eq(_health.current_hp, 50.0)


func test_revive_with_hp_clamped_to_max() -> void:
	_health.take_damage(100.0, _current_time)
	_health.revive(200.0)

	assert_eq(_health.current_hp, 100.0)


func test_revive_with_hp_clamped_to_min() -> void:
	_health.take_damage(100.0, _current_time)
	_health.revive(0.0)

	assert_eq(_health.current_hp, 1.0)  # Minimum 1 HP


func test_revive_when_not_dead() -> void:
	_health.take_damage(50.0, _current_time)
	_health.revive()

	# Should not change anything if not dead
	assert_eq(_health.current_hp, 50.0)


# =============================================================================
# HP Percent Tests
# =============================================================================

func test_get_hp_percent_full() -> void:
	assert_eq(_health.get_hp_percent(), 1.0)


func test_get_hp_percent_half() -> void:
	_health.take_damage(50.0, _current_time)
	assert_eq(_health.get_hp_percent(), 0.5)


func test_get_hp_percent_empty() -> void:
	_health.take_damage(100.0, _current_time)
	assert_eq(_health.get_hp_percent(), 0.0)


func test_get_hp_percent_zero_max_hp() -> void:
	_health.max_hp = 0.0
	assert_eq(_health.get_hp_percent(), 0.0)


# =============================================================================
# Set Max HP Tests
# =============================================================================

func test_set_max_hp_scales_current() -> void:
	_health.take_damage(50.0, _current_time)  # 50/100
	_health.set_max_hp(200.0, true)

	# Should maintain 50% HP ratio
	assert_eq(_health.max_hp, 200.0)
	assert_eq(_health.current_hp, 100.0)  # 50% of 200


func test_set_max_hp_no_scale() -> void:
	_health.take_damage(50.0, _current_time)  # 50/100
	_health.set_max_hp(200.0, false)

	assert_eq(_health.max_hp, 200.0)
	assert_eq(_health.current_hp, 50.0)  # Unchanged


func test_set_max_hp_clamps_current() -> void:
	_health.set_max_hp(50.0, false)  # Current HP was 100

	assert_eq(_health.max_hp, 50.0)
	assert_eq(_health.current_hp, 50.0)  # Clamped to new max


func test_set_max_hp_minimum() -> void:
	_health.set_max_hp(0.0, false)
	assert_eq(_health.max_hp, 1.0)


# =============================================================================
# Reset Tests
# =============================================================================

func test_reset() -> void:
	_health.take_damage(50.0, _current_time)
	_health.set_invulnerable(5.0, _current_time)

	_health.reset()

	assert_eq(_health.current_hp, 100.0)
	assert_false(_health.is_dead)
	assert_eq(_health.last_damage_time, 0.0)
	assert_eq(_health.invulnerable_until, 0.0)


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict() -> void:
	_health.take_damage(25.0, _current_time)
	_health.set_invulnerable(3.0, _current_time)

	var dict: Dictionary = _health.to_dict()

	assert_eq(dict["current_hp"], 75.0)
	assert_eq(dict["max_hp"], 100.0)
	assert_eq(dict["is_dead"], false)
	assert_eq(dict["last_damage_time"], _current_time)
	assert_eq(dict["invulnerable_until"], _current_time + 3.0)


func test_from_dict() -> void:
	var dict := {
		"current_hp": 60.0,
		"max_hp": 150.0,
		"is_dead": false,
		"last_damage_time": 12345.0,
		"invulnerable_until": 12350.0
	}

	var health: HealthComponentScript = HealthComponentScript.from_dict(dict)

	assert_eq(health.current_hp, 60.0)
	assert_eq(health.max_hp, 150.0)
	assert_false(health.is_dead)
	assert_eq(health.last_damage_time, 12345.0)
	assert_eq(health.invulnerable_until, 12350.0)


func test_from_dict_dead() -> void:
	var dict := {
		"current_hp": 0.0,
		"max_hp": 100.0,
		"is_dead": true,
		"last_damage_time": 0.0,
		"invulnerable_until": 0.0
	}

	var health: HealthComponentScript = HealthComponentScript.from_dict(dict)

	assert_eq(health.current_hp, 0.0)
	assert_true(health.is_dead)


func test_serialization_roundtrip() -> void:
	_health.take_damage(35.0, _current_time)
	_health.set_invulnerable(2.5, _current_time)

	var dict: Dictionary = _health.to_dict()
	var restored: HealthComponentScript = HealthComponentScript.from_dict(dict)

	assert_eq(restored.current_hp, _health.current_hp)
	assert_eq(restored.max_hp, _health.max_hp)
	assert_eq(restored.is_dead, _health.is_dead)
	assert_eq(restored.last_damage_time, _health.last_damage_time)
	assert_eq(restored.invulnerable_until, _health.invulnerable_until)


# =============================================================================
# Clone Tests
# =============================================================================

func test_clone() -> void:
	_health.take_damage(40.0, _current_time)
	_health.set_invulnerable(1.5, _current_time)

	var cloned: HealthComponentScript = _health.clone()

	assert_eq(cloned.current_hp, 60.0)
	assert_eq(cloned.max_hp, 100.0)
	assert_false(cloned.is_dead)
	assert_eq(cloned.last_damage_time, _current_time)
	assert_eq(cloned.invulnerable_until, _current_time + 1.5)


func test_clone_is_independent() -> void:
	var cloned: HealthComponentScript = _health.clone()

	_health.take_damage(50.0, _current_time)

	# Clone should be unaffected
	assert_eq(cloned.current_hp, 100.0)
	assert_eq(_health.current_hp, 50.0)
