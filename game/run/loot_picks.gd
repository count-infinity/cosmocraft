class_name LootPicks
extends RefCounted
## Rolls the "pick one of three" rewards offered after a region ignites:
## new parts, Mk upgrades for parts already fitted, a hull refit, or a cache
## of sparks. Richer and deeper regions roll rarer picks, and darker
## difficulty levels roll rarer still, with new parts arriving at a higher Mk
## (their "gear level").

## Odds of common / uncommon / rare by quality (region quality 0-2, plus up
## to 2 more from the darkness).
const RARITY_WEIGHTS := [
	[60.0, 30.0, 10.0],
	[35.0, 45.0, 20.0],
	[15.0, 50.0, 35.0],
	[5.0, 45.0, 50.0],
	[0.0, 35.0, 65.0],
]
## Chance of a new part arriving at Mk II and at Mk III, by gear level.
const GEAR_MARKS := [
	[0.0, 0.0],
	[0.35, 0.0],
	[0.65, 0.15],
	[0.5, 0.45],
]
const UPGRADE_CHANCE := 0.3
const HULL_CHANCE := 0.15
const SPARK_CACHE := 25
const REROLL_COST := 15
## Claims needed before a Corvette refit can be offered.
const HULL_MIN_CLAIMS := 3


class Choice:
	var kind := "component"
	var def: ComponentDef
	var mark := 1
	var target: Loadout.Fitted
	var hull_id := ""
	var sparks := 0
	var rarity := ComponentDef.Rarity.COMMON

	func title() -> String:
		match kind:
			"upgrade":
				return "%s Mk %s" % [def.display_name, "I".repeat(mark)]
			"hull":
				return "Corvette Refit"
			"sparks":
				return "Spark Cache"
		return def.display_name + (" Mk %s" % "I".repeat(mark) if mark > 1 else "")

	func description() -> String:
		match kind:
			"upgrade":
				return "Upgrade your fitted %s to Mk %s." % [def.display_name, "I".repeat(mark)]
			"hull":
				return "Move to a Corvette hull: a bigger grid, five hardpoints, more power."
			"sparks":
				return "+%d sparks." % sparks
		return def.description


## How good a region's rewards are: rich and deep regions roll better. Add
## the darkness's "quality" on top.
static func quality_for(region: RegionData) -> int:
	var quality := 0
	if region.modifier == RegionData.Modifier.RICH:
		quality += 1
	if region.depth >= 3:
		quality += 1
	return clampi(quality, 0, RARITY_WEIGHTS.size() - 1)


## `gear` (from the darkness) is how likely new parts are to arrive above Mk I.
static func roll(rng: RandomNumberGenerator, loadout: Loadout, unlocked: Array[String], quality: int, claims: int, count := 3, gear := 0) -> Array[Choice]:
	var choices: Array[Choice] = []
	var upgradable: Array[Loadout.Fitted] = []
	for item in loadout.fitted:
		if item.mark < ComponentDef.MAX_MARK:
			upgradable.append(item)
	var hull_offered := false
	for slot in count:
		var rarity := _roll_rarity(rng, quality)
		var choice: Choice = null
		var roll_value := rng.randf()
		if not hull_offered and loadout.hull.hull_class == 1 and claims >= HULL_MIN_CLAIMS and roll_value < HULL_CHANCE:
			choice = Choice.new()
			choice.kind = "hull"
			choice.hull_id = "corvette"
			choice.rarity = ComponentDef.Rarity.RARE
			hull_offered = true
		elif roll_value < HULL_CHANCE + UPGRADE_CHANCE:
			choice = _upgrade_choice(rng, upgradable, choices)
		if choice == null:
			choice = _component_choice(rng, loadout, unlocked, rarity, choices)
			if choice != null:
				choice.mark = _roll_mark(rng, gear)
		if choice == null:
			choice = Choice.new()
			choice.kind = "sparks"
			choice.sparks = SPARK_CACHE * (clampi(quality, 0, 2) + 1)
		choices.append(choice)
	return choices


