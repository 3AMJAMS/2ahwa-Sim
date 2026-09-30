class_name Stove3D
extends Station3D
## The hot station in blocks: a red gas cylinder with its burner and a
## hammered كنكة on the flame, and beside it the tea glass on its saucer
## (or a coffee فنجان). HeatGauge feeds `heat` and calls ignite()/pour()/
## boil_over(); PrepStation calls the building steps (sugar, leaves, bag,
## stir, the held pour). Tea made in the glass: the kanaka only boils water;
## sugar and leaves go in the glass and the water takes the tea's colour as
## it steeps and is stirred.

enum Pour { PERFECT, LUKEWARM, TOO_HOT }

const AT := PrepRig.STOVE_AT
const GLASS := PrepRig.GLASS_AT
## Burner top, where the kanaka's base sits.
const RING := AT + Vector3(0, 0.35, 0)
## Kanaka local space: origin at the base centre. (radius, height) up the side.
const K_PROFILE := [Vector2(0.064, 0.0), Vector2(0.071, 0.006), Vector2(0.076, 0.02), Vector2(0.077, 0.056),
	Vector2(0.057, 0.108), Vector2(0.059, 0.124), Vector2(0.072, 0.145)]
const K_RIM := 0.145
## The spout tip; pours pivot on it so the stream stays put.
const SPOUT := Vector3(0.0, 0.15, 0.093)
const REST_PIVOT := RING + SPOUT
const LIFT_PIVOT := REST_PIVOT + Vector3(0, 0.1, 0)
const POUR_PIVOT := GLASS + Vector3(0.0, 0.27, -0.03)
const POUR_TILT := 1.45
const POUR_TILT_END := 1.85
## Tea glass: foot height, (radius at the bottom, at the top), height.
const G_FOOT := 0.022
const G_R := Vector2(0.056, 0.074)
const G_H := 0.2
const GLASS_FULL := 0.86
const SAUCER_H := 0.012
## فنجان: height, (bottom, top) radius.
const CUP_H := 0.1
const CUP_R := Vector2(0.045, 0.063)

const METAL := Color("b3b9c2")
const METAL_DARK := Color("6f7682")
const GRIP := Color("5a3620")
const CYLINDER := Color("b8452f")
const BRASS := Color("c9a24a")
const IRON := Color("2c2a30")
const SAUCER := Color("ebe6dc")
const GOLD := Color("c9a24a")
const BURNT := Color("1e0f08")
const FOAM_BURNT := Color("4a3020")
const WATER := Color(0.78, 0.86, 0.94)
const SUGAR := Color("f4f1ea")
## Height of the sugar layer per spoon.
const SUGAR_PER_SPOON := 0.011
## Flow above this pours too hard and pierces the sugar layer.
const FLOW_PIERCE := 0.72
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

var sugar_spoons := 0
var sugar_melt := 0.0
var leaves := 0.0
var sugar_on_top := false
var steep_top := 0.0
var steep_bottom := 0.0
var bag := 0.0
var bag_dip := 0.0
var swirl := 0.0
## The stirring spoon's angle round the glass (the finger drives it).
var stir_angle := 0.0
var stirring := false
var pierced := false
var pour_flow := 0.0
var show_flow := false
## What's gone into the kanaka (coffee, karkade, tea): tints the water.
var pot_grounds := 0.0

var _liquid := Color("9c3d16")
var _foam := Color("dcb88a")
var _leaf := Color("2e1b0e")
var _cup := false
var _pot_water := false
var _sugar_layer := 1.0
var _swirl_t := 0.0
var _on_burner := true
var _pour_kind := Pour.PERFECT

var _pot := Node3D.new()
var _pot_body := Node3D.new()
var _pot_surface := MeshInstance3D.new()
var _pot_foam := MeshInstance3D.new()
var _drips: Array[MeshInstance3D] = []
var _flames: Array[MeshInstance3D] = []
var _glass_node := Node3D.new()
var _cup_node := Node3D.new()
var _liquid_mi := MeshInstance3D.new()
var _liquid_mat := Station3D.liquid_material()
var _surface := MeshInstance3D.new()
var _surface_mat := StandardMaterial3D.new()
var _cup_surface := MeshInstance3D.new()
var _cup_mat := StandardMaterial3D.new()
var _sugar_mi := MeshInstance3D.new()
var _leaf_mi := MeshInstance3D.new()
var _built_sugar := -1.0
var _built_leaf := Vector2(-1, -1)
var _bits: Array[MeshInstance3D] = []
var _bag := Node3D.new()
var _bag_string := MeshInstance3D.new()
var _spoon := Node3D.new()
var _scoop := Node3D.new()
var _crater := MeshInstance3D.new()
var _spoon_busy := false
var _spoon_queue := 0
var _stream := MeshInstance3D.new()
var _stream_mesh := ImmediateMesh.new()
var _stream_mat := StandardMaterial3D.new()
var _pot_mat := StandardMaterial3D.new()
var _foam_mat := StandardMaterial3D.new()
var _steam_pot: CPUParticles3D
var _steam_glass: CPUParticles3D
var _smoke: CPUParticles3D
var _bubbles: CPUParticles3D
var _drops: CPUParticles3D


