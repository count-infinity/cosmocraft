class_name GloomEnemy
extends Node2D
## A creature of the Gloom. One script covers every kind; each has its own
## stats, movement and silhouette. They're drawn to light, so they hunt the
## ship, and Snuffers go for the spark.
##
## Kinds: mite (swarmer), dart (charger), spitter (lobs shots), snuffer (goes
## for the spark), carapace (armored front), brood (bursts into mites), lancer
## (telegraphed sniper), heart (the run's boss), nest (a planet-surface spawner).
## A planet assault adds growths rooted in the ground (spore turret, thorn
## battery, hive, and the bastion with its pods) and skimmers that swoop
## across the sky in waves.
##
## The host is whatever mode owns the enemy (SpaceGame or SurfaceMission). It
## provides target_position(), has_objective(), objective_position(),
## route_to() (a waypoint toward a goal that avoids obstacles), nests_awake(),
## spawn_enemy_shot(), spawn_minions() and on_snuffer_reached().

const BODY_COLOR := Color(0.02, 0.012, 0.035)
const GLOW_COLOR := Color(1.05, 0.35, 2.2)
const ELITE_COLOR := Color(2.4, 0.4, 0.9)
const ARMOR_COLOR := Color(1.8, 1.0, 2.6)
const HEART_COLOR := Color(2.6, 0.25, 0.5)

const KINDS := {
	"mite": {"name": "Mites", "hp": 2.0, "radius": 9.0, "speed": 215.0, "contact": 8.0, "spark_chance": 0.7, "sparks": 1},
	"dart": {"name": "Darts", "hp": 5.0, "radius": 13.0, "speed": 120.0, "contact": 14.0, "spark_chance": 1.0, "sparks": 2},
	"spitter": {"name": "Spitters", "hp": 4.0, "radius": 12.0, "speed": 150.0, "contact": 10.0, "spark_chance": 1.0, "sparks": 2},
	"snuffer": {"name": "Snuffers", "hp": 28.0, "radius": 22.0, "speed": 85.0, "contact": 20.0, "spark_chance": 1.0, "sparks": 5},
	"carapace": {"name": "Carapaces", "hp": 12.0, "radius": 17.0, "speed": 80.0, "contact": 16.0, "spark_chance": 1.0, "sparks": 3},
	"brood": {"name": "Broods", "hp": 7.0, "radius": 15.0, "speed": 100.0, "contact": 12.0, "spark_chance": 1.0, "sparks": 1},
	"lancer": {"name": "Lancers", "hp": 4.0, "radius": 11.0, "speed": 150.0, "contact": 8.0, "spark_chance": 1.0, "sparks": 2},
	"heart": {"name": "The Heart", "hp": 260.0, "radius": 58.0, "speed": 0.0, "contact": 30.0, "spark_chance": 1.0, "sparks": 40},
	"nest": {"name": "Nests", "hp": 24.0, "radius": 26.0, "speed": 0.0, "contact": 12.0, "spark_chance": 1.0, "sparks": 6},
	"spore_turret": {"name": "Spore turrets", "hp": 5.0, "radius": 15.0, "speed": 0.0, "contact": 0.0, "spark_chance": 1.0, "sparks": 2},
	"thorn_battery": {"name": "Thorn batteries", "hp": 10.0, "radius": 19.0, "speed": 0.0, "contact": 0.0, "spark_chance": 1.0, "sparks": 3},
	"hive": {"name": "Hives", "hp": 16.0, "radius": 24.0, "speed": 0.0, "contact": 0.0, "spark_chance": 1.0, "sparks": 4},
	"skimmer": {"name": "Skimmers", "hp": 2.0, "radius": 11.0, "speed": 185.0, "contact": 10.0, "spark_chance": 0.6, "sparks": 1},
	"bastion": {"name": "The Bastion", "hp": 70.0, "radius": 50.0, "speed": 0.0, "contact": 0.0, "spark_chance": 1.0, "sparks": 20},
	"bastion_pod": {"name": "Bastion pods", "hp": 16.0, "radius": 17.0, "speed": 0.0, "contact": 0.0, "spark_chance": 1.0, "sparks": 4},
}
## Kinds that never move: bosses, nests and ground growths. Nothing pushes
## them around, and growths rooted in the ground can't be bumped into.
const STATIC_KINDS := ["heart", "nest", "spore_turret", "thorn_battery", "hive", "bastion", "bastion_pod"]
const TURRET_INTERVAL := 2.4
const TURRET_SHOT_SPEED := 240.0
const TURRET_SHOT_DAMAGE := 9.0
const BATTERY_INTERVAL := 3.2
const BATTERY_SHOT_SPEED := 290.0
const HIVE_INTERVAL := 5.5
const BASTION_RING_SHOTS := 12
const BASTION_INTERVAL := 2.6
const POD_INTERVAL := 2.0

