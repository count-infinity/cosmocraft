extends GutTest
## Planet surfaces: map generation and the mission flow (explore, siege,
## kindle, lift off), driven headlessly.

const FRAME := 1.0 / 60.0

var mission: SurfaceMission


func _planet(type := PlanetData.Type.ASHEN, depth := 2, seed_value := 1234) -> PlanetData:
	var planet := PlanetData.new()
	planet.id = 0
	planet.name = "Test World"
	planet.type = type
	planet.depth = depth
	planet.surface_seed = seed_value
	return planet


func _start_mission(planet: PlanetData = null) -> void:
	mission = SurfaceMission.new()
	mission.setup(RunState.fresh(1), planet if planet != null else _planet(), SpaceTuning.new())
	add_child_autofree(mission)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		mission._step(FRAME)
		elapsed += FRAME


# --- Map generation -----------------------------------------------------------------

func test_the_same_seed_makes_the_same_map() -> void:
	var a := SurfaceMap.generate(77, PlanetData.Type.FROST, 2)
	var b := SurfaceMap.generate(77, PlanetData.Type.FROST, 2)
	assert_eq(a.rocks.size(), b.rocks.size(), "Same rocks")
	assert_eq(a.landing, b.landing, "Same landing zone")
	assert_eq(a.vein, b.vein, "Same vein")
	assert_eq(a.deposits.size(), b.deposits.size(), "Same deposits")
	for i in a.deposits.size():
		assert_eq(a.deposits[i].position, b.deposits[i].position, "Deposit %d in the same place" % i)


func test_there_is_always_a_walkable_route_to_the_vein() -> void:
	for seed_value in range(1, 13):
		var map := SurfaceMap.generate(seed_value * 7919, seed_value % 6 as PlanetData.Type, 1 + seed_value % 4)
		assert_false(map.route.is_empty(), "Seed %d has a route" % seed_value)
		if not map.route.is_empty():
			assert_lt(map.route[-1].distance_to(map.vein), SurfaceMap.CELL * 1.5, "Seed %d's route ends at the vein" % seed_value)


func test_the_landing_zone_and_vein_arena_are_clear() -> void:
	for seed_value in [3, 30, 300]:
		var map := SurfaceMap.generate(seed_value, PlanetData.Type.MAGMA, 3)
		assert_eq(map.rock_push(map.landing, 200.0), Vector2.ZERO, "Nothing blocks the lander")
		assert_eq(map.rock_push(map.vein, 330.0), Vector2.ZERO, "The siege arena is open")


func test_everything_placed_can_be_reached() -> void:
	var map := SurfaceMap.generate(4242, PlanetData.Type.VERDANT, 3)
	for deposit in map.deposits:
		assert_false(map.find_path(map.landing, deposit.position).is_empty(), "Deposit reachable")
	for cache in map.caches:
		assert_false(map.find_path(map.landing, cache.position).is_empty(), "Cache reachable")
	for nest in map.nests:
		assert_false(map.find_path(map.landing, nest).is_empty(), "Nest reachable")


func test_deeper_planets_have_more_nests_and_packs() -> void:
	var shallow := SurfaceMap.generate(99, PlanetData.Type.FUNGAL, 1)
	var deep := SurfaceMap.generate(99, PlanetData.Type.FUNGAL, 4)
	assert_eq(shallow.nests.size(), 4, "Depth 1: four nests")
	assert_eq(deep.nests.size(), 6, "Depth 4: six nests")
	assert_gt(deep.packs.size(), shallow.packs.size(), "More sleeping packs deeper in")


func test_maps_have_deposits_caches_and_hazards() -> void:
	var map := SurfaceMap.generate(555, PlanetData.Type.CRYSTAL, 2)
	assert_between(map.deposits.size(), 6, 10, "Deposits to break")
	assert_between(map.caches.size(), 2, 3, "Caches to find")
	assert_between(map.hazards.size(), 3, 7, "Hazard pools")
	for nest in map.nests:
		assert_gt(nest.distance_to(map.landing), 1000.0, "Nests keep away from the lander")


