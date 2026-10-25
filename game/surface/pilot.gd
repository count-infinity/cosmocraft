class_name Pilot
extends Node2D
## The lamplighter on foot: twin-stick movement, a dodge roll with
## invulnerability frames, a sidearm and flares (fired through WeaponSystem),
## and a lantern. A barrier soaks damage before health; it only recharges in
## light, and health only recovers at the lander.

signal rolled(origin: Vector2, direction: Vector2)
signal damaged(amount: float, health_hit: bool)
signal destroyed

const BODY_COLOR := Color(0.07, 0.06, 0.09)
const TRIM_COLOR := Color(1.9, 1.45, 0.75)
const VISOR_COLOR := Color(0.55, 1.6, 2.4)
const LANTERN_COLOR := Color(2.8, 2.0, 0.9)
const BARRIER_COLOR := Color(0.45, 1.0, 1.6)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.45)
## The figure is drawn bigger than its hit circle so it reads at a glance.
const SPRITE_SCALE := 1.4

var tuning: SurfaceTuning
var input: ShipInput
var velocity := Vector2.ZERO
var aim_direction := Vector2.RIGHT
var radius := 11.0
var max_health := 100.0
var max_barrier := 40.0
var health := 100.0
var barrier := 40.0
var alive := true
## How much a hazard is slowing the pilot this frame (0 to 1).
var slow := 0.0

var _roll_left := 0.0
var _roll_cooldown_left := 0.0
var _roll_direction := Vector2.RIGHT
var _invulnerable_left := 0.0
var _since_damage := 99.0
var _time := 0.0
var _stride := 0.0
var _barrier_flash := 0.0


func setup(p_tuning: SurfaceTuning, bonus_health := 0.0, bonus_barrier := 0.0) -> void:
	tuning = p_tuning
	max_health = tuning.pilot_health + bonus_health
	max_barrier = tuning.pilot_barrier + bonus_barrier
	health = max_health
	barrier = max_barrier


func reset_at(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	health = max_health
	barrier = max_barrier
	alive = true
	visible = true
	_roll_left = 0.0
	_roll_cooldown_left = 0.0
	_since_damage = 99.0


func grant_iframes(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func roll_readiness() -> float:
	return 1.0 - _roll_cooldown_left / maxf(tuning.roll_cooldown, 0.001)


func is_rolling() -> bool:
	return _roll_left > 0.0


func update(delta: float) -> void:
	if not alive:
		return
	_time += delta
	var move := input.get_move().limit_length(1.0)
	_roll_left = maxf(_roll_left - delta, 0.0)
	if _roll_left <= 0.0:
		var top_speed := tuning.pilot_speed * (1.0 - slow)
		var rate := tuning.pilot_accel if move != Vector2.ZERO else tuning.pilot_decel
		velocity = velocity.move_toward(move * top_speed, rate * delta)
	position += velocity * delta

	var to_aim := input.get_aim_point() - position
	if to_aim.length_squared() > 16.0:
		aim_direction = to_aim.normalized()
	rotation = aim_direction.angle()

	_roll_cooldown_left = maxf(_roll_cooldown_left - delta, 0.0)
	if input.consume_dash() and _roll_cooldown_left <= 0.0:
		_roll_direction = move.normalized() if move != Vector2.ZERO else aim_direction
		velocity = _roll_direction * tuning.roll_speed
		_roll_left = tuning.roll_duration
		_roll_cooldown_left = tuning.roll_cooldown
		grant_iframes(tuning.roll_iframes)
		rolled.emit(position, _roll_direction)

	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_since_damage += delta
	_stride += velocity.length() * delta * 0.06
	_barrier_flash = maxf(_barrier_flash - delta * 3.0, 0.0)
	var blinking := _invulnerable_left > 0.0 and _roll_left <= 0.0 and fmod(_invulnerable_left, 0.14) < 0.07
	modulate.a = 0.45 if blinking else 1.0
	queue_redraw()


## Recharge while standing in light: the barrier always, health only where
## `health_rate` is above zero (at the lander).
func regen(delta: float, barrier_rate: float, health_rate := 0.0) -> void:
	if not alive or _since_damage < tuning.regen_delay:
		return
	barrier = minf(barrier + barrier_rate * delta, max_barrier)
	health = minf(health + health_rate * delta, max_health)


func heal_full() -> void:
	health = max_health
	barrier = max_barrier


## Returns true if the hit landed (it doesn't during invulnerability).
func take_damage(amount: float) -> bool:
	if not alive or _invulnerable_left > 0.0:
		return false
	_since_damage = 0.0
	var absorbed := minf(barrier, amount)
	barrier -= absorbed
	var through := amount - absorbed
	health -= through
	_barrier_flash = 1.0 if absorbed > 0.0 else 0.0
	grant_iframes(tuning.hit_iframes)
	damaged.emit(amount, through > 0.0)
	if health <= 0.0:
		health = 0.0
		alive = false
		visible = false
		destroyed.emit()
	return true


func _draw() -> void:
	var rolling := _roll_left > 0.0
	draw_set_transform(Vector2(3.0, 5.0).rotated(-rotation), 0.0, Vector2.ONE * SPRITE_SCALE)
	draw_circle(Vector2.ZERO, 10.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, (Vector2(0.75, 1.15) if rolling else Vector2.ONE) * SPRITE_SCALE)
	# Boots swing while walking.
	var swing := sin(_stride) * 4.5 * clampf(velocity.length() / 120.0, 0.0, 1.0)
	draw_circle(Vector2(swing, -4.5), 3.0, BODY_COLOR)
	draw_circle(Vector2(-swing, 4.5), 3.0, BODY_COLOR)
	# Pack, body and visor.
	draw_rect(Rect2(-11.0, -5.5, 6.0, 11.0), BODY_COLOR)
	draw_rect(Rect2(-11.0, -5.5, 6.0, 11.0), TRIM_COLOR * 0.6, false, 1.0)
	draw_circle(Vector2.ZERO, 9.0, BODY_COLOR)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, TRIM_COLOR, 1.6)
	draw_arc(Vector2.ZERO, 6.0, -0.8, 0.8, 12, VISOR_COLOR, 2.6)
	# Sidearm and lantern.
	draw_line(Vector2(4.0, 5.0), Vector2(15.0, 5.0), TRIM_COLOR, 2.5)
	var lantern := Vector2(-2.0, -11.0) + Vector2(0.0, sin(_stride * 0.5) * 1.2)
	draw_circle(lantern, 5.5, Color(LANTERN_COLOR, 0.25))
	draw_circle(lantern, 2.6, LANTERN_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if barrier > 0.0:
		var color := BARRIER_COLOR
		color.a = 0.08 + 0.22 * barrier / maxf(max_barrier, 1.0) + 0.6 * _barrier_flash
		draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 32, color, 1.6)
