# PARKED — not compiled (later/ has a .gdignore). Cut from scripts/stations/stove3d.gd
# (as of commit 0906979), where it sat right after reset(). Returns with the blender
# (Phase E): PrepStation.load_order() called stove.show_glass(not cold) so the blender's
# tall glass could stand in the tea glass's spot. With only hot drinks, Stove3D.set_look()
# already shows the glass or the فنجان, so nothing called it with false any more.

## Hides the tea glass / cup (the blender pours into its own glass).
func show_glass(on: bool) -> void:
	_glass_node.visible = on and not _cup
	_cup_node.visible = on and _cup
