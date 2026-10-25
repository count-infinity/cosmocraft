extends GutTest
## The persistent layer: banking resources and outposts, the Lab and its
## research clock, outpost production, saving, and the homeworld hub.

const HOUR := 3600.0

var meta: MetaProgress


func before_each() -> void:
	meta = MetaProgress.new()


func _finished_run(outcome := RunState.Outcome.DEFEAT) -> RunState:
	var run := RunState.fresh(1)
	run.outcome = outcome
	run.sparks = 100
	run.add_resource("crystal", 40)
	run.outposts.append({"name": "Brand VII", "type": "Crystal", "resource": "crystal"})
	return run


func test_runs_bank_resources_and_outposts_even_when_lost() -> void:
	meta.record_run(_finished_run(), 1000.0)
	assert_eq(int(meta.resources["crystal"]), 40, "Resources banked")
	assert_eq(meta.outposts.size(), 1, "Outpost kept")
	assert_eq(float(meta.outposts[0]["collected_at"]), 1000.0, "Starts producing from now")


func test_outposts_produce_over_time_up_to_a_cap() -> void:
	meta.record_run(_finished_run(), 0.0)
	assert_eq(meta.outpost_pending(meta.outposts[0], 0.5 * HOUR), 3, "Half an hour of crystal")
	assert_eq(meta.outpost_pending(meta.outposts[0], 100.0 * HOUR), int(MetaProgress.OUTPOST_RATE * MetaProgress.OUTPOST_CAP_HOURS), "Capped")
	var collected := meta.collect_outposts(2.0 * HOUR)
	assert_eq(int(collected["crystal"]), 12, "Two hours collected")
	assert_eq(int(meta.resources["crystal"]), 52, "Added to the stockpile")
	assert_eq(meta.outpost_pending(meta.outposts[0], 2.0 * HOUR), 0, "Nothing left right after collecting")


func test_the_lab_is_built_with_sparks() -> void:
	assert_false(meta.can_start_research("ember_coils"), "No lab yet")
	meta.sparks = Research.LAB_COST - 1
	assert_false(meta.build_lab(), "Not enough sparks")
	meta.sparks = Research.LAB_COST
	assert_true(meta.build_lab(), "Built")
	assert_eq(meta.sparks, 0, "Paid for")
	assert_true(meta.has_building("lab"), "Standing")


func test_research_costs_resources_and_takes_real_time() -> void:
	meta.buildings.append("lab")
	assert_false(meta.start_research("ember_coils", 0.0), "Can't afford it yet")
	meta.resources["ore"] = 25
	assert_true(meta.start_research("ember_coils", 0.0), "Started")
	assert_eq(int(meta.resources["ore"]), 5, "Ore spent")
	assert_false(meta.can_start_research("field_rations"), "One project at a time")
	assert_almost_eq(meta.research_progress(90.0), 0.5, 0.01, "Halfway after 90 seconds")
	assert_eq(meta.update_research(100.0), "", "Not done yet")
	assert_eq(meta.update_research(200.0), "ember_coils", "Done")
	assert_almost_eq(float(meta.stat_bonuses()["claim_speed"]), 0.1, 0.0001, "Claims fill faster from now on")


func test_research_can_give_every_run_a_starting_part() -> void:
	meta.research_done.append("heavy_kindler")
	var run := RunState.create(5, meta)
	var found := false
	for item in run.loadout.fitted:
		if item.def.id == "kindler_array":
			found = true
	for item in run.loadout.hold:
		if item.def.id == "kindler_array":
			found = true
	assert_true(found, "The Kindler Array comes along")