func _ready() -> void:
	super()
	var v := Vox.new()
	_build_cylinder(v)
	v.into(self, "Cylinder")
	_build_flames(v)
	_build_pot(v)
	_build_glass(v)
	_build_cup(v)
	_build_spoons(v)
	_build_bag(v)
	_stream.mesh = _stream_mesh
	_stream_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stream_mat.vertex_color_use_as_albedo = true
	_stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stream.material_override = _stream_mat
	add_child(_stream)
	_steam_pot = _puffs(Color(1, 1, 1, 0.22), 0.07, 0.18, 1.8, 24)
	_steam_glass = _puffs(Color(1, 1, 1, 0.16), 0.06, 0.14, 1.8, 16)
	_steam_glass.position = GLASS + Vector3(0, G_H + SAUCER_H, 0)
	_steam_glass.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_steam_glass.emission_sphere_radius = 0.03
	_smoke = _puffs(Color(0.16, 0.14, 0.15, 0.6), 0.12, 0.25, 1.8, 30)
	_smoke.position = RING + Vector3(0, 0.05, 0)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.08
	_bubbles = CPUParticles3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.005
	bm.height = 0.01
	bm.radial_segments = 6
	bm.rings = 3
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1, 1, 1, 0.85)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = bmat
	_bubbles.mesh = bm
	_bubbles.amount = 30
	_bubbles.lifetime = 0.45
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_bubbles.emission_ring_axis = Vector3.UP
	_bubbles.emission_ring_radius = 0.045
	_bubbles.emission_ring_inner_radius = 0.0
	_bubbles.emission_ring_height = 0.0
	_bubbles.gravity = Vector3(0, 0.05, 0)
	_bubbles.initial_velocity_min = 0.0
	_bubbles.initial_velocity_max = 0.02
	_bubbles.emitting = false
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.2))
	grow.add_point(Vector2(0.7, 1.0))
	grow.add_point(Vector2(1, 1.3))
	_bubbles.scale_amount_curve = grow
	_pot_body.add_child(_bubbles)
	_drops = _burst(Vector3.ZERO, Color(0.8, 0.9, 1.0, 0.9), 1, 0.008, Vector3.UP, 0.3, false)
	_drops.one_shot = false
	_drops.emitting = false
	_drops.amount = 20
	_drops.lifetime = 0.35
	_drops.explosiveness = 0.0
	_drops.spread = 60.0
	_drops.initial_velocity_min = 0.25
	_drops.initial_velocity_max = 0.5
	reset()


## Recolours the drink: {"liquid", "foam", "vessel": "glass"|"cup", "leaves"}.
func set_look(look: Dictionary) -> void:
	_liquid = Color(look.get("liquid", "#9c3d16"))
	_foam = Color(look.get("foam", "#dcb88a"))
	_leaf = Color(look["leaves"]) if look.has("leaves") else Color("2e1b0e")
	_cup = look.get("vessel", "glass") == "cup"
	_pot_water = look.get("pot", "") == "water"
	_sugar_layer = float(look.get("sugar_layer", 1.0))
	_glass_node.visible = not _cup
	_cup_node.visible = _cup


## True when the tea is built in the glass and the kanaka just boils water.
func builds_in_glass() -> bool:
	return _pot_water and not _cup


## Kanaka back on a cold ring, full; glass empty.
func reset() -> void:
	_kill_tween()
	_finish_sequence()
	heat = 0.0
	flame = 0.0
	pot_pivot = REST_PIVOT
	pot_tilt = 0.0
	pot_level = 1.0
	pot_grounds = 0.0
	stream = 0.0
	glass_fill = 0.0
	glass_foam = 0.0
	overflow = 0.0
	burn = 0.0
	_on_burner = true
	_pour_kind = Pour.PERFECT
	_reset_ice()
	sugar_spoons = 0
	sugar_melt = 0.0
	leaves = 0.0
	sugar_on_top = false
	steep_top = 0.0
	steep_bottom = 0.0
	bag = 0.0
	bag_dip = 0.0
	swirl = 0.0
	stirring = false
	pierced = false
	pour_flow = 0.0
	show_flow = false
	_scoop.visible = false
	_spoon_busy = false
	_spoon_queue = 0
	_update()


## Hides the tea glass / cup (the blender pours into its own glass).
func show_glass(on: bool) -> void:
	_glass_node.visible = on and not _cup
	_cup_node.visible = on and _cup


