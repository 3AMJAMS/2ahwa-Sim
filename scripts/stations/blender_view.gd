class_name BlenderView
extends StationArt
## Cold-station art: a cheap plastic blender on the counter and a tall glass
## beside it. Purely visual — BlendGauge feeds it progress/motor_heat/running/
## holding/tripped and calls pour()/trip(); scoring never reads it.
## set_look() recolours it per drink from the menu item's "look" block.

const BASE_X := 610.0
const BASE_TOP := 468.0
## Jar local space: origin at the bottom of the glass, -y is up.
const JAR_REST := Vector2(BASE_X, 452)
const JAR_H := 262.0
const JAR_FLOOR := -16.0
## Half-widths at the bottom and top: inside, and the outer glass.
const JAR_IN := Vector2(60, 92)
const JAR_OUT := Vector2(66, 98)
## Pour lip; the pour pivots around it so the stream stays put.
const SPOUT := Vector2(-106, -262)
const REST_PIVOT := JAR_REST + SPOUT
const LIFT_PIVOT := REST_PIVOT + Vector2(0, -70)
const POUR_PIVOT := Vector2(318, 336)
const POUR_TILT := -1.0
const POUR_TILT_END := -1.4
const START_LEVEL := 0.58

const GLASS_BASE := Vector2(250, 600)
const GLASS_H := 210.0
const GLASS_HW := Vector2(40, 52)
const GLASS_FOOT := 12.0
const GLASS_FULL := 0.86

const COLOR_BODY := Color("e8e0cc")
const COLOR_BODY_DARK := Color("b5ab94")
const COLOR_CHROME := Color("d9dde3")
const COLOR_PANEL := Color("2b2a30")
const COLOR_LID := Color("2f2d34")
const COLOR_METAL := Color("b3b9c2")
const COLOR_GLASS := Color(0.8, 0.92, 1.0)
const COLOR_ICE := Color(0.88, 0.95, 1.0, 0.85)
const COLOR_SMOKE := Color(0.16, 0.14, 0.15, 0.5)
const COLOR_SPARK := Color("ffd76a")
const COLOR_VENT := Color("3a342c")
const COLOR_VENT_HOT := Color("ff6a2a")
const COLOR_STRAW := Color("f4efe6")
const COLOR_STRAW_STRIPE := Color("d8433a")
## Motor heat lights, cool to hot.
const LED_COLORS := [Color("4caf50"), Color("4caf50"), Color("e6c33a"), Color("e6c33a"), Color("f08a2c"), Color("e0452b")]
const RED_ZONE := 80.0

## Fed by BlendGauge every frame.
var progress := 0.0
var motor_heat := 0.0
var running := false
var holding := false

var jar_pivot := REST_PIVOT
var jar_tilt := 0.0
## Fraction of the jar that is full, 0..1.
var jar_level := START_LEVEL
var stream := 0.0
var glass_fill := 0.0
var ice_in := 0.0
var straw := 0.0
## Thermal cut-out has tripped: the motor is off until it cools.
var tripped := false

var _liquid := Color("a3183a")
var _bits := Color("5c0d22")
var _ice := true
var _speed := 0.0
var _spin := 0.0
## Fruit/ice chunks: (angle, radius 0..1, height 0..1, size), plus is-ice flags.
var _chunks: Array[Vector4] = []
var _chunk_ice: Array[bool] = []
var _puffs := []
var _drops := []
var _sparks := []
var _smoke_acc := 0.0
var _drop_acc := 0.0
var _spark_acc := 0.0


func _ready() -> void:
	super()
	reset()


## Recolours the drink: {"liquid", "bits", "ice": bool}.
func set_look(look: Dictionary) -> void:
	_liquid = Color(look.get("liquid", "#a3183a"))
	_bits = Color(look.get("bits", look.get("liquid", "#5c0d22")))
	_ice = bool(look.get("ice", false))
	_make_chunks()
	queue_redraw()


