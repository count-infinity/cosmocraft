class_name Projectiles
extends Node2D
## Every bullet in flight, kept as plain data and drawn in one additive pass.
## SpaceGame does the collision checks using each bullet's swept segment.

const PLAYER_COLOR := Color(2.6, 2.0, 1.0)
const ENEMY_COLOR := Color(2.4, 0.45, 2.1)


class Bullet:
	var position := Vector2.ZERO
	var previous := Vector2.ZERO
	var velocity := Vector2.ZERO
	var life := 1.0
	var damage := 1.0
	var radius := 4.0
	var friendly := true


var bullets: Array[Bullet] = []


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func spawn(origin: Vector2, velocity: Vector2, damage: float, radius: float, life: float, friendly: bool) -> void:
	var bullet := Bullet.new()
	bullet.position = origin
	bullet.previous = origin
	bullet.velocity = velocity
	bullet.damage = damage
	bullet.radius = radius
	bullet.life = life
	bullet.friendly = friendly
	bullets.append(bullet)


func update(delta: float) -> void:
	for bullet in bullets:
		bullet.previous = bullet.position
		bullet.position += bullet.velocity * delta
		bullet.life -= delta


## Drops spent bullets. Call after collisions have marked hits (life = 0).
func sweep() -> void:
	var remaining: Array[Bullet] = []
	for bullet in bullets:
		if bullet.life > 0.0:
			remaining.append(bullet)
	bullets = remaining
	queue_redraw()


func clear() -> void:
	bullets.clear()
	queue_redraw()


func _draw() -> void:
	var enemy_halo := ENEMY_COLOR
	enemy_halo.a = 0.3
	for bullet in bullets:
		if bullet.friendly:
			var tail := bullet.velocity.normalized() * 16.0
			draw_line(bullet.position - tail, bullet.position, PLAYER_COLOR, 3.0)
		else:
			draw_circle(bullet.position, bullet.radius + 3.0, enemy_halo)
			draw_circle(bullet.position, bullet.radius * 0.6, ENEMY_COLOR)
