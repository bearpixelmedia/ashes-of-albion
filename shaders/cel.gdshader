shader_type spatial;
render_mode specular_disabled;

// Three-tone cel ramp with an ambient floor so unlit faces stay readable at dusk.
uniform vec4 albedo_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float ambient_floor : hint_range(0.0, 1.0) = 0.2;
uniform float ambient_emit : hint_range(0.0, 1.0) = 0.14;
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_strength = 0.0;

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = 1.0;
	EMISSION = albedo_color.rgb * ambient_emit + emission_color * emission_strength;
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float band = floor(ndl * 3.0 + 0.0001) / 3.0;
	float factor = ambient_floor + (1.0 - ambient_floor) * band;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ALBEDO * factor;
}