func reset() -> void:
	_kill_tween()
	_finish_sequence()
	progress = 0.0
	motor_heat = 0.0
	running = false
	holding = false
	jar_pivot = REST_PIVOT
	jar_tilt = 0.0
	jar_level = START_LEVEL
	stream = 0.0
	glass_fill = 0.0
	ice_in = 0.0
	straw = 0.0
	tripped = false
	_speed = 0.0
	_puffs.clear()
	_drops.clear()
	_sparks.clear()
	_make_chunks()
	queue_redraw()


## Lifts the jar off the base and pours it into the glass. Returns once the
## glass is dressed; the jar then goes back on the base by itself.
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
	if _ice:
		t.tween_property(self, "ice_in", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "straw", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_finish_sequence)
	t.tween_property(self, "jar_pivot", LIFT_PIVOT, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "jar_tilt", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "jar_pivot", REST_PIVOT, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await sequence_finished


## The thermal cut-out trips: a crack of sparks and a puff of smoke.
func trip() -> void:
	for i in 14:
		_spawn_spark()
	for i in 10:
		_puffs.append(_particle(_vents() + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-30, 30)),
			Vector2(_rng.randf_range(-70, -20), _rng.randf_range(-110, -60)),
			_rng.randf_range(1.2, 2.0), _rng.randf_range(12, 20), COLOR_SMOKE))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var target := 0.0
	if running:
		target = 2.5 if holding else 1.0
	_speed = lerpf(_speed, target, minf(1.0, delta * 6.0))
	_spin += delta * _speed * 7.0
	_emit_particles(delta)
	_step_particles(delta)
	queue_redraw()


func _make_chunks() -> void:
	_chunks.clear()
	_chunk_ice.clear()
	for i in 16:
		_chunks.append(Vector4(_rng.randf() * TAU, _rng.randf_range(0.15, 0.9),
			_rng.randf_range(0.05, 0.85), _rng.randf_range(13, 22)))
		_chunk_ice.append(_ice and i % 3 == 0)


func _blend() -> float:
	return clampf(progress / 100.0, 0.0, 1.0)


func _jar_color() -> Color:
	var k := smoothstep(0.05, 0.9, _blend())
	var raw := Color(_liquid.lerp(Color(0.92, 0.95, 1.0), 0.6), 0.5)
	return raw.lerp(Color(_liquid, 0.93), k)


#region Particles

func _vents() -> Vector2:
	return Vector2(BASE_X - 94, 528)


func _spawn_spark() -> void:
	var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
	_sparks.append(_particle(_vents() + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-24, 24)),
		Vector2(cos(a), sin(a)) * _rng.randf_range(220, 520), _rng.randf_range(0.15, 0.35), 3.0, COLOR_SPARK))


func _emit_particles(delta: float) -> void:
	var hot := clampf((motor_heat - 65.0) / 35.0, 0.0, 1.0)
	var smoke := hot if running or tripped else hot * 0.4
	if smoke > 0.0 and _puffs.size() < 120:
		_smoke_acc += delta * 14.0 * smoke
		while _smoke_acc >= 1.0:
			_smoke_acc -= 1.0
			_puffs.append(_particle(_vents() + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-26, 26)),
				Vector2(_rng.randf_range(-40, -10), _rng.randf_range(-90, -50)),
				_rng.randf_range(1.2, 2.0), _rng.randf_range(10, 18), COLOR_SMOKE))
	if running and motor_heat >= RED_ZONE:
		_spark_acc += delta * 10.0
		while _spark_acc >= 1.0:
			_spark_acc -= 1.0
			_spawn_spark()
	if stream > 0.3:
		_drop_acc += delta * 40.0
		while _drop_acc >= 1.0:
			_drop_acc -= 1.0
			_drops.append(_particle(_stream_end(), Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-160, -60)),
				_rng.randf_range(0.2, 0.35), _rng.randf_range(2.5, 4.0), _liquid))