const SPAWN_IN_TIME := 0.35
const DART_WINDUP := 0.55
const DART_CHARGE_TIME := 0.38
const DART_CHARGE_SPEED := 720.0
const SPITTER_NEAR := 300.0
const SPITTER_FAR := 440.0
const SPITTER_SHOT_SPEED := 270.0
const SPITTER_SHOT_DAMAGE := 10.0
const SPITTER_CHARGE_TIME := 0.45
const CARAPACE_TURN_RATE := 1.4
## Shots hitting the carapace head-on within this cone (as a dot product) hit
## its plate instead of its body.
const CARAPACE_ARMOR_DOT := -0.5
## Damage the plate soaks before it cracks and the carapace is open from every side.
const CARAPACE_ARMOR := 5.0
const LANCER_NEAR := 520.0
const LANCER_FAR := 720.0
const LANCER_AIM_TIME := 1.0
const LANCER_LOCK_TIME := 0.35
const LANCER_SHOT_SPEED := 1150.0
const LANCER_SHOT_DAMAGE := 16.0
const BROOD_MITES := 4
const HEART_RING_SHOTS := 14
const HEART_SHOT_SPEED := 170.0
const HEART_SHOT_DAMAGE := 12.0
## How often the heart sends a small brood while it sleeps in its shell.
const HEART_SHELL_BROOD_INTERVAL := 12.0
const NEST_RANGE := 900.0
const NEST_INTERVAL := 13.0
const NEST_PACK := 3

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
## The heart can't be hurt until its shell breaks partway through the siege.
var shielded := false
## Wanderers on a planet's surface sleep until the pilot comes within
## wake_range, or shoots them.
var dormant := false
var wake_range := 650.0
## Fraction of movement lost this frame; light slows the Gloom on planets.
## The host sets it before each update.
var slow := 0.0
## A carapace's front plate; shots to the front chip it away until it cracks.
var armor := 0.0
var max_armor := 0.0

var _timer := 0.0
var _timer_b := 0.0
var _charging := false
var _charge_direction := Vector2.ZERO
var _winding_up := false
var _flash := 0.0
var _wobble := 0.0
var _orbit_sign := 1.0
var _outline := PackedVector2Array()
var _target_offset := Vector2.ZERO
var _ring_offset := 0.0
var _speed_scale := 1.0


## `speed_scale` slows everything down on a planet's surface, where the pilot
## is on foot.
func setup(p_kind: String, p_elite: bool, rng: RandomNumberGenerator, health_scale := 1.0, speed_scale := 1.0) -> void:
	kind = p_kind
	elite = p_elite
	var stats: Dictionary = KINDS[kind]
	hp = float(stats["hp"]) * health_scale
	radius = stats["radius"]
	speed = float(stats["speed"]) * rng.randf_range(0.88, 1.12) * speed_scale
	_speed_scale = speed_scale
	contact_damage = stats["contact"]
	spark_chance = stats["spark_chance"]
	spark_count = stats["sparks"]
	if elite:
		hp *= 2.6
		radius *= 1.4
		speed *= 0.9
		spark_count = int(spark_count * 2.5)
	max_hp = hp
	if kind == "carapace":
		max_armor = CARAPACE_ARMOR * health_scale * (2.0 if elite else 1.0)
		armor = max_armor
	_wobble = rng.randf() * TAU
	_orbit_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_timer = rng.randf_range(1.2, 2.6)
	_timer_b = 4.0
	if kind == "nest":
		_timer = rng.randf_range(2.0, 5.0)
	_outline = _make_outline(rng)
	scale = Vector2.ONE * 0.3


## True when a shot coming along `direction` hits this enemy's armored front.
func blocks(direction: Vector2) -> bool:
	return armor > 0.0 and direction.normalized().dot(Vector2.from_angle(rotation)) < CARAPACE_ARMOR_DOT


## A shot hit the plate. Returns true if that cracked it.
func hit_armor(amount: float) -> bool:
	if armor <= 0.0:
		return false
	armor -= amount
	_flash = 0.04
	dormant = false
	if armor <= 0.0:
		armor = 0.0
		return true
	return false


