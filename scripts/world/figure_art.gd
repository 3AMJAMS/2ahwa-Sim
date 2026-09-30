class_name FigureArt
extends RefCounted
## People for the street, built into a MeshCanvas: about five heads tall,
## seen three-quarters from the front, lit from the left (the far right side
## falls into shade). The body (torso, neck, head) and the four limbs are
## built separately so the limbs can swing; each limb's pivot (hip or
## shoulder) is its origin. Feet stand at y = 0, the head's centre sits at
## HEAD_Y.
##
## A look is a Dictionary:
##   kind     "shirt" | "galabeya" | "hijab" | "tshirt" | "sayed"
##   skin, hair, cloth, trousers, extra (scarf colour) : Color
##   moustache, beard, glasses : bool
##   style    0 short, 1 receding, 2 curly, 3 swept back
##   mood     -1 cross .. 1 pleased

const HIP_Y := -62.0
const SHOULDER_Y := -116.0
const HEAD_Y := -150.0
const LIGHT := 0.1
const SHADE := 0.2


#region Body

static func build_body(m: MeshCanvas, look: Dictionary) -> void:
	_ellipse(m, Vector2(0, 0), Vector2(30, 9), Color(0, 0, 0, 0.3))
	var kind: String = look.get("kind", "shirt")
	match kind:
		"galabeya", "hijab":
			_robe(m, look)
		"tshirt":
			_pelvis(m, look.trousers)
			_tee(m, look)
		_:
			_pelvis(m, look.trousers)
			_shirt(m, look)
	_neck(m, look)
	if kind == "hijab":
		_hijab_head(m, look)
	else:
		_head(m, look)
		if kind == "galabeya":
			_kufi(m)
	if kind == "sayed":
		_towel(m)


## Hips in trousers with a belt.
static func _pelvis(m: MeshCanvas, trousers: Color) -> void:
	m.colored_polygon(PackedVector2Array([Vector2(-18, -52), Vector2(18, -52), Vector2(19, -66), Vector2(-19, -66)]), trousers)
	m.colored_polygon(PackedVector2Array([Vector2(6, -52), Vector2(18, -52), Vector2(19, -66), Vector2(8, -66)]),
		Color(0, 0, 0, SHADE * 0.7))
	m.colored_polygon(PackedVector2Array([Vector2(-19, -64), Vector2(19, -64), Vector2(19, -69), Vector2(-19, -69)]), Color("2a1d14"))
	m.rect(Rect2(-4, -69, 8, 5), Color("c9a24a"))


## Torso outline: waist, chest, rounded shoulders.
static func _torso_pts(waist_y: float, waist_w: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-waist_w, waist_y), Vector2(waist_w, waist_y), Vector2(22, -96), Vector2(24, -108)])
	for i in 7:
		var a := i / 6.0 * PI
		pts.append(Vector2(cos(a) * 24.0, -110.0 - sin(a) * 9.0))
	pts.append(Vector2(-24, -108))
	pts.append(Vector2(-22, -96))
	return pts


## Light from the left: a soft highlight down the near side, shade on the far.
static func _shade_torso(m: MeshCanvas, waist_y: float, waist_w: float) -> void:
	m.colored_polygon(PackedVector2Array([Vector2(waist_w * 0.3, waist_y), Vector2(waist_w, waist_y), Vector2(22, -96),
		Vector2(24, -108), Vector2(14, -117), Vector2(9, -100)]), Color(0, 0, 0, SHADE))
	m.colored_polygon(PackedVector2Array([Vector2(-waist_w + 2, waist_y), Vector2(-waist_w * 0.55, waist_y), Vector2(-16, -104),
		Vector2(-22, -106)]), Color(1, 1, 1, LIGHT))