## Fresh water in the kanaka back on a cold ring, leaving whatever has
## already gone into the glass (sugar, leaves) where it is.
func reset_pot() -> void:
	_kill_tween()
	_finish_sequence()
	heat = 0.0
	flame = 0.0
	pot_pivot = REST_PIVOT
	pot_tilt = 0.0
	pot_level = 1.0
	stream = 0.0
	overflow = 0.0
	burn = 0.0
	_on_burner = true
	_pour_kind = Pour.PERFECT


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
	t.parallel().tween_property(self, "pot_pivot", LIFT_PIVOT, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "pot_pivot", POUR_PIVOT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "pot_tilt", POUR_TILT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "stream", 1.0, 0.08)
	t.tween_property(self, "glass_fill", GLASS_FULL, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "pot_tilt", POUR_TILT_END, 0.85)
	t.parallel().tween_property(self, "pot_level", 0.0, 0.85)
	if builds_in_glass() and leaves > 0.0:
		# Boiling water straight onto the leaves: dark at the bottom first.
		t.parallel().tween_property(self, "steep_bottom", 0.8, 0.85)
		t.parallel().tween_property(self, "steep_top", 0.35, 0.85).set_ease(Tween.EASE_IN)
	t.tween_property(self, "stream", 0.0, 0.1)
	if kind == Pour.PERFECT and not builds_in_glass():
		t.parallel().tween_property(self, "glass_foam", 1.0, 0.4)
	t.tween_callback(_finish_sequence)
	t.tween_property(self, "pot_pivot", LIFT_PIVOT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "pot_tilt", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "pot_pivot", REST_PIVOT, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await sequence_finished


#region Building tea in the glass

## One spoon of sugar off the tin into the glass (or into the kanaka for
## Turkish coffee); the layer in the glass grows.
func add_sugar(into_pot := false) -> void:
	var to := _pot_mouth() if into_pot else GLASS + Vector3(0, SAUCER_H + G_H + 0.06, 0)
	await _spoonful(PrepRig.JARS.sugar + Vector3(0, 0.1, 0), to, SUGAR, 14)
	if not into_pot:
		sugar_spoons += 1


## A spoonful of loose tea into the glass.
func add_leaves() -> void:
	await _spoonful(PrepRig.JARS.tea + Vector3(0, 0.13, 0), GLASS + Vector3(0, SAUCER_H + G_H + 0.06, 0), _leaf, 18)
	create_tween().tween_property(self, "leaves", 1.0, 0.45)


## Coffee, karkade or tea into the kanaka's water.
func add_to_pot(what: String) -> void:
	var col := {"coffee": Color("3a2014"), "karkade": Color("7a1428"), "tea": Color("2e1b0e")}.get(what, _leaf) as Color
	var from: Vector3 = PrepRig.JARS.get(what, PrepRig.JARS.tea) + Vector3(0, 0.13, 0)
	await _spoonful(from, _pot_mouth(), col, 16)
	create_tween().tween_property(self, "pot_grounds", 1.0, 0.5)


## Dunk the bag once: in it goes (the first time), down and up, and a cloud
## of tea spreads from it.
func dunk_bag() -> void:
	var t := create_tween()
	if bag < 1.0:
		t.tween_property(self, "bag", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "bag_dip", 1.0, 0.18)
	t.tween_property(self, "bag_dip", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "steep_top", minf(steep_top + 0.16, 0.7), 0.6)
	t.parallel().tween_property(self, "steep_bottom", minf(steep_bottom + 0.3, 0.95), 0.6)


## One turn of the spoon. `left` is how many turns remain including this
## one: the colour evens out toward `final` and the sugar melts.
func stir(left: int, final := 1.0) -> void:
	var k := 1.0 / maxf(left, 1)
	var t := create_tween()
	t.tween_property(self, "swirl", 1.0, 0.12)
	t.parallel().tween_property(self, "steep_top", lerpf(steep_top, final, k), 0.7)
	t.parallel().tween_property(self, "steep_bottom", lerpf(steep_bottom, final, k), 0.7)
	t.parallel().tween_property(self, "sugar_melt", lerpf(sugar_melt, 1.0, k), 0.7)
	t.tween_property(self, "swirl", 0.0, 0.6).set_ease(Tween.EASE_OUT)


## Lift the kanaka over to the glass and hold it for a pour the player
## controls (pour_flow); the stream lands on the side of the glass.
func lift_for_pour() -> void:
	_kill_tween()
	_on_burner = false
	var t := create_tween()
	_tween = t
	t.tween_property(self, "flame", 0.0, 0.2)
	t.parallel().tween_property(self, "pot_pivot", LIFT_PIVOT, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "pot_pivot", POUR_PIVOT + Vector3(0, 0.02, -0.01), 0.45).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "pot_tilt", POUR_TILT * 0.6, 0.45).set_trans(Tween.TRANS_SINE)
	await t.finished
	show_flow = true


## Advances the held pour by one frame. Returns true once the glass is full.
func pour_step(delta: float) -> bool:
	stream = pour_flow
	glass_fill = minf(glass_fill + pour_flow * 0.32 * delta, GLASS_FULL)
	var k := glass_fill / GLASS_FULL
	pot_level = 1.0 - k
	pot_tilt = lerpf(POUR_TILT * 0.6, POUR_TILT_END, k) + pour_flow * 0.15
	return glass_fill >= GLASS_FULL - 0.001


## The stream punched through the sugar: tea bleeds up from the leaves.
func pierce() -> void:
	pierced = true
	create_tween().tween_property(self, "steep_bottom", 0.7, 0.5)
	create_tween().tween_property(self, "steep_top", 0.3, 1.2)


