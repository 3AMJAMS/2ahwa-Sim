class_name StreetCat
extends Node2D
## The street's ginger-and-white cat, asleep on FIFI's roof: ginger back with
## darker tabby stripes, white chest, belly, paws and a blaze down the face,
## a ringed tail, pink nose, amber eyes. It breathes; now and then an ear
## twitches or the tail tip flicks; every so often it lifts its head, looks
## round, blinks (sometimes yawns) and settles back down. Drawn in its own
## local space, the body lying along +x (tail) to -x (head).
## Walking, jumping down and wandering the pavement come later (roadmap).

const GINGER := Color("d9822b")
const GINGER_LIGHT := Color("f0a24c")
const GINGER_DARK := Color("b0601c")
const WHITE := Color("f6f1e7")
const WHITE_SHADE := Color("d9d2c4")
const PINK := Color("e89a9a")
const EYE := Color("d9a030")
const OUTLINE := Color(0.3, 0.14, 0.05, 0.75)

var _t := 0.0
var _rng := RandomNumberGenerator.new()
## 0 asleep with the head down, 1 head up and looking round.
var _awake := 0.0
var _eyes_open := 0.0
var _look := 0.0
var _yawn := 0.0
var _ear := 0.0
var _flick := 0.0
var _next_ear := 3.0
var _next_flick := 5.0
var _next_wake := 14.0
var _busy := false


