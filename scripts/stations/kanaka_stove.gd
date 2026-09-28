class_name KanakaStove
extends StationArt
## Hot-station art: a gas ring on a small cylinder with a كنكة on top, and a
## tea glass (or a coffee فنجان) on its saucer. Purely visual — HeatGauge feeds
## it `heat` and calls ignite()/pour()/boil_over(); scoring never reads it.
## set_look() recolours it per drink from the menu item's "look" block.

enum Pour { PERFECT, LUKEWARM, TOO_HOT }

## Where the kanaka's base rests on the pot support.
const BURNER_TOP := Vector2(590, 400)
const RING_Y := 436.0
const GLASS_BASE := Vector2(250, 598)
const GLASS_H := 168.0
## Solid glass at the bottom of the tumbler.
const GLASS_FOOT := 14.0
## Half-width at the foot and at the rim.
const GLASS_HW := Vector2(42, 56)
const GLASS_FULL := 0.86
## فنجان: height and half-width at the foot and rim.
const CUP_H := 92.0
const CUP_HW := Vector2(34, 50)

# Kanaka local space: origin at the base centre, -y is up.
## (half-width, y) up the side: wide belly, pinched neck, flared lip.
const K_PROFILE := [
	Vector2(76, 0), Vector2(83, -4), Vector2(87, -12), Vector2(89, -45),
	Vector2(67, -105), Vector2(69, -125), Vector2(82, -145),
]
const K_RIM_Y := -145.0
const K_RIM := Vector2(82, 16)
const K_SURFACE := Vector2(76, 13)
## Spout tip; the pour pivots around it so the stream stays put.
const K_SPOUT := Vector2(-103, -153)
const REST_PIVOT := BURNER_TOP + K_SPOUT
const LIFT_PIVOT := REST_PIVOT + Vector2(0, -60)
const POUR_PIVOT := Vector2(322, 372)
const POUR_TILT := -0.9
const POUR_TILT_END := -1.2
## Spill runs down the front of the pot: (x, max length, width).
const DRIPS := [
	Vector3(-58, 70, 10), Vector3(-32, 118, 12), Vector3(-8, 90, 11),
	Vector3(16, 132, 13), Vector3(40, 98, 11), Vector3(62, 66, 9),
]
## Spill level at which each drip starts to run.
const DRIP_START := [0.0, 0.3, 0.12, 0.45, 0.2, 0.6]

const COLOR_METAL := Color("b3b9c2")
const COLOR_METAL_DARK := Color("6f7682")
const COLOR_METAL_LIGHT := Color("e6e9ee")
const COLOR_GRIP := Color("5a3620")
const COLOR_BURNT := Color("1e0f08")
const COLOR_FOAM_BURNT := Color("4a3020")
const COLOR_CYLINDER := Color("b8452f")
const COLOR_BRASS := Color("c9a24a")
const COLOR_IRON := Color("2c2a30")
const COLOR_FLAME := Color(0.3, 0.5, 1.0, 0.8)
const COLOR_FLAME_CORE := Color(0.72, 0.88, 1.0, 0.95)
const COLOR_FLAME_TIP := Color(1.0, 0.62, 0.22, 0.7)
const COLOR_GLOW := Color("ff9f45")
const COLOR_SMOKE := Color(0.16, 0.14, 0.15, 0.5)
const COLOR_GOLD_BAND := Color("c9a24a")
## How hard the poured drink steams, indexed by Pour.
const GLASS_STEAM := [1.0, 0.35, 1.3]

var heat := 0.0
var flame := 0.0
var pot_pivot := REST_PIVOT
var pot_tilt := 0.0
## Drink left in the kanaka, 0..1.
var pot_level := 1.0
var stream := 0.0
var glass_fill := 0.0
var glass_foam := 0.0
var overflow := 0.0
var burn := 0.0

var _liquid := Color("9c3d16")
var _foam := Color("dcb88a")
var _leaves := Color("2e1b0e")
var _cup := false
var _on_burner := true
var _pour_kind := Pour.PERFECT
var _puffs := []
var _bubbles := []
var _drops := []
var _steam_acc := 0.0
var _bubble_acc := 0.0
var _smoke_acc := 0.0
var _drop_acc := 0.0
var _glass_steam_acc := 0.0


