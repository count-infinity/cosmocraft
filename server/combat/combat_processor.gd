class_name CombatProcessor
extends RefCounted
## Server-side combat processor.
## Orchestrates attacks between players and enemies, using AttackResolver
## for hit detection and applying damage through the appropriate managers.
##
## This is a stateless utility class with static methods for combat calculations.
## For combat events (player_attacked, enemy_killed, etc.), the caller should
## handle event emission based on the returned result objects.
##
## Future enhancement: Convert to instance methods if dependency injection
## or signal-based event handling becomes necessary.

const AttackResolverScript = preload("res://server/combat/attack_resolver.gd")
const TargetDataScript = preload("res://shared/combat/target_data.gd")
const EnemyStateScript = preload("res://shared/entities/enemy_state.gd")
const AttackTypesScript = preload("res://shared/combat/attack_types.gd")


## Default hitbox radius when definition doesn't specify one
const DEFAULT_HITBOX_RADIUS: float = 16.0

## Time tolerance for detecting if an enemy attack just occurred (in seconds)
## This accounts for timing jitter between AI and combat processing
const ATTACK_TIME_TOLERANCE: float = 0.1


## Result of processing a player attack
class PlayerAttackResult:
	var attacker_id: String = ""
	var hits: Array = []  # Array of HitResult from AttackResolver
	var damage_dealt: Array = []  # Array of float (damage per hit)
	var enemies_killed: Array = []  # Array of String (enemy_ids killed)


## Result of processing an enemy attack
class EnemyAttackResult:
	var enemy_id: String = ""
	var target_id: String = ""
	var damage: float = 0.0
	var target_killed: bool = false


## Process a player attacking enemies.
## Returns PlayerAttackResult with hit information.
##
## Parameters:
## - attacker_id: ID of the attacking player
## - attacker_pos: Position of the attacker
## - aim_direction: Aim direction (will be normalized if not already)
## - attack_type: Attack type string ("melee_arc", "melee_thrust", "ranged")
## - attack_range: Range of the attack in pixels
## - attack_arc: Arc width in degrees (used for melee_arc, ignored for others)
## - base_damage: Base damage of the attack
## - enemy_manager: EnemyManager instance with live enemies
static func process_player_attack(
	attacker_id: String,
	attacker_pos: Vector2,
	aim_direction: Vector2,
	attack_type: String,
	attack_range: float,
	attack_arc: float,
	base_damage: float,
	enemy_manager: RefCounted
) -> PlayerAttackResult:
	var result := PlayerAttackResult.new()
	result.attacker_id = attacker_id

	# Validate and convert attack type
	var type_int: int = AttackTypesScript.from_string(attack_type)
	if not AttackTypesScript.is_valid(type_int):
		push_warning("CombatProcessor: Unknown attack type: " + attack_type)
		return result

	# Normalize aim direction defensively
	var normalized_aim: Vector2 = aim_direction
	if not aim_direction.is_normalized():
		normalized_aim = aim_direction.normalized()
		if normalized_aim == Vector2.ZERO:
			normalized_aim = Vector2.RIGHT  # Fallback

	# Build target list from alive enemies
	var targets: Array = _build_enemy_target_list(enemy_manager)

	# Find hits based on attack type
	var hits: Array = _find_attack_hits(
		type_int, attacker_pos, normalized_aim, attack_range, attack_arc, targets
	)

	result.hits = hits

	# Apply damage to each hit target
	for hit in hits:
		var enemy_id: String = hit.target_id
		var actual_damage: float = enemy_manager.damage_enemy(enemy_id, base_damage, attacker_id)

		if actual_damage >= 0:
			result.damage_dealt.append(actual_damage)

			# Check if enemy was killed
			var enemy: RefCounted = enemy_manager.get_enemy(enemy_id)
			if enemy != null and not enemy.is_alive:
				result.enemies_killed.append(enemy_id)
		else:
			result.damage_dealt.append(0.0)

	return result


