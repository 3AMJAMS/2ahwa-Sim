class_name StreetCat
extends Node3D
## The street's ginger-and-white cat, asleep on FIFI's roof, in blocks:
## ginger back with darker tabby stripes, white chest, paws and a blaze down
## the face, a ringed tail, pink nose, amber eyes. It breathes; now and then
## an ear twitches or the tail tip flicks; every so often it lifts its head,
## looks round, blinks (sometimes yawns) and settles back down.
## Lies along +z (tail at -z, head at +z), feet at the origin.
## Walking, jumping down and wandering the pavement come later (roadmap).

const U := 0.035
const GINGER := Color("d9822b")
const GINGER_LIGHT := Color("f0a24c")
const GINGER_DARK := Color("b0601c")
const WHITE := Color("f6f1e7")
const PINK := Color("e89a9a")
const EYE := Color("d9a030")

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _body := MeshInstance3D.new()
var _head := Node3D.new()
var _faces: Array[MeshInstance3D] = []   # asleep, awake, yawning
var _tail := Node3D.new()
var _tip := Node3D.new()
## 0 asleep with the head down, 1 head up and looking round.
var _awake := 0.0
var _look := 0.0
var _flick := 0.0
var _ear := 0.0
var _next_ear := 3.0
var _next_flick := 5.0
var _next_wake := 14.0
var _busy := false


func _ready() -> void:
	_rng.randomize()
	_next_wake = _rng.randf_range(8.0, 16.0)
	var v := Vox.new()
	_build_body(v)
	_body.mesh = v.commit()
	add_child(_body)
	_head.position = _u(Vector3(0, 8, 1.5))
	add_child(_head)
	for mode in ["asleep", "awake", "yawn"]:
		_build_head(v, mode)
		var mi := MeshInstance3D.new()
		mi.mesh = v.commit()
		mi.visible = mode == "asleep"
		_head.add_child(mi)
		_faces.append(mi)
	_tail.position = _u(Vector3(3.5, -6, 1))
	add_child(_tail)
	_build_tail(v, [Vector3(0, 0, 0), Vector3(0.5, 3, 0), Vector3(0.5, 6, 0)], 0)
	var base := MeshInstance3D.new()
	base.mesh = v.commit()
	_tail.add_child(base)
	_tip.position = _u(Vector3(0.5, 7, 0))
	_tail.add_child(_tip)
	_build_tail(v, [Vector3(0, 0, 0), Vector3(-0.5, 2.5, 0), Vector3(-1.5, 4.5, 0)], 4)
	var tip := MeshInstance3D.new()
	tip.mesh = v.commit()
	_tip.add_child(tip)


## Body units (x across, y along toward the head, z up) to the node's space.
func _u(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, p.y) * U


func _b(v: Vox, lo: Vector3, hi: Vector3, c: Color) -> void:
	v.box(_u(lo), _u(hi), c)


func _build_body(v: Vox) -> void:
	# Curled loaf: ginger back with tabby stripes, white chest and paws.
	_b(v, Vector3(-4, -6, 0), Vector3(4, 7, 6), GINGER)
	_b(v, Vector3(-3.6, -6.4, 0), Vector3(3.6, -5.8, 5), GINGER)
	for y in [-4.0, -1.0, 2.0, 5.0]:
		_b(v, Vector3(-4.05, y, 3), Vector3(4.05, y + 1, 6.05), GINGER_DARK)
	_b(v, Vector3(-3.4, -5, 6), Vector3(3.4, 6, 6.6), GINGER_LIGHT)
	_b(v, Vector3(-3, 5, 0), Vector3(3, 8, 4.5), WHITE)
	_b(v, Vector3(4.0, -4, 0), Vector3(4.05, 5, 2), WHITE)
	# Front paws tucked forward, a hind paw showing.
	for x in [0.6, -2.8]:
		_b(v, Vector3(x, 8.5, 0), Vector3(x + 2.2, 11.5, 1.6), WHITE)
	_b(v, Vector3(-4.3, -4.5, 0), Vector3(-2, -1.5, 1.8), WHITE)