## Heat shimmer over the ring: a screen-reading shader on a rect that follows
## the flame, stronger as the heat builds.
var _haze := ColorRect.new()
## The gas flame is drawn additively on its own layer so it reads as
## see-through fire that brightens where the tongues overlap.
var _flame_layer := Control.new()


func _ready() -> void:
	super()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flame_layer.material = add
	_flame_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_flame_layer.set_anchors_preset(PRESET_FULL_RECT)
	_flame_layer.draw.connect(_draw_flame_layer)
	add_child(_flame_layer)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/heat_haze.gdshader")
	_haze.material = mat
	_haze.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_haze)
	reset()


## Recolours the drink: {"liquid", "foam", "vessel": "glass"|"cup", "leaves"}.
func set_look(look: Dictionary) -> void:
	_liquid = Color(look.get("liquid", "#9c3d16"))
	_foam = Color(look.get("foam", "#dcb88a"))
	_leaves = Color(look["leaves"]) if look.has("leaves") else Color.TRANSPARENT
	_cup = look.get("vessel", "glass") == "cup"
	queue_redraw()


## Kanaka back on a cold ring, full; glass empty.
func reset() -> void:
	_kill_tween()
	_finish_sequence()
	heat = 0.0
	flame = 0.0
	pot_pivot = REST_PIVOT
	pot_tilt = 0.0
	pot_level = 1.0
	stream = 0.0
	glass_fill = 0.0
	glass_foam = 0.0
	overflow = 0.0
	burn = 0.0
	_on_burner = true
	_pour_kind = Pour.PERFECT
	_puffs.clear()
	_bubbles.clear()
	_drops.clear()
	queue_redraw()


