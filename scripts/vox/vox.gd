class_name Vox
extends RefCounted
## Builds the game's blocky low-poly meshes: boxes, extruded profiles,
## lathed round things (kanakas, glasses, wheels) and swept tubes, with
## their colour in the vertices. Flat faces are flat-shaded; lathed round
## things are smooth-shaded round their axis and along gentle curves (a
## sharp turn in the profile, like a lip, stays a crisp edge), and every
## round thing gets DETAIL times the sides it asks for. Everything added between
## two commit() calls merges into one ArrayMesh, one draw call per material,
## so a whole car or a whole street costs a handful of draw calls.
##
## Authored in metres, y up. `xf` (push/pop) places what's added. Solid
## parts are closed and their faces point outward; each helper works out
## the winding from the direction a face should face, so callers never do.
##
## Materials, by the name picked with use():
##   "solid"        lit, vertex colour
##   "shiny"        lit, polished (brass, steel): tighter, brighter highlights
##   "glass"        lit, see-through (vertex alpha)
##   "glow/<name>"  unshaded, vertex colour × that group's brightness, so
##                  lamps, lit windows and LEDs bloom; set_glow() drives them.

var xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []
var _kind := "solid"
## kind -> [PackedVector3Array verts, PackedVector3Array normals, PackedColorArray colours]
var _parts := {}

## Round things get this many times the sides they're built with.
const DETAIL := 1.5

static var _materials := {}
static var _glow := {}
## The web build's renderer takes vertex colours as they are, ignoring the
## material's "is sRGB" flag, which washes everything out: convert them here.
static var _linear_colors := RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Picks the material what's added next goes into ("solid", "glass", "glow/<name>").
func use(kind: String) -> Vox:
	_kind = kind
	return self


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func push_at(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	push(Transform3D(b, pos))


func pop() -> void:
	xf = _stack.pop_back()


func is_empty() -> bool:
	return _parts.is_empty()


#region Primitives

## A planar convex polygon facing `out` (a direction in local space).
func poly(pts: Array, col: Color, out: Vector3) -> void:
	_poly_n(pts, [], col, out)


## poly() with a normal per point (local space) for smooth shading; empty
## `nrms` means flat.
func _poly_n(pts: Array, nrms: Array, col: Color, out: Vector3) -> void:
	if pts.size() < 3:
		return
	var w: Array = _buf()
	var a: Vector3 = xf * (pts[0] as Vector3)
	var nrm := Vector3.ZERO
	var world: Array[Vector3] = [a]
	for i in range(1, pts.size()):
		world.append(xf * (pts[i] as Vector3))
	for i in range(1, world.size() - 1):
		nrm += (world[i] - a).cross(world[i + 1] - a)
	if nrm.length_squared() < 1e-16:
		return
	nrm = nrm.normalized()
	var vn: Array[Vector3] = []
	if not nrms.is_empty():
		# Normals go through the inverse transpose (balls are scaled).
		var nb := xf.basis.inverse().transposed()
		for n: Vector3 in nrms:
			vn.append((nb * n).normalized())
	var o := (xf.basis * out)
	if nrm.dot(o) < 0.0:
		nrm = -nrm
		world.reverse()
		vn.reverse()
		a = world[0]
	if vn.is_empty():
		for i in world.size():
			vn.append(nrm)
	# Godot's front faces wind clockwise seen from outside: emit a, c, b.
	var verts: PackedVector3Array = w[0]
	var norms: PackedVector3Array = w[1]
	var cols: PackedColorArray = w[2]
	for i in range(1, world.size() - 1):
		verts.append(a)
		verts.append(world[i + 1])
		verts.append(world[i])
		norms.append(vn[0])
		norms.append(vn[i + 1])
		norms.append(vn[i])
		for k in 3:
			cols.append(col)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	poly([a, b, c, d], col, out)


## Axis-aligned box between two corners.
func box(lo: Vector3, hi: Vector3, col: Color) -> void:
	var l := Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z))
	var h := Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z))
	quad(Vector3(h.x, l.y, l.z), Vector3(h.x, h.y, l.z), Vector3(h.x, h.y, h.z), Vector3(h.x, l.y, h.z), col, Vector3.RIGHT)
	quad(Vector3(l.x, l.y, l.z), Vector3(l.x, h.y, l.z), Vector3(l.x, h.y, h.z), Vector3(l.x, l.y, h.z), col, Vector3.LEFT)
	quad(Vector3(l.x, h.y, l.z), Vector3(h.x, h.y, l.z), Vector3(h.x, h.y, h.z), Vector3(l.x, h.y, h.z), col, Vector3.UP)
	quad(Vector3(l.x, l.y, l.z), Vector3(h.x, l.y, l.z), Vector3(h.x, l.y, h.z), Vector3(l.x, l.y, h.z), col, Vector3.DOWN)
	quad(Vector3(l.x, l.y, h.z), Vector3(h.x, l.y, h.z), Vector3(h.x, h.y, h.z), Vector3(l.x, h.y, h.z), col, Vector3.BACK)
	quad(Vector3(l.x, l.y, l.z), Vector3(h.x, l.y, l.z), Vector3(h.x, h.y, l.z), Vector3(l.x, h.y, l.z), col, Vector3.FORWARD)


