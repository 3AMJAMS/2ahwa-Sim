# later/ — content parked for later phases

The live game holds only what the current phase uses: FIFI's twelve hot and iced drinks, both
kanakas, the rail of spare kanakas and the ladle, the menu board, FIFI's LED strips, Sayed's
chair and radio, the cat, customers, traffic, the FPS meter and Sayed's tutorial. Everything
built ahead of its phase was taken out of the game and parked here, so it can come back in
the phase the roadmap gives it (`roadmap.md`, phases A–G).

- `later/.gdignore` makes Godot skip this whole folder: nothing in it is imported, parsed or
  exported, so the `.gd` files here are not compiled and their `class_name`s don't clash.
- Paths mirror the live tree: `later/scripts/stations/blender3d.gd` lived at
  `scripts/stations/blender3d.gd`; `later/data/*.later.json` and
  `later/localization/ar_EG.later.csv` hold the entries cut from the live files of the same
  name. `later/snippets/*.gd` hold functions and blocks cut out of live scripts, each with a
  header saying where every block sat.
- **Commit `0906979`** is the last commit with everything wired in. When in doubt, compare
  against it, e.g. `git show 0906979:scripts/stations/prep_station.gd`.

## Index

| Parked thing | Lived in | Parked at | Returns in | How to restore |
|---|---|---|---|---|
| Blender: the 3D cream blender, its jar, the tall glass it pours into | `scripts/stations/blender3d.gd` | `later/scripts/stations/blender3d.gd` | E (juice tiers; G's عصارة builds on it) | `git mv` it back to `scripts/stations/`. It needs `PrepRig.BLENDER_AT` back (prep_rig snippet) and extends the live `Station3D`. Re-import (`--import`) so the class cache sees `Blender3D`. |
| Blend gauge: auto-progress, hold for turbo, motor heat and thermal cut-out | `scripts/stations/blend_gauge.gd` | `later/scripts/stations/blend_gauge.gd` | E | `git mv` it back. PrepStation builds its two bars and hold label and routes holds to it (prep_station snippet). |
| Blender wiring in the prep station: `_ensure_blender()`, the blend/motor bars, the cold/hot switch in `load_order()`, the `"blend"` step, tap/turbo gestures, hint ring, sparks at the tall glass | `scripts/stations/prep_station.gd` | `later/snippets/prep_station.blender_and_mango.gd` | E | Paste each block back where its heading says. Every drink with `"station": "blend"` then uses the blender. |
| `Stove3D.show_glass()`: hides the tea glass while the tall glass stands in its spot | `scripts/stations/stove3d.gd` | `later/snippets/stove3d.show_glass.gd` | E | Paste it back after `reset()`; `load_order()` calls it (prep_station snippet). |
| The blender's tutorial (`cold_station`) and the first-blend explanations (`first_blend`, `first_blend_start`) | `scripts/autoload/tutorial.gd` (doc line), `scripts/stations/prep_station.gd` (`_explain_cold()`, `_explain_current()` branches) | `later/snippets/tutorial.cold_station.gd`, `later/snippets/prep_station.blender_and_mango.gd` | E | Re-add the doc line; the steps come back with the prep_station blocks. |
| Blender in FIFI's trunk kit in the street view | `scripts/world/fifi3d.gd` (`_trunk()`) | `later/snippets/fifi3d.trunk_blender_fruit_charm.gd` §1 | E | Paste the block back after the gas ring's كنكة; it bakes into the "Kit" mesh. |
| Blender icon (the old tool card) | `scripts/stations/prep_icons.gd` | `later/snippets/prep_icons.mango_and_blender.gd` | E | Paste `_blender()` back and its `"blender"` branch into `draw_icon()`. |
| `blend_basic` equipment (the blender slot) | `data/equipment.json` | `later/data/equipment.later.json` | E | Append the entry (drop `_note`). `Economy.owns_slot("blend")` then turns true and blend drinks become orderable. |
| `blender` tool entry | `data/prep_items.json` (`tools`) | `later/data/prep_items.later.json` | E | Record only: the live file no longer has a `tools` list (see "Removed as dead code" below). |
| `mango_juice` menu item (blender version: steps `mango`, `blend`, then 3 ice; tier 2; 15 EGP) | `data/menu_items.json` | `later/data/menu_items.later.json` | D (first fruit drinks), E (blended) | Append it (drop `_note`). For Phase D the roadmap makes mango iced, not blended, with fruit from Sayed's ice box, so its `station`/`steps` need rewriting for the stove-side kit (a new "fruit into the glass" step) and `unlock_tier` set to when it's introduced. |
| Mango ingredient: quick-bar slot and name, `SLOT_OF` / `HINT_KEYS` entries, its `_accepts()` / `_do()` / tutorial branches | `scripts/stations/quick_bar.gd`, `scripts/stations/prep_station.gd` | `later/snippets/quick_bar.mango.gd`, `later/snippets/prep_station.blender_and_mango.gd` | D | Put `"mango"` back between cinnamon and ice in `QuickBar.ORDER` and `NAMES`; restore the prep_station entries. The dock only shows it once an orderable drink uses it. In the parked code `_do("mango")` drops fruit into the blender: point it at the glass for Phase D. |
| Mango icon | `scripts/stations/prep_icons.gd` | `later/snippets/prep_icons.mango_and_blender.gd` | D | Paste `_mango()` and `_one_mango()` back, and the `"mango"` branch into `draw_icon()`. The order ticket uses it too (a drink's first ingredient). |
| Mango jar spot on the counter (`PrepRig.JARS["mango"]`; no jar was ever built for it) | `scripts/stations/prep_rig.gd` | `later/snippets/prep_rig.lemon_rack_and_blender.gd` | D | Re-add the `JARS` entry and build a jar or crate there in `_counter()`. |
| Fruit heaped on Sayed's ice box on the pavement | `scripts/world/fifi3d.gd` (`_ice_box()`) | `later/snippets/fifi3d.trunk_blender_fruit_charm.gd` §2 | D | Paste the loop back at the end of `_ice_box()`. The ice box itself stays live. |
| Mango strings: `PREP_MANGO`, `ING_MANGO`, `SHOUT_MANGO_1`–`3`, `PREP_HINT_MANGO` | `localization/ar_EG.csv` | `later/localization/ar_EG.later.csv` | D | Append the rows to `localization/ar_EG.csv` (same `keys,ar_EG` header), then re-import. |
| Blender strings: `PREP_BLEND_HOLD`, `_OVERHEAT`, `_DONE`, `_TURBO`, `_WARM`, `_TOO_HOT`, `UI_HOLD_TO_BLEND`, `TOOL_BLENDER`, `TUT_COLD_GAUGE`, `TUT_COLD_WARN`, `PREP_HINT_BLEND`, `TUT_BLEND` | `localization/ar_EG.csv` | `later/localization/ar_EG.later.csv` | E | Same as above. |
| Espresso machine: `espresso_none` (locked placeholder), `espresso_basic` (1,200 EGP) | `data/equipment.json` | `later/data/equipment.later.json` | D | Append the entries. There is no espresso station or drink yet: Phase D builds one and its tutorial, using the new-station tutorial pattern. |
| Venues 1–5: جيب الوحش (WAHSH, 0.8×), قهوة بلدي (1.0×), قهوة بلدي مزدحمة (1.6×), قهوة تراثية (2.6×), كافيه حديث (6.0×) | `data/venues.json` | `later/data/venues.later.json` | WAHSH: D. Baladi ahwas (2, 3): E. Historic café (4) and modern كافيه (5): G | Append in order after FIFI's entry (the array index is the tier id). Moving tiers is `SaveData.current_venue_tier`; prices already scale by the venue's `price_multiplier`. |
| Lemon squeezer and tea strainer rack on the prep-station rail | `scripts/stations/prep_rig.gd` (`_rack_lemon()`, `SQUEEZER`, the `"lemon"` rack) | `later/snippets/prep_rig.lemon_rack_and_blender.gd` | B (bought in the upgrade shop; unlocks ليمون / ليمون بالنعناع) | Re-add the constant, the `"lemon"` entry in `RACKS`, the match branch and `_rack_lemon()`, built only when the upgrade is owned. Move the kanaka rail's default back from z = 0.16 to 0.3 so the two share the rail. |
| Prayer beads and the hand-of-Fatima charm hanging in FIFI's trunk (street view) | `scripts/world/fifi3d.gd` (`_trunk()`) | `later/snippets/fifi3d.trunk_blender_fruit_charm.gd` §3 | B (decorations come back as purchases) | Paste back at the end of `_trunk()`, gated on owning the decoration. |

Kept live because later phases reuse them, with only FIFI's data in them: the venue tier field
(`SaveData.current_venue_tier`) and `price_multiplier`, `unlock_tier` gating
(`GameData.pick_order()`, the menu board, the quick bar), equipment slots
(`Economy.owns_slot()`, `owns()`, `purchase_upgrade()`), `Station3D` (the stove's base class,
which the blender extends too) and the tutorial system.

## Old saves

Saves made before the parking can name things this build doesn't have. Loading them is safe:

- `Economy._fit_to_content()` pulls `current_venue_tier` into the venues that exist (it can't
  stay at 2 without a venue 2, or prices would lose FIFI's 0.6× multiplier).
- Unknown upgrade ids (`espresso_none`, `espresso_basic`, `blend_basic`) and drink ids
  (`mango_juice`) stay in the save untouched but count for nothing: `Economy.owns()` and the
  `owned_upgrades` / `unlocked_menu_items` getters ignore ids `GameData` doesn't know. When the
  content returns, they count again.
- Rack spots (`settings["rack_spots"]`): `PrepRig` only places the racks it has, falls back
  to the default for malformed entries, and `save_racks()` keeps the spots of racks it
  doesn't know, so a player's `"lemon"` spot survives until the squeezer returns.
- Tutorial ids for parked tutorials (`cold_station`, `first_blend`, `first_blend_start`) are
  only looked up by id and do nothing.

## Removed as dead code (not parked)

These fed the 2D-era card picker (pick ingredients from a tray, then a tool), which the quick
bar and gestures replaced in commit `0c586ea`; nothing has used them since. They're in git
(see `0906979`) rather than here, since no phase brings that picker back:

- `GameData.menu_ingredients()`, `tool_for_station()`, `owned_tools()`, `prep_item_name()`
  and the `ingredients` / `tools` lists they read (the matching lists in
  `data/prep_items.json`, which now holds only the sugar grades). The quick bar's slots,
  order and names live in `QuickBar.ORDER` / `QuickBar.NAMES` and `PrepStation.SLOT_OF`.
- The `"stove"`, `"spoon"` and `"done"` card icons in `PrepIcons`.
- Strings only those used: `ING_SUGAR`, `TOOL_STOVE`, and `RESULT_TIPS`.
