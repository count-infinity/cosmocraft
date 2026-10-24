class_name Ship
extends Node2D
## The player's Kindler: twin-stick movement with a little drift, a rapid-fire
## blaster, and a dash with invulnerability frames. Shields soak damage first.
## SpaceGame calls regen() only while the ship is inside claimed territory.

signal fired(origin: Vector2, direction: Vector2)
signal dashed(origin: Vector2, direction: Vector2)
signal damaged(amount: float, hull_hit: bool)
signal destroyed

const RADIUS := 11.0
const SHAPE: Array[Vector2] = [Vector2(17, 0), Vector2(-11, -11), Vector2(-6, 0), Vector2(-11, 11)]
const HULL_COLOR := Color(0.05, 0.045, 0.075)
const TRIM_COLOR := Color(2.0, 1.45, 0.6)
const ENGINE_COLOR := Color(2.2, 1.0, 0.3)
const SHIELD_COLOR := Color(0.45, 1.0, 1.6)

var tuning: SpaceTuning
var input: ShipInput
var velocity := Vector2.ZERO
var aim_direction := Vector2.RIGHT
var shield := 0.0
var hull := 0.0
var alive := true

var _dash_left := 0.0
var _dash_cooldown_left := 0.0
var _fire_cooldown := 0.0
var _invulnerable_left := 0.0
var _since_damage := 99.0
var _thrust := 0.0
var _shield_flash := 0.0
var _time := 0.0


func reset_at(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	shield = tuning.max_shield
	hull = tuning.max_hull
	alive = true
	visible = true
	_dash_left = 0.0
	_dash_cooldown_left = 0.0
	_fire_cooldown = 0.0
	_since_damage = 99.0


func grant_iframes(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func dash_readiness() -> float:
	return 1.0 - _dash_cooldown_left / maxf(tuning.dash_cooldown, 0.001)


func update(delta: float) -> void:
	if not alive:
		return
	_time += delta
	var move := input.get_move().limit_length(1.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	if _dash_left <= 0.0:
		var rate := tuning.ship_accel if move != Vector2.ZERO else tuning.ship_decel
		velocity = velocity.move_toward(move * tuning.ship_max_speed, rate * delta)
	position += velocity * delta

	var to_aim := input.get_aim_point() - position
	if to_aim.length_squared() > 16.0:
		aim_direction = to_aim.normalized()
	rotation = aim_direction.angle()

	_fire_cooldown = maxf(_fire_cooldown - delta, -0.05)
	if input.is_firing() and _fire_cooldown <= 0.0:
		_fire_cooldown += 1.0 / tuning.fire_rate
		var spread := deg_to_rad(randf_range(-tuning.bullet_spread_degrees, tuning.bullet_spread_degrees))
		fired.emit(position + aim_direction * 16.0, aim_direction.rotated(spread))

	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	if input.consume_dash() and _dash_cooldown_left <= 0.0:
		var direction := move.normalized() if move != Vector2.ZERO else aim_direction
		velocity = direction * tuning.dash_speed
		_dash_left = tuning.dash_duration
		_dash_cooldown_left = tuning.dash_cooldown
		grant_iframes(tuning.dash_iframes)
		dashed.emit(position, direction)

	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_since_damage += delta
	_thrust = lerpf(_thrust, move.length(), 1.0 - exp(-10.0 * delta))
	_shield_flash = maxf(_shield_flash - delta * 3.0, 0.0)
	var blinking := _invulnerable_left > 0.0 and _dash_left <= 0.0 and fmod(_invulnerable_left, 0.14) < 0.07
	modulate.a = 0.4 if blinking else 1.0
	queue_redraw()


func regen(delta: float) -> void:
	if not alive or _since_damage < tuning.regen_delay:
		return
	shield = minf(shield + tuning.shield_regen * delta, tuning.max_shield)
	hull = minf(hull + tuning.hull_regen * delta, tuning.max_hull)


## Returns true if the hit landed (it didn't land during invulnerability).
func take_damage(amount: float) -> bool:
	if not alive or _invulnerable_left > 0.0:
		return false
	_since_damage = 0.0
	var absorbed := minf(shield, amount)
	shield -= absorbed
	var through := amount - absorbed
	hull -= through
	_shield_flash = 1.0 if absorbed > 0.0 else 0.0
	grant_iframes(tuning.hit_iframes)
	damaged.emit(amount, through > 0.0)
	if hull <= 0.0:
		hull = 0.0
		alive = false
		visible = false
		destroyed.emit()
	return true


func _draw() -> void:
	var flame := (6.0 + 16.0 * _thrust + (16.0 if _dash_left > 0.0 else 0.0)) * (0.85 + 0.15 * sin(_time * 40.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -4), Vector2(-7.0 - flame, 0), Vector2(-7, 4)]), ENGINE_COLOR)
	var outline := PackedVector2Array(SHAPE)
	draw_colored_polygon(outline, HULL_COLOR)
	outline.append(SHAPE[0])
	draw_polyline(outline, TRIM_COLOR, 2.0)
	draw_circle(Vector2(3, 0), 2.5, TRIM_COLOR)
	if shield > 0.0:
		var shield_color := SHIELD_COLOR
		shield_color.a = 0.1 + 0.25 * shield / tuning.max_shield + 0.6 * _shield_flash
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 40, shield_color, 1.5)
