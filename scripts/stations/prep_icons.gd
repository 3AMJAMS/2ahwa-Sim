class_name PrepIcons
extends RefCounted
## Procedural icons for the prep station's pick cards: the ingredients (tea,
## coffee, dried hibiscus, mango, ice) and the tools (the كنكة on the gas
## ring, the blender). Each is drawn into a rect on any CanvasItem, in a 100×100
## design space centred on the rect. Stand-ins until the real art lands.


## Icons already painted into textures, by "id@pixels".
static var _baked := {}


## The icon as a texture `px` pixels square, painted once (into a little
## offscreen view that's kept) and then reused: drawn live it's dozens of
## polygons, a draw call each. Null until it's painted, so callers draw it
## live meanwhile.
static func baked(id: String, px: int) -> Texture2D:
	var key := "%s@%d" % [id, px]
	if not _baked.has(key):
		_baked[key] = null
		_bake(id, px, key)
	return _baked[key]


static func _bake(id: String, px: int, key: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(px, px)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Node2D.new()
	painter.draw.connect(func() -> void: draw_icon(painter, id, Rect2(0, 0, px, px)))
	vp.add_child(painter)
	tree.root.add_child.call_deferred(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_baked[key] = vp.get_texture()


static func draw_icon(ci: CanvasItem, id: String, rect: Rect2) -> void:
	var s := minf(rect.size.x, rect.size.y) / 100.0
	var o := rect.get_center()
	match id:
		"tea":
			_tea(ci, o, s)
		"coffee":
			_coffee(ci, o, s)
		"karkade":
			_karkade(ci, o, s)
		"mint":
			_mint(ci, o, s)
		"milk":
			_milk(ci, o, s)
		"anise":
			_anise(ci, o, s)
		"cinnamon":
			_cinnamon(ci, o, s)
		"mango":
			_mango(ci, o, s)
		"ice":
			_ice(ci, o, s)
		"stove":
			_stove(ci, o, s)
		"blender":
			_blender(ci, o, s)
		"sugar":
			_sugar(ci, o, s)
		"teabag":
			_teabag(ci, o, s)
		"spoon":
			_spoon(ci, o, s)
		"done":
			_done(ci, o, s)


# --- Ingredients -------------------------------------------------------------

## Glass jar of loose black tea with a ridged gold lid and a paper label.
static func _tea(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 40) * s, Vector2(34, 7) * s)
	var body := Rect2(o + Vector2(-27, -20) * s, Vector2(54, 58) * s)
	ci.draw_colored_polygon(_rrect(body, 9 * s), Color(0.8, 0.9, 1.0, 0.18))
	# Tea leaves filling the jar.
	var fill := Rect2(o + Vector2(-24, -8) * s, Vector2(48, 43) * s)
	ci.draw_colored_polygon(_rrect(fill, 7 * s), Color("2a1a0e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 46:
		var c := fill.position + Vector2(rng.randf() * fill.size.x, rng.randf() * fill.size.y)
		var tone: Color = [Color("4a2e18"), Color("3a2412"), Color("5c3a1e"), Color("1e140a")][i % 4]
		ci.draw_colored_polygon(_ellipse(c, Vector2(3.2, 1.3) * s, rng.randf() * PI, 6), tone)
	# Label with a leaf.
	var label := Rect2(o + Vector2(-24, 6) * s, Vector2(48, 17) * s)
	ci.draw_rect(label, Color("f4ead2"))
	ci.draw_rect(Rect2(label.position, Vector2(label.size.x, 2.5 * s)), Color("c2471f"))
	ci.draw_rect(Rect2(label.position + Vector2(0, label.size.y - 2.5 * s), Vector2(label.size.x, 2.5 * s)), Color("c2471f"))
	_leaf(ci, label.get_center(), 6.5 * s, 0.5, Color("3f8a3a"))
	# Glass: rim, edge shine and highlights.
	var outline := _rrect(body, 9 * s)
	outline.append(outline[0])
	ci.draw_polyline(outline, Color(0.85, 0.93, 1.0, 0.55), 2.0 * s, true)
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-22, -16) * s, Vector2(5, 48) * s), 2.5 * s), Color(1, 1, 1, 0.3))
	ci.draw_circle(o + Vector2(16, -13) * s, 2.2 * s, Color(1, 1, 1, 0.45))
	# Neck and ridged lid.
	ci.draw_rect(Rect2(o + Vector2(-21, -27) * s, Vector2(42, 8) * s), Color(0.8, 0.9, 1.0, 0.3))
	var lid := Rect2(o + Vector2(-25, -41) * s, Vector2(50, 15) * s)
	ci.draw_colored_polygon(_rrect(lid, 4 * s), Color("c9a24a"))
	ci.draw_colored_polygon(_rrect(Rect2(lid.position, Vector2(lid.size.x, 5 * s)), 3 * s), Color("e6c56e"))
	for k in 9:
		var x := lid.position.x + (4 + k * 5.3) * s
		ci.draw_line(Vector2(x, lid.position.y + 6 * s), Vector2(x, lid.end.y - 1.5 * s), Color("9c7a2c"), 1.2 * s)


