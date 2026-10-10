# PARKED — not compiled (later/ has a .gdignore). Cut from scripts/stations/prep_station.gd
# (as of commit 0906979). Returns with: the blender → Phase E (juice tiers); mango → Phase D
# (first fruit drinks; note Phase D makes mango "iced, not blended", so the "blend" step may
# not come back with it — see later/README.md).
#
# Each block below says where it sat in PrepStation. Restore them together with
# later/scripts/stations/blender3d.gd + blend_gauge.gd, PrepRig.BLENDER_AT
# (later/snippets/prep_rig.lemon_rack_and_blender.gd) and Stove3D.show_glass
# (later/snippets/stove3d.show_glass.gd).


# --- Header doc comment: the lines that described the blender --------------------------------
## (PrepRig, Stove3D; a Blender3D only at the juice tiers) sits in the
##     anise, cinnamon, ice (mango at the juice tiers);
##   - (juice tiers) tap the blender to start it, hold anywhere for turbo.


# --- Constants: the mango slot and the hint keys ------------------------------------------------
# SLOT_OF gained:      "mango": "mango",
# HINT_KEYS gained:    "mango": "PREP_HINT_MANGO",  and  "blend": "PREP_HINT_BLEND",


# --- Members (after `var stove: Stove3D`) ---------------------------------------------------------
## Only built when a blender drink is ordered (the juice tiers): FIFI makes
## hot drinks, and an idle blender would still cost frames.
var blender: Blender3D
var heat_gauge := HeatGauge.new()
var blend_gauge := BlendGauge.new()

# (after `var _heating := false`)
var _blending := false

# (UI members, after `var _tap_label := Label.new()`)
var _blend_bar := ProgressBar.new()
var _motor_bar := ProgressBar.new()
var _hold_label := Label.new()


# --- _ready(): both gauges report the same way -----------------------------------------------------
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()
	add_child(heat_gauge)
	add_child(blend_gauge)
	for gauge in [heat_gauge, blend_gauge]:
		gauge.gauge_completed.connect(_on_gauge_completed)
	heat_gauge.gauge_failed.connect(_on_gauge_failed)
	heat_gauge.boiled_over.connect(_jolt.bind(1.6, 160))
	blend_gauge.motor_tripped.connect(_jolt.bind(0.9, 80))
	quick_bar.slot_pressed.connect(func(id: String) -> void: _act("ing:" + id))


# --- attach(): the blend gauge's readouts (the blender itself is built on demand) ----------------
	blend_gauge.setup(null, _status, _blend_bar, _motor_bar, _hold_label)


func _ensure_blender() -> void:
	if blender:
		return
	blender = Blender3D.new()
	blender.rig = rig
	rig.add_child(blender)
	blend_gauge.blender = blender


# --- _build_ui(): after the heat bar's _tap_label -------------------------------------------------
	for bar in [_blend_bar, _motor_bar]:
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.show_percentage = false
		bar.size = Vector2(40, 300)
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(bar)
	_hold_label.text = tr("UI_HOLD_TO_BLEND")
	_style_label(_hold_label, 32, Color(1, 0.702, 0.278), 10)
	_hold_label.size = Vector2(420, 50)
	add_child(_hold_label)


# --- _place_readouts(): after the _tap_label line ---------------------------------------------------
	if blender:
		var b := blender.blender_rect()
		_blend_bar.position = Vector2(right - 56.0, clampf(b.position.y - 40.0, 300.0, size.y - 700.0))
		_motor_bar.position = Vector2(right, _blend_bar.position.y)
	_hold_label.position = Vector2(size.x * 0.5 - 210.0, quick_bar.position.y - 70.0)


