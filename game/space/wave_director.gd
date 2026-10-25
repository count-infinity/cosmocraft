class_name WaveDirector
extends RefCounted
## Decides what the Gloom throws at you during a claim. It earns credits over
## time (faster as progress climbs, and faster deeper into the dark), saves up
## for the next spawn card, then buys it, like Risk of Rain's director.
##
## Which Gloom can come depends on how deep the claim is: the first ring
## around home only sends mites and darts (and one plain Snuffer at the
## climax); spitters, broods and Snuffers join a step deeper; carapaces and
## lancers further out still.

const CARDS: Array[Dictionary] = [
	{"kind": "mite", "cost": 4.0, "min_count": 4, "max_count": 6, "weight": 5.0, "min_progress": 0.0, "depth": 1},
	{"kind": "dart", "cost": 3.0, "min_count": 1, "max_count": 2, "weight": 3.0, "min_progress": 0.12, "depth": 1},
	{"kind": "brood", "cost": 5.0, "min_count": 1, "max_count": 2, "weight": 1.8, "min_progress": 0.2, "depth": 2},
	{"kind": "spitter", "cost": 3.5, "min_count": 1, "max_count": 2, "weight": 2.2, "min_progress": 0.25, "depth": 2},
	{"kind": "carapace", "cost": 5.0, "min_count": 1, "max_count": 2, "weight": 1.6, "min_progress": 0.3, "depth": 3},
	{"kind": "lancer", "cost": 4.5, "min_count": 1, "max_count": 1, "weight": 1.4, "min_progress": 0.35, "depth": 3},
	{"kind": "snuffer", "cost": 9.0, "min_count": 1, "max_count": 1, "weight": 1.3, "min_progress": 0.45, "depth": 2},
]
const OPENING_MITES := 5
const ELITE_ESCORT_MITES := 8
## Near home the climax is a plain Snuffer with a smaller escort.
const PLAIN_ESCORT_MITES := 5
## The climax Snuffer is an elite from this depth on.
const ELITE_DEPTH := 3
## Regular spawns can come as elites from this depth on.
const DEEP_DEPTH := 4

var credits := 0.0
var threat := 1.0
var elite_sent := false

var _tuning: SpaceTuning
var _rng := RandomNumberGenerator.new()
var _next_card: Dictionary = {}
var _opened := false
var _depth := 99
var _pace := 1.0
var _alive_cap := 0


## `depth` decides which Gloom can come and how many may be alive at once
## (leave it out to allow everything); `pace` scales the credit rate, lower
## for long claims.
func _init(tuning: SpaceTuning, p_threat: float = 1.0, rng_seed: int = 0, depth: int = 99, pace: float = 1.0) -> void:
	_tuning = tuning
	threat = p_threat
	_rng.seed = rng_seed
	_depth = depth
	_pace = pace
	_alive_cap = tuning.alive_cap(depth)


## Every kind that can come in a claim `depth` steps from home.
static func kinds_at(depth: int) -> Array[String]:
	var kinds: Array[String] = []
	for card in CARDS:
		if depth >= int(card["depth"]):
			kinds.append(String(card["kind"]))
	return kinds


## Kinds that first show up at `depth` compared with `previous_depth`.
static func kinds_new_at(depth: int, previous_depth: int) -> Array[String]:
	var known := kinds_at(previous_depth)
	var fresh: Array[String] = []
	for kind in kinds_at(depth):
		if not known.has(kind):
			fresh.append(kind)
	return fresh


## Returns spawn requests shaped like {"kind": "mite", "count": 5, "elite": false}.
## The Snuffer sent at the elite threshold also carries "climax": true.
func update(delta: float, progress: float, alive: int, snuffers_alive: int) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	if not _opened:
		_opened = true
		spawns.append(_request("mite", OPENING_MITES))
		alive += OPENING_MITES

	var ramp := lerpf(_tuning.ramp_start, _tuning.ramp_end, clampf(progress, 0.0, 1.0))
	credits = minf(credits + delta * _tuning.credits_per_second * threat * ramp * _pace, _tuning.max_banked_credits)

	if not elite_sent and progress >= _tuning.elite_threshold:
		elite_sent = true
		var elite := _depth >= ELITE_DEPTH
		var climax := _request("snuffer", 1, elite)
		climax["climax"] = true
		spawns.append(climax)
		spawns.append(_request("mite", ELITE_ESCORT_MITES if elite else PLAIN_ESCORT_MITES))
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
		if alive + count > _alive_cap:
			break
		var kind: String = _next_card["kind"]
		credits -= cost
		alive += count
		if kind == "snuffer":
			snuffers_alive += count
		if _depth >= DEEP_DEPTH and kind != "snuffer" and _rng.randf() < _tuning.deep_elite_chance:
			spawns.append(_request(kind, ceili(count * 0.5), true))
		else:
			spawns.append(_request(kind, count))
		_next_card = {}
	return spawns


func _allowed(card: Dictionary, progress: float, snuffers_alive: int) -> bool:
	if progress < float(card["min_progress"]) or _depth < int(card["depth"]):
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