## Kraft-paper bag of ground coffee, top rolled, beans spilling out in front.
static func _coffee(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 40) * s, Vector2(38, 7) * s)
	var kraft := Color("b98a52")
	var body := PackedVector2Array([o + Vector2(-28, 38) * s, o + Vector2(28, 38) * s, o + Vector2(25, -20) * s,
		o + Vector2(-25, -20) * s])
	ci.draw_colored_polygon(body, kraft)
	# Side gusset in shadow, crease down the middle.
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(18, 38) * s, o + Vector2(28, 38) * s, o + Vector2(25, -20) * s,
		o + Vector2(17, -20) * s]), kraft.darkened(0.2))
	ci.draw_line(o + Vector2(-1, -18) * s, o + Vector2(-2, 36) * s, Color(0, 0, 0, 0.08), 1.5 * s)
	# Rolled top with its crinkled edge.
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-26, -31) * s, Vector2(52, 12) * s), 4 * s), kraft.darkened(0.12))
	ci.draw_line(o + Vector2(-25, -25) * s, o + Vector2(25, -25) * s, kraft.darkened(0.35), 1.2 * s)
	var zig := PackedVector2Array()
	for k in 11:
		zig.append(o + Vector2(-25 + k * 5, -31 - (k % 2) * 3) * s)
	ci.draw_polyline(zig, kraft.darkened(0.3), 1.5 * s, true)
	# Dark band with a bean emblem.
	ci.draw_rect(Rect2(o + Vector2(-24, -6) * s, Vector2(47, 20) * s), Color("3a2215"))
	ci.draw_rect(Rect2(o + Vector2(-24, -6) * s, Vector2(47, 2) * s), Color("e0a458"))
	_bean(ci, o + Vector2(0, 4) * s, 5.5 * s, 0.4)
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-23, -17) * s, Vector2(4, 52) * s), 2 * s), Color(1, 1, 1, 0.14))
	# Beans on the counter in front.
	var beans := [[Vector2(-30, 36), 0.3], [Vector2(-20, 41), 1.2], [Vector2(22, 42), 2.0], [Vector2(32, 37), 0.8],
		[Vector2(-38, 42), 2.4], [Vector2(12, 45), 0.2]]
	for b in beans:
		_bean(ci, o + (b[0] as Vector2) * s, 4.6 * s, b[1])


## Woven basket heaped with dried hibiscus calyces.
static func _karkade(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 38) * s, Vector2(42, 8) * s)
	var wicker := Color("b88a4a")
	var bowl := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		bowl.append(o + Vector2(cos(a) * 40, 4 + sin(a) * 32) * s)
	ci.draw_colored_polygon(bowl, wicker)
	# Weave: criss-cross strands clipped to the bowl.
	for k in 12:
		var x := -48.0 + k * 9.0
		for piece in Geometry2D.intersect_polygons(bowl, PackedVector2Array([o + Vector2(x, 2) * s, o + Vector2(x + 3, 2) * s,
				o + Vector2(x + 23, 38) * s, o + Vector2(x + 20, 38) * s])):
			ci.draw_colored_polygon(piece, wicker.darkened(0.22))
	for k in 4:
		var y := 10.0 + k * 7.0
		ci.draw_line(o + Vector2(-sqrt(maxf(0.0, 1600.0 - pow((y - 4) * 40.0 / 32.0, 2.0))), y) * s,
			o + Vector2(sqrt(maxf(0.0, 1600.0 - pow((y - 4) * 40.0 / 32.0, 2.0))), y) * s, wicker.lightened(0.15), 1.4 * s)
	# The heap of calyces, back rows first.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tones := [Color("5c0d22"), Color("7a1428"), Color("8e1330"), Color("a3183a")]
	for i in 34:
		var t := float(i) / 34.0
		var x := rng.randf_range(-34, 34) * (1.0 - t * 0.45)
		var y := 2.0 - (1.0 - absf(x) / 40.0) * 14.0 * (0.5 + t * 0.5) + rng.randf_range(-3, 3)
		_calyx(ci, o + Vector2(x, y) * s, rng.randf_range(4.0, 6.0) * s, rng.randf() * TAU, tones[i % tones.size()])
	# Rim of the basket over the heap's foot.
	ci.draw_polyline(_arc(o + Vector2(0, 4) * s, Vector2(41, 5) * s, 0.0, PI), wicker.darkened(0.3), 3.0 * s, true)
	ci.draw_polyline(_arc(o + Vector2(0, 3) * s, Vector2(41, 5) * s, 0.0, PI), wicker.lightened(0.2), 1.2 * s, true)
	for p in [Vector2(-40, 38), Vector2(36, 40)]:
		_calyx(ci, o + p * s, 4.5 * s, p.x, tones[1])