func _step_particles(delta: float) -> void:
	for p in _puffs:
		p.age += delta
		p.vel.x += sin(_t * 1.7 + p.size) * 10.0 * delta
		p.vel *= 1.0 - 0.3 * delta
		p.pos += p.vel * delta
	for p in _drops + _sparks:
		p.age += delta
		p.vel.y += 900.0 * delta
		p.pos += p.vel * delta
	_puffs = _puffs.filter(func(p): return p.age < p.life)
	_drops = _drops.filter(func(p): return p.age < p.life)
	_sparks = _sparks.filter(func(p): return p.age < p.life)

#endregion


#region Drawing

func _draw() -> void:
	if _scene_scale() <= 0.0:
		return
	var scene_xf := _scene_xf()
	var span := _scene_span()
	draw_set_transform_matrix(scene_xf)
	_soft_blob(Vector2(BASE_X - 60, 360), Vector2(520, 380), Color(0.5, 0.8, 1.0, 0.07))
	_draw_counter(span.x, span.y)
	_fill_ellipse(Vector2(BASE_X, COUNTER_Y + 2), Vector2(128, 10), Color(0, 0, 0, 0.3))
	_draw_base()
	_draw_jar(scene_xf)
	draw_set_transform_matrix(scene_xf)
	_draw_glass_back()
	if stream > 0.01:
		_draw_stream(jar_pivot + Vector2(-2, 3), _stream_end(), stream, _liquid, 7.0)
	_draw_glass_front()
	for p in _drops:
		draw_circle(p.pos, p.size * (1.0 - 0.4 * p.age / p.life), p.color)
	for p in _sparks:
		var k: float = 1.0 - p.age / p.life
		draw_line(p.pos, p.pos - p.vel * 0.03, Color(p.color, k), 3.0, true)
	for p in _puffs:
		var k: float = p.age / p.life
		_soft_blob(p.pos, Vector2.ONE * p.size * (1.6 + 2.4 * k), Color(p.color, p.color.a * 1.6 * sin(PI * k)))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _shake() -> Vector2:
	var amp := 0.9 * _speed
	if running and motor_heat >= RED_ZONE:
		amp += 1.6
	return Vector2(sin(_t * 57.0), sin(_t * 43.0 + 1.1)) * amp


