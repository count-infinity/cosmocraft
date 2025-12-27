extends GutTest
## Unit tests for the PlayerCorpse class (Phase 1 Combat System).


const PlayerCorpseScript = preload("res://shared/entities/player_corpse.gd")


# =============================================================================
# Test Fixtures
# =============================================================================

var _corpse: PlayerCorpseScript
var _death_time: float
var _test_inventory: Dictionary


func before_each() -> void:
	_corpse = PlayerCorpseScript.new()
	_death_time = Time.get_unix_time_from_system()

	# Sample inventory data
	_test_inventory = {
		"max_weight": 100.0,
		"stacks": [
			{
				"item": {"definition_id": "iron_ore"},
				"count": 20
			},
			{
				"item": {"definition_id": "iron_sword"},
				"count": 1
			}
		]
	}


# =============================================================================
# Initialization Tests
# =============================================================================

func test_initial_state() -> void:
	assert_ne(_corpse.id, "")  # ID should be auto-generated
	assert_true(_corpse.id.begins_with("pc_"))  # Should have prefix
	assert_eq(_corpse.player_id, "")
	assert_eq(_corpse.player_name, "")
	assert_eq(_corpse.position, Vector2.ZERO)
	assert_true(_corpse.inventory_data.is_empty())
	assert_eq(_corpse.death_time, 0.0)
	assert_false(_corpse.recovered)


func test_unique_ids() -> void:
	var corpse2 := PlayerCorpseScript.new()
	assert_ne(_corpse.id, corpse2.id)


# =============================================================================
# Init From Death Tests
# =============================================================================

func test_init_from_death() -> void:
	_corpse.init_from_death(
		"player_123",
		"TestPlayer",
		Vector2(500.0, 300.0),
		_test_inventory,
		_death_time
	)

	assert_eq(_corpse.player_id, "player_123")
	assert_eq(_corpse.player_name, "TestPlayer")
	assert_eq(_corpse.position, Vector2(500.0, 300.0))
	assert_eq(_corpse.death_time, _death_time)
	assert_false(_corpse.recovered)
	assert_false(_corpse.inventory_data.is_empty())


func test_init_from_death_deep_copies_inventory() -> void:
	_corpse.init_from_death(
		"player_1",
		"Player",
		Vector2.ZERO,
		_test_inventory,
		_death_time
	)

	# Modify original
	_test_inventory["max_weight"] = 200.0

	# Corpse should have the original value
	assert_eq(_corpse.inventory_data["max_weight"], 100.0)


# =============================================================================
# Expiration Tests
# =============================================================================

func test_despawn_time_constant() -> void:
	assert_eq(PlayerCorpseScript.DESPAWN_TIME, 600.0)  # 10 minutes


func test_is_expired_false_immediately() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)
	assert_false(_corpse.is_expired(_death_time))


func test_is_expired_false_before_timeout() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var check_time := _death_time + 300.0  # 5 minutes later
	assert_false(_corpse.is_expired(check_time))


func test_is_expired_true_at_timeout() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var check_time := _death_time + PlayerCorpseScript.DESPAWN_TIME
	assert_true(_corpse.is_expired(check_time))


func test_is_expired_true_after_timeout() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var check_time := _death_time + PlayerCorpseScript.DESPAWN_TIME + 60.0
	assert_true(_corpse.is_expired(check_time))


# =============================================================================
# Time Remaining Tests
# =============================================================================

func test_get_time_remaining_initial() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var remaining := _corpse.get_time_remaining(_death_time)
	assert_eq(remaining, PlayerCorpseScript.DESPAWN_TIME)


func test_get_time_remaining_half() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var check_time := _death_time + 300.0  # 5 minutes
	var remaining := _corpse.get_time_remaining(check_time)
	assert_eq(remaining, 300.0)  # 5 minutes left


func test_get_time_remaining_expired() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var check_time := _death_time + 700.0  # Past despawn time
	var remaining := _corpse.get_time_remaining(check_time)
	assert_eq(remaining, 0.0)


func test_get_time_remaining_text_full() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var text := _corpse.get_time_remaining_text(_death_time)
	assert_eq(text, "10:00")


func test_get_time_remaining_text_partial() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var check_time := _death_time + 330.0  # 5:30 into 10 minutes
	var text := _corpse.get_time_remaining_text(check_time)
	assert_eq(text, "4:30")