## A bunch of fresh mint: stems of paired, crinkled leaves tied with string.
static func _mint(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 40) * s, Vector2(30, 6) * s)
	var greens := [Color("3f8a3a"), Color("4c9a44"), Color("357a32")]
	var stems := [[Vector2(-6, 38), Vector2(-18, -30)], [Vector2(0, 38), Vector2(2, -40)], [Vector2(6, 38), Vector2(20, -28)]]
	for k in stems.size():
		var a: Vector2 = stems[k][0]
		var b: Vector2 = stems[k][1]
		ci.draw_line(o + a * s, o + b * s, Color("5a7a2a"), 2.4 * s, true)
		for j in 4:
			var t := 0.25 + j * 0.22
			var at := a.lerp(b, t)
			var dir := (b - a).normalized()
			var side := dir.orthogonal()
			var r := (13.0 - j * 2.0) * s
			for sd in [-1.0, 1.0]:
				var c: Vector2 = o + (at + side * sd * 9.0 - dir * 2.0) * s
				_leaf(ci, c, r, (side * sd).angle() - 0.4 * sd, greens[(k + j) % greens.size()])
		_leaf(ci, o + (b + (b - a).normalized() * 4.0) * s, 9.0 * s, (b - a).angle(), greens[k % greens.size()].lightened(0.1))
	# The string round the stems.
	ci.draw_line(o + Vector2(-10, 26) * s, o + Vector2(10, 26) * s, Color("e8dcc6"), 3.0 * s, true)
	ci.draw_line(o + Vector2(-9, 30) * s, o + Vector2(9, 30) * s, Color("e8dcc6"), 2.0 * s, true)


## A glass milk bottle with a blue cap and a paper label.
static func _milk(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 41) * s, Vector2(26, 6) * s)
	var body := PackedVector2Array()
	for p in [Vector2(-22, 40), Vector2(22, 40), Vector2(24, 4), Vector2(14, -18), Vector2(11, -30), Vector2(-11, -30),
			Vector2(-14, -18), Vector2(-24, 4)]:
		body.append(o + p * s)
	ci.draw_colored_polygon(body, Color("f6f3ec"))
	ci.draw_polyline(body + PackedVector2Array([body[0]]), Color("c9ccd2"), 2.0 * s, true)
	# Shading down one side, a highlight down the other.
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(12, 40) * s, o + Vector2(22, 40) * s, o + Vector2(24, 4) * s,
		o + Vector2(14, -18) * s, o + Vector2(8, -18) * s, o + Vector2(14, 4) * s]), Color(0.75, 0.78, 0.84, 0.45))
	ci.draw_line(o + Vector2(-16, 32) * s, o + Vector2(-17, 4) * s, Color(1, 1, 1, 0.9), 3.0 * s, true)
	# Cap with ridges.
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-13, -42) * s, Vector2(26, 13) * s), 3.0 * s), Color("2f6fb3"))
	for k in 5:
		var x := -10.0 + k * 5.0
		ci.draw_line(o + Vector2(x, -41) * s, o + Vector2(x, -31) * s, Color("24578e"), 1.4 * s)
	# Label with a drop.
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-20, 8) * s, Vector2(40, 20) * s), 3.0 * s), Color("2f6fb3"))
	ci.draw_colored_polygon(_ellipse(o + Vector2(0, 20) * s, Vector2(5, 5) * s, 0.0, 12), Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, 11) * s, o + Vector2(-4.5, 18) * s, o + Vector2(4.5, 18) * s]),
		Color.WHITE)


