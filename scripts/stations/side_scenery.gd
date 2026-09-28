class_name SideScenery
extends Control
## What you see around FIFI's rear when the screen is wider (or taller) than
## the fixed 9:16 prep panel: the street carrying on either side. Cairo
## apartment blocks, the wide road with its lane dashes on the left, the
## black-and-white kerb and pavement with Sayed's ice box on the right, and
## Cairo sodium streetlights on both sides.
## Lit by DayClock; redraws only on resize or when the game minute ticks.

## Width / height of the prep panel it frames (matches the AspectRatioContainer).
const PANEL_RATIO := 0.75
const BUILDING := Color("3a3548")
const WINDOW_LIT := Color("ffd27a")
const WINDOW_DAY := Color("8aa3c2")
const ASPHALT := Color("55575f")
const PAVEMENT := Color("8f8a86")
const KERB := Color("b8b4ae")
const POLE := Color("8d9199")
const HEAD := Color("7c8088")
const SODIUM := Color("ffa94d")
const PAINT_DARK := Color("2c2c31")
const PAINT_LIGHT := Color("e6e3dc")
const ICEBOX := Color("2f6fb3")
const ICEBOX_LID := Color("eef1f4")

var _soft := StationArt._make_soft_texture()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	DayClock.minute_changed.connect(queue_redraw)


func panel_rect() -> Rect2:
	var w := minf(size.x, size.y * PANEL_RATIO)
	var h := w / PANEL_RATIO
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)


func _draw() -> void:
	var panel := panel_rect()
	var amb := DayClock.ambient()
	var dark := DayClock.darkness()
	var sky := DayClock.sky()
	var horizon := panel.position.y + panel.size.y * 0.36
	var cx := panel.get_center().x
	# Sky, fading lighter toward the horizon.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([sky.darkened(0.35), sky.darkened(0.35), sky.lightened(0.12), sky.lightened(0.12)]))
	_draw_buildings(horizon, amb, dark)
	# Road down to the viewer, with the far kerb under the buildings.
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), ASPHALT * amb)
	draw_rect(Rect2(0, horizon, size.x, 18), (PAVEMENT * amb).darkened(0.1))
	# Perspective lines run out of a vanishing point behind the car.
	var bottom := panel.end.y
	var k := (panel.size.x * 0.62) / maxf(bottom - horizon, 1.0)
	var kerb_at := func(y: float) -> float: return cx + (y - horizon) * k
	# Pavement on the passenger side (the right, seen from behind).
	var pave := PackedVector2Array([Vector2(kerb_at.call(horizon + 18), horizon + 18), Vector2(size.x, horizon + 18),
		Vector2(size.x, size.y), Vector2(kerb_at.call(size.y), size.y)])
	var screen := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	for piece in Geometry2D.intersect_polygons(pave, screen):
		draw_colored_polygon(piece, PAVEMENT * amb)
	for i in range(1, 14):
		var y := horizon + 18 + pow(i / 13.0, 1.6) * (size.y - horizon - 18)
		draw_line(Vector2(kerb_at.call(y), y), Vector2(size.x, y), Color(0, 0, 0, 0.12), 2.0)
	# Kerb painted in alternating black and white blocks, longer as they near us.
	var y := horizon + 18.0
	var block := 0
	while y < size.y:
		var y2 := minf(y + 8.0 + (y - horizon) * 0.12, size.y)
		draw_line(Vector2(kerb_at.call(y), y), Vector2(kerb_at.call(y2), y2),
			(PAINT_DARK if block % 2 == 0 else PAINT_LIGHT) * amb, 4.0 + (y - horizon) * 0.02)
		y = y2
		block += 1
	# Lane dashes on the road side.
	for i in 10:
		var y0 := horizon + 30 + pow(i / 10.0, 1.7) * (size.y - horizon)
		var y1 := y0 + 12 + i * 10.0
		var x0: float = cx - (y0 - horizon) * k * 1.7
		var x1: float = cx - (y1 - horizon) * k * 1.7
		draw_line(Vector2(x0, y0), Vector2(x1, y1), Color(0.9, 0.88, 0.8, 0.5) * amb, 4.0 + i)
	_draw_streetlight(Vector2(panel.end.x + 260, bottom - 60), -1.0, 1.0, horizon, amb, dark)
	_draw_streetlight(Vector2(panel.position.x - 520, horizon + 40), 1.0, 0.45, horizon, amb, dark)
	_draw_icebox(Vector2(panel.end.x + 70, bottom - 40), amb)


