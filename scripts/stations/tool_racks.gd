class_name ToolRacks
extends Control
## Sayed's movable racks inside the trunk, drawn over the backdrop and under
## the kit: a rail across the seat back with his spare كنكة in three sizes, a
## ladle, the milk pan and tongs on S-hooks; a short rail with the lemon
## squeezer, a tea strainer and a towel; and a chalk menu board listing
## today's drinks and prices. In arrange mode (the "رتّب" button) each can
## be dragged to wherever the player likes; positions are kept in the save.

const METAL := Color("b3b9c2")
const METAL_DARK := Color("6f7682")
const METAL_LIGHT := Color("e6e9ee")
const BRASS := Color("c9a24a")
const GRIP := Color("5a3620")
const SQUEEZER := Color("f2c230")
const BOARD := Color("22302a")
const CHALK := Color(0.95, 0.94, 0.88)
const FRAME_WOOD := Color("8a5a32")

## Each rack's size at art scale 1 (the rail's length and how far its
## things hang, or the board).
const RACKS := {
	"hooks": Vector2(380, 190),
	"lemon": Vector2(190, 200),
	"board": Vector2(180, 200),
}

var backdrop: TrunkBackdrop
var arranging := false

var _font: Font = preload("res://assets/ui/main_theme.tres").default_font
var _soft := StationArt._make_soft_texture()
## Normalised positions within the trunk (0..1 across, 0..1 down), by id.
var _pos := {}
var _drag := ""
var _drag_from := Vector2.ZERO
var _overlay: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var saved: Dictionary = Economy.data.settings.get("rack_positions", {})
	for id in RACKS:
		if saved.has(id):
			_pos[id] = Vector2(saved[id][0], saved[id][1])
	if backdrop:
		backdrop.frame_changed.connect(queue_redraw)
	DayClock.minute_changed.connect(queue_redraw)


#region Arranging

## Shows the arrange overlay (drag the racks, then خلاص) or closes it.
func set_arranging(on: bool) -> void:
	arranging = on
	if on and _overlay == null:
		_overlay = Control.new()
		_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_overlay.mouse_filter = MOUSE_FILTER_STOP
		_overlay.gui_input.connect(_on_overlay_input)
		_overlay.draw.connect(_draw_overlay)
		get_parent().add_child(_overlay)
		var done := Button.new()
		done.text = tr("UI_ARRANGE_DONE")
		done.add_theme_font_size_override("font_size", 36)
		done.custom_minimum_size = Vector2(220, 84)
		done.position = Vector2(size.x * 0.5 - 110, size.y - 300)
		done.pressed.connect(set_arranging.bind(false))
		_overlay.add_child(done)
	elif not on and _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_save()
	queue_redraw()


func _on_overlay_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag = _rack_at(e.position)
			_drag_from = e.position
		else:
			_drag = ""
			_save()
	elif e is InputEventMouseMotion and not _drag.is_empty():
		var g := backdrop.trunk_geo()
		var r := _rack_rect(_drag, g)
		var moved: Vector2 = r.position + (e.position - _drag_from)
		_drag_from = e.position
		_pos[_drag] = _to_norm(_clamp(moved, r.size, g), g)
		queue_redraw()
		_overlay.queue_redraw()


func _draw_overlay() -> void:
	_overlay.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05, 0.35))
	var g := backdrop.trunk_geo()
	for id in RACKS:
		var r := _rack_rect(id, g)
		_overlay.draw_rect(r.grow(8), Color(1, 0.78, 0.38, 0.9 if id == _drag else 0.6), false, 4.0)
		_overlay.draw_circle(r.position + Vector2(r.size.x * 0.5, -22), 16, Color(1, 0.78, 0.38))
		for d in [Vector2(-8, 0), Vector2(8, 0), Vector2(0, -8), Vector2(0, 8)]:
			_overlay.draw_line(r.position + Vector2(r.size.x * 0.5, -22), r.position + Vector2(r.size.x * 0.5, -22) + d,
				Color("3a2412"), 3.0)
	var title := tr("UI_ARRANGE_HINT")
	_overlay.draw_string(_font, Vector2(0, 186), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(1, 0.85, 0.5))


func _rack_at(p: Vector2) -> String:
	var g := backdrop.trunk_geo()
	for id in ["board", "lemon", "hooks"]:
		if _rack_rect(id, g).grow(20).has_point(p):
			return id
	return ""


func _save() -> void:
	var out := {}
	for id in _pos:
		out[id] = [_pos[id].x, _pos[id].y]
	Economy.data.settings["rack_positions"] = out
	Economy.save()