func ignite() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "flame", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Lifts the kanaka off the ring and pours it out. Returns once the glass is
## full; the kanaka then settles back on the ring by itself.
func pour(kind: Pour) -> void:
	_kill_tween()
	_pour_kind = kind
	_on_burner = false
	_busy = true
	var t := create_tween()
	_tween = t
	t.tween_property(self, "flame", 0.0, 0.2)
	t.parallel().tween_property(self, "pot_pivot", LIFT_PIVOT, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "pot_pivot", POUR_PIVOT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "pot_tilt", POUR_TILT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "stream", 1.0, 0.08)
	t.tween_property(self, "glass_fill", GLASS_FULL, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "pot_tilt", POUR_TILT_END, 0.85)
	t.parallel().tween_property(self, "pot_level", 0.0, 0.85)
	t.tween_property(self, "stream", 0.0, 0.1)
	if kind == Pour.PERFECT:
		t.parallel().tween_property(self, "glass_foam", 1.0, 0.4)
	t.tween_callback(_finish_sequence)
	t.tween_property(self, "pot_pivot", LIFT_PIVOT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "pot_tilt", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "pot_pivot", REST_PIVOT, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await sequence_finished


## The drink foams over, the spill chokes the flame and it all turns to smoke.
func boil_over() -> void:
	_kill_tween()
	_busy = true
	var t := create_tween()
	_tween = t
	t.tween_property(self, "overflow", 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "burn", 1.0, 1.0)
	t.parallel().tween_property(self, "flame", 0.0, 0.7).set_delay(0.3)
	t.tween_callback(_finish_sequence)
	await sequence_finished


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var xf := _scene_xf()
	var s := _scene_scale()
	_haze.position = xf * (BURNER_TOP + Vector2(-130, -110))
	_haze.size = Vector2(260, 170) * s
	(_haze.material as ShaderMaterial).set_shader_parameter("strength", flame * (0.35 + 0.65 * clampf(heat / 100.0, 0.0, 1.0)))
	_emit_particles(delta)
	_step_particles(delta)
	queue_redraw()
	_flame_layer.queue_redraw()


func _served_color(kind: Pour) -> Color:
	match kind:
		Pour.LUKEWARM:
			return _liquid.lerp(Color("d8b48a"), 0.45)
		Pour.TOO_HOT:
			return _liquid.darkened(0.55)
	return _liquid


func _foam_light() -> Color:
	return _foam.lightened(0.45)


#region Particles

func _emit_particles(delta: float) -> void:
	var boil := clampf(heat / 100.0, 0.0, 1.0)
	if _on_burner and heat > 0.0 and _puffs.size() < 120:
		_steam_acc += delta * lerpf(1.0, 14.0, boil)
		while _steam_acc >= 1.0:
			_steam_acc -= 1.0
			var local := Vector2(_rng.randf_range(-55, 55), K_RIM_Y - 6.0 - _foam_rise())
			_puffs.append(_particle(_pot_xf() * local,
				Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-62, -40)),
				_rng.randf_range(1.6, 2.4), _rng.randf_range(10, 16),
				Color(1, 1, 1, lerpf(0.05, 0.14, boil))))
	if _on_burner and heat > 25.0 and _bubbles.size() < 40:
		_bubble_acc += delta * pow((heat - 25.0) / 75.0, 1.5) * 45.0
		while _bubble_acc >= 1.0:
			_bubble_acc -= 1.0
			var x := _rng.randf_range(-0.85, 0.85) * K_SURFACE.x
			var span := K_SURFACE.y * sqrt(1.0 - pow(x / K_SURFACE.x, 2)) * 0.8
			var y := K_RIM_Y + 5.0 + _rng.randf_range(-span, span) - _dome_height(x)
			_bubbles.append(_particle(Vector2(x, y), Vector2.ZERO,
				_rng.randf_range(0.25, 0.5), _rng.randf_range(3.0, 7.0) * lerpf(0.6, 1.0, boil), Color.WHITE))
	var smoke := maxf(overflow, burn)
	if smoke > 0.0 and _puffs.size() < 140:
		_smoke_acc += delta * (18.0 if _busy else 5.0) * smoke
		while _smoke_acc >= 1.0:
			_smoke_acc -= 1.0
			var at := BURNER_TOP + Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-40, 20))
			_puffs.append(_particle(at, Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-90, -60)),
				_rng.randf_range(1.2, 2.0), _rng.randf_range(12, 20), COLOR_SMOKE))
	if stream > 0.3:
		_drop_acc += delta * 45.0
		while _drop_acc >= 1.0:
			_drop_acc -= 1.0
			_drops.append(_particle(_stream_end(), Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-170, -70)),
				_rng.randf_range(0.2, 0.35), _rng.randf_range(2.5, 4.0), _served_color(_pour_kind)))
	if glass_fill > 0.1 and _puffs.size() < 120:
		_glass_steam_acc += delta * 7.0 * GLASS_STEAM[_pour_kind] * glass_fill
		while _glass_steam_acc >= 1.0:
			_glass_steam_acc -= 1.0
			var at := Vector2(GLASS_BASE.x + _rng.randf_range(-36, 36), _glass_surface_y() - 4.0)
			_puffs.append(_particle(at, Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-50, -34)),
				_rng.randf_range(1.6, 2.4), _rng.randf_range(8, 12), Color(1, 1, 1, 0.1)))


func _step_particles(delta: float) -> void:
	for p in _puffs:
		p.age += delta
		p.vel.x += sin(_t * 1.7 + p.size) * 10.0 * delta
		p.vel *= 1.0 - 0.3 * delta
		p.pos += p.vel * delta
	for p in _drops:
		p.age += delta
		p.vel.y += 900.0 * delta
		p.pos += p.vel * delta
	for p in _bubbles:
		p.age += delta
	_puffs = _puffs.filter(func(p): return p.age < p.life)
	_drops = _drops.filter(func(p): return p.age < p.life)
	_bubbles = _bubbles.filter(func(p): return p.age < p.life)

#endregion


#region Drawing

