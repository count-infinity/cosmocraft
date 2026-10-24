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
	if _game.claim == null:
		_seek_frontier(ship)
	else:
		_orbit += delta * 0.8
		var center := _game.kindle_spark.position if _game.kindle_spark != null else ship.position
		var goal := center + Vector2.from_angle(_orbit) * ORBIT_RADIUS
		_move = ((goal - ship.position) / 90.0).limit_length(1.0)
	var target := _game.nearest_enemy(ship.position)
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


func consume_dash() -> bool:
	var dash := _want_dash
	_want_dash = false
	return dash


func consume_kindle() -> bool:
	var kindle := _want_kindle
	_want_kindle = false
	return kindle


func _seek_frontier(ship: Ship) -> void:
	var region := _game.nearest_frontier(ship.position)
	if region == null:
		_move = Vector2.ZERO
		return
	var to_goal := region.centroid - ship.position
	_move = (to_goal / 150.0).limit_length(1.0)
	_aim = region.centroid
	if to_goal.length() < KINDLE_DISTANCE and _game.sector.region_at(ship.position) == region.id:
		_want_kindle = true
