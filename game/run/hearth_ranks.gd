class_name HearthRanks
extends RefCounted
## The Hearth's endless levels, like paragon levels: every spark you bring home
## also feeds the Hearth, and each level grants a point for one of a few small
## permanent bonuses. The first two tracks never cap; points can be reset for
## free at the Hearth.

const TRACKS: Array[Dictionary] = [
	{"id": "weapons", "name": "Searing Light", "desc": "+1% weapon damage", "bonus": {"damage": 0.01}, "max": 0},
	{"id": "hull", "name": "Warded Hull", "desc": "+2 hull and +1 shield", "bonus": {"max_hull": 2.0, "max_shield": 1.0}, "max": 0},
	{"id": "kindling", "name": "Quick Flame", "desc": "Claims and sieges 1% faster", "bonus": {"claim_speed": 0.01}, "max": 40},
	{"id": "pilot", "name": "Steady Hands", "desc": "+3 pilot health and +1 barrier", "bonus": {"pilot_health": 3.0, "pilot_barrier": 1.0}, "max": 50},
]
## Experience for the first level, plus this much more for each level after.
const FIRST_LEVEL_XP := 100
const XP_PER_LEVEL := 20


static func get_track(id: String) -> Dictionary:
	for track in TRACKS:
		if track["id"] == id:
			return track
	return {}


## Experience needed to go from `current_level` to the next.
static func xp_to_next(current_level: int) -> int:
	return LevelCurve.to_next(current_level, FIRST_LEVEL_XP, XP_PER_LEVEL)


## The level reached with `xp` total experience.
static func level_for(xp: int) -> int:
	return LevelCurve.level_for(xp, FIRST_LEVEL_XP, XP_PER_LEVEL)


## Experience gathered toward the next level, and how much it needs.
static func progress_for(xp: int) -> Vector2i:
	return LevelCurve.progress_for(xp, FIRST_LEVEL_XP, XP_PER_LEVEL)