#endregion


#region Layout

## Where a rack sits (design space): its saved spot, or its default.
func _rack_rect(id: String, g: Dictionary) -> Rect2:
	var sz: Vector2 = RACKS[id] * float(g.s)
	var at: Vector2
	if _pos.has(id):
		at = _from_norm(_pos[id], g)
	else:
		match id:
			"hooks":
				at = Vector2(lerpf(g.bl, g.br, 0.05), g.seat_top + 30.0)
			"board":
				at = Vector2(lerpf(g.bl, g.br, 0.97) - sz.x, g.seat_top + 16.0)
			_:
				at = Vector2(g.fl + 34.0 * g.s, g.plank + 58.0 * g.s)
	return Rect2(_clamp(at, sz, g), sz)


func _clamp(at: Vector2, sz: Vector2, g: Dictionary) -> Vector2:
	return Vector2(clampf(at.x, g.tl + 6.0, maxf(g.tr - sz.x - 6.0, g.tl + 6.0)),
		clampf(at.y, g.seat_top + 6.0, maxf(g.floor - sz.y - 60.0, g.seat_top + 6.0)))


func _to_norm(p: Vector2, g: Dictionary) -> Vector2:
	return Vector2((p.x - g.tl) / maxf(g.tr - g.tl, 1.0), (p.y - g.seat_top) / maxf(g.floor - g.seat_top, 1.0))


func _from_norm(n: Vector2, g: Dictionary) -> Vector2:
	return Vector2(g.tl + n.x * (g.tr - g.tl), g.seat_top + n.y * (g.floor - g.seat_top))

#endregion


#region Drawing

func _draw() -> void:
	if backdrop == null or backdrop.inner.y <= backdrop.inner.x:
		return
	var g := backdrop.trunk_geo()
	var s: float = g.s
	if s <= 0.05:
		return
	_draw_hooks(_rack_rect("hooks", g), s)
	_draw_lemon_rack(_rack_rect("lemon", g), s)
	_draw_board(_rack_rect("board", g), s)


## A chrome rail on two wall brackets, with its shadow on the seat back.
func _draw_rail(a: Vector2, length: float, s: float) -> void:
	var b := a + Vector2(length, 0)
	draw_line(a + Vector2(4, 9 * s), b + Vector2(4, 9 * s), Color(0, 0, 0, 0.35), 7.0 * s)
	for p in [a + Vector2(10 * s, 0), b - Vector2(10 * s, 0)]:
		draw_colored_polygon(PrepIcons._rrect(Rect2(p - Vector2(8, 10) * s, Vector2(16, 22) * s), 3 * s), Color("2c2a30"))
		draw_circle(p + Vector2(0, 5 * s), 2.5 * s, METAL_LIGHT)
	draw_line(a, b, METAL_DARK, 7.0 * s, true)
	draw_line(a + Vector2(0, -2 * s), b + Vector2(0, -2 * s), METAL_LIGHT, 2.0 * s, true)


## An S-hook over the rail; returns where the hung thing's hole is.
func _s_hook(at: Vector2, s: float) -> Vector2:
	draw_arc(at + Vector2(0, -2 * s), 5 * s, PI * 1.1, TAU * 1.05, 8, METAL, 2.0 * s)
	draw_arc(at + Vector2(0, 10 * s), 5 * s, -PI * 0.05, PI * 1.0, 8, METAL, 2.0 * s)
	return at + Vector2(-5 * s, 12 * s)


## Soft shadow of a hung thing on the seat back behind it.
func _hang_shadow(c: Vector2, r: Vector2) -> void:
	draw_texture_rect(_soft, Rect2(c + Vector2(10, 12) - r, r * 2.0), false, Color(0, 0, 0, 0.35))


func _draw_hooks(r: Rect2, s: float) -> void:
	var a := r.position
	_draw_rail(a, r.size.x, s)
	var items := [
		[0.1, _kanaka.bind(1.0)], [0.27, _kanaka.bind(0.78)], [0.42, _kanaka.bind(0.6)],
		[0.57, _ladle], [0.72, _milk_pan], [0.88, _tongs],
	]
	for item in items:
		var hole := _s_hook(a + Vector2(r.size.x * item[0], 0), s)
		(item[1] as Callable).call(hole, s)


func _draw_lemon_rack(r: Rect2, s: float) -> void:
	var a := r.position
	_draw_rail(a, r.size.x, s)
	_squeezer(_s_hook(a + Vector2(r.size.x * 0.2, 0), s), s)
	_strainer(_s_hook(a + Vector2(r.size.x * 0.5, 0), s), s)
	_towel(a + Vector2(r.size.x * 0.64, 0), s)


