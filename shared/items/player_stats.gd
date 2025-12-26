class_name PlayerStats
extends RefCounted
## Calculates and caches total player stats from base values, equipment, and skills.
## This is the authoritative source for a player's effective stats.


## Signal emitted when stats are recalculated
signal stats_changed


## Base stats for all players (before equipment/skills)
const BASE_STATS: Dictionary = {
	ItemEnums.StatType.MAX_HP: 100.0,
	ItemEnums.StatType.HP_REGEN: 1.0,
	ItemEnums.StatType.MAX_ENERGY: 100.0,
	ItemEnums.StatType.ENERGY_REGEN: 5.0,
	ItemEnums.StatType.STRENGTH: 10.0,
	ItemEnums.StatType.PRECISION: 10.0,
	ItemEnums.StatType.FORTITUDE: 10.0,
	ItemEnums.StatType.EFFICIENCY: 10.0,
	ItemEnums.StatType.LUCK: 10.0,
	ItemEnums.StatType.MOVE_SPEED: 1.0,
	ItemEnums.StatType.ATTACK_SPEED: 1.0,
	ItemEnums.StatType.CRIT_CHANCE: 0.05,
	ItemEnums.StatType.CRIT_DAMAGE: 1.5,
	ItemEnums.StatType.HEAT_RESIST: 0.0,
	ItemEnums.StatType.COLD_RESIST: 0.0,
	ItemEnums.StatType.RADIATION_RESIST: 0.0,
	ItemEnums.StatType.TOXIC_RESIST: 0.0,
	ItemEnums.StatType.PRESSURE_RESIST: 0.0,
}


## Reference to equipment slots
var equipment: EquipmentSlots

## Reference to equipment set registry (optional, for set bonuses)
var _set_registry: EquipmentSet.Registry = null

## Reference to player skills (optional, for skill bonuses)
var _player_skills: PlayerSkills = null

## Cached calculated stats
var _cached_stats: Dictionary = {}

## Whether cache needs recalculation
var _cache_dirty: bool = true

## Mapping from skill bonus type strings to StatType enums
## Skills use string keys like "damage", we map them to StatType
const SKILL_BONUS_TO_STAT: Dictionary = {
	"damage": ItemEnums.StatType.STRENGTH,
	"crit_chance": ItemEnums.StatType.CRIT_CHANCE,
	"crit_damage": ItemEnums.StatType.CRIT_DAMAGE,
	"max_hp": ItemEnums.StatType.MAX_HP,
	"hp_regen": ItemEnums.StatType.HP_REGEN,
	"max_energy": ItemEnums.StatType.MAX_ENERGY,
	"energy_regen": ItemEnums.StatType.ENERGY_REGEN,
	"move_speed": ItemEnums.StatType.MOVE_SPEED,
	"attack_speed": ItemEnums.StatType.ATTACK_SPEED,
	"fortitude": ItemEnums.StatType.FORTITUDE,
	"precision": ItemEnums.StatType.PRECISION,
	"efficiency": ItemEnums.StatType.EFFICIENCY,
	"luck": ItemEnums.StatType.LUCK,
	"heat_resist": ItemEnums.StatType.HEAT_RESIST,
	"cold_resist": ItemEnums.StatType.COLD_RESIST,
	"radiation_resist": ItemEnums.StatType.RADIATION_RESIST,
	"toxic_resist": ItemEnums.StatType.TOXIC_RESIST,
	"pressure_resist": ItemEnums.StatType.PRESSURE_RESIST,
}


func _init(equipment_slots: EquipmentSlots = null) -> void:
	equipment = equipment_slots
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_changed)
	_invalidate_cache()


## Set equipment slots reference
func set_equipment(equipment_slots: EquipmentSlots) -> void:
	if equipment != null:
		equipment.equipment_changed.disconnect(_on_equipment_changed)

	equipment = equipment_slots
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_changed)
	_invalidate_cache()


## Set the equipment set registry for set bonus calculations
func set_set_registry(registry: EquipmentSet.Registry) -> void:
	_set_registry = registry
	_invalidate_cache()


## Set the player skills reference for skill bonus calculations
func set_player_skills(skills: PlayerSkills) -> void:
	# Disconnect from old skills if any
	if _player_skills != null and _player_skills.level_up.is_connected(_on_skill_changed):
		_player_skills.level_up.disconnect(_on_skill_changed)

	_player_skills = skills

	# Connect to new skills for auto-update on level changes
	if _player_skills != null:
		_player_skills.level_up.connect(_on_skill_changed)
	_invalidate_cache()


