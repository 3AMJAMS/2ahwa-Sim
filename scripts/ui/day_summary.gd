class_name DaySummary
extends Control
## The end of the shift: packing up at dawn, not a game over. A pre-dawn sky
## over the Cairo rooftops (the last stars going, the moon low, a warm glow
## coming up), and Sayed's day written up like a café receipt: orders served,
## customers lost, the takings counting up, then a red "خالص" stamp. Sayed
## says a word, and "يوم جديد" carries on when the player's ready.

signal continued

const PAPER := Color("f6ecd6")
const INK := Color("3a2412")
const INK_SOFT := Color("7a5a3a")
const GOOD := Color("2e7d32")
const STAMP := Color("c23b2a")

var _font: Font = preload("res://assets/ui/main_theme.tres").default_font
var _stats := {}
var _t := 0.0
var _card_in := 0.0
var _count := 0.0
var _stamp := 0.0
var _button := Button.new()
var _portrait := SayedPortrait.new()
var _line := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_button.text = tr("UI_SUMMARY_NEXT")
	_button.add_theme_font_size_override("font_size", 44)
	_button.custom_minimum_size = Vector2(420, 120)
	_button.focus_mode = FOCUS_NONE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f2c230")
	box.border_color = Color("7a5a2e")
	box.set_border_width_all(4)
	box.set_corner_radius_all(26)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 6)
	var pressed := box.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("e0a458")
	for state in ["normal", "hover", "focus"]:
		_button.add_theme_stylebox_override(state, box)
	_button.add_theme_stylebox_override("pressed", pressed)
	_button.add_theme_color_override("font_color", INK)
	_button.add_theme_color_override("font_hover_color", INK)
	_button.add_theme_color_override("font_pressed_color", INK)
	_button.pressed.connect(func() -> void: continued.emit())
	add_child(_button)
	add_child(_portrait)
	resized.connect(_layout)


## Shows the day's receipt; returns when the player taps "يوم جديد".
## stats: {day, amount, served, failed, closed}
func show_day(stats: Dictionary) -> void:
	_stats = stats
	_line = _sayed_line()
	visible = true
	modulate.a = 0.0
	_card_in = 0.0
	_count = 0.0
	_stamp = 0.0
	_button.modulate.a = 0.0
	_layout()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.6)
	t.tween_property(self, "_card_in", 1.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_count", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_stamp", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: Input.vibrate_handheld(30))
	t.tween_property(_button, "modulate:a", 1.0, 0.3)
	await continued


func hide_now() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_layout()
		queue_redraw()


func _card_rect() -> Rect2:
	var w := minf(size.x - 120.0, 780.0)
	var h := 720.0
	var y := size.y * 0.3 + (1.0 - _card_in) * size.y * 0.6
	return Rect2((size.x - w) * 0.5, y, w, h)


func _layout() -> void:
	var card := _card_rect()
	_button.position = Vector2((size.x - _button.size.x) * 0.5, card.end.y + 70.0)
	_portrait.size = Vector2(170, 170)
	_portrait.position = Vector2(card.end.x - 130.0, card.position.y - 110.0)


func _sayed_line() -> String:
	var served: int = _stats.get("served", 0)
	var failed: int = _stats.get("failed", 0)
	var key := "UI_SUMMARY_LINE_GOOD"
	if served == 0:
		key = "UI_SUMMARY_LINE_QUIET"
	elif failed == 0:
		key = "UI_SUMMARY_LINE_PERFECT"
	var line := tr(key)
	if _stats.get("closed", false):
		line = tr("UI_SUMMARY_CLOSED") + " " + line
	return line


func _draw() -> void:
	_draw_dawn()
	_draw_card()


