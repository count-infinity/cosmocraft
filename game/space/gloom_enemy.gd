class_name GloomEnemy
extends Node2D
## A creature of the Gloom. One script covers every kind; each has its own
## stats, movement and silhouette. They're drawn to light, so they hunt the
## ship, and Snuffers go for the spark.

const BODY_COLOR := Color(0.02, 0.012, 0.035)
const GLOW_COLOR := Color(1.05, 0.35, 2.2)
const ELITE_COLOR := Color(2.4, 0.4, 0.9)

const KINDS := {
	"mite": {"hp": 2.0, "radius": 9.0, "speed": 215.0, "contact": 8.0, "spark_chance": 0.35, "sparks": 1},
	"dart": {"hp": 5.0, "radius": 13.0, "speed": 120.0, "contact": 14.0, "spark_chance": 1.0, "sparks": 1},
	"spitter": {"hp": 4.0, "radius": 12.0, "speed": 150.0, "contact": 10.0, "spark_chance": 1.0, "sparks": 1},
	"snuffer": {"hp": 28.0, "radius": 22.0, "speed": 85.0, "contact": 20.0, "spark_chance": 1.0, "sparks": 4},
}

const SPAWN_IN_TIME := 0.35
const DART_WINDUP := 0.55
const DART_CHARGE_TIME := 0.38
const DART_CHARGE_SPEED := 720.0
const SPITTER_NEAR := 300.0
const SPITTER_FAR := 440.0
const SPITTER_SHOT_SPEED := 270.0
const SPITTER_SHOT_DAMAGE := 10.0
const SPITTER_CHARGE_TIME := 0.45

var kind := "mite"
var elite := false
var hp := 1.0
var max_hp := 1.0
var radius := 10.0
var speed := 100.0
var contact_damage := 10.0
var spark_chance := 1.0
var spark_count := 1
var velocity := Vector2.ZERO
var dead := false
var age := 0.0

var _timer := 0.0
var _charging := false
var _charge_direction := Vector2.ZERO
var _winding_up := false
var _flash := 0.0
var _wobble := 0.0
var _orbit_sign := 1.0
var _outline := PackedVector2Array()
var _target_offset := Vector2.ZERO


func setup(p_kind: String, p_elite: bool, rng: RandomNumberGenerator) -> void:
	kind = p_kind
	elite = p_elite
	var stats: Dictionary = KINDS[kind]
	hp = stats["hp"]
	radius = stats["radius"]
	speed = float(stats["speed"]) * rng.randf_range(0.88, 1.12)
	contact_damage = stats["contact"]
	spark_chance = stats["spark_chance"]
	spark_count = stats["sparks"]
	if elite:
		hp *= 2.6
		radius *= 1.4
		speed *= 0.9
		spark_count = int(spark_count * 2.5)
	max_hp = hp
	_wobble = rng.randf() * TAU
	_orbit_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_timer = rng.randf_range(1.2, 2.6)
	_outline = _make_outline(rng)
	scale = Vector2.ONE * 0.3


func take_damage(amount: float) -> bool:
	if dead:
		return false
	hp -= amount
	_flash = 0.06
	return hp <= 0.0


func update(delta: float, game: SpaceGame) -> void:
	age += delta
	_flash = maxf(_flash - delta, 0.0)
	var spawn_progress := clampf(age / SPAWN_IN_TIME, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.3, 1.0, spawn_progress)
	match kind:
		"mite":
			_update_mite(delta, game.ship.position)
		"dart":
			_update_dart(delta, game.ship.position)
		"spitter":
			_update_spitter(delta, game)
		"snuffer":
			_update_snuffer(delta, game)
	position += velocity * delta
	modulate = Color(4.0, 4.0, 4.0) if _flash > 0.0 else Color(1.0, 1.0, 1.0, spawn_progress)
	if kind != "mite":
		queue_redraw()


func _steer(desired: Vector2, delta: float, responsiveness: float) -> void:
	velocity = velocity.lerp(desired, 1.0 - exp(-responsiveness * delta))


func _update_mite(delta: float, target: Vector2) -> void:
	var heading := (target - position).normalized().rotated(sin(age * 3.0 + _wobble) * 0.6)
	_steer(heading * speed, delta, 4.0)
	rotation = velocity.angle()


