class_name StreetVehicle
extends Node2D
## One passing vehicle on the street: a Cairo taxi, a microbus or a tuk-tuk,
## built from boxes in the street's 2:1 projection. The body is drawn once and
## tinted by the time of day through `modulate`; its lamps sit on a child
## layer that fades in after dusk. Traffic moves it by setting `u`.

enum Kind { TAXI, MICROBUS, TUKTUK }

const TILE_W := 128.0
const TILE_H := 64.0

var kind := Kind.TAXI
## +1 drives toward +u (we see its front), -1 toward -u (we see its back).
var dir := -1.0
var lane_v := -3.0
var speed := 4.0
var u := 0.0:
	set(value):
		u = value
		position = _point(u, lane_v)

var _lamps := Node2D.new()
var _soft := StationArt._make_soft_texture()


func _ready() -> void:
	add_child(_lamps)
	_lamps.draw.connect(_draw_lamps)


func set_light(ambient: Color, darkness: float) -> void:
	modulate = Color.WHITE
	self_modulate = ambient
	_lamps.modulate.a = lerpf(0.25, 1.0, darkness)


static func _point(pu: float, pv: float) -> Vector2:
	return Vector2((pu - pv) * TILE_W * 0.5, (pu + pv) * TILE_H * 0.5)


## Vehicle-local point: (along, across, height in px).
func _p(a: float, b: float, h: float) -> Vector2:
	return _point(a, b) + Vector2(0, -h)


func _dims() -> Vector3:
	match kind:
		Kind.MICROBUS:
			return Vector3(3.8, 1.6, 74)
		Kind.TUKTUK:
			return Vector3(2.0, 1.1, 60)
	return Vector3(3.2, 1.5, 56)


func _draw() -> void:
	var d := _dims()
	var hl := d.x * 0.5
	var hw := d.y * 0.5
	# Shadow on the road.
	draw_colored_polygon(PackedVector2Array([_p(-hl - 0.1, -hw - 0.1, 0), _p(hl + 0.2, -hw - 0.1, 0),
		_p(hl + 0.2, hw + 0.25, 0), _p(-hl - 0.1, hw + 0.25, 0)]), Color(0, 0, 0, 0.3))
	for s in [-0.3, 0.3]:
		_wheel(s * d.x, hw)
	match kind:
		Kind.TAXI:
			_box(-hl, hl, -hw, hw, 10, 32, Color("eeeeea"))
			# Cairo taxi: black-and-white chequered band along the side.
			for k in 16:
				var a := lerpf(-hl, hl, k / 16.0)
				var b := lerpf(-hl, hl, (k + 1) / 16.0)
				for row in 2:
					var h0 := 22.0 + row * 4.0
					if (k + row) % 2 == 0:
						draw_colored_polygon(PackedVector2Array([_p(a, hw + 0.01, h0), _p(b, hw + 0.01, h0),
							_p(b, hw + 0.01, h0 + 4), _p(a, hw + 0.01, h0 + 4)]), Color("1e1e22"))
			_box(-hl * 0.45, hl * 0.55, -hw * 0.85, hw * 0.85, 32, 52, Color("e6e6e2"))
			_windows(-hl * 0.4, hl * 0.5, hw * 0.85, 35, 49)
			_box(-0.15, 0.15, -0.25, 0.25, 52, 58, Color("f2d24a"))
		Kind.MICROBUS:
			_box(-hl, hl, -hw, hw, 10, d.z, Color("f1f1ee"))
			draw_colored_polygon(PackedVector2Array([_p(-hl, hw + 0.01, 30), _p(hl, hw + 0.01, 30),
				_p(hl, hw + 0.01, 36), _p(-hl, hw + 0.01, 36)]), Color("2f6fb3"))
			_windows(-hl + 0.2, hl - 0.3, hw, 44, 66)
			# Roof rack with a strapped bundle.
			_box(-hl * 0.5, hl * 0.3, -hw * 0.6, hw * 0.6, d.z, d.z + 8, Color("8a6a4a"))
		Kind.TUKTUK:
			_box(-hl, hl * 0.5, -hw, hw, 8, 30, Color("c8322b"))
			_box(hl * 0.5, hl, -hw * 0.5, hw * 0.5, 8, 34, Color("c8322b"))
			for a in [-hl + 0.05, hl * 0.45]:
				draw_line(_p(a, hw, 30), _p(a, hw, 56), Color("1c1c20"), 3.0)
			_box(-hl, hl * 0.6, -hw, hw, 54, 60, Color("1c1c20"))
	# The visible end: front grille or tail panel.
	var end := hl + 0.01
	if dir > 0:
		draw_line(_p(end, -hw * 0.5, 18), _p(end, hw * 0.5, 18), Color("2a2a30"), 3.0)
	else:
		draw_line(_p(end, -hw * 0.6, 14), _p(end, hw * 0.6, 14), Color("3a3a42"), 2.0)


func _draw_lamps() -> void:
	var d := _dims()
	var hl := d.x * 0.5 + 0.02
	var hw := d.y * 0.5
	for side in [-0.7, 0.7]:
		var at := _p(hl, side * hw, 20)
		if dir > 0:
			_lamps.draw_texture_rect(_soft, Rect2(at - Vector2(20, 20), Vector2(40, 40)), false, Color(1, 0.95, 0.8, 0.5))
			_lamps.draw_circle(at, 3.5, StationArt.hdr(Color(1, 0.96, 0.85), 2.4))
		else:
			_lamps.draw_texture_rect(_soft, Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, Color(1, 0.15, 0.1, 0.45))
			_lamps.draw_circle(at, 3.0, StationArt.hdr(Color(1, 0.2, 0.15), 2.0))
	if dir > 0:
		# Headlight beam spilling onto the road ahead.
		var ahead := _p(hl + 1.6, 0, 0)
		_lamps.draw_texture_rect(_soft, Rect2(ahead - Vector2(110, 55), Vector2(220, 110)), false, Color(1, 0.95, 0.8, 0.18))


## Visible faces of a box: top, near side (+across) and the +along end.
func _box(a0: float, a1: float, b0: float, b1: float, h0: float, h1: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([_p(a0, b0, h1), _p(a1, b0, h1), _p(a1, b1, h1), _p(a0, b1, h1)]),
		col.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([_p(a0, b1, h0), _p(a1, b1, h0), _p(a1, b1, h1), _p(a0, b1, h1)]),
		col.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([_p(a1, b0, h0), _p(a1, b1, h0), _p(a1, b1, h1), _p(a1, b0, h1)]),
		col.darkened(0.28))


func _windows(a0: float, a1: float, b: float, h0: float, h1: float) -> void:
	draw_colored_polygon(PackedVector2Array([_p(a0, b + 0.01, h0), _p(a1, b + 0.01, h0), _p(a1, b + 0.01, h1),
		_p(a0, b + 0.01, h1)]), Color("1c2346"))
	draw_line(_p(lerpf(a0, a1, 0.3), b + 0.01, h0), _p(lerpf(a0, a1, 0.36), b + 0.01, h1), Color(1, 1, 1, 0.15), 3.0)


func _wheel(a: float, b: float) -> void:
	var c := _p(a, b, 8)
	draw_set_transform(c, 0.0, Vector2(1.0, 1.0))
	draw_circle(Vector2.ZERO, 9, Color("16161b"))
	draw_circle(Vector2.ZERO, 4, Color("8a8f98"))
	draw_set_transform(Vector2.ZERO)