## Box by centre and size.
func cube(center: Vector3, size: Vector3, col: Color) -> void:
	box(center - size * 0.5, center + size * 0.5, col)


## The same box mirrored across x = 0 (left and right of a body).
func pair(lo: Vector3, hi: Vector3, col: Color) -> void:
	box(lo, hi, col)
	box(Vector3(-hi.x, lo.y, lo.z), Vector3(-lo.x, hi.y, hi.z), col)


## A box with its four edges along `axis` ("x", "y" or "z") bevelled by `r`
## (`seg` facets per corner), so it reads as rounded: bumpers, roofs, tyres
## seen side-on, mattresses.
func rbox(lo: Vector3, hi: Vector3, r: float, col: Color, axis := "x", seg := 2) -> void:
	var l := Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z))
	var h := Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z))
	var a0: float
	var a1: float
	var rect: Rect2
	match axis:
		"x":
			a0 = l.x; a1 = h.x
			rect = Rect2(l.z, l.y, h.z - l.z, h.y - l.y)
		"y":
			a0 = l.y; a1 = h.y
			rect = Rect2(l.x, l.z, h.x - l.x, h.z - l.z)
		_:
			a0 = l.z; a1 = h.z
			rect = Rect2(l.x, l.y, h.x - l.x, h.y - l.y)
	extrude(round_rect(rect, minf(r, minf(rect.size.x, rect.size.y) * 0.5), seg), axis, a0, a1, col)


## A 2D outline (points in the plane across `axis`) pushed out along it
## from a0 to a1, capped at both ends. Planes: "x" uses (z, y), "y" uses
## (x, z), "z" uses (x, y). Concave outlines are fine.
func extrude(outline: PackedVector2Array, axis: String, a0: float, a1: float, col: Color, caps := true) -> void:
	var n := outline.size()
	if n < 3:
		return
	var ccw := _signed_area(outline) > 0.0
	for i in n:
		var p: Vector2 = outline[i]
		var q: Vector2 = outline[(i + 1) % n]
		var e := q - p
		if e.length_squared() < 1e-12:
			continue
		var out2 := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		quad(_lift(p, axis, a0), _lift(q, axis, a0), _lift(q, axis, a1), _lift(p, axis, a1), col, _lift_dir(out2, axis))
	if not caps:
		return
	var tris := Geometry2D.triangulate_polygon(outline)
	var along := _axis_vec(axis)
	for k in range(0, tris.size(), 3):
		var t := [outline[tris[k]], outline[tris[k + 1]], outline[tris[k + 2]]]
		poly([_lift(t[0], axis, a1), _lift(t[1], axis, a1), _lift(t[2], axis, a1)], col, along if a1 >= a0 else -along)
		poly([_lift(t[0], axis, a0), _lift(t[1], axis, a0), _lift(t[2], axis, a0)], col, -along if a1 >= a0 else along)


