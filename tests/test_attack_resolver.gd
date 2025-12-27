extends GutTest
## Unit tests for the AttackResolver class (Phase 2 Combat System).


const AttackResolverScript = preload("res://server/combat/attack_resolver.gd")
const TargetDataScript = preload("res://shared/combat/target_data.gd")


# =============================================================================
# Helper Methods
# =============================================================================

func create_target(id: String, pos: Vector2, radius: float = 20.0):
	return TargetDataScript.new(id, pos, radius)


# =============================================================================
# TargetData Tests (now using shared TargetData class)
# =============================================================================

func test_target_data_creation() -> void:
	var target = create_target("enemy_1", Vector2(100, 50), 25.0)

	assert_eq(target.id, "enemy_1")
	assert_eq(target.position, Vector2(100, 50))
	assert_eq(target.hitbox_radius, 25.0)


func test_target_data_default_radius() -> void:
	var target = TargetDataScript.new("test", Vector2.ZERO)

	assert_eq(target.hitbox_radius, 16.0)  # Changed: shared TargetData uses 16.0 default


# =============================================================================
# HitResult Tests
# =============================================================================

func test_hit_result_creation() -> void:
	var hit = AttackResolverScript.HitResult.new("target_1", Vector2(50, 50), 70.7, 0.785)

	assert_eq(hit.target_id, "target_1")
	assert_eq(hit.target_position, Vector2(50, 50))
	assert_almost_eq(hit.distance, 70.7, 0.1)
	assert_almost_eq(hit.angle_to_target, 0.785, 0.001)


# =============================================================================
# Melee Arc Attack Tests
# =============================================================================

func test_melee_arc_hit_in_front() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [create_target("enemy", Vector2(50, 0))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,  # range
		90.0,   # arc (45 degrees each side)
		targets
	)

	assert_eq(hits.size(), 1)
	assert_eq(hits[0].target_id, "enemy")


func test_melee_arc_miss_behind() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [create_target("enemy", Vector2(-50, 0))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		90.0,
		targets
	)

	assert_eq(hits.size(), 0)


func test_melee_arc_miss_too_far() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [create_target("enemy", Vector2(200, 0))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		90.0,
		targets
	)

	assert_eq(hits.size(), 0)


func test_melee_arc_hit_edge_of_arc() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target at 44 degrees (within 45 degree half-arc)
	var targets := [create_target("enemy", Vector2(50, 40))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		90.0,
		targets
	)

	assert_eq(hits.size(), 1)


func test_melee_arc_miss_outside_arc() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target at 60 degrees (outside 45 degree half-arc)
	var targets := [create_target("enemy", Vector2(50, 87))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		90.0,
		targets
	)

	assert_eq(hits.size(), 0)


func test_melee_arc_multiple_hits() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [
		create_target("enemy_1", Vector2(50, 0)),
		create_target("enemy_2", Vector2(50, 20)),
		create_target("enemy_3", Vector2(50, -20))
	]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		90.0,
		targets
	)

	assert_eq(hits.size(), 3)


func test_melee_arc_wide_swing() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target at 80 degrees
	var targets := [create_target("enemy", Vector2(20, 100))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		150.0,
		180.0,  # 90 degree half-arc
		targets
	)

	assert_eq(hits.size(), 1)


func test_melee_arc_includes_hitbox_radius() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target center is at 110, but hitbox radius is 20
	# So effective distance is 110 - 20 = 90, within 100 range
	var targets := [create_target("enemy", Vector2(110, 0), 20.0)]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		90.0,
		targets
	)

	assert_eq(hits.size(), 1)


# =============================================================================
# Melee Thrust Attack Tests (arc = 0)
# =============================================================================

func test_melee_thrust_hit_direct() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [create_target("enemy", Vector2(50, 0))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		0.0,  # Thrust (no arc)
		targets
	)

	assert_eq(hits.size(), 1)


func test_melee_thrust_hit_within_hitbox() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target slightly off the line but within hitbox radius
	var targets := [create_target("enemy", Vector2(50, 15), 20.0)]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		0.0,
		targets
	)

	assert_eq(hits.size(), 1)


func test_melee_thrust_miss_too_far_off_line() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target too far off the line
	var targets := [create_target("enemy", Vector2(50, 30), 20.0)]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		0.0,
		targets
	)

	assert_eq(hits.size(), 0)


