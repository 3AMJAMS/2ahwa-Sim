# PARKED — not compiled (later/ has a .gdignore). Cut from scripts/stations/quick_bar.gd
# (as of commit 0906979). Returns in Phase D (first fruit drinks).
#
# The mango slot sat between cinnamon and ice in the dock's fixed order:
const ORDER := ["sugar", "tea", "teabag", "coffee", "karkade", "mint", "milk", "anise", "cinnamon", "mango", "ice"]
# and its name in NAMES:
#	"mango": "ING_MANGO",
# The dock only shows slots some orderable drink uses (PrepStation._slots(), via SLOT_OF), so
# adding it back here does nothing until a mango drink is on the menu. Its icon is in
# later/snippets/prep_icons.mango_and_blender.gd.
