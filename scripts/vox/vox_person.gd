class_name VoxPerson
extends Node3D
## A blocky person: torso, head, two arms and two legs, each baked into its
## own mesh and hinged at the neck, shoulder or hip so they can walk, look
## round, wave, sip and sit. Built from a "look" dictionary (random_look()
## rolls one: skin tone, body, age, outfit, hair, headwear, face, things
## they carry), so no two customers need be alike.
##
## Body units: x across, y toward the front, z up; one unit is 3.5 cm and a
## grown-up stands about 48 units (1.7 m). The figure faces +Z, feet at the
## origin.

const U := 0.035
const HIP := 18.0
const SHOULDER := 33.0
const NECK := 35.0

const SKINS := ["f3d2b3", "ecc09a", "e0ae84", "d39a6c", "c68c62", "b97a52", "a86f48", "946040", "7e5236", "6a442c", "553522"]
const HAIRS := ["1d1612", "231a14", "2a1f18", "3a2a1c", "4a3322", "5a3a22", "7a4a2a"]
const GREYS := ["6a6560", "8a8680", "b8b4ae", "d8d4cc"]
const SHIRTS := ["2f5f8a", "7a2e22", "3d5a45", "5a4a6a", "8a6a3a", "c9c2b0", "e9e6df", "a8c8e8", "d8b8a0", "4a6a8a",
	"6a2a3a", "2a4a3a", "c8a870", "e8d8c8", "8aa0b8"]
const TEES := ["c8322b", "2b2b30", "e9e6df", "3b8a5a", "2a6ab0", "f2d24a", "e07a2a", "7a3a8a", "3ab0b0", "f0a0b0",
	"8a8680", "1f3a6a"]
const TROUSERS := ["2b2f3a", "3a3a40", "4a3f35", "2e2e36", "5a5048", "6a6a70", "1d1d22", "8a7a60"]
const JEANS := ["355a8a", "2a3a5a", "4a6a9a", "1f2a44", "5a7aa8"]
const GALABEYA := ["d8d2c2", "8a8474", "5a6a7a", "b8a888", "6a4a3a", "f1ede4", "3a4a5a", "7a6a50", "4a5a4a", "9aa0a8"]
const ABAYA := ["1c1c24", "141418", "26263a", "3a2a4a", "2a3a4a", "4a2a2a", "2a2a2a"]
const SCARVES := ["c86a8a", "e0c8a8", "5a8aa8", "8a6ab0", "d8b060", "2a4a6a", "f1ede4", "6a2a4a", "a83a3a", "3a7a6a",
	"e8a0b0", "b0c8e0", "8a5a3a", "d87a3a", "1c1c24"]
const DRESS := ["1c1c24", "3a2a4a", "2a3a4a", "5a2a3a", "2a4a3a", "6a5a3a"]

var look: Dictionary = {}
## Walk cycle phase (radians) and how much the stride shows (0 still, 1 walking).
var stride := 0.0

var rig := Node3D.new()
var torso := MeshInstance3D.new()
var head := Node3D.new()
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
## A child walking alongside, holding the hand (mothers sometimes bring one).
var companion: VoxPerson
## What they're doing while standing about ("" just waiting; "phone",
## "watch", "arms_crossed", "hips", "scratch", "stretch", "wave", "chat",
## "tap_foot", "sip"); idle() blends the arms and legs into it.
var activity := ""
## Where the head is turned, relative to the body (radians; + is to their
## left), and tipped (+ looks down). idle() eases the head there.
var look_yaw := 0.0
var look_pitch := 0.0

var _rng := RandomNumberGenerator.new()
var _parts := {}
var _cur := ""
var _t := 0.0


## `pose`: "stand", "sit" (thighs forward, for chairs) or "drive" (sat, no legs).
func build(look_in: Dictionary, pose := "stand") -> void:
	look = look_in
	_rng.seed = int(look.get("seed", 1))
	for c in get_children():
		c.queue_free()
	rig = Node3D.new()
	add_child(rig)
	var s := 1.0
	if look.get("kid", false):
		s = 0.72
	rig.scale = Vector3.ONE * s * float(look.get("height", 1.0))
	if look.get("heavy", false):
		rig.scale.x *= 1.12
		rig.scale.z *= 1.12
	elif look.get("slim", false):
		rig.scale.x *= 0.92
	_parts.clear()
	for part in ["torso", "head", "arm_l", "arm_r", "leg_l", "leg_r"]:
		_parts[part] = {"vox": Vox.new(), "pivot": _pivot_of(part)}
	_build_look(pose)
	torso = _bake("torso", rig)
	head = _hinge("head", rig)
	arms = [_hinge("arm_l", rig), _hinge("arm_r", rig)]
	legs = []
	if pose != "drive":
		legs = [_hinge("leg_l", rig), _hinge("leg_r", rig)]
	if look.get("hunch", false):
		head.rotation.x = 0.18
	if look.has("companion") and pose == "stand":
		companion = VoxPerson.new()
		companion.position = Vector3(-0.42, 0, 0.04)
		add_child(companion)
		companion.build(look.companion)


## Bakes the face again with a new mood (-1 cross, 0, 1 pleased).
func set_mood(mood: float) -> void:
	if look.is_empty() or is_equal_approx(float(look.get("mood", 0.0)), mood):
		return
	look.mood = mood
	_parts["head"] = {"vox": Vox.new(), "pivot": _pivot_of("head")}
	_cur = "head"
	_rng.seed = int(look.get("seed", 1)) + 7
	_head_parts()
	var mi := head.get_child(0) as MeshInstance3D
	mi.mesh = (_parts["head"].vox as Vox).commit()


## One frame of the walk cycle: legs and arms swing, the body bobs.
func walk(delta: float, speed := 1.0) -> void:
	_t += delta
	stride += delta * 8.5 * speed
	var swing := sin(stride) * 0.55
	if legs.size() == 2:
		legs[0].rotation.x = swing
		legs[1].rotation.x = -swing
	arms[0].rotation.x = -swing * 0.8
	arms[0].rotation.z = 0.0
	if activity == "sip":
		# Walking off with the drink: held up, now and then to the lips.
		var lift := 0.5 + 0.5 * maxf(0.0, sin(_t * 0.9))
		arms[1].rotation.x = lerpf(-0.9, -1.75, lift)
		arms[1].rotation.z = 0.3
		head.rotation.x = -0.2 * lift
	else:
		arms[1].rotation.x = swing * 0.8
		arms[1].rotation.z = 0.0
		head.rotation.x = lerpf(head.rotation.x, 0.0, minf(1.0, delta * 4.0))
	head.rotation.y = lerp_angle(head.rotation.y, look_yaw * 0.5, minf(1.0, delta * 3.0))
	rig.position.y = absf(cos(stride)) * 0.03
	rig.rotation.z = sin(stride) * 0.03
	if companion:
		companion.walk(delta, speed * 1.3)


## Standing about: weight shifts from foot to foot, faster the more
## impatient (`urgency` 0..1); the head eases toward look_yaw/look_pitch
## and the arms and legs into the current `activity`.
func idle(delta: float, urgency := 0.0) -> void:
	_t += delta
	var k := 1.5 + 3.0 * urgency
	rig.position.y = -absf(sin(_t * (2.0 + 5.0 * urgency))) * (0.004 + 0.012 * urgency)
	rig.rotation.z = sin(_t * k) * 0.02 * (0.3 + urgency)
	# [left arm (x, z), right arm (x, z), right leg x] for the activity.
	var al := Vector2(sin(_t * k * 0.7) * 0.05 * urgency, 0.0)
	var ar := Vector2(-al.x, 0.0)
	var leg_r := 0.0
	var nod := 0.0
	match activity:
		"phone":
			ar = Vector2(-1.25 + sin(_t * 9.0) * 0.03, 0.35)
			nod = 0.42
		"watch":
			al = Vector2(-1.15, -0.45)
			nod = 0.4
		"arms_crossed":
			al = Vector2(-0.75, 0.75)
			ar = Vector2(-0.75, -0.75)
		"hips":
			al = Vector2(0.15, -0.55)
			ar = Vector2(0.15, 0.55)
		"scratch":
			ar = Vector2(-2.75, 0.45 + sin(_t * 14.0) * 0.08)
			nod = 0.15
		"stretch":
			al = Vector2(-2.9, -0.2)
			ar = Vector2(-2.9, 0.2)
			nod = -0.3
		"wave":
			ar = Vector2(-2.65, 0.25 + sin(_t * 11.0) * 0.35)
		"chat":
			ar = Vector2(-0.45 - 0.35 * maxf(0.0, sin(_t * 2.3)), 0.2)
			nod = 0.08 * sin(_t * 5.0)
		"tap_foot":
			leg_r = -0.18 * absf(sin(_t * 7.0))
			al = Vector2(0.1, -0.5)
			ar = Vector2(0.1, 0.5)
		"sip":
			ar = Vector2(-1.75, 0.3)
			nod = -0.2
	var e := minf(1.0, delta * 6.0)
	if arms.size() == 2:
		arms[0].rotation.x = lerpf(arms[0].rotation.x, al.x, e)
		arms[0].rotation.z = lerpf(arms[0].rotation.z, al.y, e)
		arms[1].rotation.x = lerpf(arms[1].rotation.x, ar.x, e)
		arms[1].rotation.z = lerpf(arms[1].rotation.z, ar.y, e)
	if legs.size() == 2:
		legs[0].rotation.x = lerpf(legs[0].rotation.x, 0.0, minf(1.0, delta * 8.0))
		legs[1].rotation.x = lerpf(legs[1].rotation.x, leg_r, minf(1.0, delta * 12.0))
	var e_head := minf(1.0, delta * 4.0)
	head.rotation.y = lerp_angle(head.rotation.y, clampf(look_yaw, -1.2, 1.2) + sin(_t * 1.3) * 0.04, e_head)
	head.rotation.x = lerpf(head.rotation.x, look_pitch + nod, e_head)
	if companion:
		companion.look_yaw = sin(_t * 0.4) * 0.6
		companion.idle(delta, urgency * 0.5)