func _draw() -> void:
	if _scene_scale() <= 0.0:
		return
	var scene_xf := _scene_xf()
	var span := _scene_span()
	draw_set_transform_matrix(scene_xf)
	_draw_backdrop()
	_draw_counter(span.x, span.y)
	_fill_ellipse(Vector2(BURNER_TOP.x, COUNTER_Y + 2), Vector2(118, 10), Color(0, 0, 0, 0.3))
	_draw_cylinder()
	_draw_flame()
	draw_set_transform_matrix(scene_xf * _pot_xf())
	_draw_pot()
	draw_set_transform_matrix(scene_xf)
	if _cup:
		_draw_cup_back()
	else:
		_draw_glass_back()
	if stream > 0.01:
		_draw_stream(pot_pivot + Vector2(-2, 3), _stream_end(), stream, _served_color(_pour_kind))
	if _cup:
		_draw_cup_front()
	else:
		_draw_glass_front()
	for p in _drops:
		draw_circle(p.pos, p.size * (1.0 - 0.5 * p.age / p.life), p.color)
	for p in _puffs:
		var k: float = p.age / p.life
		_soft_blob(p.pos, Vector2.ONE * p.size * (1.6 + 2.4 * k), Color(p.color, p.color.a * 1.6 * sin(PI * k)))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_backdrop() -> void:
	_soft_blob(BURNER_TOP + Vector2(-80, -40), Vector2(520, 380), Color(COLOR_GLOW, 0.1 + 0.12 * flame))


func _draw_cylinder() -> void:
	var cx := BURNER_TOP.x
	var shoulder := 490.0
	var foot := COUNTER_Y - 2.0
	draw_rect(Rect2(cx - 86, foot - 16, 172, 16), COLOR_IRON)
	var body := PackedVector2Array([Vector2(cx - 100, foot - 14), Vector2(cx + 100, foot - 14)])
	for i in 13:
		var a := PI * i / 12.0
		body.append(Vector2(cx + 100.0 * cos(a), shoulder - 26.0 * sin(a)))
	draw_colored_polygon(body, COLOR_CYLINDER)
	_clip_fill(body, [Vector2(cx + 38, 400), Vector2(cx + 110, 400), Vector2(cx + 110, foot), Vector2(cx + 38, foot)],
		Color(0, 0, 0, 0.22))
	_clip_fill(body, [Vector2(cx - 74, 400), Vector2(cx - 56, 400), Vector2(cx - 56, foot), Vector2(cx - 74, foot)],
		Color(1, 1, 1, 0.22))
	draw_rect(Rect2(cx - 100, 540, 200, 16), Color(0.95, 0.9, 0.8, 0.85))
	# Brass valve with its knob, then the burner cup.
	draw_rect(Rect2(cx - 20, 446, 40, 24), COLOR_BRASS)
	draw_rect(Rect2(cx - 20, 446, 12, 24), COLOR_BRASS.lightened(0.25))
	draw_rect(Rect2(cx + 20, 452, 14, 10), COLOR_BRASS.darkened(0.2))
	draw_circle(Vector2(cx + 40, 457), 10, Color("1d1c21"))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 52, RING_Y), Vector2(cx + 52, RING_Y),
		Vector2(cx + 30, 450), Vector2(cx - 30, 450)]), COLOR_IRON)
	_fill_ellipse(Vector2(cx, RING_Y), Vector2(52, 6), COLOR_IRON.lightened(0.15))
	# Pot support: two side prongs (the front one goes in front of the flame).
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([Vector2(cx + side * 46, 442), Vector2(cx + side * 94, 428),
			Vector2(cx + side * 94, 400)]), COLOR_IRON, 7.0, true)


func _draw_flame() -> void:
	_draw_front_prong()


