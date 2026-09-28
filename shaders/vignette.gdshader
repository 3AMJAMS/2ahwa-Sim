shader_type canvas_item;
// Soft dark edges over the whole screen; main.gd deepens it after dusk.

uniform float strength : hint_range(0.0, 1.0) = 0.3;
uniform vec3 tint : source_color = vec3(0.02, 0.01, 0.06);

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.85);
	float v = smoothstep(0.32, 0.8, length(d));
	COLOR = vec4(tint, v * strength);
}