## Back to the ring after a held pour.
func end_pour() -> void:
	show_flow = false
	stream = 0.0
	pour_flow = 0.0
	var t := create_tween()
	t.tween_property(self, "pot_pivot", LIFT_PIVOT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "pot_tilt", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "pot_pivot", REST_PIVOT, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished


## Screen rect round the glass (or cup), for gestures and the tutorial.
func glass_rect() -> Rect2:
	var h := CUP_H if _cup else G_H
	return local_rect(AABB(GLASS + Vector3(-0.08, 0, -0.08), Vector3(0.16, h + 0.05, 0.16)))


## Screen rect round the kanaka wherever it is (tap it to light the fire,
## take it off, hold it to pour).
func kanaka_rect() -> Rect2:
	var base := pot_pivot - SPOUT
	return local_rect(AABB(base + Vector3(-0.1, -0.02, -0.33), Vector3(0.2, 0.22, 0.45)))


## The middle of the glass on screen (the stir circles round it).
func glass_centre() -> Vector2:
	return screen_of(GLASS + Vector3(0, SAUCER_H + G_H * 0.55, 0))

#endregion


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
	_swirl_t += delta * (2.0 + 10.0 * swirl)
	_update()


func _update() -> void:
	var boil := clampf(heat / 100.0, 0.0, 1.0)
	# The kanaka: position, jitter as it comes to the boil, tilt.
	var jitter := Vector3.ZERO
	if _on_burner and heat > 80.0:
		var amp := (heat - 80.0) / 20.0 * 0.002 + overflow * 0.002
		jitter = Vector3(sin(_t * 53.0), 0, sin(_t * 41.0 + 1.3)) * amp
	_pot.position = pot_pivot + jitter
	_pot.rotation.x = pot_tilt
	# Flames flicker round the ring.
	for i in _flames.size():
		var f := _flames[i]
		var k := flame * (0.8 + 0.25 * sin(_t * 23.0 + i * 1.7) + 0.1 * sin(_t * 41.0 + i))
		f.scale = Vector3(1.0, maxf(k, 0.001), 1.0) * (0.6 + 0.4 * flame)
		f.visible = flame > 0.02
	Vox.set_glow("glow/flame", 1.5 + 1.5 * flame)
	# What's in the kanaka.
	var liquid := _liquid.darkened(0.3)
	var foam := _foam
	if _pot_water:
		liquid = WATER.darkened(0.35).lerp(Color("2e1b0e"), pot_grounds * 0.7)
		foam = WATER.lightened(0.4)
	liquid = liquid.lerp(BURNT, burn)
	foam = foam.lerp(FOAM_BURNT if not _pot_water else Color("8a8078"), burn)
	var cover := smoothstep(42.0, 66.0, heat)
	var upright := clampf(1.0 - absf(pot_tilt) / 0.35, 0.0, 1.0) * pot_level
	_pot_mat.albedo_color = liquid.lerp(foam, cover * 0.7)
	_pot_surface.visible = upright > 0.01
	var surf_y := lerpf(0.03, K_RIM - 0.015, pot_level) + sin(_t * 9.0) * boil * 0.002
	_pot_surface.position.y = surf_y
	var r := _k_radius(surf_y)
	_pot_surface.scale = Vector3(r, 1, r)
	var rise := smoothstep(58.0, 82.0, heat) * 0.035 + _spill() * 0.02
	var foamy := not _pot_water or heat > 60.0
	_pot_foam.visible = upright > 0.01 and rise > 0.002 and foamy
	_foam_mat.albedo_color = foam.lightened(0.1)
	_pot_foam.position.y = surf_y
	_pot_foam.scale = Vector3(r * (1.0 + _spill() * 0.25), rise + 0.001, r * (1.0 + _spill() * 0.25))
	for i in _drips.size():
		var d := _drips[i]
		var start := [0.0, 0.3, 0.12, 0.45, 0.2, 0.6][i] as float
		var k := clampf((_spill() - start) / (1.0 - start), 0.0, 1.0)
		d.visible = k > 0.01
		d.scale = Vector3(1, k, 1)
		(d.material_override as StandardMaterial3D).albedo_color = foam
	_bubbles.emitting = _on_burner and heat > 25.0 and upright > 0.5
	_bubbles.amount = 30
	_bubbles.position = Vector3(0, surf_y + 0.003, 0)
	_bubbles.speed_scale = lerpf(0.5, 1.6, boil)
	_steam_pot.emitting = _on_burner and heat > 5.0
	_steam_pot.position = global_transform.affine_inverse() * _pot_body.to_global(Vector3(0, K_RIM + 0.02, 0))
	_steam_pot.speed_scale = lerpf(0.4, 1.4, boil)
	_smoke.emitting = maxf(overflow, burn) > 0.05
	# The glass (or cup).
	var drink := _served_color(_pour_kind)
	if _cup:
		_cup_surface.visible = glass_fill > 0.001
		var cy := SAUCER_H + lerpf(0.02, CUP_H - 0.006, glass_fill / GLASS_FULL)
		_cup_surface.position.y = cy
		var cr := lerpf(CUP_R.x, CUP_R.y, cy / CUP_H) - 0.004
		_cup_surface.scale = Vector3(cr, 1, cr)
		_cup_mat.albedo_color = drink.lerp(_foam.lightened(0.2), glass_foam)
	else:
		_update_glass(drink)
	_steam_glass.emitting = glass_fill > 0.1 and not iced
	_steam_glass.amount = 16
	_steam_glass.speed_scale = GLASS_STEAM[_pour_kind] * (0.6 + 0.4 * glass_fill)
	_update_stream(drink)
	_update_spoon()


func _update_glass(drink: Color) -> void:
	var floor_y := SAUCER_H + G_FOOT
	var sugar_h := sugar_spoons * SUGAR_PER_SPOON * _sugar_layer * (1.0 - sugar_melt)
	var bed_h := 0.008 * leaves * (1.0 - 0.6 * sugar_melt)
	var sugar_base := floor_y + (bed_h if sugar_on_top else 0.0)
	var leaf_base := floor_y if sugar_on_top else floor_y + sugar_h
	if absf(sugar_h - _built_sugar) > 0.0004:
		_built_sugar = sugar_h
		_sugar_mi.mesh = _layer_mesh(sugar_base, sugar_base + sugar_h, SUGAR, true) if sugar_h > 0.0005 else null
	var leaf_key := Vector2(leaf_base, bed_h)
	if leaf_key.distance_to(_built_leaf) > 0.0004:
		_built_leaf = leaf_key
		_leaf_mi.mesh = _layer_mesh(leaf_base, leaf_base + bed_h, _leaf, false) if bed_h > 0.0005 else null
	_crater.visible = pierced and sugar_h > 0.001
	_crater.position = Vector3(0, sugar_base + sugar_h + 0.001, -0.02)
	# The water, taking on the tea's colour (or the drink as poured).
	var top_y := floor_y + glass_fill * (G_H - G_FOOT - 0.012)
	var bottom_col := drink
	var top_col := drink
	if builds_in_glass():
		var tea := _brew_color(_pour_kind)
		bottom_col = WATER.lerp(tea, steep_bottom)
		top_col = WATER.lerp(tea, steep_top)
		bottom_col.a = lerpf(0.3, 0.92, steep_bottom)
		top_col.a = lerpf(0.3, 0.92, steep_top)
	else:
		bottom_col.a = 0.92
		top_col = drink.lerp(_foam.lightened(0.3), glass_foam * 0.6)
		top_col.a = 0.92
	var show := glass_fill > 0.001
	_liquid_mi.visible = show
	_surface.visible = show
	_liquid_mat.set_shader_parameter("col_bottom", bottom_col)
	_liquid_mat.set_shader_parameter("col_top", top_col)
	_liquid_mat.set_shader_parameter("y0", floor_y)
	_liquid_mat.set_shader_parameter("y1", top_y)
	_liquid_mat.set_shader_parameter("swirl", swirl)
	_surface.position.y = top_y
	var sr := lerpf(G_R.x, G_R.y, (top_y - SAUCER_H) / G_H) - 0.005
	_surface.scale = Vector3(sr, 1, sr)
	var sc := top_col.lightened(0.15)
	if not builds_in_glass() and glass_foam > 0.0:
		sc = sc.lerp(_foam.lightened(0.45), glass_foam)
	sc.a = maxf(top_col.a, 0.55)
	_surface_mat.albedo_color = sc
	# Leaf bits lifting into the water as it's stirred.
	for i in _bits.size():
		var b := _bits[i]
		b.visible = leaves > 0.0 and (glass_fill > 0.05 or i < 6)
		var lift := float((i * 13) % 50) / 50.0 * 0.06 * sugar_melt * (0.5 + 0.5 * sin(_swirl_t + i))
		var a := i * 2.4 + _swirl_t * 0.6 * swirl
		var rr := 0.012 + float((i * 7) % 5) * 0.005
		b.position = Vector3(cos(a) * rr, leaf_base + bed_h + 0.003 + lift, sin(a) * rr)
	# The tea bag.
	_bag.visible = bag > 0.0
	var bag_y := lerpf(G_H + 0.05, floor_y + 0.035, bag) - bag_dip * 0.02
	_bag.position = Vector3(0.005, bag_y, -0.005)
	var rim := Vector3(0.0, SAUCER_H + G_H, -G_R.y + 0.004)
	var im := _bag_string.mesh as ImmediateMesh
	im.clear_surfaces()
	if bag > 0.0:
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_set_color(Color("f4f1ea"))
		im.surface_add_vertex(_bag.position + Vector3(0, 0.03, 0))
		im.surface_add_vertex(rim)
		im.surface_add_vertex(rim)
		im.surface_add_vertex(rim + Vector3(0, -0.04, -0.012))
		im.surface_end()


## The stirring spoon rides round the glass with the finger.
func _update_spoon() -> void:
	var y0 := SAUCER_H + G_FOOT + 0.02
	if stirring or swirl > 0.02:
		var r := 0.022
		var tip := Vector3(cos(stir_angle) * r, y0, sin(stir_angle) * r)
		_spoon.position = tip
		_spoon.rotation = Vector3(0.25 * sin(stir_angle), 0, -0.25 * cos(stir_angle))
	else:
		_spoon.position = Vector3(0.0, y0 + 0.01, 0.02)
		_spoon.rotation = Vector3(0.4, 0, 0.35)
	_spoon.visible = not _cup and (glass_fill > 0.05 or sugar_spoons > 0 or stirring)


func _update_stream(color: Color) -> void:
	_stream_mesh.clear_surfaces()
	if stream <= 0.01:
		_drops.emitting = false
		return
	var p0 := _pot.position + (_pot.basis * Vector3(0, 0.0, 0.004))
	var end := _stream_end()
	var p1 := p0 + Vector3(0, -0.01, 0.03)
	var w := 0.011 * stream
	var col := Color(color.darkened(0.05), 0.9) if not builds_in_glass() else Color(0.62, 0.78, 0.92, 0.85)
	_stream_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_stream_mesh.surface_set_color(col)
	var n := 10
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_f := Vector3.ZERO
	var prev_b := Vector3.ZERO
	for i in n + 1:
		var t := i / float(n)
		var p := p0.lerp(p1, t).lerp(p1.lerp(end, t), t)
		p += Vector3(sin(_t * 25.0 + t * 9.0), 0, cos(_t * 21.0 + t * 7.0)) * 0.0008 * t
		var ww := lerpf(w, w * 0.65, t)
		var l := p + Vector3(ww, 0, 0)
		var r := p - Vector3(ww, 0, 0)
		var f := p + Vector3(0, 0, ww)
		var b := p - Vector3(0, 0, ww)
		if i > 0:
			for quad in [[prev_l, l, prev_f, f], [prev_f, f, prev_r, r], [prev_r, r, prev_b, b], [prev_b, b, prev_l, l]]:
				_stream_mesh.surface_add_vertex(quad[0])
				_stream_mesh.surface_add_vertex(quad[1])
				_stream_mesh.surface_add_vertex(quad[2])
				_stream_mesh.surface_add_vertex(quad[2])
				_stream_mesh.surface_add_vertex(quad[1])
				_stream_mesh.surface_add_vertex(quad[3])
		prev_l = l
		prev_r = r
		prev_f = f
		prev_b = b
	_stream_mesh.surface_end()
	_drops.position = end
	_drops.emitting = stream > 0.3
	((_drops.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = Color(color.lightened(0.2), 0.9)


func _stream_end() -> Vector3:
	var top_y := SAUCER_H + G_FOOT + glass_fill * (G_H - G_FOOT - 0.012)
	if _cup:
		top_y = SAUCER_H + lerpf(0.02, CUP_H - 0.006, glass_fill / GLASS_FULL)
	var off := Vector3(0, 0, -0.035) if show_flow else Vector3(0, 0, -0.008)
	return GLASS + Vector3(0, top_y, 0) + off


func _pot_mouth() -> Vector3:
	return (pot_pivot - SPOUT) + Vector3(0, K_RIM + 0.07, 0)


func _k_radius(y: float) -> float:
	for i in K_PROFILE.size() - 1:
		var a: Vector2 = K_PROFILE[i]
		var b: Vector2 = K_PROFILE[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.0001)) - 0.004
	return 0.06


func _spill() -> float:
	return clampf(maxf((heat - 85.0) / 15.0, 0.0) * 0.7 + overflow, 0.0, 1.0)


func _served_color(kind: Pour) -> Color:
	if builds_in_glass():
		return WATER
	return _brew_color(kind)


## The drink's colour as poured: paler if lukewarm, stewed if too hot.
func _brew_color(kind: Pour) -> Color:
	match kind:
		Pour.LUKEWARM:
			return _liquid.lerp(Color("d8b48a"), 0.45)
		Pour.TOO_HOT:
			return _liquid.darkened(0.55)
	return _liquid


## A spoon dips into the jar, swings over and tips its load in. Quick taps
## queue up, one spoonful after another.
func _spoonful(from: Vector3, to: Vector3, col: Color, grains: int) -> void:
	_spoon_queue += 1
	while _spoon_busy:
		await get_tree().process_frame
	_spoon_busy = true
	_scoop.visible = true
	_scoop.position = from + Vector3(0, 0.05, 0)
	_scoop.rotation = Vector3.ZERO
	var t := create_tween()
	t.tween_property(_scoop, "position", from, 0.07)
	t.tween_property(_scoop, "position", from.lerp(to, 0.5) + Vector3(0, 0.08, 0), 0.12).set_trans(Tween.TRANS_SINE)
	t.tween_property(_scoop, "position", to, 0.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(_scoop, "rotation:z", 1.2, 0.1)
	t.tween_callback(func() -> void: _burst(to + Vector3(0, -0.01, 0), col, grains, 0.006, Vector3(0, -0.2, 0), 0.4))
	await t.finished
	_spoon_queue -= 1
	_spoon_busy = false
	if _spoon_queue == 0:
		var back := create_tween()
		back.tween_property(_scoop, "rotation:z", 0.0, 0.1)
		back.parallel().tween_property(_scoop, "position", from + Vector3(0, 0.08, 0), 0.2)
		back.tween_callback(func() -> void:
			if _spoon_queue == 0:
				_scoop.visible = false)
	await get_tree().create_timer(0.15).timeout


func _focus_box() -> AABB:
	return AABB(AT + Vector3(-0.15, 0, -0.35), Vector3(0.3, 0.55, 0.5))


func _ice_surface() -> Vector3:
	var top_y := SAUCER_H + G_FOOT + glass_fill * (G_H - G_FOOT - 0.012)
	return GLASS + Vector3(0, top_y, 0)


#region Building the meshes

func _build_cylinder(v: Vox) -> void:
	# Red cylinder with a white band, dome, collar, valve and the burner.
	v.push_at(AT)
	v.lathe([Vector2(0.105, 0.0), Vector2(0.12, 0.02), Vector2(0.12, 0.21), Vector2(0.1, 0.26), Vector2(0.045, 0.285)],
		14, CYLINDER)
	v.cyl(Vector3(0, 0.1, 0), 0.121, 0.121, 0.035, Color("efe6d2"), 14)
	v.cyl(Vector3(0, 0.0, 0), 0.108, 0.108, 0.015, IRON, 14)
	v.cyl(Vector3(0, 0.28, 0), 0.05, 0.05, 0.025, BRASS, 10)
	v.cyl(Vector3(0, 0.305, 0), 0.04, 0.03, 0.02, IRON, 10)
	v.rod(Vector3(0.0, 0.29, 0.04), Vector3(0.0, 0.29, 0.09), 0.012, BRASS, 6)
	v.cyl(Vector3(0.0, 0.28, 0.1), 0.018, 0.018, 0.03, Color("c8322b"), 8)
	# Burner head and the three pot-support prongs.
	v.cyl(Vector3(0, 0.322, 0), 0.042, 0.048, 0.02, IRON, 12)
	v.cyl(Vector3(0, 0.34, 0), 0.036, 0.036, 0.004, Color("4a4850"), 12)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		v.rod(Vector3(cos(a) * 0.045, 0.325, sin(a) * 0.045), Vector3(cos(a) * 0.085, 0.35, sin(a) * 0.085), 0.006, IRON, 4)
		v.cube(Vector3(cos(a) * 0.075, 0.35, sin(a) * 0.075), Vector3(0.03, 0.006, 0.01), IRON)
	# A sticker with the gas company's flame and a scratch or two.
	v.box(Vector3(0.11, 0.14, -0.04), Vector3(0.121, 0.2, 0.04), Color("f4f1ea"))
	v.box(Vector3(0.12, 0.155, -0.012), Vector3(0.123, 0.185, 0.012), Color("2a6ab0"))
	v.pop()


func _build_flames(v: Vox) -> void:
	for k in 10:
		var a := TAU * k / 10.0
		var f := MeshInstance3D.new()
		v.use("glow/flame")
		v.push_at(Vector3.ZERO, Vector3(0, -rad_to_deg(a), 0))
		v.lathe([Vector2(0.006, 0.0), Vector2(0.008, 0.012), Vector2(0.0, 0.034)], 5, Color("4a7aff"))
		v.pop()
		f.mesh = v.commit()
		f.position = RING + Vector3(cos(a) * 0.03, -0.012, sin(a) * 0.03)
		add_child(f)
		_flames.append(f)


func _build_pot(v: Vox) -> void:
	add_child(_pot)
	_pot.add_child(_pot_body)
	_pot_body.position = -SPOUT
	# Hammered body: the outer wall, the dark inside, the flared lip.
	v.lathe(K_PROFILE, 14, METAL, false)
	var inner: Array = []
	for i in range(K_PROFILE.size() - 1, -1, -1):
		var p: Vector2 = K_PROFILE[i]
		inner.append(Vector2(p.x - 0.004, maxf(p.y, 0.004)))
	v.lathe(inner, 14, Color("3a302a"), false, true)
	# Dimples and an engraved band.
	for k in 20:
		var a := k * 2.39
		var y := 0.02 + float((k * 31) % 80) / 1000.0
		var r := _k_profile_r(y) + 0.001
		v.cube(Vector3(cos(a) * r, y, sin(a) * r), Vector3(0.008, 0.008, 0.008), METAL.lightened(0.15) if k % 2 else METAL_DARK)
	v.cyl(Vector3(0, 0.07, 0), 0.0775, 0.0775, 0.006, METAL_DARK, 14)
	# Spout, pinched out of the lip toward +z.
	v.poly([Vector3(-0.022, K_RIM, 0.068), Vector3(0.022, K_RIM, 0.068), Vector3(0.0, K_RIM + 0.004, SPOUT.z)], METAL, Vector3.UP)
	v.poly([Vector3(-0.022, K_RIM, 0.068), Vector3(0.0, K_RIM + 0.004, SPOUT.z), Vector3(0.0, K_RIM - 0.02, 0.07)],
		METAL_DARK, Vector3(-1, 0, 0.3))
	v.poly([Vector3(0.022, K_RIM, 0.068), Vector3(0.0, K_RIM + 0.004, SPOUT.z), Vector3(0.0, K_RIM - 0.02, 0.07)],
		METAL_DARK, Vector3(1, 0, 0.3))
	# Long handle toward -z with a wooden grip, riveted at the neck.
	v.rod(Vector3(0, 0.1, -0.06), Vector3(0, 0.125, -0.2), 0.008, METAL_DARK, 6)
	v.rod(Vector3(0, 0.123, -0.19), Vector3(0, 0.145, -0.32), 0.014, GRIP, 6)
	v.ball(Vector3(0, 0.146, -0.322), Vector3(0.015, 0.015, 0.015), GRIP, 6, 3)
	for y in [0.095, 0.108]:
		v.cube(Vector3(0, y, -0.062), Vector3(0.008, 0.006, 0.006), Color("e6e9ee"))
	v.into(_pot_body, "Body")
	# The drink's surface, the foam, spill drips (all resized each frame).
	v.use("solid").cyl(Vector3.ZERO, 1.0, 1.0, 0.002, Color.WHITE, 14)
	_pot_surface.mesh = v.commit()
	_pot_mat.roughness = 0.2
	_pot_surface.material_override = _pot_mat
	_pot_body.add_child(_pot_surface)
	v.ball(Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Color.WHITE, 12, 3)
	_pot_foam.mesh = v.commit()
	_foam_mat.roughness = 0.9
	_pot_foam.material_override = _foam_mat
	_pot_body.add_child(_pot_foam)
	for i in 6:
		var a := -0.9 + i * 0.36
		var d := MeshInstance3D.new()
		v.box(Vector3(-0.006, -0.1, -0.004), Vector3(0.006, 0.0, 0.004), Color.WHITE)
		d.mesh = v.commit()
		var m := StandardMaterial3D.new()
		d.material_override = m
		d.position = Vector3(sin(a) * 0.075, K_RIM, cos(a) * 0.075)
		d.rotation.y = a
		_pot_body.add_child(d)
		_drips.append(d)


func _k_profile_r(y: float) -> float:
	for i in K_PROFILE.size() - 1:
		var a: Vector2 = K_PROFILE[i]
		var b: Vector2 = K_PROFILE[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.0001))
	return 0.07


func _build_glass(v: Vox) -> void:
	_glass_node.position = GLASS
	add_child(_glass_node)
	# Saucer.
	v.lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.12, 0.009), Vector2(0.122, SAUCER_H)], 18, SAUCER)
	v.cyl(Vector3(0, SAUCER_H - 0.001, 0), 0.064, 0.064, 0.002, SAUCER.darkened(0.07), 18)
	v.cyl(Vector3(0, SAUCER_H - 0.002, 0), 0.108, 0.108, 0.002, GOLD, 18)
	v.into(_glass_node, "Saucer")
	# The contents (under the glass so the glass draws over them).
	var r0 := G_R.x - 0.004
	var r1 := G_R.y - 0.005
	v.push_at(Vector3(0, SAUCER_H, 0))
	v.lathe([Vector2(0.0, G_FOOT), Vector2(r0, G_FOOT), Vector2(r1, G_H - 0.004)], 14, Color.WHITE, false)
	v.pop()
	_liquid_mi.mesh = v.commit()
	_liquid_mi.material_override = _liquid_mat
	_liquid_mat.render_priority = -1
	_glass_node.add_child(_liquid_mi)
	v.cyl(Vector3.ZERO, 1.0, 1.0, 0.001, Color.WHITE, 14)
	_surface.mesh = v.commit()
	_surface_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_surface_mat.roughness = 0.1
	_surface_mat.render_priority = -1
	_surface.material_override = _surface_mat
	_glass_node.add_child(_surface)
	_glass_node.add_child(_sugar_mi)
	_glass_node.add_child(_leaf_mi)
	for i in 14:
		var b := MeshInstance3D.new()
		v.cube(Vector3.ZERO, Vector3(0.006, 0.003, 0.005), _leaf)
		b.mesh = v.commit()
		b.rotation = Vector3(i * 0.7, i * 1.3, 0)
		_glass_node.add_child(b)
		_bits.append(b)
	v.cyl(Vector3.ZERO, 0.014, 0.014, 0.002, Color("3a2a1c"), 8)
	_crater.mesh = v.commit()
	_glass_node.add_child(_crater)
	# The glass itself: thick foot, walls, rim; pressed facets on the lower half.
	v.use("glass")
	v.push_at(Vector3(0, SAUCER_H, 0))
	v.lathe([Vector2(G_R.x, 0.0), Vector2(G_R.y, G_H)], 14, Color(0.86, 0.94, 1.0, 0.22), false, true)
	v.lathe([Vector2(G_R.y - 0.003, G_H), Vector2(G_R.x - 0.004, G_FOOT)], 14, Color(0.86, 0.94, 1.0, 0.12), false, false)
	v.cyl(Vector3(0, 0.0, 0), G_R.x - 0.002, G_R.x - 0.004, G_FOOT, Color(0.9, 0.96, 1.0, 0.4), 14)
	v.lathe([Vector2(G_R.y + 0.001, G_H - 0.004), Vector2(G_R.y + 0.001, G_H)], 14, Color(1, 1, 1, 0.6), false, false)
	for k in 7:
		var a := TAU * k / 7.0
		v.box(Vector3(cos(a) * (G_R.x + 0.001) - 0.002, G_FOOT, sin(a) * (G_R.x + 0.001) - 0.002),
			Vector3(cos(a) * (G_R.x + 0.001) + 0.002, G_H * 0.45, sin(a) * (G_R.x + 0.001) + 0.002), Color(1, 1, 1, 0.3))
	v.pop()
	v.use("solid")
	var gm := v.into(_glass_node, "Glass")
	(gm.mesh.surface_get_material(0) as Material).render_priority = 1