## Process all enemy attacks for a tick.
## Call this after AI processing has set attack flags via record_attack().
##
## Parameters:
## - enemy_manager: EnemyManager with enemies
## - player_positions: Dictionary of player_id -> Vector2
## - player_healths: Dictionary of player_id -> HealthComponent
## - current_time: Current game time for attack detection and invulnerability
##
## Returns: Array of EnemyAttackResult
static func process_enemy_attacks(
	enemy_manager: RefCounted,
	player_positions: Dictionary,
	player_healths: Dictionary,
	current_time: float
) -> Array:
	var results: Array = []

	for enemy in enemy_manager.get_alive_enemies():
		# Only process enemies in ATTACKING state
		if enemy.state != EnemyStateScript.State.ATTACKING:
			continue

		# Check if enemy has a valid target
		if enemy.target_id.is_empty():
			continue

		# Check if target exists
		if not player_positions.has(enemy.target_id):
			continue

		# Get enemy definition for damage
		var definition: Resource = enemy_manager.get_registry().get_definition(enemy.definition_id)
		if definition == null:
			continue

		# Check if enemy just attacked (last_attack_time was just set by AI)
		# Uses tolerance to account for timing jitter
		if absf(enemy.last_attack_time - current_time) > ATTACK_TIME_TOLERANCE:
			continue  # Attack didn't just happen

		# Calculate damage and apply to player
		var attack_result := _process_single_attack(
			enemy, definition, player_healths, current_time
		)
		if attack_result != null:
			results.append(attack_result)

	return results


## Process a single enemy attack on a player.
## Use this for direct attack processing outside the batch system.
##
## Parameters:
## - enemy: The attacking enemy state
## - enemy_definition: The enemy's definition resource
## - target_id: ID of the target player
## - player_health: The target's HealthComponent
## - current_time: Current game time for invulnerability checks
##
## Returns: EnemyAttackResult with attack details
static func process_single_enemy_attack(
	enemy: RefCounted,
	enemy_definition: Resource,
	target_id: String,
	player_health: RefCounted,
	current_time: float
) -> EnemyAttackResult:
	var result := EnemyAttackResult.new()
	result.enemy_id = enemy.id
	result.target_id = target_id

	var base_damage: float = enemy_definition.damage
	result.damage = base_damage

	player_health.take_damage(base_damage, current_time, enemy.id)
	result.target_killed = player_health.is_dead

	return result


## Build target list from enemies for a player attack.
## Filters to only alive enemies.
static func build_enemy_targets(enemy_manager: RefCounted) -> Array:
	return _build_enemy_target_list(enemy_manager)


## Build target list from players for an enemy attack.
static func build_player_targets(player_positions: Dictionary) -> Array:
	var targets: Array = []

	for player_id in player_positions:
		var pos: Vector2 = player_positions[player_id]
		targets.append(TargetDataScript.from_player(player_id, pos))

	return targets


# =============================================================================
# Private Helper Methods
# =============================================================================

## Get hitbox radius for an enemy with fallback to default
static func _get_hitbox_radius(definition: Resource) -> float:
	if definition != null and "hitbox_radius" in definition:
		return definition.hitbox_radius
	return DEFAULT_HITBOX_RADIUS


## Build target list from alive enemies
static func _build_enemy_target_list(enemy_manager: RefCounted) -> Array:
	var targets: Array = []

	for enemy in enemy_manager.get_alive_enemies():
		var definition: Resource = enemy_manager.get_registry().get_definition(enemy.definition_id)
		var hitbox_radius: float = _get_hitbox_radius(definition)
		targets.append(TargetDataScript.from_enemy(enemy.id, enemy.position, hitbox_radius))

	return targets


## Find attack hits based on attack type
static func _find_attack_hits(
	attack_type: int,
	attacker_pos: Vector2,
	aim_direction: Vector2,
	attack_range: float,
	attack_arc: float,
	targets: Array
) -> Array:
	match attack_type:
		AttackTypesScript.Type.MELEE_ARC:
			return AttackResolverScript.find_melee_targets(
				attacker_pos, aim_direction, attack_range, attack_arc, targets
			)
		AttackTypesScript.Type.MELEE_THRUST:
			# Thrust uses 0.0 arc for narrow line detection
			return AttackResolverScript.find_melee_targets(
				attacker_pos, aim_direction, attack_range, 0.0, targets
			)
		AttackTypesScript.Type.RANGED:
			return AttackResolverScript.find_ranged_targets(
				attacker_pos, aim_direction, attack_range, targets
			)
		_:
			return []


## Process a single attack from batch processing
static func _process_single_attack(
	enemy: RefCounted,
	definition: Resource,
	player_healths: Dictionary,
	current_time: float
) -> EnemyAttackResult:
	var target_id: String = enemy.target_id

	# Check if we have health component for target
	if not player_healths.has(target_id):
		return null

	var result := EnemyAttackResult.new()
	result.enemy_id = enemy.id
	result.target_id = target_id
	result.damage = definition.damage

	var health: RefCounted = player_healths[target_id]
	health.take_damage(definition.damage, current_time, enemy.id)
	result.target_killed = health.is_dead

	return result
