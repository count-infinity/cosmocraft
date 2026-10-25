class_name AssaultAutopilot
extends ShipInput
## Flies a planet assault on its own: holds a lane above the terrain, weaves
## away from incoming shots, shoots whatever's ahead (fliers first when
## they're close), torpedoes the bastion once its shield is down. Used for
## screenshots and smoke tests (--autoplay).

const LANE_X := 330.0
const BASTION_LANE_X := 420.0
const FIRE_RANGE := 950.0
const DODGE_RANGE := 150.0

var _mission: AssaultMission
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _firing := false
var _want_dash := false
var _want_secondary := false


func _init(mission: AssaultMission) -> void:
	super(mission)
	_mission = mission


func think(_delta: float) -> void:
	var ship := _mission.ship
	_firing = false
	if not ship.alive:
		_move = Vector2.ZERO
		return
	var lane_x := _mission.scroll + (BASTION_LANE_X if _mission.in_bastion_phase() else LANE_X)
	var floor := _mission.ground_y(ship.position.x)
	var lane_y := clampf(floor - 200.0 + sin(_mission._time * 0.9) * 70.0, 90.0, floor - 70.0)
	var dodge := Vector2.ZERO
	for threat in _mission.threats_near(ship.position, DODGE_RANGE):
		var away := ship.position - threat
		dodge += away.normalized() * (DODGE_RANGE - away.length()) / DODGE_RANGE
		if away.length() < 40.0:
			_want_dash = true
	_move = ((Vector2(lane_x, lane_y) - ship.position) / 120.0 + dodge * 1.6).limit_length(1.0)
	var target := _pick_target(ship)
	if target != null:
		_aim = target.position + target.velocity * 0.12
		_firing = true
		if target.position.distance_to(ship.position) < target.radius + 50.0:
			_want_dash = true
	if _mission.bastion_alive() and not _mission.bastion.shielded and _mission.in_view(_mission.bastion.position):
		_want_secondary = true


## The closest flier within 320, otherwise the nearest thing ahead.
func _pick_target(ship: Ship) -> GloomEnemy:
	var best: GloomEnemy = null
	var best_score := INF
	for enemy in _mission.battle.enemies:
		if enemy.dead or enemy.shielded or enemy.position.x < ship.position.x - 120.0:
			continue
		var distance := enemy.position.distance_to(ship.position)
		if distance > FIRE_RANGE:
			continue
		var score := distance if enemy.is_static() else distance * 0.5
		if score < best_score:
			best_score = score
			best = enemy
	return best


func get_move() -> Vector2:
	return _move


func get_aim_point() -> Vector2:
	return _aim


func is_firing() -> bool:
	return _firing


func consume_secondary() -> bool:
	var fire := _want_secondary
	_want_secondary = false
	return fire


func consume_dash() -> bool:
	var dash := _want_dash
	_want_dash = false
	return dash


func consume_kindle() -> bool:
	return false