## Stalks, winds up (telegraphed with a line), then charges in a straight line.
func _update_dart(delta: float, target: Vector2) -> void:
	_timer -= delta
	if _charging:
		if _timer <= 0.0:
			_charging = false
			_timer = randf_range(1.6, 2.6)
		return
	if _winding_up:
		_steer(Vector2.ZERO, delta, 6.0)
		_charge_direction = (target - position).normalized()
		rotation = _charge_direction.angle()
		if _timer <= 0.0:
			_winding_up = false
			_charging = true
			_timer = DART_CHARGE_TIME
			velocity = _charge_direction * DART_CHARGE_SPEED
		return
	_steer((target - position).normalized() * speed, delta, 3.0)
	rotation = velocity.angle()
	if _timer <= 0.0 and age > SPAWN_IN_TIME:
		_winding_up = true
		_timer = DART_WINDUP


## Keeps its distance, circles, and lobs slow shots that glow before they fire.
func _update_spitter(delta: float, game: SpaceGame) -> void:
	var to_target := game.ship.position - position
	var distance := to_target.length()
	var direction := to_target / maxf(distance, 0.001)
	var desired := direction.orthogonal() * speed * _orbit_sign
	if distance > SPITTER_FAR:
		desired = direction * speed
	elif distance < SPITTER_NEAR:
		desired = -direction * speed
	_steer(desired, delta, 2.5)
	rotation = direction.angle()
	_timer -= delta
	if _timer <= 0.0 and age > SPAWN_IN_TIME and distance < SPITTER_FAR * 1.6:
		_timer = randf_range(1.6, 2.3)
		game.spawn_enemy_shot(position + direction * radius, direction * SPITTER_SHOT_SPEED, SPITTER_SHOT_DAMAGE)


## Ignores the ship and crawls toward the spark. Reaching it snuffs progress.
func _update_snuffer(delta: float, game: SpaceGame) -> void:
	var target := game.ship.position
	if game.kindle_spark != null:
		target = game.kindle_spark.position
	var to_target := target - position
	_steer(to_target.normalized() * speed, delta, 2.0)
	_target_offset = to_target / maxf(scale.x, 0.01)
	if game.kindle_spark != null and to_target.length() < radius + 12.0:
		game.on_snuffer_reached(self)


func _make_outline(rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	match kind:
		"mite":
			for i in 8:
				var reach := radius if i % 2 == 0 else radius * 0.45
				points.append(Vector2.from_angle(TAU * i / 8.0) * reach * rng.randf_range(0.9, 1.1))
		"dart":
			points = PackedVector2Array([
				Vector2(radius * 1.4, 0.0), Vector2(-radius, -radius * 0.8),
				Vector2(-radius * 0.4, 0.0), Vector2(-radius, radius * 0.8),
			])
		"spitter":
			for i in 9:
				var reach := radius if i % 3 != 0 else radius * 1.35
				points.append(Vector2.from_angle(TAU * i / 9.0) * reach)
		_:
			for i in 14:
				points.append(Vector2.from_angle(TAU * i / 14.0) * radius * rng.randf_range(0.82, 1.12))
	return points


func _draw() -> void:
	var glow := ELITE_COLOR if elite else GLOW_COLOR
	if kind == "snuffer":
		_draw_tether(glow)
	draw_colored_polygon(_outline, BODY_COLOR)
	var closed := _outline.duplicate()
	closed.append(_outline[0])
	draw_polyline(closed, glow, 3.0 if kind == "snuffer" else 2.0)
	match kind:
		"mite":
			draw_circle(Vector2.ZERO, 2.2, glow)
		"dart":
			draw_circle(Vector2(radius * 0.2, 0.0), 2.6, glow)
			if _winding_up:
				var warning := glow
				warning.a = 0.15 + 0.35 * (1.0 - _timer / DART_WINDUP)
				draw_line(Vector2(radius * 1.4, 0.0), Vector2(radius + 260.0, 0.0), warning, 2.0)
		"spitter":
			var charge := 1.0 - clampf(_timer / SPITTER_CHARGE_TIME, 0.0, 1.0)
			draw_circle(Vector2.ZERO, 3.5 + 3.5 * charge, glow)
		"snuffer":
			var pulse := 0.5 + 0.5 * sin(age * 5.0)
			draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 32, glow, 2.0)
			draw_circle(_target_offset.normalized() * radius * 0.35, radius * 0.18 + 2.0 * pulse, glow)


func _draw_tether(color: Color) -> void:
	var length := _target_offset.length()
	if length < 1.0:
		return
	var direction := _target_offset / length
	var faded := color
	faded.a = 0.28
	var distance := radius + 6.0 + fmod(age * 40.0, 24.0)
	while distance < length - 10.0:
		draw_line(direction * distance, direction * minf(distance + 12.0, length), faded, 2.0)
		distance += 24.0
