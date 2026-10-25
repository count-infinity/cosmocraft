class_name Projectiles
extends Node2D
## Every shot in flight, kept as plain data and drawn in one additive pass.
## SpaceGame steers homing shots and resolves hits using each shot's swept
## segment; this node only moves and draws them.

const PLAYER_COLOR := Color(2.6, 2.0, 1.0)
const PELLET_COLOR := Color(2.6, 1.4, 0.6)
const LANCE_COLOR := Color(2.8, 2.6, 2.0)
const MISSILE_COLOR := Color(1.0, 1.8, 2.6)
const FLAK_COLOR := Color(2.6, 1.2, 0.4)
const TORPEDO_COLOR := Color(2.8, 2.2, 1.4)
const ENEMY_COLOR := Color(2.4, 0.45, 2.1)
const FLARE_COLOR := Color(2.8, 1.5, 0.7)

const RADIUS_BY_STYLE := {
	"bolt": 4.0, "pellet": 3.0, "lance": 6.0, "missile": 5.0,
	"flak": 5.0, "torpedo": 9.0, "orb": 6.0, "enemy_bolt": 4.0, "flare": 7.0,
}


class Bullet:
	var position := Vector2.ZERO
	var previous := Vector2.ZERO
	var velocity := Vector2.ZERO
	var life := 1.0
	var damage := 1.0
	var radius := 4.0
	var friendly := true
	var style := "bolt"
	var pierce := 0
	var homing := 0.0
	var aoe := 0.0
	var knockback := 0.0
	## Flak, missiles and torpedoes burst when their time runs out.
	var burst_on_expire := false
	var target: GloomEnemy
	## Enemies a piercing shot has already passed through.
	var hit: Array[GloomEnemy] = []


var bullets: Array[Bullet] = []


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func spawn_player(spec: WeaponSpec, origin: Vector2, velocity: Vector2, life: float, target: GloomEnemy) -> Bullet:
	var bullet := _make(origin, velocity, spec.damage, life, true, spec.style)
	bullet.pierce = spec.pierce
	bullet.homing = spec.homing
	bullet.aoe = spec.aoe
	bullet.knockback = spec.knockback
	bullet.target = target
	bullet.burst_on_expire = spec.aoe > 0.0
	return bullet


func spawn_enemy(origin: Vector2, velocity: Vector2, damage: float, life: float, style := "orb") -> Bullet:
	return _make(origin, velocity, damage, life, false, style)


func clear() -> void:
	bullets.clear()
	queue_redraw()


func update(delta: float) -> void:
	for bullet in bullets:
		bullet.previous = bullet.position
		bullet.position += bullet.velocity * delta
		bullet.life -= delta


## Drops spent shots. Call after hits have been resolved.
func sweep() -> void:
	var remaining: Array[Bullet] = []
	for bullet in bullets:
		if bullet.life > 0.0:
			remaining.append(bullet)
	bullets = remaining
	queue_redraw()


func _make(origin: Vector2, velocity: Vector2, damage: float, life: float, friendly: bool, style: String) -> Bullet:
	var bullet := Bullet.new()
	bullet.position = origin
	bullet.previous = origin
	bullet.velocity = velocity
	bullet.damage = damage
	bullet.life = life
	bullet.friendly = friendly
	bullet.style = style
	bullet.radius = RADIUS_BY_STYLE.get(style, 4.0)
	bullets.append(bullet)
	return bullet


func _draw() -> void:
	for bullet in bullets:
		var direction := bullet.velocity.normalized()
		match bullet.style:
			"bolt":
				draw_line(bullet.position - direction * 16.0, bullet.position, PLAYER_COLOR, 3.0)
			"pellet":
				draw_line(bullet.position - direction * 9.0, bullet.position, PELLET_COLOR, 2.5)
			"lance":
				draw_line(bullet.position - direction * 70.0, bullet.position, LANCE_COLOR, 5.0)
				draw_line(bullet.position - direction * 110.0, bullet.position - direction * 70.0, Color(LANCE_COLOR, 0.35), 3.0)
			"missile":
				draw_line(bullet.position - direction * 18.0, bullet.position - direction * 4.0, Color(MISSILE_COLOR, 0.4), 2.0)
				draw_circle(bullet.position, 3.5, MISSILE_COLOR)
			"flak":
				draw_circle(bullet.position, 4.5, FLAK_COLOR)
			"torpedo":
				var pulse := 0.8 + 0.2 * sin(bullet.life * 30.0)
				draw_circle(bullet.position, 16.0 * pulse, Color(TORPEDO_COLOR, 0.25))
				draw_circle(bullet.position, 7.0, TORPEDO_COLOR)
			"enemy_bolt":
				draw_line(bullet.position - direction * 22.0, bullet.position, ENEMY_COLOR, 3.0)
			"flare":
				var flicker := 0.85 + 0.15 * sin(bullet.life * 47.0)
				draw_line(bullet.position - direction * 26.0, bullet.position, Color(FLARE_COLOR, 0.35), 4.0)
				draw_circle(bullet.position, 13.0 * flicker, Color(FLARE_COLOR, 0.25))
				draw_circle(bullet.position, 5.5, FLARE_COLOR)
			_:
				draw_circle(bullet.position, bullet.radius + 3.0, Color(ENEMY_COLOR, 0.3))
				draw_circle(bullet.position, bullet.radius * 0.6, ENEMY_COLOR)
