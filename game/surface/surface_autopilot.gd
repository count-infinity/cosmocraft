class_name SurfaceAutopilot
extends ShipInput
## Walks the pilot on its own: breaks a few deposits, opens caches on the way,
## retreats to the lander when hurt, heads for the vein, plants the pylon and
## circles it shooting whatever comes, then lifts off once the planet is
## kindled. Used for screenshots and smoke tests (--autoplay).

## Roughly what a player can see: the lantern's reach plus a little.
const FIRE_RANGE := 400.0
const NEST_RANGE := 400.0
## Aim is off by up to this much, re-rolled a few times a second, so the
## autopilot misses like a person and its runs say something about balance.
const AIM_WOBBLE := 22.0
const REPATH_SECONDS := 0.6
const ORBIT_RADIUS := 150.0
const DEPOSIT_RANGE := 260.0
const DEPOSIT_DETOUR := 1300.0
const MAX_DEPOSITS := 5
## Gives up on a deposit it can't break in this long (blocked, out of reach).
const DEPOSIT_PATIENCE := 14.0
const CACHE_DETOUR := 900.0
const EXPLORE_SECONDS := 110.0
const RETREAT_HEALTH := 0.3
const LIFTOFF_DELAY := 6.0

var _mission: SurfaceMission
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _firing := false
var _want_roll := false
var _want_kindle := false
var _want_flare := false
var _path := PackedVector2Array()
var _path_index := 0
var _path_goal := Vector2.INF
var _repath_left := 0.0
var _orbit := 0.0
var _explore_time := 0.0
var _retreating := false
var _kindled_time := 0.0
var _deposits_at_start := -1
var _wobble := Vector2.ZERO
var _wobble_left := 0.0
var _deposit: SurfaceMap.Deposit
var _deposit_time := 0.0
var _skipped: Array[SurfaceMap.Deposit] = []


func _init(mission: SurfaceMission) -> void:
	super(mission)
	_mission = mission


func think(delta: float) -> void:
	var pilot := _mission.pilot
	_firing = false
	if not pilot.alive:
		_move = Vector2.ZERO
		return
	if _deposits_at_start < 0:
		_deposits_at_start = _mission.map.deposits.size()
	_explore_time += delta
	_wobble_left -= delta
	if _wobble_left <= 0.0:
		_wobble_left = 0.25
		_wobble = Vector2.from_angle(randf() * TAU) * randf() * AIM_WOBBLE
	var goal := pilot.position
	match _mission.phase:
		SurfaceMission.Phase.KINDLED:
			_kindled_time += delta
			var site := _affordable_site(pilot)
			if site != null:
				goal = site.position
				if _mission.extractor_site() != null:
					_want_kindle = true
			elif _kindled_time > LIFTOFF_DELAY:
				_want_kindle = true
		SurfaceMission.Phase.SIEGE:
			_orbit += delta * 0.7
			goal = _mission.map.vein + Vector2.from_angle(_orbit) * ORBIT_RADIUS
		_:
			goal = _explore_goal(pilot)
	_walk_to(pilot, goal, delta)
	var enemy := _nearest_threat(pilot)
	if enemy != null:
		var distance := enemy.position.distance_to(pilot.position)
		_aim = enemy.position + enemy.velocity * 0.12 + _wobble
		_firing = true
		if distance < enemy.radius + 46.0:
			_want_roll = true
		if distance < 420.0 and _cluster_near(enemy.position) >= 4:
			_want_flare = true
		return
	var deposit := _deposit_in_reach(pilot)
	if deposit != null:
		_aim = deposit.position
		_firing = true
		if deposit == _deposit:
			_move = Vector2.ZERO
	elif _move != Vector2.ZERO:
		_aim = pilot.position + _move * 120.0


func get_move() -> Vector2:
	return _move


func get_aim_point() -> Vector2:
	return _aim


func is_firing() -> bool:
	return _firing


func consume_secondary() -> bool:
	var flare := _want_flare
	_want_flare = false
	return flare


func consume_dash() -> bool:
	var roll := _want_roll
	_want_roll = false
	return roll


func consume_kindle() -> bool:
	var kindle := _want_kindle
	_want_kindle = false
	return kindle