## A spare كنكة hanging by the hole at the end of its handle: drawn in
## the stove's side profile, turned so the handle points up at the hook and
## the pot hangs below it with its mouth to one side.
func _kanaka(hole: Vector2, s: float, k: float) -> void:
	var z := 0.42 * s * k
	var rot := -PI * 0.5 - atan2(-38.0, 180.0)
	var origin := hole - (Vector2(244, -139) * z).rotated(rot)
	var belly := origin + (Vector2(0, -60) * z).rotated(rot)
	_hang_shadow(belly, Vector2(70, 60) * z)
	draw_set_transform(origin, rot, Vector2(z, z))
	var body := PackedVector2Array()
	for p in KanakaStove.K_PROFILE:
		body.append(Vector2(-p.x, p.y))
	for i in range(KanakaStove.K_PROFILE.size() - 1, -1, -1):
		body.append(KanakaStove.K_PROFILE[i])
	draw_colored_polygon(body, METAL)
	# Shade on the far side, a bright band near the light, the hammered dents.
	var shade := PackedVector2Array()
	var shine := PackedVector2Array()
	for p in KanakaStove.K_PROFILE:
		shade.append(Vector2(p.x * 0.35, p.y))
		shine.append(Vector2(-p.x * 0.72, p.y))
	for i in range(KanakaStove.K_PROFILE.size() - 1, -1, -1):
		var p: Vector2 = KanakaStove.K_PROFILE[i]
		shade.append(p)
		shine.append(Vector2(-p.x * 0.5, p.y))
	draw_colored_polygon(shade, Color(0, 0, 0, 0.22))
	draw_colored_polygon(shine, Color(1, 1, 1, 0.28))
	for i in 10:
		var c := Vector2(float((i * 47) % 140) - 70.0, -16.0 - float((i * 31) % 110))
		draw_arc(c, 6.0, 0.3, PI - 0.3, 6, Color(1, 1, 1, 0.22), 2.0)
	# Rim seen edge-on, the dark mouth just showing, the spout.
	draw_colored_polygon(PrepIcons._ellipse(Vector2(0, KanakaStove.K_RIM_Y), Vector2(82, 12), 0.0, 20), Color("2a2522"))
	var rim := PrepIcons._ellipse(Vector2(0, KanakaStove.K_RIM_Y), Vector2(82, 12), 0.0, 20)
	rim.append(rim[0])
	draw_polyline(rim, METAL_LIGHT, 5.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-70, -150), KanakaStove.K_SPOUT, Vector2(-79, -137)]), METAL)
	# Handle with its wooden grip and the hanging hole.
	draw_line(Vector2(60, -100), Vector2(172, -124), METAL_DARK, 12.0, true)
	draw_line(Vector2(160, -121.5), Vector2(244, -139), GRIP, 20.0, true)
	draw_line(Vector2(166, -126), Vector2(238, -142), GRIP.lightened(0.2), 4.0, true)
	draw_circle(Vector2(236, -138), 6.0, Color("1a1410"))
	draw_set_transform(Vector2.ZERO)


## Aluminium soup ladle.
func _ladle(hole: Vector2, s: float) -> void:
	var bowl := hole + Vector2(0, 150 * s)
	_hang_shadow(bowl + Vector2(0, -40 * s), Vector2(24, 90) * s)
	draw_circle(hole, 4 * s, Color("1a1410"))
	draw_line(hole + Vector2(0, 6 * s), bowl + Vector2(0, -26 * s), METAL, 5.0 * s, true)
	draw_line(hole + Vector2(-1.5 * s, 8 * s), bowl + Vector2(-1.5 * s, -28 * s), METAL_LIGHT, 1.5 * s, true)
	draw_colored_polygon(PrepIcons._ellipse(bowl, Vector2(26, 24) * s, 0.0, 20), METAL_DARK)
	draw_colored_polygon(PrepIcons._ellipse(bowl + Vector2(-2, -2) * s, Vector2(22, 20) * s, 0.0, 20), METAL)
	draw_colored_polygon(PrepIcons._ellipse(bowl + Vector2(-8, -8) * s, Vector2(7, 5) * s, -0.5, 10), Color(1, 1, 1, 0.45))


