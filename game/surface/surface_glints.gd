class_name SurfaceGlints
extends CanvasLayer
## Tiny lights that show through the dark: the Gloom's eyes, a twinkle on each
## deposit, a blink on unopened caches, the pulse of nests and the ember glow
## of the vein. Drawn above the LanternVeil so the dark hints at what's out
## there without showing it.

const EYE_COLOR := Color(1.0, 0.35, 0.85)
const SLEEP_COLOR := Color(0.65, 0.3, 0.7)
const EMBER_COLOR := Color(1.0, 0.62, 0.25)
const CACHE_COLOR := Color(1.0, 0.85, 0.45)

var map: SurfaceMap
var battle: Battle
var resource := "ore"
var show_vein := true

var _drawer: Drawer


class Drawer extends Node2D:
	var owner_layer: SurfaceGlints
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var layer := owner_layer
		if layer.map == null:
			return
		var map := layer.map
		if layer.show_vein:
			var beat := 0.5 + 0.5 * sin(_time * 2.2)
			draw_circle(map.vein, 5.0 + 3.0 * beat, Color(EMBER_COLOR, 0.8))
			draw_arc(map.vein, 26.0 + 10.0 * beat, 0.0, TAU, 32, Color(EMBER_COLOR, 0.35 * (1.0 - beat)), 2.0)
		var shard: Color = PlanetData.RESOURCE_COLORS[layer.resource]
		var twinkle_color := Color(minf(shard.r, 1.0), minf(shard.g, 1.0), minf(shard.b, 1.0))
		for deposit in map.deposits:
			if not deposit.is_intact():
				continue
			var t := fmod(_time * 0.8 + deposit.shape_seed % 100 * 0.01, 1.0)
			var size := 2.0 + 5.0 * pow(sin(t * PI), 3.0)
			var spot := deposit.position + Vector2(-deposit.radius() * 0.3, -deposit.radius() * 0.6)
			draw_line(spot - Vector2(size, 0.0), spot + Vector2(size, 0.0), Color(twinkle_color, 0.85), 1.5)
			draw_line(spot - Vector2(0.0, size), spot + Vector2(0.0, size), Color(twinkle_color, 0.85), 1.5)
		for cache in map.caches:
			if not cache.opened and fmod(_time + cache.position.y * 0.001, 1.6) < 0.25:
				draw_circle(cache.position, 3.0, CACHE_COLOR)
		if layer.battle == null:
			return
		for enemy in layer.battle.enemies:
			if enemy.dead:
				continue
			if enemy.kind == "nest":
				var throb := 0.5 + 0.5 * sin(_time * 2.0 + enemy.position.x)
				draw_circle(enemy.position, 3.0 + 2.0 * throb, Color(EYE_COLOR, 0.35 + 0.3 * throb))
				continue
			var facing := Vector2.from_angle(enemy.rotation)
			var side := facing.orthogonal() * maxf(enemy.radius * 0.35, 3.0)
			var ahead := enemy.position + facing * enemy.radius * 0.45
			var color := EYE_COLOR
			if enemy.dormant:
				color = SLEEP_COLOR
				color.a = 0.5 if fmod(_time + enemy.position.x * 0.01, 4.0) > 0.25 else 0.0
			draw_circle(ahead + side, 1.6, color)
			draw_circle(ahead - side, 1.6, color)


func _ready() -> void:
	layer = 6
	follow_viewport_enabled = true
	_drawer = Drawer.new()
	_drawer.owner_layer = self
	add_child(_drawer)
