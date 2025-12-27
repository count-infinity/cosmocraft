class_name AttackResolver
extends RefCounted
## Resolves attack hitboxes and finds valid targets.
## Handles both melee (arc/thrust) and ranged (hitscan) attacks.
## Uses duck-typing for target objects to ensure headless mode compatibility.


## Result of a hit check
class HitResult:
	var target_id: String
	var target_position: Vector2
	var distance: float
	var angle_to_target: float

	func _init(id: String, pos: Vector2, dist: float, angle: float) -> void:
		target_id = id
		target_position = pos
		distance = dist
		angle_to_target = angle


## Default hitbox radius for entities
const DEFAULT_HITBOX_RADIUS: float = 20.0


## Find all targets hit by a melee attack (arc or thrust)
## attacker_pos: Position of the attacker
## aim_direction: Normalized direction the attacker is aiming
## attack_range: Maximum distance of the attack in pixels
## attack_arc: Arc width in degrees (0 = line/thrust, 90+ = swing arc)
## targets: Array of target objects with id, position, hitbox_radius properties
## Returns: Array of HitResult for each target hit
static func find_melee_targets(
	attacker_pos: Vector2,
	aim_direction: Vector2,
	attack_range: float,
	attack_arc: float,
	targets: Array
) -> Array:
	var hits: Array = []
	var aim_angle: float = aim_direction.angle()
	var half_arc: float = deg_to_rad(attack_arc / 2.0)

	for target in targets:
		# Use duck-typing to check for required properties
		if not _is_target_like(target):
			continue

		var target_id: String = str(target.id)
		var target_pos: Vector2 = target.position
		var target_radius: float = float(target.hitbox_radius)

		var to_target: Vector2 = target_pos - attacker_pos
		var distance: float = to_target.length()

		# Check if within range (accounting for hitbox radius)
		if distance > attack_range + target_radius:
			continue

		# For arc attacks, check if within arc angle
		if attack_arc > 0:
			var angle_to_target: float = to_target.angle()
			var angle_diff: float = absf(angle_difference(aim_angle, angle_to_target))

			if angle_diff > half_arc:
				continue

		# For thrust attacks (arc = 0), check perpendicular distance
		elif attack_arc <= 0:
			# Project target onto aim direction
			var projected: Vector2 = to_target.project(aim_direction)

			# Check if target is in front of attacker
			if projected.dot(aim_direction) < 0:
				continue

			# Check perpendicular distance (how far off the line)
			var perp_dist: float = (to_target - projected).length()
			if perp_dist > target_radius:
				continue

		# Target is hit
		var angle_to: float = to_target.angle()
		hits.append(HitResult.new(target_id, target_pos, distance, angle_to))

	return hits


## Find targets hit by a ranged hitscan attack
## attacker_pos: Position of the attacker
## aim_direction: Normalized direction the attacker is aiming
## max_range: Maximum range of the attack in pixels
## targets: Array of target objects with id, position, hitbox_radius properties
## Returns: Array with single HitResult (first target hit) or empty array
static func find_ranged_targets(
	attacker_pos: Vector2,
	aim_direction: Vector2,
	max_range: float,
	targets: Array
) -> Array:
	var closest_dist: float = max_range + 1.0
	var closest_target: Variant = null

	for target in targets:
		# Use duck-typing to check for required properties
		if not _is_target_like(target):
			continue

		var target_pos: Vector2 = target.position
		var target_radius: float = float(target.hitbox_radius)

		var to_target: Vector2 = target_pos - attacker_pos

		# Project onto aim direction
		var projected: Vector2 = to_target.project(aim_direction)

		# Check if target is in front of attacker
		if projected.dot(aim_direction) < 0:
			continue

		var distance: float = projected.length()

		# Check if within range
		if distance > max_range:
			continue

		# Check perpendicular distance (raycast width is based on hitbox)
		var perp_dist: float = (to_target - projected).length()
		if perp_dist > target_radius:
			continue

		# Track closest target
		if distance < closest_dist:
			closest_dist = distance
			closest_target = target

	# Return first hit (hitscan only hits one target)
	if closest_target != null:
		var target_pos: Vector2 = closest_target.position
		var to_target: Vector2 = target_pos - attacker_pos
		return [HitResult.new(
			str(closest_target.id),
			target_pos,
			closest_dist,
			to_target.angle()
		)]

	return []


