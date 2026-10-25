class_name MetaUpgrades
extends RefCounted
## Permanent upgrades bought with banked sparks between runs, plus blueprints
## that add parts to the loot pool. Each rank costs more than the last.

const LIST: Array[Dictionary] = [
	{"id": "hull", "name": "Reinforced Frame", "desc": "+15 hull per rank", "max": 5, "cost": 40, "stat": "max_hull", "per_rank": 15.0},
	{"id": "shield", "name": "Shield Matrix", "desc": "+10 shield per rank", "max": 5, "cost": 40, "stat": "max_shield", "per_rank": 10.0},
	{"id": "magnet", "name": "Ember Magnet", "desc": "+20 spark pickup range per rank", "max": 5, "cost": 30, "stat": "magnet", "per_rank": 20.0},
	{"id": "damage", "name": "Hot Cores", "desc": "+8% weapon damage per rank", "max": 5, "cost": 50, "stat": "damage", "per_rank": 0.08},
	{"id": "kindling", "name": "Kindling", "desc": "Claims fill 6% faster per rank", "max": 5, "cost": 45, "stat": "claim_speed", "per_rank": 0.06},
	{"id": "engines", "name": "Tuned Engines", "desc": "+5% speed per rank", "max": 3, "cost": 40, "stat": "speed", "per_rank": 0.05},
	{"id": "revive", "name": "Spare Spark", "desc": "Revive once per run per rank", "max": 2, "cost": 150, "special": "revive"},
	{"id": "reroll", "name": "Second Look", "desc": "+1 free loot reroll per run", "max": 3, "cost": 60, "special": "reroll"},
	{"id": "corvette", "name": "Corvette Hull", "desc": "Start runs in a bigger hull", "max": 1, "cost": 400, "special": "corvette"},
]

## Parts that start locked; buying the blueprint adds them to the loot pool.
const BLUEPRINTS := {
	"seeker_pod": 90,
	"point_defense": 70,
	"overclock_coil": 70,
	"field_capacitor": 100,
	"torpedo_bay": 120,
	"lance": 120,
}


static func get_upgrade(id: String) -> Dictionary:
	for upgrade in LIST:
		if upgrade["id"] == id:
			return upgrade
	return {}


## Cost of the next rank when you already own `rank` ranks.
static func cost(upgrade: Dictionary, rank: int) -> int:
	return int(upgrade["cost"]) * (rank + 1)


## Parts available in loot picks before buying any blueprints.
static func default_components() -> Array[String]:
	var ids: Array[String] = []
	for def in ComponentLibrary.all():
		if not BLUEPRINTS.has(def.id):
			ids.append(def.id)
	return ids