# --- Mission flow ------------------------------------------------------------------

func test_the_pilot_lands_next_to_the_lander() -> void:
	_start_mission()
	assert_eq(mission.phase, SurfaceMission.Phase.EXPLORE, "Exploring")
	assert_lt(mission.pilot.position.distance_to(mission.map.landing), SurfaceMission.LANDER_RADIUS, "At the lander")
	var expected := mission.map.nests.size()
	for pack in mission.map.packs:
		expected += int(pack["count"])
	assert_eq(mission.battle.enemies.size(), expected, "Nests and sleeping packs are out there")
	assert_eq(mission.weapons.mounts.size(), 2, "Sidearm and flares")


func test_breaking_a_deposit_drops_its_resource() -> void:
	_start_mission()
	var deposit: SurfaceMap.Deposit = mission.map.deposits[0]
	mission._hit_deposit(deposit, deposit.hp + 1.0, deposit.position)
	assert_false(deposit.is_intact(), "Broken")
	assert_eq(mission._pickups.count(mission.resource()), deposit.shards, "Shards dropped")
	mission.pilot.position = deposit.position
	_step(1.5)
	assert_eq(int(mission.run.resources[mission.resource()]), deposit.shards, "Picked up into the run")
	assert_eq(mission.haul, deposit.shards, "Counted toward this planet's haul")


func test_caches_open_when_touched() -> void:
	_start_mission()
	var cache: SurfaceMap.Cache = mission.map.caches[0]
	mission.pilot.position = cache.position
	_step(0.1)
	assert_true(cache.opened, "Opened")


func test_sleeping_gloom_wakes_when_the_pilot_comes_close() -> void:
	_start_mission()
	var sleeper: GloomEnemy = null
	for enemy in mission.battle.enemies:
		if enemy.dormant:
			sleeper = enemy
			break
	assert_not_null(sleeper, "There's a sleeping pack")
	mission.battle.god_mode = true
	mission.pilot.position = sleeper.position + Vector2(200.0, 0.0)
	_step(0.1)
	assert_false(sleeper.dormant, "Woke up")


func test_planting_the_pylon_starts_the_siege() -> void:
	_start_mission()
	mission.pilot.position = mission.map.vein + Vector2(40.0, 0.0)
	mission._interact()
	assert_eq(mission.phase, SurfaceMission.Phase.SIEGE, "Siege on")
	assert_not_null(mission.claim, "The pylon is charging")
	assert_false(mission.nests_awake(), "Nests go quiet during the siege")
	mission.battle.god_mode = true
	_step(1.0)
	assert_gt(mission._siege_enemy_count(), 0, "The Gloom comes out of the dark")


func test_holding_the_pylon_kindles_the_planet() -> void:
	_start_mission()
	mission.tuning.claim_speed_multiplier = 30.0
	mission.battle.god_mode = true
	mission.pilot.position = mission.map.vein + Vector2(40.0, 0.0)
	mission._interact()
	_step(4.0)
	assert_eq(mission.phase, SurfaceMission.Phase.KINDLED, "Kindled")
	_step(3.0)
	assert_eq(mission.battle.enemies.size(), 0, "The wave of light burned every Gloom on the planet")
	assert_gt(int(mission.run.resources[mission.resource()]), 0, "The haul flew in")
	assert_gte(mission.run.sparks, mission.tuning.kindle_sparks, "And the kindling sparks")
	watch_signals(mission)
	mission._interact()
	assert_eq(mission._outcome, "kindled", "Lifting off as kindled")


func test_wandering_off_lets_the_pylon_go_dark() -> void:
	_start_mission()
	mission.battle.god_mode = true
	mission.pilot.position = mission.map.vein + Vector2(40.0, 0.0)
	mission._interact()
	mission.claim.progress = 0.05
	mission.pilot.position = mission.map.landing
	_step(mission.tuning.claim_grace_seconds + 3.0)
	assert_null(mission.claim, "Siege failed")
	assert_eq(mission.phase, SurfaceMission.Phase.EXPLORE, "Back to exploring")