# --- load_order(): the cold/hot switch (replaces the plain heat_gauge.reset()/set_look lines) ---
	_blending = false
	var look: Dictionary = _item.get("look", {})
	var cold: bool = _item.get("station", "") == "blend"
	if cold:
		_ensure_blender()
	heat_gauge.reset()
	blend_gauge.reset()
	heat_gauge.set_look(look)
	if cold:
		blend_gauge.set_look(look)
	heat_gauge.water = look.get("pot", "") == "water"
	heat_gauge.milk = _has_step("milk_pot")
	heat_gauge.manual_pour = _has_step("pour_gentle")
	stove.show_glass(not cold)
	if blender:
		blender.show_glass(cold)
	_heat_bar.visible = not cold
	_green_zone.visible = not cold
	_blend_bar.visible = cold
	_motor_bar.visible = cold
	_hold_label.modulate.a = 0.0


# --- _act(): the blender blocks other actions while it runs -----------------------------------------
## Everything the player does comes through here: "ing:<id>" (a slot or a
## jar), "kanaka", "glass", "blender", "stir" (a full turn), "dunk".
func _act(action: String) -> void:
	if _done or arranging or _heating and action != "kanaka" or _blending or _pouring:
		pass  # (rest unchanged)


# --- _accepts(): mango is a plain "ing:" step; blend is a tap on the blender ---------------------------
		"coffee", "karkade", "mango", "mint", "anise", "cinnamon":
			return action == "ing:" + id
		"blend":
			return action == "blender"


# --- _do(): mango into the blender, the blend itself, ice into the blender's glass ------------------
		"mango":
			quick_bar.flash("mango", true)
			blender.add_fruit()
			tutorial_action.emit()
			_finish_step(id)
		"blend":
			_blending = true
			tutorial_action.emit()
			blend_gauge.start(float(_item.get("prep_time_sec", 10)))
			_explain_cold()
			var ok: bool = await _brewed
			if run != _run:
				return
			_blending = false
			if ok:
				_finish_step(id)
		"ice":
			quick_bar.flash("ice", true)
			if _item.get("station", "") == "blend":
				blender.add_ice_cube()
			else:
				stove.add_ice_cube()
			_ice_left -= 1
			tutorial_action.emit()
			if _ice_left <= 0:
				_finish_step(id)


# --- Gestures: tapping the blender, and holding for turbo ---------------------------------------------
func _tap(target: String) -> void:
	match target:
		"":
			pass
		"kanaka", "glass", "blender":
			_act(target)
		_:
			_act("ing:" + target)


## What's under the finger: the kanaka, the glass, the blender or a jar.
# (in _target_at(), after the glass check)
	if blender and blender.blender_rect().grow(10).has_point(p):
		return "blender"


## Holding: the gentle pour, or the blender's turbo.
func _set_hold(on: bool) -> void:
	_hold = on and not _done
	if _blending:
		blend_gauge.set_holding(_hold)


# --- _process() / _clear_hint(): no hints while blending ------------------------------------------------
	if not _heating and not _blending:
		pass  # (_process: the hint timer)
	if not _heating and not _blending and not _pouring:
		pass  # (_clear_hint: clear the status line)


# --- _draw_marks(): the hint ring round the blender ----------------------------------------------------
			"blend":
				if blender:
					r = blender.blender_rect()


# --- _explain_current(): Sayed explains mango and the blender the first time ----------------------------
		"mango":
			tut = "first_blend"
			steps = [{"text": tr("TUT_ADD_POT").format({"item": tr("ING_MANGO")}), "target": _slot_rect.bind("mango"),
				"until": tutorial_action}]
		"blend":
			tut = "first_blend_start"
			steps = [{"text": tr("TUT_BLEND"), "target": blender.blender_rect, "until": tutorial_action}]


# --- The blender's own tutorial (the "cold_station" one; see also tutorial.cold_station.gd) -----------
func _explain_cold() -> void:
	if not Tutorial.pending("cold_station"):
		return
	await Tutorial.play([
		{"text": tr("TUT_COLD_GAUGE"), "target": blender.blender_rect},
		{"text": tr("TUT_COLD_WARN"), "target": _motor_bar.get_global_rect},
	])
	Tutorial.mark("cold_station")


# --- _celebrate(): sparks at the blender's tall glass for a blended drink ---------------------------------
	var at := stove.glass_centre() if _item.get("station", "") != "blend" else blender.screen_of(PrepRig.GLASS_AT + Vector3(0, 0.2, 0))
