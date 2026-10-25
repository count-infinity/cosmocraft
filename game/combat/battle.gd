class_name Battle
extends RefCounted
## Combat shared by every mode: the Gloom on the field, player shots versus
## enemies (pierce, blasts, armor, knockback, homing), enemy shots and contact
## versus the player, and the effects and sounds that go with them.
## SpaceGame and SurfaceMission each own one and decide what kills drop by
## listening to enemy_killed.
##
## The player is any Node2D with `velocity` and `take_damage(amount) -> bool`.

signal enemy_killed(enemy: GloomEnemy)
## A blast went off (flak, torpedo, flare); the surface lights up flares.
signal exploded(bullet: Projectiles.Bullet, point: Vector2)

const HOMING_SEARCH_RANGE := 650.0
const ENEMY_BULLET_LIFE := 4.0
## How many brood and heart spawns may exceed the enemy cap.
const MINION_HEADROOM := 12
const IGNITE_COLOR := Color(2.6, 2.0, 1.0)
const DEFLECT_COLOR := Color(1.8, 1.4, 2.6)
const PLATE_COLOR := Color(1.8, 1.0, 2.6)
const OBSTACLE_HIT_COLOR := Color(0.9, 0.8, 0.9)

var enemies: Array[GloomEnemy] = []
var max_alive := 70
## Enemy speed multiplier for this mode (slower on foot).
var speed_scale := 1.0
## Multiplies every hit the Gloom lands (contact and shots); set from the darkness.
var damage_scale := 1.0
var god_mode := false

var _grid := SpatialGrid.new(96.0)
var _rng: RandomNumberGenerator
var _root: Node2D
var _projectiles: Projectiles
var _fx: FxLayer
var _sfx: Sfx
var _camera: GameCamera


func _init(root: Node2D, projectiles: Projectiles, fx: FxLayer, sfx: Sfx, camera: GameCamera, rng: RandomNumberGenerator) -> void:
	_root = root
	_projectiles = projectiles
	_fx = fx
	_sfx = sfx
	_camera = camera
	_rng = rng


func spawn(kind: String, elite: bool, at: Vector2, health_scale := 1.0) -> GloomEnemy:
	var enemy := GloomEnemy.new()
	enemy.setup(kind, elite, _rng, health_scale, speed_scale)
	enemy.position = at
	_root.add_child(enemy)
	enemies.append(enemy)
	return enemy


## Extra Gloom from a dying Brood, a nest or the heart, within a little
## headroom over the cap so swarms can't snowball.
func spawn_minions(origin: Vector2, kind: String, count: int, drops_sparks := true) -> void:
	count = mini(count, max_alive + MINION_HEADROOM - enemies.size())
	for i in count:
		var enemy := spawn(kind, false, origin + Vector2.from_angle(TAU * i / count) * _rng.randf_range(20.0, 50.0))
		if not drops_sparks:
			enemy.spark_chance = 0.0


func spawn_enemy_shot(origin: Vector2, velocity: Vector2, damage: float, style := "orb") -> void:
	_projectiles.spawn_enemy(origin, velocity, damage * damage_scale, ENEMY_BULLET_LIFE, style)
	_sfx.play("spit", -12.0)


