extends GutTest
## Drives the real SpaceGame headlessly through the main run flows.

const FRAME := 1.0 / 60.0

var game: SpaceGame


func before_each() -> void:
	game = SpaceGame.new()
	game.sector_seed = 42
	add_child_autofree(game)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		game._step(FRAME)
		elapsed += FRAME


func _region_with_depth(depth: int) -> RegionData:
	for region in game.sector.regions:
		if region.depth == depth and not region.is_heart:
			return region
	return null


func _move_to(region: RegionData) -> void:
	game.ship.position = region.anchor
	game._ship_region = game.sector.region_at(region.anchor)


func _kindle_frontier() -> RegionData:
	var region := _region_with_depth(1)
	_move_to(region)
	game._try_kindle()
	return region


func _spawn(kind: String, position: Vector2) -> GloomEnemy:
	var enemy := game.battle.spawn(kind, false, position)
	enemy.age = 1.0
	return enemy


## Claims everything around the heart's path so it unseals and is reachable.
func _unseal_heart() -> void:
	var heart := game.sector.heart()
	for region in game.sector.regions:
		if region != heart:
			region.claimed = true
	game._refresh_territory()


func test_starts_at_the_home_beacon_with_the_starter_ship() -> void:
	assert_eq(game.sector.claimed_count(), 1, "Only home is claimed")
	assert_eq(game.ship.position, game.sector.home().beacon, "Ship starts at home")
	assert_null(game.claim, "No claim yet")
	assert_eq(game.stats.weapons.size(), 1, "One weapon fitted")
	assert_eq(game.weapons.mounts.size(), 1, "Weapon system knows about it")


func test_kindling_a_frontier_region_starts_a_claim() -> void:
	var region := _kindle_frontier()
	assert_not_null(game.claim, "Claim started")
	assert_eq(game.claim.region_id, region.id, "Claiming the region the ship is in")
	assert_not_null(game.kindle_spark, "Spark dropped")


func test_regions_deeper_in_the_dark_cannot_be_kindled() -> void:
	_move_to(_region_with_depth(2))
	game._try_kindle()
	assert_null(game.claim, "Not adjacent to territory, so no claim")


func test_holding_the_region_ignites_it_and_offers_loot() -> void:
	game.battle.god_mode = true
	game.tuning.claim_speed_multiplier = 40.0
	var region := _kindle_frontier()
	_step(6.0)
	assert_true(region.claimed, "Region claimed")
	assert_eq(game.run.regions_claimed, 1, "Run counts the claim")
	assert_null(game.claim, "Claim finished")
	assert_eq(game.battle.enemies.size(), 0, "The ignition wave burned the Gloom away")
	assert_true(game._loot.visible, "Loot pick is on screen")
	assert_eq(game._loot_choices.size(), 3, "Three choices offered")


func test_picking_loot_applies_it() -> void:
	var choice := LootPicks.Choice.new()
	choice.def = ComponentLibrary.get_def("magnet_coil")
	var before := game.stats.magnet
	game._on_loot_picked(choice)
	assert_gt(game.stats.magnet, before, "Magnet coil fitted and applied")


func test_waves_spawn_during_a_claim() -> void:
	game.battle.god_mode = true
	_kindle_frontier()
	_step(0.5)
	assert_gt(game.battle.enemies.size(), 0, "The Gloom shows up")


func test_dying_with_a_spare_spark_respawns_at_home() -> void:
	game.run.revives_left = 1
	_kindle_frontier()
	game.ship._invulnerable_left = 0.0
	game.ship.take_damage(9999.0)
	assert_false(game.ship.alive, "Ship destroyed")
	assert_null(game.claim, "Claim failed with the ship")
	assert_eq(game.run.revives_left, 0, "Spare spark used")
	_step(game.tuning.respawn_delay + 0.1)
	assert_true(game.ship.alive, "Ship respawned")
	assert_eq(game.ship.position, game.sector.home().beacon, "Back at the home beacon")