func _draw_buildings(horizon: float, amb: Color, dark: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 127
	var x := -40.0
	while x < size.x:
		var bw := rng.randf_range(160, 280)
		var bh := rng.randf_range(260, 560)
		var top := horizon - bh
		var tint := BUILDING.lightened(rng.randf_range(0.0, 0.12))
		draw_rect(Rect2(x, top, bw, bh), tint * amb)
		# Balcony ledges, water tanks and satellite dishes on the roofs.
		var rows := int(bh / 64.0)
		for r in rows:
			var wy := top + 22 + r * 64
			for c in int(bw / 52.0):
				var wx := x + 16 + c * 52
				var lit := rng.randf() < 0.45
				var col := WINDOW_DAY * amb
				if dark > 0.05:
					col = col.lerp(StationArt.hdr(WINDOW_LIT, 1.3) if lit else Color("1c1a28"), dark)
				draw_rect(Rect2(wx, wy, 28, 34), col)
			draw_rect(Rect2(x, wy + 42, bw, 5), (tint.darkened(0.3)) * amb)
		if rng.randf() < 0.6:
			draw_rect(Rect2(x + bw * 0.6, top - 26, 34, 26), Color("4a4656") * amb)
		if rng.randf() < 0.7:
			draw_circle(Vector2(x + bw * 0.25, top - 10), 12, Color("c8c4bc") * amb)
		x += bw + rng.randf_range(4, 18)


## A Cairo street lamp seen side-on: concrete foot, tapered galvanised pole
## with black-and-white bands low down, a swan-neck arm reaching over the road
## (reach -1 = to the left), a cobra-head lantern, and after dusk its sodium
## cone and pool of light. `k` scales it for distance.
func _draw_streetlight(base: Vector2, reach: float, k: float, horizon: float, amb: Color, dark: float) -> void:
	var top := Vector2(base.x, horizon - 420.0 * k - (base.y - horizon) * 0.2)
	var head := top + Vector2(reach * 170.0 * k, 26.0 * k)
	if dark > 0.01:
		var pool := Vector2(head.x, base.y + 8.0 * k)
		draw_polygon(PackedVector2Array([head + Vector2(-18 * k, 10 * k), head + Vector2(18 * k, 10 * k),
			pool + Vector2(170 * k, 0), pool + Vector2(-170 * k, 0)]),
			PackedColorArray([Color(SODIUM, 0.22 * dark), Color(SODIUM, 0.22 * dark), Color(SODIUM, 0.0), Color(SODIUM, 0.0)]))
		_soft_blob(pool, Vector2(280, 60) * k, Color(SODIUM, 0.35 * dark))
	draw_rect(Rect2(base.x - 20 * k, base.y - 22 * k, 40 * k, 22 * k), Color("a8a49c") * amb)
	var hb := 11.0 * k
	var ht := 5.0 * k
	var y0 := base.y - 22.0 * k
	draw_colored_polygon(PackedVector2Array([Vector2(base.x - hb, y0), Vector2(base.x, y0), top, top - Vector2(ht, 0)]),
		POLE.lightened(0.15) * amb)
	draw_colored_polygon(PackedVector2Array([Vector2(base.x, y0), Vector2(base.x + hb, y0), top + Vector2(ht, 0), top]),
		POLE.darkened(0.2) * amb)
	for band in 6:
		var ya := y0 - band * 22.0 * k
		var w := lerpf(hb, ht, (y0 - ya) / maxf(y0 - top.y, 1.0)) + 0.5
		draw_rect(Rect2(base.x - w, ya - 22.0 * k, w * 2.0, 22.0 * k), (PAINT_DARK if band % 2 == 0 else PAINT_LIGHT) * amb)
	draw_rect(Rect2(base.x - 5 * k, y0 - 170 * k, 10 * k, 26 * k), POLE.darkened(0.35) * amb)
	# Swan-neck arm curving up and out to the lantern.
	var arm := PackedVector2Array()
	var c1 := top + Vector2(0, -70 * k)
	var c2 := head + Vector2(-reach * 40 * k, -24 * k)
	for i in 17:
		var t := i / 16.0
		arm.append(top.lerp(c1, t).lerp(c1.lerp(c2, t), t).lerp(c1.lerp(c2, t).lerp(c2.lerp(head, t), t), t))
	draw_polyline(arm, POLE.darkened(0.1) * amb, 9.0 * k, true)
	draw_polyline(arm, POLE.lightened(0.25) * amb, 3.0 * k, true)
	# Cobra head: long rounded shell, glowing lens underneath.
	var shell := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		shell.append(head + Vector2(reach * (cos(a) * 44.0 + 12.0), sin(a) * 13.0 - 4.0) * k)
	draw_colored_polygon(shell, HEAD * amb)
	draw_line(head + Vector2(reach * -24, -12) * k, head + Vector2(reach * 44, -12) * k, HEAD.lightened(0.35) * amb, 3.0 * k)
	var lens := PackedVector2Array([head + Vector2(reach * -22, 4) * k, head + Vector2(reach * 46, 4) * k,
		head + Vector2(reach * 38, 12) * k, head + Vector2(reach * -14, 12) * k])
	draw_colored_polygon(lens, (Color("d8d4c8") * amb).lerp(StationArt.hdr(SODIUM.lightened(0.5), 3.0), dark))
	if dark > 0.01:
		var glow := head + Vector2(reach * 12, 10) * k
		_soft_blob(glow, Vector2(130, 130) * k, Color(SODIUM, 0.45 * dark))
		_soft_blob(glow, Vector2(44, 44) * k, StationArt.hdr(Color(1.0, 0.92, 0.75, 0.8 * dark), 2.2))


func _draw_icebox(base: Vector2, amb: Color) -> void:
	var w := 170.0
	var h := 110.0
	_soft_blob(base + Vector2(w * 0.5, 6), Vector2(w * 0.7, 18), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(base.x, base.y - h, w, h), ICEBOX * amb)
	draw_rect(Rect2(base.x + w - 30, base.y - h, 30, h), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(base.x - 6, base.y - h - 26, w + 12, 30), ICEBOX_LID * amb)
	draw_rect(Rect2(base.x + 40, base.y - h - 36, w - 80, 12), ICEBOX_LID.darkened(0.2) * amb)
	for f in [[Vector2(52, -150), 20.0, Color("f2a324")], [Vector2(92, -154), 19.0, Color("e8c33a")],
			[Vector2(126, -146), 14.0, Color("f4e04d")]]:
		var at: Vector2 = base + f[0]
		draw_circle(at, f[1], f[2] * amb)
		draw_circle(at + Vector2(-5, -6), f[1] * 0.3, Color(1, 1, 1, 0.3))


func _soft_blob(c: Vector2, r: Vector2, color: Color) -> void:
	draw_texture_rect(_soft, Rect2(c - r, r * 2.0), false, color)