## Arm `side` (0 left, 1 right) raised forward by `amount` (0..1): waving
## down FIFI, taking the drink, lifting a glass to the lips.
func raise_arm(side: int, amount: float) -> void:
	if side < arms.size():
		arms[side].rotation.x = -amount * 1.9
		arms[side].rotation.z = amount * (0.25 if side == 1 else -0.25)


## Top of the head in local space (for bubbles and patience bars).
func head_top() -> Vector3:
	return Vector3(0, 52.0 * U * rig.scale.y, 0)


#region Looks

## A random passer-by. `man_share` tilts who turns up.
static func random_look(rng: RandomNumberGenerator, man_share := 0.62) -> Dictionary:
	var pick := func(a: Array) -> Variant: return a[rng.randi() % a.size()]
	var col := func(a: Array) -> Color: return Color(a[rng.randi() % a.size()])
	var L := {"seed": rng.randi(), "skin": col.call(SKINS), "hc": col.call(HAIRS), "height": rng.randf_range(0.94, 1.06)}
	var old := rng.randf() < 0.2
	if old:
		L.hc = col.call(GREYS)
	if rng.randf() < 0.12:
		L.heavy = true
	elif rng.randf() < 0.15:
		L.slim = true
	var roll := rng.randf()
	if roll < man_share:
		var kind: String = pick.call(["casual", "casual", "casual", "shirt", "shirt", "galabeya", "galabeya", "suit",
			"worker", "rider", "student", "fan", "sheikh", "tourist", "baker", "coat", "tracksuit"])
		match kind:
			"casual":
				L.top = pick.call(["tshirt", "tshirt", "polo", "sweater", "jacket"])
				L.cloth = col.call(TEES if L.top in ["tshirt", "polo"] else SHIRTS)
				L.bottom = pick.call(["jeans", "jeans", "trousers", "shorts"] if not old else ["trousers"])
				L.pants = col.call(TROUSERS)
				L.shoe = pick.call(["sneakers", "sneakers", "shoes", "sandals"])
				L.hair = pick.call(["short", "curly", "buzz", "spiky", "swept", "fade"])
				if rng.randf() < 0.25:
					L.head = pick.call(["cap", "cap_back", "beanie"])
			"shirt":
				L.top = "shirt"
				L.cloth = col.call(SHIRTS)
				L.bottom = "trousers"
				L.pants = col.call(TROUSERS)
				L.shoe = "shoes"
				L.hair = pick.call(["short", "receding", "swept", "short"] if not old else ["receding", "bald", "short"])
				if rng.randf() < 0.3:
					L.pattern = pick.call(["check", "stripe"])
			"galabeya":
				L.robe = "galabeya"
				L.cloth = col.call(GALABEYA)
				L.shoe = pick.call(["sandals", "sandals", "shoes"])
				L.hair = "short"
				L.head = pick.call(["kufi", "turban", "none", "shawl"])
				if rng.randf() < 0.4:
					L.pattern = "stripe"
			"suit":
				L.top = "suit"
				L.cloth = col.call(["2a2e3a", "3a3a40", "2a3a4a", "4a3f35", "1d1d22"])
				L.shirt = col.call(["e9eef4", "f1ede4", "a8c8e8"])
				L.tie = col.call(["8a2a2a", "2a4a8a", "3a3a40", "6a2a5a", "c9a24a"])
				L.bottom = "trousers"
				L.pants = L.cloth
				L.shoe = "shoes"
				L.hair = pick.call(["swept", "short", "receding"])
				L.extra = [pick.call(["briefcase", "phone", "newspaper"])]
			"worker":
				L.top = "vest"
				L.cloth = col.call(SHIRTS)
				L.bottom = "trousers"
				L.pants = col.call(["4a4038", "5a5048", "3a3a40"])
				L.shoe = "boots"
				L.head = pick.call(["hardhat", "hardhat", "cap"])
				L.hair = "short"
			"rider":
				L.top = "jacket"
				L.cloth = col.call(["c8322b", "2a6ab0", "e07a2a", "3b8a5a", "2b2b30"])
				L.bottom = "jeans"
				L.shoe = "boots"
				L.head = "moto"
				L.extra = ["delivery_box"]
			"student":
				L.top = "school"
				L.cloth = col.call(["a8c8e8", "f1ede4", "e8e4dc"])
				L.bottom = "trousers"
				L.pants = col.call(["6a6a70", "2a3a6a", "3a3a40"])
				L.shoe = "shoes"
				L.hair = pick.call(["short", "spiky", "curly"])
				L.extra = ["backpack"]
				L.kid = rng.randf() < 0.5
				old = false
				L.hc = col.call(HAIRS)
			"fan":
				L.top = "jersey"
				L.cloth = col.call(["c8322b", "f1ede4", "c8322b"])
				L.bottom = pick.call(["shorts", "jeans"])
				L.pants = Color("f2efe8")
				L.shoe = "sneakers"
				L.hair = pick.call(["buzz", "fade", "spiky"])
			"sheikh":
				L.robe = "kaftan"
				L.cloth = col.call(["3a2e4a", "2a3a4a", "4a3a2a", "1c1c24"])
				L.head = "tarboush"
				L.beard = "short"
				L.shoe = "shoes"
				L.extra = ["book"]
			"tourist":
				L.top = "tshirt"
				L.cloth = col.call(["7ab0c8", "e9e6df", "f2d24a", "f0a0b0"])
				L.bottom = "shorts"
				L.pants = Color("c8b890")
				L.head = "sunhat"
				L.hair = "short"
				L.skin = Color(pick.call(SKINS.slice(0, 3)))
				L.hc = Color(pick.call(["c89a5a", "e0c080", "8a5a3a", "2a1f18"]))
				L.shoe = "sandals"
				L.sunglasses = true
				L.extra = ["camera"]
			"baker":
				L.top = "shirt"
				L.cloth = Color("e9e6df")
				L.bottom = "trousers"
				L.pants = col.call(TROUSERS)
				L.head = "bread"
				L.hair = "short"
				L.shoe = "sandals"
			"coat":
				L.top = "coat"
				L.cloth = Color("f4f2ee")
				L.shirt = col.call(["a8c8e8", "e9eef4", "c9c2b0"])
				L.bottom = "trousers"
				L.pants = col.call(TROUSERS)
				L.shoe = "shoes"
				L.hair = pick.call(["short", "swept", "receding"])
				L.glasses = rng.randf() < 0.6
			"tracksuit":
				L.top = "tracksuit"
				L.cloth = col.call(["2a3a6a", "2b2b30", "3b6a4a", "6a2a3a", "4a4a52"])
				L.bottom = "tracksuit"
				L.shoe = "sneakers"
				L.hair = pick.call(["spiky", "buzz", "curly", "fade"])
		if not L.has("moustache"):
			L.moustache = rng.randf() < (0.7 if old else 0.45)
		if not L.has("beard"):
			var b := rng.randf()
			L.beard = "white" if old and b < 0.35 else ("short" if b < 0.25 else ("stubble" if b < 0.45 else ""))
		if L.get("beard", "") == "white":
			L.hc = Color(pick.call(GREYS.slice(2)))
		if old and not L.has("hunch"):
			L.hunch = rng.randf() < 0.4
			if L.hunch and not L.has("extra"):
				L.extra = [pick.call(["cane", "beads"])]
	else:
		var kind: String = pick.call(["hijab_abaya", "hijab_abaya", "hijab_modern", "hijab_modern", "hijab_modern",
			"niqab", "uncovered", "auntie", "mother", "student_girl"])
		L.woman = true
		L.shoe = "flats"
		match kind:
			"hijab_abaya":
				L.robe = "abaya"
				L.cloth = col.call(ABAYA)
				L.head = "hijab"
				L.scarf = col.call(SCARVES)
			"hijab_modern":
				L.top = pick.call(["blouse", "longtop", "cardigan"])
				L.cloth = col.call(SHIRTS + TEES)
				L.bottom = pick.call(["skirt", "jeans", "skirt"])
				L.pants = col.call(["3a3a5a", "2a3a4a", "5a4a3a", "1c1c24", "8a6a8a"])
				L.head = "hijab"
				L.scarf = col.call(SCARVES)
				L.shoe = pick.call(["flats", "sneakers"])
			"niqab":
				L.robe = "abaya"
				L.cloth = col.call(["141418", "1c1c24"])
				L.head = "niqab"
				L.scarf = L.cloth
			"uncovered":
				L.top = pick.call(["blouse", "tshirt", "longtop"])
				L.cloth = col.call(SHIRTS + TEES)
				L.bottom = pick.call(["jeans", "skirt"])
				L.pants = col.call(["3a3a5a", "1c1c24", "5a4a3a"])
				L.hair = pick.call(["long", "ponytail", "bun", "bob"])
				L.shoe = pick.call(["flats", "sneakers"])
			"auntie":
				L.robe = "dress"
				L.cloth = col.call(DRESS)
				L.head = "headscarf"
				L.scarf = col.call(["1c1c24", "3a2a2a", "2a2a3a"])
				L.hc = col.call(GREYS)
				L.hunch = rng.randf() < 0.5
				L.extra = [pick.call(["basket", "basket", "handbag"])]
				old = true
			"mother":
				L.robe = "abaya"
				L.cloth = col.call(ABAYA)
				L.head = "hijab"
				L.scarf = col.call(SCARVES)
				var kid := random_look(rng, 0.5)
				kid.erase("companion")
				kid.kid = true
				kid.hunch = false
				kid.extra = []
				kid.skin = L.skin
				kid.hc = col.call(HAIRS)
				kid.moustache = false
				kid.beard = ""
				L.companion = kid
			"student_girl":
				L.top = "school"
				L.cloth = col.call(["f1ede4", "a8c8e8"])
				L.bottom = "skirt"
				L.pants = col.call(["2a3a6a", "3a3a40", "5a2a3a"])
				L.head = "hijab"
				L.scarf = col.call(["f1ede4", "2a3a6a", "e8a0b0"])
				L.extra = ["backpack"]
				L.kid = rng.randf() < 0.4
				L.shoe = "shoes"
		if not L.has("extra"):
			var bag: float = rng.randf()
			L.extra = ["handbag"] if bag < 0.45 else (["phone"] if bag < 0.65 else [])
	if not L.has("extra"):
		var e := rng.randf()
		L.extra = [pick.call(["phone", "keys", "newspaper", "beads", "backpack", "headphones"])] if e < 0.45 else []
	if not L.has("glasses") and not L.get("sunglasses", false):
		L.glasses = rng.randf() < (0.35 if old else 0.12)
	L.mood = 0.0
	return L