func test_dying_without_spare_sparks_ends_the_run() -> void:
	game.ship._invulnerable_left = 0.0
	game.ship.take_damage(9999.0)
	assert_eq(game.run.outcome, RunState.Outcome.DEFEAT, "Run lost")
	_step(game.tuning.respawn_delay + 0.5)
	assert_false(game.ship.alive, "No respawn after the run ends")


func test_leaving_the_region_fails_the_claim() -> void:
	game.battle.god_mode = true
	_kindle_frontier()
	game.ship.position = game.sector.home().beacon
	_step(game.tuning.claim_grace_seconds + 0.5)
	assert_null(game.claim, "Abandoned claim drained away")
	assert_eq(game.sector.claimed_count(), 1, "Nothing new claimed")


func test_a_snuffer_at_the_spark_costs_progress() -> void:
	_kindle_frontier()
	game.claim.progress = 0.5
	var snuffer := _spawn("snuffer", game.kindle_spark.position)
	game.on_snuffer_reached(snuffer)
	assert_almost_eq(game.claim.progress, 0.5 - game.tuning.snuff_penalty, 0.0001, "Lost the snuff penalty")
	assert_true(snuffer.dead, "Snuffer spent itself")


func test_refit_only_opens_in_your_territory() -> void:
	game._open_refit()
	assert_true(game._refit.visible, "Opens at home")
	game._refit.close()
	assert_false(game._refit.visible, "Closes")
	_move_to(_region_with_depth(1))
	game._open_refit()
	assert_false(game._refit.visible, "Not out in the dark")


func test_auto_turrets_fire_at_nearby_enemies() -> void:
	game.battle.god_mode = true
	game.run.loadout.remove(game.run.loadout.fitted[1])
	assert_not_null(game.run.loadout.place(ComponentLibrary.get_def("flak_turret"), Vector2i(0, 2), 0), "Turret fits once the shield's power is free")
	game._apply_loadout()
	_spawn("carapace", game.ship.position + Vector2(200, 0))
	_step(0.1)
	var shots := 0
	for bullet in game._projectiles.bullets:
		if bullet.friendly:
			shots += 1
	assert_gt(shots, 0, "The turret fired on its own")


func test_blasts_hit_everything_in_range() -> void:
	var near := _spawn("mite", Vector2(10000, 10000))
	var close := _spawn("mite", Vector2(10040, 10000))
	var far := _spawn("mite", Vector2(10400, 10000))
	game.battle.rebuild_grid()
	var spec := WeaponSpec.from_weapon("flak_turret", ComponentLibrary.get_def("flak_turret").weapon)
	var bullet := game._projectiles.spawn_player(spec, Vector2(10000, 10000), Vector2.ZERO, 1.0, null)
	bullet.damage = 10.0
	game.battle.explode(bullet, Vector2(10000, 10000))
	assert_true(near.dead and close.dead, "Both mites in the blast died")
	assert_false(far.dead, "The far one is untouched")


func test_carapace_shrugs_off_shots_to_its_front() -> void:
	var carapace := _spawn("carapace", Vector2.ZERO)
	carapace.rotation = 0.0
	assert_true(carapace.blocks(Vector2.LEFT), "A shot flying into its face is blocked")
	assert_false(carapace.blocks(Vector2.RIGHT), "A shot from behind gets through")