func test_melee_thrust_miss_behind() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target behind attacker
	var targets := [create_target("enemy", Vector2(-50, 0))]

	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		0.0,
		targets
	)

	assert_eq(hits.size(), 0)


# =============================================================================
# Ranged Hitscan Attack Tests
# =============================================================================

func test_ranged_hit_direct() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [create_target("enemy", Vector2(100, 0))]

	var hits = AttackResolverScript.find_ranged_targets(
		attacker_pos,
		aim_dir,
		200.0,
		targets
	)

	assert_eq(hits.size(), 1)
	assert_eq(hits[0].target_id, "enemy")


func test_ranged_hit_within_hitbox() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Slightly off the line but within hitbox
	var targets := [create_target("enemy", Vector2(100, 15), 20.0)]

	var hits = AttackResolverScript.find_ranged_targets(
		attacker_pos,
		aim_dir,
		200.0,
		targets
	)

	assert_eq(hits.size(), 1)


func test_ranged_miss_too_far_off() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Too far off the raycast line
	var targets := [create_target("enemy", Vector2(100, 30), 20.0)]

	var hits = AttackResolverScript.find_ranged_targets(
		attacker_pos,
		aim_dir,
		200.0,
		targets
	)

	assert_eq(hits.size(), 0)


func test_ranged_miss_behind() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [create_target("enemy", Vector2(-100, 0))]

	var hits = AttackResolverScript.find_ranged_targets(
		attacker_pos,
		aim_dir,
		200.0,
		targets
	)

	assert_eq(hits.size(), 0)


func test_ranged_miss_out_of_range() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [create_target("enemy", Vector2(300, 0))]

	var hits = AttackResolverScript.find_ranged_targets(
		attacker_pos,
		aim_dir,
		200.0,
		targets
	)

	assert_eq(hits.size(), 0)


func test_ranged_hits_closest_only() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [
		create_target("far_enemy", Vector2(150, 0)),
		create_target("close_enemy", Vector2(50, 0)),
		create_target("mid_enemy", Vector2(100, 0))
	]

	var hits = AttackResolverScript.find_ranged_targets(
		attacker_pos,
		aim_dir,
		200.0,
		targets
	)

	assert_eq(hits.size(), 1)
	assert_eq(hits[0].target_id, "close_enemy")


func test_ranged_diagonal_aim() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2(1, 1).normalized()
	# Target along diagonal
	var targets := [create_target("enemy", Vector2(70, 70))]

	var hits = AttackResolverScript.find_ranged_targets(
		attacker_pos,
		aim_dir,
		200.0,
		targets
	)

	assert_eq(hits.size(), 1)


# =============================================================================
# Angle Difference Tests
# =============================================================================

func test_angle_difference_zero() -> void:
	var diff = AttackResolverScript.angle_difference(0.0, 0.0)
	assert_almost_eq(diff, 0.0, 0.001)


func test_angle_difference_small() -> void:
	var diff = AttackResolverScript.angle_difference(0.0, 0.5)
	assert_almost_eq(diff, 0.5, 0.001)


func test_angle_difference_wrap_positive() -> void:
	var diff = AttackResolverScript.angle_difference(3.0, -3.0)
	# Should wrap around to smallest difference
	assert_lt(absf(diff), PI)


func test_angle_difference_wrap_negative() -> void:
	var diff = AttackResolverScript.angle_difference(-3.0, 3.0)
	assert_lt(absf(diff), PI)


# =============================================================================
# Point in Cone Tests
# =============================================================================

func test_is_point_in_cone_center() -> void:
	var result = AttackResolverScript.is_point_in_cone(
		Vector2.ZERO,
		Vector2.RIGHT,
		90.0,
		Vector2(50, 0)
	)
	assert_true(result)


func test_is_point_in_cone_edge() -> void:
	var result = AttackResolverScript.is_point_in_cone(
		Vector2.ZERO,
		Vector2.RIGHT,
		90.0,
		Vector2(50, 40)
	)
	assert_true(result)


func test_is_point_in_cone_outside() -> void:
	var result = AttackResolverScript.is_point_in_cone(
		Vector2.ZERO,
		Vector2.RIGHT,
		90.0,
		Vector2(50, 100)
	)
	assert_false(result)


