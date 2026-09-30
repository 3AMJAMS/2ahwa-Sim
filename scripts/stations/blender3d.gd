class_name Blender3D
extends Station3D
## The cold station in blocks: a cheap cream plastic blender on the counter
## (heat lights, buttons, a speed dial, vents that glow as the motor
## heats), its glass jar with the fruit going round, and a tall glass it
## pours into. BlendGauge feeds progress/motor_heat/running/holding/
## tripped and calls pour()/trip(); PrepStation drops the fruit in.

const AT := PrepRig.BLENDER_AT
const GLASS := PrepRig.GLASS_AT
const JAR_H := 0.26
## Jar radius at the bottom and at the top (inside).
const JAR_R := Vector2(0.055, 0.08)
const BASE_H := 0.13
## Jar local space: origin at the bottom of the glass, the pour lip at -z.
const SPOUT := Vector3(0.0, JAR_H, 0.085)
const REST_PIVOT := AT + Vector3(0, BASE_H, 0) + SPOUT
const LIFT_PIVOT := REST_PIVOT + Vector3(0, 0.12, 0)
const POUR_PIVOT := GLASS + Vector3(0.0, 0.34, -0.05)
const POUR_TILT := 1.0
const POUR_TILT_END := 1.45
const START_LEVEL := 0.58
## The tall glass it pours into.
const TG_R := Vector2(0.052, 0.066)
const TG_H := 0.24
const GLASS_FULL := 0.86
const LED_COLORS := [Color("4caf50"), Color("4caf50"), Color("e6c33a"), Color("e6c33a"), Color("f08a2c"), Color("e0452b")]
const RED_ZONE := 80.0
const BODY := Color("e8e0cc")
const PANEL := Color("2b2a30")
const LID := Color("2f2d34")
const METAL := Color("b3b9c2")

## Fed by BlendGauge every frame.
var progress := 0.0
var motor_heat := 0.0
var running := false
var holding := false
var tripped := false

var jar_pivot := REST_PIVOT
var jar_tilt := 0.0
var jar_level := START_LEVEL
var stream := 0.0
var glass_fill := 0.0
var straw := 0.0
## Fruit in the jar (0 empty, 1 in).
var fruit := 1.0

var _liquid := Color("f2a324")
var _bits := Color("f7c64f")
var _speed := 0.0
var _spin := 0.0
var _jar := Node3D.new()
var _jar_body := Node3D.new()
var _blades := Node3D.new()
var _chunks: Array[MeshInstance3D] = []
var _jar_liquid := MeshInstance3D.new()
var _jar_mat := Station3D.liquid_material()
var _tall := Node3D.new()
var _tall_liquid := MeshInstance3D.new()
var _tall_mat := Station3D.liquid_material()
var _straw := Node3D.new()
var _leds: Array[MeshInstance3D] = []
var _vent_mat := StandardMaterial3D.new()
var _stream := MeshInstance3D.new()
var _stream_mesh := ImmediateMesh.new()
var _smoke: CPUParticles3D
var _base := Node3D.new()


func _ready() -> void:
	super()
	var v := Vox.new()
	_build_base(v)
	_build_jar(v)
	_build_tall(v)
	_stream.mesh = _stream_mesh
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	_stream.material_override = sm
	add_child(_stream)
	_smoke = _puffs(Color(0.16, 0.14, 0.15, 0.6), 0.08, 0.2, 1.6, 24)
	_smoke.position = AT + Vector3(0.0, 0.08, 0.1)
	reset()


## Recolours the drink: {"liquid", "bits"}.
func set_look(look: Dictionary) -> void:
	_liquid = Color(look.get("liquid", "#f2a324"))
	_bits = Color(look.get("bits", look.get("liquid", "#f7c64f")))
	for c in _chunks:
		(c.material_override as StandardMaterial3D).albedo_color = _bits


func reset() -> void:
	_kill_tween()
	_finish_sequence()
	progress = 0.0
	motor_heat = 0.0
	running = false
	holding = false
	tripped = false
	jar_pivot = REST_PIVOT
	jar_tilt = 0.0
	jar_level = START_LEVEL
	stream = 0.0
	glass_fill = 0.0
	straw = 0.0
	fruit = 1.0
	_speed = 0.0
	_reset_ice()
	_update()


## Shows the tall glass on the counter in place of the tea glass.
func show_glass(on: bool) -> void:
	_tall.visible = on


## Chunks of fruit tipped into the jar.
func add_fruit() -> void:
	fruit = 0.0
	_burst(AT + Vector3(0, BASE_H + JAR_H + 0.05, 0), _bits, 10, 0.022, Vector3(0, -0.3, 0), 0.4)
	create_tween().tween_property(self, "fruit", 1.0, 0.4).set_delay(0.15)