func _ready() -> void:
	_rng.randomize()
	_next_wake = _rng.randf_range(8.0, 16.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_next_ear -= delta
	_next_flick -= delta
	_next_wake -= delta
	if _next_ear <= 0.0:
		_next_ear = _rng.randf_range(3.0, 8.0)
		var t := create_tween()
		t.tween_property(self, "_ear", 1.0, 0.07)
		t.tween_property(self, "_ear", 0.0, 0.18)
		t.tween_property(self, "_ear", 0.7, 0.06)
		t.tween_property(self, "_ear", 0.0, 0.2)
	if _next_flick <= 0.0:
		_next_flick = _rng.randf_range(4.0, 10.0)
		var t := create_tween()
		t.tween_property(self, "_flick", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "_flick", -0.4, 0.3).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "_flick", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	if _next_wake <= 0.0 and not _busy:
		_wake_up()
	queue_redraw()


## Lift the head, open the eyes, look one way then the other, maybe yawn,
## then back to sleep.
func _wake_up() -> void:
	_busy = true
	var t := create_tween()
	t.tween_property(self, "_awake", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "_eyes_open", 1.0, 0.4).set_delay(0.3)
	t.tween_property(self, "_look", -1.0, 0.6).set_trans(Tween.TRANS_SINE).set_delay(0.4)
	t.tween_property(self, "_eyes_open", 0.0, 0.08).set_delay(0.5)
	t.tween_property(self, "_eyes_open", 1.0, 0.1)
	t.tween_property(self, "_look", 0.8, 0.9).set_trans(Tween.TRANS_SINE).set_delay(0.6)
	t.tween_property(self, "_look", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_delay(0.5)
	if _rng.randf() < 0.5:
		t.tween_property(self, "_eyes_open", 0.2, 0.2)
		t.parallel().tween_property(self, "_yawn", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "_yawn", 0.0, 0.5).set_delay(0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_eyes_open", 0.0, 0.5).set_delay(0.6)
	t.tween_property(self, "_awake", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void:
		_busy = false
		_next_wake = _rng.randf_range(16.0, 30.0))


func _draw() -> void:
	var breath := sin(_t * TAU / 3.2)
	# Soft shadow on the roof.
	_ellipse(Vector2(4, 16), Vector2(44, 9), Color(0, 0, 0, 0.28))
	_draw_tail(breath)
	_draw_body(breath)
	_draw_head()


func _draw_tail(breath: float) -> void:
	# The tail curls from the haunch round the front of the body toward the
	# chin; its tip lifts and flicks. Rings of lighter fur along it.
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := i / float(n)
		var a := lerpf(-0.3, PI * 0.92, t)
		var r := lerpf(34.0, 30.0, t)
		var p := Vector2(6 + cos(a) * r, 4 + sin(a) * r * 0.42)
		if t > 0.7:
			var k := (t - 0.7) / 0.3
			p += Vector2(0, -k * k * (6.0 + 8.0 * _flick)) + Vector2(k * 4.0 * _flick, 0)
		pts.append(p)
	for i in n:
		var w := lerpf(8.0, 6.0, i / float(n))
		var col := GINGER if i % 2 == 0 else GINGER_LIGHT
		draw_line(pts[i], pts[i + 1], col, w, true)
		draw_circle(pts[i + 1], w * 0.5, col)
	draw_circle(pts[n], 3.4, GINGER_DARK)


func _draw_body(breath: float) -> void:
	var ry := 17.0 * (1.0 + 0.035 * breath)
	var c := Vector2(8, -2 - 0.6 * breath)
	# A thin dark rim so the cat reads against FIFI's paint.
	_ellipse(c + Vector2(16, 4), Vector2(21.5, ry * 0.95 + 1.5), OUTLINE)
	_ellipse(c, Vector2(34.5, ry + 1.5), OUTLINE)
	# Haunch at the back, the long loaf of the body, white underneath.
	_ellipse(c + Vector2(16, 4), Vector2(20, ry * 0.95), GINGER)
	_ellipse(c, Vector2(33, ry), GINGER)
	_ellipse(c + Vector2(-4, -ry * 0.45), Vector2(26, ry * 0.45), GINGER_LIGHT)
	# Soft tabby stripes curving down the flank, following the body.
	for k in 5:
		var u := -0.55 + k * 0.27
		var arc := PackedVector2Array()
		for i in 8:
			var t := i / 7.0
			var a := lerpf(-PI * 0.5 - 0.35, -PI * 0.5 + 0.9, t)
			arc.append(c + Vector2(u * 33.0 + cos(a) * 6.0 + t * 2.0, sin(a) * ry * 0.95 * (1.0 - 0.25 * absf(u))))
		draw_polyline(arc, Color(GINGER_DARK, 0.45), 2.0 + 0.8 * (1.0 - absf(u)), true)
	# White belly and back leg, as in the photos.
	_ellipse(c + Vector2(20, 10), Vector2(13, 6), WHITE)
	_ellipse(c + Vector2(-4, 12), Vector2(22, 5.5), WHITE_SHADE)
	# White chest and the tucked front paws.
	_ellipse(c + Vector2(-24, 6), Vector2(13, 11), WHITE)
	_ellipse(c + Vector2(-33, 13), Vector2(6, 3.5), WHITE)
	_ellipse(c + Vector2(-25, 14), Vector2(6, 3.5), WHITE)
	draw_line(c + Vector2(-35, 13), c + Vector2(-31, 13), WHITE_SHADE, 1.0)


func _draw_head() -> void:
	var lift := _awake
	var c := Vector2(-34 + 3 * _look, 0 - 10 * lift)
	var tilt := 0.12 * _look - 0.15 * (1.0 - lift)
	draw_set_transform(c, tilt)
	# Ears first: ginger with pink insides, the near one twitching.
	for side in [-1.0, 1.0]:
		var twitch := (_ear * 0.35) if side > 0 else 0.0
		var base_a := Vector2(side * 4.0, -9)
		var tip := Vector2(side * 11.0, -21).rotated(twitch * side)
		var base_b := Vector2(side * 12.0, -5)
		draw_colored_polygon(PackedVector2Array([base_a, tip, base_b]), GINGER)
		draw_colored_polygon(PackedVector2Array([base_a.lerp(base_b, 0.25), tip.lerp(Vector2(side * 8, -8), 0.25),
			base_a.lerp(base_b, 0.75)]), PINK)
	# Head: ginger, slightly wider than tall, white blaze and muzzle.
	_ellipse(Vector2.ZERO, Vector2(15.5, 13.5), OUTLINE)
	_ellipse(Vector2.ZERO, Vector2(14, 12), GINGER)
	_ellipse(Vector2(0, -5), Vector2(10, 5), GINGER_LIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -11), Vector2(2, -11), Vector2(5, 2), Vector2(-5, 2)]), WHITE)
	_ellipse(Vector2(0, 5), Vector2(9, 6.5), WHITE)
	for k in 3:
		draw_line(Vector2(-6 + k * 2, -10), Vector2(-5 + k * 1.5, -6), Color(GINGER_DARK, 0.7), 1.2)
	# Eyes: closed crescents asleep, amber with slit pupils awake.
	for side in [-1.0, 1.0]:
		var e := Vector2(side * 6.0, -1)
		if _eyes_open > 0.1:
			var h := 3.2 * _eyes_open
			_ellipse(e, Vector2(3.4, h), EYE)
			_ellipse(e + Vector2(0.3 * _look, 0), Vector2(0.9, h * 0.9), Color("1a1208"))
			draw_circle(e + Vector2(-1, -1), 0.8, Color(1, 1, 1, 0.8))
		else:
			draw_arc(e + Vector2(0, -1.5), 3.2, 0.25, PI - 0.25, 6, Color("5a3014"), 1.4, true)
	# Nose, mouth (open when it yawns), whiskers.
	draw_colored_polygon(PackedVector2Array([Vector2(-2, 3), Vector2(2, 3), Vector2(0, 5)]), PINK)
	if _yawn > 0.05:
		_ellipse(Vector2(0, 8 + 1.5 * _yawn), Vector2(3.0, 4.0 * _yawn), Color("b0485a"))
	else:
		draw_line(Vector2(0, 5), Vector2(-2, 7), Color("8a5040"), 1.0)
		draw_line(Vector2(0, 5), Vector2(2, 7), Color("8a5040"), 1.0)
	for side in [-1.0, 1.0]:
		for k in 3:
			draw_line(Vector2(side * 5.0, 6), Vector2(side * 17.0, 3.0 + k * 3.0), Color(1, 1, 1, 0.6), 0.7, true)
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
