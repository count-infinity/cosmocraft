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
		assert_false(spawn["elite"], "The elite only arrives once")


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