static func _shirt(m: MeshCanvas, look: Dictionary) -> void:
	var cloth: Color = look.cloth
	m.colored_polygon(_torso_pts(-64, 18), cloth)
	if look.get("kind", "") == "sayed":
		# Sayed's checked shirt.
		for k in 5:
			var x := -18.0 + k * 9.0
			m.line(Vector2(x, -64), Vector2(x * 1.25, -114), Color(1, 1, 1, 0.22), 2.0)
		for k in 5:
			var y := -70.0 - k * 9.0
			m.line(Vector2(-21, y), Vector2(21, y), Color(1, 1, 1, 0.18), 2.0)
	_shade_torso(m, -64, 18)
	# Open collar, placket and buttons, breast pocket, folds at the waist.
	m.colored_polygon(PackedVector2Array([Vector2(-9, -119), Vector2(0, -104), Vector2(9, -119), Vector2(4, -121), Vector2(-4, -121)]),
		look.skin.darkened(0.1))
	for side in [-1.0, 1.0]:
		m.colored_polygon(PackedVector2Array([Vector2(side * 3, -121), Vector2(side * 12, -120), Vector2(side * 8, -109),
			Vector2(side * 1, -106)]), cloth.lightened(0.12))
	m.line(Vector2(0, -104), Vector2(0, -66), cloth.darkened(0.25), 1.5)
	for k in 4:
		m.circle(Vector2(1.5, -98 + k * 9.0), 1.3, cloth.lightened(0.35), 6)
	m.rect(Rect2(-17, -101, 10, 9), cloth.darkened(0.1))
	m.line(Vector2(-17, -101), Vector2(-7, -101), cloth.darkened(0.3), 1.2)
	for x in [-10.0, 6.0]:
		m.line(Vector2(x, -66), Vector2(x - 2, -76), cloth.darkened(0.2), 1.2)


static func _tee(m: MeshCanvas, look: Dictionary) -> void:
	var cloth: Color = look.cloth
	m.colored_polygon(_torso_pts(-60, 18), cloth)
	_shade_torso(m, -60, 18)
	m.colored_polygon(PackedVector2Array([Vector2(-8, -118), Vector2(8, -118), Vector2(5, -113), Vector2(-5, -113)]), look.skin.darkened(0.1))
	m.line(Vector2(-9, -118), Vector2(9, -118), cloth.darkened(0.25), 2.0)
	# A print across the chest.
	var ink := Color.WHITE if cloth.get_luminance() < 0.5 else Color("2b2b30")
	m.circle(Vector2(-3, -94), 7.0, Color(ink, 0.85), 12)
	m.circle(Vector2(-3, -94), 4.0, cloth, 10)
	m.rect(Rect2(-12, -83, 18, 3), Color(ink, 0.7))


## Galabeya (or abaya): long straight robe to the ankles, wide at the hem,
## a slit neckline with a braided trim, and a couple of long folds.
static func _robe(m: MeshCanvas, look: Dictionary) -> void:
	var cloth: Color = look.cloth
	var pts := PackedVector2Array([Vector2(-27, -8), Vector2(27, -8), Vector2(23, -96), Vector2(24, -108)])
	for i in 7:
		var a := i / 6.0 * PI
		pts.append(Vector2(cos(a) * 24.0, -110.0 - sin(a) * 9.0))
	pts.append(Vector2(-24, -108))
	pts.append(Vector2(-23, -96))
	m.colored_polygon(pts, cloth)
	m.colored_polygon(PackedVector2Array([Vector2(8, -8), Vector2(27, -8), Vector2(23, -96), Vector2(24, -108), Vector2(14, -117),
		Vector2(10, -96)]), Color(0, 0, 0, SHADE))
	m.colored_polygon(PackedVector2Array([Vector2(-25, -8), Vector2(-18, -8), Vector2(-17, -100), Vector2(-22, -104)]),
		Color(1, 1, 1, LIGHT))
	for x in [-9.0, 4.0, 16.0]:
		m.line(Vector2(x * 0.8, -60), Vector2(x, -10), cloth.darkened(0.18), 1.6)
	m.line(Vector2(-27, -9), Vector2(27, -9), cloth.darkened(0.3), 2.0)
	if look.get("kind", "") == "galabeya":
		m.colored_polygon(PackedVector2Array([Vector2(-6, -120), Vector2(6, -120), Vector2(2, -96), Vector2(-2, -96)]),
			look.skin.darkened(0.1))
		m.polyline(PackedVector2Array([Vector2(-7, -121), Vector2(-3, -95), Vector2(3, -95), Vector2(7, -121)]), cloth.darkened(0.35), 2.0)


