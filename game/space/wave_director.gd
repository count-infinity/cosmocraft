class_name WaveDirector
extends RefCounted
## Decides what the Gloom throws at you during a claim. It earns credits over
## time (faster as progress climbs, and faster deeper into the dark), saves up
## for the next spawn card, then buys it, like Risk of Rain's director.

const CARDS: Array[Dictionary] = [
	{"kind": "mite", "cost": 4.0, "min_count": 4, "max_count": 6, "weight": 5.0, "min_progress": 0.0},
	{"kind": "dart", "cost": 3.0, "min_count": 1, "max_count": 2, "weight": 3.0, "min_progress": 0.12},
	{"kind": "spitter", "cost": 3.5, "min_count": 1, "max_count": 2, "weight": 2.2, "min_progress": 0.25},
	{"kind": "snuffer", "cost": 9.0, "min_count": 1, "max_count": 1, "weight": 1.3, "min_progress": 0.45},
]
const OPENING_MITES := 5
const ELITE_ESCORT_MITES := 8

var credits := 0.0
var threat := 1.0
var elite_sent := false

var _tuning: SpaceTuning
var _rng := RandomNumberGenerator.new()
var _next_card: Dictionary = {}
var _opened := false


func _init(tuning: SpaceTuning, p_threat: float = 1.0, rng_seed: int = 0) -> void:
	_tuning = tuning
	threat = p_threat
	_rng.seed = rng_seed


## Returns spawn requests shaped like {"kind": "mite", "count": 5, "elite": false}.
func update(delta: float, progress: float, alive: int, snuffers_alive: int) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	if not _opened:
		_opened = true
		spawns.append(_request("mite", OPENING_MITES))
		alive += OPENING_MITES

	var ramp := lerpf(_tuning.ramp_start, _tuning.ramp_end, clampf(progress, 0.0, 1.0))
	credits = minf(credits + delta * _tuning.credits_per_second * threat * ramp, _tuning.max_banked_credits)

	if not elite_sent and progress >= _tuning.elite_threshold:
		elite_sent = true
		spawns.append(_request("snuffer", 1, true))
		spawns.append(_request("mite", ELITE_ESCORT_MITES))
		return spawns

	while true:
		if _next_card.is_empty() or not _allowed(_next_card, progress, snuffers_alive):
			_next_card = _pick_card(progress, snuffers_alive)
			if _next_card.is_empty():
				break
		var cost: float = _next_card["cost"]
		if credits < cost:
			break
		var count := _rng.randi_range(_next_card["min_count"], _next_card["max_count"])
		if alive + count > _tuning.max_alive:
			break
		var kind: String = _next_card["kind"]
		credits -= cost
		alive += count
		if kind == "snuffer":
			snuffers_alive += count
		spawns.append(_request(kind, count))
		_next_card = {}
	return spawns


func _allowed(card: Dictionary, progress: float, snuffers_alive: int) -> bool:
	if progress < float(card["min_progress"]):
		return false
	return card["kind"] != "snuffer" or snuffers_alive < _tuning.max_snuffers


func _pick_card(progress: float, snuffers_alive: int) -> Dictionary:
	var total := 0.0
	for card in CARDS:
		if _allowed(card, progress, snuffers_alive):
			total += float(card["weight"])
	if total <= 0.0:
		return {}
	var roll := _rng.randf() * total
	for card in CARDS:
		if not _allowed(card, progress, snuffers_alive):
			continue
		roll -= float(card["weight"])
		if roll <= 0.0:
			return card
	return CARDS[0]


func _request(kind: String, count: int, elite := false) -> Dictionary:
	return {"kind": kind, "count": count, "elite": elite}