## A surface of revolution round the y axis: `profile` is (radius, y) from
## bottom to top. Closes the bottom (and the top if `cap_top`) where the
## radius isn't zero. `seg` sides (times DETAIL), smooth-shaded.
func lathe(profile: Array, seg: int, col: Color, cap_top := true, cap_bottom := true, phase := 0.0) -> void:
	seg = sides(seg)
	# Each profile segment's outward normal in (radius, y), and at each point
	# the one to shade with: shared where the profile bends gently, so it
	# reads as one curve, kept apart at a sharp turn (a lip, a rim).
	var m := profile.size() - 1
	var seg_n: Array[Vector2] = []
	for i in m:
		var p: Vector2 = profile[i]
		var q: Vector2 = profile[i + 1]
		seg_n.append(Vector2(q.y - p.y, -(q.x - p.x)).normalized())
	var at_start: Array[Vector2] = []
	var at_end: Array[Vector2] = []
	for i in m:
		var n0: Vector2 = seg_n[i]
		var n1: Vector2 = seg_n[i]
		if i > 0 and seg_n[i - 1].dot(seg_n[i]) > 0.75:
			n0 = (seg_n[i - 1] + seg_n[i]).normalized()
		if i < m - 1 and seg_n[i + 1].dot(seg_n[i]) > 0.75:
			n1 = (seg_n[i + 1] + seg_n[i]).normalized()
		at_start.append(n0)
		at_end.append(n1)
	for s in seg:
		var a0 := TAU * s / seg + phase
		var a1 := TAU * (s + 1) / seg + phase
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var mid := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		for i in m:
			var p: Vector2 = profile[i]
			var q: Vector2 = profile[i + 1]
			var np: Vector2 = at_start[i]
			var nq: Vector2 = at_end[i]
			var pts: Array = []
			var nrms: Array = []
			if p.x > 0.0001:
				pts.append(d0 * p.x + Vector3.UP * p.y)
				nrms.append(d0 * np.x + Vector3.UP * np.y)
				pts.append(d1 * p.x + Vector3.UP * p.y)
				nrms.append(d1 * np.x + Vector3.UP * np.y)
			else:
				pts.append(Vector3.UP * p.y)
				nrms.append(mid * np.x + Vector3.UP * np.y)
			if q.x > 0.0001:
				pts.append(d1 * q.x + Vector3.UP * q.y)
				nrms.append(d1 * nq.x + Vector3.UP * nq.y)
				pts.append(d0 * q.x + Vector3.UP * q.y)
				nrms.append(d0 * nq.x + Vector3.UP * nq.y)
			else:
				pts.append(Vector3.UP * q.y)
				nrms.append(mid * nq.x + Vector3.UP * nq.y)
			# Outward: away from the axis, tilted by the slope of the profile.
			var sn: Vector2 = seg_n[i]
			_poly_n(pts, nrms, col, mid * sn.x + Vector3.UP * sn.y)
	var first: Vector2 = profile[0]
	var last: Vector2 = profile[profile.size() - 1]
	if cap_bottom and first.x > 0.0001:
		poly(_ring(first.x, first.y, seg, phase), col, Vector3.DOWN)
	if cap_top and last.x > 0.0001:
		poly(_ring(last.x, last.y, seg, phase), col, Vector3.UP)


## Upright cylinder (or cone frustum) standing on `base`.
func cyl(base: Vector3, r_bottom: float, r_top: float, h: float, col: Color, seg := 8, phase := 0.0) -> void:
	push(Transform3D(Basis.IDENTITY, base))
	lathe([Vector2(r_bottom, 0.0), Vector2(r_top, h)], seg, col, true, true, phase)
	pop()


## Cylinder between two points (rods, pipes, handles, poles).
func rod(a: Vector3, b: Vector3, r: float, col: Color, seg := 6, r_b := -1.0) -> void:
	var d := b - a
	var len := d.length()
	if len < 1e-5:
		return
	push(Transform3D(_basis_up(d / len), a))
	lathe([Vector2(r, 0.0), Vector2(r if r_b < 0.0 else r_b, len)], seg, col)
	pop()