func test_lifting_off_at_the_lander_leaves_the_planet_dark() -> void:
	_start_mission()
	watch_signals(mission)
	mission._interact()
	assert_eq(mission._outcome, "left", "Leaving")
	await wait_seconds(SurfaceMission.LIFTOFF_SECONDS + 0.3)
	assert_signal_emitted_with_parameters(mission, "finished", ["left"])


func test_losing_the_pilot_with_no_spare_sparks_is_defeat() -> void:
	_start_mission()
	mission.pilot._invulnerable_left = 0.0
	mission.pilot.take_damage(9999.0)
	assert_eq(mission.phase, SurfaceMission.Phase.LOST, "Lost")
	assert_eq(mission._outcome, "defeat", "Defeat")


func test_a_spare_spark_brings_the_pilot_back_at_the_lander() -> void:
	_start_mission()
	mission.run.revives_left = 1
	mission.pilot.position = mission.map.vein
	mission.pilot._invulnerable_left = 0.0
	mission.pilot.take_damage(9999.0)
	assert_eq(mission.run.revives_left, 0, "Spare spark used")
	_step(mission.tuning.respawn_delay + 0.2)
	assert_true(mission.pilot.alive, "Back on their feet")
	assert_lt(mission.pilot.position.distance_to(mission.map.landing), SurfaceMission.LANDER_RADIUS, "At the lander")


func test_enemies_route_around_rocks() -> void:
	_start_mission()
	var rock: SurfaceMap.Rock = null
	for candidate in mission.map.rocks:
		if candidate.radius > 70.0 and mission.map.bounds.grow(-400.0).has_point(candidate.position):
			rock = candidate
			break
	assert_not_null(rock, "Found a big rock")
	var mite := mission.battle.spawn("mite", false, rock.position + Vector2(-rock.radius - 40.0, 0.0))
	var goal := rock.position + Vector2(rock.radius + 60.0, 0.0)
	var waypoint := mission.route_to(mite, goal)
	assert_ne(waypoint, goal, "A rock in the way means a detour")
	assert_false(mission.map.segment_hits_rock(mite.position, goal, 1.0) and waypoint == goal, "Never walks straight into it")



func test_extractors_are_built_on_a_kindled_planet() -> void:
	_start_mission()
	mission.tuning.claim_speed_multiplier = 30.0
	mission.battle.god_mode = true
	mission.pilot.position = mission.map.vein + Vector2(40.0, 0.0)
	mission._interact()
	_step(4.0)
	assert_eq(mission.phase, SurfaceMission.Phase.KINDLED, "Kindled")
	var deposit: SurfaceMap.Deposit = mission.map.deposits[0]
	mission.pilot.position = deposit.position + Vector2(deposit.radius() + 30.0, 0.0)
	assert_not_null(mission.extractor_site(), "Standing at a deposit site")
	mission.run.resources[mission.resource()] = 0
	mission._interact()
	assert_false(deposit.extractor, "Can't afford it")
	mission.run.resources[mission.resource()] = SurfaceMission.EXTRACTOR_COST + 2
	mission._interact()
	assert_true(deposit.extractor, "Built")
	assert_eq(mission.planet.extractors, 1, "Counted on the planet")
	assert_eq(int(mission.run.resources[mission.resource()]), 2, "Paid for with the haul")
	assert_eq(mission._outcome, "", "Building didn't lift off")


func test_killing_gloom_on_foot_earns_pilot_experience() -> void:
	_start_mission()
	var before := mission.run.pilot_xp
	var mite := mission.battle.spawn("mite", false, mission.pilot.position + Vector2(300.0, 0.0))
	mission.battle.kill(mite)
	assert_gt(mission.run.pilot_xp, before, "Experience for the kill")