## Handler for skill level changes
func _on_skill_changed(_skill_id: String, _new_level: int) -> void:
	_invalidate_cache()
	stats_changed.emit()


## Get a specific stat (uses cache)
func get_stat(stat: ItemEnums.StatType) -> float:
	_ensure_cache_valid()
	return _cached_stats.get(stat, BASE_STATS.get(stat, 0.0))


## Get all stats as dictionary (uses cache)
func get_all_stats() -> Dictionary:
	_ensure_cache_valid()
	return _cached_stats.duplicate()


## Force recalculation of stats
func recalculate() -> void:
	_invalidate_cache()
	_ensure_cache_valid()


## Invalidate the cache (call when equipment or skills change)
func _invalidate_cache() -> void:
	_cache_dirty = true


## Ensure cache is valid, recalculate if needed
func _ensure_cache_valid() -> void:
	if not _cache_dirty:
		return

	_cached_stats = _calculate_stats()
	_cache_dirty = false


## Calculate all stats from sources
func _calculate_stats() -> Dictionary:
	var stats: Dictionary = {}

	# Start with base stats
	for stat in BASE_STATS:
		stats[stat] = BASE_STATS[stat]

	# Add equipment stats
	if equipment != null:
		var equip_stats := equipment.get_total_stats()
		for stat in equip_stats:
			stats[stat] = stats.get(stat, 0.0) + equip_stats[stat]

	# Add skill bonuses (requires player skills reference)
	if _player_skills != null:
		stats = _apply_skill_bonuses(stats)

	# Add set bonuses (requires set registry and equipment)
	if _set_registry != null and equipment != null:
		stats = _apply_set_bonuses(stats)

	# TODO: Add active buff effects

	# Apply stat caps/floors
	stats = _apply_stat_limits(stats)

	return stats


## Apply skill bonuses to stats
## Skills provide bonuses based on their level_bonuses dictionary
func _apply_skill_bonuses(stats: Dictionary) -> Dictionary:
	# Get all skill definitions and check for stat-related bonuses
	for skill_def in _player_skills.get_all_skill_definitions():
		var skill_id := skill_def.id
		if not _player_skills.is_skill_unlocked(skill_id):
			continue

		var level := _player_skills.get_skill_level(skill_id)
		if level <= 0:
			continue

		# Check each bonus type this skill provides
		for bonus_type in skill_def.level_bonuses:
			# See if this bonus type maps to a stat
			if SKILL_BONUS_TO_STAT.has(bonus_type):
				var stat_type: ItemEnums.StatType = SKILL_BONUS_TO_STAT[bonus_type]
				var bonus_value: float = skill_def.get_bonus_at_level(bonus_type, level)
				stats[stat_type] = stats.get(stat_type, 0.0) + bonus_value

	return stats


## Apply equipment set bonuses to stats
func _apply_set_bonuses(stats: Dictionary) -> Dictionary:
	# Get all equipped item definition IDs
	var equipped_item_ids: Array = []
	for item in equipment.get_all_equipped():
		if item != null and item.definition != null:
			equipped_item_ids.append(item.definition.id)

	# Get all active set bonuses
	var all_bonuses := _set_registry.get_all_active_bonuses(equipped_item_ids)

	# Apply stat bonuses from each active set
	for set_id in all_bonuses:
		var set_data: Dictionary = all_bonuses[set_id]
		var stat_bonuses: Dictionary = set_data.get("stat_bonuses", {})

		for stat in stat_bonuses:
			stats[stat] = stats.get(stat, 0.0) + stat_bonuses[stat]

	return stats


