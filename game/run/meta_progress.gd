class_name MetaProgress
extends RefCounted
## What carries over between runs: banked sparks and planet resources,
## permanent upgrade ranks, unlocked blueprints, the homeworld's buildings and
## research, outposts on kindled planets, the darkness levels unlocked, Hearth
## levels, and a few lifetime records. Saved as JSON in user://.
##
## Research and outposts run on the real clock (unix seconds), so they keep
## going during runs and while the game is closed. Functions that care take
## `now` so tests can control time.

const SAVE_PATH := "user://cosmocraft_save.json"
const VERSION := 2
## Resources each outpost produces per hour, and how many hours can pile up
## before the Relay has to collect them.
const OUTPOST_RATE := 6.0
const OUTPOST_CAP_HOURS := 12.0
## Each extractor built on a planet adds this much to its outpost's hourly rate.
const EXTRACTOR_RATE := 3.0

var sparks := 0
var ranks: Dictionary = {}
var blueprints: Array[String] = []
var runs := 0
var wins := 0
var best_regions := 0
var lifetime_sparks := 0
var resources := {"ore": 0, "crystal": 0, "biomass": 0}
## Kindled planets: {"name", "type", "resource", "collected_at"}.
var outposts: Array[Dictionary] = []
var buildings: Array[String] = []
var research_done: Array[String] = []
## The Lab's current project: {"id": String, "finish_at": float}, or empty.
var research_active: Dictionary = {}
## The darkness picked for the next run, and the darkest one unlocked so far.
var darkness := Difficulty.DEFAULT
var darkness_unlocked := Difficulty.DEFAULT
## The darkest level a sector has been relit on (-1 for none yet).
var darkness_relit := -1
## Every banked spark feeds the Hearth; its level grants points to spend.
var hearth_xp := 0
var hearth_points: Dictionary = {}
## The pilot's experience (earned on planets) and stat points spent.
var pilot_xp := 0
var pilot_points: Dictionary = {}
## Set by relight_sector when a win unlocks a darker level (not saved).
var newly_unlocked := -1
## The conquest map: which galaxy (by seed), the sectors conquered (home is
## always one), and the sector picked for the next run.
var galaxy_seed := 0
var conquered: Array[int] = []
var selected_sector := -1
## Each conquered system adds this much to every reward.
const SYSTEM_REWARD_BONUS := 0.1

var _galaxy: GalaxyData


static func now() -> float:
	return Time.get_unix_time_from_system()


func rank(upgrade_id: String) -> int:
	return int(ranks.get(upgrade_id, 0))


func next_cost(upgrade_id: String) -> int:
	return MetaUpgrades.cost(MetaUpgrades.get_upgrade(upgrade_id), rank(upgrade_id))


func is_maxed(upgrade_id: String) -> bool:
	return rank(upgrade_id) >= int(MetaUpgrades.get_upgrade(upgrade_id)["max"])


func can_buy(upgrade_id: String) -> bool:
	return not is_maxed(upgrade_id) and sparks >= next_cost(upgrade_id)


func buy(upgrade_id: String) -> bool:
	if not can_buy(upgrade_id):
		return false
	sparks -= next_cost(upgrade_id)
	ranks[upgrade_id] = rank(upgrade_id) + 1
	return true


func can_buy_blueprint(component_id: String) -> bool:
	return MetaUpgrades.BLUEPRINTS.has(component_id) and not blueprints.has(component_id) \
		and sparks >= int(MetaUpgrades.BLUEPRINTS[component_id])


func buy_blueprint(component_id: String) -> bool:
	if not can_buy_blueprint(component_id):
		return false
	sparks -= int(MetaUpgrades.BLUEPRINTS[component_id])
	blueprints.append(component_id)
	return true


## Parts that can show up in loot picks.
func unlocked_components() -> Array[String]:
	var ids := MetaUpgrades.default_components()
	ids.append_array(blueprints)
	return ids


## Stat bonuses from upgrade ranks and finished research, using
## Loadout.compute_stats keys (plus pilot and planet keys the surface reads).
func stat_bonuses() -> Dictionary:
	var bonuses := {}
	for upgrade in MetaUpgrades.LIST:
		if upgrade.has("stat") and rank(upgrade["id"]) > 0:
			bonuses[upgrade["stat"]] = float(upgrade["per_rank"]) * rank(upgrade["id"])
	for id in research_done:
		var project := Research.get_project(id)
		var bonus: Dictionary = project.get("bonus", {})
		for key: String in bonus:
			bonuses[key] = float(bonuses.get(key, 0.0)) + float(bonus[key])
	for id: String in hearth_points:
		var bonus: Dictionary = HearthRanks.get_track(id).get("bonus", {})
		for key: String in bonus:
			bonuses[key] = float(bonuses.get(key, 0.0)) + float(bonus[key]) * int(hearth_points[id])
	for id: String in pilot_points:
		var bonus: Dictionary = PilotRanks.get_stat(id).get("bonus", {})
		for key: String in bonus:
			bonuses[key] = float(bonuses.get(key, 0.0)) + float(bonus[key]) * int(pilot_points[id])
	return bonuses


