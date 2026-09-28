class_name CoachOverlay
extends Control
## The tutorial's on-screen layer: dims the screen round a spotlight on the
## thing being explained, points at it with a hand, and shows Sayed's speech
## bubble. On "tap to continue" steps it swallows every tap and reports it;
## on "do it" steps taps inside the spotlight fall through to the game.

signal tapped
signal skip_pressed

const DIM_SHADER := preload("res://shaders/coach_dim.gdshader")
const PAPER := Color("f6ecd6")
const INK := Color("3a2412")
## Ignore taps this soon after a step appears, so a double tap can't skip it.
const TAP_GRACE := 0.35

var _dim := ColorRect.new()
var _ring := Control.new()
var _hand := PointerHand.new()
var _bubble := PanelContainer.new()
var _text := Label.new()
var _hint := Label.new()
var _skip := Button.new()
var _hole := Rect2()
var _passthrough := false
var _shown_at := 0.0
var _t := 0.0
## Spotlight slide between two steps' targets.
var _anim_from := Rect2()
var _anim_to := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var mat := ShaderMaterial.new()
	mat.shader = DIM_SHADER
	_dim.material = mat
	_dim.mouse_filter = MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_dim)
	_ring.mouse_filter = MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	add_child(_hand)
	_build_bubble()
	resized.connect(_update_dim)
	visible = false


func _build_bubble() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("7a5a2e")
	style.set_border_width_all(5)
	style.set_corner_radius_all(30)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble.add_child(row)
	var portrait := SayedPortrait.new()
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(head)
	var name_label := Label.new()
	name_label.text = tr("TUT_SAYED")
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color("b8561e"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	_skip.text = tr("TUT_SKIP")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 26)
	_skip.add_theme_color_override("font_color", Color("8a6a4a"))
	_skip.add_theme_color_override("font_hover_color", Color("5a3a1e"))
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	head.add_child(_skip)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 36)
	_text.add_theme_color_override("font_color", INK)
	_text.custom_minimum_size = Vector2(300, 0)
	col.add_child(_text)
	_hint.text = tr("TUT_TAP_CONTINUE")
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color("8a6a4a"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_hint)


func open() -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(func() -> void: visible = false)


## Shows one line from Sayed. `target` is the screen rect to spotlight (empty
## for none); `passthrough` lets taps inside it reach the game.
func show_step(text: String, target: Rect2, passthrough: bool) -> void:
	_text.text = text
	_passthrough = passthrough
	_hint.visible = not passthrough
	_shown_at = _t
	var from := _hole
	var to := target.grow(14) if target.has_area() else Rect2()
	if from.has_area() and to.has_area():
		_anim_from = from
		_anim_to = to
		create_tween().tween_method(_set_hole, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_set_hole_rect(to)
	_place_bubble(to)
	_place_hand(to)



func _set_hole(t: float) -> void:
	_set_hole_rect(Rect2(_anim_from.position.lerp(_anim_to.position, t), _anim_from.size.lerp(_anim_to.size, t)))


func _set_hole_rect(r: Rect2) -> void:
	_hole = r
	_update_dim()
	_ring.queue_redraw()


func _update_dim() -> void:
	var mat := _dim.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("hole", Vector4(_hole.position.x, _hole.position.y, _hole.size.x, _hole.size.y))
	mat.set_shader_parameter("dim", 0.62 if _hole.has_area() else 0.45)


## Keep the bubble clear of the spotlight: at the top if the target is low.
func _place_bubble(target: Rect2) -> void:
	var w := minf(size.x - 60.0, 980.0)
	_bubble.modulate.a = 0.0
	# Two passes: the wrapped text's height is only known once it has the width.
	for pass_ in 2:
		_bubble.size = Vector2(w, 0)
		await get_tree().process_frame
	var h := _bubble.size.y
	# No target: sit low, clear of the order and results at the top.
	var y := size.y - h - 170.0
	if target.has_area():
		y = 150.0 if target.get_center().y > size.y * 0.5 else size.y - h - 170.0
		# Still overlapping (a tall target)? Park it in whichever gap is bigger.
		if Rect2(0, y, size.x, h).intersects(target):
			y = maxf(40.0, target.position.y - h - 40.0) if target.position.y > size.y - target.end.y \
				else minf(size.y - h - 40.0, target.end.y + 40.0)
	var end := Vector2((size.x - w) * 0.5, y)
	_bubble.position = end + Vector2(0, 24)
	var t := create_tween().set_parallel()
	t.tween_property(_bubble, "position", end, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_bubble, "modulate:a", 1.0, 0.18)


## The hand sits under the target pointing up, or over it pointing down when
## the target is near the bottom of the screen.
func _place_hand(target: Rect2) -> void:
	_hand.visible = target.has_area()
	if not _hand.visible:
		return
	var below_room := size.y - target.end.y
	if below_room > 200.0:
		_hand.position = Vector2(target.get_center().x + 20.0, target.end.y - 18.0)
		_hand.rotation = -0.35
	else:
		_hand.position = Vector2(target.get_center().x - 20.0, target.position.y + 18.0)
		_hand.rotation = PI - 0.35


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_ring.modulate.a = 0.55 + 0.45 * sin(_t * 5.0)
		_hint.modulate.a = 0.7 + 0.3 * sin(_t * 3.0)


func _draw_ring() -> void:
	if not _hole.has_area():
		return
	for ring in [[0.0, 26.0, 5.0, 1.0], [9.0, 32.0, 3.0, 0.35]]:
		var pts := PrepIcons._rrect(_hole.grow(ring[0]), ring[1])
		pts.append(pts[0])
		_ring.draw_polyline(pts, Color(1.0, 0.82, 0.4, ring[3]), ring[2], true)


## Taps inside the spotlight reach the game on "do it" steps.
func _has_point(point: Vector2) -> bool:
	if _passthrough and _hole.has_point(point):
		return false
	return Rect2(Vector2.ZERO, size).has_point(point)


func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if press or event.is_action_pressed("ui_accept"):
		accept_event()
		if not _passthrough and _t - _shown_at >= TAP_GRACE:
			tapped.emit()
		elif _passthrough:
			# Nudge: bounce the hand toward the spotlight.
			var t := create_tween()
			t.tween_property(_hand, "scale", Vector2(1.5, 1.5), 0.1)
			t.tween_property(_hand, "scale", Vector2(1.25, 1.25), 0.15)