static func _neck(m: MeshCanvas, look: Dictionary) -> void:
	var skin: Color = look.skin
	m.colored_polygon(PackedVector2Array([Vector2(-6, -118), Vector2(6, -118), Vector2(6, -132), Vector2(-6, -132)]), skin.darkened(0.12))
	m.colored_polygon(PackedVector2Array([Vector2(-6, -126), Vector2(6, -126), Vector2(6, -132), Vector2(-6, -132)]),
		Color(0, 0, 0, 0.15))

#endregion


#region Head

## Skull and jaw: rounded top, cheekbones, a narrower chin.
static func _head_pts(c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(a) * 16.5, sin(a) * 18.0))
	pts.append(c + Vector2(15.5, 8))
	pts.append(c + Vector2(10, 17))
	pts.append(c + Vector2(3, 21))
	pts.append(c + Vector2(-3, 21))
	pts.append(c + Vector2(-10, 17))
	pts.append(c + Vector2(-15.5, 8))
	return pts


static func _head(m: MeshCanvas, look: Dictionary) -> void:
	var c := Vector2(0, HEAD_Y)
	var skin: Color = look.skin
	var hair: Color = look.hair
	# Ears behind the face.
	for side in [-1.0, 1.0]:
		_ellipse(m, c + Vector2(side * 16.0, 2), Vector2(3.5, 5.5), skin.darkened(0.12))
	m.colored_polygon(_head_pts(c), skin)
	# Shade the far side of the face and under the jaw.
	m.colored_polygon(PackedVector2Array([c + Vector2(7, -16), c + Vector2(16.5, -2), c + Vector2(15.5, 8), c + Vector2(10, 17),
		c + Vector2(3, 21), c + Vector2(6, 6)]), Color(0, 0, 0, 0.16))
	if look.get("beard", false):
		m.colored_polygon(PackedVector2Array([c + Vector2(-15.5, 4), c + Vector2(-10, 17), c + Vector2(-3, 22), c + Vector2(3, 22),
			c + Vector2(10, 17), c + Vector2(15.5, 4), c + Vector2(9, 12), c + Vector2(-9, 12)]), hair)
	elif look.get("kind", "") == "sayed":
		# Sayed's stubble.
		m.colored_polygon(PackedVector2Array([c + Vector2(-15, 5), c + Vector2(-10, 17), c + Vector2(-3, 21), c + Vector2(3, 21),
			c + Vector2(10, 17), c + Vector2(15, 5), c + Vector2(8, 11), c + Vector2(-8, 11)]), Color(hair, 0.28))
	_hair(m, c, look)
	_face(m, c, look)


static func _hair(m: MeshCanvas, c: Vector2, look: Dictionary) -> void:
	var hair: Color = look.hair
	var style: int = look.get("style", 0)
	match style:
		1:
			# Receding: a crown band round the back and sides, bare forehead.
			m.colored_polygon(PackedVector2Array([c + Vector2(-17, 0), c + Vector2(-17, -10), c + Vector2(-12, -16), c + Vector2(-8, -12),
				c + Vector2(-13, -2)]), hair)
			m.colored_polygon(PackedVector2Array([c + Vector2(17, 0), c + Vector2(17, -10), c + Vector2(12, -16), c + Vector2(8, -12),
				c + Vector2(13, -2)]), hair)
		2:
			# Tight curls.
			for i in 11:
				var a := PI + PI * i / 10.0
				m.circle(c + Vector2(cos(a) * 15.0, sin(a) * 16.0 - 2.0), 5.5, hair, 8)
			m.circle(c + Vector2(0, -15), 7.0, hair, 8)
		3:
			# Swept back, a little volume on top.
			m.colored_polygon(PackedVector2Array([c + Vector2(-17, -2), c + Vector2(-17, -12), c + Vector2(-10, -20), c + Vector2(2, -23),
				c + Vector2(13, -20), c + Vector2(18, -10), c + Vector2(17, -2), c + Vector2(12, -12), c + Vector2(-2, -14),
				c + Vector2(-12, -10)]), hair)
		_:
			m.colored_polygon(PackedVector2Array([c + Vector2(-17, -2), c + Vector2(-17, -12), c + Vector2(-11, -19), c + Vector2(0, -21),
				c + Vector2(11, -19), c + Vector2(17, -12), c + Vector2(17, -2), c + Vector2(13, -11), c + Vector2(4, -13),
				c + Vector2(-6, -12), c + Vector2(-13, -10)]), hair)
	# Grey at the temples for the older ones.
	if hair.get_luminance() > 0.3:
		m.line(c + Vector2(-16, -6), c + Vector2(-15, 0), hair.lightened(0.2), 2.0)