## Parts every run starts with, from finished research.
func start_parts() -> Array[String]:
	var ids: Array[String] = []
	for id in research_done:
		var part := String(Research.get_project(id).get("start_part", ""))
		if not part.is_empty():
			ids.append(part)
	return ids


func starting_hull() -> HullDef:
	return HullDef.corvette() if rank("corvette") > 0 else HullDef.skiff()


# --- The conquest map ----------------------------------------------------------------

## The galaxy, generated from its seed the first time it's needed.
func galaxy() -> GalaxyData:
	if galaxy_seed == 0:
		galaxy_seed = randi_range(1, 999999)
	if _galaxy == null or _galaxy.galaxy_seed != galaxy_seed:
		_galaxy = GalaxyData.generate(galaxy_seed)
		if not conquered.has(_galaxy.home_id):
			conquered.append(_galaxy.home_id)
	return _galaxy


func conquered_set() -> Dictionary:
	var owned := {}
	for id in conquered:
		owned[id] = true
	owned[galaxy().home_id] = true
	return owned


## The sector a run can launch into: any dark sector on a lane from your
## territory, or one already conquered (to replay it).
func can_select_sector(id: int) -> bool:
	var map := galaxy()
	if id < 0 or id >= map.sectors.size() or id == map.home_id:
		return false
	var owned := conquered_set()
	return owned.has(id) or map.can_invade(id, owned)


func select_sector(id: int) -> bool:
	if not can_select_sector(id):
		return false
	selected_sector = id
	return true


## The picked sector, or the easiest frontier sector if none is picked.
func launch_sector() -> int:
	if can_select_sector(selected_sector):
		return selected_sector
	var map := galaxy()
	var frontier := map.frontier(conquered_set())
	frontier.sort_custom(func(a: int, b: int) -> bool: return map.sectors[a].tier < map.sectors[b].tier)
	selected_sector = frontier[0] if not frontier.is_empty() else map.sectors[map.home_id].neighbors[0]
	return selected_sector


func conquest_bonus() -> float:
	return SYSTEM_REWARD_BONUS * galaxy().systems_conquered(conquered_set())


## A sector's heart burned out on `darkness`. Conquers it, counts the win, and
## unlocks the next darkness if this was the darkest one. Returns what's new:
## {"conquered": bool, "system": name of a system that just fell or "",
##  "galaxy": bool, "unlocked": darkness level or -1}.
func relight_sector(id: int, darkness_level: int) -> Dictionary:
	var map := galaxy()
	var news := {"conquered": false, "system": "", "galaxy": false, "unlocked": -1}
	wins += 1
	darkness_relit = maxi(darkness_relit, darkness_level)
	if darkness_level >= darkness_unlocked and darkness_unlocked < Difficulty.MAX_LEVEL:
		darkness_unlocked += 1
		newly_unlocked = darkness_unlocked
		news["unlocked"] = darkness_unlocked
	if id == selected_sector:
		selected_sector = -1
	if id >= 0 and id < map.sectors.size() and not conquered.has(id):
		var system_before := map.system_conquered(map.sectors[id].system_id, conquered_set())
		conquered.append(id)
		news["conquered"] = true
		var owned := conquered_set()
		if not system_before and map.system_conquered(map.sectors[id].system_id, owned):
			news["system"] = map.system_of(id).name
		news["galaxy"] = map.galaxy_conquered(owned)
	return news


# --- Darkness and the Hearth -----------------------------------------------------------

## Picks the darkness for the next run, if it's unlocked.
func select_darkness(level: int) -> bool:
	if level < 0 or level > darkness_unlocked:
		return false
	darkness = level
	return true


func hearth_level() -> int:
	return HearthRanks.level_for(hearth_xp)


func hearth_points_spent() -> int:
	var spent := 0
	for id: String in hearth_points:
		spent += int(hearth_points[id])
	return spent


func hearth_points_free() -> int:
	return hearth_level() - hearth_points_spent()


