# PARKED — not compiled (later/ has a .gdignore). Cut from scripts/world/fifi3d.gd (as of
# commit 0906979): bits of FIFI's street-view model (the far, low-detail version; the prep
# view's close-up kit is PrepRig/Stove3D) that belong to later phases.
#
#   1. The blender in the trunk kit → Phase E (blender + juice tiers).
#   2. The fruit heaped on Sayed's ice box on the pavement → Phase D (the first fruit drinks
#      use "fruit from Sayed's ice box"). The ice box itself stays.
#   3. The string of prayer beads and the hand-of-Fatima charm hanging off the trunk's roof
#      → Phase B (decorations come back as upgrade-shop purchases).
#
# To restore: paste each block back where it says, in car-local space (FIFI faces -x, the
# trunk is at +x, her left side +z). They are baked into the "Kit" / "Body" meshes with the
# rest, so they cost no extra draw calls; gate 3 (and later 2) on Economy.owns(...).

# --- Header doc comment (old wording) -----------------------------------------------------------
## with her hatch up so the day's kit shows in the trunk (gas ring and
## كنكة, jars on a wooden rack, the blender, a water jerrycan), LED strips
## round the opening and up the raised hatch, two work bulbs, and the fruit
## ice box down on the pavement.

# --- 1. _trunk(): after the gas cylinder's كنكة handle (v.rod(...Color("5a3620"))) ----------------
## Looking in over the sill: carpet, seat back, trim walls, headliner, the
## wooden rack of jars, the gas ring with the كنكة, the blender, a jerrycan.
	# Blender at the back, squat base, jar and lid.
	var b := Vector3(1.05, FLOOR_Y + 0.03, -0.45)
	v.box(b + Vector3(-0.1, 0, -0.09), b + Vector3(0.1, 0.13, 0.09), Color("e8e0cc"))
	v.box(b + Vector3(0.1, 0.03, -0.05), b + Vector3(0.105, 0.09, 0.05), Color("2b2a30"))
	v.use("glass")
	v.cyl(b + Vector3(0, 0.13, 0), 0.07, 0.09, 0.26, Color(0.8, 0.92, 1.0, 0.35), 8)
	v.use("solid")
	v.cyl(b + Vector3(0, 0.14, 0), 0.068, 0.075, 0.09, Color("a3183a"), 8)
	v.cyl(b + Vector3(0, 0.39, 0), 0.095, 0.095, 0.035, Color("2f2d34"), 8)

# --- 3. _trunk(): the last lines, after the two work bulbs -----------------------------------------
	# A string of prayer beads and a hand of Fatima charm off the roof.
	for k in 8:
		v.cube(Vector3(1.05, 1.24 - k * 0.025, 0.05), Vector3(0.02, 0.02, 0.02), Color("2e5a3a") if k % 3 else Color("c9a24a"))
	v.box(Vector3(1.04, 1.02, 0.02), Vector3(1.06, 1.06, 0.08), Color("2a6ab0"))

# --- 2. _ice_box(): the last lines, after the handles ------------------------------------------------
## Sayed's ice box of fruit, down on the pavement beside the trunk.
	for f in [[Vector3(-0.1, 0.42, -0.05), 0.06, Color("f2a324")], [Vector3(0.05, 0.42, 0.06), 0.055, Color("e8c33a")],
			[Vector3(0.14, 0.41, -0.08), 0.045, Color("f4e04d")], [Vector3(-0.02, 0.41, -0.1), 0.045, Color("f4e04d")]]:
		v.ball(at + (f[0] as Vector3), Vector3.ONE * float(f[1]), f[2], 6, 3)
