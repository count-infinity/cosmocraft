class_name ToolCalculator
extends RefCounted
## Static utility class for tool efficiency and durability calculations.
## Uses PlayerStats EFFICIENCY stat for bonuses.
## Server-authoritative: all calculations happen server-side.

const PlayerStatsClass = preload("res://shared/items/player_stats.gd")
const ItemDefinitionClass = preload("res://shared/items/item_definition.gd")
const ItemInstanceClass = preload("res://shared/items/item_instance.gd")
const ItemEnumsClass = preload("res://shared/items/item_enums.gd")


## Result of an efficiency calculation
class EfficiencyResult:
	var base_efficiency: float = 1.0
	var tool_tier_bonus: float = 1.0
	var stat_multiplier: float = 1.0
	var total_efficiency: float = 1.0

	func _to_string() -> String:
		return "EfficiencyResult(base=%.2f, tier=%.2f, stat=%.2f, total=%.2f)" % [
			base_efficiency, tool_tier_bonus, stat_multiplier, total_efficiency
		]


## Result of a durability calculation
class DurabilityResult:
	var base_cost: int = 1
	var efficiency_reduction: float = 1.0
	var final_cost: int = 1

	func _to_string() -> String:
		return "DurabilityResult(base=%d, reduction=%.2f, final=%d)" % [
			base_cost, efficiency_reduction, final_cost
		]


## Calculate gathering efficiency for a player using a tool.
## Higher efficiency = faster gathering and potentially better yields.
## Uses EFFICIENCY stat for bonus.
## @param player_stats: The player's PlayerStats
## @param tool: The tool ItemDefinition (can be null for bare hands)
## @param target_tier: The tier of the material being gathered (for tier matching bonus)
## @returns: EfficiencyResult with full breakdown
static func calculate_gathering_efficiency(
	player_stats: PlayerStats,
	tool: ItemDefinition,
	target_tier: int = 1
) -> EfficiencyResult:
	var result := EfficiencyResult.new()

	# Base efficiency from tool
	if tool != null and tool.type == ItemEnums.ItemType.TOOL:
		result.base_efficiency = 1.0

		# Tool tier bonus: higher tier tools work faster on lower tier materials
		var tool_tier := tool.tier
		if tool_tier >= target_tier:
			# Bonus for using higher tier tool: 20% per tier difference
			result.tool_tier_bonus = 1.0 + (tool_tier - target_tier) * 0.2
		else:
			# Penalty for using lower tier tool: 50% penalty per tier difference
			# Also may not be able to gather at all (handled elsewhere)
			result.tool_tier_bonus = maxf(0.1, 1.0 - (target_tier - tool_tier) * 0.5)
	else:
		# No tool or wrong type: bare hands
		result.base_efficiency = 0.5  # Half efficiency with bare hands
		result.tool_tier_bonus = 1.0
		# Bare hands can only gather tier 1 materials effectively
		if target_tier > 1:
			result.tool_tier_bonus = 0.1

	# Calculate stat multiplier from EFFICIENCY
	# Each point of efficiency above 10 adds 2% to efficiency
	var efficiency := player_stats.get_stat(ItemEnums.StatType.EFFICIENCY)
	result.stat_multiplier = 1.0 + (efficiency - 10.0) * 0.02
	result.stat_multiplier = maxf(0.1, result.stat_multiplier)

	# Calculate total efficiency
	result.total_efficiency = result.base_efficiency * result.tool_tier_bonus * result.stat_multiplier

	return result


## Calculate durability cost for using a tool.
## Higher EFFICIENCY stat reduces durability consumption.
## @param player_stats: The player's PlayerStats
## @param tool: The tool ItemInstance (not definition, we need durability info)
## @param base_cost: The base durability cost for this action (default 1)
## @returns: DurabilityResult with final durability cost
static func calculate_durability_use(
	player_stats: PlayerStats,
	tool: ItemInstance,
	base_cost: int = 1
) -> DurabilityResult:
	var result := DurabilityResult.new()
	result.base_cost = base_cost

	if tool == null or tool.definition == null:
		result.final_cost = 0  # No durability cost if no tool
		return result

	if not tool.definition.has_durability():
		result.final_cost = 0  # Tool has no durability (indestructible)
		return result

	# EFFICIENCY reduces durability consumption
	# Each point of efficiency above 10 reduces cost by 1%
	var efficiency := player_stats.get_stat(ItemEnums.StatType.EFFICIENCY)
	result.efficiency_reduction = maxf(0.5, 1.0 - (efficiency - 10.0) * 0.01)

	# Calculate final cost (minimum 1 if base cost > 0)
	var reduced_cost := float(base_cost) * result.efficiency_reduction
	result.final_cost = maxi(1, roundi(reduced_cost))

	return result