func take_damage(amount: float) -> bool:
	if dead or shielded:
		return false
	dormant = false
	hp -= amount
	_flash = 0.06
	return hp <= 0.0


func is_static() -> bool:
	return STATIC_KINDS.has(kind)


func update(delta: float, host: Node) -> void:
	age += delta
	_flash = maxf(_flash - delta, 0.0)
	var spawn_progress := clampf(age / SPAWN_IN_TIME, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.3, 1.0, spawn_progress)
	var target: Vector2 = host.target_position()
	if dormant:
		if position.distance_squared_to(target) < wake_range * wake_range:
			dormant = false
		else:
			_update_dormant(delta)
			return
	var waypoint: Vector2 = host.route_to(self, target)
	match kind:
		"mite", "brood":
			_update_mite(delta, waypoint)
		"dart":
			_update_dart(delta, target, waypoint)
		"spitter":
			_update_spitter(delta, target, waypoint, host)
		"snuffer":
			_update_snuffer(delta, host)
		"carapace":
			_update_carapace(delta, waypoint)
		"lancer":
			_update_lancer(delta, target, waypoint, host)
		"heart":
			_update_heart(delta, host)
		"nest":
			_update_nest(delta, target, host)
		"spore_turret", "thorn_battery", "bastion_pod":
			_update_growth_gun(delta, target, host)
		"hive":
			_update_hive(delta, host)
		"skimmer":
			_update_skimmer(delta)
		"bastion":
			_update_bastion(delta, host)
	position += velocity * delta * (1.0 - slow)
	modulate = Color(4.0, 4.0, 4.0) if _flash > 0.0 else Color(1.0, 1.0, 1.0, spawn_progress)
	if kind != "mite":
		queue_redraw()


## Asleep: drifts to a stop and slowly turns in place.
func _update_dormant(delta: float) -> void:
	_steer(Vector2.ZERO, delta, 4.0)
	rotation += delta * 0.4 * _orbit_sign
	position += velocity * delta
	modulate = Color(0.75, 0.75, 0.75, clampf(age / SPAWN_IN_TIME, 0.0, 1.0))
	if kind != "mite":
		queue_redraw()


func _steer(desired: Vector2, delta: float, responsiveness: float) -> void:
	velocity = velocity.lerp(desired, 1.0 - exp(-responsiveness * delta))


func _update_mite(delta: float, target: Vector2) -> void:
	var heading := (target - position).normalized().rotated(sin(age * 3.0 + _wobble) * 0.6)
	_steer(heading * speed, delta, 4.0)
	rotation = velocity.angle()


## Stalks, winds up (telegraphed with a line), then charges in a straight line.
func _update_dart(delta: float, target: Vector2, waypoint: Vector2) -> void:
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
			velocity = _charge_direction * DART_CHARGE_SPEED * _speed_scale
		return
	_steer((waypoint - position).normalized() * speed, delta, 3.0)
	rotation = velocity.angle()
	if _timer <= 0.0 and age > SPAWN_IN_TIME and waypoint == target:
		_winding_up = true
		_timer = DART_WINDUP


## Keeps its distance, circles, and lobs slow shots that glow before they fire.
func _update_spitter(delta: float, target: Vector2, waypoint: Vector2, host: Node) -> void:
	var to_target := target - position
	var distance := to_target.length()
	var direction := to_target / maxf(distance, 0.001)
	if waypoint != target:
		_steer((waypoint - position).normalized() * speed, delta, 3.0)
	else:
		_keep_range(direction, distance, SPITTER_NEAR, SPITTER_FAR, delta)
	rotation = direction.angle()
	_timer -= delta
	if _timer <= 0.0 and age > SPAWN_IN_TIME and distance < SPITTER_FAR * 1.6 and waypoint == target:
		_timer = randf_range(1.6, 2.3)
		host.spawn_enemy_shot(position + direction * radius, direction * SPITTER_SHOT_SPEED * _speed_scale, SPITTER_SHOT_DAMAGE)


## Ignores the ship and crawls toward the spark. Reaching it snuffs progress.
func _update_snuffer(delta: float, host: Node) -> void:
	var has_objective: bool = host.has_objective()
	var target: Vector2 = host.objective_position() if has_objective else host.target_position()
	var to_target := target - position
	var waypoint: Vector2 = host.route_to(self, target)
	_steer((waypoint - position).normalized() * speed, delta, 2.0)
	_target_offset = to_target / maxf(scale.x, 0.01)
	if has_objective and to_target.length() < radius + 12.0:
		host.on_snuffer_reached(self)


