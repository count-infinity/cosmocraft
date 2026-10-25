class_name AssaultSky
extends CanvasLayer
## The sky behind an assault, drawn in screen space: a dark gradient warming
## toward the planet's glow at the horizon, a moon, stars, and two ranges of
## mountains that scroll slower than the ground (parallax).

var planet_type := PlanetData.Type.ASHEN
## How far the stage has scrolled (world x of the screen's left edge).
var scroll := 0.0
var _drawer: SkyDrawer


class SkyDrawer extends Control:
	var sky: AssaultSky
	var _stars := PackedVector3Array()
	var _far := FastNoiseLite.new()
	var _near := FastNoiseLite.new()

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 91
		for i in 160:
			_stars.append(Vector3(rng.randf(), rng.randf() * 0.7, rng.randf()))
		_far.seed = 5
		_far.frequency = 0.004
		_near.seed = 9
		_near.frequency = 0.006

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var info: Dictionary = PlanetData.TYPES[sky.planet_type]
		var base: Color = info["base"]
		var accent: Color = info["accent"]
		var top := Color(0.008, 0.008, 0.022)
		var horizon := Color(accent * 0.11, 1.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, size.y), Vector2(0.0, size.y)]),
			PackedColorArray([top, top, horizon, horizon]))
		for star in _stars:
			var x := fposmod(star.x * size.x - sky.scroll * 0.03, size.x)
			draw_rect(Rect2(Vector2(x, star.y * size.y), Vector2(1.5, 1.5)), Color(0.7, 0.72, 1.0, 0.2 + 0.5 * star.z * star.z))
		var moon := Vector2(size.x * 0.78 - sky.scroll * 0.01, size.y * 0.2)
		draw_circle(moon, 46.0, Color(base * 0.6 + Color(0.1, 0.1, 0.12), 1.0))
		draw_circle(moon + Vector2(-12.0, -8.0), 40.0, Color(accent * 0.12, 0.6))
		_draw_range(_far, sky.scroll * 0.2, size.y * 0.62, 110.0, Color(base * 0.14 + accent * 0.03, 1.0))
		_draw_range(_near, sky.scroll * 0.45, size.y * 0.72, 90.0, Color(base * 0.2 + accent * 0.04, 1.0))

	func _draw_range(noise: FastNoiseLite, offset: float, baseline: float, height: float, color: Color) -> void:
		var points := PackedVector2Array()
		var x := 0.0
		while x <= size.x + 20.0:
			points.append(Vector2(x, baseline - absf(noise.get_noise_1d(x + offset)) * height * 1.6))
			x += 20.0
		points.append(Vector2(size.x + 20.0, size.y))
		points.append(Vector2(0.0, size.y))
		draw_colored_polygon(points, color)


func _ready() -> void:
	layer = -1
	_drawer = SkyDrawer.new()
	_drawer.sky = self
	add_child(_drawer)