## Aniseed heaped in a little wooden bowl, a few seeds spilled beside it.
static func _anise(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 38) * s, Vector2(40, 7) * s)
	var wood := Color("a0703e")
	var bowl := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		bowl.append(o + Vector2(cos(a) * 38, 6 + sin(a) * 28) * s)
	ci.draw_colored_polygon(bowl, wood)
	ci.draw_polyline(_arc(o + Vector2(0, 6) * s, Vector2(38, 28) * s, 0.15, PI - 0.15), wood.darkened(0.25), 2.0 * s, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var tones := [Color("8a7a4a"), Color("a08c56"), Color("6e6038"), Color("b4a06a")]
	for i in 70:
		var t := float(i) / 70.0
		var x := rng.randf_range(-34, 34) * (1.0 - t * 0.5)
		var y := 6.0 - (1.0 - absf(x) / 38.0) * 18.0 * (0.4 + t * 0.6) + rng.randf_range(-2, 2)
		ci.draw_colored_polygon(_ellipse(o + Vector2(x, y) * s, Vector2(3.0, 1.3) * s, rng.randf() * PI, 6),
			tones[i % tones.size()])
	ci.draw_polyline(_arc(o + Vector2(0, 6) * s, Vector2(39, 4) * s, 0.0, PI), wood.darkened(0.35), 3.0 * s, true)
	for p in [Vector2(-40, 36), Vector2(-33, 40), Vector2(38, 38)]:
		ci.draw_colored_polygon(_ellipse(o + p * s, Vector2(3.0, 1.3) * s, p.x, 6), tones[0])


## A bundle of cinnamon quills tied with string.
static func _cinnamon(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 38) * s, Vector2(40, 7) * s)
	var bark := [Color("9a5a2c"), Color("8a4e24"), Color("a8653a"), Color("7e4520")]
	var quills := [[Vector2(-36, 24), Vector2(30, -20)], [Vector2(-30, 32), Vector2(36, -12)], [Vector2(-38, 12), Vector2(26, -30)],
		[Vector2(-26, 36), Vector2(40, -2)]]
	for k in quills.size():
		var a: Vector2 = quills[k][0]
		var b: Vector2 = quills[k][1]
		var d := (b - a).normalized().orthogonal() * 6.0
		var col: Color = bark[k]
		ci.draw_colored_polygon(PackedVector2Array([o + (a + d) * s, o + (b + d) * s, o + (b - d) * s, o + (a - d) * s]), col)
		ci.draw_line(o + (a + d * 0.4) * s, o + (b + d * 0.4) * s, col.lightened(0.18), 1.6 * s, true)
		# The rolled end: a spiral of bark.
		ci.draw_colored_polygon(_ellipse(o + b * s, Vector2(6.0, 6.0) * s, 0.0, 14), col.darkened(0.2))
		ci.draw_polyline(_arc(o + b * s, Vector2(4.0, 4.0) * s, 0.0, TAU * 0.8, 14), col.lightened(0.25), 1.4 * s, true)
		ci.draw_polyline(_arc(o + b * s, Vector2(2.0, 2.0) * s, 1.0, TAU * 0.7 + 1.0, 10), col.lightened(0.25), 1.2 * s, true)
	# String round the middle.
	for k in 2:
		var c := o + Vector2(0 + k * 4, 6 - k * 2) * s
		ci.draw_line(c + Vector2(-8, -12) * s, c + Vector2(8, 12) * s, Color("e8dcc6"), 2.4 * s, true)


## Two ripe mangoes with a leaf.
static func _mango(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 36) * s, Vector2(42, 8) * s)
	_one_mango(ci, o + Vector2(14, 6) * s, s * 0.9, -0.5)
	_one_mango(ci, o + Vector2(-12, 12) * s, s, 0.35)
	_leaf(ci, o + Vector2(10, -30) * s, 15 * s, -0.9, Color("3f8a3a"))


static func _one_mango(ci: CanvasItem, c: Vector2, s: float, rot: float) -> void:
	var body := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		# Kidney shape: one side fuller than the other.
		var r := Vector2(24 + 3 * cos(a), 17 + 3 * sin(a) * cos(a))
		body.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot) * s)
	ci.draw_colored_polygon(body, Color("f2a324"))
	for piece in Geometry2D.intersect_polygons(body, _ellipse(c + Vector2(10, -6).rotated(rot) * s, Vector2(18, 13) * s, rot, 16)):
		ci.draw_colored_polygon(piece, Color("e8632a", 0.75))
	for piece in Geometry2D.intersect_polygons(body, _ellipse(c + Vector2(-16, 4).rotated(rot) * s, Vector2(12, 10) * s, rot, 16)):
		ci.draw_colored_polygon(piece, Color("b8c43a", 0.6))
	for piece in Geometry2D.intersect_polygons(body, _ellipse(c + Vector2(4, 9).rotated(rot) * s, Vector2(22, 8) * s, rot, 16)):
		ci.draw_colored_polygon(piece, Color(0, 0, 0, 0.12))
	ci.draw_colored_polygon(_ellipse(c + Vector2(-6, -8).rotated(rot) * s, Vector2(7, 3.5) * s, rot - 0.3, 10), Color(1, 1, 1, 0.35))
	var stem := c + Vector2(-23, -2).rotated(rot) * s
	ci.draw_line(stem, stem + Vector2(-5, -4).rotated(rot) * s, Color("5a3a1a"), 2.5 * s, true)
	for k in 5:
		ci.draw_circle(c + Vector2(-8 + k * 5, 2 - k % 2 * 4).rotated(rot) * s, 0.7 * s, Color(1, 1, 0.8, 0.5))


