class_name AssaultTerrain
extends Node2D
## The ground of a planet seen from the side during an assault: rolling hills
## and the odd peak in the planet's palette, with a glowing rim, surface
## details that suit the world type, and a flat plateau at the end where the
## bastion stands. Also answers "how high is the ground here?".

const STEP := 40.0
const BASE_Y := 600.0
const LOWEST := 660.0
const HIGHEST := 400.0
const BOTTOM := 900.0

var planet_type := PlanetData.Type.ASHEN
var length := 8000.0
## Where the plateau for the bastion starts.
var plateau_from := 7000.0
var _heights := PackedFloat32Array()
var _origin := -400.0
var _details: Array[Dictionary] = []


func build(seed_value: int, type: PlanetData.Type, stage_length: float, plateau_start: float) -> void:
	planet_type = type
	length = stage_length
	plateau_from = plateau_start
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.0022
	noise.fractal_octaves = 3
	var peaks := FastNoiseLite.new()
	peaks.seed = seed_value + 17
	peaks.frequency = 0.0009
	_heights.clear()
	var x := _origin
	while x <= length + 800.0:
		var height := BASE_Y + noise.get_noise_1d(x) * 80.0
		var peak := maxf(peaks.get_noise_1d(x) - 0.25, 0.0) * 520.0
		height -= peak
		# Ease into the plateau so the bastion has flat ground.
		var flat := clampf((x - plateau_from) / 400.0, 0.0, 1.0)
		height = lerpf(height, BASE_Y + 20.0, flat)
		# And keep the first screen gentle.
		height = lerpf(BASE_Y + 30.0, height, clampf((x - 200.0) / 600.0, 0.0, 1.0))
		_heights.append(clampf(height, HIGHEST, LOWEST))
		x += STEP
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 3
	_details.clear()
	x = _origin
	while x < length + 800.0:
		x += rng.randf_range(60.0, 180.0)
		_details.append({"x": x, "size": rng.randf_range(0.6, 1.4), "lean": rng.randf_range(-0.3, 0.3)})
	queue_redraw()


## Height of the ground (screen y, larger is lower) at world x.
func ground_y(x: float) -> float:
	if _heights.is_empty():
		return BASE_Y
	var t := (x - _origin) / STEP
	var i := clampi(floori(t), 0, _heights.size() - 2)
	return lerpf(_heights[i], _heights[i + 1], clampf(t - i, 0.0, 1.0))


## The ground's slope at x (rise over run), for placing things on flat spots.
func slope(x: float) -> float:
	return (ground_y(x + 20.0) - ground_y(x - 20.0)) / 40.0


func _draw() -> void:
	var info: Dictionary = PlanetData.TYPES[planet_type]
	var base: Color = info["base"]
	var accent: Color = info["accent"]
	var ground := PackedVector2Array()
	var rim := PackedVector2Array()
	for i in _heights.size():
		var point := Vector2(_origin + i * STEP, _heights[i])
		ground.append(point)
		rim.append(point)
	ground.append(Vector2(_origin + (_heights.size() - 1) * STEP, BOTTOM))
	ground.append(Vector2(_origin, BOTTOM))
	draw_colored_polygon(ground, Color(base * 0.35, 1.0))
	var under := PackedVector2Array()
	for point in rim:
		under.append(point + Vector2(0.0, 28.0))
	draw_polyline(under, Color(accent * 0.25, 0.5), 10.0)
	draw_polyline(rim, accent * 0.9, 3.0)
	for detail in _details:
		_draw_detail(detail, accent)


## Little bits of surface: crystal spikes, mushrooms, fronds or rocks.
func _draw_detail(detail: Dictionary, accent: Color) -> void:
	var x: float = detail["x"]
	var at := Vector2(x, ground_y(x) + 2.0)
	var size: float = detail["size"]
	var up := Vector2.UP.rotated(float(detail["lean"]))
	match planet_type:
		PlanetData.Type.CRYSTAL, PlanetData.Type.FROST:
			var tip := at + up * 22.0 * size
			var side := up.orthogonal() * 4.0 * size
			draw_colored_polygon(PackedVector2Array([at - side, tip, at + side]), Color(accent * 0.6, 0.9))
		PlanetData.Type.FUNGAL:
			draw_line(at, at + up * 12.0 * size, Color(accent * 0.4, 0.9), 2.0)
			draw_circle(at + up * 13.0 * size, 5.0 * size, Color(accent * 0.7, 0.9))
		PlanetData.Type.VERDANT:
			for k in 3:
				var frond := up.rotated(-0.5 + 0.5 * k)
				draw_line(at, at + frond * 14.0 * size, Color(accent * 0.55, 0.9), 2.0)
		_:
			draw_circle(at + Vector2(0.0, -3.0 * size), 5.0 * size, Color(0.08, 0.06, 0.06, 1.0))
			draw_arc(at + Vector2(0.0, -3.0 * size), 5.0 * size, PI, TAU, 8, Color(accent * 0.5, 0.8), 1.5)
