class_name PickCard
extends Control
## One tappable card on the prep station's pick tray: a paper-label card with
## the item's icon and name. Pops when pressed, gets a green tick and border
## when it was the right pick, flashes red and shakes when it wasn't.

signal pressed(id: String)

const PAPER := Color("f6ecd6")
const EDGE := Color("7a5a2e")
const RIGHT := Color("4caf50")
const WRONG := Color("e0452b")

var id := ""
var picked := false
## A count shown in a bubble on the corner (spoons of sugar so far); -1 hides it.
var badge := -1

var _label := Label.new()
var _shake := 0.0
var _flash := 0.0


func setup(item_id: String, title: String) -> void:
	id = item_id
	_label.text = title


func _ready() -> void:
	custom_minimum_size = Vector2(172, 226)
	mouse_filter = MOUSE_FILTER_STOP
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color("3a2412"))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_label.offset_top = -58
	_label.offset_bottom = -8
	add_child(_label)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if picked:
			return
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
		t.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pressed.emit(id)


func mark_right() -> void:
	picked = true
	queue_redraw()


func mark_wrong() -> void:
	var t := create_tween()
	t.tween_method(_set_flash, 1.0, 0.0, 0.5)
	t.parallel().tween_method(_set_shake, 1.0, 0.0, 0.4)


func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()


func _set_shake(v: float) -> void:
	_shake = sin(v * 28.0) * 9.0 * v
	queue_redraw()


func _draw() -> void:
	if size.x < 60.0 or size.y < 160.0:
		return
	draw_set_transform(Vector2(_shake, 0))
	var r := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(PrepIcons._rrect(Rect2(r.position + Vector2(0, 7), r.size), 22), Color(0, 0, 0, 0.35))
	var edge := RIGHT if picked else EDGE.lerp(WRONG, _flash)
	draw_colored_polygon(PrepIcons._rrect(r, 22), edge)
	var inner := r.grow(-5 if picked else -4)
	draw_colored_polygon(PrepIcons._rrect(inner, 18), PAPER.lerp(Color("ffd6cc"), _flash * 0.8))
	# Soft band behind the icon, and a stitched line above the name.
	draw_colored_polygon(PrepIcons._rrect(Rect2(inner.position + Vector2(10, 10), Vector2(inner.size.x - 20, 138)), 14),
		Color("ecdcb8"))
	for k in 14:
		var x := inner.position.x + 14 + k * (inner.size.x - 28) / 13.0
		draw_line(Vector2(x, inner.end.y - 60), Vector2(x + 5, inner.end.y - 60), Color(EDGE, 0.35), 2.0)
	PrepIcons.draw_icon(self, id, Rect2(inner.position + Vector2(14, 12), Vector2(inner.size.x - 28, 134)))
	if badge >= 0:
		var bc := Vector2(26, 26)
		draw_circle(bc, 22, Color("7a5a2e"))
		draw_circle(bc, 19, Color("e0a458"))
		var text := GameData.ar_digits(badge)
		var font := get_theme_default_font()
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(font, bc + Vector2(-sz.x * 0.5, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("3a2412"))
	if picked:
		var c := Vector2(r.end.x - 24, 24)
		draw_circle(c, 22, Color("1f5a24"))
		draw_circle(c, 19, RIGHT)
		draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-3, 7), c + Vector2(10, -7)]), Color.WHITE, 4.5, true)
	draw_set_transform(Vector2.ZERO)