func test_a_carapace_plate_cracks_under_fire() -> void:
	var carapace := _spawn("carapace", Vector2(10000, 10000))
	carapace.rotation = 0.0
	var hp := carapace.hp
	var spec := WeaponSpec.from_weapon("pulse_laser", ComponentLibrary.get_def("pulse_laser").weapon)
	var shots := 0
	while carapace.blocks(Vector2.LEFT) and shots < 50:
		game._projectiles.spawn_player(spec, Vector2(10060, 10000), Vector2(-1150, 0), 1.0, null)
		game.battle.update_projectiles(1.0 / 30.0, game.ship, game.ship.radius, false, func(_bullet: Projectiles.Bullet) -> bool: return false)
		shots += 1
	assert_eq(carapace.hp, hp, "The plate took every hit")
	assert_false(carapace.blocks(Vector2.LEFT), "Then it cracked")
	assert_lt(shots, 10, "Within a handful of laser hits")
	game._projectiles.spawn_player(spec, Vector2(10060, 10000), Vector2(-1150, 0), 1.0, null)
	game.battle.update_projectiles(1.0 / 30.0, game.ship, game.ship.radius, false, func(_bullet: Projectiles.Bullet) -> bool: return false)
	assert_lt(carapace.hp, hp, "Now shots to the front hurt it")


func test_the_heart_stays_sealed_until_enough_claims() -> void:
	var heart := game.sector.heart()
	for neighbor_id in heart.neighbors:
		game.sector.regions[neighbor_id].claimed = true
		break
	_move_to(heart)
	if game.heart_claims_needed() > 0:
		game._try_kindle()
		assert_null(game.claim, "Sealed heart can't be kindled")
	_unseal_heart()
	assert_eq(game.heart_claims_needed(), 0, "Seal broken")
	game._try_kindle()
	assert_not_null(game.claim, "Now it can")
	assert_not_null(game.heart_boss, "And the heart awakens")
	assert_true(game.heart_boss.shielded, "Shielded at first")


func test_the_heart_must_die_before_its_region_ignites() -> void:
	game.battle.god_mode = true
	_unseal_heart()
	_move_to(game.sector.heart())
	game._try_kindle()
	game.claim.progress = 0.995
	_step(0.5)
	assert_not_null(game.claim, "Still claiming while the heart beats")
	assert_lt(game.claim.progress, 1.0, "Held just short of ignition")
	assert_false(game.heart_boss.shielded, "Shell broken")
	game.battle.kill(game.heart_boss)
	_step(2.0)
	assert_true(game.sector.heart().claimed, "Heart region ignited")
	assert_true(game._loot.visible, "A loot pick for the heart")
	game._on_loot_picked(game._loot_choices[0])
	assert_eq(game.run.outcome, RunState.Outcome.VICTORY, "A practice run goes home a winner")


func test_relighting_a_galaxy_sector_offers_to_push_on() -> void:
	var map := GalaxyData.generate(77)
	var owned := {map.home_id: true}
	var target: int = map.frontier(owned)[0]
	game.galaxy = map
	game.conquered = owned
	game.run.enter_sector(map, target)
	game.start_sector(game.run.sector_seed)
	watch_signals(game)
	game.battle.god_mode = true
	_unseal_heart()
	_move_to(game.sector.heart())
	game._try_kindle()
	game.claim.progress = 0.995
	_step(0.5)
	game.battle.kill(game.heart_boss)
	_step(2.0)
	assert_signal_emitted_with_parameters(game, "sector_relit", [target])
	game._on_loot_picked(game._loot_choices[0])
	assert_true(game._choice.visible, "Push on or go home")
	var next: int = map.dark_neighbors(target, game.conquered)[0]
	game._on_sector_chosen(next)
	assert_eq(game.run.sector_id, next, "Pushed on")
	assert_eq(game.run.outcome, RunState.Outcome.IN_PROGRESS, "The run goes on")
	assert_eq(game.sector.claimed_count(), 1, "A fresh sector, only its entry claimed")
	assert_eq(game.run.sectors_conquered, [target] as Array[int], "One conquest so far this run")


func test_kills_during_a_claim_drop_sparks() -> void:
	game.battle.god_mode = true
	_kindle_frontier()
	var mite := _spawn("mite", game.ship.position + Vector2(300, 0))
	mite.spark_chance = 1.0
	game.battle.kill(mite)
	assert_eq(game.run.kills, 1, "Kill counted")
	assert_gt(game._pickups.count(Pickups.SPARK), 0, "Sparks dropped")