## Apply minimum/maximum limits to stats
func _apply_stat_limits(stats: Dictionary) -> Dictionary:
	# HP can't go below 1
	if stats.has(ItemEnums.StatType.MAX_HP):
		stats[ItemEnums.StatType.MAX_HP] = maxf(1.0, stats[ItemEnums.StatType.MAX_HP])

	# Energy can't go below 0
	if stats.has(ItemEnums.StatType.MAX_ENERGY):
		stats[ItemEnums.StatType.MAX_ENERGY] = maxf(0.0, stats[ItemEnums.StatType.MAX_ENERGY])

	# Speed multipliers can't go below 0.1 (10%)
	if stats.has(ItemEnums.StatType.MOVE_SPEED):
		stats[ItemEnums.StatType.MOVE_SPEED] = maxf(0.1, stats[ItemEnums.StatType.MOVE_SPEED])
	if stats.has(ItemEnums.StatType.ATTACK_SPEED):
		stats[ItemEnums.StatType.ATTACK_SPEED] = maxf(0.1, stats[ItemEnums.StatType.ATTACK_SPEED])

	# Crit chance capped at 100%
	if stats.has(ItemEnums.StatType.CRIT_CHANCE):
		stats[ItemEnums.StatType.CRIT_CHANCE] = clampf(
			stats[ItemEnums.StatType.CRIT_CHANCE], 0.0, 1.0
		)

	# Crit damage minimum 1.0 (no reduction)
	if stats.has(ItemEnums.StatType.CRIT_DAMAGE):
		stats[ItemEnums.StatType.CRIT_DAMAGE] = maxf(1.0, stats[ItemEnums.StatType.CRIT_DAMAGE])

	# Resistances capped at 90%
	for resist in [ItemEnums.StatType.HEAT_RESIST, ItemEnums.StatType.COLD_RESIST,
				   ItemEnums.StatType.RADIATION_RESIST, ItemEnums.StatType.TOXIC_RESIST,
				   ItemEnums.StatType.PRESSURE_RESIST]:
		if stats.has(resist):
			stats[resist] = clampf(stats[resist], 0.0, 0.9)

	return stats


## Handler for equipment changes
func _on_equipment_changed(_slot: ItemEnums.EquipSlot) -> void:
	_invalidate_cache()
	stats_changed.emit()


# =============================================================================
# Derived stat helpers
# =============================================================================

## Get maximum HP
func get_max_hp() -> float:
	return get_stat(ItemEnums.StatType.MAX_HP)


## Get HP regeneration per second
func get_hp_regen() -> float:
	return get_stat(ItemEnums.StatType.HP_REGEN)


## Get maximum energy
func get_max_energy() -> float:
	return get_stat(ItemEnums.StatType.MAX_ENERGY)


## Get energy regeneration per second
func get_energy_regen() -> float:
	return get_stat(ItemEnums.StatType.ENERGY_REGEN)


## Get movement speed multiplier
func get_move_speed() -> float:
	return get_stat(ItemEnums.StatType.MOVE_SPEED)


## Get attack speed multiplier
func get_attack_speed() -> float:
	return get_stat(ItemEnums.StatType.ATTACK_SPEED)


## Get crit chance (0.0 - 1.0)
func get_crit_chance() -> float:
	return get_stat(ItemEnums.StatType.CRIT_CHANCE)


## Get crit damage multiplier
func get_crit_damage() -> float:
	return get_stat(ItemEnums.StatType.CRIT_DAMAGE)


## Calculate melee damage based on strength
func calculate_melee_damage(base_damage: float) -> float:
	var strength := get_stat(ItemEnums.StatType.STRENGTH)
	# Each point of strength adds 2% damage
	var multiplier := 1.0 + (strength - 10.0) * 0.02
	return base_damage * maxf(0.1, multiplier)


## Calculate ranged damage based on precision
func calculate_ranged_damage(base_damage: float) -> float:
	var precision := get_stat(ItemEnums.StatType.PRECISION)
	var multiplier := 1.0 + (precision - 10.0) * 0.02
	return base_damage * maxf(0.1, multiplier)


## Calculate damage reduction from fortitude
func calculate_damage_reduction() -> float:
	var fortitude := get_stat(ItemEnums.StatType.FORTITUDE)
	# Diminishing returns formula: 1 - (100 / (100 + fortitude))
	return 1.0 - (100.0 / (100.0 + fortitude))


## Calculate tool efficiency multiplier
func calculate_tool_efficiency() -> float:
	var efficiency := get_stat(ItemEnums.StatType.EFFICIENCY)
	return 1.0 + (efficiency - 10.0) * 0.02


## Calculate luck bonus for drops/crafting
func calculate_luck_bonus() -> float:
	var luck := get_stat(ItemEnums.StatType.LUCK)
	return 1.0 + (luck - 10.0) * 0.01


## Calculate resistance reduction for a damage type
func calculate_resistance_reduction(resist_type: ItemEnums.StatType) -> float:
	return get_stat(resist_type)


## Serialize current stats snapshot
func to_dict() -> Dictionary:
	_ensure_cache_valid()
	var data: Dictionary = {}
	for stat in _cached_stats:
		data[str(stat)] = _cached_stats[stat]
	return data