# =============================================================================
# Point in Range Tests
# =============================================================================

func test_is_point_in_range_inside() -> void:
	var result = AttackResolverScript.is_point_in_range(
		Vector2.ZERO,
		Vector2(50, 0),
		100.0
	)
	assert_true(result)


func test_is_point_in_range_exact() -> void:
	var result = AttackResolverScript.is_point_in_range(
		Vector2.ZERO,
		Vector2(100, 0),
		100.0
	)
	assert_true(result)


func test_is_point_in_range_outside() -> void:
	var result = AttackResolverScript.is_point_in_range(
		Vector2.ZERO,
		Vector2(101, 0),
		100.0
	)
	assert_false(result)


# =============================================================================
# Target Creation Helper Tests
# =============================================================================

func test_create_target_from_dict_with_position() -> void:
	var data := {
		"position": {"x": 100.0, "y": 50.0}
	}
	var target = AttackResolverScript.create_target_from_dict("test", data, 15.0)

	assert_eq(target.id, "test")
	assert_eq(target.position, Vector2(100, 50))
	assert_eq(target.hitbox_radius, 15.0)


func test_create_target_from_dict_with_xy() -> void:
	var data := {
		"x": 75.0,
		"y": 25.0
	}
	var target = AttackResolverScript.create_target_from_dict("test", data)

	assert_eq(target.position, Vector2(75, 25))


func test_create_target_from_dict_empty() -> void:
	var target = AttackResolverScript.create_target_from_dict("test", {})

	assert_eq(target.position, Vector2.ZERO)


func test_create_target_from_player() -> void:
	var target = AttackResolverScript.create_target_from_player("player_1", Vector2(200, 100))

	assert_eq(target.id, "player_1")
	assert_eq(target.position, Vector2(200, 100))
	assert_eq(target.hitbox_radius, 16.0)  # Half player size


# =============================================================================
# Edge Case Tests
# =============================================================================

func test_empty_targets_melee() -> void:
	var hits = AttackResolverScript.find_melee_targets(
		Vector2.ZERO,
		Vector2.RIGHT,
		100.0,
		90.0,
		[]
	)
	assert_eq(hits.size(), 0)


func test_empty_targets_ranged() -> void:
	var hits = AttackResolverScript.find_ranged_targets(
		Vector2.ZERO,
		Vector2.RIGHT,
		100.0,
		[]
	)
	assert_eq(hits.size(), 0)


func test_invalid_target_type_melee() -> void:
	var targets := ["not a target", 12345, null]

	var hits = AttackResolverScript.find_melee_targets(
		Vector2.ZERO,
		Vector2.RIGHT,
		100.0,
		90.0,
		targets
	)
	assert_eq(hits.size(), 0)


func test_invalid_target_type_ranged() -> void:
	var targets := ["not a target", 12345, null]

	var hits = AttackResolverScript.find_ranged_targets(
		Vector2.ZERO,
		Vector2.RIGHT,
		100.0,
		targets
	)
	assert_eq(hits.size(), 0)


func test_target_at_attacker_position() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	# Target at same position as attacker
	var targets := [create_target("enemy", Vector2(0, 0))]

	# Should still hit (distance is 0, which is within range)
	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		90.0,
		targets
	)
	assert_eq(hits.size(), 1)


func test_zero_range_melee() -> void:
	var hits = AttackResolverScript.find_melee_targets(
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,  # Zero range
		90.0,
		[create_target("enemy", Vector2(50, 0))]
	)

	# Only hits targets within hitbox radius of attacker
	assert_eq(hits.size(), 0)


func test_full_circle_arc() -> void:
	var attacker_pos := Vector2(0, 0)
	var aim_dir := Vector2.RIGHT
	var targets := [
		create_target("front", Vector2(50, 0)),
		create_target("back", Vector2(-50, 0)),
		create_target("left", Vector2(0, -50)),
		create_target("right", Vector2(0, 50))
	]

	# 360 degree arc should hit all directions
	var hits = AttackResolverScript.find_melee_targets(
		attacker_pos,
		aim_dir,
		100.0,
		360.0,
		targets
	)

	assert_eq(hits.size(), 4)