## Three ice cubes with frosted edges and trapped bubbles.
static func _ice(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 38) * s, Vector2(40, 7) * s)
	for cube in [[Vector2(-15, 4), 17.0], [Vector2(17, 10), 15.0], [Vector2(0, 26), 16.0]]:
		_cube(ci, o + (cube[0] as Vector2) * s, cube[1] * s)
	for d in [Vector2(-34, 34), Vector2(30, 36), Vector2(-6, 42)]:
		ci.draw_colored_polygon(_ellipse(o + d * s, Vector2(4, 1.8) * s, 0.0, 10), Color(0.7, 0.85, 1.0, 0.45))
	for sp in [Vector2(-26, -14), Vector2(26, -8)]:
		var c: Vector2 = o + sp * s
		ci.draw_line(c + Vector2(-4, 0) * s, c + Vector2(4, 0) * s, Color(1, 1, 1, 0.9), 1.4 * s)
		ci.draw_line(c + Vector2(0, -4) * s, c + Vector2(0, 4) * s, Color(1, 1, 1, 0.9), 1.4 * s)


static func _cube(ci: CanvasItem, c: Vector2, e: float) -> void:
	var top := PackedVector2Array([c + Vector2(0, -e), c + Vector2(e, -e * 0.5), c, c + Vector2(-e, -e * 0.5)])
	var left := PackedVector2Array([c + Vector2(-e, -e * 0.5), c, c + Vector2(0, e), c + Vector2(-e, e * 0.5)])
	var right := PackedVector2Array([c, c + Vector2(e, -e * 0.5), c + Vector2(e, e * 0.5), c + Vector2(0, e)])
	ci.draw_colored_polygon(left, Color(0.62, 0.8, 0.95, 0.85))
	ci.draw_colored_polygon(right, Color(0.5, 0.7, 0.9, 0.85))
	ci.draw_colored_polygon(top, Color(0.85, 0.95, 1.0, 0.95))
	ci.draw_colored_polygon(_ellipse(c + Vector2(-e * 0.45, e * 0.15), Vector2(e * 0.25, e * 0.3), 0.3, 10), Color(1, 1, 1, 0.25))
	for b in [Vector2(0.4, 0.2), Vector2(0.55, 0.45), Vector2(-0.6, 0.35)]:
		ci.draw_circle(c + b * e, e * 0.07, Color(1, 1, 1, 0.55))
	var edges := PackedVector2Array([top[0], top[1], top[2], top[3], top[0]])
	ci.draw_polyline(edges, Color(1, 1, 1, 0.8), 1.2, true)
	ci.draw_line(top[2], left[2], Color(1, 1, 1, 0.5), 1.0)