## Additive layer: a faint wide veil, the blue body and a bright core per
## tongue, orange licks at the tips. Colours add up, so overlaps glow.
func _draw_flame_layer() -> void:
	if flame <= 0.01 or _scene_scale() <= 0.0:
		return
	var ci := _flame_layer
	ci.draw_set_transform_matrix(_scene_xf())
	var f := flame
	if burn > 0.0:
		f *= 0.55 + 0.45 * absf(sin(_t * 23.0))
	ci.draw_texture_rect(_soft, Rect2(Vector2(BURNER_TOP.x, RING_Y - 14) - Vector2(190, 80), Vector2(380, 160)), false,
		Color(COLOR_GLOW, 0.22 * f))
	var n := 11
	for i in n:
		var u := i / float(n - 1) * 2.0 - 1.0
		var base := Vector2(BURNER_TOP.x + u * 50.0, RING_Y)
		var flicker := 0.85 + 0.15 * sin(_t * 19.0 + i * 2.3) + 0.08 * sin(_t * 31.0 + i)
		var h := (30.0 + 12.0 * absf(u)) * f * flicker
		var lean := u * 24.0 + sin(_t * 7.0 + i) * 2.5
		_tongue_on(ci, base, 18.0, h * 1.15, lean * 1.1, Color(0.2, 0.35, 1.0, 0.18))
		_tongue_on(ci, base, 12.0, h, lean, hdr(Color(0.3, 0.5, 1.0, 0.42), 1.5))
		_tongue_on(ci, base, 5.0, h * 0.5, lean * 0.5, hdr(Color(0.7, 0.88, 1.0, 0.55), 2.0))
		if h > 6.0:
			var tip := base + Vector2(lean, -h + 3.0)
			ci.draw_circle(tip, 3.2 * f, hdr(Color(1.0, 0.55, 0.2, 0.45), 1.8))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _tongue_on(ci: CanvasItem, base: Vector2, w: float, h: float, lean: float, color: Color) -> void:
	if h < 1.0:
		return
	ci.draw_colored_polygon(PackedVector2Array([
		base + Vector2(-w * 0.5, 0),
		base + Vector2(-w * 0.55 + lean * 0.25, -h * 0.35),
		base + Vector2(-w * 0.3 + lean * 0.65, -h * 0.72),
		base + Vector2(lean, -h),
		base + Vector2(w * 0.3 + lean * 0.65, -h * 0.72),
		base + Vector2(w * 0.55 + lean * 0.25, -h * 0.35),
		base + Vector2(w * 0.5, 0),
	]), color)


func _draw_front_prong() -> void:
	var x := BURNER_TOP.x + 8.0
	draw_polyline(PackedVector2Array([Vector2(x, 448), Vector2(x, 400)]), COLOR_IRON.lightened(0.08), 6.0, true)


