class_name LanternVeil
extends CanvasLayer
## The dark of an unkindled planet. Everything is smothered except pools of
## light: the pilot's lantern, the lander, the pylon, flares, glowing hazards
## and deposits. Sits above the world and below the glints and the HUD.
##
## Each frame the mission calls begin(), adds lights in world space, then
## commit().

const MAX_LIGHTS := 24
const FADE_SPEED := 0.6

var strength := 0.94
var target_strength := 0.94

var _rect: ColorRect
var _material: ShaderMaterial
var _lights := PackedVector4Array()
var _canvas := Transform2D.IDENTITY
var _zoom := 1.0
var _view := Rect2()


func _ready() -> void:
	layer = 5
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
const int MAX_LIGHTS = %d;
uniform vec4 lights[MAX_LIGHTS];
uniform int light_count = 0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float strength = 0.94;
uniform vec4 veil_color : source_color = vec4(0.01, 0.008, 0.025, 1.0);

void fragment() {
	vec2 p = UV * rect_size;
	float lit = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 l = lights[i];
		float d = distance(p, l.xy);
		float a = 1.0 - smoothstep(l.z * 0.3, l.z, d);
		lit = max(lit, a * a * (3.0 - 2.0 * a) * l.w);
	}
	COLOR = vec4(veil_color.rgb, (1.0 - clamp(lit, 0.0, 1.0)) * strength);
}
""" % MAX_LIGHTS
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func begin(canvas: Transform2D, zoom: float) -> void:
	_lights.clear()
	_canvas = canvas
	_zoom = zoom
	_view = Rect2(Vector2.ZERO, _rect.size)


## A light at a world position. Lights well off screen are skipped, and once
## the limit is reached the rest are dropped (add the important ones first).
func add_light(world_position: Vector2, radius: float, intensity: float) -> void:
	if _lights.size() >= MAX_LIGHTS or intensity <= 0.01:
		return
	var screen := _canvas * world_position
	var screen_radius := radius * _zoom
	if not _view.grow(screen_radius).has_point(screen):
		return
	_lights.append(Vector4(screen.x, screen.y, screen_radius, intensity))


func commit(delta: float) -> void:
	strength = move_toward(strength, target_strength, delta * FADE_SPEED)
	visible = strength > 0.001
	var padded := _lights.duplicate()
	while padded.size() < MAX_LIGHTS:
		padded.append(Vector4.ZERO)
	_material.set_shader_parameter("lights", padded)
	_material.set_shader_parameter("light_count", _lights.size())
	_material.set_shader_parameter("rect_size", _rect.size)
	_material.set_shader_parameter("strength", strength)
