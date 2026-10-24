extends GutTest

var tuning: SpaceTuning


func before_each() -> void:
	tuning = SpaceTuning.new()
	tuning.claim_grace_seconds = 3.0
	tuning.claim_drain_rate = 2.0
	tuning.spark_seconds = 0.5
	tuning.snuff_penalty = 0.15
	tuning.claim_speed_multiplier = 1.0


func _advance(claim: Claim, seconds: float, inside: bool, step := 0.1) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		claim.update(step, inside)
		elapsed += step


func test_starts_active_and_empty() -> void:
	var claim := Claim.new(3, 60.0, tuning)
	assert_eq(claim.state, Claim.State.ACTIVE, "Starts active")
	assert_eq(claim.progress, 0.0, "Starts empty")
	assert_eq(claim.region_id, 3, "Remembers its region")


func test_fills_over_the_required_time_while_inside() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 5.0, true)
	assert_almost_eq(claim.progress, 0.5, 0.001, "Half way after half the time")
	_advance(claim, 5.0, true)
	assert_eq(claim.state, Claim.State.COMPLETE, "Complete after the full time")
	assert_eq(claim.progress, 1.0, "Progress capped at 1")


func test_pauses_during_the_grace_period() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 4.0, true)
	_advance(claim, 2.0, false)
	assert_eq(claim.state, Claim.State.PAUSED, "Paused while briefly outside")
	assert_almost_eq(claim.progress, 0.4, 0.001, "No progress lost during grace")


func test_drains_after_the_grace_period() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 4.0, true)
	_advance(claim, 4.0, false)
	assert_eq(claim.state, Claim.State.DRAINING, "Draining once grace runs out")
	assert_almost_eq(claim.progress, 0.2, 0.025, "One second of draining at double speed")


func test_fails_when_drained_to_zero() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 1.0, true)
	_advance(claim, 4.0, false)
	assert_eq(claim.state, Claim.State.FAILED, "Fails once empty")
	assert_eq(claim.progress, 0.0, "Progress bottoms out at 0")


func test_returning_inside_restarts_the_grace_period() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 2.0, true)
	_advance(claim, 2.5, false)
	_advance(claim, 0.5, true)
	_advance(claim, 2.5, false)
	assert_eq(claim.state, Claim.State.PAUSED, "Grace restarts after re-entering")
	assert_almost_eq(claim.progress, 0.25, 0.001, "Only time inside counted")


func test_abandoning_a_fresh_claim_fails_it() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 3.5, false)
	assert_eq(claim.state, Claim.State.FAILED, "Leaving straight away fails after grace")


func test_sparks_add_progress() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	claim.add_spark()
	claim.add_spark()
	assert_almost_eq(claim.progress, 0.1, 0.0001, "Two half-second sparks on a 10s claim")
	assert_eq(claim.sparks_collected, 2, "Counts sparks")


func test_sparks_can_complete_a_claim() -> void:
	var claim := Claim.new(0, 2.0, tuning)
	for i in 4:
		claim.add_spark()
	assert_eq(claim.state, Claim.State.COMPLETE, "Enough sparks finish the claim")


func test_snuffing_costs_progress_but_never_fails() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 2.0, true)
	claim.snuff()
	assert_almost_eq(claim.progress, 0.05, 0.001, "Loses the snuff penalty")
	claim.snuff()
	assert_eq(claim.progress, 0.0, "Never below zero")
	assert_false(claim.is_over(), "Snuffing alone doesn't end the claim")


func test_nothing_changes_once_over() -> void:
	var claim := Claim.new(0, 1.0, tuning)
	_advance(claim, 1.0, true)
	claim.snuff()
	claim.update(5.0, false)
	claim.add_spark()
	assert_eq(claim.state, Claim.State.COMPLETE, "Stays complete")
	assert_eq(claim.progress, 1.0, "Progress frozen")


func test_fail_ends_the_claim() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	claim.fail()
	assert_eq(claim.state, Claim.State.FAILED, "Failed")
	assert_true(claim.is_over(), "Over")


func test_speed_multiplier_shortens_claims() -> void:
	tuning.claim_speed_multiplier = 4.0
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 2.5, true)
	assert_eq(claim.state, Claim.State.COMPLETE, "A 10s claim at 4x takes 2.5s")


func test_seconds_remaining() -> void:
	var claim := Claim.new(0, 10.0, tuning)
	_advance(claim, 4.0, true)
	assert_almost_eq(claim.seconds_remaining(), 6.0, 0.001, "Six seconds left")
