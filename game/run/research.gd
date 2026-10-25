class_name Research
extends RefCounted
## Projects the homeworld's Lab can run, one at a time, on a real-time clock
## that keeps ticking during runs and while the game is closed. Each costs
## planet resources. A finished project gives a permanent bonus (in the same
## keys as MetaUpgrades, plus pilot and planet keys) or a part that every run
## starts with.

const LAB_COST := 150

const LIST: Array[Dictionary] = [
	{"id": "ember_coils", "name": "Ember Coils", "desc": "Claims and pylon sieges fill 10% faster",
		"cost": {"ore": 20}, "minutes": 3.0, "bonus": {"claim_speed": 0.1}},
	{"id": "field_rations", "name": "Field Rations", "desc": "Pilot +30 health and +20 barrier",
		"cost": {"biomass": 20}, "minutes": 3.0, "bonus": {"pilot_health": 30.0, "pilot_barrier": 20.0}},
	{"id": "lantern_lens", "name": "Lantern Lens", "desc": "Your lantern lights 30% farther on planets",
		"cost": {"crystal": 15}, "minutes": 3.0, "bonus": {"lantern": 0.3}},
	{"id": "reinforced_hulls", "name": "Reinforced Hulls", "desc": "+25 hull for every ship",
		"cost": {"ore": 30}, "minutes": 4.0, "bonus": {"max_hull": 25.0}},
	{"id": "flare_satchel", "name": "Flare Satchel", "desc": "Carry one more flare on planets",
		"cost": {"biomass": 15, "ore": 10}, "minutes": 4.0, "bonus": {"flares": 1.0}},
	{"id": "lens_grinding", "name": "Lens Grinding", "desc": "+10% damage for ship weapons and sidearm",
		"cost": {"crystal": 25}, "minutes": 5.0, "bonus": {"damage": 0.1}},
	{"id": "twin_mounts", "name": "Twin Mounts", "desc": "Start every run with a Twin Laser",
		"cost": {"ore": 25, "crystal": 10}, "minutes": 5.0, "start_part": "twin_laser"},
	{"id": "survey_drones", "name": "Survey Drones", "desc": "+50% resources when you kindle a planet",
		"cost": {"crystal": 25, "ore": 15}, "minutes": 6.0, "bonus": {"surface_haul": 0.5}},
	{"id": "heavy_kindler", "name": "Heavy Kindler", "desc": "Start every run with a Kindler Array",
		"cost": {"crystal": 30}, "minutes": 6.0, "start_part": "kindler_array"},
	{"id": "outpost_refinery", "name": "Outpost Refinery", "desc": "Outposts produce 50% more",
		"cost": {"ore": 30, "biomass": 20}, "minutes": 8.0, "bonus": {"outpost_output": 0.5}},
]


static func get_project(id: String) -> Dictionary:
	for project in LIST:
		if project["id"] == id:
			return project
	return {}


static func seconds(project: Dictionary) -> float:
	return float(project["minutes"]) * 60.0


## "20 ore + 10 crystal"
static func cost_text(project: Dictionary) -> String:
	var parts: Array[String] = []
	var cost: Dictionary = project["cost"]
	for kind in PlanetData.RESOURCE_ORDER:
		if cost.has(kind):
			parts.append("%d %s" % [int(cost[kind]), kind])
	return " + ".join(parts)


## "4:05" or "1h 02m"
static func duration_text(total_seconds: float) -> String:
	var whole := maxi(ceili(total_seconds), 0)
	if whole >= 3600:
		return "%dh %02dm" % [whole / 3600, (whole % 3600) / 60]
	return "%d:%02d" % [whole / 60, whole % 60]
