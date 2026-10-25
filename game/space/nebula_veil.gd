class_name NebulaVeil
extends CanvasLayer
## Darkness that closes in around the ship inside an unlit nebula region.
## Sits above the world and below the HUD.

const RADIUS := 300.0
const FADE_SPEED := 2.5

var strength := 0.0
var target_strength := 0.0

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 5
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 center = vec2(640.0, 360.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float radius = 300.0;
uniform float strength = 0.0;
uniform vec4 veil_color : source_color = vec4(0.02, 0.015, 0.05, 1.0);

void fragment() {
	float d = distance(UV * rect_size, center);
	float dark = smoothstep(radius * 0.45, radius, d);
	COLOR = vec4(veil_color.rgb, dark * strength * 0.94);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	visible = false


## `screen_position` is the ship on screen; `zoom` scales the clear radius.
func update_veil(delta: float, screen_position: Vector2, zoom: float) -> void:
	strength = move_toward(strength, target_strength, delta * FADE_SPEED)
	visible = strength > 0.001
	if not visible:
		return
	_material.set_shader_parameter("center", screen_position)
	_material.set_shader_parameter("rect_size", _rect.size)
	_material.set_shader_parameter("radius", RADIUS * zoom)
	_material.set_shader_parameter("strength", strength)