## Drawn in kanaka-local space.
func _draw_pot() -> void:
	var upright := clampf(1.0 - absf(pot_tilt) / 0.3, 0.0, 1.0) * pot_level
	var liquid := _liquid.darkened(0.3).lerp(COLOR_BURNT, burn)
	var foam := _foam.lerp(COLOR_FOAM_BURNT, burn)
	var foam_light := _foam_light().lerp(foam, burn)
	var cover := smoothstep(42.0, 66.0, heat)
	var rise := _foam_rise()
	var spill := _spill()
	var rim_c := Vector2(0, K_RIM_Y)

	# Inside: dark back wall and back lip, then the drink and its foam.
	_fill_ellipse(rim_c, K_RIM - Vector2(3, 2), Color("29211d"))
	_arc(rim_c, K_RIM, PI, TAU, COLOR_METAL_DARK, 3.0)
	if upright > 0.0:
		var surf := Vector2(0, K_RIM_Y + 5.0 + sin(_t * 9.0) * heat / 100.0 * 1.2)
		_fill_ellipse(surf, K_SURFACE, Color(liquid.lerp(foam, cover * 0.85), upright))
		for i in 14:
			var x := (float((i * 53) % 130) - 65.0)
			var y := surf.y + float((i * 29) % 15) - 7.0
			draw_circle(Vector2(x, y), 3.0 + (i % 3), Color(foam_light, cover * 0.6 * upright))
		if rise > 0.5:
			var half := 74.0 + spill * 14.0
			var dome := PackedVector2Array()
			for i in 17:
				var u := -1.0 + 2.0 * i / 16.0
				dome.append(Vector2(u * half, surf.y - rise * sqrt(1.0 - u * u)))
			for i in range(1, 16):
				var a := PI * i / 16.0
				dome.append(Vector2(half * cos(a), surf.y + K_SURFACE.y * sin(a)))
			draw_colored_polygon(dome, Color(foam, upright))
			for i in 9:
				var u := -0.8 + 1.6 * i / 8.0
				var c := Vector2(u * half, surf.y - rise * sqrt(1.0 - u * u) * 0.85)
				var r := 10.0 + 4.0 * sin(_t * 3.0 + i * 1.7)
				draw_circle(c, r, Color(foam.lightened(0.08), upright))
				draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.35, Color(foam_light, 0.8 * upright))
		for b in _bubbles:
			var k: float = b.age / b.life
			var r: float = b.size * minf(1.0, k * 1.6)
			var a := (1.0 - smoothstep(0.75, 1.0, k)) * upright
			draw_circle(b.pos, r, Color(liquid.lerp(foam_light, 0.55), 0.85 * a))
			draw_circle(b.pos + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.6 * a))

	# Body, shading, flame reflection on the base.
	var body := _pot_body()
	draw_colored_polygon(body, COLOR_METAL)
	var shade := PackedVector2Array()
	var shine := PackedVector2Array()
	for p in K_PROFILE:
		shade.append(Vector2(p.x * 0.35, p.y))
		shine.append(Vector2(-p.x * 0.72, p.y))
	for i in range(K_PROFILE.size() - 1, -1, -1):
		var p: Vector2 = K_PROFILE[i]
		shade.append(Vector2(p.x, p.y))
		shine.append(Vector2(-p.x * 0.52, p.y))
	_clip_fill(body, shade, Color(0, 0, 0, 0.22))
	_clip_fill(body, shine, Color(1, 1, 1, 0.3))
	_arc(Vector2(0, -105), Vector2(67, 8), 0.0, PI, Color(0, 0, 0, 0.18), 2.0)
	_arc(Vector2(0, -12), Vector2(87, 10), 0.0, PI, Color(0, 0, 0, 0.18), 2.0)
	if flame > 0.0:
		# Firelight on the base, fading up the belly.
		var band := PackedVector2Array([Vector2(-100, 4), Vector2(100, 4), Vector2(100, -48), Vector2(-100, -48)])
		for piece in Geometry2D.intersect_polygons(body, band):
			var colors := PackedColorArray()
			for p in piece:
				colors.append(Color(COLOR_GLOW, 0.4 * flame * clampf(1.0 + p.y / 48.0, 0.0, 1.0)))
			draw_polygon(piece, colors)

	# Front lip and spout.
	_arc(rim_c, K_RIM, 0.0, PI, COLOR_METAL_LIGHT, 5.0)
	var spout := PackedVector2Array([Vector2(-70, -150), K_SPOUT, Vector2(-79, -137)])
	draw_colored_polygon(spout, COLOR_METAL)
	draw_polyline(spout, COLOR_METAL_LIGHT, 2.5, true)

	# Boil-over running down the outside.
	if spill > 0.0:
		for i in DRIPS.size():
			var d: Vector3 = DRIPS[i]
			var start: float = DRIP_START[i]
			var k := clampf((spill - start) / (1.0 - start), 0.0, 1.0)
			if k <= 0.0:
				continue
			var y0 := K_RIM_Y + K_RIM.y * sqrt(1.0 - pow(d.x / K_RIM.x, 2))
			var y1 := minf(y0 + d.y * k, -6.0)
			draw_line(Vector2(d.x, y0 - 2.0), Vector2(d.x, y1), foam, d.z * (0.7 + 0.3 * k), true)
			draw_circle(Vector2(d.x, y1), d.z * 0.62, foam)
		for i in 11:
			var x := (-1.0 + i / 5.0) * 76.0
			draw_circle(Vector2(x, K_RIM_Y + K_RIM.y * sqrt(1.0 - pow(x / K_RIM.x, 2))), 2.0 + 8.0 * spill, foam)

	# Long handle with a wooden grip, riveted at the neck.
	draw_line(Vector2(60, -100), Vector2(172, -124), COLOR_METAL_DARK, 12.0, true)
	draw_line(Vector2(60, -103), Vector2(172, -127), COLOR_METAL, 4.0, true)
	draw_line(Vector2(160, -121.5), Vector2(240, -138.5), COLOR_GRIP, 18.0, true)
	draw_circle(Vector2(240, -138.5), 9.0, COLOR_GRIP)
	draw_line(Vector2(166, -126), Vector2(236, -141), COLOR_GRIP.lightened(0.2), 3.0, true)
	_fill_ellipse(Vector2(66, -101), Vector2(9, 12), COLOR_METAL_DARK)
	for y in [-106.0, -96.0]:
		draw_circle(Vector2(66, y), 2.2, COLOR_METAL_LIGHT)