## Lifts the jar off the base and pours it into the glass. Returns once the
## glass is dressed; the jar goes back on the base by itself.
func pour() -> void:
	_kill_tween()
	running = false
	_busy = true
	var t := create_tween()
	_tween = t
	t.tween_interval(0.25)
	t.tween_property(self, "jar_pivot", LIFT_PIVOT, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "jar_pivot", POUR_PIVOT, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "jar_tilt", POUR_TILT, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "stream", 1.0, 0.08)
	t.tween_property(self, "glass_fill", GLASS_FULL, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "jar_tilt", POUR_TILT_END, 0.9)
	t.parallel().tween_property(self, "jar_level", 0.08, 0.9)
	t.tween_property(self, "stream", 0.0, 0.1)
	t.tween_property(self, "straw", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_finish_sequence)
	t.tween_property(self, "jar_pivot", LIFT_PIVOT, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "jar_tilt", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "jar_pivot", REST_PIVOT, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await sequence_finished


## The thermal cut-out trips: a crack of sparks and a puff of smoke.
func trip() -> void:
	_burst(AT + Vector3(0.0, 0.06, 0.11), Color(1.6, 1.3, 0.5), 16, 0.008, Vector3(0.3, 0.5, 0.3), 0.35)
	_smoke.restart()


## Screen rect round the blender (hold it to run it on turbo).
func blender_rect() -> Rect2:
	return local_rect(AABB(AT + Vector3(-0.12, 0, -0.12), Vector3(0.24, BASE_H + JAR_H + 0.06, 0.24)))


func _focus_box() -> AABB:
	return AABB(AT + Vector3(-0.12, 0, -0.12), Vector3(0.24, BASE_H + JAR_H + 0.06, 0.24))


func _ice_surface() -> Vector3:
	return GLASS + Vector3(0, 0.012 + 0.02 + glass_fill * (TG_H - 0.04), 0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var target := 0.0
	if running:
		target = 2.5 if holding else 1.0
	_speed = lerpf(_speed, target, minf(1.0, delta * 6.0))
	_spin += delta * _speed * 9.0
	_update()


func _update() -> void:
	var shake := Vector3.ZERO
	var at_rest := jar_pivot.is_equal_approx(REST_PIVOT)
	if at_rest:
		var amp := 0.0012 * _speed + (0.002 if running and motor_heat >= RED_ZONE else 0.0)
		shake = Vector3(sin(_t * 57.0), 0, sin(_t * 43.0 + 1.1)) * amp
	_base.position = shake * 0.5
	_jar.position = jar_pivot + shake
	_jar.rotation.x = jar_tilt
	_blades.rotation.y = _spin * 2.0
	# Liquid in the jar: rough and pale at first, smooth and deep once blended.
	var blend := clampf(progress / 100.0, 0.0, 1.0)
	var k := smoothstep(0.05, 0.9, blend)
	var raw := Color(_liquid.lerp(Color(0.92, 0.95, 1.0), 0.6), 0.55)
	var col := raw.lerp(Color(_liquid, 0.95), k)
	var level := lerpf(0.02, JAR_H - 0.02, jar_level) * fruit
	var upright := absf(jar_tilt) < 0.05
	_jar_liquid.visible = level > 0.005 and upright
	_jar_mat.set_shader_parameter("col_bottom", col.darkened(0.08))
	_jar_mat.set_shader_parameter("col_top", col.lightened(0.08))
	_jar_mat.set_shader_parameter("y0", 0.012)
	_jar_mat.set_shader_parameter("y1", 0.012 + level)
	_jar_mat.set_shader_parameter("swirl", clampf(_speed / 2.5, 0.0, 1.0))
	for i in _chunks.size():
		var c := _chunks[i]
		c.visible = upright and fruit > 0.5 and blend < 0.85 - i * 0.05
		var a := i * 1.7 + _spin * (1.0 + i * 0.1)
		var r := 0.02 + float(i % 3) * 0.013
		c.position = Vector3(cos(a) * r, 0.03 + float((i * 7) % 5) * 0.03 + sin(_t * 3.0 + i) * 0.01 * _speed, sin(a) * r)
	# Heat lights and vents.
	var lit := motor_heat / 100.0 * LED_COLORS.size()
	var blink := (0.5 + 0.5 * signf(sin(_t * 18.0))) if motor_heat >= RED_ZONE or tripped else 1.0
	for i in _leds.size():
		_leds[i].visible = lit > i and blink > 0.4
	Vox.set_glow("glow/blend", 2.2)
	var glow := smoothstep(50.0, 100.0, motor_heat)
	_vent_mat.albedo_color = Color("3a342c").lerp(Color("ff6a2a"), glow)
	_vent_mat.emission_enabled = glow > 0.05
	_vent_mat.emission = Color("ff6a2a") * glow * 2.0
	_smoke.emitting = (running or tripped) and motor_heat > 65.0
	# The tall glass.
	var ty := 0.012 + 0.02
	_tall_liquid.visible = glass_fill > 0.001
	_tall_mat.set_shader_parameter("col_bottom", Color(_liquid.darkened(0.05), 0.95))
	_tall_mat.set_shader_parameter("col_top", Color(_liquid.lightened(0.12), 0.95))
	_tall_mat.set_shader_parameter("y0", ty)
	_tall_mat.set_shader_parameter("y1", ty + glass_fill * (TG_H - 0.04))
	_straw.visible = straw > 0.01
	_straw.position = Vector3(0.01, 0.02 + (1.0 - straw) * 0.2, 0.0)
	# The pour.
	_stream_mesh.clear_surfaces()
	if stream > 0.01:
		var p0 := _jar.position
		var end := GLASS + Vector3(0, ty + glass_fill * (TG_H - 0.04), -0.01)
		var p1 := p0 + Vector3(0, -0.02, 0.04)
		var w := 0.009 * stream
		_stream_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_stream_mesh.surface_set_color(Color(_liquid.lightened(0.1), 1.0))
		var prev := PackedVector3Array()
		for i in 11:
			var t := i / 10.0
			var p := p0.lerp(p1, t).lerp(p1.lerp(end, t), t)
			var ring := PackedVector3Array([p + Vector3(w, 0, 0), p + Vector3(0, 0, w), p - Vector3(w, 0, 0), p - Vector3(0, 0, w)])
			if i > 0:
				for j in 4:
					var a := prev[j]
					var b := prev[(j + 1) % 4]
					var c := ring[j]
					var d := ring[(j + 1) % 4]
					for q in [a, c, b, b, c, d]:
						_stream_mesh.surface_add_vertex(q)
			prev = ring
		_stream_mesh.surface_end()


#region Building

func _build_base(v: Vox) -> void:
	_base.position = Vector3.ZERO
	add_child(_base)
	v.push_at(AT)
	# Squat tapered body, chrome trim, rubber feet.
	v.lathe([Vector2(0.11, 0.0), Vector2(0.115, 0.02), Vector2(0.095, BASE_H - 0.01), Vector2(0.085, BASE_H)], 8, BODY, true, true,
		PI / 8.0)
	v.cyl(Vector3(0, 0.024, 0), 0.114, 0.114, 0.006, Color("d9dde3"), 8, PI / 8.0)
	v.cyl(Vector3(0, BASE_H - 0.004, 0), 0.07, 0.07, 0.006, PANEL, 12)
	for s in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			v.cube(Vector3(s * 0.08, 0.002, z * 0.08), Vector3(0.03, 0.006, 0.03), Color("141317"))
	# Front panel (toward the camera, +x): buttons and the dial.
	v.box(Vector3(0.095, 0.03, -0.055), Vector3(0.105, 0.1, 0.055), PANEL)
	for i in 3:
		v.cyl(Vector3(0.104, 0.05, -0.03 + i * 0.03), 0.009, 0.009, 0.004, Color("55535c"), 8)
	v.pop()
	v.into(_base, "Base")
	# Heat lights along the top of the panel, each its own little mesh.
	for i in LED_COLORS.size():
		var led := MeshInstance3D.new()
		var c: Color = LED_COLORS[i]
		v.use("glow/blend")
		v.cube(Vector3.ZERO, Vector3(0.004, 0.008, 0.012), c)
		led.mesh = v.commit()
		led.position = AT + Vector3(0.106, 0.085, -0.045 + i * 0.018)
		_base.add_child(led)
		_leds.append(led)
	# Vents on the side, glowing when hot.
	for i in 4:
		v.box(Vector3(-0.004, -0.003, -0.03), Vector3(0.004, 0.003, 0.03), Color.WHITE)
		var vent := MeshInstance3D.new()
		vent.mesh = v.commit()
		vent.material_override = _vent_mat
		vent.position = AT + Vector3(0.05, 0.04 + i * 0.018, 0.098)
		vent.rotation_degrees.y = 60
		_base.add_child(vent)


func _build_jar(v: Vox) -> void:
	add_child(_jar)
	_jar.add_child(_jar_body)
	_jar_body.position = -SPOUT
	# Coupling collar, the glass jar with measuring ribs, handle, lid.
	v.cyl(Vector3.ZERO, 0.075, 0.07, 0.03, LID, 8, PI / 8.0)
	v.rod(Vector3(0, 0.2, -0.085), Vector3(0, 0.23, -0.14), 0.012, Color(0.85, 0.9, 0.95, 1))
	v.rod(Vector3(0, 0.23, -0.14), Vector3(0, 0.07, -0.13), 0.012, Color(0.85, 0.9, 0.95, 1))
	v.rod(Vector3(0, 0.07, -0.13), Vector3(0, 0.06, -0.075), 0.012, Color(0.85, 0.9, 0.95, 1))
	v.cyl(Vector3(0, JAR_H, 0), JAR_R.y + 0.01, JAR_R.y + 0.01, 0.03, LID, 12)
	v.cyl(Vector3(0, JAR_H + 0.03, 0), 0.03, 0.03, 0.02, LID.lightened(0.15), 10)
	v.into(_jar_body, "Collar")
	# The blades on the jar's floor.
	_blades.position = Vector3(0, 0.03, 0)
	_jar_body.add_child(_blades)
	for k in 2:
		v.push_at(Vector3.ZERO, Vector3(0, k * 90, 0))
		v.box(Vector3(-0.045, -0.002, -0.006), Vector3(0.045, 0.002, 0.006), METAL)
		v.pop()
	v.cyl(Vector3(0, -0.005, 0), 0.01, 0.01, 0.012, METAL.darkened(0.3), 8)
	v.into(_blades, "Blades")
	# The drink, and chunks of fruit tumbling round.
	v.push_at(Vector3(0, 0.02, 0))
	v.lathe([Vector2(0.0, 0.012), Vector2(JAR_R.x - 0.004, 0.012), Vector2(JAR_R.y - 0.006, JAR_H - 0.02)], 12, Color.WHITE, false)
	v.pop()
	_jar_liquid.mesh = v.commit()
	_jar_liquid.material_override = _jar_mat
	_jar_mat.render_priority = -1
	_jar_liquid.position = Vector3(0, 0.0, 0)
	_jar_body.add_child(_jar_liquid)
	for i in 10:
		var c := MeshInstance3D.new()
		v.cube(Vector3.ZERO, Vector3(0.018, 0.016, 0.018), Color.WHITE)
		c.mesh = v.commit()
		var m := StandardMaterial3D.new()
		m.albedo_color = _bits
		c.material_override = m
		c.rotation = Vector3(i * 0.9, i * 1.3, 0)
		_jar_liquid.add_child(c)
		_chunks.append(c)
	v.use("glass")
	v.push_at(Vector3(0, 0.02, 0))
	v.lathe([Vector2(JAR_R.x + 0.006, 0.0), Vector2(JAR_R.y + 0.006, JAR_H - 0.02)], 12, Color(0.85, 0.94, 1.0, 0.22), false, true)
	for k in 4:
		var y := 0.06 + k * 0.045
		var r := lerpf(JAR_R.x, JAR_R.y, y / JAR_H) + 0.008
		v.box(Vector3(r - 0.002, y, -0.02), Vector3(r + 0.001, y + 0.003, 0.02), Color(1, 1, 1, 0.5))
	v.pop()
	v.use("solid")
	var jm := v.into(_jar_body, "Jar")
	(jm.mesh.surface_get_material(0) as Material).render_priority = 1


func _build_tall(v: Vox) -> void:
	_tall.position = GLASS
	add_child(_tall)
	v.cyl(Vector3.ZERO, 0.07, 0.075, 0.012, Color("ebe6dc"), 14)
	v.into(_tall, "Coaster")
	v.push_at(Vector3(0, 0.012, 0))
	v.lathe([Vector2(0.0, 0.02), Vector2(TG_R.x - 0.005, 0.02), Vector2(TG_R.y - 0.006, TG_H - 0.01)], 14, Color.WHITE, false)
	v.pop()
	_tall_liquid.mesh = v.commit()
	_tall_liquid.material_override = _tall_mat
	_tall_mat.render_priority = -1
	_tall.add_child(_tall_liquid)
	# A striped straw.
	v.rod(Vector3.ZERO, Vector3(0.02, 0.3, 0.0), 0.006, Color("f4efe6"), 6)
	for k in 5:
		var p := Vector3(0.02, 0.3, 0.0) * (0.15 + k * 0.17)
		v.cyl(p, 0.0065, 0.0065, 0.018, Color("d8433a"), 6)
	v.into(_straw, "Straw")
	_tall.add_child(_straw)
	v.use("glass")
	v.push_at(Vector3(0, 0.012, 0))
	v.lathe([Vector2(TG_R.x, 0.0), Vector2(TG_R.y, TG_H)], 14, Color(0.86, 0.94, 1.0, 0.22), false, true)
	v.cyl(Vector3.ZERO, TG_R.x - 0.002, TG_R.x - 0.003, 0.02, Color(0.9, 0.96, 1.0, 0.4), 14)
	v.pop()
	v.use("solid")
	v.into(_tall, "Glass")
	_tall.visible = false

#endregion