## Turns slowly to keep its armored front toward you, so flanking pays off.
func _update_carapace(delta: float, target: Vector2) -> void:
	var wanted := (target - position).angle()
	rotation = rotate_toward(rotation, wanted, CARAPACE_TURN_RATE * _speed_scale * delta)
	_steer(Vector2.from_angle(rotation) * speed, delta, 2.0)


## Hangs back, paints you with a tracking line, locks it, then fires a fast bolt.
func _update_lancer(delta: float, target: Vector2, waypoint: Vector2, host: Node) -> void:
	var to_target := target - position
	var distance := to_target.length()
	var direction := to_target / maxf(distance, 0.001)
	_timer -= delta
	if _winding_up:
		_steer(Vector2.ZERO, delta, 5.0)
		if _timer > LANCER_LOCK_TIME:
			rotation = direction.angle()
		if _timer <= 0.0:
			_winding_up = false
			_timer = randf_range(3.0, 4.0)
			var aim := Vector2.from_angle(rotation)
			host.spawn_enemy_shot(position + aim * radius, aim * LANCER_SHOT_SPEED * _speed_scale, LANCER_SHOT_DAMAGE, "enemy_bolt")
		return
	if waypoint != target:
		_steer((waypoint - position).normalized() * speed, delta, 3.0)
	else:
		_keep_range(direction, distance, LANCER_NEAR, LANCER_FAR, delta)
	rotation = direction.angle()
	if _timer <= 0.0 and age > SPAWN_IN_TIME and distance < LANCER_FAR * 1.4 and waypoint == target:
		_winding_up = true
		_timer = LANCER_AIM_TIME


## Sleeps in its shell while you hold the region, sending only the odd brood
## of mites. Once the shell breaks it wakes: rotating rings of shots, more
## mites, and a spiral once it's badly hurt.
func _update_heart(delta: float, host: Node) -> void:
	velocity = Vector2.ZERO
	if age < 1.5:
		return
	if shielded:
		_timer_b -= delta
		if _timer_b <= 0.0:
			_timer_b = HEART_SHELL_BROOD_INTERVAL
			host.spawn_minions(position, "mite", 3, false)
		_timer = minf(_timer, 1.5)
		return
	var hurt := hp < max_hp * 0.5
	_timer -= delta
	if _timer <= 0.0:
		_timer = 2.2 if hurt else 3.2
		_ring_offset += 0.37
		for i in HEART_RING_SHOTS:
			var direction := Vector2.from_angle(_ring_offset + TAU * i / HEART_RING_SHOTS)
			host.spawn_enemy_shot(position + direction * radius, direction * HEART_SHOT_SPEED, HEART_SHOT_DAMAGE)
	_timer_b -= delta
	if _timer_b <= 0.0:
		_timer_b = 7.0
		host.spawn_minions(position, "mite", 5, false)
	if hp < max_hp * 0.4:
		_ring_offset += delta * 2.2
		if fmod(age, 0.14) < delta:
			var direction := Vector2.from_angle(_ring_offset * 3.0)
			host.spawn_enemy_shot(position + direction * radius, direction * HEART_SHOT_SPEED * 1.2, HEART_SHOT_DAMAGE * 0.8)


## A planet-surface nest: sits still and sends out a pack whenever the pilot
## comes near. Destroying it stops the packs.
func _update_nest(delta: float, target: Vector2, host: Node) -> void:
	velocity = Vector2.ZERO
	if not host.nests_awake():
		return
	_timer -= delta
	if _timer <= 0.0 and position.distance_to(target) < NEST_RANGE:
		_timer = NEST_INTERVAL
		host.spawn_minions(position, "mite", NEST_PACK)


## Ground guns on an assaulted planet: only fire while on screen. Turrets aim
## one shot, batteries and bastion pods throw a fan.
func _update_growth_gun(delta: float, target: Vector2, host: Node) -> void:
	velocity = Vector2.ZERO
	var direction := (target - position).normalized()
	rotation = rotate_toward(rotation, direction.angle(), 3.0 * delta)
	if not host.in_view(position):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var aim := Vector2.from_angle(rotation)
	match kind:
		"spore_turret":
			_timer = TURRET_INTERVAL
			host.spawn_enemy_shot(position + aim * radius, aim * TURRET_SHOT_SPEED * _speed_scale, TURRET_SHOT_DAMAGE)
		"thorn_battery":
			_timer = BATTERY_INTERVAL
			for spread in [-0.25, 0.0, 0.25]:
				var shot := aim.rotated(spread)
				host.spawn_enemy_shot(position + shot * radius, shot * BATTERY_SHOT_SPEED * _speed_scale, TURRET_SHOT_DAMAGE, "enemy_bolt")
		_:
			_timer = POD_INTERVAL
			for spread in [-0.4, -0.2, 0.0, 0.2, 0.4]:
				var shot := aim.rotated(spread)
				host.spawn_enemy_shot(position + shot * radius, shot * BATTERY_SHOT_SPEED * 0.85 * _speed_scale, TURRET_SHOT_DAMAGE)