func _draw_glass_back() -> void:
	var b := GLASS_BASE
	_draw_saucer(b)
	draw_colored_polygon(_glass_poly(b.y, b.y - GLASS_H, 0.0), Color(0.8, 0.9, 1.0, 0.1))
	_arc(Vector2(b.x, b.y - GLASS_H), Vector2(GLASS_HW.y, 8), PI, TAU, Color(1, 1, 1, 0.3), 2.0)
	var floor_y := b.y - GLASS_FOOT
	if _leaves.a > 0.0:
		# Loose leaves waiting at the bottom (شاي كشري is brewed straight in).
		for i in 16:
			var x := b.x + float((i * 37) % 66) - 33.0
			draw_circle(Vector2(x, floor_y - 2.0 - float((i * 13) % 6)), 2.4, _leaves)
	if glass_fill <= 0.001:
		return
	var col := _served_color(_pour_kind)
	var top_y := _glass_surface_y()
	var hw := _glass_hw(top_y) - 4.0
	draw_colored_polygon(_glass_poly(floor_y, top_y, 4.0), Color(col, 0.9))
	_fill_ellipse(Vector2(b.x, top_y), Vector2(hw, 6), Color(col.lightened(0.15), 0.95))
	if glass_foam > 0.0:
		_fill_ellipse(Vector2(b.x, top_y - 1.0), Vector2(hw - 1.0, 6.5), Color(_foam_light(), glass_foam))
		for i in 9:
			draw_circle(Vector2(b.x - hw * 0.7 + i * hw * 0.17, top_y + sin(i * 2.1) * 2.5), 2.2,
				Color(_foam, glass_foam))


func _draw_glass_front() -> void:
	var b := GLASS_BASE
	var top := b.y - GLASS_H
	draw_colored_polygon(_glass_poly(b.y, b.y - GLASS_FOOT, 0.0), Color(0.85, 0.95, 1.0, 0.18))
	for side in [-1.0, 1.0]:
		draw_line(Vector2(b.x + side * GLASS_HW.x, b.y), Vector2(b.x + side * GLASS_HW.y, top),
			Color(1, 1, 1, 0.5), 3.0, true)
	_arc(b, Vector2(GLASS_HW.x, 5), 0.0, PI, Color(1, 1, 1, 0.35), 2.0)
	_arc(Vector2(b.x, top), Vector2(GLASS_HW.y, 8), 0.0, PI, Color(1, 1, 1, 0.55), 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(b.x - 34, b.y - 16), Vector2(b.x - 26, b.y - 16),
		Vector2(b.x - 38, top + 14), Vector2(b.x - 46, top + 14)]), Color(1, 1, 1, 0.2))
	# Teaspoon leaning out of the glass.
	draw_line(Vector2(b.x - 20, top + 12), Vector2(b.x - 66, top - 44), COLOR_METAL, 5.0, true)
	_fill_ellipse(Vector2(b.x - 68, top - 47), Vector2(5, 6), COLOR_METAL_LIGHT)


## Inside of the فنجان: dark well, then the coffee surface seen through the rim.
func _draw_cup_back() -> void:
	var b := GLASS_BASE
	_draw_saucer(b)
	var rim := Vector2(b.x, b.y - CUP_H)
	var mouth := _ellipse(rim, Vector2(CUP_HW.y - 3.0, 8.0))
	draw_colored_polygon(mouth, COLOR_SAUCER.darkened(0.35))
	if glass_fill <= 0.001:
		return
	var col := _served_color(_pour_kind)
	var surf := _ellipse(Vector2(b.x, _glass_surface_y()), Vector2(CUP_HW.y - 4.0, 8.0))
	for piece in Geometry2D.intersect_polygons(mouth, surf):
		draw_colored_polygon(piece, col)
		if glass_foam > 0.0:
			draw_colored_polygon(piece, Color(_foam, glass_foam * 0.9))
	if glass_foam > 0.0:
		for i in 7:
			var p := Vector2(b.x - 30.0 + i * 10.0, _glass_surface_y() + sin(i * 1.9) * 2.5)
			draw_circle(p, 2.0, Color(_foam_light(), glass_foam * 0.8))


