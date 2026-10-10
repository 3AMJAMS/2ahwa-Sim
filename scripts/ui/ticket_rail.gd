class_name TicketRail
extends HBoxContainer
## The order tickets clipped along the top of the street view: one per
## waiting customer, with the drink, a patience bar and its state (waiting,
## on the stove, ready to hand over). Tapping a ticket makes that order.

signal ticket_pressed(customer: Customer)

var _tickets := {}   # Customer -> Ticket


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	mouse_filter = MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_RTL


func add_order(c: Customer) -> void:
	if _tickets.has(c):
		return
	var t := Ticket.new()
	t.customer = c
	t.pressed.connect(func() -> void: ticket_pressed.emit(c))
	add_child(t)
	_tickets[c] = t
	t.pop_in()


func remove_order(c: Customer) -> void:
	if not _tickets.has(c):
		return
	var t: Ticket = _tickets[c]
	_tickets.erase(c)
	t.tear_off()


func ticket_rect(c: Customer) -> Rect2:
	return (_tickets[c] as Control).get_global_rect() if _tickets.has(c) else Rect2()


func clear() -> void:
	for c in _tickets.keys():
		remove_order(c)


## One paper ticket.
class Ticket extends Control:
	signal pressed

	var customer: Customer
	var _t := 0.0
	var _name := Label.new()
	var _sugar := Label.new()

	func _ready() -> void:
		custom_minimum_size = Vector2(176, 150)
		mouse_filter = MOUSE_FILTER_STOP
		pivot_offset = Vector2(88, 0)
		var item := GameData.get_menu_item(customer.item_id)
		_name.text = tr(item.get("name_key", customer.item_id))
		_name.add_theme_font_size_override("font_size", 24 if _name.text.length() <= 10 else 19)
		_name.add_theme_color_override("font_color", Color("3a2412"))
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.mouse_filter = MOUSE_FILTER_IGNORE
		_name.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
		_name.offset_top = 70
		_name.offset_bottom = 100
		add_child(_name)
		# The sugar grade, written under the drink like on a real order pad.
		_sugar.text = GameData.sugar_name(customer.sugar)
		_sugar.add_theme_font_size_override("font_size", 22)
		_sugar.add_theme_color_override("font_color", Color("9c3d16"))
		_sugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sugar.mouse_filter = MOUSE_FILTER_IGNORE
		_sugar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
		_sugar.offset_top = 96
		_sugar.offset_bottom = 122
		add_child(_sugar)

	func pop_in() -> void:
		scale = Vector2(1, 0)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func tear_off() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.25)
		t.parallel().tween_property(self, "position:y", position.y - 40.0, 0.25)
		t.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		if not is_instance_valid(customer):
			return
		var w := size.x
		var h := size.y
		# Clip at the top, paper body with a torn bottom edge.
		var paper := PackedVector2Array([Vector2(0, 10), Vector2(w, 10)])
		for i in 12:
			var x := w - w * (i + 0.5) / 11.0
			paper.append(Vector2(clampf(x, 0, w), h - (6.0 if i % 2 == 0 else 0.0)))
		draw_colored_polygon(PointerHand._offset(paper, Vector2(0, 5)), Color(0, 0, 0, 0.3))
		var f := customer.patience / customer.patience_max
		var tint := Color("f6ecd6")
		if customer.drink_ready:
			tint = Color("e2f2d6")
		elif f < 0.25:
			tint = tint.lerp(Color("ffd0c4"), 0.5 + 0.5 * sin(_t * 8.0))
		draw_colored_polygon(paper, tint)
		draw_rect(Rect2(w * 0.5 - 22, 0, 44, 18), Color("b3b9c2"))
		draw_rect(Rect2(w * 0.5 - 22, 0, 44, 5), Color("e6e9ee"))
		var item := GameData.get_menu_item(customer.item_id)
		var needs: Array = item.get("ingredients", [])
		var icon: String = needs[0] if not needs.is_empty() else "tea"
		var spot := Rect2(w * 0.5 - 27, 18, 54, 54)
		var tex := PrepIcons.baked(icon, 108)
		if tex:
			draw_texture_rect(tex, spot, false)
		else:
			PrepIcons.draw_icon(self, icon, spot)
		# Patience bar, or the state once it's being made / ready.
		var bar := Rect2(14, h - 26, w - 28, 10)
		draw_rect(bar, Color(0, 0, 0, 0.15))
		var col := Color("4caf50").lerp(Color("e6c33a"), smoothstep(0.6, 0.35, f)).lerp(Color("e0452b"), smoothstep(0.3, 0.1, f))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), col)
		if customer.drink_ready:
			draw_circle(Vector2(w - 22, 30), 14, Color("4caf50"))
			draw_polyline(PackedVector2Array([Vector2(w - 29, 30), Vector2(w - 24, 36), Vector2(w - 14, 24)]), Color.WHITE, 3.0, true)
		elif customer.being_made:
			draw_circle(Vector2(w - 22, 30), 14, Color("e0a458"))
