extends GutTest
## Drives the real SpaceGame headlessly through the main claim flows.

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
		if region.depth == depth:
			return region
	return null


func _kindle_frontier() -> RegionData:
	var region := _region_with_depth(1)
	game.ship.position = region.centroid
	game._ship_region = game.sector.region_at(region.centroid)
	game._try_kindle()
	return region


func test_starts_at_the_home_beacon() -> void:
	assert_eq(game.sector.claimed_count(), 1, "Only home is claimed")
	assert_eq(game.ship.position, game.sector.home().beacon, "Ship starts at home")
	assert_null(game.claim, "No claim yet")


func test_kindling_a_frontier_region_starts_a_claim() -> void:
	var region := _kindle_frontier()
	assert_not_null(game.claim, "Claim started")
	assert_eq(game.claim.region_id, region.id, "Claiming the region the ship is in")
	assert_not_null(game.kindle_spark, "Spark dropped")


func test_regions_deeper_in_the_dark_cannot_be_kindled() -> void:
	var region := _region_with_depth(2)
	game.ship.position = region.centroid
	game._ship_region = game.sector.region_at(region.centroid)
	game._try_kindle()
	assert_null(game.claim, "Not adjacent to territory, so no claim")


func test_holding_the_region_ignites_it() -> void:
	game._god_mode = true
	game.tuning.claim_speed_multiplier = 40.0
	var region := _kindle_frontier()
	_step(6.0)
	assert_true(region.claimed, "Region claimed")
	assert_eq(game.sector.claimed_count(), 2, "Territory grew")
	assert_null(game.claim, "Claim finished")
	assert_eq(game.enemies.size(), 0, "The ignition wave burned the Gloom away")


func test_waves_spawn_during_a_claim() -> void:
	game._god_mode = true
	_kindle_frontier()
	_step(0.5)
	assert_gt(game.enemies.size(), 0, "The Gloom shows up")


func test_dying_fails_the_claim_and_respawns_at_home() -> void:
	_kindle_frontier()
	game.ship._invulnerable_left = 0.0
	game.ship.take_damage(9999.0)
	assert_false(game.ship.alive, "Ship destroyed")
	assert_null(game.claim, "Claim failed with the ship")
	_step(game.tuning.respawn_delay + 0.1)
	assert_true(game.ship.alive, "Ship respawned")
	assert_eq(game.ship.position, game.sector.home().beacon, "Back at the home beacon")


func test_leaving_the_region_fails_the_claim() -> void:
	game._god_mode = true
	_kindle_frontier()
	game.ship.position = game.sector.home().beacon
	_step(game.tuning.claim_grace_seconds + 0.5)
	assert_null(game.claim, "Abandoned claim drained away")
	assert_eq(game.sector.claimed_count(), 1, "Nothing new claimed")


func test_a_snuffer_at_the_spark_costs_progress() -> void:
	_kindle_frontier()
	game.claim.progress = 0.5
	var snuffer := GloomEnemy.new()
	snuffer.setup("snuffer", false, RandomNumberGenerator.new())
	game.enemies.append(snuffer)
	add_child_autofree(snuffer)
	game.on_snuffer_reached(snuffer)
	assert_almost_eq(game.claim.progress, 0.5 - game.tuning.snuff_penalty, 0.0001, "Lost the snuff penalty")
	assert_true(snuffer.dead, "Snuffer spent itself")
