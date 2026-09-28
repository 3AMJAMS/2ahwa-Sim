shader_type canvas_item;
// Tutorial dim: darkens the whole screen except a rounded-rect spotlight
// (`hole`, in pixels: x, y, width, height) around what Sayed is talking about.

uniform vec2 rect_size = vec2(1080.0, 1920.0);
uniform vec4 hole = vec4(0.0);
uniform float radius = 26.0;
uniform float feather = 14.0;
uniform float dim : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 p = UV * rect_size;
	float a = 1.0;
	if (hole.z > 0.0) {
		vec2 c = hole.xy + hole.zw * 0.5;
		vec2 q = abs(p - c) - hole.zw * 0.5 + vec2(radius);
		float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
		a = smoothstep(0.0, feather, d);
	}
	COLOR = vec4(0.02, 0.01, 0.05, dim * a);
}