func _draw_base() -> void:
	var j := _shake() * 0.5
	var cx := BASE_X + j.x
	var foot := COUNTER_Y - 2.0
	var top := BASE_TOP + j.y
	draw_rect(Rect2(cx - 100, foot - 8, 200, 8), COLOR_PANEL)
	var body := PackedVector2Array([Vector2(cx - 116, foot - 6), Vector2(cx + 116, foot - 6),
		Vector2(cx + 96, top + 14), Vector2(cx + 86, top), Vector2(cx - 86, top), Vector2(cx - 96, top + 14)])
	draw_colored_polygon(body, COLOR_BODY)
	_clip_fill(body, [Vector2(cx - 130, foot - 30), Vector2(cx + 130, foot - 30), Vector2(cx + 130, foot), Vector2(cx - 130, foot)],
		COLOR_BODY_DARK)
	_clip_fill(body, [Vector2(cx + 50, top), Vector2(cx + 130, top), Vector2(cx + 130, foot), Vector2(cx + 60, foot)],
		Color(0, 0, 0, 0.14))
	_clip_fill(body, [Vector2(cx - 80, top), Vector2(cx - 68, top), Vector2(cx - 84, foot), Vector2(cx - 96, foot)],
		Color(1, 1, 1, 0.35))
	draw_rect(Rect2(cx - 86, top, 172, 8), COLOR_CHROME)
	# Drive socket, seen when the jar is lifted off.
	_fill_ellipse(Vector2(cx, top + 1), Vector2(60, 6), COLOR_PANEL)
	# Front panel: heat lights over three buttons (off, on, turbo).
	draw_rect(Rect2(cx - 72, 498, 144, 70), COLOR_PANEL)
	var lit := motor_heat / 100.0 * LED_COLORS.size()
	var blink := 0.5 + 0.5 * signf(sin(_t * 18.0)) if motor_heat >= RED_ZONE or tripped else 1.0
	for i in LED_COLORS.size():
		var r := Rect2(cx - 62 + i * 21, 508, 16, 9)
		if lit > i:
			var c: Color = LED_COLORS[i]
			draw_rect(r, hdr(Color(c, blink if i >= 4 or tripped else 1.0), 1.8))
			_soft_blob(r.get_center(), Vector2(16, 12), Color(c, 0.35 * blink))
		else:
			draw_rect(r, Color(1, 1, 1, 0.08))
	var buttons := [Color("55535c"), hdr(Color("7be08a"), 1.6) if running else Color("55535c"),
		hdr(Color("ffb347"), 1.8) if running and holding else Color("55535c")]
	for i in 3:
		var at := Vector2(cx - 40 + i * 40, 546)
		draw_circle(at, 12, buttons[i])
		draw_circle(at + Vector2(-3, -3), 4, Color(1, 1, 1, 0.25))
	# Vents glow as the motor heats.
	var glow := smoothstep(50.0, 100.0, motor_heat)
	var vent := COLOR_VENT.lerp(COLOR_VENT_HOT, glow)
	for i in 5:
		var y := top + 34.0 + i * 12.0
		draw_line(Vector2(cx - 104 + i * 1.5, y), Vector2(cx - 84 + i * 1.5, y), vent, 4.0)
	if glow > 0.0:
		_soft_blob(Vector2(cx - 94, top + 58), Vector2(46, 46), Color(COLOR_VENT_HOT, 0.45 * glow))


func _jar_xf() -> Transform2D:
	var j := _shake() if jar_pivot == REST_PIVOT else Vector2.ZERO
	return Transform2D(jar_tilt, jar_pivot + j) * Transform2D(0.0, -SPOUT)


func _draw_jar(scene_xf: Transform2D) -> void:
	var xf := _jar_xf()
	draw_set_transform_matrix(scene_xf * xf)
	# Coupling collar, handle, then the back of the glass.
	draw_colored_polygon(PackedVector2Array([Vector2(-82, 16), Vector2(82, 16), Vector2(76, 0), Vector2(-76, 0)]), COLOR_LID)
	draw_line(Vector2(-78, 3), Vector2(78, 3), Color(1, 1, 1, 0.15), 2.0)
	draw_polyline(PackedVector2Array([Vector2(90, -226), Vector2(138, -214), Vector2(148, -130),
		Vector2(132, -74), Vector2(76, -64)]), Color(0.85, 0.9, 0.95, 0.5), 14.0, true)
	var outer := PackedVector2Array([Vector2(-JAR_OUT.x, 0), Vector2(JAR_OUT.x, 0),
		Vector2(JAR_OUT.y, -JAR_H), Vector2(-JAR_OUT.y, -JAR_H)])
	draw_colored_polygon(outer, Color(COLOR_GLASS, 0.1))
	_arc(Vector2(0, -JAR_H), Vector2(JAR_OUT.y, 12), PI, TAU, Color(1, 1, 1, 0.3), 2.0)
	_draw_blades()

	# Liquid is solved in scene space so its surface stays level as the jar tilts.
	draw_set_transform_matrix(scene_xf)
	var upright := absf(jar_tilt) < 0.05
	var level_y := _draw_liquid(xf, upright)

	draw_set_transform_matrix(scene_xf * xf)
	if upright:
		var level_local := (xf.affine_inverse() * Vector2(xf.origin.x, level_y)).y
		_draw_swirls(level_local)
		_draw_chunks(level_local)
	# Front of the glass: edges, highlight, measuring ticks, lip.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * JAR_OUT.x, 0), Vector2(side * JAR_OUT.y, -JAR_H), Color(1, 1, 1, 0.45), 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-56, -20), Vector2(-46, -20), Vector2(-78, -240), Vector2(-88, -240)]),
		Color(1, 1, 1, 0.16))
	for k in 4:
		var y := -60.0 - k * 48.0
		var x := _jar_hw(y, JAR_OUT) - 4.0
		draw_line(Vector2(x, y), Vector2(x - 16, y), Color(1, 1, 1, 0.4), 2.0)
	_arc(Vector2(0, -JAR_H), Vector2(JAR_OUT.y, 12), 0.0, PI, Color(1, 1, 1, 0.6), 2.5)
	_draw_lid()


