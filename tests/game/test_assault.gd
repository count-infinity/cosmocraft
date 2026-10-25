extends GutTest
## The planet assault: terrain, ground defenses, the bastion, and how the
## assault ends.

const FRAME := 1.0 / 60.0

var mission: AssaultMission


func _planet() -> PlanetData:
	var planet := PlanetData.new()
	planet.name = "Test World"
	planet.type = PlanetData.Type.FUNGAL
	planet.depth = 2
	planet.surface_seed = 4321
	return planet


func _start(run: RunState = null) -> void:
	mission = AssaultMission.new()
	mission.setup(run if run != null else RunState.fresh(1), _planet(), SpaceTuning.new())
	add_child_autofree(mission)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		mission._step(FRAME)
		elapsed += FRAME


func test_the_terrain_stays_on_screen_and_flattens_for_the_bastion() -> void:
	var terrain := AssaultTerrain.new()
	add_child_autofree(terrain)
	terrain.build(7, PlanetData.Type.ASHEN, 9000.0, 7800.0)
	for x in range(0, 9000, 97):
		var y := terrain.ground_y(x)
		assert_between(y, AssaultTerrain.HIGHEST, AssaultTerrain.LOWEST, "Ground at %d is on screen" % x)
	assert_lt(absf(terrain.slope(8500.0)), 0.05, "Flat where the bastion stands")


func test_ground_defenses_sit_on_the_ground() -> void:
	_start()
	assert_gt(mission.defenses_total, 6, "A run of defenses to burn")
	for enemy in mission.battle.enemies:
		if enemy.kind in ["spore_turret", "thorn_battery", "hive"]:
			assert_almost_eq(enemy.position.y, mission.ground_y(enemy.position.x) - enemy.radius * 0.35, 1.0, "%s rooted in the ground" % enemy.kind)


func test_destroying_defenses_raises_suppression() -> void:
	_start()
	assert_eq(mission.suppression(), 0.0, "Nothing destroyed yet")
	var killed := 0
	for enemy in mission.battle.enemies.duplicate():
		if enemy.kind == "spore_turret" and killed < 3:
			mission.battle.kill(enemy)
			killed += 1
	assert_eq(mission.defenses_destroyed, killed, "Counted")
	assert_almost_eq(mission.suppression(), float(killed) / mission.defenses_total, 0.0001, "Share of defenses down")


func test_the_bastion_is_shielded_until_its_pods_fall() -> void:
	_start()
	mission.battle.god_mode = true
	mission._step(FRAME)
	assert_true(mission.bastion.shielded, "Shielded behind its pods")
	for pod in mission.pods:
		mission.battle.kill(pod)
	mission.battle.remove_dead()
	mission._step(FRAME)
	assert_false(mission.bastion.shielded, "Exposed once they're gone")


func test_breaking_the_bastion_lands_you() -> void:
	_start()
	mission.battle.god_mode = true
	for pod in mission.pods:
		mission.battle.kill(pod)
	mission.battle.remove_dead()
	mission._step(FRAME)
	watch_signals(mission)
	mission.battle.kill(mission.bastion)
	assert_true(mission.planet.assaulted, "The planet's defenses are down for good")
	await wait_seconds(AssaultMission.FINISH_SECONDS + 0.3)
	assert_signal_emitted(mission, "finished", "Off to land")
	assert_eq(mission._outcome, "landed", "Landed")


func test_the_stage_scrolls_and_carries_the_ship() -> void:
	_start()
	mission.battle.god_mode = true
	var start := mission.ship.position.x
	_step(2.0)
	assert_almost_eq(mission.scroll, AssaultMission.SCROLL_SPEED * 2.0, 2.0, "The camera moves on")
	assert_gt(mission.ship.position.x, start + 150.0, "The ship comes along")


func test_losing_the_ship_with_a_spare_spark_bounces_you_to_orbit() -> void:
	var run := RunState.fresh(1)
	run.revives_left = 1
	_start(run)
	mission.ship._invulnerable_left = 0.0
	mission.ship.take_damage(9999.0)
	assert_eq(mission._outcome, "retreated", "Back to orbit")
	assert_eq(run.revives_left, 0, "Spare spark spent")


func test_losing_the_ship_without_spare_sparks_ends_the_run() -> void:
	_start()
	mission.ship._invulnerable_left = 0.0
	mission.ship.take_damage(9999.0)
	assert_eq(mission._outcome, "defeat", "Run over")


func test_suppression_thins_out_the_surface() -> void:
	var planet := _planet()
	var full := SurfaceMission.new()
	full.setup(RunState.fresh(1), planet, SpaceTuning.new())
	add_child_autofree(full)
	var thinned := SurfaceMission.new()
	thinned.setup(RunState.fresh(1), planet, SpaceTuning.new(), false, 1.0)
	add_child_autofree(thinned)
	assert_lt(thinned.map.nests.size(), full.map.nests.size(), "Fewer nests")
	assert_lt(thinned.map.packs.size(), full.map.packs.size(), "Fewer sleeping packs")