## Calculate the difference between two angles, normalized to [-PI, PI]
static func angle_difference(angle1: float, angle2: float) -> float:
	var diff: float = angle2 - angle1
	# Normalize to [-PI, PI] range
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff


## Check if a point is within a cone
static func is_point_in_cone(
	cone_origin: Vector2,
	cone_direction: Vector2,
	cone_angle: float,
	point: Vector2
) -> bool:
	var to_point: Vector2 = point - cone_origin
	var aim_angle: float = cone_direction.angle()
	var point_angle: float = to_point.angle()
	var half_arc: float = deg_to_rad(cone_angle / 2.0)

	var angle_diff: float = absf(angle_difference(aim_angle, point_angle))
	return angle_diff <= half_arc


## Check if a point is within range of another point
static func is_point_in_range(
	origin: Vector2,
	point: Vector2,
	max_range: float
) -> bool:
	return origin.distance_to(point) <= max_range


## Create TargetData from a dictionary with position
## Returns RefCounted for headless mode compatibility
static func create_target_from_dict(
	id: String,
	data: Dictionary,
	radius: float = DEFAULT_HITBOX_RADIUS
) -> RefCounted:
	var pos: Vector2 = Vector2.ZERO
	if data.has("position"):
		var pos_data: Dictionary = data["position"]
		pos = Vector2(float(pos_data.get("x", 0.0)), float(pos_data.get("y", 0.0)))
	elif data.has("x") and data.has("y"):
		pos = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))

	var TargetDataScript: GDScript = load("res://shared/combat/target_data.gd")
	return TargetDataScript.new(id, pos, radius, TargetDataScript.Faction.NEUTRAL)


## Create TargetData from a PlayerState-like object
## Returns RefCounted for headless mode compatibility
static func create_target_from_player(player_id: String, position: Vector2) -> RefCounted:
	var TargetDataScript: GDScript = load("res://shared/combat/target_data.gd")
	return TargetDataScript.new(player_id, position, 16.0, TargetDataScript.Faction.PLAYER)


## Create TargetData from an enemy
## Returns RefCounted for headless mode compatibility
static func create_target_from_enemy(enemy_id: String, position: Vector2, hitbox_radius: float) -> RefCounted:
	var TargetDataScript: GDScript = load("res://shared/combat/target_data.gd")
	return TargetDataScript.new(enemy_id, position, hitbox_radius, TargetDataScript.Faction.ENEMY)


## Check if an object has the required properties to be used as a target
## This allows duck-typing for backwards compatibility
static func _is_target_like(obj: Variant) -> bool:
	if obj == null:
		return false
	# Check for required properties using has_method check for 'get' or direct property access
	if obj is Object:
		return "id" in obj and "position" in obj and "hitbox_radius" in obj
	elif obj is Dictionary:
		return obj.has("id") and obj.has("position") and obj.has("hitbox_radius")
	return false


## Convert a target-like object to a proper TargetData
static func _to_target_data(obj: Variant) -> RefCounted:
	var TargetDataScript: GDScript = load("res://shared/combat/target_data.gd")
	var faction_neutral: int = TargetDataScript.Faction.NEUTRAL

	var obj_faction: int = faction_neutral
	if obj is Object and "faction" in obj:
		obj_faction = int(obj.faction)
	elif obj is Dictionary and obj.has("faction"):
		obj_faction = int(obj.get("faction", faction_neutral))

	return TargetDataScript.new(
		str(obj.id) if obj is Object else str(obj.get("id", "")),
		obj.position if obj is Object else obj.get("position", Vector2.ZERO),
		float(obj.hitbox_radius) if obj is Object else float(obj.get("hitbox_radius", DEFAULT_HITBOX_RADIUS)),
		obj_faction
	)
