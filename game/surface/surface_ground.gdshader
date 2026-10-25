shader_type canvas_item;
// The ground of a planet's surface: mottled rock and dust in the planet's
// palette with faint glowing cracks. `kindled` warms and brightens it once
// the planet has been relit.

uniform vec4 base_color : source_color = vec4(0.3, 0.27, 0.25, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float kindled = 0.0;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

void fragment() {
	vec2 uv = world / 1400.0;
	float broad = texture(noise_tex, uv).r;
	float mid = texture(noise_tex, uv * 3.3 + vec2(0.31, 0.77)).r;
	float fine = texture(noise_tex, uv * 13.0 + vec2(0.5, 0.2)).r;
	vec3 col = base_color.rgb * (0.7 + 0.4 * broad) * (0.9 + 0.2 * fine);
	col = mix(col, accent_color.rgb * 0.3, smoothstep(0.62, 0.9, mid) * 0.25);
	float crack = 1.0 - smoothstep(0.0, 0.018, abs(mid - 0.5));
	col += accent_color.rgb * crack * (0.1 + 0.45 * kindled) * smoothstep(0.35, 0.7, broad);
	col *= mix(0.85, 1.1, kindled);
	COLOR = vec4(col, 1.0);
}