## Releases skimmers while on screen.
func _update_hive(delta: float, host: Node) -> void:
	velocity = Vector2.ZERO
	if not host.in_view(position):
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = HIVE_INTERVAL
		host.spawn_minions(position + Vector2(0.0, -radius), "skimmer", 2)


## Swoops across the sky against the scroll in a sine wave.
func _update_skimmer(delta: float) -> void:
	velocity = Vector2(-speed, sin(age * 3.2 + _wobble) * speed * 0.7)
	rotation = velocity.angle()


## Sits behind its pods' shield; once they're gone it throws rings of shots
## and sends skimmers.
func _update_bastion(delta: float, host: Node) -> void:
	velocity = Vector2.ZERO
	if shielded or not host.in_view(position):
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = BASTION_INTERVAL
		_ring_offset += 0.3
		for i in BASTION_RING_SHOTS:
			var direction := Vector2.from_angle(_ring_offset + TAU * i / BASTION_RING_SHOTS)
			if direction.y < 0.3:
				host.spawn_enemy_shot(position + direction * radius, direction * HEART_SHOT_SPEED * 1.2, TURRET_SHOT_DAMAGE)
	_timer_b -= delta
	if _timer_b <= 0.0:
		_timer_b = 6.0
		host.spawn_minions(position + Vector2(0.0, -radius), "skimmer", 3)


func _keep_range(direction: Vector2, distance: float, near: float, far: float, delta: float) -> void:
	var desired := direction.orthogonal() * speed * _orbit_sign
	if distance > far:
		desired = direction * speed
	elif distance < near:
		desired = -direction * speed
	_steer(desired, delta, 2.5)


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
		"carapace":
			for i in 10:
				points.append(Vector2.from_angle(TAU * i / 10.0) * radius * (1.0 if i % 2 == 0 else 0.86))
		"lancer":
			points = PackedVector2Array([
				Vector2(radius * 1.8, 0.0), Vector2(0.0, -radius * 0.55), Vector2(-radius, -radius * 0.35),
				Vector2(-radius * 0.6, 0.0), Vector2(-radius, radius * 0.35), Vector2(0.0, radius * 0.55),
			])
		"spore_turret", "thorn_battery", "hive":
			# A mound rooted in the ground: flat underneath, lumpy on top.
			var corners := 12
			for i in corners + 1:
				var angle := PI + PI * i / corners
				points.append(Vector2.from_angle(angle) * radius * rng.randf_range(0.85, 1.1) * Vector2(1.25, 1.0))
			points.append(Vector2(radius * 1.2, radius * 0.35))
			points.append(Vector2(-radius * 1.2, radius * 0.35))
		"skimmer":
			points = PackedVector2Array([
				Vector2(radius * 1.2, 0.0), Vector2(-radius * 0.2, -radius * 0.35), Vector2(-radius, -radius * 1.0),
				Vector2(-radius * 0.6, 0.0), Vector2(-radius, radius * 1.0), Vector2(-radius * 0.2, radius * 0.35),
			])
		"bastion":
			points = PackedVector2Array([
				Vector2(-radius * 1.1, radius * 0.5), Vector2(-radius * 0.8, -radius * 0.4), Vector2(-radius * 0.45, -radius * 1.5),
				Vector2(0.0, -radius * 1.9), Vector2(radius * 0.45, -radius * 1.5), Vector2(radius * 0.8, -radius * 0.4),
				Vector2(radius * 1.1, radius * 0.5),
			])
		"bastion_pod":
			for i in 6:
				points.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * radius)
		_:
			var corners := 20 if kind == "heart" or kind == "nest" else 14
			for i in corners:
				points.append(Vector2.from_angle(TAU * i / corners) * radius * rng.randf_range(0.82, 1.12))
	return points