func _draw_cup_front() -> void:
	var b := GLASS_BASE
	var top := b.y - CUP_H
	var body := PackedVector2Array([Vector2(b.x - CUP_HW.x, b.y - 4.0), Vector2(b.x + CUP_HW.x, b.y - 4.0)])
	for i in 17:
		var a := PI * i / 16.0
		body.append(Vector2(b.x + CUP_HW.y * cos(a), top + 8.0 * sin(a)))
	# Handle first, so the body overlaps its roots.
	draw_arc(Vector2(b.x + CUP_HW.y + 2.0, top + 34.0), 17.0, -PI * 0.55, PI * 0.55, 16, COLOR_SAUCER.darkened(0.12), 9.0, true)
	draw_colored_polygon(body, COLOR_SAUCER)
	_clip_fill(body, [Vector2(b.x + 14, top - 10), Vector2(b.x + 60, top - 10), Vector2(b.x + 60, b.y), Vector2(b.x + 10, b.y)],
		Color(0, 0, 0, 0.14))
	_clip_fill(body, [Vector2(b.x - 32, top), Vector2(b.x - 22, top), Vector2(b.x - 18, b.y), Vector2(b.x - 26, b.y)],
		Color(1, 1, 1, 0.5))
	_fill_ellipse(Vector2(b.x, b.y - 3.0), Vector2(CUP_HW.x + 4.0, 5.0), COLOR_SAUCER.darkened(0.1))
	# Gold band under the lip, and the lip itself.
	_arc(Vector2(b.x, top + 12.0), Vector2(CUP_HW.y - 2.5, 8.0), 0.0, PI, COLOR_GOLD_BAND, 3.0)
	_arc(Vector2(b.x, top), Vector2(CUP_HW.y, 8.0), 0.0, PI, Color.WHITE, 2.5)

#endregion


#region Geometry

func _pot_xf() -> Transform2D:
	var jitter := Vector2.ZERO
	if _on_burner and heat > 80.0:
		var amp := (heat - 80.0) / 20.0 * 1.6 + overflow * 1.5
		jitter = Vector2(sin(_t * 53.0), sin(_t * 41.0 + 1.3)) * amp
	return Transform2D(pot_tilt, pot_pivot + jitter) * Transform2D(0.0, -K_SPOUT)


## Body outline whose top edge is the front half of the rim, so the inside
## of the pot shows above it.
func _pot_body() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in K_PROFILE:
		pts.append(Vector2(-p.x, p.y))
	# Arc inset a touch so it can't poke outside the flared lip.
	for i in 17:
		var a := PI - PI * i / 16.0
		pts.append(Vector2((K_RIM.x - 1.5) * cos(a), K_RIM_Y + K_RIM.y * sin(a)))
	for i in range(K_PROFILE.size() - 1, -1, -1):
		var p: Vector2 = K_PROFILE[i]
		pts.append(p)
	return pts


func _foam_rise() -> float:
	return smoothstep(58.0, 82.0, heat) * 26.0 + _spill() * 10.0


func _spill() -> float:
	return clampf(maxf((heat - 85.0) / 15.0, 0.0) * 0.7 + overflow, 0.0, 1.0)


func _dome_height(x: float) -> float:
	var u := clampf(x / 74.0, -1.0, 1.0)
	return _foam_rise() * sqrt(1.0 - u * u) * 0.9


func _glass_hw(y: float) -> float:
	return lerpf(GLASS_HW.x, GLASS_HW.y, (GLASS_BASE.y - y) / GLASS_H)


func _glass_poly(y_bottom: float, y_top: float, inset: float) -> PackedVector2Array:
	var x := GLASS_BASE.x
	var hb := _glass_hw(y_bottom) - inset
	var ht := _glass_hw(y_top) - inset
	return PackedVector2Array([Vector2(x - hb, y_bottom), Vector2(x + hb, y_bottom),
		Vector2(x + ht, y_top), Vector2(x - ht, y_top)])


func _glass_surface_y() -> float:
	if _cup:
		# Only the top of the coffee shows, sinking out of sight when empty.
		return GLASS_BASE.y - CUP_H + lerpf(40.0, 3.0, glass_fill / GLASS_FULL)
	return GLASS_BASE.y - GLASS_FOOT - glass_fill * (GLASS_H - GLASS_FOOT - 8.0)


func _stream_end() -> Vector2:
	return Vector2(GLASS_BASE.x + 8.0, _glass_surface_y())

#endregion