## Check if a tool can harvest a specific tier of material.
## @param tool: The tool ItemDefinition
## @param target_tier: The tier of the material
## @returns: True if the tool can harvest this material
static func can_harvest_tier(tool: ItemDefinition, target_tier: int) -> bool:
	if tool == null:
		# Bare hands can only harvest tier 1
		return target_tier <= 1

	if tool.type != ItemEnums.ItemType.TOOL:
		return false

	# Tool's harvest_tier determines what it can harvest
	return tool.harvest_tier >= target_tier


## Calculate the time to gather a resource.
## @param player_stats: The player's PlayerStats
## @param tool: The tool ItemDefinition
## @param base_time: Base gathering time in seconds
## @param target_tier: The tier of the resource
## @returns: Actual gathering time in seconds
static func calculate_gather_time(
	player_stats: PlayerStats,
	tool: ItemDefinition,
	base_time: float,
	target_tier: int = 1
) -> float:
	var efficiency := calculate_gathering_efficiency(player_stats, tool, target_tier)

	# Time is inversely proportional to efficiency
	var gather_time := base_time / efficiency.total_efficiency

	# Minimum gather time of 0.1 seconds to prevent instant gathering
	return maxf(0.1, gather_time)


## Calculate bonus drops based on luck and efficiency.
## @param player_stats: The player's PlayerStats
## @param base_drops: Base number of items dropped
## @param rng_seed: Optional seed for deterministic rolls (for testing)
## @returns: Final number of items to drop
static func calculate_bonus_drops(
	player_stats: PlayerStats,
	base_drops: int,
	rng_seed: int = -1
) -> int:
	var luck := player_stats.get_stat(ItemEnums.StatType.LUCK)

	# Luck bonus: each point above 10 adds 1% chance for bonus drop
	var bonus_chance := (luck - 10.0) * 0.01

	if bonus_chance <= 0:
		return base_drops

	# Roll for each potential bonus drop
	var bonus_drops := 0
	var max_bonus := ceili(float(base_drops) * bonus_chance)

	var rng: RandomNumberGenerator
	if rng_seed >= 0:
		rng = RandomNumberGenerator.new()
		rng.seed = rng_seed
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	for i in range(max_bonus):
		if rng.randf() < bonus_chance:
			bonus_drops += 1

	return base_drops + bonus_drops


## Calculate tool mode effectiveness.
## Different modes have different efficiency/durability tradeoffs.
## @param tool: The tool ItemDefinition
## @param mode: The tool mode to use
## @returns: Dictionary with "efficiency_mult" and "durability_mult"
static func get_mode_modifiers(tool: ItemDefinition, mode: ItemEnums.ToolMode) -> Dictionary:
	if tool == null or mode not in tool.available_modes:
		return {
			"efficiency_mult": 1.0,
			"durability_mult": 1.0,
			"area": 1
		}

	match mode:
		ItemEnums.ToolMode.STANDARD:
			return {
				"efficiency_mult": 1.0,
				"durability_mult": 1.0,
				"area": 1
			}
		ItemEnums.ToolMode.PRECISION:
			# Slower but more careful - better quality results
			return {
				"efficiency_mult": 0.7,
				"durability_mult": 0.8,
				"area": 1
			}
		ItemEnums.ToolMode.AREA:
			# Hits multiple blocks but uses more durability
			return {
				"efficiency_mult": 0.8,
				"durability_mult": 2.0,
				"area": 9  # 3x3 area
			}
		ItemEnums.ToolMode.VEIN:
			# Mines connected blocks of same type
			return {
				"efficiency_mult": 0.9,
				"durability_mult": 1.0,  # Per block
				"area": -1  # Special: follows vein
			}

	return {
		"efficiency_mult": 1.0,
		"durability_mult": 1.0,
		"area": 1
	}