func _draw() -> void:
	var glow := ELITE_COLOR if elite else GLOW_COLOR
	if kind == "heart" or kind == "bastion":
		glow = HEART_COLOR
	if kind in ["spore_turret", "thorn_battery", "hive", "bastion", "bastion_pod"]:
		_draw_growth(glow)
		return
	if kind == "snuffer":
		_draw_tether(glow)
	if kind == "lancer" and _winding_up:
		_draw_aim_line(glow)
	draw_colored_polygon(_outline, BODY_COLOR)
	var closed := _outline.duplicate()
	closed.append(_outline[0])
	draw_polyline(closed, glow, 3.0 if radius > 20.0 else 2.0)
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
		"carapace":
			if armor > 0.0:
				var health := armor / maxf(max_armor, 0.001)
				var plate := ARMOR_COLOR
				plate.a = 0.45 + 0.55 * health
				draw_arc(Vector2.ZERO, radius + 4.0, -1.05, 1.05, 20, plate, 2.0 + 2.5 * health)
			else:
				for i in 3:
					var angle := -0.8 + 0.8 * i
					draw_line(Vector2.from_angle(angle) * (radius + 1.0), Vector2.from_angle(angle + 0.2) * (radius + 6.0), Color(ARMOR_COLOR, 0.4), 1.5)
			draw_circle(Vector2(-radius * 0.35, 0.0), 3.0, glow)
		"brood":
			for i in BROOD_MITES:
				draw_circle(Vector2.from_angle(TAU * i / BROOD_MITES + age * 2.0) * radius * 0.45, 2.4, glow)
		"lancer":
			draw_circle(Vector2(radius * 0.4, 0.0), 2.4, glow)
		"nest":
			var throb := 0.5 + 0.5 * sin(age * 2.0)
			draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 32, glow, 2.0)
			for i in 5:
				draw_circle(Vector2.from_angle(TAU * i / 5.0 + age * 0.4) * radius * 0.35, 2.5 + 1.5 * throb, glow)
		"heart":
			var beat := pow(maxf(sin(age * 3.2), 0.0), 6.0)
			draw_arc(Vector2.ZERO, radius * (0.55 + 0.08 * beat), 0.0, TAU, 48, glow, 3.0)
			draw_circle(Vector2.ZERO, radius * (0.22 + 0.06 * beat), glow)
			if shielded:
				draw_arc(Vector2.ZERO, radius + 16.0, 0.0, TAU, 64, Color(2.0, 1.4, 2.6, 0.55 + 0.25 * beat), 4.0)


## Ground growths keep their mound upright while their barrel turns.
func _draw_growth(glow: Color) -> void:
	var upright := -rotation
	var body := PackedVector2Array()
	for point in _outline:
		body.append(point.rotated(upright))
	draw_colored_polygon(body, BODY_COLOR)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, glow, 3.0 if radius > 20.0 else 2.0)
	var pulse := 0.5 + 0.5 * sin(age * 3.0 + _wobble)
	match kind:
		"spore_turret":
			draw_line(Vector2.ZERO, Vector2(radius * 1.3, 0.0), glow, 4.0)
			draw_circle(Vector2.ZERO, 4.0 + 1.5 * pulse, glow)
		"thorn_battery":
			for spread in [-0.25, 0.0, 0.25]:
				draw_line(Vector2.ZERO, Vector2.from_angle(spread) * radius * 1.25, glow, 3.0)
			draw_circle(Vector2.ZERO, 5.0, glow)
		"hive":
			for i in 3:
				draw_circle(Vector2(-radius * 0.55 + radius * 0.55 * i, -radius * 0.35).rotated(upright), 3.5 + 2.0 * pulse, glow)
		"bastion_pod":
			draw_line(Vector2.ZERO, Vector2(radius * 1.4, 0.0), glow, 4.0)
			draw_circle(Vector2.ZERO, 5.0, glow)
		"bastion":
			var core := Vector2(0.0, -radius * 0.7).rotated(upright)
			draw_circle(core, radius * (0.28 + 0.05 * pulse), glow)
			if shielded:
				draw_arc(core, radius * 0.9, 0.0, TAU, 48, Color(2.0, 1.4, 2.6, 0.5 + 0.3 * pulse), 4.0)


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


func _draw_aim_line(color: Color) -> void:
	var locked := _timer <= LANCER_LOCK_TIME
	var line_color := Color(2.6, 0.4, 0.6) if locked else color
	line_color.a = 0.2 + 0.6 * (1.0 - _timer / LANCER_AIM_TIME)
	draw_line(Vector2(radius, 0.0), Vector2(radius + 900.0, 0.0), line_color, 3.0 if locked else 1.5)
