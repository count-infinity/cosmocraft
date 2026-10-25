extends GutTest
## Loot picks, run setup, and permanent progression.

const TEST_SAVE := "user://test_cosmocraft_save.json"

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 12345


func after_all() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _unlocked() -> Array[String]:
	return MetaUpgrades.default_components()


# --- Loot ---------------------------------------------------------------------

func test_rolls_three_distinct_choices() -> void:
	for i in 30:
		var choices := LootPicks.roll(rng, Loadout.starter(), _unlocked(), 0, 0)
		assert_eq(choices.size(), 3, "Three choices")
		var seen := []
		for choice in choices:
			var key := "%s:%s" % [choice.kind, choice.def.id if choice.def != null else choice.hull_id]
			assert_false(seen.has(key), "No duplicates (%s)" % key)
			seen.append(key)


func test_never_offers_parts_the_hull_cannot_mount() -> void:
	var unlocked := _unlocked()
	unlocked.append("lance")
	for i in 60:
		for choice in LootPicks.roll(rng, Loadout.starter(), unlocked, 2, 0):
			if choice.kind == "component":
				assert_ne(choice.def.id, "lance", "Skiffs can't mount a lance")


func test_only_offers_unlocked_parts() -> void:
	for i in 60:
		for choice in LootPicks.roll(rng, Loadout.starter(), _unlocked(), 2, 0):
			if choice.kind == "component":
				assert_false(MetaUpgrades.BLUEPRINTS.has(choice.def.id), "%s needs a blueprint" % choice.def.id)


func test_better_regions_roll_rarer_parts() -> void:
	var plain := _rare_count(0)
	var rich := _rare_count(2)
	assert_gt(rich, plain, "Rich, deep regions offer more rare picks (%d vs %d)" % [rich, plain])


func _rare_count(quality: int) -> int:
	var count := 0
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 99
	var unlocked := _unlocked()
	unlocked.append_array(MetaUpgrades.BLUEPRINTS.keys())
	for i in 200:
		for choice in LootPicks.roll(local_rng, Loadout.starter(), unlocked, quality, 0):
			if choice.rarity == ComponentDef.Rarity.RARE:
				count += 1
	return count


func test_upgrade_choices_target_fitted_parts() -> void:
	var found := false
	for i in 40:
		var loadout := Loadout.starter()
		for choice in LootPicks.roll(rng, loadout, _unlocked(), 0, 0):
			if choice.kind == "upgrade":
				found = true
				assert_true(loadout.fitted.has(choice.target), "Upgrade points at a fitted part")
				assert_eq(choice.mark, choice.target.mark + 1, "One mark up")
	assert_true(found, "Upgrades show up")


func test_hull_refit_needs_a_few_claims_first() -> void:
	var early := 0
	var later := 0
	for i in 200:
		for choice in LootPicks.roll(rng, Loadout.starter(), _unlocked(), 0, 0):
			if choice.kind == "hull":
				early += 1
		for choice in LootPicks.roll(rng, Loadout.starter(), _unlocked(), 0, LootPicks.HULL_MIN_CLAIMS):
			if choice.kind == "hull":
				later += 1
	assert_eq(early, 0, "No refit offers right away")
	assert_gt(later, 0, "Refits show up after a few claims")


func test_applying_choices() -> void:
	var run := RunState.fresh(1)
	var component := LootPicks.Choice.new()
	component.def = ComponentLibrary.get_def("magnet_coil")
	assert_string_contains(LootPicks.apply(component, run), "fitted", "Small part gets fitted")
	assert_eq(run.loadout.fitted.size(), 3, "Now three parts")

	var upgrade := LootPicks.Choice.new()
	upgrade.kind = "upgrade"
	upgrade.target = run.loadout.fitted[0]
	upgrade.def = upgrade.target.def
	upgrade.mark = 2
	LootPicks.apply(upgrade, run)
	assert_eq(run.loadout.fitted[0].mark, 2, "Upgraded")

	var cache := LootPicks.Choice.new()
	cache.kind = "sparks"
	cache.sparks = 25
	LootPicks.apply(cache, run)
	assert_eq(run.sparks, 25, "Sparks added")

	var hull := LootPicks.Choice.new()
	hull.kind = "hull"
	hull.hull_id = "corvette"
	LootPicks.apply(hull, run)
	assert_eq(run.loadout.hull.id, "corvette", "Refitted")


