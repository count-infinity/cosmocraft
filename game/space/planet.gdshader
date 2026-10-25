shader_type canvas_item;
// A planet disk: a lit sphere with slowly turning continents in the planet's
// palette. Dormant planets are grey; kindled ones show warm city lights on
// their night side.

uniform float radius = 100.0;
uniform vec4 base_color : source_color = vec4(0.3, 0.27, 0.25, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform vec4 dormant_color : source_color = vec4(0.11, 0.1, 0.13, 1.0);
uniform vec4 city_color : source_color = vec4(1.0, 0.75, 0.4, 1.0);
uniform float awake = 0.0;
uniform float kindled = 0.0;
uniform float seed = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

varying vec2 local;

void vertex() {
	local = VERTEX / radius;
}

void fragment() {
	float d = length(local);
	if (d > 1.0) {
		discard;
	}
	float z = sqrt(1.0 - d * d);
	vec2 surface = local / (1.0 + z);
	vec2 uv = surface * 0.7 + vec2(TIME * 0.008 + seed, seed * 0.37);
	float n = texture(noise_tex, uv).r;
	float n2 = texture(noise_tex, uv * 2.6 + vec2(3.1, 1.7)).r;
	vec3 land = mix(base_color.rgb, accent_color.rgb * 0.55, smoothstep(0.48, 0.78, n));
	land += accent_color.rgb * 0.2 * smoothstep(0.7, 0.95, n2);
	vec3 col = mix(dormant_color.rgb * (0.7 + 0.6 * n), land, awake);
	float light = clamp(dot(normalize(vec3(local, z)), normalize(vec3(-0.55, -0.6, 0.6))), 0.0, 1.0);
	col *= 0.3 + 0.8 * light;
	col += accent_color.rgb * smoothstep(0.78, 1.0, d) * 0.7 * awake;
	float cities = step(0.8, texture(noise_tex, uv * 7.0).r) * (1.0 - light) * kindled;
	col += city_color.rgb * 2.5 * cities;
	COLOR = vec4(col, 1.0);
}