## Low-poly ellipsoid.
func ball(center: Vector3, radii: Vector3, col: Color, seg := 8, rings := 4) -> void:
	rings = sides(rings)
	var prof: Array = []
	for i in rings + 1:
		var a := -PI * 0.5 + PI * i / rings
		prof.append(Vector2(cos(a), sin(a)))
	push(Transform3D(Basis.from_scale(radii), center))
	lathe(prof, seg, col)
	pop()


## Sweeps a 2D cross-section along a path of points (tube frames, bumpers
## wrapping round corners, cables). The section's x runs sideways, y along
## `up` (projected off the path direction). Capped at both ends.
func sweep(section: PackedVector2Array, path: Array, col: Color, up := Vector3.UP, caps := true) -> void:
	var n := path.size()
	if n < 2:
		return
	var rings: Array = []
	for i in n:
		var t: Vector3
		if i == 0:
			t = (path[1] - path[0]).normalized()
		elif i == n - 1:
			t = (path[n - 1] - path[n - 2]).normalized()
		else:
			t = ((path[i] - path[i - 1]).normalized() + (path[i + 1] - path[i]).normalized()).normalized()
		var u := up - t * up.dot(t)
		if u.length_squared() < 1e-8:
			u = Vector3.RIGHT - t * t.x
		u = u.normalized()
		var s := t.cross(u).normalized()
		# Stretch the joint so the tube keeps its thickness round a bend.
		var k := 1.0
		if i > 0 and i < n - 1:
			var prev: Vector3 = path[i - 1]
			var here: Vector3 = path[i]
			k = 1.0 / maxf((here - prev).normalized().dot(t), 0.35)
		var ring: Array = []
		for p in section:
			ring.append(path[i] + s * p.x * k + u * p.y)
		rings.append(ring)
	var m := section.size()
	for i in n - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0 := _centroid(r0)
		var c1 := _centroid(r1)
		for j in m:
			var a: Vector3 = r0[j]
			var b: Vector3 = r0[(j + 1) % m]
			var c: Vector3 = r1[(j + 1) % m]
			var d: Vector3 = r1[j]
			var mid := (a + b + c + d) * 0.25
			quad(a, b, c, d, col, mid - (c0 + c1) * 0.5)
	if caps:
		var s0: Array = rings[0]
		var s1: Array = rings[n - 1]
		poly(s0, col, path[0] - path[1])
		poly(s1, col, path[n - 1] - path[n - 2])


## A flat decal a hair proud of a surface: a rectangle in the plane of
## `normal` (axis-aligned normals only), centred on `center`.
func decal(center: Vector3, size: Vector2, normal: Vector3, col: Color) -> void:
	var c := center + normal * 0.0015
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var a: Vector3
	var b: Vector3
	if absf(normal.y) > 0.9:
		a = Vector3(hx, 0, 0)
		b = Vector3(0, 0, hy)
	elif absf(normal.x) > 0.9:
		a = Vector3(0, 0, hx)
		b = Vector3(0, hy, 0)
	else:
		a = Vector3(hx, 0, 0)
		b = Vector3(0, hy, 0)
	quad(c - a - b, c + a - b, c + a + b, c - a + b, col, normal)

#endregion


#region Output

## Bakes everything added so far into one mesh (a surface per material) and
## starts afresh.
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for kind: String in _parts:
		var w: Array = _parts[kind]
		if (w[0] as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = w[0]
		arrays[Mesh.ARRAY_NORMAL] = w[1]
		var colors: PackedColorArray = w[2]
		if _linear_colors and not kind.begins_with("glow"):
			for i in colors.size():
				colors[i] = colors[i].srgb_to_linear()
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(kind))
	_parts.clear()
	xf = Transform3D.IDENTITY
	_stack.clear()
	_kind = "solid"
	return mesh


