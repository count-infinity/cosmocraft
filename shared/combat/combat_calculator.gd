class_name CombatCalculator
extends RefCounted
## Static utility class for combat damage calculations.
## All calculations use PlayerStats for attribute bonuses.
## Server-authoritative: all combat calculations happen server-side.

const PlayerStatsClass = preload("res://shared/items/player_stats.gd")
const ItemDefinitionClass = preload("res://shared/items/item_definition.gd")
const ItemEnumsClass = preload("res://shared/items/item_enums.gd")


## Result of a damage calculation
class DamageResult:
	var base_damage: float = 0.0
	var stat_multiplier: float = 1.0
	var is_critical: bool = false
	var crit_multiplier: float = 1.0
	var damage_before_reduction: float = 0.0
	var damage_reduction: float = 0.0
	var final_damage: float = 0.0

	func _to_string() -> String:
		return "DamageResult(base=%.1f, crit=%s, final=%.1f)" % [
			base_damage, str(is_critical), final_damage
		]


## Calculate melee damage from an attacker to a target.
## Uses STRENGTH stat for damage bonus.
## @param attacker_stats: The attacker's PlayerStats
## @param weapon: The weapon ItemDefinition (can be null for unarmed)
## @param target_stats: The target's PlayerStats (for damage reduction)
## @param rng_seed: Optional seed for deterministic crit rolls (for testing)
## @returns: DamageResult with full breakdown
static func calculate_melee_damage(
	attacker_stats: PlayerStats,
	weapon: ItemDefinition,
	target_stats: PlayerStats,
	rng_seed: int = -1
) -> DamageResult:
	var result := DamageResult.new()

	# Get base damage from weapon or use unarmed default
	if weapon != null:
		result.base_damage = float(weapon.base_damage)
	else:
		result.base_damage = 5.0  # Unarmed base damage

	# Calculate stat multiplier from STRENGTH
	# Each point of strength above 10 adds 2% damage
	var strength := attacker_stats.get_stat(ItemEnums.StatType.STRENGTH)
	result.stat_multiplier = 1.0 + (strength - 10.0) * 0.02
	result.stat_multiplier = maxf(0.1, result.stat_multiplier)  # Minimum 10% damage

	# Check for critical hit
	var crit_result := calculate_crit(attacker_stats, rng_seed)
	result.is_critical = crit_result["is_crit"]
	result.crit_multiplier = crit_result["multiplier"]

	# Calculate damage before target reduction
	result.damage_before_reduction = result.base_damage * result.stat_multiplier
	if result.is_critical:
		result.damage_before_reduction *= result.crit_multiplier

	# Apply target's damage reduction from FORTITUDE
	result.damage_reduction = calculate_damage_reduction(target_stats, result.damage_before_reduction)
	result.final_damage = maxf(1.0, result.damage_before_reduction - result.damage_reduction)

	return result


## Calculate ranged damage from an attacker to a target.
## Uses PRECISION stat for damage bonus.
## @param attacker_stats: The attacker's PlayerStats
## @param weapon: The weapon ItemDefinition
## @param target_stats: The target's PlayerStats (for damage reduction)
## @param distance: Distance to target (for potential falloff, not yet implemented)
## @param rng_seed: Optional seed for deterministic crit rolls (for testing)
## @returns: DamageResult with full breakdown
static func calculate_ranged_damage(
	attacker_stats: PlayerStats,
	weapon: ItemDefinition,
	target_stats: PlayerStats,
	distance: float = 0.0,
	rng_seed: int = -1
) -> DamageResult:
	var result := DamageResult.new()

	# Get base damage from weapon
	if weapon != null:
		result.base_damage = float(weapon.base_damage)
	else:
		result.base_damage = 1.0  # No ranged unarmed

	# Calculate stat multiplier from PRECISION
	# Each point of precision above 10 adds 2% damage
	var precision := attacker_stats.get_stat(ItemEnums.StatType.PRECISION)
	result.stat_multiplier = 1.0 + (precision - 10.0) * 0.02
	result.stat_multiplier = maxf(0.1, result.stat_multiplier)  # Minimum 10% damage

	# Optional: Apply distance falloff (currently unused but prepared for future)
	# For now, distance parameter is reserved for future range penalty/bonus
	var _distance_factor := 1.0
	if distance > 0.0:
		# Future: could reduce damage at extreme range
		pass

	# Check for critical hit
	var crit_result := calculate_crit(attacker_stats, rng_seed)
	result.is_critical = crit_result["is_crit"]
	result.crit_multiplier = crit_result["multiplier"]

	# Calculate damage before target reduction
	result.damage_before_reduction = result.base_damage * result.stat_multiplier
	if result.is_critical:
		result.damage_before_reduction *= result.crit_multiplier

	# Apply target's damage reduction from FORTITUDE
	result.damage_reduction = calculate_damage_reduction(target_stats, result.damage_before_reduction)
	result.final_damage = maxf(1.0, result.damage_before_reduction - result.damage_reduction)

	return result