## The small milk pan, hanging by its handle.
func _milk_pan(hole: Vector2, s: float) -> void:
	var c := hole + Vector2(0, 118 * s)
	_hang_shadow(c, Vector2(42, 48) * s)
	draw_line(hole, hole + Vector2(0, 66 * s), Color("2a2a30"), 9.0 * s, true)
	draw_circle(hole, 4 * s, Color("0e0d11"))
	draw_colored_polygon(PrepIcons._ellipse(c, Vector2(40, 40) * s, 0.0, 24), Color("d0d4da"))
	draw_colored_polygon(PrepIcons._ellipse(c, Vector2(33, 33) * s, 0.0, 24), Color("9aa0aa"))
	draw_arc(c, 36 * s, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.6), 3.0 * s)
	draw_colored_polygon(PrepIcons._ellipse(c + Vector2(10, 12) * s, Vector2(10, 7) * s, 0.5, 10), Color(1, 1, 1, 0.12))


## Tongs for the ice (and later the shisha coals).
func _tongs(hole: Vector2, s: float) -> void:
	draw_circle(hole + Vector2(0, 6 * s), 6 * s, METAL_DARK)
	for side in [-1.0, 1.0]:
		var tip := hole + Vector2(side * 14.0 * s, 150 * s)
		draw_line(hole + Vector2(side * 3.0 * s, 8 * s), tip, METAL, 4.0 * s, true)
		draw_line(tip, tip + Vector2(-side * 7.0 * s, 10 * s), METAL, 4.0 * s, true)
	_hang_shadow(hole + Vector2(0, 80 * s), Vector2(22, 80) * s)


## The Egyptian lemon press, painted yellow: two long handles up to the
## hook, the perforated cup and its dome at the bottom where they hinge.
func _squeezer(hole: Vector2, s: float) -> void:
	var head := hole + Vector2(0, 124 * s)
	_hang_shadow(head + Vector2(0, -40 * s), Vector2(34, 90) * s)
	draw_circle(hole, 4 * s, Color("1a1410"))
	for side in [-1.0, 1.0]:
		draw_line(hole + Vector2(side * 4.0 * s, 4 * s), head + Vector2(side * 22.0 * s, -20 * s), SQUEEZER.darkened(0.25), 9.0 * s, true)
		draw_line(hole + Vector2(side * 4.0 * s - 2 * s, 6 * s), head + Vector2(side * 22.0 * s - 2 * s, -22 * s),
			SQUEEZER, 4.0 * s, true)
	# The cup, its holes, and the dome of the press closed over it.
	draw_colored_polygon(PrepIcons._ellipse(head, Vector2(30, 24) * s, 0.0, 22), SQUEEZER.darkened(0.2))
	draw_colored_polygon(PrepIcons._ellipse(head + Vector2(0, -3) * s, Vector2(26, 20) * s, 0.0, 22), SQUEEZER)
	for i in 7:
		var a := TAU * i / 7.0
		draw_circle(head + Vector2(cos(a) * 14, sin(a) * 10 - 3) * s, 2.2 * s, Color("7a5a10"))
	draw_circle(head + Vector2(0, -3) * s, 3.0 * s, Color("7a5a10"))
	draw_colored_polygon(PrepIcons._ellipse(head + Vector2(-9, -10) * s, Vector2(7, 4) * s, -0.4, 10), Color(1, 1, 1, 0.45))
	draw_circle(head + Vector2(0, -24) * s, 5 * s, METAL_DARK)


## A fine-mesh tea strainer.
func _strainer(hole: Vector2, s: float) -> void:
	var c := hole + Vector2(0, 96 * s)
	_hang_shadow(c, Vector2(30, 34) * s)
	draw_line(hole, c + Vector2(0, -28 * s), METAL, 4.0 * s, true)
	draw_colored_polygon(PrepIcons._ellipse(c, Vector2(27, 27) * s, 0.0, 22), METAL_DARK)
	draw_colored_polygon(PrepIcons._ellipse(c, Vector2(23, 23) * s, 0.0, 22), Color("4a4850"))
	for k in range(-4, 5):
		var o := k * 5.0 * s
		var half := sqrt(maxf(0.0, 23.0 * s * 23.0 * s - o * o))
		draw_line(c + Vector2(o, -half), c + Vector2(o, half), Color(1, 1, 1, 0.18), 1.0)
		draw_line(c + Vector2(-half, o), c + Vector2(half, o), Color(1, 1, 1, 0.18), 1.0)
	draw_arc(c, 25 * s, 0.0, TAU, 24, METAL_LIGHT, 2.0 * s)