func test_parts_without_room_go_to_the_hold() -> void:
	var run := RunState.fresh(1)
	var reactor := LootPicks.Choice.new()
	reactor.def = ComponentLibrary.get_def("reactor")
	assert_string_contains(LootPicks.apply(reactor, run), "fitted", "One reactor fits on a Skiff")
	assert_string_contains(LootPicks.apply(reactor, run), "hold", "No room for a second")
	assert_eq(run.loadout.hold.size(), 1, "Waiting in the hold")


# --- Runs and meta progress ------------------------------------------------------

func test_runs_start_from_unlocks() -> void:
	var meta := MetaProgress.new()
	meta.ranks = {"revive": 1, "reroll": 2, "hull": 2, "corvette": 1}
	var run := RunState.create(5, meta)
	assert_eq(run.revives_left, 1, "Spare sparks")
	assert_eq(run.free_rerolls, 2, "Free rerolls")
	assert_eq(run.loadout.hull.id, "corvette", "Corvette unlocked")
	assert_almost_eq(float(run.bonuses["max_hull"]), 30.0, 0.001, "Two ranks of hull")


func test_victory_banks_a_bonus() -> void:
	var run := RunState.fresh(1)
	run.sparks = 100
	run.outcome = RunState.Outcome.DEFEAT
	assert_eq(run.banked_sparks(), 100, "Defeat keeps everything")
	run.outcome = RunState.Outcome.VICTORY
	assert_eq(run.banked_sparks(), 125, "Victory adds 25%")


func test_buying_upgrades() -> void:
	var meta := MetaProgress.new()
	meta.sparks = 100
	assert_eq(meta.next_cost("magnet"), 30, "First rank")
	assert_true(meta.buy("magnet"), "Bought")
	assert_eq(meta.sparks, 70, "Paid")
	assert_eq(meta.next_cost("magnet"), 60, "Second rank costs more")
	assert_true(meta.buy("magnet"), "Bought again")
	assert_false(meta.buy("magnet"), "Can't afford a third")
	assert_almost_eq(float(meta.stat_bonuses()["magnet"]), 40.0, 0.001, "Two ranks of magnet")


func test_upgrades_stop_at_max_rank() -> void:
	var meta := MetaProgress.new()
	meta.sparks = 100000
	for i in 10:
		meta.buy("engines")
	assert_eq(meta.rank("engines"), 3, "Engines cap at 3")
	assert_true(meta.is_maxed("engines"), "Maxed")


func test_blueprints_unlock_parts() -> void:
	var meta := MetaProgress.new()
	meta.sparks = 500
	assert_false(meta.unlocked_components().has("lance"), "Locked at first")
	assert_true(meta.buy_blueprint("lance"), "Bought the blueprint")
	assert_true(meta.unlocked_components().has("lance"), "Now in the pool")
	assert_false(meta.buy_blueprint("lance"), "Can't buy it twice")
	assert_false(meta.buy_blueprint("pulse_laser"), "Default parts have no blueprint")


func test_recording_runs() -> void:
	var meta := MetaProgress.new()
	var run := RunState.fresh(1)
	run.sparks = 80
	run.regions_claimed = 6
	run.outcome = RunState.Outcome.VICTORY
	assert_eq(meta.record_run(run), 100, "Banked with the victory bonus")
	assert_eq(meta.sparks, 100, "In the bank")
	assert_eq(meta.best_regions, 6, "Best run recorded")


func test_save_and_load_round_trip() -> void:
	var meta := MetaProgress.new()
	meta.sparks = 321
	meta.ranks = {"hull": 2, "magnet": 1}
	meta.blueprints.append("lance")
	meta.runs = 4
	assert_true(meta.save(TEST_SAVE), "Saved")
	var loaded := MetaProgress.load_from(TEST_SAVE)
	assert_eq(loaded.sparks, 321, "Sparks")
	assert_eq(loaded.rank("hull"), 2, "Ranks")
	assert_true(loaded.blueprints.has("lance"), "Blueprints")
	assert_eq(loaded.runs, 4, "Records")


func test_missing_save_starts_fresh() -> void:
	var meta := MetaProgress.load_from("user://does_not_exist.json")
	assert_eq(meta.sparks, 0, "Fresh progress")
