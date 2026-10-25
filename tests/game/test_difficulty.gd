extends GutTest
## Darkness levels (difficulty you can step up or down) and Hearth levels
## (endless paragon-style progression).


func test_darker_levels_are_harder_and_pay_more() -> void:
	for level in range(1, 10):
		var lighter := Difficulty.level(level - 1)
		var darker := Difficulty.level(level)
		assert_gt(float(darker["health"]), float(lighter["health"]), "Level %d: tougher Gloom" % level)
		assert_gte(float(darker["damage"]), float(lighter["damage"]), "Level %d: hits as hard or harder" % level)
		assert_gt(float(darker["reward"]), float(lighter["reward"]), "Level %d: better rewards" % level)
	assert_lt(float(Difficulty.level(0)["reward"]), 1.0, "Twilight pays less")
	assert_eq(Difficulty.name_of(Difficulty.DEFAULT), "Dusk", "Runs start on Dusk")
	assert_eq(Difficulty.name_of(5), "Void I", "Past Eclipse the Void levels begin")
	assert_eq(Difficulty.name_of(7), "Void III", "And keep climbing")


func test_sparks_are_banked_at_the_darkness_reward_rate() -> void:
	var run := RunState.fresh(1)
	run.darkness = 0
	run.add_sparks(10)
	assert_eq(run.sparks, 6, "Twilight pays 60%")
	run.darkness_max = 2
	run.set_darkness(2)
	run.add_sparks(10)
	assert_eq(run.sparks, 22, "Nightfall pays 160%")
	run.add_sparks(1)
	run.add_sparks(1)
	assert_eq(run.sparks, 25, "Fractions carry over")


func test_runs_cannot_go_darker_than_unlocked() -> void:
	var run := RunState.fresh(1)
	assert_false(run.set_darkness(2), "Nightfall isn't unlocked yet")
	assert_true(run.set_darkness(0), "Twilight always is")


func test_relighting_on_the_darkest_level_unlocks_the_next() -> void:
	var meta := MetaProgress.new()
	meta.galaxy_seed = 5
	var news := meta.relight_sector(-1, Difficulty.DEFAULT)
	assert_eq(meta.darkness_unlocked, 2, "Nightfall unlocked")
	assert_eq(int(news["unlocked"]), 2, "And announced")
	assert_eq(meta.newly_unlocked, 2, "And remembered for the Hearth")
	assert_eq(meta.darkness_relit, 1, "Dusk relit")
	assert_eq(meta.wins, 1, "A win")
	meta.relight_sector(-1, 0)
	assert_eq(meta.darkness_unlocked, 2, "A win on a lighter level unlocks nothing new")
	var lost := RunState.create(3, meta)
	lost.darkness = 2
	lost.outcome = RunState.Outcome.DEFEAT
	meta.record_run(lost, 0.0)
	assert_eq(meta.darkness_unlocked, 2, "Nor does a loss")


func test_banked_sparks_raise_the_hearth() -> void:
	var meta := MetaProgress.new()
	assert_eq(meta.hearth_level(), 0, "A cold hearth to start")
	var run := RunState.fresh(1)
	run.sparks = HearthRanks.xp_to_next(0) + HearthRanks.xp_to_next(1) + 5
	run.outcome = RunState.Outcome.DEFEAT
	meta.record_run(run, 0.0)
	assert_eq(meta.hearth_level(), 2, "Two levels from one good run")
	assert_eq(HearthRanks.progress_for(meta.hearth_xp), Vector2i(5, HearthRanks.xp_to_next(2)), "Partway to the third")


func test_hearth_points_become_bonuses() -> void:
	var meta := MetaProgress.new()
	meta.hearth_xp = 100000
	for i in 10:
		assert_true(meta.spend_hearth_point("weapons"), "Searing Light never caps")
	assert_almost_eq(float(meta.stat_bonuses()["damage"]), 0.1, 0.0001, "+10% damage")
	for i in 40:
		meta.spend_hearth_point("kindling")
	assert_false(meta.spend_hearth_point("kindling"), "Quick Flame caps at 40")
	assert_false(meta.spend_hearth_point("nonsense"), "Unknown tracks are ignored")


func test_darkness_raises_loot_gear_levels() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var above_mk1 := 0
	var total := 0
	for i in 60:
		for choice in LootPicks.roll(rng, Loadout.starter(), MetaUpgrades.default_components(), 2, 0, 3, 3):
			if choice.kind == "component":
				total += 1
				if choice.mark > 1:
					above_mk1 += 1
	assert_gt(total, 0, "Some new parts were offered")
	assert_gt(float(above_mk1) / total, 0.8, "Deep in the Void, new parts mostly arrive at Mk II or III")
	for choice in LootPicks.roll(rng, Loadout.starter(), MetaUpgrades.default_components(), 0, 0, 3, 0):
		if choice.kind == "component":
			assert_eq(choice.mark, 1, "On Dusk they arrive at Mk I")


func test_darkness_and_the_hearth_survive_a_save() -> void:
	var meta := MetaProgress.new()
	meta.darkness_unlocked = 4
	meta.darkness = 3
	meta.darkness_relit = 3
	meta.hearth_xp = 777
	meta.hearth_points = {"hull": 2}
	var loaded := MetaProgress.from_dict(JSON.parse_string(JSON.stringify(meta.to_dict())))
	assert_eq(loaded.darkness_unlocked, 4, "Unlocked levels")
	assert_eq(loaded.darkness, 3, "Picked level")
	assert_eq(loaded.darkness_relit, 3, "Darkest relit")
	assert_eq(loaded.hearth_xp, 777, "Hearth experience")
	assert_eq(int(loaded.hearth_points["hull"]), 2, "Hearth points")
	var old := MetaProgress.from_dict({"version": 1, "sparks": 10, "lifetime_sparks": 900})
	assert_eq(old.hearth_xp, 900, "Old saves light the Hearth from their lifetime sparks")
	assert_eq(old.darkness, Difficulty.DEFAULT, "And start on Dusk")