## Bakes into a new MeshInstance3D added under `parent`.
func into(parent: Node3D, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func material(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m: Material
	if kind == "solid":
		var s := StandardMaterial3D.new()
		s.vertex_color_use_as_albedo = true
		s.vertex_color_is_srgb = not _linear_colors
		s.roughness = 0.82
		s.metallic_specular = 0.3
		m = s
	elif kind == "shiny":
		var sh := StandardMaterial3D.new()
		sh.vertex_color_use_as_albedo = true
		sh.vertex_color_is_srgb = not _linear_colors
		sh.roughness = 0.3
		sh.metallic = 0.25
		sh.metallic_specular = 0.9
		m = sh
	elif kind == "glass":
		var g := StandardMaterial3D.new()
		g.vertex_color_use_as_albedo = true
		g.vertex_color_is_srgb = not _linear_colors
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.roughness = 0.08
		g.metallic_specular = 0.9
		g.cull_mode = BaseMaterial3D.CULL_DISABLED
		m = g
	elif kind.begins_with("glow"):
		var sm := ShaderMaterial.new()
		sm.shader = _glow_shader()
		sm.set_shader_parameter("glow", _glow.get(kind, 1.0))
		m = sm
	else:
		push_error("Vox: unknown material '%s'" % kind)
		return material("solid")
	_materials[kind] = m
	return m


## Brightness of a glow group ("glow/lamp", "glow/led3"...): 0 shows the
## plain colour, above 1 blooms.
static func set_glow(kind: String, value: float) -> void:
	_glow[kind] = value
	if _materials.has(kind):
		(_materials[kind] as ShaderMaterial).set_shader_parameter("glow", value)


static func _glow_shader() -> Shader:
	if _materials.has("_glow_shader"):
		return _materials["_glow_shader"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float glow = 1.0;
varying vec3 col;
void vertex() {
	vec3 c = COLOR.rgb;
	col = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
void fragment() {
	ALBEDO = col * mix(0.55, 1.0, clamp(glow, 0.0, 1.0)) * max(glow, 1.0);
}
"""
	_materials["_glow_shader"] = sh
	return sh

#endregion


#region Helpers

## Rounded rectangle outline, counter-clockwise.
static func round_rect(r: Rect2, rad: float, seg := 2) -> PackedVector2Array:
	seg = sides(seg)
	var pts := PackedVector2Array()
	if rad <= 0.0001:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var corners := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var start := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for i in seg + 1:
			var a: float = start[c] + PI * 0.5 * i / seg
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Circle (or ellipse) outline, counter-clockwise.
static func circle(c: Vector2, r: Vector2, seg := 12, phase := 0.0) -> PackedVector2Array:
	seg = sides(seg)
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg + phase
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## How many sides a round thing asked to have `n` gets.
static func sides(n: int) -> int:
	return maxi(n, ceili(n * DETAIL))


func _buf() -> Array:
	if not _parts.has(_kind):
		_parts[_kind] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	return _parts[_kind]


func _ring(r: float, y: float, seg: int, phase: float) -> Array:
	var pts: Array = []
	for s in seg:
		var a := TAU * s / seg + phase
		pts.append(Vector3(cos(a) * r, y, sin(a) * r))
	return pts


static func _lift(p: Vector2, axis: String, a: float) -> Vector3:
	match axis:
		"x":
			return Vector3(a, p.y, p.x)
		"y":
			return Vector3(p.x, a, p.y)
	return Vector3(p.x, p.y, a)


static func _lift_dir(d: Vector2, axis: String) -> Vector3:
	match axis:
		"x":
			return Vector3(0, d.y, d.x)
		"y":
			return Vector3(d.x, 0, d.y)
	return Vector3(d.x, d.y, 0)


static func _axis_vec(axis: String) -> Vector3:
	match axis:
		"x":
			return Vector3.RIGHT
		"y":
			return Vector3.UP
	return Vector3.BACK


static func _signed_area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a: Vector2 = p[i]
		var b: Vector2 = p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


static func _centroid(pts: Array) -> Vector3:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / maxf(pts.size(), 1)


## A basis whose y axis points along `dir`.
static func _basis_up(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

#endregion
