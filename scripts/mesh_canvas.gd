@tool
class_name MeshCanvas
extends RefCounted
## Collects flat-colour 2D shapes (polygons, lines, circles, rects) into one
## vertex-coloured ArrayMesh, so a detailed procedural drawing costs a single
## draw call instead of one per shape. Mirrors the CanvasItem draw_* calls it
## replaces; draw the result with CanvasItem.draw_mesh(mesh, null).

var _verts := PackedVector2Array()
var _cols := PackedColorArray()
var _xf := Transform2D.IDENTITY


func set_transform(pos: Vector2, rot := 0.0, scl := Vector2.ONE) -> void:
	_xf = Transform2D(rot, scl, 0.0, pos)


func colored_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3 or color.a <= 0.0:
		return
	for i in Geometry2D.triangulate_polygon(points):
		_verts.append(_xf * points[i])
		_cols.append(color)


func polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.size() < 3:
		return
	for i in Geometry2D.triangulate_polygon(points):
		_verts.append(_xf * points[i])
		_cols.append(colors[i] if i < colors.size() else colors[0])


func line(a: Vector2, b: Vector2, color: Color, width := 1.0, _antialiased := false) -> void:
	var d := b - a
	if d.length_squared() < 0.0001 or color.a <= 0.0:
		return
	var n := d.normalized().orthogonal() * maxf(width, 1.0) * 0.5
	_quad(a + n, b + n, b - n, a - n, color)


func polyline(points: PackedVector2Array, color: Color, width := 1.0, _antialiased := false) -> void:
	for i in points.size() - 1:
		line(points[i], points[i + 1], color, width)
		# Round off the joints so thick polylines don't crack at the bends.
		if width > 3.0 and i > 0:
			circle(points[i], width * 0.5, color, 8)


func multiline(points: PackedVector2Array, color: Color, width := 1.0) -> void:
	for i in range(0, points.size() - 1, 2):
		line(points[i], points[i + 1], color, width)


func circle(c: Vector2, r: float, color: Color, segments := 16) -> void:
	if r <= 0.0 or color.a <= 0.0:
		return
	var n := clampi(segments if r > 6.0 else 10, 6, 32)
	var prev := c + Vector2(r, 0)
	for i in range(1, n + 1):
		var a := TAU * i / n
		var p := c + Vector2(cos(a), sin(a)) * r
		_tri(c, prev, p, color)
		prev = p


func rect(r: Rect2, color: Color, filled := true, width := 1.0) -> void:
	if filled:
		_quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), color)
	else:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y),
			r.position])
		polyline(pts, color, width)


func is_empty() -> bool:
	return _verts.is_empty()


## Bakes everything added so far into a mesh (null if nothing was drawn).
func commit() -> ArrayMesh:
	if _verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_tri(a, b, c, color)
	_tri(a, c, d, color)


func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_verts.append(_xf * a)
	_verts.append(_xf * b)
	_verts.append(_xf * c)
	_cols.append(color)
	_cols.append(color)
	_cols.append(color)
