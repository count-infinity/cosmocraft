class_name Pickups
extends Node2D
## Things shaken loose for the ship or pilot to collect: sparks from the Gloom,
## and on planets, shards of ore, crystal or biomass. They drift, get pulled
## in when the collector comes close, and update() reports what arrived.

const SPARK := "spark"
const SPARK_COLOR := Color(2.4, 1.8, 0.8)
const COLLECT_RADIUS := 20.0
const LIFETIME := 9.0
## Resource shards last longer and are pulled in from farther away, so a
## broken deposit's haul comes to you.
const SHARD_LIFETIME := 30.0
const SHARD_MAGNET_SCALE := 2.6
const PULL_SPEED := 900.0
const SIZE := 5.0


class Item:
	var kind := SPARK
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var life := 0.0
	var pulled := false


var items: Array[Item] = []


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


static func color_of(kind: String) -> Color:
	if kind == SPARK:
		return SPARK_COLOR
	return PlanetData.RESOURCE_COLORS.get(kind, SPARK_COLOR)


func drop(origin: Vector2, count: int, kind := SPARK) -> void:
	for i in count:
		var item := Item.new()
		item.kind = kind
		item.position = origin
		item.velocity = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0)
		item.life = LIFETIME if kind == SPARK else SHARD_LIFETIME
		items.append(item)


## Sends everything flying to the collector (used at ignition).
func pull_all() -> void:
	for item in items:
		item.pulled = true


func clear() -> void:
	items.clear()
	queue_redraw()


func count(kind := "") -> int:
	if kind.is_empty():
		return items.size()
	var total := 0
	for item in items:
		if item.kind == kind:
			total += 1
	return total


## Moves everything and returns what reached the collector this frame, as
## {kind: count}. `magnet` is how close it has to be before things fly to it.
func update(delta: float, collector: Vector2, can_collect: bool, magnet: float) -> Dictionary:
	var collected := {}
	var remaining: Array[Item] = []
	for item in items:
		item.life -= delta
		var to_collector := collector - item.position
		var distance := to_collector.length()
		var reach := magnet if item.kind == SPARK else magnet * SHARD_MAGNET_SCALE
		if can_collect and (item.pulled or distance < reach):
			item.pulled = true
			var pull := to_collector / maxf(distance, 0.001) * PULL_SPEED
			item.velocity = item.velocity.lerp(pull, 1.0 - exp(-8.0 * delta))
		else:
			item.velocity = item.velocity.lerp(Vector2.ZERO, 1.0 - exp(-2.0 * delta))
		item.position += item.velocity * delta
		if can_collect and distance < COLLECT_RADIUS:
			collected[item.kind] = int(collected.get(item.kind, 0)) + 1
		elif item.life > 0.0 or (can_collect and item.pulled):
			remaining.append(item)
	items = remaining
	queue_redraw()
	return collected


func _draw() -> void:
	for item in items:
		if item.life < 2.0 and not item.pulled and fmod(item.life, 0.25) < 0.12:
			continue
		var p := item.position
		var color := color_of(item.kind)
		match item.kind:
			SPARK:
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(0.0, -SIZE), p + Vector2(SIZE * 0.6, 0.0),
					p + Vector2(0.0, SIZE), p + Vector2(-SIZE * 0.6, 0.0),
				]), color)
			"crystal":
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(0.0, -SIZE * 1.5), p + Vector2(SIZE * 0.5, 0.0),
					p + Vector2(0.0, SIZE * 1.1), p + Vector2(-SIZE * 0.5, 0.0),
				]), color)
			"biomass":
				draw_circle(p, SIZE * 0.85, color)
			_:
				var hexagon := PackedVector2Array()
				for k in 6:
					hexagon.append(p + Vector2.from_angle(TAU * k / 6.0 + 0.3) * SIZE)
				draw_colored_polygon(hexagon, color)