func _build_cup(v: Vox) -> void:
	_cup_node.position = GLASS
	add_child(_cup_node)
	v.lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.12, 0.009), Vector2(0.122, SAUCER_H)], 18, SAUCER)
	v.push_at(Vector3(0, SAUCER_H, 0))
	v.lathe([Vector2(CUP_R.x, 0.0), Vector2(CUP_R.y, CUP_H)], 16, Color("f4f1ea"), false, true)
	v.lathe([Vector2(CUP_R.y - 0.004, CUP_H), Vector2(CUP_R.x - 0.004, 0.006)], 16, Color("3a2418"), false, true)
	v.cyl(Vector3(0, CUP_H - 0.02, 0), CUP_R.y * 0.97 + 0.001, CUP_R.y * 0.97 + 0.001, 0.006, GOLD, 16)
	v.sweep(Vox.round_rect(Rect2(-0.006, -0.003, 0.012, 0.006), 0.002, 1), [Vector3(0, CUP_H * 0.75, -CUP_R.y + 0.004),
		Vector3(0, CUP_H * 0.75, -CUP_R.y - 0.025), Vector3(0, CUP_H * 0.3, -CUP_R.y - 0.022), Vector3(0, CUP_H * 0.25, -CUP_R.x)],
		Color("f4f1ea"), Vector3.RIGHT)
	v.pop()
	v.into(_cup_node, "Cup")
	v.cyl(Vector3.ZERO, 1.0, 1.0, 0.002, Color.WHITE, 16)
	_cup_surface.mesh = v.commit()
	_cup_mat.roughness = 0.5
	_cup_surface.material_override = _cup_mat
	_cup_node.add_child(_cup_surface)
	_cup_node.visible = false


