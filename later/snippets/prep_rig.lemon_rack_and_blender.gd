# PARKED — not compiled (later/ has a .gdignore). Cut from scripts/stations/prep_rig.gd
# (as of commit 0906979).
#   - The lemon squeezer + tea strainer rack → Phase B (bought in the upgrade shop on the dawn
#     receipt; the squeezer unlocks ليمون / ليمون بالنعناع).
#   - BLENDER_AT → Phase E (where Blender3D stands; later/scripts/stations/blender3d.gd reads it).
#   - The "mango" spot in JARS → Phase D (it only ever held a spot: no jar was built for it).
#
# To restore the rack: put SQUEEZER back with the colour constants, "lemon" back into RACKS
# (its old default spot was Vector2(0.0, -0.14); the kanaka rail ("hooks") sat at z = 0.3
# beside it, and was moved to z = 0.16, nearer the middle of the opening, when the squeezer
# was parked, so put "hooks" back at 0.3 too), the "lemon" branch back into the match in _ready(), and _rack_lemon() back in the
# Racks region (after _kanaka_hanging()). Movable racks keep their spots in
# SaveData.settings["rack_spots"]; PrepRig.save_racks() keeps spots of racks it doesn't know,
# so a player's old "lemon" spot is still in the save when the rack returns. Gate it on owning
# the upgrade (Economy.owns(...)) rather than building it always.

# --- Header doc comment (old wording) -----------------------------------------------------------
## across the sill for the stove, the glass, the blender and the jars, two
## work bulbs, and Sayed's movable racks (the rail of كنكة, the lemon
## squeezer, the chalk menu board). Kept plain on purpose: decorations come
## later. The camera stands behind the car at hatch height looking down in.

# --- Constants ------------------------------------------------------------------------------------
const SQUEEZER := Color("f2c230")

## Where the blender would stand (the juice tiers; FIFI has none).
const BLENDER_AT := Vector3(1.4, COUNTER_Y, -0.58)

# (in JARS)
	"mango": Vector3(1.36, COUNTER_Y, -0.3),

const RACKS := {"hooks": Vector2(0.0, 0.3), "lemon": Vector2(0.0, -0.14), "board": Vector2(0.5, 0.0)}

# --- _ready(): the match that builds each rack -----------------------------------------------------
			"lemon":
				_rack_lemon(v)

# --- The rack itself --------------------------------------------------------------------------------
## The lemon squeezer, as it hangs on its hook: two long yellow handles
## hinged at the bottom round a round perforated cup with the press dome
## nested in it, the cup's mouth toward us. A tea strainer hangs beside it.
func _rack_lemon(v: Vox) -> void:
	_rail(v, -0.13, 0.09)
	# The squeezer.
	var z := -0.07
	_s_hook(v, z)
	var top := Vector3(0.045, -0.05, z)
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.008, 0.008), 6), [top + Vector3(0, 0.0, 0), top + Vector3(0.0, -0.01, 0.01),
		top + Vector3(0, -0.02, 0), top + Vector3(0, -0.01, -0.01), top], Color("8a8e96"), Vector3.RIGHT, false)
	var cup := top + Vector3(0.0, -0.21, 0)
	for side in [-1.0, 1.0]:
		# Flat handles, one in front of the other, opening a touch at the cup.
		var h0 := top + Vector3(side * 0.006, -0.02, 0)
		var h1 := cup + Vector3(side * 0.035, 0.05, side * 0.02)
		v.sweep(Vox.round_rect(Rect2(-0.009, -0.004, 0.018, 0.008), 0.003, 1), [h0, h0.lerp(h1, 0.6) + Vector3(side * 0.006, 0, 0), h1],
			SQUEEZER, Vector3.RIGHT)
		v.cube(h0 + Vector3(0, -0.01, 0), Vector3(0.012, 0.02, 0.022), SQUEEZER.darkened(0.2))
	# The cup: a yellow bowl facing us with holes in its floor.
	v.push_at(cup + Vector3(0.035, 0, 0), Vector3(0, 0, -90))
	v.lathe([Vector2(0.0, -0.02), Vector2(0.035, -0.012), Vector2(0.045, 0.01), Vector2(0.047, 0.02)], 14, SQUEEZER, false)
	v.lathe([Vector2(0.043, 0.02), Vector2(0.041, 0.01), Vector2(0.03, -0.008), Vector2(0.0, -0.014)], 14, SQUEEZER.darkened(0.12),
		false, false)
	v.pop()
	for k in 7:
		var a := TAU * k / 7.0
		v.cube(cup + Vector3(0.023, sin(a) * 0.02, cos(a) * 0.02), Vector3(0.004, 0.006, 0.006), Color("5a4a1a"))
	v.cube(cup + Vector3(0.023, 0, 0), Vector3(0.004, 0.006, 0.006), Color("5a4a1a"))
	# The hinge pin under the cup, and the press dome's edge showing behind.
	v.push_at(cup + Vector3(0.0, -0.055, 0), Vector3(0, 0, 90))
	v.cyl(Vector3(0, -0.02, 0), 0.008, 0.008, 0.04, Color("8a8e96"), 6)
	v.pop()
	v.push_at(cup + Vector3(0.0, 0, 0), Vector3(0, 0, -90))
	v.lathe([Vector2(0.046, -0.002), Vector2(0.04, 0.02), Vector2(0.0, 0.03)], 14, SQUEEZER.lightened(0.08))
	v.pop()
	# Tea strainer on the next hook.
	var sz := 0.03
	_s_hook(v, sz)
	v.rod(Vector3(0.035, -0.045, sz), Vector3(0.035, -0.13, sz), 0.004, METAL, 4)
	v.push_at(Vector3(0.05, -0.16, sz), Vector3(0, 0, -90))
	v.lathe([Vector2(0.032, 0.0), Vector2(0.025, 0.015), Vector2(0.0, 0.02)], 12, Color("4a4850"))
	v.cyl(Vector3(0, -0.003, 0), 0.034, 0.034, 0.005, METAL, 12)
	v.pop()


