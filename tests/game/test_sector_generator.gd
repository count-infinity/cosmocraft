extends GutTest

const SEEDS: Array[int] = [3, 17, 99, 404, 9001]

var tuning: SpaceTuning


func before_each() -> void:
	tuning = SpaceTuning.new()


func test_merges_cells_down_to_about_the_requested_region_count() -> void:
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		assert_between(sector.regions.size(), tuning.region_count, tuning.region_count + 6, "Region count near the target (seed %d)" % seed_value)


func test_same_seed_gives_same_sector() -> void:
	var a := SectorGenerator.generate(42, tuning)
	var b := SectorGenerator.generate(42, tuning)
	assert_eq(a.regions.size(), b.regions.size(), "Same seed, same region count")
	for i in a.regions.size():
		assert_eq(a.regions[i].polygon, b.regions[i].polygon, "Region %d polygon should match" % i)
		assert_eq(a.regions[i].name, b.regions[i].name, "Region %d name should match" % i)
		assert_eq(a.regions[i].modifier, b.regions[i].modifier, "Region %d modifier should match" % i)


func test_different_seeds_give_different_sectors() -> void:
	var a := SectorGenerator.generate(1, tuning)
	var b := SectorGenerator.generate(2, tuning)
	assert_ne(a.regions[0].polygon, b.regions[0].polygon, "Different seeds should differ")


func test_regions_tile_the_sector() -> void:
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		var total := 0.0
		for region in sector.regions:
			total += region.area
		var boundary_area := absf(SectorGenerator.polygon_area(sector.boundary))
		assert_almost_eq(total, boundary_area, boundary_area * 0.01, "Regions should cover the sector (seed %d)" % seed_value)


func test_sample_points_fall_in_exactly_one_region() -> void:
	var sector := SectorGenerator.generate(7, tuning)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var misses := 0
	var checked := 0
	while checked < 400:
		var point := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * sector.radius
		if not Geometry2D.is_point_in_polygon(point, sector.boundary):
			continue
		checked += 1
		var hits := 0
		for region in sector.regions:
			if region.contains(point):
				hits += 1
		if hits != 1:
			misses += 1
	assert_eq(misses, 0, "Every point inside the sector should be in exactly one region")


func test_claim_times_vary_widely() -> void:
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		var shortest := INF
		var longest := 0.0
		for region in sector.regions:
			if region.claimed or region.is_heart:
				continue
			shortest = minf(shortest, region.claim_seconds)
			longest = maxf(longest, region.claim_seconds)
		assert_gt(longest / shortest, 2.0, "Longest claim should be over twice the shortest (seed %d: %.0fs to %.0fs)" % [seed_value, shortest, longest])


func test_some_regions_are_merged_from_several_cells() -> void:
	var sector := SectorGenerator.generate(12, tuning)
	var multi := 0
	for region in sector.regions:
		if region.cell_count > 1 and not region.is_heart:
			multi += 1
	assert_gt(multi, 2, "Several regions should be built from more than one cell")


func test_anchors_are_inside_their_regions() -> void:
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		for region in sector.regions:
			assert_true(region.contains(region.anchor), "Anchor inside region %d (seed %d)" % [region.id, seed_value])


func test_neighbors_are_symmetric() -> void:
	var sector := SectorGenerator.generate(11, tuning)
	for region in sector.regions:
		for neighbor_id in region.neighbors:
			assert_true(sector.regions[neighbor_id].neighbors.has(region.id), "%d and %d should list each other" % [region.id, neighbor_id])


func test_every_region_is_reachable_from_home() -> void:
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		for region in sector.regions:
			assert_true(region.depth >= 0, "Region %d should be reachable (seed %d)" % [region.id, seed_value])


func test_home_starts_claimed_and_everything_else_dark() -> void:
	var sector := SectorGenerator.generate(8, tuning)
	assert_eq(sector.claimed_count(), 1, "Only home is claimed")
	assert_true(sector.home().claimed, "Home is claimed")
	assert_eq(sector.home().depth, 0, "Home has depth 0")
	assert_eq(sector.home().cell_count, 1, "Home is a single cell")


func test_home_neighbors_are_the_first_frontier() -> void:
	var sector := SectorGenerator.generate(8, tuning)
	for region in sector.regions:
		assert_eq(sector.is_frontier(region.id), region.depth == 1, "Region %d frontier should match depth 1" % region.id)