## Fires one volley from a weapon: spread shots fan out, twin shots run side
## by side, and flak aimed at a target bursts right where it is.
func fire_volley(spec: WeaponSpec, origin: Vector2, direction: Vector2, target: GloomEnemy, shooter_velocity: Vector2) -> void:
	var life := spec.life
	if spec.style == "flak" and target != null:
		life = clampf(origin.distance_to(target.position) / spec.speed, 0.08, spec.life)
	for i in spec.count:
		var t := float(i) / (spec.count - 1) if spec.count > 1 else 0.5
		var start := origin
		var heading := direction
		if spec.parallel > 0.0 and spec.count > 1:
			start += direction.orthogonal() * lerpf(-spec.parallel, spec.parallel, t) * 0.5
		elif spec.count > 1:
			heading = direction.rotated(deg_to_rad(lerpf(-spec.spread, spec.spread, t) * 0.5))
		heading = heading.rotated(deg_to_rad(randf_range(-1.0, 1.0) * minf(spec.spread * 0.15, 2.5)))
		_projectiles.spawn_player(spec, start, heading * spec.speed + shooter_velocity * 0.3, life, target)
	_fx.burst(origin, Projectiles.PLAYER_COLOR, 2, 40.0, 120.0, 0.12, 1.5, direction.angle(), 0.5)
	match spec.style:
		"lance":
			_sfx.play("lance", -6.0)
		"missile":
			_sfx.play("missile", -10.0)
		"flak":
			_sfx.play("flak", -10.0)
		"torpedo", "flare":
			_sfx.play("torpedo", -2.0)
			_camera.add_trauma(0.15)
		"pellet":
			_sfx.play("scatter", -8.0)
		_:
			_sfx.play("shoot", -14.0)


## Closest live, hittable enemy within range (for turrets and seekers).
func nearest_enemy_within(from: Vector2, reach: float) -> GloomEnemy:
	var best: GloomEnemy = null
	var best_distance := reach * reach
	for enemy in enemies:
		if enemy.dead or enemy.shielded:
			continue
		var distance := from.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Closest live enemy, treating Snuffers as closer than they are.
func nearest_enemy(from: Vector2) -> GloomEnemy:
	var best: GloomEnemy = null
	var best_score := INF
	for enemy in enemies:
		if enemy.dead or enemy.shielded:
			continue
		var score := from.distance_squared_to(enemy.position)
		if enemy.kind == "snuffer":
			score *= 0.25
		if score < best_score:
			best_score = score
			best = enemy
	return best


func count_kind(kind: String) -> int:
	var count := 0
	for enemy in enemies:
		if enemy.kind == kind and not enemy.dead:
			count += 1
	return count


## Moves every enemy, keeps swarms from stacking, pushes them out of
## obstacles (`push_out(point, radius) -> Vector2`), and applies contact damage.
func update_enemies(dt: float, host: Node, player: Node2D, player_radius: float, player_alive: bool, push_out: Callable) -> void:
	rebuild_grid()
	for enemy in enemies:
		if enemy.dead:
			continue
		enemy.update(dt, host)
		if not enemy.is_static():
			_separate(enemy, dt)
			enemy.position += push_out.call(enemy.position, enemy.radius)
		if player_alive and not enemy.dead and enemy.age > GloomEnemy.SPAWN_IN_TIME:
			var reach := enemy.radius + player_radius
			if enemy.contact_damage > 0.0 and enemy.position.distance_squared_to(player.position) < reach * reach:
				if not god_mode and player.take_damage(enemy.contact_damage * damage_scale):
					var push := (player.position - enemy.position).normalized()
					player.velocity += push * 380.0
					if not enemy.is_static():
						enemy.velocity -= push * 260.0
	remove_dead()


## Moves shots and resolves hits. `blocked(bullet) -> bool` says whether a
## shot's path this frame (previous to position) runs into an obstacle; it may
## also damage what it hit, like a resource deposit.
func update_projectiles(dt: float, player: Node2D, player_radius: float, player_alive: bool, blocked: Callable) -> void:
	_steer_missiles(dt)
	_projectiles.update(dt)
	rebuild_grid()
	for bullet in _projectiles.bullets:
		if bullet.life <= 0.0:
			if bullet.friendly and bullet.burst_on_expire:
				explode(bullet, bullet.position)
			continue
		if blocked.call(bullet):
			if bullet.friendly and bullet.aoe > 0.0:
				explode(bullet, bullet.position)
			bullet.life = 0.0
			_fx.burst(bullet.position, OBSTACLE_HIT_COLOR, 3, 30.0, 120.0, 0.2, 1.4)
			continue
		if bullet.friendly:
			_resolve_player_shot(bullet)
		elif player_alive:
			var closest := Geometry2D.get_closest_point_to_segment(player.position, bullet.previous, bullet.position)
			if closest.distance_to(player.position) <= player_radius + bullet.radius:
				bullet.life = 0.0
				if not god_mode:
					player.take_damage(bullet.damage)
				_fx.burst(closest, Projectiles.ENEMY_COLOR, 6, 40.0, 160.0, 0.3, 2.0)
	_projectiles.sweep()
	remove_dead()


