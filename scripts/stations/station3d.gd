class_name Station3D
extends Node3D
## Shared kit for the 3D prep-station appliances (the stove and the
## blender): tweens that report when a sequence ends, ice cubes dropped into
## the served glass, soft steam and smoke, grains poured off a spoon, and
## screen rects for taps and the tutorial. Mounted on the PrepRig, so local
## space is FIFI's (the tail at +x, her left at +z). Purely visual: the
## gauges and PrepStation drive it.

signal sequence_finished

## The rig: its camera turns 3D spots into screen rects.
var rig: PrepRig
## The drink is iced: the glass stops steaming.
var iced := false

var _t := 0.0
var _tween: Tween
var _busy := false
var _rng := RandomNumberGenerator.new()
var _ice: Array[Node3D] = []

static var _soft_tex: Texture2D


func _ready() -> void:
	_rng.randomize()


#region Screen space

## Screen rect round a box in local space.
func local_rect(box: AABB) -> Rect2:
	if rig == null:
		return Rect2()
	return rig.screen_rect_of(global_transform * box)


func screen_of(local: Vector3) -> Vector2:
	if rig == null:
		return Vector2.ZERO
	return rig.screen_point(global_transform * local)


## Screen rect round the appliance, for the tutorial's spotlight.
func focus_rect() -> Rect2:
	return local_rect(_focus_box())


func _focus_box() -> AABB:
	return AABB(Vector3.ZERO, Vector3.ONE * 0.3)

#endregion


#region Ice

## Where the served glass's drink surface is (local), for the cubes.
func _ice_surface() -> Vector3:
	return Vector3.ZERO


## Drops one cube into the glass; it splashes, bobs and floats.
func add_ice_cube() -> void:
	var n := _ice.size()
	var cube := Node3D.new()
	var v := Vox.new()
	v.use("glass").cube(Vector3.ZERO, Vector3(0.028, 0.028, 0.028), Color(0.88, 0.96, 1.0, 0.75))
	v.cube(Vector3(0.004, 0.006, 0.004), Vector3(0.014, 0.012, 0.014), Color(1, 1, 1, 0.5))
	v.into(cube)
	add_child(cube)
	_ice.append(cube)
	iced = true
	var surf := _ice_surface()
	var off := [Vector3(0.012, 0, -0.01), Vector3(-0.014, 0, 0.01), Vector3(0.0, 0, 0.016), Vector3(-0.004, 0, -0.016),
		Vector3(0.016, 0, 0.012)][n % 5] as Vector3
	var rest := surf + off + Vector3(0, -0.006 - float(n % 2) * 0.008, 0)
	cube.position = rest + Vector3(0, 0.2, 0)
	cube.rotation = Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0, TAU), _rng.randf_range(-0.5, 0.5))
	var t := create_tween()
	t.tween_property(cube, "position", rest + Vector3(0, -0.012, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_splash.bind(rest))
	t.tween_property(cube, "position", rest, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_ice() -> void:
	for c in _ice:
		c.queue_free()
	_ice.clear()
	iced = false


func _splash(at: Vector3) -> void:
	var p := _burst(at, Color(1, 1, 1, 0.8), 8, 0.012, Vector3(0, 0.5, 0), 0.35)
	p.spread = 70.0

#endregion


#region Particles

static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_soft_tex = tex
	return _soft_tex


## A soft billboard puff emitter (steam, smoke).
func _puffs(color: Color, size: float, rise: float, life: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = soft_texture()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, rise * 0.3, 0)
	p.initial_velocity_min = rise * 0.6
	p.initial_velocity_max = rise
	p.damping_min = 0.05
	p.damping_max = 0.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.8))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	return p


## A one-shot shower of little cubes (sugar grains, tea leaves, drops).
func _burst(at: Vector3, color: Color, count: int, size: float, vel: Vector3, life: float, auto_free := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var b := BoxMesh.new()
	b.size = Vector3.ONE * size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.roughness = 0.8
	b.material = m
	p.mesh = b
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = count
	p.lifetime = life
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length()
	p.gravity = Vector3(0, -3.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.01
	p.angular_velocity_min = -200
	p.angular_velocity_max = 200
	add_child(p)
	p.emitting = true
	if auto_free:
		get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p

#endregion


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _finish_sequence() -> void:
	if _busy:
		_busy = false
		sequence_finished.emit()


## A liquid that shades from `bottom` to `top` colour up its height and
## shows only between two heights (so one mesh fills to any level).
static func liquid_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _liquid_shader()
	return sm


static var _liquid_sh: Shader


static func _liquid_shader() -> Shader:
	if _liquid_sh == null:
		_liquid_sh = Shader.new()
		_liquid_sh.code = """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
uniform vec4 col_bottom : source_color = vec4(0.6, 0.25, 0.1, 0.9);
uniform vec4 col_top : source_color = vec4(0.6, 0.25, 0.1, 0.9);
uniform float y0 = 0.0;
uniform float y1 = 1.0;
uniform float swirl = 0.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	if (lp.y < y0 - 0.0005 || lp.y > y1 + 0.0005) { discard; }
	float t = clamp((lp.y - y0) / max(y1 - y0, 0.001), 0.0, 1.0);
	vec4 c = mix(col_bottom, col_top, t);
	float band = swirl * 0.22 * smoothstep(0.55, 1.0, sin(atan(lp.z, lp.x) * 3.0 + lp.y * 60.0 - TIME * 9.0));
	ALBEDO = c.rgb + vec3(band);
	ALPHA = c.a;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
"""
	return _liquid_sh