func can_spend_hearth_point(track_id: String) -> bool:
	var track := HearthRanks.get_track(track_id)
	if track.is_empty() or hearth_points_free() <= 0:
		return false
	var cap := int(track["max"])
	return cap <= 0 or int(hearth_points.get(track_id, 0)) < cap


func spend_hearth_point(track_id: String) -> bool:
	if not can_spend_hearth_point(track_id):
		return false
	hearth_points[track_id] = int(hearth_points.get(track_id, 0)) + 1
	return true


## Takes every point back to spend again (free).
func reset_hearth_points() -> void:
	hearth_points.clear()


func pilot_level() -> int:
	return PilotRanks.level_for(pilot_xp)


func pilot_points_free() -> int:
	var spent := 0
	for id: String in pilot_points:
		spent += int(pilot_points[id])
	return pilot_level() - spent


func can_spend_pilot_point(stat_id: String) -> bool:
	var stat := PilotRanks.get_stat(stat_id)
	if stat.is_empty() or pilot_points_free() <= 0:
		return false
	var cap := int(stat["max"])
	return cap <= 0 or int(pilot_points.get(stat_id, 0)) < cap


func spend_pilot_point(stat_id: String) -> bool:
	if not can_spend_pilot_point(stat_id):
		return false
	pilot_points[stat_id] = int(pilot_points.get(stat_id, 0)) + 1
	return true


func reset_pilot_points() -> void:
	pilot_points.clear()


# --- Resources ---------------------------------------------------------------------

func can_afford(cost: Dictionary) -> bool:
	for kind: String in cost:
		if int(resources.get(kind, 0)) < int(cost[kind]):
			return false
	return true


func spend(cost: Dictionary) -> void:
	for kind: String in cost:
		resources[kind] = int(resources.get(kind, 0)) - int(cost[kind])


# --- Buildings and research ----------------------------------------------------------

func has_building(id: String) -> bool:
	return buildings.has(id)


func can_build_lab() -> bool:
	return not has_building("lab") and sparks >= Research.LAB_COST


func build_lab() -> bool:
	if not can_build_lab():
		return false
	sparks -= Research.LAB_COST
	buildings.append("lab")
	return true


func is_researching() -> bool:
	return not research_active.is_empty()


func can_start_research(id: String) -> bool:
	var project := Research.get_project(id)
	return has_building("lab") and not project.is_empty() and not is_researching() \
		and not research_done.has(id) and can_afford(project["cost"])


func start_research(id: String, at := now()) -> bool:
	if not can_start_research(id):
		return false
	var project := Research.get_project(id)
	spend(project["cost"])
	research_active = {"id": id, "finish_at": at + Research.seconds(project)}
	return true


## 0..1 progress of the current project.
func research_progress(at := now()) -> float:
	if not is_researching():
		return 0.0
	var project := Research.get_project(String(research_active["id"]))
	var left := float(research_active["finish_at"]) - at
	return clampf(1.0 - left / Research.seconds(project), 0.0, 1.0)


func research_seconds_left(at := now()) -> float:
	if not is_researching():
		return 0.0
	return maxf(float(research_active["finish_at"]) - at, 0.0)


## Finishes the current project if its time is up; returns its id, or "".
func update_research(at := now()) -> String:
	if not is_researching() or at < float(research_active["finish_at"]):
		return ""
	var id := String(research_active["id"])
	research_done.append(id)
	research_active = {}
	return id


# --- Outposts ------------------------------------------------------------------------

## Hourly output of an outpost with no extractors (or of `outpost`, counting
## its extractors).
func outpost_rate(outpost: Dictionary = {}) -> float:
	var base := OUTPOST_RATE + EXTRACTOR_RATE * int(outpost.get("extractors", 0))
	return base * (1.0 + float(stat_bonuses().get("outpost_output", 0.0)))


## What one outpost has ready to collect.
func outpost_pending(outpost: Dictionary, at := now()) -> int:
	var hours := clampf((at - float(outpost["collected_at"])) / 3600.0, 0.0, OUTPOST_CAP_HOURS)
	return floori(hours * outpost_rate(outpost))


func pending_total(at := now()) -> Dictionary:
	var totals := {}
	for outpost in outposts:
		var amount := outpost_pending(outpost, at)
		if amount > 0:
			totals[outpost["resource"]] = int(totals.get(outpost["resource"], 0)) + amount
	return totals


## Collects everything the outposts have made; returns {resource: amount}.
func collect_outposts(at := now()) -> Dictionary:
	var totals := pending_total(at)
	for kind: String in totals:
		resources[kind] = int(resources.get(kind, 0)) + int(totals[kind])
	for outpost in outposts:
		if outpost_pending(outpost, at) > 0:
			outpost["collected_at"] = at
	return totals


