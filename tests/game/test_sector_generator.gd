extends GutTest

var tuning: SpaceTuning


func before_each() -> void:
	tuning = SpaceTuning.new()


func test_generates_close_to_requested_region_count() -> void:
	var sector := SectorGenerator.generate(1234, tuning)
	assert_between(sector.regions.size(), tuning.region_count - 4, tuning.region_count, "Region count should be near the target")


func test_same_seed_gives_same_sector() -> void:
	var a := SectorGenerator.generate(42, tuning)
	var b := SectorGenerator.generate(42, tuning)
	assert_eq(a.regions.size(), b.regions.size(), "Same seed, same region count")
	for i in a.regions.size():
		assert_eq(a.regions[i].polygon, b.regions[i].polygon, "Region %d polygon should match" % i)
		assert_eq(a.regions[i].name, b.regions[i].name, "Region %d name should match" % i)


func test_different_seeds_give_different_sectors() -> void:
	var a := SectorGenerator.generate(1, tuning)
	var b := SectorGenerator.generate(2, tuning)
	assert_ne(a.regions[0].polygon, b.regions[0].polygon, "Different seeds should differ")


func test_regions_tile_the_sector() -> void:
	for seed_value in [3, 17, 99]:
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


func test_neighbors_are_symmetric() -> void:
	var sector := SectorGenerator.generate(11, tuning)
	for region in sector.regions:
		for neighbor_id in region.neighbors:
			assert_true(sector.regions[neighbor_id].neighbors.has(region.id), "%d and %d should list each other" % [region.id, neighbor_id])


func test_every_region_is_reachable_from_home() -> void:
	for seed_value in [5, 23, 404, 9001]:
		var sector := SectorGenerator.generate(seed_value, tuning)
		for region in sector.regions:
			assert_true(region.depth >= 0, "Region %d should be reachable (seed %d)" % [region.id, seed_value])


func test_home_starts_claimed_and_everything_else_dark() -> void:
	var sector := SectorGenerator.generate(8, tuning)
	assert_eq(sector.claimed_count(), 1, "Only home starts claimed")
	assert_true(sector.home().claimed, "Home is claimed")
	assert_eq(sector.home().depth, 0, "Home has depth 0")


func test_home_neighbors_are_the_first_frontier() -> void:
	var sector := SectorGenerator.generate(8, tuning)
	for region in sector.regions:
		assert_eq(sector.is_frontier(region.id), region.depth == 1, "Region %d frontier should match depth 1" % region.id)


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