static func _face(m: MeshCanvas, c: Vector2, look: Dictionary) -> void:
	var mood: float = look.get("mood", 0.0)
	var hair: Color = look.hair
	var skin: Color = look.skin
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 7.0, -2)
		_ellipse(m, e, Vector2(3.4, 2.2), Color("f1ede4"))
		m.circle(e + Vector2(0.6, 0), 1.7, Color("2a1c12"), 8)
		# Brows tilt down to the middle when they're cross.
		m.line(c + Vector2(side * 3.5, -7 + (2.5 if mood < 0 else 0.0)), c + Vector2(side * 11.0, -8 - (1.0 if mood > 0 else 0.0)),
			hair.darkened(0.2), 2.4)
	# Nose: a shaded wedge on the far side and a highlight on the bridge.
	m.colored_polygon(PackedVector2Array([c + Vector2(1, -2), c + Vector2(4, 7), c + Vector2(0, 8)]), skin.darkened(0.2))
	m.line(c + Vector2(-0.5, -1), c + Vector2(-0.5, 6), skin.lightened(0.15), 1.2)
	if look.get("moustache", false):
		m.colored_polygon(PackedVector2Array([c + Vector2(-8, 11), c + Vector2(0, 9), c + Vector2(8, 11), c + Vector2(7, 13.5),
			c + Vector2(0, 12), c + Vector2(-7, 13.5)]), hair)
	var smile := 2.0 * mood
	m.polyline(PackedVector2Array([c + Vector2(-4.5, 15 - smile * 0.5), c + Vector2(0, 15 + smile * 0.6), c + Vector2(4.5, 15 - smile * 0.5)]),
		Color("6a2e22"), 1.8)
	if look.get("glasses", false):
		for side in [-1.0, 1.0]:
			var g := PackedVector2Array()
			for i in 13:
				var a := TAU * i / 12.0
				g.append(c + Vector2(side * 7.0 + cos(a) * 5.2, -2 + sin(a) * 4.2))
			m.polyline(g, Color("1d1612"), 1.4)
		m.line(c + Vector2(-2, -2), c + Vector2(2, -2), Color("1d1612"), 1.4)


static func _kufi(m: MeshCanvas) -> void:
	var c := Vector2(0, HEAD_Y)
	_ellipse(m, c + Vector2(0, -16), Vector2(17, 6), Color("f1ede4"))
	m.colored_polygon(PackedVector2Array([c + Vector2(-17, -16), c + Vector2(17, -16), c + Vector2(15, -26), c + Vector2(-15, -26)]),
		Color("f1ede4"))
	m.colored_polygon(PackedVector2Array([c + Vector2(6, -16), c + Vector2(17, -16), c + Vector2(15, -26), c + Vector2(8, -26)]),
		Color(0, 0, 0, 0.1))
	for k in 4:
		m.line(c + Vector2(-13 + k * 8, -18), c + Vector2(-12 + k * 8, -24), Color(0.8, 0.78, 0.7), 1.0)


## Scarf framing the face, falling over the shoulders.
static func _hijab_head(m: MeshCanvas, look: Dictionary) -> void:
	var c := Vector2(0, HEAD_Y)
	var scarf: Color = look.extra
	m.colored_polygon(PackedVector2Array([Vector2(-28, -106), Vector2(28, -106), Vector2(26, -124), Vector2(-26, -124)]), scarf.darkened(0.1))
	_ellipse(m, c + Vector2(0, -1), Vector2(22, 25), scarf)
	m.colored_polygon(PackedVector2Array([c + Vector2(10, -20), c + Vector2(22, -4), c + Vector2(20, 14), c + Vector2(26, 42),
		c + Vector2(10, 40)]), scarf.darkened(0.18))
	var face := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		face.append(c + Vector2(cos(a) * 13.0, sin(a) * 16.0 + 2.0))
	m.colored_polygon(face, look.skin)
	m.polyline(PackedVector2Array([c + Vector2(-14, 6), c + Vector2(-12, -10), c + Vector2(0, -15), c + Vector2(12, -10), c + Vector2(14, 6)]),
		scarf.darkened(0.3), 1.5)
	var f := look.duplicate()
	f.moustache = false
	f.glasses = false
	_face(m, c + Vector2(0, 2), f)


