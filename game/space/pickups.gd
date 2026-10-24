class_name Pickups
extends Node2D
## Sparks shaken loose from the Gloom. They drift, get pulled in when the ship
## comes close, and each one collected feeds the claim.

const COLOR := Color(2.4, 1.8, 0.8)
const MAGNET_RADIUS := 160.0
const COLLECT_RADIUS := 20.0
const LIFETIME := 9.0
const PULL_SPEED := 900.0
const SIZE := 5.0


class Spark:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var life := 0.0
	var pulled := false


var sparks: Array[Spark] = []


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func drop(origin: Vector2, count: int) -> void:
	for i in count:
		var spark := Spark.new()
		spark.position = origin
		spark.velocity = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0)
		spark.life = LIFETIME
		sparks.append(spark)


## Sends every spark flying to the ship (used at ignition).
func pull_all() -> void:
	for spark in sparks:
		spark.pulled = true


func clear() -> void:
	sparks.clear()
	queue_redraw()


## Moves the sparks and returns how many reached the ship this frame.
func update(delta: float, ship_position: Vector2, can_collect: bool) -> int:
	var collected := 0
	var remaining: Array[Spark] = []
	for spark in sparks:
		spark.life -= delta
		var to_ship := ship_position - spark.position
		var distance := to_ship.length()
		if can_collect and (spark.pulled or distance < MAGNET_RADIUS):
			spark.pulled = true
			var pull := to_ship / maxf(distance, 0.001) * PULL_SPEED
			spark.velocity = spark.velocity.lerp(pull, 1.0 - exp(-8.0 * delta))
		else:
			spark.velocity = spark.velocity.lerp(Vector2.ZERO, 1.0 - exp(-2.0 * delta))
		spark.position += spark.velocity * delta
		if can_collect and distance < COLLECT_RADIUS:
			collected += 1
		elif spark.life > 0.0 or (can_collect and spark.pulled):
			remaining.append(spark)
	sparks = remaining
	queue_redraw()
	return collected


func _draw() -> void:
	for spark in sparks:
		if spark.life < 2.0 and not spark.pulled and fmod(spark.life, 0.25) < 0.12:
			continue
		var p := spark.position
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0.0, -SIZE), p + Vector2(SIZE * 0.6, 0.0),
			p + Vector2(0.0, SIZE), p + Vector2(-SIZE * 0.6, 0.0),
		]), COLOR)