## Sayed: checked shirt, the قهوجي's towel over his shoulder, moustache.
static func sayed_look() -> Dictionary:
	return {"seed": 127, "skin": Color("b97a52"), "hc": Color("1d1612"), "top": "shirt", "cloth": Color("2f5f8a"),
		"pattern": "check", "bottom": "trousers", "pants": Color("3a3a40"), "shoe": "sandals", "hair": "short",
		"moustache": true, "beard": "stubble", "extra": ["towel", "tea"], "mood": 0.4}

#endregion


#region Building

func _pivot_of(part: String) -> Vector3:
	match part:
		"head":
			return Vector3(0, 0, NECK)
		"arm_l":
			return Vector3(-6.7, 0, SHOULDER)
		"arm_r":
			return Vector3(6.7, 0, SHOULDER)
		"leg_l":
			return Vector3(-2.5, 0, HIP)
		"leg_r":
			return Vector3(2.5, 0, HIP)
	return Vector3.ZERO


func _bake(part: String, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = (_parts[part].vox as Vox).commit()
	parent.add_child(mi)
	return mi


func _hinge(part: String, parent: Node3D) -> Node3D:
	var pivot: Vector3 = _parts[part].pivot
	var n := Node3D.new()
	n.position = Vector3(pivot.x, pivot.z, pivot.y) * U
	parent.add_child(n)
	_bake(part, n)
	return n


func _to(part: String) -> void:
	_cur = part


## One block from lo to hi in body units, into the current part.
func _b(lo: Vector3, hi: Vector3, c: Color) -> void:
	var part: Dictionary = _parts[_cur]
	var p: Vector3 = part.pivot
	(part.vox as Vox).box(Vector3(lo.x - p.x, lo.z - p.z, lo.y - p.y) * U, Vector3(hi.x - p.x, hi.z - p.z, hi.y - p.y) * U, c)


func _pair(lo: Vector3, hi: Vector3, c: Color) -> void:
	_b(lo, hi, c)
	_b(Vector3(-hi.x, lo.y, lo.z), Vector3(-lo.x, hi.y, hi.z), c)


## Mirrored across the body, left half into the left part and right into the right.
func _sides(part_prefix: String, lo: Vector3, hi: Vector3, c: Color) -> void:
	_to(part_prefix + "_r")
	_b(lo, hi, c)
	_to(part_prefix + "_l")
	_b(Vector3(-hi.x, lo.y, lo.z), Vector3(-lo.x, hi.y, hi.z), c)


func _pick(a: Array) -> Variant:
	return a[_rng.randi() % a.size()]


func _build_look(pose: String) -> void:
	var robe: String = look.get("robe", "")
	var sitting := pose != "stand"
	if pose != "drive":
		_feet(sitting)
		if robe == "":
			_legs(sitting)
	_to("torso")
	if robe != "":
		_robe(robe, sitting)
	else:
		_top()
	_arms()
	_to("torso")
	_b(Vector3(-1.8, -1.8, 34), Vector3(1.8, 1.8, 36.2), (look.skin as Color).darkened(0.12))
	_head_parts()
	for x in look.get("extra", []):
		_extra(x)


func _head_parts() -> void:
	_to("head")
	var skin: Color = look.skin
	_b(Vector3(-5, -5, 36), Vector3(5, 5, 46), skin)
	_pair(Vector3(5, -1, 39), Vector3(5.8, 1, 42.5), skin.darkened(0.1))
	_face()
	_hair()
	_headwear()


func _feet(sitting: bool) -> void:
	var style: String = look.get("shoe", "shoes")
	var skin: Color = look.skin
	var shoe_c := Color(_pick(["1c1c22", "4a2e1c", "2a1d14"]))
	var lace := Color(_pick(["c8322b", "2a6ab0", "2b2b30", "3b8a5a"]))
	for side in ["r", "l"]:
		var x0 := 0.5 if side == "r" else -4.6
		var x1 := 4.6 if side == "r" else -0.5
		# Seated, the feet sit forward under the knees.
		var fy := 9.0 if sitting else 0.0
		_to("leg_" + side)
		match style:
			"sandals":
				_b(Vector3(x0, -3 + fy, 0), Vector3(x1, 6 + fy, 0.8), Color("4a2e1c"))
				_b(Vector3(x0 + 0.3, -2.5 + fy, 0.8), Vector3(x1 - 0.3, 5.5 + fy, 2.2), skin.darkened(0.08))
				_b(Vector3(x0, 2 + fy, 0.8), Vector3(x1, 3.4 + fy, 2.6), Color("6a4028"))
			"sneakers":
				_b(Vector3(x0, -3.5 + fy, 0), Vector3(x1, 6 + fy, 1.2), Color("c8c4bc"))
				_b(Vector3(x0, -3.3 + fy, 1.2), Vector3(x1, 5.6 + fy, 3.4), Color("f2efe8"))
				_b(Vector3(x0 - 0.05, -1 + fy, 1.6), Vector3(x1 + 0.05, 2.5 + fy, 2.4), lace)
			"boots":
				_b(Vector3(x0, -3.5 + fy, 0), Vector3(x1, 6 + fy, 1.2), Color("2a1d14"))
				_b(Vector3(x0, -3.3 + fy, 1.2), Vector3(x1, 5.6 + fy, 6), Color("6a4a2a"))
			"flats":
				_b(Vector3(x0 + 0.3, -3 + fy, 0), Vector3(x1 - 0.3, 5.5 + fy, 2), Color("1c1c22"))
				_b(Vector3(x0 + 0.3, 3 + fy, 1.2), Vector3(x1 - 0.3, 5.5 + fy, 2.2), skin.darkened(0.05))
			_:
				_b(Vector3(x0, -3.5 + fy, 0), Vector3(x1, 6 + fy, 0.9), Color("141418"))
				_b(Vector3(x0, -3.3 + fy, 0.9), Vector3(x1, 5.8 + fy, 3), shoe_c)
				_b(Vector3(x0 + 0.5, 4 + fy, 2.4), Vector3(x1 - 0.5, 5.9 + fy, 3.1), shoe_c.lightened(0.2))


func _legs(sitting: bool) -> void:
	var bottom: String = look.get("bottom", "trousers")
	var pants: Color = look.get("pants", Color("355a8a"))
	if bottom == "jeans":
		pants = Color(JEANS[int(look.get("seed", 0)) % JEANS.size()])
	if bottom == "tracksuit":
		pants = look.cloth
	if bottom == "skirt":
		# A long skirt: the torso carries it; only a glimpse of leg shows.
		_to("torso")
		if sitting:
			_b(Vector3(-5.6, -4, 14), Vector3(5.6, 12, 20), pants)
			_b(Vector3(-5.6, 9, 3), Vector3(5.6, 12, 14), pants)
		else:
			_b(Vector3(-5.8, -4.2, 3), Vector3(5.8, 4.4, 19), pants)
			_b(Vector3(-5.85, -4.25, 3), Vector3(5.85, 4.45, 4), pants.darkened(0.2))
			for x in [-3.0, 0.0, 3.0]:
				_b(Vector3(x - 0.2, 4.4, 4), Vector3(x + 0.2, 4.5, 17), pants.darkened(0.12))
		return
	for side in ["r", "l"]:
		var x0 := 0.5 if side == "r" else -4.5
		var x1 := 4.5 if side == "r" else -0.5
		_to("leg_" + side)
		if sitting:
			# Thigh forward along the seat, shin down to the foot.
			_b(Vector3(x0, -3, 15), Vector3(x1, 12, 21), pants)
			_b(Vector3(x0, 6, 3), Vector3(x1, 12, 15), pants if bottom != "shorts" else look.skin)
			continue
		var z0 := 11.0 if bottom == "shorts" else 3.0
		if bottom == "shorts":
			_b(Vector3(x0 + 0.4, -2.5, 3), Vector3(x1 - 0.4, 2.5, 11), look.skin)
		_b(Vector3(x0, -3, z0), Vector3(x1, 3, 18.5), pants)
		if bottom == "jeans":
			_b(Vector3(x1 - 0.5 if side == "r" else x0 + 0.3, 3, z0 + 1), Vector3(x1 - 0.3 if side == "r" else x0 + 0.5, 3.1, 17), Color("d88a3a"))
			_b(Vector3(x0, -3.05, z0), Vector3(x1, 3.05, z0 + 0.8), pants.lightened(0.15))
		elif bottom == "tracksuit":
			var edge := x1 if side == "r" else x0
			_b(Vector3(edge - 0.05, -0.5, z0), Vector3(edge + 0.05, 0.5, 18), Color("f2efe8"))
		else:
			var mid := (x0 + x1) * 0.5
			_b(Vector3(mid - 0.15, 3, z0 + 1), Vector3(mid + 0.15, 3.12, 17.5), pants.lightened(0.18))


func _top() -> void:
	var top: String = look.get("top", "shirt")
	var cloth: Color = look.cloth
	var skin: Color = look.skin
	var woman: bool = look.get("woman", false)
	_to("torso")
	var tucked: bool = not woman and top in ["shirt", "school", "suit", "polo", "vest", "coat"]
	if tucked:
		_b(Vector3(-5.2, -3.6, 17), Vector3(5.2, 3.6, 19), Color("2a1d14"))
		_b(Vector3(-1, 3.6, 17.3), Vector3(1, 3.9, 18.7), Color("d4b24a"))
	var z0 := 19.0 if tucked else 16.5
	if top in ["longtop", "coat"]:
		z0 = 10.0
	_b(Vector3(-5, -3.5, z0), Vector3(5, 3.5, 34), cloth)
	_b(Vector3(-5.6, -3.3, 31.5), Vector3(5.6, 3.3, 34.3), cloth)
	# Checks or stripes woven over the shirt.
	var pattern: String = look.get("pattern", "")
	if pattern == "check" and top == "shirt":
		for z in [21.0, 24.5, 28.0, 31.5]:
			_b(Vector3(-5.05, -3.55, z), Vector3(5.05, 3.55, z + 0.6), cloth.darkened(0.3))
		for x in [-3.5, -1.2, 1.2, 3.5]:
			_b(Vector3(x - 0.3, 3.5, z0), Vector3(x + 0.3, 3.56, 34), cloth.darkened(0.3))
	elif pattern == "stripe" and top == "shirt":
		for x in [-4.0, -2.4, -0.8, 0.8, 2.4, 4.0]:
			_b(Vector3(x - 0.2, 3.5, z0), Vector3(x + 0.2, 3.56, 34), cloth.lightened(0.35))
	match top:
		"tshirt", "jersey", "polo":
			_b(Vector3(-2.2, 3.5, 32.6), Vector3(2.2, 3.6, 34), skin)
			if top == "jersey":
				var white := cloth.is_equal_approx(Color("f1ede4"))
				var stripe := Color("c8322b") if white else Color("f2efe8")
				if white:
					# Zamalek: white with the two red bands.
					_b(Vector3(-5.05, 3.5, 26), Vector3(5.05, 3.58, 27.2), stripe)
					_b(Vector3(-5.05, 3.5, 28), Vector3(5.05, 3.58, 29.2), stripe)
				else:
					for x in [-3.5, 0.0, 3.5]:
						_b(Vector3(x - 0.8, 3.5, z0), Vector3(x + 0.8, 3.56, 32.5), stripe)
				_b(Vector3(-1, 3.56, 28), Vector3(1, 3.62, 30.5), Color("1c1c22") if not white else Color("c8322b"))
				_b(Vector3(-1, -3.62, 25), Vector3(1, -3.56, 31), Color("1c1c22") if not white else Color("c8322b"))
			elif top == "polo":
				_b(Vector3(-2.2, 3.5, 32.6), Vector3(2.2, 3.62, 34.3), cloth.lightened(0.2))
				for z in [30.0, 31.6]:
					_b(Vector3(-0.3, 3.62, z), Vector3(0.3, 3.75, z + 0.5), Color("e8e4dc"))
				_b(Vector3(-4, 3.5, 29), Vector3(-2.5, 3.58, 30.2), cloth.darkened(0.25))
			else:
				var ink := Color(_pick(["f2d24a", "2b2b30", "c8322b", "f2efe8", "3ab0b0"]))
				if ink.is_equal_approx(cloth):
					ink = Color("2b2b30")
				var mark: int = _rng.randi() % 3
				if mark == 0:
					_b(Vector3(-2.5, 3.5, 25), Vector3(2.5, 3.6, 29.5), ink)
				elif mark == 1:
					_b(Vector3(-4, 3.5, 27), Vector3(4, 3.6, 28.2), ink)
					_b(Vector3(-4, 3.5, 25), Vector3(4, 3.6, 25.6), ink)
				else:
					_b(Vector3(-1.2, 3.5, 24), Vector3(1.2, 3.6, 30), ink)
					_b(Vector3(-3, 3.5, 26), Vector3(3, 3.6, 28), ink)
		"suit":
			_b(Vector3(-2, 3.5, 24), Vector3(2, 3.58, 34), look.shirt)
			_b(Vector3(-0.7, 3.58, 23), Vector3(0.7, 3.7, 33.5), look.tie)
			_b(Vector3(-0.9, 3.58, 32.5), Vector3(0.9, 3.72, 33.8), (look.tie as Color).darkened(0.2))
			_pair(Vector3(0.6, 3.5, 26), Vector3(2.4, 3.65, 34), cloth.lightened(0.1))
			_b(Vector3(-5, 3.5, 19), Vector3(5, 3.6, 21), cloth.darkened(0.15))
			_b(Vector3(-4.6, 3.6, 29.5), Vector3(-2.6, 3.66, 30.5), Color("f1ede4"))
			for z in [21.5, 24.0]:
				_b(Vector3(-0.3, 3.6, z), Vector3(0.3, 3.72, z + 0.6), Color("1c1c22"))
		"vest":
			_b(Vector3(-5.1, -3.6, 19), Vector3(5.1, 3.6, 33), Color("f28a1a"))
			_b(Vector3(-5.15, -3.65, 24), Vector3(5.15, 3.65, 25), Color("e8e4dc"))
			_b(Vector3(-5.15, -3.65, 28), Vector3(5.15, 3.65, 29), Color("e8e4dc"))
			_b(Vector3(-1, 3.6, 19), Vector3(1, 3.7, 33), cloth)
		"school", "shirt", "coat":
			var body_c: Color = cloth if top != "coat" else look.get("shirt", Color("a8c8e8"))
			_b(Vector3(-0.7, 3.5, 30.5), Vector3(0.7, 3.62, 34), skin.darkened(0.08))
			_pair(Vector3(0.7, 3.3, 32.4), Vector3(3.2, 3.9, 34.6), body_c.lightened(0.18))
			_b(Vector3(-0.35, 3.5, 19), Vector3(0.35, 3.62, 30.5), body_c.darkened(0.2))
			for z in [21.0, 24.0, 27.0]:
				_b(Vector3(-0.35, 3.62, z), Vector3(0.35, 3.85, z + 0.7), Color("e8e4dc"))
			_b(Vector3(-4.2, 3.5, 26.5), Vector3(-1.4, 3.64, 29.8), cloth.darkened(0.08))
			if top == "school":
				_b(Vector3(-3.8, 3.64, 27.4), Vector3(-2, 3.72, 29), Color("2a3a6a"))
			elif top == "coat":
				# The white coat hangs open over the shirt, a pen in the pocket.
				_b(Vector3(-2, 3.5, z0), Vector3(2, 3.56, 30), body_c)
				_pair(Vector3(2, 3.5, z0), Vector3(2.6, 3.7, 34), cloth.darkened(0.08))
				_b(Vector3(-4.4, 3.56, 26), Vector3(-2.6, 3.62, 29), cloth.darkened(0.1))
				_b(Vector3(-3.8, 3.62, 28.5), Vector3(-3.4, 3.7, 30.5), Color("2a4a8a"))
				_pair(Vector3(2.8, 3.5, 14), Vector3(4.6, 3.6, 17), cloth.darkened(0.1))
		"sweater", "cardigan":
			_b(Vector3(-2.4, 3.5, 31.8), Vector3(2.4, 3.6, 34), Color("e9e6df"))
			for z in [21.0, 23.0, 25.0, 27.0, 29.0]:
				_b(Vector3(-5, 3.5, z), Vector3(5, 3.58, z + 0.4), cloth.darkened(0.12))
			_b(Vector3(-5, -3.5, z0), Vector3(5, 3.5, z0 + 1.5), cloth.darkened(0.2))
			if top == "cardigan":
				_b(Vector3(-0.4, 3.58, z0), Vector3(0.4, 3.64, 33), cloth.darkened(0.3))
		"blouse", "longtop":
			_b(Vector3(-2.2, 3.5, 31.5), Vector3(2.2, 3.6, 34), skin)
			_b(Vector3(-5.2, -3.7, z0), Vector3(5.2, 3.7, z0 + 1.5), cloth.darkened(0.1))
			for x in [-2.5, 2.5]:
				_b(Vector3(x - 0.5, 3.5, 26), Vector3(x + 0.5, 3.6, 27), cloth.lightened(0.3))
			if top == "longtop":
				_b(Vector3(-5.05, 3.5, 20), Vector3(5.05, 3.56, 21), cloth.lightened(0.2))
		"jacket":
			_b(Vector3(-0.3, 3.5, z0), Vector3(0.3, 3.62, 34), Color("c9ced6"))
			_b(Vector3(-5.1, -3.6, z0), Vector3(5.1, 3.6, z0 + 1.5), Color("1c1c22"))
			_b(Vector3(-3, 3.5, 32), Vector3(3, 3.7, 34.5), Color("1c1c22"))
			_pair(Vector3(2, 3.5, 22), Vector3(4.2, 3.6, 24), cloth.darkened(0.25))
		"tracksuit":
			_b(Vector3(-0.3, 3.5, z0), Vector3(0.3, 3.62, 34), Color("c9ced6"))
			_pair(Vector3(5.6, -0.5, 20), Vector3(5.7, 0.5, 34), Color("f2efe8"))


func _robe(kind: String, sitting: bool) -> void:
	var cloth: Color = look.cloth
	if sitting:
		_b(Vector3(-5.8, -4, 14), Vector3(5.8, 12, 20), cloth)
		_b(Vector3(-5.8, 8, 2), Vector3(5.8, 12.5, 14), cloth)
	else:
		_b(Vector3(-6.2, -4.4, 2), Vector3(6.2, 4.4, 12), cloth)
		_b(Vector3(-6.25, -4.45, 2), Vector3(6.25, 4.45, 3), cloth.darkened(0.25))
	_b(Vector3(-5.6, -3.9, 12), Vector3(5.6, 3.9, 34), cloth)
	_b(Vector3(-5.9, -3.3, 31.5), Vector3(5.9, 3.3, 34.3), cloth)
	match kind:
		"galabeya":
			_b(Vector3(-0.4, 3.9, 26), Vector3(0.4, 4.0, 34), Color("3a2a1c"))
			_pair(Vector3(0.4, 3.9, 26), Vector3(1.2, 4.02, 34.2), cloth.darkened(0.3))
			for z in [27.5, 30.0, 32.5]:
				_b(Vector3(-0.3, 4.0, z), Vector3(0.3, 4.1, z + 0.6), Color("c9a24a"))
			if look.get("pattern", "") == "stripe" and not sitting:
				for x in [-4.5, -2.5, -0.5, 1.5, 3.5]:
					_b(Vector3(x, 3.9, 3), Vector3(x + 0.4, 3.98, 25.5), cloth.darkened(0.18))
					_b(Vector3(x, 4.4, 3), Vector3(x + 0.4, 4.48, 11.5), cloth.darkened(0.18))
			# Side pocket slit.
			_b(Vector3(5.6, -1, 15), Vector3(5.7, 1, 21), cloth.darkened(0.3))
		"kaftan":
			# A long open coat (jubba) over a lighter robe.
			_b(Vector3(-1.6, 3.9, 3 if not sitting else 14), Vector3(1.6, 4.0, 34), Color("e9e6df"))
			_pair(Vector3(1.6, 3.9, 3 if not sitting else 14), Vector3(2.2, 4.05, 34.3), Color("c9a24a"))
		"dress":
			_b(Vector3(-5.6, 3.9, 18), Vector3(5.6, 4.0, 19), cloth.lightened(0.15))
		_:
			_b(Vector3(-0.15, 3.9, 3 if not sitting else 14), Vector3(0.15, 4.0, 30), cloth.lightened(0.12))
			_b(Vector3(-5.65, -3.95, 20), Vector3(5.65, 3.95, 20.6), cloth.lightened(0.08))


func _arms() -> void:
	var top: String = look.get("top", "")
	var robe: String = look.get("robe", "")
	var cloth: Color = look.cloth
	var skin: Color = look.skin
	var sleeve := cloth.darkened(0.05)
	if top == "suit" or top == "coat":
		sleeve = cloth
	for side in ["r", "l"]:
		var x0 := 5.2 if side == "r" else -8.2
		var x1 := 8.2 if side == "r" else -5.2
		_to("arm_" + side)
		if top in ["tshirt", "jersey", "polo"]:
			_b(Vector3(x0, -1.6, 28.5), Vector3(x1, 1.6, 33.5), sleeve)
			_b(Vector3(x0 - 0.05, -1.65, 28.5), Vector3(x1 + 0.05, 1.65, 29.2), sleeve.darkened(0.15))
			_b(Vector3(x0 + 0.2, -1.4, 19.5), Vector3(x1 - 0.2, 1.4, 28.5), skin)
		elif top == "vest":
			_b(Vector3(x0, -1.6, 28.5), Vector3(x1, 1.6, 33.5), Color(look.get("cloth", Color("5a6a7a"))))
			_b(Vector3(x0 + 0.2, -1.4, 19.5), Vector3(x1 - 0.2, 1.4, 28.5), skin)
		elif robe != "":
			_b(Vector3(x0, -1.8, 21), Vector3(x1, 1.8, 33.5), sleeve)
			_b(Vector3(x0 - 0.3, -2.1, 19.5), Vector3(x1 + 0.3, 2.1, 21.2), sleeve.darkened(0.15))
		else:
			_b(Vector3(x0, -1.6, 21), Vector3(x1, 1.6, 33.5), sleeve)
			_b(Vector3(x0 - 0.1, -1.7, 19.5), Vector3(x1 + 0.1, 1.7, 21), sleeve.lightened(0.12))
			if look.get("pattern", "") == "check" and top == "shirt":
				_b(Vector3(x0 - 0.05, -1.65, 25), Vector3(x1 + 0.05, 1.65, 25.6), cloth.darkened(0.3))
		# Hand, with the thumb forward.
		_b(Vector3(x0 + 0.3, -1.2, 16), Vector3(x1 - 0.3, 1.2, 19.5), skin)
		_b(Vector3(x0 + 0.8, 1.2, 17.2), Vector3(x1 - 0.8, 2.0, 18.8), skin.darkened(0.06))
		if side == "l" and _rng.randf() < 0.3 and not look.get("kid", false):
			# A wristwatch.
			_b(Vector3(x0 - 0.05, -1.3, 19.3), Vector3(x1 + 0.05, 1.3, 20.1), Color(_pick(["c9a24a", "c9ced6", "1c1c22"])))


func _face() -> void:
	var skin: Color = look.skin
	var hc: Color = look.hc
	var f := 5.0
	var mood := float(look.get("mood", 0.0))
	var head_kind: String = look.get("head", "")
	# Eyes: whites, pupils toward the middle; closed to a line when pleased.
	if mood > 0.7:
		_pair(Vector3(1.1, f, 41.0), Vector3(3.2, f + 0.12, 41.5), Color("2a1c12"))
	else:
		_pair(Vector3(1.1, f, 40.4), Vector3(3.2, f + 0.12, 42), Color("f4efe6"))
		_pair(Vector3(1.1, f + 0.12, 40.4), Vector3(2.1, f + 0.24, 41.8), Color("2a1c12"))
	if head_kind == "niqab":
		_pair(Vector3(0.9, f, 42.6), Vector3(3.5, f + 0.3, 43.4), Color("1d1612"))
		return
	# Brows: level, or knitted down toward the nose when cross.
	if mood < -0.3:
		_pair(Vector3(0.9, f, 42.2), Vector3(2.2, f + 0.3, 43.0), hc.darkened(0.3))
		_pair(Vector3(2.2, f, 42.8), Vector3(3.5, f + 0.3, 43.6), hc.darkened(0.3))
	else:
		_pair(Vector3(0.9, f, 42.6), Vector3(3.5, f + 0.3, 43.4), hc.darkened(0.3))
	if look.get("woman", false):
		_pair(Vector3(3.2, f + 0.12, 41.6), Vector3(3.5, f + 0.26, 42.2), Color("1d1612"))
	_b(Vector3(-0.7, f, 38.6), Vector3(0.7, f + 0.9, 41.2), skin.darkened(0.06))
	_b(Vector3(-0.7, f + 0.9, 38.6), Vector3(0.7, f + 1.0, 39.2), skin.darkened(0.2))
	_pair(Vector3(2.4, f, 38.6), Vector3(4, f + 0.08, 39.8), skin.lerp(Color("d86a5a"), 0.25))
	# Mouth: a smile turns up at the corners, a frown down.
	var lip := Color("7a2e22")
	if mood > 0.2:
		_b(Vector3(-1.4, f, 37.0), Vector3(1.4, f + 0.12, 37.6), lip)
		_pair(Vector3(1.4, f, 37.4), Vector3(2.0, f + 0.12, 38.1), lip)
	elif mood < -0.3:
		_b(Vector3(-1.4, f, 37.4), Vector3(1.4, f + 0.12, 38.0), lip)
		_pair(Vector3(1.4, f, 36.8), Vector3(2.0, f + 0.12, 37.5), lip)
	else:
		_b(Vector3(-1.4, f, 37.2), Vector3(1.4, f + 0.12, 37.8), lip)
	if look.get("moustache", false) and not look.get("woman", false):
		_b(Vector3(-2.4, f, 37.9), Vector3(2.4, f + 0.4, 38.7), hc)
	match look.get("beard", ""):
		"white":
			_b(Vector3(-4.4, f, 34.5), Vector3(4.4, f + 0.6, 38.6), Color("e8e4dc"))
			_pair(Vector3(4.2, -1, 35), Vector3(5.1, f, 40), Color("e8e4dc"))
			_b(Vector3(-2.4, f, 37.9), Vector3(2.4, f + 0.7, 38.7), Color("e8e4dc"))
		"short":
			_b(Vector3(-4.2, f, 35.6), Vector3(4.2, f + 0.5, 37.2), hc)
			_pair(Vector3(4.2, -1, 35.6), Vector3(5.1, f, 40), hc)
		"stubble":
			_b(Vector3(-4.6, f, 36), Vector3(4.6, f + 0.06, 38.5), skin.darkened(0.22))
	if look.get("glasses", false) or look.get("sunglasses", false):
		var dark: bool = look.get("sunglasses", false)
		for side in [-1.0, 1.0]:
			var x0: float = 0.8 if side > 0 else -3.6
			var x1: float = 3.6 if side > 0 else -0.8
			if dark:
				_b(Vector3(x0, f + 0.3, 39.9), Vector3(x1, f + 0.45, 42.3), Color("1a1a20"))
			else:
				var frame := Color("1d1612")
				_b(Vector3(x0, f + 0.3, 39.9), Vector3(x1, f + 0.45, 40.2), frame)
				_b(Vector3(x0, f + 0.3, 42.1), Vector3(x1, f + 0.45, 42.4), frame)
				_b(Vector3(x0, f + 0.3, 40.2), Vector3(x0 + 0.3, f + 0.45, 42.1), frame)
				_b(Vector3(x1 - 0.3, f + 0.3, 40.2), Vector3(x1, f + 0.45, 42.1), frame)
		_b(Vector3(-0.8, f + 0.3, 41.4), Vector3(0.8, f + 0.45, 41.7), Color("1d1612"))
		_pair(Vector3(5, -2.5, 41.4), Vector3(5.15, f, 41.7), Color("1d1612"))


func _hair() -> void:
	var hc: Color = look.hc
	var head_kind: String = look.get("head", "")
	if head_kind in ["hijab", "niqab", "turban", "moto", "headscarf", "shawl"]:
		return
	var style: String = look.get("hair", "short")
	var y0 := -5.3
	var y1 := 5.3
	match style:
		"none":
			pass
		"bald":
			_b(Vector3(-5.3, y0, 39), Vector3(5.3, -4.6, 43), hc)
			_pair(Vector3(4.6, y0, 40), Vector3(5.3, 1.5, 43.5), hc)
		"receding":
			_b(Vector3(-5.3, y0, 44), Vector3(5.3, -1.5, 46.6), hc)
			_b(Vector3(-5.3, y0, 39), Vector3(5.3, -4.6, 44), hc)
			_pair(Vector3(4.6, y0, 41), Vector3(5.3, 1.5, 45.2), hc)
		"buzz", "fade":
			_b(Vector3(-5.15, y0 + 0.15, 45.6), Vector3(5.15, y1 - 0.15, 46.4), hc)
			_b(Vector3(-5.15, y0 + 0.15, 40), Vector3(5.15, -4.8, 46), hc)
			if style == "fade":
				_b(Vector3(-4.2, -4.2, 46.4), Vector3(4.2, 4.2, 48.2), hc)
				_pair(Vector3(5.0, y0 + 0.15, 43), Vector3(5.2, 2.0, 46), hc)
		"curly":
			_b(Vector3(-5.4, y0, 44), Vector3(5.4, y1, 47.5), hc)
			for i in 9:
				var x := -4.0 + (i % 3) * 4.0
				var y := -4.0 + (i / 3) * 4.0
				_b(Vector3(x - 1.2, y - 1.2, 47.5), Vector3(x + 1.2, y + 1.2, 48.8), hc)
			_b(Vector3(-5.4, y0, 39), Vector3(5.4, -4.6, 44), hc)
			_pair(Vector3(4.6, y0, 41), Vector3(5.4, 2.5, 44), hc)
		"spiky":
			_b(Vector3(-5.3, y0, 44.5), Vector3(5.3, y1, 46.5), hc)
			for x in [-3.5, 0.0, 3.5]:
				_b(Vector3(x - 1, -1, 46.5), Vector3(x + 1, 2, 49), hc)
			_b(Vector3(-5.3, y0, 40), Vector3(5.3, -4.6, 44.5), hc)
		"long", "ponytail", "bun", "bob":
			_b(Vector3(-5.4, y0, 44.8), Vector3(5.4, y1, 47.4), hc)
			var low := {"long": 30.0, "bob": 37.5, "ponytail": 40.0, "bun": 40.0}[style] as float
			_b(Vector3(-5.4, y0 - 0.3, low), Vector3(5.4, -4.4, 45), hc)
			_pair(Vector3(4.6, y0, low + 1.0), Vector3(5.5, 3.5, 45), hc)
			_b(Vector3(-5.3, 4.4, 43.4), Vector3(5.3, y1, 45), hc)
			if style == "ponytail":
				_b(Vector3(-1.2, y0 - 2.5, 36), Vector3(1.2, y0, 44), hc)
				_b(Vector3(-1.4, y0 - 0.6, 43), Vector3(1.4, y0, 44.5), Color(_pick(["c8322b", "f2d24a", "2a6ab0"])))
			elif style == "bun":
				_b(Vector3(-2, y0 - 2.5, 44), Vector3(2, y0, 48), hc)
		"swept":
			_b(Vector3(-5.3, y0, 45), Vector3(5.3, y1, 47.6), hc)
			_b(Vector3(-5.3, y0, 39), Vector3(5.3, -4.6, 45), hc)
			_pair(Vector3(4.6, y0, 42), Vector3(5.3, 2.5, 45), hc)
			_b(Vector3(-4, -2, 47.6), Vector3(4, 4, 48.4), hc)
		_:
			_b(Vector3(-5.3, y0, 45), Vector3(5.3, y1, 47.4), hc)
			_b(Vector3(-5.3, y0, 39), Vector3(5.3, -4.6, 45), hc)
			_pair(Vector3(4.6, y0, 42), Vector3(5.3, 2.5, 45), hc)
			_pair(Vector3(4.6, 1.2, 39.5), Vector3(5.3, 2.4, 42), hc)
			_b(Vector3(-5.3, 4.6, 43.8), Vector3(1.5, y1, 45), hc)
			_b(Vector3(-3, -3, 47.4), Vector3(3.5, 3, 48.2), hc)


func _headwear() -> void:
	var y0 := -5.4
	var y1 := 5.4
	match look.get("head", ""):
		"kufi":
			_b(Vector3(-5.35, y0, 44.2), Vector3(5.35, y1, 48.6), Color("f1ede4"))
			_b(Vector3(-5.4, y0 - 0.05, 45.2), Vector3(5.4, y1 + 0.05, 46.2), Color("d8d2c2"))
			for i in 5:
				var x := -4.0 + i * 2.0
				_b(Vector3(x - 0.3, 5.4, 45.4), Vector3(x + 0.3, 5.5, 46), Color("a09a88"))
		"turban":
			# Upper-Egypt emma: a big white wrap.
			_b(Vector3(-6.2, y0 - 0.8, 43.5), Vector3(6.2, y1 + 0.8, 48.5), Color("f1ede4"))
			_b(Vector3(-5, y0, 48.5), Vector3(5, y1, 50.5), Color("e8e4dc"))
			for z in [44.5, 46.5]:
				_b(Vector3(-6.25, y1 + 0.8, z), Vector3(6.25, y1 + 0.9, z + 0.4), Color("d8d2c2"))
			_b(Vector3(-6.3, y0 - 1.6, 44), Vector3(-4, y0 - 0.8, 46), Color("e8e4dc"))
		"shawl":
			# A wool شال wound round the head and over the shoulders.
			var s := Color(_pick(["8a7a60", "5a4a3a", "a89a80", "3a3a40"]))
			_b(Vector3(-5.8, y0 - 0.4, 43.5), Vector3(5.8, y1 + 0.4, 47.5), s)
			_pair(Vector3(4.8, y0 - 0.4, 36), Vector3(5.8, y1 + 0.2, 43.5), s)
			_b(Vector3(-5.8, y0 - 0.4, 36), Vector3(5.8, -4.6, 43.5), s)
			_to("torso")
			_b(Vector3(-6.6, -4.5, 31), Vector3(6.6, 4.5, 35), s)
			_to("head")
		"tarboush":
			# Red tarboush wrapped in white (an Azhari sheikh).
			_b(Vector3(-5.6, y0 - 0.2, 44), Vector3(5.6, y1 + 0.2, 46.5), Color("f1ede4"))
			_b(Vector3(-4.2, y0 + 1.2, 46.5), Vector3(4.2, y1 - 1.2, 51), Color("a8242a"))
			_b(Vector3(-0.3, y0 + 1.2, 51), Vector3(0.3, y0 + 1.8, 51.5), Color("1c1c22"))
		"cap", "cap_back", "beanie":
			var c := Color(_pick(["c8322b", "2a4a8a", "2b2b30", "e9e6df", "3b8a5a"]))
			_b(Vector3(-5.4, y0, 45), Vector3(5.4, y1, 48.6), c)
			_b(Vector3(-0.6, -0.6, 48.6), Vector3(0.6, 0.6, 49.1), c.darkened(0.2))
			if look.head == "cap":
				_b(Vector3(-4.2, y1, 45), Vector3(4.2, y1 + 3.4, 45.8), c.darkened(0.25))
				_b(Vector3(-2.2, y1 + 0.05, 46), Vector3(2.2, y1 + 0.1, 47.6), Color("f2efe8"))
			elif look.head == "cap_back":
				_b(Vector3(-4.2, y0 - 3.4, 45), Vector3(4.2, y0, 45.8), c.darkened(0.25))
			else:
				_b(Vector3(-5.45, y0 - 0.05, 44.5), Vector3(5.45, y1 + 0.05, 46), c.darkened(0.15))
		"hardhat":
			_b(Vector3(-5.8, y0 - 0.6, 45), Vector3(5.8, y1 + 1.6, 46), Color("f2c230"))
			_b(Vector3(-5, y0, 46), Vector3(5, y1, 49.5), Color("f2c230"))
			_b(Vector3(-0.6, y0, 49.5), Vector3(0.6, y1, 50), Color("e0b020"))
		"moto":
			_b(Vector3(-6, y0 - 0.6, 37), Vector3(6, y1 + 0.6, 49), Color("1c1c22"))
			_b(Vector3(-4.6, y1 + 0.6, 39), Vector3(4.6, y1 + 0.8, 44), Color("5a7a9a"))
			_b(Vector3(-6.05, y0, 43), Vector3(6.05, y1 + 0.6, 44), Color("c8322b"))
		"sunhat":
			_b(Vector3(-8.5, y0 - 3, 45.2), Vector3(8.5, y1 + 3, 46), Color("e8d8a8"))
			_b(Vector3(-5.3, y0, 46), Vector3(5.3, y1, 49.5), Color("e8d8a8"))
			_b(Vector3(-5.35, y0 - 0.05, 46), Vector3(5.35, y1 + 0.05, 47), Color("7a4a2a"))
		"bread":
			# A wooden tray of عيش balanced on his head.
			_b(Vector3(-9, y0 - 4, 47.4), Vector3(9, y1 + 4, 48.2), Color("8a5a32"))
			for i in 12:
				var x := -7.0 + (i % 4) * 4.6
				var y := -6.0 + (i / 4) * 5.5
				_b(Vector3(x - 1.9, y - 1.9, 48.2), Vector3(x + 1.9, y + 1.9, 49.4), Color("d8a860"))
				_b(Vector3(x - 1.2, y - 1.2, 49.4), Vector3(x + 1.2, y + 1.2, 49.7), Color("c89050"))
			_b(Vector3(-5.3, y0, 45), Vector3(5.3, y1, 47.4), look.hc)
		"hijab", "niqab":
			var scarf: Color = look.scarf
			_b(Vector3(-5.8, y0 - 0.4, 45), Vector3(5.8, y1 + 0.4, 47.8), scarf)
			_pair(Vector3(4.6, y0 - 0.4, 35), Vector3(5.8, y1 + 0.4, 45), scarf)
			_b(Vector3(-5.8, y0 - 0.4, 35), Vector3(5.8, -4.6, 45), scarf)
			_b(Vector3(-5.8, 4.8, 43.8), Vector3(5.8, y1 + 0.4, 45), scarf)
			_b(Vector3(-5.8, 4.8, 34.5), Vector3(5.8, y1 + 0.4, 37), scarf)
			if look.head == "niqab":
				_b(Vector3(-5.8, 4.8, 37), Vector3(5.8, y1 + 0.4, 40.2), scarf)
			else:
				_b(Vector3(4.4, 5.8, 35.6), Vector3(5.2, 6.1, 36.4), Color("e8d27a"))
			# Draped over the shoulders, falling to a point on the chest.
			_to("torso")
			_b(Vector3(-6.6, -4.5, 29.5), Vector3(6.6, 4.5, 35), scarf.darkened(0.08))
			_b(Vector3(-4, 4.5, 25.5), Vector3(4, 4.9, 35), scarf.darkened(0.08))
			_b(Vector3(-2, 4.9, 24), Vector3(2, 5.0, 26), scarf.darkened(0.08))
			for x in [-2.5, 0.0, 2.5]:
				_b(Vector3(x - 0.15, 4.9, 27), Vector3(x + 0.15, 5.0, 34.5), scarf.darkened(0.25))
			_to("head")
		"headscarf":
			# Loose scarf over grey hair, knotted under the chin.
			var s: Color = look.scarf
			_b(Vector3(-5.8, y0 - 0.4, 44), Vector3(5.8, y1 - 1, 47.8), s)
			_pair(Vector3(4.8, y0 - 0.4, 37), Vector3(5.8, y1 - 1, 44), s)
			_b(Vector3(-5.8, y0 - 0.4, 34), Vector3(5.8, -4.6, 44), s)
			_b(Vector3(-1.2, 5, 34.5), Vector3(1.2, 5.8, 36), s)
			_b(Vector3(-4.8, 4.4, 43.8), Vector3(4.8, 5.3, 44.4), look.hc)


func _extra(what: String) -> void:
	match what:
		"backpack":
			_to("torso")
			var c := Color(_pick(["2a6ab0", "c8322b", "3b8a5a", "e0a030", "2b2b30", "8a3a8a"]))
			_b(Vector3(-4.5, -7.5, 21), Vector3(4.5, -3.5, 32), c)
			_b(Vector3(-3.5, -8, 22), Vector3(3.5, -7.5, 26), c.darkened(0.2))
			_b(Vector3(-4.55, -7.55, 30), Vector3(4.55, -3.45, 31), c.darkened(0.3))
			_pair(Vector3(2.8, -3.6, 25), Vector3(3.6, 3.6, 33.5), c.darkened(0.3))
		"headphones":
			_to("head")
			_b(Vector3(-5.8, -1, 47), Vector3(5.8, 1, 48), Color("1c1c22"))
			_pair(Vector3(5, -1.5, 39.5), Vector3(6.4, 1.5, 43), Color("1c1c22"))
		"briefcase":
			_to("arm_r")
			_b(Vector3(6.2, -3, 9), Vector3(7.8, 4, 15), Color("4a2e1c"))
			_b(Vector3(6.6, -0.5, 15), Vector3(7.4, 1.5, 16.5), Color("2a1d14"))
			_b(Vector3(6.1, 0, 13), Vector3(6.2, 1, 14), Color("d4b24a"))
		"handbag":
			_to("arm_l")
			var bag := Color(_pick(["b08a5a", "8a2a3a", "2a2a30", "c8a070", "5a3a5a"]))
			_b(Vector3(-9.8, -2.5, 16), Vector3(-7.8, 3, 22), bag)
			_b(Vector3(-9.85, -2.55, 21.2), Vector3(-7.75, 3.05, 22), bag.darkened(0.2))
			_b(Vector3(-9.9, 0, 19.5), Vector3(-9.8, 1, 20.5), Color("d4b24a"))
			_b(Vector3(-8.6, -0.3, 22), Vector3(-8.2, 0.3, 30), bag.darkened(0.3))
		"phone":
			_to("arm_r")
			_b(Vector3(5.8, 1.2, 17.5), Vector3(7.6, 1.6, 21), Color("1a1a1e"))
			_b(Vector3(6.0, 1.6, 17.9), Vector3(7.4, 1.65, 20.6), Color("7ab8e8"))
		"beads":
			_to("arm_r")
			for i in 7:
				var z := 15.4 - i * 0.9
				_b(Vector3(6.2, 0.6, z - 0.4), Vector3(7.0, 1.4, z + 0.4), Color("2e5a3a") if i % 3 else Color("c9a24a"))
			_b(Vector3(6.3, 0.7, 7.6), Vector3(6.9, 1.3, 8.8), Color("c9a24a"))
		"cane":
			_to("arm_r")
			_b(Vector3(6.4, 2.5, 0.5), Vector3(7.2, 3.3, 17), Color("6a4028"))
			_b(Vector3(6.4, 0.5, 16.2), Vector3(7.2, 3.3, 17.2), Color("6a4028"))
		"newspaper":
			_to("arm_l")
			_b(Vector3(-9.2, -3.8, 17), Vector3(-7.9, 3.8, 19.8), Color("e8e4d8"))
			for y in [-2.5, -0.5, 1.5]:
				_b(Vector3(-9.25, y, 17.6), Vector3(-9.2, y + 1.2, 19.2), Color("8a8680"))
		"book":
			_to("arm_l")
			_b(Vector3(-9.2, -1, 15), Vector3(-7.8, 3, 20), Color("2a5a3a"))
			_b(Vector3(-9.25, -0.8, 15.2), Vector3(-9.2, 2.8, 19.8), Color("c9a24a"))
		"delivery_box":
			_to("torso")
			_b(Vector3(-5.5, -11, 22), Vector3(5.5, -3.6, 33), Color("c8322b"))
			_b(Vector3(-5.55, -11.05, 26), Vector3(5.55, -3.55, 28), Color("f2efe8"))
		"basket":
			_to("arm_l")
			_b(Vector3(-10, -2.5, 12), Vector3(-7.6, 4, 18), Color("b08a5a"))
			_b(Vector3(-9.6, -1.5, 18), Vector3(-8, 3, 19.5), Color("3b8a3a"))
			_b(Vector3(-9.2, 0, 18.5), Vector3(-8.4, 1.5, 20.5), Color("c8322b"))
			_b(Vector3(-8.9, -0.3, 19.5), Vector3(-8.7, 0.3, 24), Color("8a6a3a"))
		"camera":
			_to("torso")
			_b(Vector3(-2.2, 3.6, 25), Vector3(2.2, 5.4, 28), Color("1c1c22"))
			_b(Vector3(-0.8, 5.4, 25.6), Vector3(0.8, 6.4, 27.4), Color("4a4a52"))
			_pair(Vector3(1.8, 3.4, 28), Vector3(2.2, 3.6, 34), Color("1c1c22"))
		"keys":
			_to("arm_r")
			_b(Vector3(6.4, 1.4, 14), Vector3(7.2, 1.8, 16.2), Color("c9ced6"))
		"tea":
			# A glass of tea on its saucer in the right hand.
			_to("arm_r")
			_b(Vector3(5.0, 1.6, 15.6), Vector3(8.4, 5.2, 16.1), Color("ebe6dc"))
			_b(Vector3(5.6, 2.2, 16.1), Vector3(7.8, 4.6, 20.6), Color("c8dce8"))
			_b(Vector3(5.75, 2.35, 16.2), Vector3(7.65, 4.45, 19.6), Color("a8461c"))
			_b(Vector3(5.5, 2.1, 20.4), Vector3(7.9, 4.7, 20.7), Color("eef4f8"))
			_b(Vector3(7.2, 3.6, 20.4), Vector3(7.5, 3.9, 23), Color("c9ced6"))
		"towel":
			# The قهوجي's towel over his left shoulder, red stripes near the ends.
			_to("torso")
			var towel := Color("f1ede4")
			_b(Vector3(-6.6, -4, 33.8), Vector3(-2.8, 4.2, 35), towel)
			_b(Vector3(-5.8, 3.6, 25), Vector3(-3.2, 4.4, 34.6), towel)
			_b(Vector3(-5.8, -4.4, 27), Vector3(-3.2, -3.6, 34.6), towel)
			for z in [26.2, 27.6]:
				_b(Vector3(-5.85, 3.55, z), Vector3(-3.15, 4.45, z + 0.6), Color("c23b2a"))

#endregion
