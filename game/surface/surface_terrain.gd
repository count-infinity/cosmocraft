class_name SurfaceTerrain
extends Node2D
## The static ground of a planet's surface: the textured floor, hazard pools
## (animated) and rocks (drawn once). Rocks sit on top so pools tuck under them.

const GroundShader: Shader = preload("res://game/surface/surface_ground.gdshader")
const MARGIN := 900.0

var map: SurfaceMap
## 0 while the planet is dark, 1 once kindled; brightens the ground.
var kindled := 0.0:
	set(value):
		kindled = value
		if _ground != null:
			(_ground.material as ShaderMaterial).set_shader_parameter("kindled", value)

var _ground: Polygon2D
var _pools: PoolLayer
var _rocks: RockLayer


class PoolLayer extends Node2D:
	var map: SurfaceMap
	var info: Dictionary
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var color: Color = info["color"]
		var hazard_type: String = PlanetData.TYPES[map.planet_type]["hazard"]
		for hazard in map.hazards:
			_draw_pool(hazard, color, hazard_type)

	func _draw_pool(hazard: SurfaceMap.Hazard, color: Color, hazard_type: String) -> void:
		var outer := PackedVector2Array()
		var body := PackedVector2Array()
		var inner := PackedVector2Array()
		for point in hazard.outline:
			outer.append(hazard.position + point * 1.12)
			body.append(hazard.position + point)
			inner.append(hazard.position + point * 0.66)
		var pulse := 0.5 + 0.5 * sin(_time * 1.7 + hazard.radius)
		draw_colored_polygon(outer, Color(color, 0.05 + 0.03 * pulse))
		draw_colored_polygon(body, Color(color * 0.1, 0.95))
		draw_colored_polygon(inner, Color(color * (0.16 + 0.04 * pulse), 0.9))
		var closed := body.duplicate()
		closed.append(body[0])
		draw_polyline(closed, Color(color * 0.75, 0.85), 2.5)
		# Specks: bubbles, embers, shards, spores or frost, by type.
		for i in 9:
			var phase := float(i) * 2.39996 + hazard.radius
			var t := fmod(_time * 0.35 + float(i) / 9.0, 1.0)
			var reach := hazard.radius * 0.7 * sqrt(fract_hash(phase))
			var spot := hazard.position + Vector2.from_angle(phase) * reach
			var glow := sin(t * PI)
			match hazard_type:
				"shards", "cryo":
					var size := 5.0 + 4.0 * fract_hash(phase * 1.7)
					var spike := PackedVector2Array([spot + Vector2(0, -size * 1.6), spot + Vector2(size * 0.5, 0), spot + Vector2(0, size * 0.6), spot + Vector2(-size * 0.5, 0)])
					draw_colored_polygon(spike, color * (0.6 + 0.8 * glow))
				"spores":
					draw_circle(spot + Vector2(0.0, -t * 40.0), 2.0 + 2.5 * glow, Color(color, glow))
				_:
					draw_circle(spot, 2.0 + 4.0 * glow, Color(color * 1.2, glow))

	static func fract_hash(value: float) -> float:
		var s := sin(value * 12.9898) * 43758.5453
		return s - floorf(s)


class RockLayer extends Node2D:
	var map: SurfaceMap
	var base: Color
	var accent: Color

	func _draw() -> void:
		var shadow := Color(0.0, 0.0, 0.0, 0.4)
		var body_color := Color(base * 0.5, 1.0)
		var top_color := Color(base * 0.78, 1.0)
		var rim_color := Color(accent * 0.5, 0.55)
		for rock in map.rocks:
			var body := PackedVector2Array()
			var cast := PackedVector2Array()
			var top := PackedVector2Array()
			var lift := Vector2(-0.1, -0.16) * rock.radius
			for point in rock.outline:
				body.append(rock.position + point)
				cast.append(rock.position + point + Vector2(10.0, 14.0))
				top.append(rock.position + lift + point * 0.72)
			draw_colored_polygon(cast, shadow)
			draw_colored_polygon(body, body_color)
			draw_colored_polygon(top, top_color)
			body.append(body[0])
			draw_polyline(body, rim_color, 1.5)


func build(new_map: SurfaceMap) -> void:
	map = new_map
	var info: Dictionary = PlanetData.TYPES[map.planet_type]
	var noise := FastNoiseLite.new()
	noise.seed = map.map_seed
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	var shader_material := ShaderMaterial.new()
	shader_material.shader = GroundShader
	shader_material.set_shader_parameter("base_color", info["base"])
	shader_material.set_shader_parameter("accent_color", info["accent"])
	shader_material.set_shader_parameter("noise_tex", texture)
	shader_material.set_shader_parameter("kindled", kindled)
	var area := map.bounds.grow(MARGIN)
	_ground = Polygon2D.new()
	_ground.polygon = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	_ground.material = shader_material
	add_child(_ground)
	_pools = PoolLayer.new()
	_pools.map = map
	_pools.info = map.hazard_info()
	add_child(_pools)
	_rocks = RockLayer.new()
	_rocks.map = map
	_rocks.base = info["base"]
	_rocks.accent = info["accent"]
	add_child(_rocks)