func test_get_time_remaining_text_expired() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)

	var check_time := _death_time + 700.0
	var text := _corpse.get_time_remaining_text(check_time)
	assert_eq(text, "Expired")


# =============================================================================
# Empty/Recovery Tests
# =============================================================================

func test_is_empty_with_inventory() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, _test_inventory, _death_time)
	assert_false(_corpse.is_empty())


func test_is_empty_no_inventory() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, {}, _death_time)
	assert_true(_corpse.is_empty())


func test_mark_recovered() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, _test_inventory, _death_time)
	assert_false(_corpse.recovered)

	_corpse.mark_recovered()

	assert_true(_corpse.recovered)
	assert_true(_corpse.inventory_data.is_empty())


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict() -> void:
	_corpse.init_from_death(
		"player_456",
		"SerializeTest",
		Vector2(100.0, 200.0),
		_test_inventory,
		_death_time
	)

	var dict := _corpse.to_dict()

	assert_eq(dict["id"], _corpse.id)
	assert_eq(dict["player_id"], "player_456")
	assert_eq(dict["player_name"], "SerializeTest")
	assert_eq(dict["position"]["x"], 100.0)
	assert_eq(dict["position"]["y"], 200.0)
	assert_eq(dict["death_time"], _death_time)
	assert_false(dict["recovered"])
	assert_true(dict.has("inventory_data"))


func test_from_dict() -> void:
	var dict := {
		"id": "pc_test_123",
		"player_id": "player_789",
		"player_name": "FromDictPlayer",
		"position": {"x": 350.0, "y": 450.0},
		"inventory_data": _test_inventory,
		"death_time": 1000.0,
		"recovered": false
	}

	var corpse := PlayerCorpseScript.from_dict(dict)

	assert_eq(corpse.id, "pc_test_123")
	assert_eq(corpse.player_id, "player_789")
	assert_eq(corpse.player_name, "FromDictPlayer")
	assert_eq(corpse.position, Vector2(350.0, 450.0))
	assert_eq(corpse.death_time, 1000.0)
	assert_false(corpse.recovered)


func test_from_dict_recovered() -> void:
	var dict := {
		"id": "pc_recovered",
		"player_id": "p1",
		"player_name": "Player",
		"position": {"x": 0.0, "y": 0.0},
		"inventory_data": {},
		"death_time": 500.0,
		"recovered": true
	}

	var corpse := PlayerCorpseScript.from_dict(dict)
	assert_true(corpse.recovered)


func test_serialization_roundtrip() -> void:
	_corpse.init_from_death(
		"roundtrip_player",
		"RoundTripTest",
		Vector2(777.0, 888.0),
		_test_inventory,
		_death_time
	)

	var dict := _corpse.to_dict()
	var restored := PlayerCorpseScript.from_dict(dict)

	assert_eq(restored.id, _corpse.id)
	assert_eq(restored.player_id, _corpse.player_id)
	assert_eq(restored.player_name, _corpse.player_name)
	assert_eq(restored.position, _corpse.position)
	assert_eq(restored.death_time, _corpse.death_time)
	assert_eq(restored.recovered, _corpse.recovered)


# =============================================================================
# Clone Tests
# =============================================================================

func test_clone() -> void:
	_corpse.init_from_death(
		"clone_player",
		"CloneTest",
		Vector2(123.0, 456.0),
		_test_inventory,
		_death_time
	)

	var cloned := _corpse.clone()

	assert_eq(cloned.id, _corpse.id)
	assert_eq(cloned.player_id, _corpse.player_id)
	assert_eq(cloned.player_name, _corpse.player_name)
	assert_eq(cloned.position, _corpse.position)
	assert_eq(cloned.death_time, _corpse.death_time)
	assert_eq(cloned.recovered, _corpse.recovered)


func test_clone_is_independent() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, _test_inventory, _death_time)

	var cloned := _corpse.clone()

	_corpse.mark_recovered()

	# Clone should be unaffected
	assert_false(cloned.recovered)
	assert_true(_corpse.recovered)


func test_clone_deep_copies_inventory() -> void:
	_corpse.init_from_death("p1", "Player", Vector2.ZERO, _test_inventory, _death_time)

	var cloned := _corpse.clone()

	# Modify clone's inventory
	cloned.inventory_data["max_weight"] = 999.0

	# Original should be unaffected
	assert_eq(_corpse.inventory_data["max_weight"], 100.0)