## Applies a picked reward. New parts are fitted automatically if there's
## room, otherwise they wait in the hold. Returns a short note for the HUD.
static func apply(choice: Choice, run: RunState) -> String:
	match choice.kind:
		"upgrade":
			if run.loadout.fitted.has(choice.target):
				choice.target.mark = choice.mark
				return "%s upgraded" % choice.title()
			return "That part is no longer fitted"
		"hull":
			run.loadout.change_hull(HullDef.by_id(choice.hull_id))
			return "Refitted to a Corvette" + (" (some parts went to the hold)" if not run.loadout.hold.is_empty() else "")
		"sparks":
			return "+%d sparks" % run.add_sparks(choice.sparks)
	if run.loadout.auto_fit(choice.def, choice.mark) != null:
		return "%s fitted" % choice.title()
	run.loadout.stow(choice.def, choice.mark)
	return "%s is in your hold. Press F in your territory to fit it" % choice.title()


static func _roll_rarity(rng: RandomNumberGenerator, quality: int) -> ComponentDef.Rarity:
	var weights: Array = RARITY_WEIGHTS[clampi(quality, 0, RARITY_WEIGHTS.size() - 1)]
	var roll_value := rng.randf() * (float(weights[0]) + float(weights[1]) + float(weights[2]))
	if roll_value < float(weights[0]):
		return ComponentDef.Rarity.COMMON
	if roll_value < float(weights[0]) + float(weights[1]):
		return ComponentDef.Rarity.UNCOMMON
	return ComponentDef.Rarity.RARE


static func _roll_mark(rng: RandomNumberGenerator, gear: int) -> int:
	var odds: Array = GEAR_MARKS[clampi(gear, 0, GEAR_MARKS.size() - 1)]
	var roll_value := rng.randf()
	if roll_value < float(odds[1]):
		return mini(3, ComponentDef.MAX_MARK)
	if roll_value < float(odds[1]) + float(odds[0]):
		return mini(2, ComponentDef.MAX_MARK)
	return 1


static func _upgrade_choice(rng: RandomNumberGenerator, upgradable: Array[Loadout.Fitted], taken: Array[Choice]) -> Choice:
	var options: Array[Loadout.Fitted] = []
	for item in upgradable:
		var already := false
		for choice in taken:
			if choice.target == item:
				already = true
		if not already:
			options.append(item)
	if options.is_empty():
		return null
	var item := options[rng.randi() % options.size()]
	var choice := Choice.new()
	choice.kind = "upgrade"
	choice.def = item.def
	choice.target = item
	choice.mark = item.mark + 1
	choice.rarity = ComponentDef.Rarity.UNCOMMON if choice.mark == 2 else ComponentDef.Rarity.RARE
	return choice


## A new part of the rolled rarity, falling back to other rarities if none fit.
static func _component_choice(rng: RandomNumberGenerator, loadout: Loadout, unlocked: Array[String], rarity: ComponentDef.Rarity, taken: Array[Choice]) -> Choice:
	var pool: Array[ComponentDef] = []
	for id in unlocked:
		var def := ComponentLibrary.get_def(id)
		if def == null or def.min_hull_class > loadout.hull.hull_class:
			continue
		var already := false
		for choice in taken:
			if choice.kind == "component" and choice.def == def:
				already = true
		if not already:
			pool.append(def)
	if pool.is_empty():
		return null
	for tier in [rarity, ComponentDef.Rarity.UNCOMMON, ComponentDef.Rarity.COMMON, ComponentDef.Rarity.RARE]:
		var matching: Array[ComponentDef] = []
		for def in pool:
			if def.rarity == tier:
				matching.append(def)
		if not matching.is_empty():
			var choice := Choice.new()
			choice.def = matching[rng.randi() % matching.size()]
			choice.rarity = choice.def.rarity
			return choice
	return null