## Tin sugar bowl heaped white, a teaspoon standing in it.
static func _sugar(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 40) * s, Vector2(38, 7) * s)
	# Heap of sugar above the rim, grains catching the light.
	var heap := _arc(o + Vector2(0, -2) * s, Vector2(32, 18) * s, PI, TAU, 14)
	ci.draw_colored_polygon(heap, Color("f4f1ea"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 22:
		var p := o + Vector2(rng.randf_range(-26, 26), rng.randf_range(-14, -2)) * s
		ci.draw_circle(p, 1.3 * s, Color("d8d2c4") if k % 2 else Color.WHITE)
	# Spoon stuck in the heap.
	ci.draw_line(o + Vector2(6, -8) * s, o + Vector2(26, -44) * s, Color("b3b9c2"), 4.0 * s)
	ci.draw_line(o + Vector2(7, -9) * s, o + Vector2(26, -43) * s, Color("e6e9ee"), 1.5 * s)
	# The bowl: a squat tin with a rolled rim.
	var bowl := PackedVector2Array([o + Vector2(-38, -2) * s, o + Vector2(38, -2) * s, o + Vector2(30, 36) * s, o + Vector2(-30, 36) * s])
	ci.draw_colored_polygon(bowl, Color("9fa7b3"))
	ci.draw_colored_polygon(PackedVector2Array([bowl[0], o + Vector2(-20, -2) * s, o + Vector2(-16, 36) * s, bowl[3]]),
		Color(1, 1, 1, 0.25))
	ci.draw_colored_polygon(_ellipse(o + Vector2(0, -2) * s, Vector2(39, 6) * s, 0.0, 20), Color("c9ced6"))
	ci.draw_colored_polygon(_ellipse(o + Vector2(0, -3) * s, Vector2(33, 4) * s, 0.0, 20), Color("f4f1ea"))
	ci.draw_line(o + Vector2(-34, 14) * s, o + Vector2(34, 14) * s, Color(0, 0, 0, 0.15), 2.0 * s)


## A paper tea bag on its string, with the little tag.
static func _teabag(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(-6, 40) * s, Vector2(30, 6) * s)
	var bag := PackedVector2Array([o + Vector2(-30, -6) * s, o + Vector2(10, -6) * s, o + Vector2(12, 34) * s, o + Vector2(-32, 34) * s])
	ci.draw_colored_polygon(bag, Color("efe6d2"))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-26, 4) * s, o + Vector2(6, 4) * s, o + Vector2(8, 30) * s,
		o + Vector2(-28, 30) * s]), Color("6a3a1e", 0.55))
	for k in 5:
		ci.draw_line(o + Vector2(-30 + k * 10, -6) * s, o + Vector2(-30 + k * 10, -2) * s, Color("c9bda4"), 1.2 * s)
	# Folded top with its staple, the string up and over to the tag.
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-30, -6) * s, o + Vector2(10, -6) * s, o + Vector2(0, -16) * s,
		o + Vector2(-20, -16) * s]), Color("e2d7bf"))
	ci.draw_line(o + Vector2(-14, -14) * s, o + Vector2(-6, -14) * s, Color("9fa7b3"), 2.0 * s)
	var string := PackedVector2Array()
	for i in 10:
		var t := i / 9.0
		string.append((o + Vector2(-10, -16) * s).bezier_interpolate(o + Vector2(0, -44) * s, o + Vector2(24, -44) * s,
			o + Vector2(28, -22) * s, t))
	ci.draw_polyline(string, Color("f4f1ea"), 1.5 * s, true)
	var tag := Rect2(o + Vector2(18, -22) * s, Vector2(22, 26) * s)
	ci.draw_colored_polygon(_rrect(tag, 3 * s), Color("c23b2a"))
	ci.draw_colored_polygon(_rrect(tag.grow(-4 * s), 2 * s), Color("f2d24a"))


## A teaspoon stirring a tea glass, with the swirl.
static func _spoon(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 40) * s, Vector2(30, 6) * s)
	var glass := PackedVector2Array([o + Vector2(-22, 38) * s, o + Vector2(22, 38) * s, o + Vector2(28, -24) * s, o + Vector2(-28, -24) * s])
	ci.draw_colored_polygon(glass, Color(0.8, 0.9, 1.0, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-21, 34) * s, o + Vector2(21, 34) * s, o + Vector2(26, -14) * s,
		o + Vector2(-26, -14) * s]), Color("9c3d16"))
	ci.draw_polyline(_arc(o + Vector2(0, -14) * s, Vector2(20, 5) * s, 0.2, TAU - 0.6, 14), Color("dcb88a"), 2.0 * s)
	ci.draw_polyline(_arc(o + Vector2(0, 6) * s, Vector2(14, 4) * s, 0.8, TAU - 0.2, 12), Color(1, 1, 1, 0.35), 1.5 * s)
	ci.draw_line(o + Vector2(-2, 22) * s, o + Vector2(24, -46) * s, Color("b3b9c2"), 4.0 * s)
	ci.draw_line(o + Vector2(-1, 20) * s, o + Vector2(24, -45) * s, Color("e6e9ee"), 1.5 * s)
	ci.draw_polyline(_arc(o + Vector2(40, -30) * s, Vector2(12, 12) * s, -2.4, 0.9, 10), Color("7a5a2e"), 3.0 * s)


## "Done": a big green tick in a ring.
static func _done(ci: CanvasItem, o: Vector2, s: float) -> void:
	ci.draw_colored_polygon(_ellipse(o, Vector2(38, 38) * s, 0.0, 28), Color("1f5a24"))
	ci.draw_colored_polygon(_ellipse(o, Vector2(33, 33) * s, 0.0, 28), Color("4caf50"))
	ci.draw_polyline(PackedVector2Array([o + Vector2(-16, 0) * s, o + Vector2(-5, 12) * s, o + Vector2(18, -12) * s]),
		Color.WHITE, 7.0 * s, true)


# --- Tools ---------------------------------------------------------------------