## Where to go while exploring: back to the lander when hurt, a few deposits
## and caches while there's time, then the vein.
func _explore_goal(pilot: Pilot) -> Vector2:
	var health := pilot.health / maxf(pilot.max_health, 1.0)
	if health < RETREAT_HEALTH:
		_retreating = true
	if _retreating:
		if health > 0.85:
			_retreating = false
		else:
			return pilot.position if _mission.at_lander() else _mission.map.landing
	if _explore_time < EXPLORE_SECONDS:
		var broken := _deposits_at_start - _intact_deposits()
		if _deposit != null and (not _deposit.is_intact() or _explore_time - _deposit_time > DEPOSIT_PATIENCE):
			if _deposit.is_intact():
				_skipped.append(_deposit)
			_deposit = null
		if _deposit == null and broken < MAX_DEPOSITS:
			_deposit = _nearest_deposit(pilot.position, DEPOSIT_DETOUR)
			_deposit_time = _explore_time
		if _deposit != null:
			return _deposit.position
		var shards := _mission.nearest_pickup(pilot.position, 700.0)
		if shards != Vector2.INF:
			return shards
		var cache := _nearest_cache(pilot.position, CACHE_DETOUR)
		if cache != null:
			return cache.position
	if _mission.near_vein():
		_want_kindle = true
	return _mission.map.vein


## Follows a grid path toward `goal`, or walks straight when nothing's in the way.
func _walk_to(pilot: Pilot, goal: Vector2, delta: float) -> void:
	var map := _mission.map
	var target := goal
	if map.segment_hits_rock(pilot.position, goal, pilot.radius + 4.0):
		_repath_left -= delta
		if _repath_left <= 0.0 or goal.distance_to(_path_goal) > 80.0 or _path.is_empty():
			_repath_left = REPATH_SECONDS
			_path_goal = goal
			_path = map.find_path(pilot.position, goal)
			_path_index = 0
		while _path_index < _path.size() - 1 and pilot.position.distance_to(_path[_path_index]) < 34.0:
			_path_index += 1
		if not _path.is_empty():
			target = _path[_path_index]
	else:
		_path = PackedVector2Array()
	var to_target := target - pilot.position
	_move = Vector2.ZERO if to_target.length() < 10.0 else (to_target / 60.0).limit_length(1.0)


func _nearest_threat(pilot: Pilot) -> GloomEnemy:
	var best: GloomEnemy = null
	var best_score := INF
	for enemy in _mission.battle.enemies:
		if enemy.dead:
			continue
		var distance := enemy.position.distance_to(pilot.position)
		var reach := NEST_RANGE if enemy.kind == "nest" else FIRE_RANGE
		if enemy.dormant:
			reach = 300.0
		if distance > reach or _mission.map.segment_hits_rock(pilot.position, enemy.position, 3.0):
			continue
		var score := distance * (0.3 if enemy.kind == "snuffer" else 1.0)
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _cluster_near(point: Vector2) -> int:
	var count := 0
	for enemy in _mission.battle.enemies:
		if not enemy.dead and not enemy.dormant and enemy.position.distance_to(point) < 140.0:
			count += 1
	return count


func _intact_deposits() -> int:
	var count := 0
	for deposit in _mission.map.deposits:
		if deposit.is_intact():
			count += 1
	return count


func _nearest_deposit(from: Vector2, reach: float) -> SurfaceMap.Deposit:
	var best: SurfaceMap.Deposit = null
	var best_distance := reach
	for deposit in _mission.map.deposits:
		if deposit.is_intact() and not _skipped.has(deposit) and deposit.position.distance_to(from) < best_distance:
			best_distance = deposit.position.distance_to(from)
			best = deposit
	return best


func _deposit_in_reach(pilot: Pilot) -> SurfaceMap.Deposit:
	var deposit := _nearest_deposit(pilot.position, DEPOSIT_RANGE)
	if deposit == null or _mission.map.segment_hits_rock(pilot.position, deposit.position, 3.0):
		return null
	return deposit


## The closest deposit site to build an extractor on, if the haul covers it.
func _affordable_site(pilot: Pilot) -> SurfaceMap.Deposit:
	if int(_mission.run.resources.get(_mission.resource(), 0)) < SurfaceMission.EXTRACTOR_COST:
		return null
	var best: SurfaceMap.Deposit = null
	var best_distance := INF
	for deposit in _mission.map.deposits:
		if not deposit.extractor and deposit.position.distance_to(pilot.position) < best_distance:
			best_distance = deposit.position.distance_to(pilot.position)
			best = deposit
	return best


func _nearest_cache(from: Vector2, reach: float) -> SurfaceMap.Cache:
	var best: SurfaceMap.Cache = null
	var best_distance := reach
	for cache in _mission.map.caches:
		if not cache.opened and cache.position.distance_to(from) < best_distance:
			best_distance = cache.position.distance_to(from)
			best = cache
	return best