func _draw_blades() -> void:
	var y := JAR_FLOOR - 8.0
	if _speed > 0.6:
		_fill_ellipse(Vector2(0, y), Vector2(44, 7), Color(COLOR_METAL, 0.35 * minf(1.0, _speed)))
	for k in 2:
		var a := _spin * 2.0 + k * PI * 0.5
		var tip := Vector2(cos(a) * 42.0, sin(a) * 6.0)
		draw_line(Vector2(0, y) - tip, Vector2(0, y) + tip, COLOR_METAL, 6.0, true)
	draw_circle(Vector2(0, y), 7, COLOR_METAL.darkened(0.3))


## Fills the jar to jar_level and returns the surface height (scene y).
func _draw_liquid(xf: Transform2D, upright: bool) -> float:
	var interior := xf * PackedVector2Array([Vector2(-JAR_IN.x, JAR_FLOOR), Vector2(JAR_IN.x, JAR_FLOOR),
		Vector2(JAR_IN.y, -JAR_H + 4.0), Vector2(-JAR_IN.y, -JAR_H + 4.0)])
	var cx := (xf * Vector2(0, -JAR_H * 0.5)).x
	var dip := 30.0 * clampf(_speed / 2.5, 0.0, 1.0) if upright else 0.0
	var target := jar_level * _area(interior)
	var lo := INF
	var hi := -INF
	for p in interior:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	for i in 14:
		var mid := (lo + hi) * 0.5
		if _clipped_area(interior, _below(mid, cx, dip)) > target:
			lo = mid
		else:
			hi = mid
	var level_y := (lo + hi) * 0.5
	var col := _jar_color()
	var froth := Color(_liquid.lightened(0.4), 0.3 + 0.6 * _blend())
	for piece in Geometry2D.intersect_polygons(interior, _below(level_y, cx, dip)):
		draw_colored_polygon(piece, col)
		var top: Array[Vector2] = []
		for p in piece:
			if absf(p.y - _surface(p.x, level_y, cx, dip)) < 0.6:
				top.append(p)
		if top.size() >= 2:
			top.sort_custom(func(a, b): return a.x < b.x)
			draw_polyline(PackedVector2Array(top), froth, 6.0, true)
	return level_y


func _surface(x: float, y: float, cx: float, dip: float) -> float:
	return y + dip * exp(-pow((x - cx) / 38.0, 2))


## Region under a (possibly vortexed) liquid surface at height y.
func _below(y: float, cx: float, dip: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(cx - 400, 4000), Vector2(cx - 400, y)])
	for i in 25:
		var x := cx - 160.0 + i * 320.0 / 24.0
		pts.append(Vector2(x, _surface(x, y, cx, dip)))
	pts.append(Vector2(cx + 400, y))
	pts.append(Vector2(cx + 400, 4000))
	return pts


func _clipped_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var total := 0.0
	for piece in Geometry2D.intersect_polygons(a, b):
		total += _area(piece)
	return total


func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5


func _jar_hw(y: float, hw: Vector2) -> float:
	return lerpf(hw.x, hw.y, clampf(-y / JAR_H, 0.0, 1.0))