# --- Runs and saving ------------------------------------------------------------------

## Banks a finished run's sparks, resources and kindled planets (kept even
## when the run is lost), feeds the Hearth, and updates the records.
## Conquests and darkness unlocks happen as hearts burn out (relight_sector).
## Returns the sparks banked.
func record_run(run: RunState, at := now()) -> int:
	var banked := run.banked_sparks()
	sparks += banked
	lifetime_sparks += banked
	hearth_xp += banked
	pilot_xp += run.pilot_xp
	for kind: String in run.resources:
		resources[kind] = int(resources.get(kind, 0)) + int(run.resources[kind])
	for outpost in run.outposts:
		var kept := outpost.duplicate()
		kept["collected_at"] = at
		outposts.append(kept)
	runs += 1
	best_regions = maxi(best_regions, run.regions_claimed)
	return banked


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "sparks": sparks, "ranks": ranks, "blueprints": blueprints,
		"runs": runs, "wins": wins, "best_regions": best_regions, "lifetime_sparks": lifetime_sparks,
		"resources": resources, "outposts": outposts, "buildings": buildings,
		"research_done": research_done, "research_active": research_active,
		"darkness": darkness, "darkness_unlocked": darkness_unlocked, "darkness_relit": darkness_relit,
		"hearth_xp": hearth_xp, "hearth_points": hearth_points,
		"galaxy_seed": galaxy_seed, "conquered": conquered, "selected_sector": selected_sector,
		"pilot_xp": pilot_xp, "pilot_points": pilot_points,
	}


static func from_dict(data: Dictionary) -> MetaProgress:
	var meta := MetaProgress.new()
	meta.sparks = int(data.get("sparks", 0))
	var saved_ranks: Dictionary = data.get("ranks", {})
	for key: String in saved_ranks:
		meta.ranks[key] = int(saved_ranks[key])
	for id: String in data.get("blueprints", []):
		meta.blueprints.append(id)
	meta.runs = int(data.get("runs", 0))
	meta.wins = int(data.get("wins", 0))
	meta.best_regions = int(data.get("best_regions", 0))
	meta.lifetime_sparks = int(data.get("lifetime_sparks", 0))
	var saved_resources: Dictionary = data.get("resources", {})
	for kind: String in saved_resources:
		meta.resources[kind] = int(saved_resources[kind])
	for outpost: Dictionary in data.get("outposts", []):
		meta.outposts.append({
			"name": String(outpost.get("name", "")), "type": String(outpost.get("type", "")),
			"resource": String(outpost.get("resource", "ore")), "collected_at": float(outpost.get("collected_at", 0.0)),
			"extractors": int(outpost.get("extractors", 0)),
		})
	for id: String in data.get("buildings", []):
		meta.buildings.append(id)
	for id: String in data.get("research_done", []):
		meta.research_done.append(id)
	var active: Dictionary = data.get("research_active", {})
	if active.has("id"):
		meta.research_active = {"id": String(active["id"]), "finish_at": float(active.get("finish_at", 0.0))}
	meta.darkness_unlocked = clampi(int(data.get("darkness_unlocked", Difficulty.DEFAULT)), Difficulty.DEFAULT, Difficulty.MAX_LEVEL)
	meta.darkness = clampi(int(data.get("darkness", Difficulty.DEFAULT)), 0, meta.darkness_unlocked)
	meta.darkness_relit = int(data.get("darkness_relit", -1))
	meta.hearth_xp = int(data.get("hearth_xp", meta.lifetime_sparks))
	var points: Dictionary = data.get("hearth_points", {})
	for key: String in points:
		meta.hearth_points[key] = int(points[key])
	meta.pilot_xp = int(data.get("pilot_xp", 0))
	var stat_points: Dictionary = data.get("pilot_points", {})
	for key: String in stat_points:
		meta.pilot_points[key] = int(stat_points[key])
	meta.galaxy_seed = int(data.get("galaxy_seed", 0))
	for id in data.get("conquered", []):
		meta.conquered.append(int(id))
	meta.selected_sector = int(data.get("selected_sector", -1))
	return meta


func save(path := SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("MetaProgress: couldn't write %s" % path)
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


## Loads the save, or returns fresh progress if there isn't one (or it's unreadable).
static func load_from(path := SAVE_PATH) -> MetaProgress:
	if not FileAccess.file_exists(path):
		return MetaProgress.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return from_dict(parsed)
	push_warning("MetaProgress: %s is unreadable, starting fresh" % path)
	return MetaProgress.new()