func explode(bullet: Projectiles.Bullet, point: Vector2) -> void:
	bullet.life = -1.0
	for enemy: GloomEnemy in _grid.query(point, bullet.aoe + 64.0):
		if not enemy.dead and enemy.position.distance_to(point) <= bullet.aoe + enemy.radius:
			damage_enemy(enemy, bullet.damage, (enemy.position - point).normalized(), enemy.position, 120.0)
	var big := bullet.aoe >= 100.0
	var color := Projectiles.TORPEDO_COLOR if big else Projectiles.FLAK_COLOR
	_fx.ring(point, color, bullet.aoe, 0.35, 3.0 if big else 2.0)
	_fx.burst(point, color, 24 if big else 8, 40.0, 300.0 if big else 180.0, 0.45, 2.0)
	_sfx.play("boom" if big else "pop", -4.0 if big else -10.0)
	if big:
		_camera.add_trauma(0.35)
	exploded.emit(bullet, point)


func damage_enemy(enemy: GloomEnemy, amount: float, direction: Vector2, point: Vector2, knockback: float) -> void:
	if enemy.shielded:
		_fx.burst(point, DEFLECT_COLOR, 4, 60.0, 200.0, 0.25, 1.6)
		_sfx.play("ting", -12.0)
		return
	var killed := enemy.take_damage(amount)
	var push := knockback if knockback > 0.0 else 110.0
	if enemy.is_static():
		push = 0.0
	elif enemy.kind == "snuffer" or enemy.kind == "carapace":
		push *= 0.35
	enemy.velocity += direction * push
	_fx.burst(point, Projectiles.PLAYER_COLOR, 3, 60.0, 220.0, 0.22, 1.6, direction.angle(), 0.9)
	if killed:
		kill(enemy)
	else:
		_sfx.play("hit", -10.0)


## Destroys an enemy with full effects. Broods burst into mites; the owner
## decides drops through enemy_killed.
func kill(enemy: GloomEnemy) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	var big := enemy.radius > 20.0
	var glow := GloomEnemy.ELITE_COLOR if enemy.elite else GloomEnemy.GLOW_COLOR
	if enemy.kind == "heart":
		glow = GloomEnemy.HEART_COLOR
	_fx.burst(enemy.position, glow, 26 if big else 12, 60.0, 340.0 if big else 260.0, 0.55, 2.2)
	_fx.burst(enemy.position, IGNITE_COLOR, 6 if big else 3, 30.0, 140.0, 0.4, 1.8)
	if big:
		_fx.ring(enemy.position, glow, enemy.radius * 5.0, 0.45, 3.0)
	_camera.add_trauma(0.35 if big else 0.06)
	_sfx.play("boom" if big else "pop", -2.0 if big else -6.0)
	if enemy.kind == "brood":
		spawn_minions(enemy.position, "mite", GloomEnemy.BROOD_MITES)
	enemy_killed.emit(enemy)


## Caught by an ignition wave: burns away with no drop.
func burn(enemy: GloomEnemy) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	_fx.burst(enemy.position, IGNITE_COLOR, 10, 60.0, 300.0, 0.6, 2.2)
	_fx.burst(enemy.position, GloomEnemy.GLOW_COLOR, 6, 40.0, 200.0, 0.5, 2.0)
	_sfx.play("pop", -8.0)


