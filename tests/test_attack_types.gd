extends GutTest
## Unit tests for the AttackTypes class.

const AttackTypesScript = preload("res://shared/combat/attack_types.gd")


# =============================================================================
# from_string Tests
# =============================================================================

func test_from_string_melee_arc() -> void:
	assert_eq(AttackTypesScript.from_string("melee_arc"), AttackTypesScript.Type.MELEE_ARC)


func test_from_string_melee_thrust() -> void:
	assert_eq(AttackTypesScript.from_string("melee_thrust"), AttackTypesScript.Type.MELEE_THRUST)


func test_from_string_ranged() -> void:
	assert_eq(AttackTypesScript.from_string("ranged"), AttackTypesScript.Type.RANGED)


func test_from_string_case_insensitive() -> void:
	assert_eq(AttackTypesScript.from_string("MELEE_ARC"), AttackTypesScript.Type.MELEE_ARC)
	assert_eq(AttackTypesScript.from_string("Ranged"), AttackTypesScript.Type.RANGED)


func test_from_string_invalid() -> void:
	assert_eq(AttackTypesScript.from_string("unknown"), -1)
	assert_eq(AttackTypesScript.from_string(""), -1)
	assert_eq(AttackTypesScript.from_string("magic_beam"), -1)


# =============================================================================
# to_string_name Tests
# =============================================================================

func test_to_string_name_melee_arc() -> void:
	assert_eq(AttackTypesScript.to_string_name(AttackTypesScript.Type.MELEE_ARC), "melee_arc")


func test_to_string_name_melee_thrust() -> void:
	assert_eq(AttackTypesScript.to_string_name(AttackTypesScript.Type.MELEE_THRUST), "melee_thrust")


func test_to_string_name_ranged() -> void:
	assert_eq(AttackTypesScript.to_string_name(AttackTypesScript.Type.RANGED), "ranged")


func test_to_string_name_invalid() -> void:
	assert_eq(AttackTypesScript.to_string_name(-1), "unknown")
	assert_eq(AttackTypesScript.to_string_name(99), "unknown")


# =============================================================================
# is_valid Tests
# =============================================================================

func test_is_valid_melee_arc() -> void:
	assert_true(AttackTypesScript.is_valid(AttackTypesScript.Type.MELEE_ARC))


func test_is_valid_melee_thrust() -> void:
	assert_true(AttackTypesScript.is_valid(AttackTypesScript.Type.MELEE_THRUST))


func test_is_valid_ranged() -> void:
	assert_true(AttackTypesScript.is_valid(AttackTypesScript.Type.RANGED))


func test_is_valid_invalid() -> void:
	assert_false(AttackTypesScript.is_valid(-1))
	assert_false(AttackTypesScript.is_valid(99))


# =============================================================================
# is_melee Tests
# =============================================================================

func test_is_melee_arc() -> void:
	assert_true(AttackTypesScript.is_melee(AttackTypesScript.Type.MELEE_ARC))


func test_is_melee_thrust() -> void:
	assert_true(AttackTypesScript.is_melee(AttackTypesScript.Type.MELEE_THRUST))


func test_is_melee_ranged() -> void:
	assert_false(AttackTypesScript.is_melee(AttackTypesScript.Type.RANGED))


# =============================================================================
# is_ranged Tests
# =============================================================================

func test_is_ranged_arc() -> void:
	assert_false(AttackTypesScript.is_ranged(AttackTypesScript.Type.MELEE_ARC))


func test_is_ranged_ranged() -> void:
	assert_true(AttackTypesScript.is_ranged(AttackTypesScript.Type.RANGED))


# =============================================================================
# Round Trip Tests
# =============================================================================

func test_round_trip_melee_arc() -> void:
	var original := AttackTypesScript.Type.MELEE_ARC
	var as_string := AttackTypesScript.to_string_name(original)
	var back_to_int := AttackTypesScript.from_string(as_string)
	assert_eq(back_to_int, original)


func test_round_trip_melee_thrust() -> void:
	var original := AttackTypesScript.Type.MELEE_THRUST
	var as_string := AttackTypesScript.to_string_name(original)
	var back_to_int := AttackTypesScript.from_string(as_string)
	assert_eq(back_to_int, original)


func test_round_trip_ranged() -> void:
	var original := AttackTypesScript.Type.RANGED
	var as_string := AttackTypesScript.to_string_name(original)
	var back_to_int := AttackTypesScript.from_string(as_string)
	assert_eq(back_to_int, original)