## Calculate damage reduction based on defender's FORTITUDE stat.
## Uses diminishing returns formula: reduction = 1 - (100 / (100 + fortitude))
## @param defender_stats: The defender's PlayerStats
## @param incoming_damage: The incoming damage before reduction
## @returns: Amount of damage reduced (not the remaining damage)
static func calculate_damage_reduction(defender_stats: PlayerStats, incoming_damage: float) -> float:
	var fortitude := defender_stats.get_stat(ItemEnums.StatType.FORTITUDE)

	# Diminishing returns formula
	# At 0 fortitude: 0% reduction
	# At 10 fortitude: ~9% reduction
	# At 50 fortitude: ~33% reduction
	# At 100 fortitude: 50% reduction
	# At 200 fortitude: ~67% reduction
	var reduction_percent := 1.0 - (100.0 / (100.0 + fortitude))

	# Cap reduction at 90% to prevent invincibility
	reduction_percent = clampf(reduction_percent, 0.0, 0.9)

	return incoming_damage * reduction_percent


## Calculate critical hit based on attacker's stats.
## Uses CRIT_CHANCE and CRIT_DAMAGE stats.
## @param attacker_stats: The attacker's PlayerStats
## @param rng_seed: Optional seed for deterministic rolls (for testing)
## @returns: Dictionary with "is_crit" (bool) and "multiplier" (float)
static func calculate_crit(attacker_stats: PlayerStats, rng_seed: int = -1) -> Dictionary:
	var crit_chance := attacker_stats.get_stat(ItemEnums.StatType.CRIT_CHANCE)
	var crit_damage := attacker_stats.get_stat(ItemEnums.StatType.CRIT_DAMAGE)

	# Roll for crit
	var roll: float
	if rng_seed >= 0:
		# Deterministic roll for testing
		var rng := RandomNumberGenerator.new()
		rng.seed = rng_seed
		roll = rng.randf()
	else:
		roll = randf()

	var is_crit := roll < crit_chance

	return {
		"is_crit": is_crit,
		"multiplier": crit_damage if is_crit else 1.0
	}


## Calculate effective attack speed considering weapon and stats.
## @param attacker_stats: The attacker's PlayerStats
## @param weapon: The weapon ItemDefinition (can be null)
## @returns: Attacks per second multiplier
static func calculate_attack_speed(attacker_stats: PlayerStats, weapon: ItemDefinition) -> float:
	var base_speed := 1.0

	if weapon != null:
		base_speed = weapon.attack_speed

	var stat_speed := attacker_stats.get_stat(ItemEnums.StatType.ATTACK_SPEED)

	# Combine weapon and stat speed multiplicatively
	return base_speed * stat_speed


## Calculate environmental damage with resistance.
## @param defender_stats: The defender's PlayerStats
## @param damage_type: The resistance StatType to check
## @param base_damage: The incoming environmental damage
## @returns: Final damage after resistance reduction
static func calculate_environmental_damage(
	defender_stats: PlayerStats,
	damage_type: ItemEnums.StatType,
	base_damage: float
) -> float:
	# Validate that this is a resistance stat
	var valid_resists := [
		ItemEnums.StatType.HEAT_RESIST,
		ItemEnums.StatType.COLD_RESIST,
		ItemEnums.StatType.RADIATION_RESIST,
		ItemEnums.StatType.TOXIC_RESIST,
		ItemEnums.StatType.PRESSURE_RESIST,
	]

	if damage_type not in valid_resists:
		push_warning("CombatCalculator: Invalid resistance type for environmental damage")
		return base_damage

	var resistance := defender_stats.get_stat(damage_type)
	# Resistance is already capped at 0.9 (90%) in PlayerStats

	return base_damage * (1.0 - resistance)
