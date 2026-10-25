extends GutTest

var tuning: SpaceTuning


func before_each() -> void:
	tuning = SpaceTuning.new()


func _total(spawns: Array[Dictionary], kind := "") -> int:
	var total := 0
	for spawn in spawns:
		if kind.is_empty() or spawn["kind"] == kind:
			total += int(spawn["count"])
	return total


func _run(director: WaveDirector, seconds: float, progress: float, alive := 0) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var elapsed := 0.0
	while elapsed < seconds:
		spawns.append_array(director.update(0.1, progress, alive, 0))
		elapsed += 0.1
	return spawns


func test_opens_with_a_mite_pack() -> void:
	var director := WaveDirector.new(tuning, 1.0, 1)
	var spawns := director.update(0.016, 0.0, 0, 0)
	assert_eq(_total(spawns, "mite"), WaveDirector.OPENING_MITES, "First update sends the opening pack")


func test_no_snuffers_before_their_threshold() -> void:
	var spawns := _run(WaveDirector.new(tuning, 1.0, 2), 120.0, 0.3)
	assert_eq(_total(spawns, "snuffer"), 0, "Snuffers wait for later in the claim")
	assert_gt(_total(spawns), 0, "Other enemies still come")


func test_snuffers_appear_later_in_the_claim() -> void:
	var spawns := _run(WaveDirector.new(tuning, 1.0, 3), 120.0, 0.7)
	assert_gt(_total(spawns, "snuffer"), 0, "Snuffers show up past their threshold")


func test_elite_arrives_once_at_the_threshold() -> void:
	var director := WaveDirector.new(tuning, 1.0, 4)
	director.update(0.1, 0.5, 0, 0)
	var elites := 0
	for spawn in director.update(0.1, tuning.elite_threshold, 0, 0):
		if spawn["elite"]:
			elites += 1
	assert_eq(elites, 1, "One elite at the threshold")
	for spawn in _run(director, 10.0, 0.95):
		assert_false(spawn.get("climax", false), "The climax Snuffer only arrives once")


func test_respects_max_alive() -> void:
	var director := WaveDirector.new(tuning, 1.0, 5)
	director.update(0.1, 0.5, 0, 0)
	var spawns := _run(director, 60.0, 0.5, tuning.max_alive)
	assert_eq(_total(spawns), 0, "Nothing spawns while the field is full")


func test_pressure_ramps_with_progress() -> void:
	var early := _total(_run(WaveDirector.new(tuning, 1.0, 6), 60.0, 0.05))
	var late := _total(_run(WaveDirector.new(tuning, 1.0, 6), 60.0, 0.85))
	assert_gt(late, early, "Later in the claim means more enemies")


func test_threat_increases_pressure() -> void:
	var calm := _total(_run(WaveDirector.new(tuning, 1.0, 7), 60.0, 0.5))
	var deep := _total(_run(WaveDirector.new(tuning, 2.0, 7), 60.0, 0.5))
	assert_gt(deep, calm, "Deeper regions send more")


func test_same_seed_same_waves() -> void:
	var a := _run(WaveDirector.new(tuning, 1.0, 8), 30.0, 0.5)
	var b := _run(WaveDirector.new(tuning, 1.0, 8), 30.0, 0.5)
	assert_eq(a, b, "Deterministic for a given seed")


func _kinds(spawns: Array[Dictionary]) -> Dictionary:
	var kinds := {}
	for spawn in spawns:
		kinds[spawn["kind"]] = true
	return kinds


func test_the_first_ring_only_sends_mites_and_darts() -> void:
	var kinds := _kinds(_run(WaveDirector.new(tuning, 1.0, 9, 1), 180.0, 0.8))
	for kind: String in kinds:
		assert_true(kind == "mite" or kind == "dart", "Depth 1 sent %s" % kind)
	assert_eq(WaveDirector.kinds_at(1), ["mite", "dart"] as Array[String], "The first ring's roster")


func test_tougher_gloom_waits_for_deeper_regions() -> void:
	var middle := _kinds(_run(WaveDirector.new(tuning, 1.5, 10, 2), 240.0, 0.8))
	assert_false(middle.has("carapace") or middle.has("lancer"), "No carapaces or lancers a step from home")
	assert_true(WaveDirector.kinds_at(3).has("carapace"), "Carapaces further out")
	assert_eq(WaveDirector.kinds_new_at(3, 2), ["carapace", "lancer"] as Array[String], "What's new at depth 3")
	assert_eq(WaveDirector.kinds_new_at(2, 2), [] as Array[String], "Nothing new at a depth you've already held")


func test_the_climax_snuffer_is_plain_near_home_and_elite_further_out() -> void:
	for depth in [1, 3]:
		var director := WaveDirector.new(tuning, 1.0, 11, depth)
		director.update(0.1, 0.5, 0, 0)
		var climax: Dictionary = {}
		for spawn in director.update(0.1, tuning.elite_threshold, 0, 0):
			if spawn.get("climax", false):
				climax = spawn
		assert_eq(String(climax.get("kind", "")), "snuffer", "Depth %d climax is a Snuffer" % depth)
		assert_eq(bool(climax.get("elite", false)), depth >= WaveDirector.ELITE_DEPTH, "Elite only from depth %d" % WaveDirector.ELITE_DEPTH)


func test_the_deepest_regions_send_some_elites() -> void:
	var elites := 0
	for spawn in _run(WaveDirector.new(tuning, 2.0, 12, 4), 300.0, 0.8):
		if spawn["elite"] and not spawn.get("climax", false):
			elites += 1
	assert_gt(elites, 0, "Elites mixed into regular waves at depth 4")


func test_threat_and_health_grow_with_depth() -> void:
	assert_lt(tuning.threat_for(1), tuning.threat_for(3), "More pressure further out")
	assert_lt(tuning.health_scale(1), 1.0, "Weaker Gloom next to home")
	assert_gt(tuning.health_scale(4), 1.0, "Tougher Gloom deep in the dark")
