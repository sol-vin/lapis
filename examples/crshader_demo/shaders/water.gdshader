shader_type canvas_item;

render_mode unshaded;

uniform float wave_speed : hint_range(0.1, 5.0) = 1.8;
uniform float wave_frequency : hint_range(1.0, 30.0) = 8.0;
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.04;
uniform vec4 water_color : source_color = vec4(0.12, 0.52, 0.88, 0.9);
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	float wave_x = (sin(((uv.y * wave_frequency) + (TIME * wave_speed))) * wave_amplitude);
	float wave_y = (cos((((uv.x * wave_frequency) * 0.7) + ((TIME * wave_speed) * 1.2))) * (wave_amplitude * 0.5));
	vec2 distorted_uv = vec2((uv.x + wave_x), (uv.y + wave_y));
	float foam_factor = clamp(((sin(((distorted_uv.y + ((TIME * wave_speed) * 0.2)) * 20.0)) * 0.5) + 0.5), 0.0, 1.0);
	vec3 base_col = water_color.rgb;
	vec3 foam_col = foam_color.rgb;
	vec3 final_rgb = mix(base_col, foam_col, (foam_factor * 0.35));
	COLOR = vec4(final_rgb, water_color.a);
}

