class_name PilotRanks
extends RefCounted
## The pilot's own growth, separate from the ship: experience earned on
## planets (kills, deposits, caches, kindling, building) raises the pilot's
## level, and each level is a point for one of four stats, spent at the
## Quarters and reset there for free.

const STATS: Array[Dictionary] = [
	{"id": "vitality", "name": "Vitality", "desc": "+12 health", "bonus": {"pilot_health": 12.0}, "max": 0},
	{"id": "agility", "name": "Agility", "desc": "+3% speed, rolls recharge 3% faster", "bonus": {"pilot_speed": 0.03, "pilot_roll": 0.03}, "max": 20},
	{"id": "aim", "name": "Aim", "desc": "+6% sidearm damage", "bonus": {"sidearm_damage": 0.06}, "max": 0},
	{"id": "lantern", "name": "Lanterncraft", "desc": "+6% lantern reach, +3 barrier", "bonus": {"lantern": 0.06, "pilot_barrier": 3.0}, "max": 25},
]
const FIRST_LEVEL_XP := 60
const XP_PER_LEVEL := 15
## Experience for each Gloom kind killed on foot.
const KILL_XP := {"mite": 2, "dart": 4, "spitter": 4, "brood": 5, "carapace": 8, "lancer": 6, "snuffer": 12, "nest": 15}
const DEPOSIT_XP := 6
const CACHE_XP := 10
const EXTRACTOR_XP := 5


static func get_stat(id: String) -> Dictionary:
	for stat in STATS:
		if stat["id"] == id:
			return stat
	return {}


static func kindle_xp(depth: int) -> int:
	return 60 + 20 * depth


static func level_for(xp: int) -> int:
	return LevelCurve.level_for(xp, FIRST_LEVEL_XP, XP_PER_LEVEL)


static func progress_for(xp: int) -> Vector2i:
	return LevelCurve.progress_for(xp, FIRST_LEVEL_XP, XP_PER_LEVEL)
