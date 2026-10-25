class_name RegionLayer
extends Node2D
## Region fills: murky fog while dark, a spreading light while being claimed,
## and the ignition wave that makes a region yours. See region.gdshader.

const RegionShader: Shader = preload("res://game/space/region.gdshader")

enum Look { DARK = 0, FRONTIER = 1, CLAIMING = 2, CLAIMED = 3 }

## Fog tint per modifier: color, strength, pulse.
const TINTS := {
	RegionData.Modifier.NEST: [Color(0.36, 0.08, 0.5), 0.5, 0.7],
	RegionData.Modifier.RICH: [Color(0.5, 0.36, 0.08), 0.3, 0.3],
	RegionData.Modifier.ASTEROIDS: [Color(0.16, 0.13, 0.12), 0.35, 0.0],
	RegionData.Modifier.NEBULA: [Color(0.1, 0.16, 0.42), 0.55, 0.2],
}
const HEART_TINT := [Color(0.55, 0.02, 0.1), 0.5, 1.0]

var _fills: Array[Polygon2D] = []
var _noise: NoiseTexture2D


func build(sector: SectorData) -> void:
	for fill in _fills:
		fill.queue_free()
	_fills.clear()
	if _noise == null:
		_noise = _make_noise()
	for region in sector.regions:
		var fill := Polygon2D.new()
		fill.polygon = region.polygon
		var shader_material := ShaderMaterial.new()
		shader_material.shader = RegionShader
		shader_material.set_shader_parameter("noise_tex", _noise)
		shader_material.set_shader_parameter("nebula_color", region.nebula_color)
		var tint: Array = HEART_TINT if region.is_heart else TINTS.get(region.modifier, [])
		if not tint.is_empty():
			shader_material.set_shader_parameter("tint_color", tint[0])
			shader_material.set_shader_parameter("tint_strength", tint[1])
			shader_material.set_shader_parameter("tint_pulse", tint[2])
		fill.material = shader_material
		add_child(fill)
		_fills.append(fill)
	refresh(sector)


## Re-derives each region's look from claim state: dark, frontier or claimed.
func refresh(sector: SectorData) -> void:
	for region in sector.regions:
		var look := Look.DARK
		if region.claimed:
			look = Look.CLAIMED
		elif sector.is_frontier(region.id):
			look = Look.FRONTIER
		set_param(region.id, "state", float(look))


func set_param(region_id: int, param: StringName, value: Variant) -> void:
	if region_id < 0 or region_id >= _fills.size():
		return
	var shader_material := _fills[region_id].material as ShaderMaterial
	shader_material.set_shader_parameter(param, value)


func _make_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	return texture
