class_name SidewalkFurniture
extends Node3D
## Sayed's spot on the pavement beside FIFI, in blocks: his folding lawn
## chair (aluminium tube frame, green-and-white woven strips, black armrest
## pads), a stool with his transistor radio on it, and Sayed himself, sat
## with a glass of tea. Customer seating (plastic chairs, a table) comes
## later as an upgrade. The chair faces +z; the node sits on the pavement.

const ALU := Color("c9ced6")
const WEB_A := Color("2f8a4c")
const WEB_B := Color("eeeae0")
const PAD := Color("2a2a30")
const SEAT_H := 0.36

var sayed := SayedFigure.new()


func _ready() -> void:
	var v := Vox.new()
	_chair(v)
	_stool(v, Vector3(0.62, 0, -0.1))
	v.into(self, "Chair")
	sayed.position = Vector3(0, SEAT_H + 0.04 - VoxPerson.HIP * VoxPerson.U, -0.08)
	add_child(sayed)


func _chair(v: Vox) -> void:
	var tube := Vox.circle(Vector2.ZERO, Vector2(0.014, 0.014), 6)
	var w := 0.27
	# Seat frame and legs (a folding X under each side).
	for s in [-1.0, 1.0]:
		var x: float = s * w
		v.sweep(tube, [Vector3(x, SEAT_H, 0.24), Vector3(x, SEAT_H, -0.22)], ALU)
		v.sweep(tube, [Vector3(x, 0.0, 0.25), Vector3(x, SEAT_H, -0.2)], ALU)
		v.sweep(tube, [Vector3(x, 0.0, -0.24), Vector3(x, SEAT_H, 0.22)], ALU)
		# Back uprights, reclined, and the armrest with its pad.
		v.sweep(tube, [Vector3(x, SEAT_H, -0.22), Vector3(x, 0.95, -0.42)], ALU)
		v.sweep(tube, [Vector3(x, SEAT_H, 0.2), Vector3(x, 0.58, 0.2), Vector3(x, 0.58, -0.28)], ALU)
		v.box(Vector3(x - 0.03, 0.58, -0.22), Vector3(x + 0.03, 0.61, 0.16), PAD)
	for z in [0.24, -0.22]:
		v.sweep(tube, [Vector3(-w, SEAT_H, z), Vector3(w, SEAT_H, z)], ALU)
	v.sweep(tube, [Vector3(-w, 0.95, -0.42), Vector3(w, 0.95, -0.42)], ALU)
	# Woven strips across the seat and up the back.
	for k in 6:
		var z := lerpf(0.21, -0.19, k / 5.0)
		v.box(Vector3(-w, SEAT_H - 0.008, z - 0.03), Vector3(w, SEAT_H + 0.006, z + 0.03), WEB_A if k % 2 == 0 else WEB_B)
	for k in 7:
		var t := k / 6.0
		var p := Vector3(0, SEAT_H, -0.22).lerp(Vector3(0, 0.95, -0.42), t)
		v.push_at(p, Vector3(-19, 0, 0))
		v.box(Vector3(-w, -0.035, -0.008), Vector3(w, 0.035, 0.006), WEB_A if k % 2 == 0 else WEB_B)
		v.pop()
	for s in [-1.0, 1.0]:
		v.box(Vector3(s * 0.1 - 0.02, SEAT_H - 0.004, -0.2), Vector3(s * 0.1 + 0.02, SEAT_H + 0.008, 0.22), WEB_B if s < 0 else WEB_A)


## A low stool with the radio on it: wooden top, the radio's leather case,
## its dial, grille and aerial.
func _stool(v: Vox, at: Vector3) -> void:
	var wood := Color("8a5a32")
	v.box(at + Vector3(-0.16, 0.34, -0.16), at + Vector3(0.16, 0.38, 0.16), wood)
	for x in [-0.12, 0.12]:
		for z in [-0.12, 0.12]:
			v.box(at + Vector3(x - 0.02, 0, z - 0.02), at + Vector3(x + 0.02, 0.34, z + 0.02), wood.darkened(0.25))
	var r := at + Vector3(0, 0.38, 0)
	v.rbox(r + Vector3(-0.12, 0, -0.05), r + Vector3(0.12, 0.14, 0.05), 0.02, Color("7a2e22"), "z", 1)
	v.box(r + Vector3(-0.1, 0.02, 0.05), r + Vector3(0.02, 0.12, 0.052), Color("c9b890"))
	for k in 4:
		v.box(r + Vector3(-0.095, 0.03 + k * 0.024, 0.052), r + Vector3(0.015, 0.038 + k * 0.024, 0.055), Color("8a7a5a"))
	v.box(r + Vector3(0.04, 0.04, 0.05), r + Vector3(0.1, 0.1, 0.053), Color("e8dcb0"))
	v.cube(r + Vector3(0.07, 0.07, 0.055), Vector3(0.02, 0.02, 0.01), Color("c8322b"))
	v.rod(r + Vector3(0.09, 0.14, 0), r + Vector3(0.2, 0.55, -0.05), 0.004, Color("d4d9e1"), 4)
	# A spare glass and the sugar tin on the stool.
	v.cyl(at + Vector3(-0.08, 0.38, 0.11), 0.03, 0.03, 0.004, Color("ebe6dc"), 8)
