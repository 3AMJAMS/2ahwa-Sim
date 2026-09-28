class_name Customer
extends Node2D
## One customer on the pavement: walks up to FIFI, shouts an order (speech
## bubble), waits with a patience bar over their head, and walks off happy
## once served or angry when patience runs out. Follows the blueprint's
## patience state machine:
##   ARRIVING → ORDER_PLACED (waiting for the drink) → SERVED | LEFT_ANGRY
## The body is a placeholder figure (galabeya and kufi, shirt and trousers,
## hijab and abaya, or t-shirt and jeans) baked into one mesh.

signal ordered
signal tapped
signal left(angry: bool)

enum State { ARRIVING, WAITING, LEAVING }
enum Look { GALABEYA, SHIRT, HIJAB, TSHIRT }

const TILE_W := 128.0
const TILE_H := 64.0
const PAVEMENT_RISE := 10.4
const WALK_SPEED := 2.2
## The kerbside path along the pavement, and where they leave the scene.
const PATH_V := 5.6
const EXIT_U := -18.0
const SKIN := [Color("c68c62"), Color("a86f48"), Color("8a5a3a"), Color("d9a47a")]

var state := State.ARRIVING
var item_id := ""
var shout := ""
## Seconds of patience at the start, and what's left.
var patience_max := 90.0
var patience := 90.0
## Set during the tutorial: patience doesn't run down.
var patient := false
## Where they stand to order (tile coords); set by CustomerQueue.
var slot := Vector2.ZERO
## The drink is on the stove for them / ready in Sayed's hands.
var being_made := false
var drink_ready := false

var _look := Look.SHIRT
var _rng := RandomNumberGenerator.new()
var _pos := Vector2.ZERO
var _path: Array[Vector2] = []
var _t := 0.0
var _body := Node2D.new()
var _mesh: ArrayMesh
var _m: MeshCanvas
var _bar := Node2D.new()
var _bubble := PanelContainer.new()
var _bubble_label := Label.new()
var _area := Area2D.new()
var _mood := 0.0
## Colours are rolled once, so a redraw (the cross face) keeps the outfit.
var _skin := Color.WHITE
var _hair := Color.BLACK
var _cloth := Color.WHITE
var _extra := Color.WHITE
var _moustache := true


func setup(order_id: String, shout_text: String, patience_sec: float, stand_at: Vector2, from_u: float) -> void:
	item_id = order_id
	shout = shout_text
	patience_max = patience_sec
	patience = patience_sec
	slot = stand_at
	_pos = Vector2(from_u, PATH_V)
	_path = [Vector2(slot.x, PATH_V), slot]


func _ready() -> void:
	_rng.randomize()
	_look = (_rng.randi() % 4) as Look
	_skin = SKIN[_rng.randi() % SKIN.size()]
	_hair = [Color("1d1612"), Color("2a1f18"), Color("6a6560"), Color("3a2a1c")][_rng.randi() % 4]
	_moustache = _rng.randf() < 0.75
	match _look:
		Look.GALABEYA:
			_cloth = [Color("d8d2c2"), Color("8a8474"), Color("5a6a7a"), Color("b8a888")][_rng.randi() % 4]
		Look.HIJAB:
			_cloth = [Color("1f1d24"), Color("3a2a4a"), Color("2a3a4a"), Color("4a2a2a")][_rng.randi() % 4]
			_extra = [Color("c86a8a"), Color("e0c8a8"), Color("5a8aa8"), Color("8a6ab0"), Color("d8b060")][_rng.randi() % 5]
		Look.TSHIRT:
			_cloth = [Color("c8322b"), Color("2b2b30"), Color("e9e6df"), Color("3b8a5a")][_rng.randi() % 4]
		_:
			_cloth = [Color("2f5f8a"), Color("7a2e22"), Color("3d5a45"), Color("5a4a6a"), Color("8a6a3a"),
				Color("c9c2b0")][_rng.randi() % 6]
	add_child(_body)
	_body.draw.connect(_draw_body)
	add_child(_bar)
	_bar.position = Vector2(0, -212)
	_bar.draw.connect(_draw_bar)
	_bar.visible = false
	_build_bubble()
	# Tap target round the body.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 200)
	shape.shape = rect
	shape.position = Vector2(0, -95)
	_area.add_child(shape)
	_area.input_pickable = true
	_area.input_event.connect(_on_input)
	add_child(_area)
	_place()