## Pre-dawn: deep blue overhead warming to peach at the horizon, the last
## stars, a low moon, rooftops with water tanks and a few lit windows.
func _draw_dawn() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.78
	var top := Color("1d2552")
	var mid := Color("6a4a86")
	var low := Color("f0a070")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon * 0.6), Vector2(0, horizon * 0.6)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, horizon * 0.6), Vector2(w, horizon * 0.6), Vector2(w, horizon), Vector2(0, horizon)]),
		PackedColorArray([mid, mid, low, low]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 60:
		var p := Vector2(rng.randf() * w, rng.randf() * horizon * 0.55)
		var tw := 0.5 + 0.5 * sin(_t * rng.randf_range(1.0, 2.5) + k)
		draw_circle(p, rng.randf_range(1.0, 2.2), Color(1, 1, 1, (0.25 + 0.5 * tw) * (1.0 - p.y / (horizon * 0.55))))
	# Low crescent moon.
	var moon := Vector2(w * 0.2, h * 0.16)
	draw_circle(moon, 46, Color(1, 0.95, 0.85, 0.12))
	draw_circle(moon, 30, Color("f4ecd6"))
	draw_circle(moon + Vector2(12, -6), 28, top.lerp(mid, 0.25))
	# Warm glow on the horizon.
	draw_polygon(PackedVector2Array([Vector2(0, horizon - 160), Vector2(w, horizon - 160), Vector2(w, horizon), Vector2(0, horizon)]),
		PackedColorArray([Color(1, 0.7, 0.45, 0), Color(1, 0.7, 0.45, 0), Color(1, 0.75, 0.5, 0.45), Color(1, 0.75, 0.5, 0.45)]))
	# Rooftops.
	var x := -20.0
	rng.seed = 9
	while x < w:
		var bw := rng.randf_range(110, 220)
		var bh := rng.randf_range(120, 300)
		var col := Color("2e2640")
		draw_rect(Rect2(x, horizon - bh, bw, h - horizon + bh), col)
		if rng.randf() < 0.6:
			draw_rect(Rect2(x + bw * 0.55, horizon - bh - 34, 40, 34), col)
			draw_rect(Rect2(x + bw * 0.55 + 16, horizon - bh - 44, 8, 10), col)
		if rng.randf() < 0.5:
			draw_circle(Vector2(x + bw * 0.25, horizon - bh - 10), 13, col)
		for r in int(bh / 60.0):
			for c in int(bw / 50.0):
				if rng.randf() < 0.12:
					draw_rect(Rect2(x + 14 + c * 50, horizon - bh + 22 + r * 60, 22, 28), Color("ffd27a").darkened(0.1))
		x += bw + rng.randf_range(2, 10)
	draw_rect(Rect2(0, horizon, w, h - horizon), Color("2a2036"))


## The receipt: torn top and bottom, title, dotted rows, takings, stamp,
## and Sayed's line.
func _draw_card() -> void:
	var r := _card_rect()
	var paper := PackedVector2Array()
	var teeth := 16
	for i in teeth + 1:
		paper.append(Vector2(r.position.x + r.size.x * i / teeth, r.position.y + (0.0 if i % 2 == 0 else 10.0)))
	for i in range(teeth, -1, -1):
		paper.append(Vector2(r.position.x + r.size.x * i / teeth, r.end.y - (0.0 if i % 2 == 0 else 10.0)))
	draw_colored_polygon(PointerHand._offset(paper, Vector2(0, 14)), Color(0, 0, 0, 0.35))
	draw_colored_polygon(paper, PAPER)
	var pad := 50.0
	var x0 := r.position.x + pad
	var width := r.size.x - pad * 2.0
	var y := r.position.y + 90.0
	var day := GameData.ar_digits(int(_stats.get("day", 1)))
	draw_string(_font, Vector2(x0, y), tr("UI_SUMMARY_TITLE").format({"day": day}), HORIZONTAL_ALIGNMENT_RIGHT, width, 54, INK)
	y += 34.0
	_dots(x0, width, y)
	y += 70.0
	var served := roundi(float(_stats.get("served", 0)) * _count)
	var failed := roundi(float(_stats.get("failed", 0)) * _count)
	var amount := roundi(float(_stats.get("amount", 0)) * _count)
	_row(x0, width, y, tr("UI_SUMMARY_SERVED"), GameData.ar_digits(served), INK)
	y += 64.0
	_row(x0, width, y, tr("UI_SUMMARY_LOST"), GameData.ar_digits(failed), INK_SOFT)
	y += 40.0
	_dots(x0, width, y)
	y += 80.0
	draw_string(_font, Vector2(x0, y), tr("UI_SUMMARY_TIPS"), HORIZONTAL_ALIGNMENT_RIGHT, width, 46, INK)
	draw_string(_font, Vector2(x0, y), "%s %s" % [GameData.ar_digits(amount), tr("UI_CURRENCY")], HORIZONTAL_ALIGNMENT_LEFT,
		width, 56, GOOD)
	y += 70.0
	_dots(x0, width, y)
	y += 64.0
	# Sayed's word on the right, the stamp beside it on the left.
	draw_multiline_string(_font, Vector2(x0 + width * 0.36, y), _line, HORIZONTAL_ALIGNMENT_RIGHT, width * 0.64, 32, 4, INK_SOFT)
	# The stamp, slammed on at an angle.
	if _stamp > 0.0:
		var c := Vector2(r.position.x + 150.0, r.end.y - 110.0)
		var k := lerpf(1.8, 1.0, _stamp)
		draw_set_transform(c, -0.25, Vector2(k, k))
		var col := Color(STAMP, 0.85 * _stamp)
		var box := PrepIcons._rrect(Rect2(-110, -48, 220, 96), 14)
		box.append(box[0])
		draw_polyline(box, col, 6.0, true)
		var inner := PrepIcons._rrect(Rect2(-98, -36, 196, 72), 10)
		inner.append(inner[0])
		draw_polyline(inner, col, 2.0, true)
		draw_string(_font, Vector2(-110, 18), tr("UI_SUMMARY_STAMP"), HORIZONTAL_ALIGNMENT_CENTER, 220, 52, col)
		draw_set_transform(Vector2.ZERO)


func _row(x0: float, width: float, y: float, label: String, value: String, col: Color) -> void:
	draw_string(_font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_RIGHT, width, 38, col)
	draw_string(_font, Vector2(x0, y), value, HORIZONTAL_ALIGNMENT_LEFT, width, 44, col)


func _dots(x0: float, width: float, y: float) -> void:
	var n := int(width / 18.0)
	for i in n:
		draw_circle(Vector2(x0 + i * 18.0 + 4.0, y), 2.5, Color(INK_SOFT, 0.5))