## The brass كنكة on the cast-iron gas ring, blue flames licking round it.
static func _stove(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 42) * s, Vector2(40, 7) * s)
	# Burner body, cast-iron trivet and its legs.
	ci.draw_colored_polygon(_ellipse(o + Vector2(0, 34) * s, Vector2(34, 8) * s, 0.0, 22), Color("2c2a30"))
	ci.draw_rect(Rect2(o + Vector2(-34, 26) * s, Vector2(68, 8) * s), Color("3a383f"))
	ci.draw_colored_polygon(_ellipse(o + Vector2(0, 26) * s, Vector2(34, 8) * s, 0.0, 22), Color("4a4850"))
	for x in [-28.0, -10.0, 10.0, 28.0]:
		ci.draw_line(o + Vector2(x, 26) * s, o + Vector2(x * 0.8, 16) * s, Color("1d1c21"), 3.0 * s)
	# Flame tongues round the ring.
	for k in 9:
		var a := PI * (0.05 + k * 0.1125)
		var base := o + Vector2(cos(a) * 22, 22 + sin(a) * 3) * s
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0) * s, base + Vector2(3, 0) * s,
			base + Vector2(0, -9 - (k % 3) * 2) * s]), Color("3b8fff", 0.85))
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-1.5, 0) * s, base + Vector2(1.5, 0) * s,
			base + Vector2(0, -5) * s]), Color("bfe0ff"))
	# The كنكة: flared belly, pinched neck, pouring lip, long wooden handle.
	var pot := PackedVector2Array([o + Vector2(-19, 16) * s, o + Vector2(19, 16) * s, o + Vector2(15, -6) * s,
		o + Vector2(11, -16) * s, o + Vector2(13, -22) * s, o + Vector2(-15, -22) * s, o + Vector2(-11, -16) * s,
		o + Vector2(-15, -6) * s])
	ci.draw_colored_polygon(pot, Color("c9923a"))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(6, 16) * s, o + Vector2(19, 16) * s, o + Vector2(15, -6) * s,
		o + Vector2(11, -16) * s, o + Vector2(13, -22) * s, o + Vector2(6, -22) * s]), Color("9c6a24"))
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-10, -18) * s, Vector2(4, 30) * s), 2 * s), Color(1, 1, 1, 0.3))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-15, -22) * s, o + Vector2(-22, -26) * s,
		o + Vector2(-13, -25) * s]), Color("c9923a"))
	ci.draw_line(o + Vector2(-15, -22) * s, o + Vector2(13, -22) * s, Color("e6b860"), 2.0 * s)
	for y in [0.0, 8.0]:
		ci.draw_line(o + Vector2(-16, y) * s, o + Vector2(16, y) * s, Color("8a5a1e", 0.5), 1.2 * s)
	ci.draw_line(o + Vector2(15, -8) * s, o + Vector2(44, -24) * s, Color("5a3620"), 5.0 * s, true)
	ci.draw_line(o + Vector2(20, -11) * s, o + Vector2(42, -23) * s, Color("7a4c2c"), 2.0 * s, true)
	ci.draw_circle(o + Vector2(15, -8) * s, 2.5 * s, Color("8a5a1e"))
	# Steam curling up.
	for k in 2:
		var pts := PackedVector2Array()
		for i in 8:
			var t := i / 7.0
			pts.append(o + Vector2(-4 + k * 8 + sin(t * 5.0 + k) * 3, -28 - t * 16) * s)
		ci.draw_polyline(pts, Color(1, 1, 1, 0.35), 1.8 * s, true)


