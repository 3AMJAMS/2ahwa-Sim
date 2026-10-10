# PARKED — not compiled (later/ has a .gdignore). The blender's tutorial ("cold_station") and
# the first-mango / first-blend explanations. Returns with the blender in Phase E.
#
# In scripts/autoload/tutorial.gd it was one line of the doc comment listing the tutorials,
# after hot_station:
##   cold_station — first time on the blender: turbo and the motor cut-out.
#
# The steps themselves lived in scripts/stations/prep_station.gd: _explain_cold() (called
# from the "blend" step in _do()) and the "mango" / "blend" branches of _explain_current()
# (tutorial ids "first_blend" and "first_blend_start"). They are in
# later/snippets/prep_station.blender_and_mango.gd. Strings: TUT_COLD_GAUGE, TUT_COLD_WARN,
# TUT_BLEND (later/localization/ar_EG.later.csv); the mango one reuses the live TUT_ADD_POT.
#
# Saves from before the parking may already have "cold_station", "first_blend" or
# "first_blend_start" in SaveData.tutorials_seen; they're harmless (only looked up by id) and
# mean that player won't see those explanations again when the blender returns.