func _build_head(v: Vox, mode: String) -> void:
	# Head in its own space: back of the head at the origin, facing +y.
	var c := Vector3(0, 0, 0)
	_b(v, c + Vector3(-3.5, 0, 0), c + Vector3(3.5, 5, 6), GINGER)
	_b(v, c + Vector3(-3.6, 0.5, 4.5), c + Vector3(3.6, 3.5, 5), GINGER_DARK)
	var f := c.y + 5
	_b(v, Vector3(-0.8, f, 2.5), Vector3(0.8, f + 0.1, 6), WHITE)
	_b(v, Vector3(-2, f, 0), Vector3(2, f + 1, 2.6), WHITE)
	_b(v, Vector3(-0.6, f + 1, 1.8), Vector3(0.6, f + 1.2, 2.6), PINK)
	if mode == "yawn":
		_b(v, Vector3(-1.2, f + 0.9, 0.2), Vector3(1.2, f + 1.05, 1.6), Color("8a2a3a"))
		_b(v, Vector3(-0.8, f + 1.0, 0.4), Vector3(0.8, f + 1.1, 1.0), PINK)
	for side in [-1.0, 1.0]:
		var ex: float = side * 2.0
		if mode == "awake":
			_b(v, Vector3(ex - 0.9, f, 3), Vector3(ex + 0.9, f + 0.1, 4.4), EYE)
			_b(v, Vector3(ex - 0.2, f + 0.1, 3), Vector3(ex + 0.2, f + 0.18, 4.4), Color("1a1208"))
		else:
			_b(v, Vector3(ex - 1, f, 3.4), Vector3(ex + 1, f + 0.1, 3.8), Color("5a3014"))
		# Ears with pink insides.
		_b(v, Vector3(ex - 1.2, 1.5, 6), Vector3(ex + 1.2, 3, 7.6), GINGER)
		_b(v, Vector3(ex - 0.6, 1.8, 7.6), Vector3(ex + 0.6, 2.8, 8.6), GINGER)
		_b(v, Vector3(ex - 0.7, 3, 6.2), Vector3(ex + 0.7, 3.1, 7.4), PINK)
		# Whiskers.
		_b(v, Vector3(side * 2, f + 0.4, 1.2), Vector3(side * 5.5, f + 0.5, 1.35), Color(0.95, 0.95, 0.92))
		_b(v, Vector3(side * 2, f + 0.4, 1.8), Vector3(side * 5.2, f + 0.5, 1.95), Color(0.95, 0.95, 0.92))


## Ringed tail through the given points (block units), from `ring` on.
func _build_tail(v: Vox, pts: Array, ring: int) -> void:
	var k := ring
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := int(ceil(a.distance_to(b) / 1.4))
		for j in n:
			var c := a.lerp(b, float(j) / n)
			var col := GINGER if k % 2 == 0 else GINGER_LIGHT
			_b(v, c - Vector3(0.8, 0.8, 0), c + Vector3(0.8, 0.8, 1.6), col)
			k += 1
	if ring > 0:
		var tip: Vector3 = pts[pts.size() - 1]
		_b(v, tip - Vector3(0.8, 0.8, 0), tip + Vector3(0.8, 0.8, 1.6), GINGER_DARK)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_next_ear -= delta
	_next_flick -= delta
	_next_wake -= delta
	if _next_ear <= 0.0:
		_next_ear = _rng.randf_range(3.0, 8.0)
		var t := create_tween()
		t.tween_property(self, "_ear", 1.0, 0.07)
		t.tween_property(self, "_ear", 0.0, 0.25)
	if _next_flick <= 0.0:
		_next_flick = _rng.randf_range(4.0, 9.0)
		var t := create_tween()
		t.tween_property(self, "_flick", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "_flick", -0.6, 0.22).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "_flick", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	if _next_wake <= 0.0 and not _busy:
		_wake_up()
	# Breathing, the head's pose, the tail.
	_body.scale = Vector3(1.0 + 0.025 * sin(_t * TAU / 3.2), 1.0 + 0.03 * sin(_t * TAU / 3.2), 1.0)
	_head.rotation = Vector3(-0.35 * (1.0 - _awake) + 0.15 * _awake, _look * 0.8, _ear * 0.08)
	_head.position = _u(Vector3(0, 8, 1.5 + 2.5 * _awake))
	_tail.rotation.y = sin(_t * 0.6) * 0.08 + _flick * 0.2
	_tip.rotation.y = _flick * 0.9 + sin(_t * 1.1) * 0.1


## Lifts its head, looks round, blinks, maybe yawns, and settles back.
func _wake_up() -> void:
	_busy = true
	var t := create_tween()
	t.tween_property(self, "_awake", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_eyes.bind(1))
	t.tween_property(self, "_look", -0.6, 0.8).set_trans(Tween.TRANS_SINE).set_delay(0.3)
	t.tween_callback(_eyes.bind(0)).set_delay(0.6)
	t.tween_callback(_eyes.bind(1)).set_delay(0.15)
	t.tween_property(self, "_look", 0.5, 1.0).set_trans(Tween.TRANS_SINE).set_delay(0.5)
	if _rng.randf() < 0.5:
		t.tween_callback(_eyes.bind(2)).set_delay(0.3)
		t.tween_interval(0.9)
		t.tween_callback(_eyes.bind(1))
	t.tween_property(self, "_look", 0.0, 0.6).set_delay(0.6)
	t.tween_callback(_eyes.bind(0))
	t.tween_property(self, "_awake", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		_busy = false
		_next_wake = _rng.randf_range(14.0, 26.0))


func _eyes(mode: int) -> void:
	for i in _faces.size():
		_faces[i].visible = i == mode
