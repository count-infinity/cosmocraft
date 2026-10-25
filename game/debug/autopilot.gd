class_name Autopilot
extends ShipInput
## Flies the ship on its own: heads for the nearest frontier region, kindles
## it, then circles the spark shooting whatever is closest (Snuffers first).
## Used for screenshots, smoke tests and as an attract mode (--autoplay).

const ORBIT_RADIUS := 190.0
const KINDLE_DISTANCE := 120.0
const FIRE_RANGE := 900.0

var _game: SpaceGame
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _firing := false
var _want_dash := false
var _want_kindle := false
var _orbit := 0.0


func _init(game: SpaceGame) -> void:
	super(game)
	_game = game


func think(delta: float) -> void:
	var ship := _game.ship
	_firing = false
	if not ship.alive:
		_move = Vector2.ZERO
		return
	var planet := _awake_planet()
	if _game.claim == null and planet != null:
		_seek(ship, planet.position, planet.radius * 0.5)
	elif _game.claim == null:
		_seek_frontier(ship)
	else:
		_orbit += delta * 0.8
		var center := _game.kindle_spark.position if _game.kindle_spark != null else ship.position
		var goal := center + Vector2.from_angle(_orbit) * ORBIT_RADIUS
		_move = ((goal - ship.position) / 90.0).limit_length(1.0)
	var target := _game.nearest_enemy(ship.position)
	var heart := _game.heart_boss
	if heart != null and not heart.dead and not heart.shielded and heart.position.distance_to(ship.position) < FIRE_RANGE:
		var snuffer_close := target != null and target.kind == "snuffer" and target.position.distance_to(ship.position) < 350.0
		if not snuffer_close:
			target = heart
	if target != null:
		var distance := target.position.distance_to(ship.position)
		_aim = target.position + target.velocity * 0.15
		_firing = distance < FIRE_RANGE
		if distance < target.radius + 40.0:
			_want_dash = true


func get_move() -> Vector2:
	return _move


func get_aim_point() -> Vector2:
	return _aim


func is_firing() -> bool:
	return _firing


func consume_secondary() -> bool:
	return false


func consume_dash() -> bool:
	var dash := _want_dash
	_want_dash = false
	return dash


func consume_kindle() -> bool:
	var kindle := _want_kindle
	_want_kindle = false
	return kindle


## An awake planet waiting to be kindled, if there is one.
func _awake_planet() -> PlanetData:
	for planet in _game.sector.planets:
		if not planet.kindled and planet.is_awake(_game.sector):
			return planet
	return null


## Flies to a point and presses E once close (lands on planets).
func _seek(ship: Ship, point: Vector2, close_enough: float) -> void:
	var to_goal := point - ship.position
	_move = (to_goal / 150.0).limit_length(1.0)
	_aim = point
	if to_goal.length() < close_enough:
		_want_kindle = true


## The kindlable region nearest a point (used to push toward the heart).
func _closest_to(point: Vector2) -> RegionData:
	var best: RegionData = null
	var best_distance := INF
	for region in _game.sector.regions:
		if _game.can_kindle(region) and region.anchor.distance_to(point) < best_distance:
			best_distance = region.anchor.distance_to(point)
			best = region
	return best


func _seek_frontier(ship: Ship) -> void:
	var region := _game.nearest_frontier(ship.position)
	var heart := _game.sector.heart()
	if heart != null and not heart.claimed and _game.heart_claims_needed() == 0:
		region = heart if _game.can_kindle(heart) else _closest_to(heart.anchor)
	if region == null:
		_move = Vector2.ZERO
		return
	var to_goal := region.anchor - ship.position
	_move = (to_goal / 150.0).limit_length(1.0)
	_aim = region.anchor
	if to_goal.length() < KINDLE_DISTANCE and _game.sector.region_at(ship.position) == region.id:
		_want_kindle = true
