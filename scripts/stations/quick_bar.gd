class_name QuickBar
extends Control
## The ingredient dock along the bottom of the prep station: one slot per
## ingredient, always in the same order (sugar, tea, tea bags, coffee,
## karkade, mango, ice), so the thumb learns where each lives. Tapping a
## slot adds that ingredient now; PrepStation decides whether it was the
## right moment. Slots can show a count (spoons of sugar), flash green or
## red, and pulse when Sayed hints at what's next.
##
## The dock, the cards and their icons are hundreds of little polygons, so
## they're painted once into a texture (again only when the slots change)
## and the bar just shows it, with the live highlights drawn on top.

signal slot_pressed(id: String)

const ORDER := ["sugar", "tea", "teabag", "coffee", "karkade", "mango", "ice"]
const NAMES := {"sugar": "ING_SUGAR_SHORT", "tea": "ING_TEA", "teabag": "ING_TEABAG", "coffee": "ING_COFFEE",
	"karkade": "ING_KARKADE", "mango": "ING_MANGO", "ice": "ING_ICE"}
const WOOD := Color("7a4e2c")
const WOOD_DARK := Color("4a2e1a")
const PAPER := Color("f6ecd6")
const EDGE := Color("7a5a2e")
const RIGHT := Color("4caf50")
const WRONG := Color("e0452b")
const HINT := Color("ffd27a")

var _ids: Array[String] = []
var _badges := {}
var _flash := {}
var _flash_col := {}
var _pulse := ""
var _pressed := ""
var _t := 0.0
var _font: Font = preload("res://assets/ui/main_theme.tres").default_font
var _cache := SubViewport.new()
## A plain Node2D: a Control here would be mirrored by the Arabic layout.
var _painter := Node2D.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_cache.disable_3d = true
	_cache.transparent_bg = true
	_cache.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_cache)
	_painter.draw.connect(_paint)
	_cache.add_child(_painter)
	resized.connect(_repaint)
	visibility_changed.connect(_repaint)


## Paints the dock into the cache at the screen's real pixel size.
func _repaint() -> void:
	if not is_inside_tree() or size.x < 2.0 or size.y < 2.0:
		return
	var k := clampf(float(get_window().size.x) / get_viewport_rect().size.x, 0.25, 3.0)
	_cache.size = Vector2i(ceili(size.x * k), ceili(size.y * k))
	_cache.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(k, k))
	_painter.queue_redraw()
	_cache.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()


## The slots to show (in the fixed order), badges cleared.
func set_slots(ids: Array) -> void:
	_ids.clear()
	for id in ORDER:
		if id in ids:
			_ids.append(id)
	_badges.clear()
	_flash.clear()
	_pulse = ""
	_repaint()


func set_badge(id: String, n: int) -> void:
	if n <= 0:
		_badges.erase(id)
	else:
		_badges[id] = n
	queue_redraw()


func flash(id: String, right: bool) -> void:
	_flash[id] = 1.0
	_flash_col[id] = RIGHT if right else WRONG


## Pulses a slot to show what's next ("" stops).
func pulse(id: String) -> void:
	_pulse = id
	queue_redraw()


func slot_rect(id: String) -> Rect2:
	var i := _ids.find(id)
	if i < 0:
		return Rect2()
	return _rect(i)


func has_slot(id: String) -> bool:
	return id in _ids


func _rect(i: int) -> Rect2:
	var n := maxi(_ids.size(), 1)
	var pad := 14.0
	var w := minf((size.x - pad * 2.0) / n, 190.0)
	var total := w * n
	var x0 := (size.x - total) * 0.5
	return Rect2(Vector2(x0 + w * i + 5.0, 30.0), Vector2(w - 10.0, size.y - 52.0))