## A checked kitchen towel draped over the rail.
func _towel(at: Vector2, s: float) -> void:
	var w := 62.0 * s
	var h := 120.0 * s
	var back := PackedVector2Array([at + Vector2(0, -4 * s), at + Vector2(w, -4 * s), at + Vector2(w + 4 * s, h * 0.6),
		at + Vector2(-2 * s, h * 0.6)])
	draw_colored_polygon(back, Color("c8c2b6"))
	var front := PackedVector2Array([at + Vector2(-4 * s, 0), at + Vector2(w + 2 * s, 0), at + Vector2(w + 8 * s, h),
		at + Vector2(-6 * s, h - 6 * s)])
	draw_texture_rect(_soft, Rect2(at + Vector2(-20 * s, 20 * s), Vector2(w + 50 * s, h + 10 * s)), false, Color(0, 0, 0, 0.3))
	draw_colored_polygon(front, Color("efe9dc"))
	for k in 5:
		var y := h * (0.15 + k * 0.18)
		draw_line(at + Vector2(-5 * s, y), at + Vector2(w + 6 * s, y + 2 * s), Color("c23b2a", 0.75), 5.0 * s)
	for k in 3:
		var x := w * (0.2 + k * 0.3)
		draw_line(at + Vector2(x, 0), at + Vector2(x + 3 * s, h - 3 * s), Color("c23b2a", 0.45), 4.0 * s)
	draw_line(at + Vector2(-4 * s, 2 * s), at + Vector2(w + 2 * s, 2 * s), Color(0, 0, 0, 0.18), 3.0 * s)


## Chalkboard hung from a nail: the drinks you can order today, with prices.
func _draw_board(r: Rect2, s: float) -> void:
	var nail := r.position + Vector2(r.size.x * 0.5, 0)
	draw_texture_rect(_soft, Rect2(r.position + Vector2(-10, 14 * s), r.size + Vector2(34, 30) * s), false, Color(0, 0, 0, 0.45))
	var top := r.position + Vector2(0, 30 * s)
	var body := Rect2(top, Vector2(r.size.x, r.size.y - 30 * s))
	draw_line(nail, top + Vector2(18 * s, 0), Color("d8d2c6"), 1.5 * s, true)
	draw_line(nail, top + Vector2(r.size.x - 18 * s, 0), Color("d8d2c6"), 1.5 * s, true)
	draw_circle(nail, 4 * s, METAL_DARK)
	draw_rect(body, FRAME_WOOD)
	draw_rect(body.grow(-8 * s), BOARD)
	draw_rect(Rect2(body.position + Vector2(8, 8) * s, Vector2(body.size.x - 16 * s, 3 * s)), Color(0, 0, 0, 0.3))
	for k in 3:
		draw_line(body.position + Vector2(20 + k * 44, 30 + k * 11) * s, body.position + Vector2(50 + k * 40, 60 + k * 9) * s,
			Color(1, 1, 1, 0.04), 12.0 * s)
	var inner := body.grow(-14 * s)
	var fs := int(22.0 * s)
	draw_string(_font, Vector2(inner.position.x, inner.position.y + fs), tr("UI_MENU_BOARD"), HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x, fs, CHALK)
	draw_line(inner.position + Vector2(inner.size.x * 0.2, fs + 8 * s), inner.position + Vector2(inner.size.x * 0.8, fs + 8 * s),
		Color(CHALK, 0.6), 1.5 * s)
	var y := inner.position.y + fs * 2.0 + 10 * s
	var line_fs := int(15.0 * s)
	for item in _menu_lines():
		if y > inner.end.y - 4 * s:
			break
		draw_string(_font, Vector2(inner.position.x, y), item[0], HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x, line_fs, CHALK)
		draw_string(_font, Vector2(inner.position.x, y), item[1], HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, line_fs,
			Color("f2d24a"))
		y += line_fs + 7.0 * s
	# A chalk stub and the rag on the frame's ledge.
	draw_rect(Rect2(body.end - Vector2(46, 8) * s, Vector2(20, 5) * s), CHALK)


## Today's orderable drinks, [name, "٨ ج"], cheapest first.
func _menu_lines() -> Array:
	var rows := []
	for id in GameData.menu_items:
		var item: Dictionary = GameData.menu_items[id]
		if int(item.get("unlock_tier", 0)) > Economy.current_venue_tier or not Economy.owns_slot(item.get("station", "")):
			continue
		var price := roundi(GameData.price_for(id, Economy.current_venue_tier))
		rows.append([tr(item.get("name_key", id)), "%s ج" % GameData.ar_digits(price), price])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	return rows

#endregion