func test_heart_is_big_and_deep_in_the_dark() -> void:
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		var heart := sector.heart()
		assert_not_null(heart, "Heart exists (seed %d)" % seed_value)
		assert_ne(heart.id, sector.home_id, "Heart is not home")
		# Run length comes from heart_requires_claims; this only keeps it off home's doorstep.
		assert_gte(heart.depth, 2, "Heart is never next to home (seed %d)" % seed_value)
		assert_gte(heart.cell_count, 3, "Heart is a big region (seed %d)" % seed_value)
		assert_eq(sector.steps_to_heart(), heart.depth, "Steps to heart match its depth at the start")


func test_modifiers_skip_home_heart_and_the_first_ring() -> void:
	var with_modifier := 0
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		for region in sector.regions:
			if region.claimed or region.is_heart or region.depth <= 1:
				assert_eq(region.modifier, RegionData.Modifier.NONE, "No modifier on region %d (seed %d)" % [region.id, seed_value])
			elif region.modifier != RegionData.Modifier.NONE:
				with_modifier += 1
	assert_gt(with_modifier, 5, "Modifiers show up across a few sectors")


func test_asteroids_sit_inside_asteroid_regions() -> void:
	var found := 0
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		for asteroid in sector.asteroids:
			found += 1
			var region := sector.get_region(asteroid.region_id)
			assert_eq(region.modifier, RegionData.Modifier.ASTEROIDS, "Asteroid in an asteroid field")
			assert_true(region.contains(asteroid.position), "Asteroid inside its region")
			assert_gt(asteroid.position.distance_to(region.anchor), SectorGenerator.ASTEROID_CLEARING - 0.01, "Clearing around the anchor")
	assert_gt(found, 0, "Some asteroid fields across these seeds")


func test_planets_sit_where_regions_meet() -> void:
	var found := 0
	for seed_value in SEEDS:
		var sector := SectorGenerator.generate(seed_value, tuning)
		for planet in sector.planets:
			found += 1
			assert_gte(planet.touching.size(), 2, "Several regions around %s" % planet.name)
			assert_false(planet.touching.has(sector.home_id), "Home is never part of a planet")
			assert_false(planet.touching.has(sector.heart_id), "Neither is the heart")
			assert_false(planet.is_awake(sector), "Starts dormant")
			for other in sector.planets:
				if other != planet:
					assert_gt(planet.position.distance_to(other.position), tuning.planet_spacing - 0.01, "Planets are spread out")
	assert_gt(found, SEEDS.size(), "Most sectors have planets")


func test_claiming_around_a_planet_wakes_it() -> void:
	var sector := SectorGenerator.generate(SEEDS[0], tuning)
	var planet := sector.planets[0]
	for region_id in planet.touching:
		assert_false(planet.is_awake(sector), "Still dormant until every region is claimed")
		sector.regions[region_id].claimed = true
	assert_true(planet.is_awake(sector), "Awake once surrounded")


func test_edge_neighbors_line_up_with_polygon_edges() -> void:
	var sector := SectorGenerator.generate(13, tuning)
	for region in sector.regions:
		assert_eq(region.edge_neighbors.size(), region.polygon.size(), "One neighbor entry per edge")


func test_bigger_regions_take_longer_to_claim() -> void:
	var small := SectorGenerator.claim_seconds_for_area(SpaceTuning.SCREEN_AREA * 0.5, tuning)
	var large := SectorGenerator.claim_seconds_for_area(SpaceTuning.SCREEN_AREA * 2.0, tuning)
	assert_gt(large, small, "Larger area should take longer")


func test_claim_time_is_clamped() -> void:
	assert_eq(SectorGenerator.claim_seconds_for_area(0.0, tuning), tuning.claim_min_seconds, "Clamped to the minimum")
	assert_eq(SectorGenerator.claim_seconds_for_area(SpaceTuning.SCREEN_AREA * 100.0, tuning), tuning.claim_max_seconds, "Clamped to the maximum")


func test_polygon_area_and_centroid_of_a_square() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	assert_almost_eq(absf(SectorGenerator.polygon_area(square)), 100.0, 0.001, "Area of a 10x10 square")
	var centroid := SectorGenerator.polygon_centroid(square)
	assert_almost_eq(centroid.x, 5.0, 0.001, "Centroid x")
	assert_almost_eq(centroid.y, 5.0, 0.001, "Centroid y")