## The blender: base with buttons and dial, ribbed jug of karkade, black lid.
static func _blender(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 44) * s, Vector2(32, 6) * s)
	var base := PackedVector2Array([o + Vector2(-24, 42) * s, o + Vector2(24, 42) * s, o + Vector2(19, 16) * s,
		o + Vector2(-19, 16) * s])
	ci.draw_colored_polygon(base, Color("e8e0cc"))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(12, 42) * s, o + Vector2(24, 42) * s, o + Vector2(19, 16) * s,
		o + Vector2(10, 16) * s]), Color("c8bfa8"))
	ci.draw_rect(Rect2(o + Vector2(-22, 40) * s, Vector2(44, 3) * s), Color("2c2a30"))
	for k in 3:
		ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-15 + k * 8, 30) * s, Vector2(6, 5) * s), 1.5 * s),
			[Color("4caf50"), Color("e6c33a"), Color("e0452b")][k])
	ci.draw_circle(o + Vector2(12, 28) * s, 4.5 * s, Color("3a383f"))
	ci.draw_line(o + Vector2(12, 28) * s, o + Vector2(14, 25) * s, Color("e8e0cc"), 1.2 * s)
	# Jug: collar, glass with contents, ribs, blades, handle.
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-17, 11) * s, Vector2(34, 6) * s), 2 * s), Color("3a383f"))
	var jug := PackedVector2Array([o + Vector2(-15, 11) * s, o + Vector2(15, 11) * s, o + Vector2(20, -34) * s,
		o + Vector2(-20, -34) * s])
	ci.draw_colored_polygon(jug, Color(0.8, 0.92, 1.0, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-15, 11) * s, o + Vector2(15, 11) * s, o + Vector2(17.6, -12) * s,
		o + Vector2(-17.6, -12) * s]), Color("a3183a", 0.85))
	ci.draw_colored_polygon(_ellipse(o + Vector2(0, -12) * s, Vector2(17.6, 2.5) * s, 0.0, 14), Color("c43a58"))
	for k in 4:
		var x := -12.0 + k * 8.0
		ci.draw_line(o + Vector2(x, 9) * s, o + Vector2(x * 1.3, -31) * s, Color(1, 1, 1, 0.18), 1.2 * s)
	ci.draw_line(o + Vector2(-8, 6) * s, o + Vector2(8, 3) * s, Color("d4d9e1"), 2.0 * s)
	ci.draw_line(o + Vector2(-6, 2) * s, o + Vector2(6, 8) * s, Color("d4d9e1"), 2.0 * s)
	var jug_outline := jug.duplicate()
	jug_outline.append(jug[0])
	ci.draw_polyline(jug_outline, Color(0.85, 0.93, 1.0, 0.6), 1.5 * s, true)
	ci.draw_polyline(PackedVector2Array([o + Vector2(18, -26) * s, o + Vector2(28, -24) * s, o + Vector2(27, 0) * s,
		o + Vector2(16, 2) * s]), Color(0.85, 0.93, 1.0, 0.7), 3.5 * s, true)
	for k in 5:
		var y := 4.0 - k * 7.0
		ci.draw_line(o + Vector2(-17 - k * 0.5, y) * s, o + Vector2(-13 - k * 0.5, y) * s, Color(1, 1, 1, 0.5), 1.0 * s)
	# Lid and its filler cap.
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-22, -40) * s, Vector2(44, 8) * s), 3 * s), Color("2f2d34"))
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-7, -46) * s, Vector2(14, 7) * s), 2 * s), Color("45434b"))
	ci.draw_line(o + Vector2(-20, -39) * s, o + Vector2(20, -39) * s, Color(1, 1, 1, 0.2), 1.2 * s)


# --- Helpers -------------------------------------------------------------------

static func _shadow(ci: CanvasItem, c: Vector2, r: Vector2) -> void:
	ci.draw_colored_polygon(_ellipse(c, r, 0.0, 20), Color(0, 0, 0, 0.28))


static func _bean(ci: CanvasItem, c: Vector2, r: float, rot: float) -> void:
	ci.draw_colored_polygon(_ellipse(c, Vector2(r, r * 0.7), rot, 12), Color("4a2b1b"))
	ci.draw_colored_polygon(_ellipse(c + Vector2(-r * 0.25, -r * 0.2).rotated(rot), Vector2(r * 0.4, r * 0.2), rot, 8),
		Color(1, 1, 1, 0.15))
	var d := Vector2(r * 0.8, 0).rotated(rot)
	ci.draw_polyline(PackedVector2Array([c - d, c - d * 0.3 + d.orthogonal() * 0.15, c + d * 0.3 - d.orthogonal() * 0.15, c + d]),
		Color("24140c"), maxf(1.0, r * 0.22), true)


## A dried hibiscus calyx: five pointed lobes round a darker heart.
static func _calyx(ci: CanvasItem, c: Vector2, r: float, rot: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a) * 0.8) * rr)
	ci.draw_colored_polygon(pts, color)
	ci.draw_circle(c, r * 0.28, color.darkened(0.4))
	ci.draw_line(c, c + Vector2(cos(rot), sin(rot) * 0.8) * r * 0.9, color.lightened(0.2), maxf(1.0, r * 0.12))


static func _leaf(ci: CanvasItem, c: Vector2, r: float, rot: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.42 * (1.0 - 0.3 * cos(a))).rotated(rot))
	ci.draw_colored_polygon(pts, color)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[7], pts[8]]),
		color.lightened(0.12))
	ci.draw_line(c + Vector2(-r, 0).rotated(rot), c + Vector2(r, 0).rotated(rot), color.darkened(0.35), maxf(1.0, r * 0.08))
	for k in 3:
		var at := c + Vector2(-r * 0.5 + k * r * 0.45, 0).rotated(rot)
		ci.draw_line(at, at + Vector2(r * 0.22, -r * 0.28).rotated(rot), color.darkened(0.25), maxf(1.0, r * 0.05))


static func _ellipse(c: Vector2, r: Vector2, rot: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


static func _arc(c: Vector2, r: Vector2, a0: float, a1: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


static func _rrect(r: Rect2, radius: float) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.49)
	var pts := PackedVector2Array()
	var corners := [[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5]]
	for corner in corners:
		for k in 5:
			var a: float = corner[1] + PI * 0.5 * k / 4.0
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * rad)
	return pts