func test_pilot_research_reaches_the_surface() -> void:
	meta.research_done.append("field_rations")
	meta.research_done.append("flare_satchel")
	var run := RunState.create(5, meta)
	var planet := PlanetData.new()
	planet.name = "Test"
	planet.surface_seed = 99
	var mission := SurfaceMission.new()
	mission.setup(run, planet, SpaceTuning.new())
	add_child_autofree(mission)
	assert_eq(mission.pilot.max_health, mission.tuning.pilot_health + 30.0, "Tougher pilot")
	assert_eq(mission.weapons.ammo_status().y, 3, "Three flares")


func test_progress_survives_a_save() -> void:
	meta.sparks = 77
	meta.resources["biomass"] = 12
	meta.buildings.append("lab")
	meta.research_done.append("lantern_lens")
	meta.research_active = {"id": "ember_coils", "finish_at": 1234.5}
	meta.record_run(_finished_run(), 50.0)
	var path := "user://test_meta_roundtrip.json"
	assert_true(meta.save(path), "Saved")
	var loaded := MetaProgress.load_from(path)
	assert_eq(loaded.sparks, meta.sparks, "Sparks")
	assert_eq(int(loaded.resources["biomass"]), 12, "Resources")
	assert_eq(int(loaded.resources["crystal"]), 40, "Banked resources")
	assert_true(loaded.has_building("lab"), "Buildings")
	assert_eq(loaded.research_done, meta.research_done, "Finished research")
	assert_eq(String(loaded.research_active["id"]), "ember_coils", "Research in progress")
	assert_eq(loaded.outposts.size(), 1, "Outposts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_old_saves_still_load() -> void:
	var old := MetaProgress.from_dict({"version": 1, "sparks": 300, "ranks": {"hull": 2}, "runs": 4})
	assert_eq(old.sparks, 300, "Sparks kept")
	assert_eq(old.rank("hull"), 2, "Ranks kept")
	assert_eq(int(old.resources["ore"]), 0, "No resources yet")
	assert_true(old.outposts.is_empty(), "No outposts yet")


# --- The homeworld hub ---------------------------------------------------------------

func _home(last_run: RunState = null) -> Homeworld:
	var home := Homeworld.new()
	home.setup(meta, last_run, 120)
	add_child_autofree(home)
	return home


func test_coming_home_opens_the_hearth_report() -> void:
	var home := _home(_finished_run())
	assert_true(home.panel.visible, "A panel is up")
	assert_eq(home.panel.page, "hearth", "The Hearth's run report")


func test_walking_up_to_a_building_lets_you_use_it() -> void:
	var home := _home()
	home.pilot.position = Homeworld.BUILDINGS["shipyard"]["position"] + Vector2(120.0, 0.0)
	assert_eq(home.nearest_building(), "shipyard", "In reach of the Shipyard")
	home.use("shipyard")
	assert_eq(home.panel.page, "shipyard", "Its panel opened")
	home.pilot.position = Vector2(560.0, 280.0)
	assert_eq(home.nearest_building(), "", "Nothing in reach out by the rocks")


func test_the_launch_pad_picks_the_darkness_and_launches() -> void:
	var home := _home()
	meta.darkness_unlocked = 2
	home.use("pad")
	assert_eq(home.panel.page, "launch", "The pad opens the launch window")
	home.panel.press("darkness:2")
	assert_eq(meta.darkness, 2, "Picked Nightfall")
	home.panel.press("darkness:3")
	assert_eq(meta.darkness, 2, "Midnight is still locked")
	watch_signals(home)
	home.panel.press("launch")
	assert_signal_emitted(home, "launch_requested", "Off to the next sector")


func test_hearth_points_are_spent_at_the_hearth() -> void:
	var home := _home()
	meta.hearth_xp = HearthRanks.xp_to_next(0) + HearthRanks.xp_to_next(1)
	home.use("hearth")
	home.panel.press("hearth:weapons")
	home.panel.press("hearth:hull")
	home.panel.press("hearth:hull")
	assert_eq(int(meta.hearth_points.get("weapons", 0)), 1, "One point in weapons")
	assert_eq(int(meta.hearth_points.get("hull", 0)), 1, "Only two points to spend")
	home.panel.press("hearth_reset")
	assert_eq(meta.hearth_points_free(), 2, "Reset gives them back")


func test_building_the_lab_from_its_panel() -> void:
	var home := _home()
	meta.sparks = Research.LAB_COST + 10
	home.use("lab")
	watch_signals(home)
	home.panel.press("build_lab")
	assert_true(meta.has_building("lab"), "Built")
	assert_signal_emitted(home, "changed", "GameFlow gets told to save")
	meta.resources["ore"] = 20
	home.panel.press("research:ember_coils")
	assert_true(meta.is_researching(), "Research started from the panel")


func test_the_relay_collects_what_outposts_mined() -> void:
	var home := _home()
	meta.outposts.append({"name": "Kiln I", "type": "Fungal", "resource": "biomass", "collected_at": MetaProgress.now() - 3.0 * HOUR})
	home.use("relay")
	home.panel.press("collect")
	assert_eq(int(meta.resources["biomass"]), int(3.0 * MetaProgress.OUTPOST_RATE), "Three hours of biomass")



# --- The pilot ------------------------------------------------------------------------

func test_pilot_experience_levels_up_and_banks_at_the_end_of_a_run() -> void:
	var run := RunState.create(1, meta)
	assert_false(run.add_pilot_xp(10), "Not a level yet")
	assert_true(run.add_pilot_xp(PilotRanks.FIRST_LEVEL_XP), "Level 1 reached mid-run")
	assert_eq(run.pilot_level(), 1, "Level 1")
	run.outcome = RunState.Outcome.DEFEAT
	meta.record_run(run, 0.0)
	assert_eq(meta.pilot_level(), 1, "Kept after the run, win or lose")
	assert_eq(meta.pilot_points_free(), 1, "A point to spend")


func test_pilot_points_become_pilot_stats() -> void:
	meta.pilot_xp = 100000
	assert_true(meta.spend_pilot_point("vitality"), "Vitality")
	assert_true(meta.spend_pilot_point("aim"), "Aim")
	var bonuses := meta.stat_bonuses()
	assert_eq(float(bonuses["pilot_health"]), 12.0, "+12 health")
	assert_almost_eq(float(bonuses["sidearm_damage"]), 0.06, 0.0001, "+6% sidearm damage")
	for i in 20:
		meta.spend_pilot_point("agility")
	assert_false(meta.spend_pilot_point("agility"), "Agility caps at 20")
	meta.reset_pilot_points()
	assert_true(meta.pilot_points.is_empty(), "Reset for free")


func test_the_quarters_spend_pilot_points() -> void:
	var home := _home()
	meta.pilot_xp = PilotRanks.FIRST_LEVEL_XP
	home.use("quarters")
	assert_eq(home.panel.page, "quarters", "The Quarters open the pilot sheet")
	home.panel.press("pilot:lantern")
	assert_eq(int(meta.pilot_points.get("lantern", 0)), 1, "Point spent")


func test_extractors_make_an_outpost_mine_faster() -> void:
	meta.outposts.append({"name": "Kiln I", "type": "Fungal", "resource": "biomass", "collected_at": 0.0, "extractors": 2})
	var expected := int((MetaProgress.OUTPOST_RATE + 2.0 * MetaProgress.EXTRACTOR_RATE) * 2.0)
	assert_eq(meta.outpost_pending(meta.outposts[0], 2.0 * HOUR), expected, "Two hours with two extractors")
	var loaded := MetaProgress.from_dict(JSON.parse_string(JSON.stringify(meta.to_dict())))
	assert_eq(int(loaded.outposts[0]["extractors"]), 2, "Extractors are saved")
	meta.pilot_xp = 321
	loaded = MetaProgress.from_dict(JSON.parse_string(JSON.stringify(meta.to_dict())))
	assert_eq(loaded.pilot_xp, 321, "Pilot experience is saved")