func _build_spoons(v: Vox) -> void:
	# The teaspoon that stands in the glass and stirs.
	v.rod(Vector3.ZERO, Vector3(0, 0.2, 0), 0.0035, METAL, 4)
	v.ball(Vector3(0, 0.0, 0), Vector3(0.009, 0.004, 0.014), METAL, 6, 2)
	v.ball(Vector3(0, 0.2, 0), Vector3(0.006, 0.01, 0.004), Color("e6e9ee"), 6, 2)
	v.into(_spoon, "Spoon")
	_glass_node.add_child(_spoon)
	# The scooping spoon that carries sugar and leaves over.
	v.rod(Vector3(0, 0, 0), Vector3(0.13, 0.05, 0), 0.004, METAL, 4)
	v.push_at(Vector3(-0.012, 0.0, 0))
	v.lathe([Vector2(0.0, -0.006), Vector2(0.016, 0.0), Vector2(0.018, 0.003)], 10, METAL, false)
	v.pop()
	v.into(_scoop, "Scoop")
	_scoop.visible = false
	add_child(_scoop)


func _build_bag(v: Vox) -> void:
	# A tea bag: the paper pouch, folded top and staple; the tag hangs
	# outside the glass on its string.
	v.box(Vector3(-0.016, -0.03, -0.003), Vector3(0.016, 0.02, 0.003), Color("e6dcc6"))
	v.box(Vector3(-0.016, 0.02, -0.003), Vector3(0.016, 0.03, 0.003), Color("f0e8d4"))
	v.cube(Vector3(0, 0.03, 0), Vector3(0.006, 0.004, 0.007), Color("b3b9c2"))
	v.box(Vector3(-0.014, -0.028, 0.003), Vector3(0.014, 0.0, 0.0035), Color("8a5a3a"))
	v.into(_bag, "Bag")
	_glass_node.add_child(_bag)
	v.box(Vector3(-0.012, -0.035, -0.002), Vector3(0.012, 0.0, 0.002), Color("c23b2a"))
	v.box(Vector3(-0.008, -0.03, 0.002), Vector3(0.008, -0.006, 0.003), Color("f2d24a"))
	var tag := v.into(_glass_node, "Tag")
	tag.position = Vector3(0.0, SAUCER_H + G_H - 0.04, -G_R.y - 0.014)
	_bag.visibility_changed.connect(func() -> void: tag.visible = _bag.visible)
	tag.visible = false
	_bag_string.mesh = ImmediateMesh.new()
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	_bag_string.material_override = sm
	_glass_node.add_child(_bag_string)


## A layer (sugar or leaves) filling the glass between two heights.
func _layer_mesh(y0: float, y1: float, col: Color, heaped: bool) -> ArrayMesh:
	var v := Vox.new()
	var r0 := lerpf(G_R.x, G_R.y, (y0 - SAUCER_H) / G_H) - 0.005
	var r1 := lerpf(G_R.x, G_R.y, (y1 - SAUCER_H) / G_H) - 0.005
	var prof := [Vector2(r0, y0), Vector2(r1, y1)]
	if heaped:
		prof.append(Vector2(r1 * 0.5, y1 + 0.004 * (1.0 - sugar_melt)))
		prof.append(Vector2(0.0, y1 + 0.005 * (1.0 - sugar_melt)))
	v.lathe(prof, 14, col)
	return v.commit()

#endregion
