class_name StationArt
extends Control
## Shared drawing kit for the flat prep-station art (stove, blender). Each
## scene is authored in a 960×740 box, scaled to fit and pinned to the bottom,
## standing on the front edge of FIFI's trunk floor (TrunkBackdrop draws the
## rest of the car around it). Purely visual: the gauges drive it.

signal sequence_finished

const SCENE_SIZE := Vector2(960, 740)
const COUNTER_Y := 606.0
## The carpet band runs from COUNTER_Y - 8 down to the sill.
const SILL_Y := COUNTER_Y + 18.0
const COLOR_CARPET := Color("463e46")
const COLOR_SAUCER := Color("ebe6dc")

var _t := 0.0
var _tween: Tween
var _busy := false
var _rng := RandomNumberGenerator.new()
## Soft round sprite for glows, steam and smoke.
var _soft := _make_soft_texture()


class Particle:
	var pos: Vector2
	var vel: Vector2
	var age := 0.0
	var life := 1.0
	var size := 4.0
	var color := Color.WHITE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _scene_scale() -> float:
	return minf(size.x / SCENE_SIZE.x, size.y / SCENE_SIZE.y)


func _scene_xf() -> Transform2D:
	var s := _scene_scale()
	var origin := Vector2((size.x - SCENE_SIZE.x * s) * 0.5, size.y - SCENE_SIZE.y * s)
	return Transform2D(0.0, Vector2(s, s), 0.0, origin)


## Left/right edges of the control in scene space, so the counter can run
## edge to edge on wide screens.
func _scene_span() -> Vector2:
	var xf := _scene_xf()
	var s := _scene_scale()
	return Vector2(-xf.origin.x / s, (size.x - xf.origin.x) / s)


## Screen position of a point in scene space, for lining up the backdrop.
func scene_to_global(p: Vector2) -> Vector2:
	return get_global_transform() * (_scene_xf() * p)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _finish_sequence() -> void:
	if _busy:
		_busy = false
		sequence_finished.emit()


func _particle(pos: Vector2, vel: Vector2, life: float, size_px: float, color: Color) -> Particle:
	var p := Particle.new()
	p.pos = pos
	p.vel = vel
	p.life = life
	p.size = size_px
	p.color = color
	return p


## Front edge of the trunk floor: a band of carpet the kit stands on.
func _draw_counter(left: float, right: float) -> void:
	var top := COUNTER_Y - 8.0
	draw_rect(Rect2(left, top, right - left, SILL_Y - top), COLOR_CARPET)
	draw_line(Vector2(left, top), Vector2(right, top), COLOR_CARPET.lightened(0.12), 2.0)
	for i in 40:
		var x := lerpf(left, right, float((i * 37) % 97) / 97.0)
		var y := top + 3.0 + float((i * 13) % 20)
		draw_circle(Vector2(x, y), 1.4, Color(1, 1, 1, 0.06))


func _draw_saucer(c: Vector2) -> void:
	_fill_ellipse(c + Vector2(0, 9), Vector2(104, 15), Color(0, 0, 0, 0.3))
	_fill_ellipse(c + Vector2(0, 5), Vector2(98, 15), COLOR_SAUCER.darkened(0.25))
	_fill_ellipse(c + Vector2(0, 2), Vector2(98, 14), COLOR_SAUCER)
	_fill_ellipse(c + Vector2(0, 2), Vector2(58, 8), COLOR_SAUCER.darkened(0.07))


## Quadratic pour stream from a spout to a landing point.
func _draw_stream(p0: Vector2, p2: Vector2, amount: float, color: Color, width := 5.5) -> void:
	var p1 := Vector2(p0.x - 46, p0.y + 6)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var t := i / float(n)
		var p := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var tangent := (p1 - p0).lerp(p2 - p1, t).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		p += normal * sin(_t * 25.0 + t * 9.0) * 1.2 * t
		var w := lerpf(width, width * 0.64, t) * amount
		left.append(p + normal * w)
		right.append(p - normal * w)
	right.reverse()
	draw_colored_polygon(left + right, Color(color.lightened(0.1), 0.95))


func _soft_blob(c: Vector2, r: Vector2, color: Color) -> void:
	draw_texture_rect(_soft, Rect2(c - r, r * 2.0), false, color)


static func _make_soft_texture() -> GradientTexture2D:
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
	return tex


func _fill_ellipse(c: Vector2, r: Vector2, color: Color, segments := 32) -> void:
	if r.x <= 0.0 or r.y <= 0.0:
		return
	draw_colored_polygon(_ellipse(c, r, segments), color)


func _ellipse(c: Vector2, r: Vector2, segments := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(c + Vector2(r.x * cos(a), r.y * sin(a)))
	return pts


## Ellipse arc from angle a0 to a1; 0..PI is the front (lower) half.
func _arc(c: Vector2, r: Vector2, a0: float, a1: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		pts.append(c + Vector2(r.x * cos(a), r.y * sin(a)))
	draw_polyline(pts, color, width, true)


func _clip_fill(shape: PackedVector2Array, region, color: Color) -> void:
	for piece in Geometry2D.intersect_polygons(shape, PackedVector2Array(region)):
		draw_colored_polygon(piece, color)