## The fight ended without a win: the Gloom loses interest and fades.
func dissolve(enemy: GloomEnemy) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	_fx.burst(enemy.position, GloomEnemy.GLOW_COLOR, 6, 20.0, 90.0, 0.7, 1.6)


func dissolve_all() -> void:
	for enemy in enemies:
		dissolve(enemy)
	remove_dead()


## Removes every enemy and shot without effects (new sector, leaving a planet).
func clear() -> void:
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	_projectiles.clear()


func rebuild_grid() -> void:
	_grid.clear()
	for enemy in enemies:
		if not enemy.dead:
			_grid.insert(enemy, enemy.position)


func remove_dead() -> void:
	var alive: Array[GloomEnemy] = []
	for enemy in enemies:
		if enemy.dead:
			enemy.queue_free()
		else:
			alive.append(enemy)
	enemies = alive


## Pushes overlapping enemies apart so swarms spread out instead of stacking.
func _separate(enemy: GloomEnemy, dt: float) -> void:
	if enemy.is_static():
		return
	var push := Vector2.ZERO
	for item: GloomEnemy in _grid.query(enemy.position, enemy.radius + 60.0):
		if item == enemy or item.dead:
			continue
		var offset := enemy.position - item.position
		var min_distance := enemy.radius + item.radius + 2.0
		var distance_squared := offset.length_squared()
		if distance_squared < min_distance * min_distance and distance_squared > 0.0001:
			var distance := sqrt(distance_squared)
			push += offset / distance * (min_distance - distance)
	enemy.position += push * minf(dt * 10.0, 0.5)


func _steer_missiles(dt: float) -> void:
	for bullet in _projectiles.bullets:
		if not bullet.friendly or bullet.homing <= 0.0:
			continue
		if bullet.target == null or not is_instance_valid(bullet.target) or bullet.target.dead:
			bullet.target = nearest_enemy_within(bullet.position, HOMING_SEARCH_RANGE)
		if bullet.target == null:
			continue
		var heading := rotate_toward(bullet.velocity.angle(), (bullet.target.position - bullet.position).angle(), bullet.homing * dt)
		bullet.velocity = Vector2.from_angle(heading) * bullet.velocity.length()


## Hits along a shot's path this frame. Blasts burst on the first contact,
## piercing shots keep going, and plain shots to a Carapace's front chip its
## plate instead of hurting it, until the plate cracks.
func _resolve_player_shot(bullet: Projectiles.Bullet) -> void:
	var middle := (bullet.previous + bullet.position) * 0.5
	var reach := bullet.previous.distance_to(bullet.position) * 0.5 + bullet.radius + 64.0
	for enemy: GloomEnemy in _grid.query(middle, reach):
		if enemy.dead or bullet.hit.has(enemy):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, bullet.previous, bullet.position)
		if closest.distance_to(enemy.position) > enemy.radius + bullet.radius:
			continue
		if bullet.aoe > 0.0:
			explode(bullet, closest)
			return
		var direction := bullet.velocity.normalized()
		if bullet.pierce <= 0 and enemy.blocks(direction):
			bullet.life = 0.0
			if enemy.hit_armor(bullet.damage):
				_fx.burst(closest, PLATE_COLOR, 22, 60.0, 300.0, 0.5, 2.0, (-direction).angle(), 1.2)
				_camera.add_trauma(0.12)
				_sfx.play("shatter", -6.0)
			else:
				_fx.burst(closest, DEFLECT_COLOR, 5, 60.0, 220.0, 0.25, 1.6, (-direction).angle(), 0.9)
				_sfx.play("ting", -10.0)
			return
		damage_enemy(enemy, bullet.damage, direction, closest, bullet.knockback)
		if bullet.pierce > 0:
			bullet.pierce -= 1
			bullet.hit.append(enemy)
			continue
		bullet.life = 0.0
		return