func test_pickups_report_what_arrived_by_kind() -> void:
	var pickups := Pickups.new()
	add_child_autofree(pickups)
	pickups.drop(Vector2.ZERO, 3)
	pickups.drop(Vector2.ZERO, 2, "ore")
	var arrived := {}
	for i in 120:
		var got := pickups.update(1.0 / 60.0, Vector2(10, 0), true, 500.0)
		for kind: String in got:
			arrived[kind] = int(arrived.get(kind, 0)) + int(got[kind])
	assert_eq(int(arrived.get(Pickups.SPARK, 0)), 3, "Three sparks")
	assert_eq(int(arrived.get("ore", 0)), 2, "Two ore shards")
	assert_eq(pickups.count(), 0, "Nothing left lying around")


func test_landing_needs_an_awake_planet() -> void:
	if game.sector.planets.is_empty():
		pass_test("This sector has no planets")
		return
	var planet: PlanetData = game.sector.planets[0]
	game.ship.position = planet.position
	assert_null(game._planet_under_ship(), "Dormant planets can't be landed on")
	for region_id in planet.touching:
		game.sector.regions[region_id].claimed = true
	assert_eq(game._planet_under_ship(), planet, "Awake planet under the ship")
	watch_signals(game)
	game._request_landing(planet)
	assert_signal_emitted_with_parameters(game, "landing_requested", [planet])


func test_returning_from_a_kindled_planet_makes_an_outpost() -> void:
	if game.sector.planets.is_empty():
		pass_test("This sector has no planets")
		return
	var planet: PlanetData = game.sector.planets[0]
	for region_id in planet.touching:
		game.sector.regions[region_id].claimed = true
	game.on_returned_from_surface(planet, "kindled")
	assert_true(planet.kindled, "Planet kindled")
	assert_eq(game.run.outposts.size(), 1, "Outpost recorded")
	assert_true(game._loot.visible, "A loot pick for the trouble")
	assert_null(game._planet_under_ship(), "Can't land on it again")


func test_darkness_changes_only_between_fights() -> void:
	game.run.darkness_max = 3
	assert_true(game.change_darkness(1), "Nightfall between fights")
	assert_eq(game.run.darkness, 2, "Now on Nightfall")
	_kindle_frontier()
	assert_false(game.change_darkness(1), "Not in the middle of a claim")
	assert_eq(game.run.darkness, 2, "Still Nightfall")


func test_darker_levels_make_tougher_gloom() -> void:
	game.battle.god_mode = true
	game.run.darkness_max = 4
	game.run.darkness = 4
	_kindle_frontier()
	_step(0.5)
	var mite: GloomEnemy = null
	for enemy in game.battle.enemies:
		if enemy.kind == "mite":
			mite = enemy
	assert_not_null(mite, "The opening pack arrived")
	var expected := float(GloomEnemy.KINDS["mite"]["hp"]) * game.tuning.health_scale(1) * float(Difficulty.level(4)["health"])
	assert_almost_eq(mite.max_hp, expected, 0.01, "Eclipse mites are much tougher")
	assert_almost_eq(game.battle.damage_scale, float(Difficulty.level(4)["damage"]), 0.0001, "And hit harder")


func test_waves_stop_once_the_hearts_shell_breaks() -> void:
	game.battle.god_mode = true
	_unseal_heart()
	_move_to(game.sector.heart())
	game._try_kindle()
	game.claim.progress = SpaceGame.HEART_SHIELD_UNTIL + 0.01
	_step(0.2)
	assert_false(game.heart_boss.shielded, "Shell broken")
	var credits := game.director.credits
	_step(1.0)
	assert_eq(game.director.credits, credits, "The director stopped: it's a duel now")
