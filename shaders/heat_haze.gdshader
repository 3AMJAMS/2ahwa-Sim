shader_type canvas_item;
// Shimmer over the gas flame: wobbles what's already drawn behind it.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float fade = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.75, UV.y) * (1.0 - abs(UV.x - 0.5) * 2.0);
	float wave = sin(UV.y * 40.0 - TIME * 7.0) + 0.5 * sin(UV.y * 73.0 + UV.x * 9.0 - TIME * 11.0);
	vec2 offset = vec2(wave, 0.3 * wave) * 0.0035 * strength * fade;
	COLOR = texture(screen_tex, SCREEN_UV + offset);
}
