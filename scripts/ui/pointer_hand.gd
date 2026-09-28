class_name PointerHand
extends Node2D
## A cartoon pointing hand (white glove, dark outline) for the tutorial. The
## fingertip is at the origin, pointing up; rotate the node to aim it.
## Pokes toward its tip on its own; the glove is drawn once on a child layer
## and only that layer moves.

const GLOVE := Color("fbf7ef")
const LINE := Color("2a1d14")

var _t := 0.0
var _body := Node2D.new()


func _ready() -> void:
	scale = Vector2(1.25, 1.25)
	add_child(_body)
	_body.draw.connect(_draw_hand)


func _process(delta: float) -> void:
	_t += delta
	_body.position = Vector2(0, absf(sin(_t * 4.0)) * 16.0)


func _draw_hand() -> void:
	var shapes := [
		_capsule(Vector2(0, 4), Vector2(0, 50), 11.0),
		PrepIcons._rrect(Rect2(-17, 40, 46, 48), 16),
		_capsule(Vector2(10, 46), Vector2(24, 46), 8.0),
		_capsule(Vector2(12, 60), Vector2(27, 60), 8.0),
		_capsule(Vector2(12, 74), Vector2(26, 74), 8.0),
		_capsule(Vector2(-14, 72), Vector2(-26, 52), 8.5),
	]
	# Drop shadow, outline pass, then the glove.
	for shape in shapes:
		_body.draw_colored_polygon(_offset(shape, Vector2(6, 8)), Color(0, 0, 0, 0.25))
	for shape in shapes:
		_body.draw_colored_polygon(Geometry2D.offset_polygon(shape, 3.5)[0], LINE)
	for shape in shapes:
		_body.draw_colored_polygon(shape, GLOVE)
	for y in [53.0, 67.0]:
		_body.draw_line(Vector2(12, y), Vector2(24, y), Color(LINE, 0.5), 2.0, true)
	_body.draw_line(Vector2(-3, 20), Vector2(-3, 38), Color(1, 1, 1, 0.8), 3.0, true)
	var cuff := PrepIcons._rrect(Rect2(-15, 86, 42, 16), 5)
	_body.draw_colored_polygon(Geometry2D.offset_polygon(cuff, 3.5)[0], LINE)
	_body.draw_colored_polygon(cuff, Color("e0a458"))
	_body.draw_line(Vector2(-12, 91), Vector2(24, 91), Color(1, 1, 1, 0.35), 2.0)


static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := (b - a).angle()
	for i in 9:
		var t := d + PI * 0.5 + PI * i / 8.0
		pts.append(a + Vector2(cos(t), sin(t)) * r)
	for i in 9:
		var t := d - PI * 0.5 + PI * i / 8.0
		pts.append(b + Vector2(cos(t), sin(t)) * r)
	return pts


static func _offset(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + by)
	return out
