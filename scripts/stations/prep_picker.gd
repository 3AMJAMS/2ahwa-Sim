class_name PrepPicker
extends Control
## The tray of pick cards that slides up at the bottom of the prep station:
## first the ingredients the order needs, then the tool to make it with.
## Right picks get a tick; the step is done once every needed item is picked.
## Wrong picks shake and report through wrong_pick (PrepStation docks tips).

signal step_done
## A right card was just picked (the tutorial steps through them one by one).
signal picked_right
signal wrong_pick(id: String)

## True once the current step's picks are all in (step_done has fired).
var step_complete := true

var _required: Array = []
var _picked: Array = []
var _cards: Array[PickCard] = []
var _base_title := ""
var _busy := false
var _repeat_left := 0
var _repeat_total := 0
var _repeat_each: Callable

var _title := Label.new()
var _row := HBoxContainer.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_top = 22
	box.offset_bottom = -26
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(1, 0.784, 0.38))
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	_title.add_theme_constant_override("outline_size", 10)
	box.add_child(_title)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 14)
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(_row)
	visible = false


## Lays out a fresh set of cards and slides the tray up if it was hidden.
func show_step(title: String, options: Array, required: Array) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_required = required.duplicate()
	_picked.clear()
	_repeat_left = 0
	_busy = false
	step_complete = false
	_base_title = title
	_update_title()
	for option in options:
		var card := PickCard.new()
		card.setup(option.id, tr(option.name_key))
		card.pressed.connect(_on_card)
		_row.add_child(card)
		_cards.append(card)
	if not visible:
		visible = true
		modulate.a = 0.0
		var t := create_tween()
		t.tween_property(self, "modulate:a", 1.0, 0.25)


## One card tapped `count` times (dropping ice cubes, say); `each` is called
## per tap and step_done fires after the last.
func show_repeat(title: String, option: Dictionary, count: int, each: Callable) -> void:
	show_step(title, [option], [])
	_repeat_left = count
	_repeat_total = count
	_repeat_each = each
	_base_title = title
	_title.text = "%s (%s/%s)" % [title, GameData.ar_digits(0), GameData.ar_digits(count)]


func hide_now() -> void:
	visible = false
	step_complete = true
	for card in _cards:
		card.queue_free()
	_cards.clear()


## Fades the tray out and away.
func slide_away() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	await t.finished
	hide_now()


## Where a card sits on screen, for the tutorial's spotlight.
func card_rect(item_id: String) -> Rect2:
	for card in _cards:
		if card.id == item_id:
			return card.get_global_rect()
	return Rect2()


func _on_card(item_id: String) -> void:
	if _busy or step_complete:
		return
	if _repeat_left > 0:
		_repeat_left -= 1
		_repeat_each.call()
		picked_right.emit()
		var done := _repeat_total - _repeat_left
		_title.text = "%s (%s/%s)" % [_base_title, GameData.ar_digits(done), GameData.ar_digits(_repeat_total)]
		if _repeat_left == 0:
			for card in _cards:
				card.mark_right()
			_busy = true
			await get_tree().create_timer(0.5).timeout
			step_complete = true
			step_done.emit()
		return
	if item_id in _required and not item_id in _picked:
		_picked.append(item_id)
		for card in _cards:
			if card.id == item_id:
				card.mark_right()
		_update_title()
		picked_right.emit()
		if _picked.size() >= _required.size():
			_busy = true
			await get_tree().create_timer(0.35).timeout
			step_complete = true
			step_done.emit()
	else:
		for card in _cards:
			if card.id == item_id:
				card.mark_wrong()
		_title.text = tr("PREP_WRONG_PICK")
		wrong_pick.emit(item_id)
		get_tree().create_timer(0.9).timeout.connect(_update_title)


func _update_title() -> void:
	if _required.size() > 1:
		_title.text = "%s (%s/%s)" % [_base_title, GameData.ar_digits(_picked.size()), GameData.ar_digits(_required.size())]
	else:
		_title.text = _base_title


## A dark tray with a warm lip along the top.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([Color(0.1, 0.07, 0.1, 0.82), Color(0.1, 0.07, 0.1, 0.82), Color(0.05, 0.04, 0.07, 0.95),
			Color(0.05, 0.04, 0.07, 0.95)]))
	draw_rect(Rect2(0, 0, size.x, 5), Color("e0a458"))
	draw_rect(Rect2(0, 5, size.x, 3), Color(0, 0, 0, 0.4))
	for x in [18.0, size.x - 18.0]:
		draw_circle(Vector2(x, 20), 4, Color("c9ced6"))