## Curved streaks circling the vortex while it spins.
func _draw_swirls(level: float) -> void:
	var a := clampf(_speed, 0.0, 1.0) * 0.3
	if a <= 0.01:
		return
	for i in 5:
		var y := level + 26.0 + i * 30.0
		if y > JAR_FLOOR - 12.0:
			break
		var r := Vector2(_jar_hw(y, JAR_IN) * 0.72, 7.0)
		var phase := fmod(_spin * (1.3 - i * 0.12) + i * 1.7, TAU)
		_arc(Vector2(0, y), r, phase * 0.5, phase * 0.5 + 1.3, Color(1, 1, 1, a), 2.5)


## Fruit (or hibiscus, or ice) whirling round and shrinking as it's blended.
func _draw_chunks(level: float) -> void:
	var shrink := pow(1.0 - _blend(), 0.8)
	if shrink < 0.06:
		return
	var depth := JAR_FLOOR - level
	for i in _chunks.size():
		var c := _chunks[i]
		var ang := c.x + _spin * (0.6 + 0.5 * (1.0 - c.y))
		var y := JAR_FLOOR - 12.0 - c.z * maxf(depth - 24.0, 0.0) + sin(ang) * 6.0 \
			+ sin(_spin * 0.5 + c.x * 3.0) * 8.0 * minf(_speed, 1.0)
		var x := cos(ang) * c.y * (_jar_hw(y, JAR_IN) - 12.0)
		var sz := c.w * shrink * (0.9 + 0.1 * sin(ang))
		var front := 1.0 if sin(ang) > 0.0 else 0.6
		var rot := c.x * 5.0 + _spin * 0.8
		var half := sz * 0.5
		var quad := PackedVector2Array()
		for k in 4:
			var a := rot + k * PI * 0.5
			quad.append(Vector2(x, y) + Vector2(cos(a), sin(a)) * half * 1.3)
		if _chunk_ice[i]:
			draw_colored_polygon(quad, Color(COLOR_ICE, COLOR_ICE.a * front))
			draw_polyline(quad + PackedVector2Array([quad[0]]), Color(1, 1, 1, 0.7 * front), 1.5)
		else:
			draw_colored_polygon(quad, Color(_bits, front))
			draw_circle(Vector2(x, y) + Vector2(-half, -half) * 0.35, half * 0.3, Color(1, 1, 1, 0.25 * front))


func _draw_lid() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-102, -JAR_H + 2), Vector2(102, -JAR_H + 2),
		Vector2(100, -276), Vector2(-100, -276)]), COLOR_LID)
	draw_colored_polygon(PackedVector2Array([Vector2(-28, -276), Vector2(28, -276),
		Vector2(24, -292), Vector2(-24, -292)]), COLOR_LID)
	draw_line(Vector2(-98, -274), Vector2(98, -274), Color(1, 1, 1, 0.12), 2.0)


func _draw_glass_back() -> void:
	var b := GLASS_BASE
	_fill_ellipse(b + Vector2(0, 4), Vector2(66, 9), Color(0, 0, 0, 0.3))
	draw_colored_polygon(_glass_poly(b.y, b.y - GLASS_H, 0.0), Color(0.8, 0.9, 1.0, 0.1))
	_arc(Vector2(b.x, b.y - GLASS_H), Vector2(GLASS_HW.y, 8), PI, TAU, Color(1, 1, 1, 0.3), 2.0)
	if straw > 0.0:
		_draw_straw()
	if glass_fill <= 0.001:
		return
	var floor_y := b.y - GLASS_FOOT
	var top_y := _glass_surface_y()
	var hw := _glass_hw(top_y) - 4.0
	draw_colored_polygon(_glass_poly(floor_y, top_y, 4.0), Color(_liquid, 0.93))
	_fill_ellipse(Vector2(b.x, top_y), Vector2(hw, 6), Color(_liquid.lightened(0.25), 0.95))
	if ice_in > 0.0:
		for i in 3:
			var at := Vector2(b.x - 22 + i * 20, top_y - 4 + sin(_t * 2.0 + i) * 1.5 - 120.0 * (1.0 - ice_in))
			var quad := PackedVector2Array()
			for k in 4:
				var a := i * 0.6 + k * PI * 0.5
				quad.append(at + Vector2(cos(a), sin(a)) * 12.0)
			draw_colored_polygon(quad, Color(COLOR_ICE, ice_in))
			draw_polyline(quad + PackedVector2Array([quad[0]]), Color(1, 1, 1, 0.8 * ice_in), 1.5)


