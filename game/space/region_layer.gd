class_name RegionLayer
extends Node2D
## Region fills: murky fog while dark, a spreading light while being claimed,
## and the ignition wave that makes a region yours. See region.gdshader.

const RegionShader: Shader = preload("res://game/space/region.gdshader")

enum Look { DARK = 0, FRONTIER = 1, CLAIMING = 2, CLAIMED = 3 }

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
