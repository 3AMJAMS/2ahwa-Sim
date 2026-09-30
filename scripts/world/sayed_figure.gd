class_name SayedFigure
extends Node2D
## Sayed in his lawn chair between orders: checked shirt, the قهوجي's towel
## over his shoulder, moustache and stubble (FigureArt's "sayed" look),
## sitting with his legs out toward the trunk. He breathes, and every so
## often lifts his glass of tea for a sip. The origin is the middle of the
## seat; the body is baked once into a mesh, only the tea arm redraws while
## it moves.

const SKIN := Color("b97a52")
const HAIR := Color("1d1612")
const SHIRT := Color("2f5f8a")
const TROUSERS := Color("3a3a40")
const TEA := Color("a8461c")
## How far the seated body sits below a standing figure's hips.
const SIT_DROP := 58.0

var _mesh: ArrayMesh
var _t := 0.0
var _sip := 0.0
var _next_sip := 5.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _look() -> Dictionary:
	return {"kind": "sayed", "skin": SKIN, "hair": HAIR, "cloth": SHIRT, "trousers": TROUSERS,
		"moustache": true, "style": 0, "mood": 0.4}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	# Breathing: the chest rises and falls a touch.
	scale.y = 1.0 + 0.012 * sin(_t * TAU / 3.6)
	_next_sip -= delta
	if _next_sip <= 0.0:
		_next_sip = _rng.randf_range(7.0, 14.0)
		var t := create_tween()
		t.tween_property(self, "_sip", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_interval(0.8)
		t.tween_property(self, "_sip", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _sip > 0.0 or _next_sip > 13.5:
		queue_redraw()


func _draw() -> void:
	if _mesh == null:
		_mesh = _build()
	_draw_tea_arm(true)
	if _mesh:
		draw_mesh(_mesh, null)
	_draw_tea_arm(false)


## Seated: the standing figure's body lowered onto the seat, thighs out
## toward the trunk (screen right and down), shins down to the pavement,
## the near arm resting along the thigh.
func _build() -> ArrayMesh:
	var m := MeshCanvas.new()
	var look := _look()
	# Legs first (the far one darker), then the body over them.
	for k in 2:
		var off := Vector2(8, -4) if k == 0 else Vector2(-4, 3)
		var col := TROUSERS.darkened(0.15 if k == 0 else 0.0)
		var hip := Vector2(4, 2) + off
		var knee := hip + Vector2(34, 14)
		var foot := knee + Vector2(4, 36)
		m.colored_polygon(PackedVector2Array([hip + Vector2(-2, -9), knee + Vector2(2, -8), knee + Vector2(4, 7), hip + Vector2(-2, 9)]), col)
		m.colored_polygon(PackedVector2Array([knee + Vector2(-5, 0), knee + Vector2(6, -2), foot + Vector2(4, 0), foot + Vector2(-4, 0)]),
			col)
		m.colored_polygon(PackedVector2Array([foot + Vector2(-6, -2), foot + Vector2(8, -2), foot + Vector2(13, 2), foot + Vector2(13, 5),
			foot + Vector2(-6, 5)]), Color("5a3a28"))
	m.set_transform(Vector2(0, SIT_DROP))
	FigureArt.build_body(m, look)
	m.set_transform(Vector2.ZERO)
	# Near (left) arm resting along the thigh, hand on the knee.
	var shoulder := Vector2(-20, FigureArt.SHOULDER_Y + SIT_DROP)
	var elbow := shoulder + Vector2(4, 28)
	var hand := elbow + Vector2(28, 8)
	m.colored_polygon(PackedVector2Array([shoulder + Vector2(-7, 0), shoulder + Vector2(7, 0), elbow + Vector2(5, 0), elbow + Vector2(-5, 0)]),
		SHIRT.darkened(0.05))
	m.colored_polygon(PackedVector2Array([elbow + Vector2(0, -5), elbow + Vector2(0, 5), hand + Vector2(0, 4), hand + Vector2(0, -4)]),
		SHIRT.darkened(0.05))
	m.rect(Rect2(hand.x - 3, hand.y - 5, 4, 10), SHIRT.lightened(0.1))
	m.circle(hand + Vector2(5, 0), 6.0, SKIN, 10)
	return m.commit()


## The far arm with the tea glass: at rest on his lap, lifted to his mouth
## for a sip. Drawn in two passes: the arm behind the body, the glass and
## hand in front once it's raised.
func _draw_tea_arm(behind: bool) -> void:
	var shoulder := Vector2(20, FigureArt.SHOULDER_Y + SIT_DROP)
	var mouth := Vector2(4, FigureArt.HEAD_Y + SIT_DROP + 16)
	var elbow := shoulder + Vector2(10, 26).lerp(Vector2(14, 10), _sip)
	var hand := (shoulder + Vector2(26, 34)).lerp(mouth + Vector2(8, 6), _sip)
	if behind:
		draw_colored_polygon(PackedVector2Array([shoulder + Vector2(-7, 0), shoulder + Vector2(7, 0), elbow + Vector2(5, 3),
			elbow + Vector2(-5, -3)]), SHIRT.darkened(0.2))
		draw_line(elbow, hand, SHIRT.darkened(0.2), 10.0, true)
		return
	# Hand round the tea glass (tilted as he drinks).
	var tilt := -0.6 * _sip
	draw_set_transform(hand + Vector2(4, -6), tilt)
	draw_colored_polygon(PackedVector2Array([Vector2(-4.5, 8), Vector2(4.5, 8), Vector2(5.5, -10), Vector2(-5.5, -10)]),
		Color(0.85, 0.93, 1.0, 0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 7), Vector2(4, 7), Vector2(5, -4), Vector2(-5, -4)]), TEA)
	draw_line(Vector2(-5.5, -10), Vector2(5.5, -10), Color(1, 1, 1, 0.7), 1.0)
	draw_set_transform(Vector2.ZERO)
	draw_circle(hand, 6.0, SKIN)
	draw_circle(hand + Vector2(-3, -2), 2.5, SKIN.darkened(0.1))