func _draw_straw() -> void:
	var b := GLASS_BASE
	var drop := Vector2(0, -80.0 * (1.0 - straw))
	var p0 := Vector2(b.x + 8, b.y - 40) + drop
	var p1 := Vector2(b.x + 42, b.y - GLASS_H - 76) + drop
	draw_line(p0, p1, Color(COLOR_STRAW, straw), 9.0, true)
	for k in 7:
		var t0 := k / 7.0 + 0.02
		draw_line(p0.lerp(p1, t0), p0.lerp(p1, t0 + 0.05), Color(COLOR_STRAW_STRIPE, straw), 9.0)


func _draw_glass_front() -> void:
	var b := GLASS_BASE
	var top := b.y - GLASS_H
	draw_colored_polygon(_glass_poly(b.y, b.y - GLASS_FOOT, 0.0), Color(0.85, 0.95, 1.0, 0.18))
	for side in [-1.0, 1.0]:
		draw_line(Vector2(b.x + side * GLASS_HW.x, b.y), Vector2(b.x + side * GLASS_HW.y, top),
			Color(1, 1, 1, 0.5), 3.0, true)
	_arc(b, Vector2(GLASS_HW.x, 5), 0.0, PI, Color(1, 1, 1, 0.35), 2.0)
	_arc(Vector2(b.x, top), Vector2(GLASS_HW.y, 8), 0.0, PI, Color(1, 1, 1, 0.55), 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(b.x - 32, b.y - 16), Vector2(b.x - 24, b.y - 16),
		Vector2(b.x - 36, top + 14), Vector2(b.x - 44, top + 14)]), Color(1, 1, 1, 0.2))
	# Condensation beads on the cold part of the glass.
	var cold := glass_fill / GLASS_FULL
	if cold > 0.05:
		var surf := _glass_surface_y()
		for i in 16:
			var y := b.y - GLASS_FOOT - 8.0 - float((i * 47) % 170)
			if y < surf + 6.0:
				continue
			var x := b.x + (float((i * 29) % 100) / 100.0 - 0.5) * 2.0 * (_glass_hw(y) - 8.0)
			draw_circle(Vector2(x, y), 2.6, Color(1, 1, 1, 0.3 * cold))
			draw_circle(Vector2(x - 0.8, y - 0.8), 1.0, Color(1, 1, 1, 0.6 * cold))

#endregion


#region Geometry

func _glass_hw(y: float) -> float:
	return lerpf(GLASS_HW.x, GLASS_HW.y, (GLASS_BASE.y - y) / GLASS_H)


func _glass_poly(y_bottom: float, y_top: float, inset: float) -> PackedVector2Array:
	var x := GLASS_BASE.x
	var hb := _glass_hw(y_bottom) - inset
	var ht := _glass_hw(y_top) - inset
	return PackedVector2Array([Vector2(x - hb, y_bottom), Vector2(x + hb, y_bottom),
		Vector2(x + ht, y_top), Vector2(x - ht, y_top)])


func _glass_surface_y() -> float:
	return GLASS_BASE.y - GLASS_FOOT - glass_fill * (GLASS_H - GLASS_FOOT - 8.0)


func _stream_end() -> Vector2:
	return Vector2(GLASS_BASE.x + 8.0, _glass_surface_y())

#endregion
