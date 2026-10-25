class_name PlanetLayer
extends Node2D
## Planets in space. Dormant ones are grey, with an orbit ring that lights a
## segment for each surrounding region you claim. Once surrounded a planet
## wakes in its own colors and can be landed on; kindled planets glow warmly.

const PlanetShader: Shader = preload("res://game/space/planet.gdshader")
const RING_GAP := 26.0
const LIT_RING := Color(1.6, 1.1, 0.45)
const DIM_RING := Color(0.45, 0.4, 0.55, 0.45)

var sector: SectorData
var map_mode := false
var zoom := 1.0

var _disks: Array[Polygon2D] = []
var _noise: NoiseTexture2D
var _time := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func build(new_sector: SectorData) -> void:
	sector = new_sector
	for disk in _disks:
		disk.queue_free()
	_disks.clear()
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.noise = noise
	for planet in sector.planets:
		var disk := Polygon2D.new()
		var points := PackedVector2Array()
		for i in 64:
			points.append(Vector2.from_angle(TAU * i / 64.0) * planet.radius)
		disk.polygon = points
		disk.position = planet.position
		var shader_material := ShaderMaterial.new()
		shader_material.shader = PlanetShader
		shader_material.set_shader_parameter("radius", planet.radius)
		shader_material.set_shader_parameter("base_color", planet.info()["base"])
		shader_material.set_shader_parameter("accent_color", planet.info()["accent"])
		shader_material.set_shader_parameter("seed", float(planet.surface_seed % 1000) / 97.0)
		shader_material.set_shader_parameter("noise_tex", _noise)
		disk.material = shader_material
		add_child(disk)
		_disks.append(disk)


func _process(delta: float) -> void:
	_time += delta
	if sector == null:
		return
	for planet in sector.planets:
		var shader_material := _disks[planet.id].material as ShaderMaterial
		var awake := 1.0 if planet.kindled or planet.is_awake(sector) else 0.0
		shader_material.set_shader_parameter("awake", awake)
		shader_material.set_shader_parameter("kindled", 1.0 if planet.kindled else 0.0)
	queue_redraw()


func _draw() -> void:
	if sector == null:
		return
	var pixel := 1.0 / maxf(zoom, 0.01)
	for planet in sector.planets:
		_draw_halo(planet)
		_draw_ring(planet, pixel)
		if map_mode:
			_draw_label(planet, pixel)


func _draw_halo(planet: PlanetData) -> void:
	var accent: Color = planet.info()["accent"]
	if planet.kindled or planet.is_awake(sector):
		var pulse := 0.0 if planet.kindled else 0.5 + 0.5 * sin(_time * 2.4)
		draw_circle(planet.position, planet.radius * (1.22 + 0.05 * pulse), Color(accent, 0.08 + 0.06 * pulse))
		draw_circle(planet.position, planet.radius * 1.1, Color(accent, 0.14))
	else:
		draw_circle(planet.position, planet.radius * 1.12, Color(0.5, 0.45, 0.6, 0.06))


## One arc per surrounding region, lit once that region is yours.
func _draw_ring(planet: PlanetData, pixel: float) -> void:
	var ring_radius := planet.radius + RING_GAP
	var count := planet.touching.size()
	var angles: Array[float] = []
	for region_id in planet.touching:
		angles.append((sector.regions[region_id].anchor - planet.position).angle())
	var order := range(count)
	order.sort_custom(func(a: int, b: int) -> bool: return angles[a] < angles[b])
	var arc := TAU / count
	for slot in count:
		var region := sector.regions[planet.touching[order[slot]]]
		var start := -PI * 0.5 + slot * arc + 0.06
		var color := LIT_RING if region.claimed or planet.kindled else DIM_RING
		draw_arc(planet.position, ring_radius, start, start + arc - 0.12, 24, color, (3.0 if region.claimed else 2.0) * pixel)


func _draw_label(planet: PlanetData, pixel: float) -> void:
	var width := 360.0 * pixel
	var top := planet.position + Vector2(-width * 0.5, planet.radius + RING_GAP + 22.0 * pixel)
	var accent: Color = planet.info()["accent"]
	var status := "KINDLED"
	if not planet.kindled:
		status = "AWAKE  ·  LAND" if planet.is_awake(sector) else "DORMANT  %d/%d" % [planet.claimed_around(sector), planet.touching.size()]
	draw_string(_font, top, planet.name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, width, int(14.0 * pixel), accent)
	var detail := "%s  ·  %s  ·  %s" % [planet.type_name(), PlanetData.RESOURCE_NAMES[planet.resource()], status]
	draw_string(_font, top + Vector2(0.0, 17.0 * pixel), detail, HORIZONTAL_ALIGNMENT_CENTER, width, int(11.0 * pixel), Color(0.85, 0.82, 0.95))