func _process(delta: float) -> void:
	_t += delta
	var dirty := _pulse != ""
	for id in _flash.keys():
		_flash[id] = maxf(float(_flash[id]) - delta * 2.2, 0.0)
		dirty = true
		if _flash[id] <= 0.0:
			_flash.erase(id)
	if dirty:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := ""
		for i in _ids.size():
			if _rect(i).grow(4).has_point(event.position):
				hit = _ids[i]
		if event.pressed:
			_pressed = hit
			queue_redraw()
		else:
			if hit != "" and hit == _pressed:
				slot_pressed.emit(hit)
			_pressed = ""
			queue_redraw()
		accept_event()


func _draw() -> void:
	draw_texture_rect(_cache.get_texture(), Rect2(Vector2.ZERO, size), false)
	for i in _ids.size():
		var id := _ids[i]
		var s := _rect(i)
		if _pressed == id:
			draw_colored_polygon(PrepIcons._rrect(s, 18), Color(0.23, 0.14, 0.07, 0.25))
		if _flash.has(id):
			var f := float(_flash[id])
			draw_colored_polygon(PrepIcons._rrect(s, 18), Color(_flash_col[id], 0.25 * f))
			_ring(s, 18, Color(_flash_col[id], f), 4.0)
		if _pulse == id:
			var pulse := 0.5 + 0.5 * sin(_t * 7.0)
			_ring(s.grow(5.0 + 4.0 * pulse), 22, Color(HINT, 0.45 + 0.45 * pulse), 7.0)
			_ring(s, 18, EDGE, 4.0)
		if _badges.has(id):
			var c := Vector2(s.end.x - 10, s.position.y + 10)
			draw_circle(c, 22, Color("c23b2a"))
			draw_circle(c, 22, Color.WHITE, false, 3.0, true)
			var txt := GameData.ar_digits(int(_badges[id]))
			draw_string(_font, c + Vector2(-30, 10), txt, HORIZONTAL_ALIGNMENT_CENTER, 60, 28, Color.WHITE)


func _ring(r: Rect2, radius: float, col: Color, width: float) -> void:
	var line := PrepIcons._rrect(r, radius)
	line.append(line[0])
	draw_polyline(line, col, width, true)


## The still part, drawn into the cache: the wooden dock with a warm lip and
## screws at the ends, and a paper card per slot with its icon and name.
func _paint() -> void:
	var p := _painter
	var r := Rect2(Vector2.ZERO, size)
	p.draw_colored_polygon(PrepIcons._rrect(Rect2(8, 8, size.x - 16, size.y - 12), 26), WOOD_DARK)
	p.draw_colored_polygon(PrepIcons._rrect(Rect2(8, 4, size.x - 16, size.y - 16), 26), WOOD)
	for k in 5:
		var y := 18.0 + k * (r.size.y - 40.0) / 4.0
		p.draw_line(Vector2(30, y), Vector2(size.x - 30, y), Color(0, 0, 0, 0.08), 2.0)
	p.draw_rect(Rect2(30, 6, size.x - 60, 4), Color("e0a458"))
	for x in [26.0, size.x - 26.0]:
		p.draw_circle(Vector2(x, 22), 5, Color("c9ced6"))
	for i in _ids.size():
		var id := _ids[i]
		var s := _rect(i)
		p.draw_colored_polygon(PrepIcons._rrect(Rect2(s.position + Vector2(0, 5), s.size), 18), Color(0, 0, 0, 0.3))
		p.draw_colored_polygon(PrepIcons._rrect(s, 18), PAPER)
		var outline := PrepIcons._rrect(s, 18)
		outline.append(outline[0])
		p.draw_polyline(outline, EDGE, 3.0, true)
		var icon := Rect2(s.position + Vector2(s.size.x * 0.12, 10), Vector2(s.size.x * 0.76, s.size.y * 0.56))
		PrepIcons.draw_icon(p, id, icon)
		var name := tr(NAMES.get(id, id))
		var fs := 26 if s.size.x > 120 else 22
		p.draw_string(_font, Vector2(s.position.x, s.end.y - 16), name, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, fs, Color("3a2412"))