func _build_bubble() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f6ecd6")
	style.border_color = Color("7a5a2e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.light_mask = 0
	_bubble_label.add_theme_font_size_override("font_size", 26)
	_bubble_label.add_theme_color_override("font_color", Color("3a2412"))
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.light_mask = 0
	_bubble.add_child(_bubble_label)
	_bubble.visible = false
	add_child(_bubble)


func _process(delta: float) -> void:
	_t += delta
	match state:
		State.ARRIVING:
			if _walk(delta):
				_arrive()
		State.WAITING:
			if not patient and not drink_ready:
				patience = maxf(patience - delta, 0.0)
				if patience <= 0.0:
					leave(true)
			# Fidget while waiting; more impatient, more fidgety.
			var urgency := 1.0 - patience / patience_max
			_body.position.y = -absf(sin(_t * (2.0 + 5.0 * urgency))) * (1.0 + 2.0 * urgency)
			_bar.queue_redraw()
		State.LEAVING:
			if _walk(delta):
				queue_free()


## Walks along the path; returns true when it's used up.
func _walk(delta: float) -> bool:
	if _path.is_empty():
		return true
	var target: Vector2 = _path[0]
	var step := WALK_SPEED * delta
	var to := target - _pos
	if to.length() <= step:
		_pos = target
		_path.remove_at(0)
	else:
		_pos += to.normalized() * step
		# Face the way they walk: screen x grows with u and shrinks with v.
		var sx := to.x - to.y
		if absf(sx) > 0.01:
			_body.scale.x = signf(sx)
	_body.position.y = -absf(sin(_t * 9.0)) * 5.0
	_body.rotation = sin(_t * 9.0) * 0.03
	_place()
	return _path.is_empty()


func _arrive() -> void:
	state = State.WAITING
	_body.rotation = 0.0
	_body.scale.x = 1.0
	_bar.visible = true
	_show_bubble(shout, 4.0)
	ordered.emit()


func _show_bubble(text: String, hold: float) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_bubble.reset_size()
	_bubble.position = Vector2(-_bubble.size.x * 0.5, -275 - _bubble.size.y * 0.5)
	var t := create_tween()
	t.tween_property(_bubble, "modulate:a", 1.0, 0.2)
	t.tween_interval(hold)
	t.tween_property(_bubble, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void: _bubble.visible = false)


## Served: a quick "thank you", then off down the pavement.
func serve() -> void:
	drink_ready = false
	_bar.visible = false
	_show_bubble(tr("CUST_THANKS_%d" % (_rng.randi() % 3 + 1)), 1.4)
	_mood = 1.0
	_mesh = null
	_body.queue_redraw()
	_leave_path()
	left.emit(false)


func leave(angry: bool) -> void:
	if state == State.LEAVING:
		return
	_bar.visible = false
	if angry:
		_mood = -1.0
		_mesh = null
		_body.queue_redraw()
		_show_bubble(tr("CUST_ANGRY_%d" % (_rng.randi() % 2 + 1)), 1.4)
	_leave_path()
	left.emit(angry)


func _leave_path() -> void:
	state = State.LEAVING
	_path = [Vector2(_pos.x, PATH_V), Vector2(EXIT_U, PATH_V)]


func is_waiting() -> bool:
	return state == State.WAITING


## Screen rect round the figure, for the tutorial's spotlight.
func screen_rect() -> Rect2:
	var p := get_global_transform() * Vector2.ZERO
	return Rect2(p + Vector2(-50, -215), Vector2(100, 225))


func _place() -> void:
	position = Vector2((_pos.x - _pos.y) * TILE_W * 0.5, (_pos.x + _pos.y) * TILE_H * 0.5 - PAVEMENT_RISE)


func _on_input(_viewport: Node, event: InputEvent, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		tapped.emit()


## Patience over the head: green → amber → red; a pot icon while the drink is
## on the stove and a tick once it's ready.
func _draw_bar() -> void:
	var f := patience / patience_max
	var w := 70.0
	_bar.draw_rect(Rect2(-w * 0.5 - 3, -8, w + 6, 16), Color(0.05, 0.04, 0.07, 0.8))
	var col := Color("4caf50").lerp(Color("e6c33a"), smoothstep(0.6, 0.35, f)).lerp(Color("e0452b"), smoothstep(0.3, 0.1, f))
	_bar.draw_rect(Rect2(-w * 0.5, -5, w * f, 10), col)
	if drink_ready:
		_bar.draw_circle(Vector2(w * 0.5 + 18, 0), 13, Color("4caf50"))
		_bar.draw_polyline(PackedVector2Array([Vector2(w * 0.5 + 12, 0), Vector2(w * 0.5 + 16, 5), Vector2(w * 0.5 + 24, -5)]),
			Color.WHITE, 3.0, true)
	elif being_made:
		_bar.draw_circle(Vector2(w * 0.5 + 18, 0), 13, Color("e0a458"))
		_bar.draw_rect(Rect2(w * 0.5 + 11, -3, 14, 9), Color("5a3620"))


func _draw_body() -> void:
	if _mesh == null:
		_m = MeshCanvas.new()
		_build_body()
		_mesh = _m.commit()
		_m = null
	if _mesh:
		_body.draw_mesh(_mesh, null)


## A chunky ~4-heads-tall figure seen three-quarters from the front, feet at
## the origin, about 180 px tall.
func _build_body() -> void:
	var skin := _skin
	var hair := _hair
	var cloth := _cloth
	_ellipse(Vector2(0, 0), Vector2(30, 10), Color(0, 0, 0, 0.28))
	match _look:
		Look.GALABEYA:
			_feet(Color("5a3a28"))
			_trap(-6, 26, 22, -126, 20, cloth)
			_m.line(Vector2(0, -122), Vector2(0, -92), cloth.darkened(0.25), 2.0)
			_arms(cloth, skin, 23.0)
			_head(skin, hair, _moustache)
			# White kufi cap.
			_ellipse(Vector2(0, -170), Vector2(21, 9), Color("f1ede4"))
			_m.colored_polygon(PackedVector2Array([Vector2(-21, -170), Vector2(21, -170), Vector2(18, -181), Vector2(-18, -181)]),
				Color("f1ede4"))
		Look.SHIRT:
			_legs(Color("2b2f3a"), Color("1a1a1e"))
			_trap(-62, 22, 21, -126, 20, cloth)
			_m.line(Vector2(0, -124), Vector2(0, -64), cloth.darkened(0.2), 1.5)
			_m.rect(Rect2(-22, -66, 44, 5), Color("3a2a1c"))
			_arms(cloth, skin, 22.0)
			_head(skin, hair, _moustache)
			_hair_short(hair)
		Look.HIJAB:
			_feet(Color("2a2020"))
			_trap(-4, 27, 21, -124, 20, cloth)
			_arms(cloth, skin, 22.0)
			# Scarf round the head and down over the shoulders, face showing.
			_m.colored_polygon(PackedVector2Array([Vector2(-26, -118), Vector2(26, -118), Vector2(30, -136), Vector2(-30, -136)]),
				_extra.darkened(0.08))
			_ellipse(Vector2(0, -155), Vector2(27, 29), _extra)
			_ellipse(Vector2(0, -150), Vector2(16, 19), skin)
			_face(Vector2(0, -150), false)
		Look.TSHIRT:
			_legs(Color("2f4a7a"), Color("e9e6df"))
			_trap(-64, 21, 20, -124, 20, cloth)
			_arms(cloth, skin, 21.0, true)
			_head(skin, hair, false)
			_hair_short(hair)


## A shape wider or narrower at the bottom: hem y0 half-width w0, top y1 w1.
func _trap(y0: float, w0: float, w1: float, y1: float, round_top: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(-w0, y0), Vector2(w0, y0)])
	for i in 7:
		var a := PI * i / 6.0
		pts.append(Vector2(cos(a) * w1, y1 + round_top * 0.5 - sin(a) * round_top * 0.5))
	_m.colored_polygon(pts, color)
	# Shade the far side to give it some roundness.
	_m.colored_polygon(PackedVector2Array([Vector2(w0 * 0.35, y0), Vector2(w0, y0), Vector2(w1, y1 + round_top * 0.5),
		Vector2(w1 * 0.4, y1)]), Color(0, 0, 0, 0.12))


func _feet(color: Color) -> void:
	for x in [-10.0, 10.0]:
		_ellipse(Vector2(x, -3), Vector2(9, 5), color)


func _legs(trousers: Color, shoes: Color) -> void:
	for x in [-10.0, 10.0]:
		_m.colored_polygon(PackedVector2Array([Vector2(x - 8, -4), Vector2(x + 8, -4), Vector2(x + 9, -66), Vector2(x - 9, -66)]),
			trousers)
		_ellipse(Vector2(x, -3), Vector2(10, 5), shoes)
	_m.line(Vector2(0, -60), Vector2(0, -20), trousers.darkened(0.3), 1.5)


func _arms(sleeve: Color, skin: Color, shoulder: float, short := false) -> void:
	for side in [-1.0, 1.0]:
		var top := Vector2(side * shoulder, -116)
		var elbow := Vector2(side * (shoulder + 5), -88)
		var hand := Vector2(side * (shoulder + 4), -64)
		_m.line(top, elbow, sleeve.darkened(0.05 if side < 0 else 0.15), 11.0)
		_m.line(elbow, hand, skin if short else sleeve.darkened(0.05 if side < 0 else 0.15), 10.0)
		_m.circle(hand, 6.5, skin)


func _head(skin: Color, hair: Color, moustache: bool) -> void:
	_m.rect(Rect2(-6, -134, 12, 10), skin.darkened(0.1))
	_ellipse(Vector2(0, -154), Vector2(21, 24), skin)
	for side in [-1.0, 1.0]:
		_ellipse(Vector2(side * 21, -152), Vector2(4, 6), skin.darkened(0.1))
	_face(Vector2(0, -154), moustache, hair)


func _face(c: Vector2, moustache: bool, hair := Color("1d1612")) -> void:
	var mood_y := -2.0 * _mood
	for side in [-1.0, 1.0]:
		_m.circle(c + Vector2(side * 8, -3), 2.6, Color("1d1612"))
		# Brows tilt down to the middle when they're cross.
		_m.line(c + Vector2(side * 4, -9 + (3.0 if _mood < 0 else 0.0)), c + Vector2(side * 13, -10), hair, 2.5)
	if moustache:
		_m.colored_polygon(PackedVector2Array([c + Vector2(-9, 7), c + Vector2(0, 5), c + Vector2(9, 7), c + Vector2(7, 10),
			c + Vector2(-7, 10)]), hair)
	_m.polyline(PackedVector2Array([c + Vector2(-5, 13 - mood_y * 0.5), c + Vector2(0, 13 + mood_y), c + Vector2(5, 13 - mood_y * 0.5)]),
		Color("6a2e22"), 2.0)


func _hair_short(hair: Color) -> void:
	_m.colored_polygon(PackedVector2Array([Vector2(-21, -158), Vector2(-20, -170), Vector2(-12, -178), Vector2(0, -180),
		Vector2(12, -178), Vector2(20, -170), Vector2(21, -158), Vector2(14, -168), Vector2(-14, -168)]), hair)


func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_m.colored_polygon(pts, color)
