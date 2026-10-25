extends GutTest
## The conquest map: systems of sectors, the frontier you can invade, tiers,
## and conquering sectors and systems.


func test_the_same_seed_makes_the_same_galaxy() -> void:
	var a := GalaxyData.generate(42)
	var b := GalaxyData.generate(42)
	assert_eq(a.sectors.size(), b.sectors.size(), "Same number of sectors")
	assert_eq(a.home_id, b.home_id, "Same home")
	for i in a.sectors.size():
		assert_eq(a.sectors[i].sector_seed, b.sectors[i].sector_seed, "Sector %d has the same seed" % i)


func test_every_sector_can_be_reached_from_home() -> void:
	for seed_value in [1, 2, 3, 99, 1234]:
		var galaxy := GalaxyData.generate(seed_value)
		assert_eq(galaxy.systems.size(), GalaxyData.SYSTEMS.size(), "Every system is there")
		for sector in galaxy.sectors:
			assert_gte(sector.tier, 0, "Seed %d: %s is reachable" % [seed_value, sector.name])
		assert_eq(galaxy.sectors[galaxy.home_id].tier, 0, "Home is tier 0")
		assert_eq(galaxy.sectors[galaxy.home_id].system_id, 0, "Home is in Ember Reach")


func test_the_frontier_is_next_to_your_territory() -> void:
	var galaxy := GalaxyData.generate(7)
	var owned := {galaxy.home_id: true}
	var frontier := galaxy.frontier(owned)
	assert_gt(frontier.size(), 0, "Somewhere to invade")
	for id in frontier:
		assert_true(galaxy.sectors[id].neighbors.has(galaxy.home_id), "Next to home")
		assert_eq(galaxy.sectors[id].tier, 1, "Tier 1")
	var far := -1
	for sector in galaxy.sectors:
		if sector.tier >= 3:
			far = sector.id
			break
	assert_false(galaxy.can_invade(far, owned), "Deep sectors are out of reach")


func test_conquering_a_sector_extends_the_frontier_and_systems_fall() -> void:
	var meta := MetaProgress.new()
	meta.galaxy_seed = 11
	var galaxy := meta.galaxy()
	assert_true(meta.conquered_set().has(galaxy.home_id), "Home starts lit")
	var target := meta.launch_sector()
	assert_eq(galaxy.sectors[target].tier, 1, "The first launch goes next door")
	var news := meta.relight_sector(target, Difficulty.DEFAULT)
	assert_true(bool(news["conquered"]), "Conquered")
	assert_true(meta.conquered.has(target), "Saved as conquered")
	assert_ne(meta.launch_sector(), target, "The next launch picks a new dark sector")
	var system_news := {}
	for id in galaxy.systems[0].sectors:
		if not meta.conquered_set().has(id):
			system_news = meta.relight_sector(id, Difficulty.DEFAULT)
	assert_eq(String(system_news.get("system", "")), "Ember Reach", "The home system falls")
	assert_almost_eq(meta.conquest_bonus(), MetaProgress.SYSTEM_REWARD_BONUS, 0.0001, "And pays a lasting reward bonus")


func test_conquered_sectors_can_be_replayed_but_deep_ones_cannot_be_picked() -> void:
	var meta := MetaProgress.new()
	meta.galaxy_seed = 13
	var galaxy := meta.galaxy()
	var target := meta.launch_sector()
	meta.relight_sector(target, Difficulty.DEFAULT)
	assert_true(meta.select_sector(target), "A conquered sector can be replayed")
	assert_false(meta.select_sector(galaxy.home_id), "Home isn't a battlefield")
	for sector in galaxy.sectors:
		if sector.tier >= 4:
			assert_false(meta.select_sector(sector.id), "Too deep to reach yet")
			break


func test_further_sectors_are_harder_and_pay_more() -> void:
	var near := Difficulty.for_sector(Difficulty.DEFAULT, 1)
	var far := Difficulty.for_sector(Difficulty.DEFAULT, 5)
	assert_gt(float(far["health"]), float(near["health"]), "Tougher Gloom further out")
	assert_gt(float(far["reward"]), float(near["reward"]), "Better rewards further out")
	assert_eq(int(near["roster"]), 0, "Tier 1 keeps the gentle roster")
	assert_gt(int(Difficulty.for_sector(Difficulty.DEFAULT, 7)["roster"]), 0, "Deep tiers bring tougher kinds sooner")


func test_system_themes_shape_their_sectors() -> void:
	var tuning := SpaceTuning.new()
	var nebulae := 0
	var nests := 0
	for seed_value in range(1, 9):
		var hollow := SectorGenerator.generate(seed_value * 31, tuning, GalaxyData.SYSTEMS[1]["theme"])
		var tangle := SectorGenerator.generate(seed_value * 31, tuning, GalaxyData.SYSTEMS[2]["theme"])
		for region in hollow.regions:
			if region.modifier == RegionData.Modifier.NEBULA:
				nebulae += 1
		for region in tangle.regions:
			if region.modifier == RegionData.Modifier.NEST:
				nests += 1
		for planet in tangle.planets:
			assert_true(planet.type == PlanetData.Type.VERDANT or planet.type == PlanetData.Type.FUNGAL, "Verdant Tangle grows green worlds")
	assert_gt(nebulae, 8, "Hollow Expanse is full of nebulae")
	assert_gt(nests, 8, "Verdant Tangle is full of nests")


func test_the_galaxy_survives_a_save() -> void:
	var meta := MetaProgress.new()
	meta.galaxy_seed = 21
	var target := meta.launch_sector()
	meta.relight_sector(target, Difficulty.DEFAULT)
	var loaded := MetaProgress.from_dict(JSON.parse_string(JSON.stringify(meta.to_dict())))
	assert_eq(loaded.galaxy_seed, 21, "Same galaxy")
	assert_true(loaded.conquered_set().has(target), "Conquests kept")