## The قهوجي's towel over Sayed's left shoulder.
static func _towel(m: MeshCanvas) -> void:
	m.colored_polygon(PackedVector2Array([Vector2(-26, -104), Vector2(-12, -120), Vector2(-4, -118), Vector2(-14, -100),
		Vector2(-16, -76), Vector2(-24, -78)]), Color("f1ede4"))
	for k in 3:
		m.line(Vector2(-24 + k * 3, -94 + k * 6), Vector2(-15 + k * 2, -98 + k * 6), Color("c23b2a", 0.7), 2.0)

#endregion


#region Limbs

## Limb k (0 left leg, 1 right leg, 2 left arm, 3 right arm) in its own
## space with the hip or shoulder at the origin. Robes show only the feet.
static func build_limb(m: MeshCanvas, look: Dictionary, k: int) -> void:
	var kind: String = look.get("kind", "shirt")
	var robe := kind == "galabeya" or kind == "hijab"
	if k < 2:
		var shoe := Color("1a1a1e")
		if kind == "galabeya":
			shoe = Color("5a3a28")
		elif kind == "tshirt":
			shoe = Color("e9e6df")
		if not robe:
			var tr: Color = look.trousers
			var leg := tr.darkened(0.1 if k == 0 else 0.0)
			m.colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(9, 0), Vector2(8, 30), Vector2(7, 56), Vector2(-7, 56),
				Vector2(-8, 30)]), leg)
			m.colored_polygon(PackedVector2Array([Vector2(3, 0), Vector2(9, 0), Vector2(8, 30), Vector2(7, 56), Vector2(3, 56)]),
				Color(0, 0, 0, 0.15))
			m.line(Vector2(-2, 26), Vector2(3, 32), tr.darkened(0.25), 1.2)
		# Shoe: sole, toe cap pointing a little toward us, a shine.
		m.colored_polygon(PackedVector2Array([Vector2(-7, 54), Vector2(7, 54), Vector2(12, 58), Vector2(12, 62), Vector2(-8, 62),
			Vector2(-8, 57)]), shoe)
		m.rect(Rect2(-8, 61, 20, 2.5), shoe.darkened(0.4))
		m.line(Vector2(-3, 56), Vector2(5, 56), Color(1, 1, 1, 0.25), 1.2)
		if kind == "tshirt":
			m.line(Vector2(-8, 60), Vector2(12, 60), Color("c8322b"), 1.5)
	else:
		var cloth: Color = look.cloth
		var sleeve := cloth.darkened(0.05 if k == 2 else 0.18)
		var skin: Color = look.skin
		var short := kind == "tshirt"
		var s := -1.0 if k == 2 else 1.0
		var elbow := Vector2(3.0 * s, 28)
		var wrist := Vector2(2.0 * s, 50)
		# Upper arm and forearm, tapered, with a cuff at the wrist.
		m.colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), elbow + Vector2(5.5, 0), elbow + Vector2(-5.5, 0)]), sleeve)
		var fore := skin if short else sleeve
		m.colored_polygon(PackedVector2Array([elbow + Vector2(-5.5, 0), elbow + Vector2(5.5, 0), wrist + Vector2(4.5, 0),
			wrist + Vector2(-4.5, 0)]), fore)
		if short:
			m.colored_polygon(PackedVector2Array([Vector2(-7.5, 0), Vector2(7.5, 0), Vector2(7, 16), Vector2(-7, 16)]), sleeve)
		elif kind == "shirt" or kind == "sayed":
			m.rect(Rect2(wrist.x - 5, wrist.y - 5, 10, 4), cloth.lightened(0.1))
		# Hand with the thumb toward us.
		_ellipse(m, wrist + Vector2(0, 5), Vector2(5.5, 6.5), skin)
		_ellipse(m, wrist + Vector2(-3.5 * s, 2), Vector2(2.2, 3.5), skin.darkened(0.08))
		m.line(wrist + Vector2(-2, 9), wrist + Vector2(2, 9), skin.darkened(0.2), 1.0)

#endregion


static func _ellipse(m: MeshCanvas, c: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	m.colored_polygon(pts, color)
