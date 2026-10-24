shader_type canvas_item;
// Region fill. Dark regions are murky fog; a region being claimed shows light
// spreading out from the spark; claimed regions turn translucent so the stars
// and the region's own nebula colors show through. The ignition wave converts
// dark to claimed as it passes.
//
// Colors are uniforms with source_color so they look right with HDR 2D on.

// 0 = dark, 1 = frontier (claimable), 2 = being claimed, 3 = claimed
uniform float state = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 fog_deep : source_color = vec4(0.045, 0.028, 0.08, 0.88);
uniform vec4 fog_light : source_color = vec4(0.16, 0.08, 0.23, 0.88);
uniform vec4 light_color : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform vec4 alarm_color : source_color = vec4(0.5, 0.05, 0.06, 1.0);
uniform vec4 nebula_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec2 spark_pos = vec2(0.0);
uniform float claim_radius = 0.0;
uniform float alarm = 0.0;
uniform vec2 ignite_pos = vec2(0.0);
uniform float ignite_radius = -1.0;

varying vec2 world_pos;

void vertex() {
	// Region polygons are built in world coordinates at the origin.
	world_pos = VERTEX;
}

vec4 dark_look(float n, float n2) {
	vec4 col = mix(fog_deep, fog_light, smoothstep(0.35, 0.85, n) * 0.8);
	col.rgb += fog_light.rgb * 0.5 * smoothstep(0.6, 0.95, n2);
	return col;
}

vec4 claimed_look(float n, float n2) {
	float cloud = smoothstep(0.35, 0.85, n);
	float wisps = smoothstep(0.55, 0.9, n2);
	vec3 col = light_color.rgb * 0.06 + nebula_color.rgb * (cloud * 0.35 + wisps * 0.25);
	return vec4(col, 0.08 + 0.25 * cloud);
}

void fragment() {
	vec2 uv = world_pos / 1100.0;
	float n = texture(noise_tex, uv + vec2(TIME * 0.006, TIME * 0.004)).r;
	float n2 = texture(noise_tex, uv * 2.7 + vec2(-TIME * 0.011, TIME * 0.007)).r;
	vec4 col;
	if (state > 2.5) {
		col = claimed_look(n, n2);
	} else {
		col = dark_look(n, n2);
		if (state > 0.5 && state < 1.5) {
			float pulse = 0.6 + 0.4 * sin(TIME * 2.2);
			col.rgb += light_color.rgb * 0.025 * pulse;
		}
		if (state > 1.5) {
			float d = distance(world_pos, spark_pos);
			float inside = 1.0 - smoothstep(claim_radius - 140.0, claim_radius, d);
			float flicker = 0.85 + 0.15 * sin(TIME * 7.0 + n * 12.0);
			vec4 lit = claimed_look(n, n2);
			lit.rgb += light_color.rgb * 0.08 * flicker;
			lit.a = max(lit.a, 0.3);
			col = mix(col, lit, inside * 0.8);
			float front = 1.0 - smoothstep(0.0, 22.0, abs(d - claim_radius));
			col.rgb += light_color.rgb * front * 1.4 * flicker;
			col.a = max(col.a, front * 0.8);
			col.rgb = mix(col.rgb, alarm_color.rgb, alarm * 0.35);
		}
	}
	if (ignite_radius >= 0.0) {
		float d = distance(world_pos, ignite_pos);
		if (d < ignite_radius) {
			col = claimed_look(n, n2);
		}
		// A bright wavefront with a short wash of light trailing behind it.
		float ring = 1.0 - smoothstep(0.0, 28.0, abs(d - ignite_radius));
		float wash = smoothstep(ignite_radius - 260.0, ignite_radius, d) * step(d, ignite_radius);
		col.rgb += light_color.rgb * (1.6 * ring + 0.25 * wash);
		col.a = max(col.a, max(ring * 0.9, wash * 0.4));
	}
	COLOR = col;
}
