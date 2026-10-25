class_name RunState
extends RefCounted
## One run: the sector being crossed, the ship built along the way, and what
## it has earned so far. A run ends when the heart burns out, the ship is lost
## with no spare sparks left, or the player abandons it.

enum Outcome { IN_PROGRESS, VICTORY, DEFEAT, ABANDONED }

## Extra sparks banked for burning out the heart.
const VICTORY_BONUS := 0.25

var sector_seed := 0
var loadout: Loadout
## Permanent upgrade bonuses, in Loadout.compute_stats keys.
var bonuses: Dictionary = {}
## Parts allowed in loot picks.
var unlocked: Array[String] = []
var sparks := 0
## Planet resources gathered this run: ore, crystal, biomass.
var resources := {"ore": 0, "crystal": 0, "biomass": 0}
## Planets kindled this run, each {"name", "type", "resource"}; they become
## permanent outposts.
var outposts: Array[Dictionary] = []
var kills := 0
var regions_claimed := 0
var elapsed := 0.0
var revives_left := 0
var free_rerolls := 0
var outcome := Outcome.IN_PROGRESS
## How dark this run is (a Difficulty level). It can change between fights,
## up to darkness_max.
var darkness := Difficulty.DEFAULT
var darkness_max := Difficulty.DEFAULT
## The galaxy sector being invaded (-1 for a practice run), how far it is from
## home, and its system's theme for the generator.
var sector_id := -1
var sector_tier := 1
var sector_name := ""
var sector_theme: Dictionary = {}
## Sectors this run has conquered (a run can push on through several).
var sectors_conquered: Array[int] = []
## Extra rewards from conquered systems.
var reward_bonus := 0.0
## Pilot experience earned this run, and what the pilot had at launch (to
## spot level-ups on a planet).
var pilot_xp := 0
var pilot_xp_start := 0

var _spark_carry := 0.0


## A run set up from what's been unlocked so far.
static func create(seed_value: int, meta: MetaProgress) -> RunState:
	var run := RunState.new()
	run.sector_seed = seed_value
	run.loadout = Loadout.starter()
	var hull := meta.starting_hull()
	if hull.id != run.loadout.hull.id:
		run.loadout.change_hull(hull)
	run.bonuses = meta.stat_bonuses()
	for id in meta.start_parts():
		var def := ComponentLibrary.get_def(id)
		if def != null and run.loadout.auto_fit(def) == null:
			run.loadout.stow(def)
	run.unlocked = meta.unlocked_components()
	run.revives_left = meta.rank("revive")
	run.free_rerolls = meta.rank("reroll")
	run.pilot_xp_start = meta.pilot_xp
	run.darkness_max = meta.darkness_unlocked
	run.darkness = clampi(meta.darkness, 0, run.darkness_max)
	return run


## A practice run with nothing unlocked (used when SpaceGame runs on its own).
static func fresh(seed_value: int) -> RunState:
	return create(seed_value, MetaProgress.new())


func add_resource(resource: String, amount: int) -> void:
	resources[resource] = int(resources.get(resource, 0)) + amount


func difficulty() -> Dictionary:
	return Difficulty.for_sector(darkness, sector_tier, reward_bonus)


## Points the run at a galaxy sector (at launch, or pushing on after a heart).
func enter_sector(galaxy: GalaxyData, id: int) -> void:
	var sector := galaxy.get_sector(id)
	sector_id = id
	sector_seed = sector.sector_seed
	sector_tier = maxi(sector.tier, 1)
	sector_name = sector.name
	sector_theme = galaxy.system_of(id).theme


## Adds collected sparks at this darkness's reward rate (fractions carry over).
## Returns how many were actually added.
func add_sparks(count: int) -> int:
	_spark_carry += count * float(difficulty()["reward"])
	var whole := floori(_spark_carry)
	_spark_carry -= whole
	sparks += whole
	return whole


func pilot_level() -> int:
	return PilotRanks.level_for(pilot_xp_start + pilot_xp)


## Adds pilot experience at this darkness's reward rate. Returns true if the
## pilot just reached a new level.
func add_pilot_xp(amount: int) -> bool:
	var before := pilot_level()
	pilot_xp += maxi(roundi(amount * float(difficulty()["reward"])), 1)
	return pilot_level() > before


## Steps to another unlocked darkness. Returns false if it's out of reach.
func set_darkness(level: int) -> bool:
	if level < 0 or level > darkness_max or level == darkness:
		return false
	darkness = level
	return true


func is_over() -> bool:
	return outcome != Outcome.IN_PROGRESS


func banked_sparks() -> int:
	if outcome == Outcome.VICTORY:
		return int(round(sparks * (1.0 + VICTORY_BONUS)))
	return sparks
