class_name Claim
extends RefCounted
## Progress of one siege: kindling a region and holding it until it ignites.
## Progress fills while the ship is inside the region, pauses for a grace
## period when it leaves, then drains. Sparks speed it up; Snuffers set it back.

enum State { ACTIVE, PAUSED, DRAINING, COMPLETE, FAILED }

const COMPLETE_AT := 0.99999

var region_id: int
var required_seconds: float
var progress := 0.0
var state := State.ACTIVE
var outside_time := 0.0
var sparks_collected := 0
## Claim time shaved off by sparks so far.
var spark_seconds := 0.0
var snuffs := 0
## Ship bonuses such as a Kindler Array (1.0 = no bonus).
var speed_scale := 1.0

var _tuning: SpaceTuning


func _init(p_region_id: int, p_required_seconds: float, tuning: SpaceTuning) -> void:
	region_id = p_region_id
	required_seconds = maxf(p_required_seconds, 1.0)
	_tuning = tuning


func update(delta: float, player_inside: bool) -> void:
	if is_over():
		return
	var rate := _tuning.claim_speed_multiplier * speed_scale / required_seconds
	if player_inside:
		outside_time = 0.0
		state = State.ACTIVE
		_add_progress(delta * rate)
		return
	outside_time += delta
	if outside_time <= _tuning.claim_grace_seconds:
		state = State.PAUSED
		return
	state = State.DRAINING
	progress -= delta * rate * _tuning.claim_drain_rate
	if progress <= 0.0:
		progress = 0.0
		state = State.FAILED


func add_spark() -> void:
	if is_over():
		return
	sparks_collected += 1
	spark_seconds += _tuning.spark_seconds
	_add_progress(_tuning.spark_seconds / required_seconds)


## A Snuffer reached the spark. Costs progress but never fails the claim outright.
func snuff() -> void:
	if is_over():
		return
	snuffs += 1
	progress = maxf(progress - _tuning.snuff_penalty, 0.0)


func fail() -> void:
	if not is_over():
		state = State.FAILED


func is_over() -> bool:
	return state == State.COMPLETE or state == State.FAILED


## Seconds left at the current fill rate, not counting sparks.
func seconds_remaining() -> float:
	return (1.0 - progress) * required_seconds / (_tuning.claim_speed_multiplier * speed_scale)


func _add_progress(amount: float) -> void:
	progress = minf(progress + amount, 1.0)
	if progress >= COMPLETE_AT:
		progress = 1.0
		state = State.COMPLETE
