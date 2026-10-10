class_name FpsMeter
extends CanvasLayer
## A small frame-rate readout in the corner for testing on phones: frames
## per second and the 3D draw calls. Shown or hidden by holding the
## day/clock/money line for a second; the choice is kept in the save.

var _label := Label.new()
var _t := 0.0


func _ready() -> void:
	layer = 20
	_label.position = Vector2(16, 8)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 8)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_label)
	visible = bool(Economy.data.settings.get("show_fps", false))


func toggle() -> void:
	visible = not visible
	Economy.data.settings["show_fps"] = visible


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	var vp := get_viewport()
	_label.text = "FPS %d  ·  %d draws" % [Engine.get_frames_per_second(),
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)]
