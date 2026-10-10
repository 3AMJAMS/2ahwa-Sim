# Technical Blueprint — 2ahwa Sim (Qahwagi)

Companion to `roadmap.md` (the production bible). This doc is the implementation
handoff for Godot / Claude Code: folder structure, data schemas, and state machines.
It does not repeat scope or narrative decisions — see the roadmap for those.

The roadmap runs in lettered phases: **A** lock the frame and the look (current) → **B** the FIFI
week, worth replaying → **C** ship the FIFI slice → **D** WAHSH and shisha → **E** fixed venues and
staff → **F** authenticity, English, launch → **G** live ops. Older notes used numbered phases; they
map as: old 1 → done / A; old 2 (station loop) → done / B (telemetry now PostHog, in B); old 3
(personas, economy, store upgrades, tier gate, new-station tutorials) → B (upgrade shop) and D
(personas, WAHSH gate, shisha, new-station tutorials); old 4 (modes, authenticity, voice, music) →
E (Rush Hour) and F; old 5 (platform, itch.io page) → C (page) and F (paid launch); old 6 (English,
live ops, venues, mobile) → F and G.

---

## 1. Godot Project Folder Structure

The game is blocky 3D built in code (`scripts/vox/`), not sprites, so there are no art folders:
scenes are thin and scripts build their meshes. As built:

```
2ahwa-Sim/
├── project.godot                 # autoloads, 1080×1920 portrait, Mobile renderer, ar_EG locale
├── assets/
│   ├── fonts/                    # Cairo (OFL), Arabic + Latin subsets
│   └── ui/main_theme.tres
├── data/                         # content for the current phase only — see §2
│   ├── menu_items.json           # FIFI's 12 drinks: recipe steps, sugar grades, colours
│   ├── equipment.json            # station slots / purchasable equipment (heat_basic)
│   ├── venues.json               # venue tiers (FIFI only): price multiplier, seating
│   └── prep_items.json           # sugar grades
├── localization/
│   └── ar_EG.csv                 # every UI string as a key, even though Arabic is the base
│                                 # language — the English pass (Phase F) adds a column
├── scenes/
│   ├── main.tscn                 # fades, HUD, WorldEnvironment, vignette
│   ├── stations/prep_station.tscn
│   └── world/world_host.tscn
├── scripts/
│   ├── main.gd                   # street ↔ prep state machine, serving, tips, day end
│   ├── autoload/                 # GameData, SaveSystem, Economy, DayClock, Tutorial
│   ├── save/save_data.gd         # SaveData resource — see §4
│   ├── stations/                 # the prep view: PrepStation (recipe step engine, gestures),
│   │                             # PrepRig (FIFI's tail up close, racks, camera), Station3D
│   │                             # (appliance base), Stove3D, HeatGauge, QuickBar, PrepIcons
│   ├── ui/                       # ticket rail, tutorial overlay, dawn receipt, FPS meter
│   ├── vox/                      # Vox (block-mesh builder), VoxPerson (people generator)
│   └── world/                    # street, FIFI, traffic, customers, Sayed, the cat, daylight
├── shaders/                      # vignette, tutorial spotlight dim
└── later/                        # parked for later phases (.gdignore: never imported,
    ├── README.md                 #   parsed or exported). README.md is the index: what,
    ├── data/*.later.json         #   where it lived, which phase, how to restore.
    ├── localization/ar_EG.later.csv
    ├── scripts/stations/         # blender3d.gd, blend_gauge.gd (Phase E)
    └── snippets/*.gd             # blocks cut out of live scripts, each labelled
```

**Notes:**
- **Only the current phase is live.** Anything built ahead of its phase is parked in `later/` with a
  row in `later/README.md`, and comes back in its phase. Commit `0906979` is the last one with
  everything wired in.
- **Where later phases plug in.** A new station (shisha corner, espresso machine in D; the blender
  again in E) is a `Station3D` subclass in `scripts/stations/` with its own gauge node, driven by
  `PrepStation`'s step engine through new step ids. New vehicles and venues (WAHSH in D, the
  ahwas in E) are builders in `scripts/world/` plus a `venues.json` entry. Audio (B) goes in
  `assets/audio/` (`sfx/`, `ambience/`, later `barks/` for F's voiced barks).
- The day bookends (B) are short code-driven sequences, not a separate time-lapse scene, and pick
  their variant from what `Economy` says is owned.

---

## 2. Data Schemas

Game content is flat JSON loaded by the `GameData` autoload, so menu, prices and recipes can be
tuned without touching scripts. Each list's entries are looked up by `id`.

### `data/menu_items.json` (live)
```json
{
  "menu_items": [
    {
      "id": "tea_koshari",
      "name_key": "PREP_TEA_KOSHARI",
      "name_ar": "شاي كشري",
      "station": "heat",
      "ingredients": ["tea"],
      "shout_keys": ["SHOUT_TEA_1", "SHOUT_TEA_2", "SHOUT_TEA_3"],
      "unlock_tier": 0,
      "base_price_egp": 8,
      "prep_time_sec": 12,
      "difficulty": 1,
      "look": { "liquid": "#9c3d16", "foam": "#dcb88a", "vessel": "glass", "pot": "water" },
      "sugar": { "sada": 0, "mazboot": 2, "ziyada": 3 },
      "steps": ["sugar", "tea_leaves", "boil", "pour", "stir"]
    },
    {
      "id": "coffee_turkish",
      "station": "heat",
      "look": { "liquid": "#3a2014", "foam": "#a0724a", "vessel": "cup", "kanaka": "brass" },
      "sugar": { "sada": 0, "riha": 1, "mazboot": 2, "mano": 3, "ziyada": 4 },
      "sugar_unit": "half",
      "steps": [["coffee", "sugar_pot"], "boil", "pour"]
    },
    {
      "id": "karkade_cold",
      "station": "heat",
      "finish": { "ice": 3 },
      "steps": ["karkade", "boil", "pour"]
    }
  ]
}
```
(The last two are abridged; every entry carries the full set of fields.)

- `station` — the equipment slot the drink needs (`heat` today). A drink is orderable when
  `unlock_tier <= current_venue_tier` and `Economy.owns_slot(station)`.
- `steps` — the recipe, done in order; a nested array is a group done in either order. Step ids:
  `sugar` (spoons into the glass), `sugar_pot` (into the kanaka), `tea_leaves`, `tea_pot`, `teabag`
  (in, then dunk), `coffee`, `karkade`, `mint`, `milk_pot`, `anise`, `cinnamon`, `boil` / `brew` (the
  heat gauge), `pour` (part of boil; implicit), `pour_gentle` (held pour), `stir`. `finish.ice` adds
  that many ice cubes as the last step.
- `sugar` — the grades it can be ordered with and the taps each takes (`sugar_unit: "half"` makes
  a tap half a spoon). Grades are defined in `prep_items.json`.
- `look` — colours and kit: `vessel` (`glass` / `cup`), `pot` (`water` / `milk`: the tea is built in
  the glass), `kanaka` (`brass` for coffee), `sugar_layer`.
- `ingredients` — the first one is the order ticket's icon.
- `base_price_egp` — what the drink costs at a venue with multiplier 1.0; the venue's
  `price_multiplier` is applied at runtime (`GameData.price_for()`), never a price per tier.

Parked: `mango_juice` (station `blend`, steps `mango`, `blend`) in `later/data/menu_items.later.json`
— Phase D brings mango back iced, not blended; Phase E brings the blender.

### `data/equipment.json` (live)
```json
{
  "equipment": [
    { "id": "heat_basic", "slot": "heat", "tier": 0, "name_ar": "موقد بسيط", "cost_egp": 0, "unlocked": true }
  ]
}
```
Optional fields: `requires` (id of the item it upgrades), `hint_ar` (shown while locked).
`Economy.purchase_upgrade(id)` buys one (cost from tips, saved at once); `Economy.owns(id)` is true
when bought or `unlocked`; `owns_slot(slot)` gates drinks by `station`. Parked:
`espresso_none` / `espresso_basic` (1,200 EGP, Phase D) and `blend_basic` (Phase E).

### `data/venues.json` (live)
```json
{
  "venues": [
    { "id": 0, "name_ar": "عربية فيفي", "vehicle_id": "fifi", "price_multiplier": 0.6, "seating": false }
  ]
}
```
The array index is the tier id (`SaveData.current_venue_tier`). Parked in
`later/data/venues.later.json`, in order: WAHSH (1, 0.8×, Phase D), قهوة بلدي (2, 1.0×) and
قهوة بلدي مزدحمة (3, 1.6×) in Phase E, قهوة تراثية (4, 2.6×) and كافيه حديث (5, 6.0×) in Phase G.
Multipliers come from the Masrawy pricing survey (12.5 → 32.5 → ~80 EGP average bands); tune them
when the WAHSH unlock (D) and the ahwas (E) are playtested.

### `data/prep_items.json` (live)
```json
{
  "sugar_grades": [
    { "id": "sada", "name_key": "SUGAR_SADA" },
    { "id": "riha", "name_key": "SUGAR_RIHA" },
    { "id": "mazboot", "name_key": "SUGAR_MAZBOOT" },
    { "id": "mano", "name_key": "SUGAR_MANO" },
    { "id": "ziyada", "name_key": "SUGAR_ZIYADA" }
  ]
}
```
From least to most sweet. (The 2D-era `ingredients` / `tools` catalogs are gone: the quick bar's
slots, order and names live in `QuickBar` and `PrepStation.SLOT_OF`.)

### Planned: the upgrade shop (Phase B)
The Phase B shop on the dawn receipt sells kit and decorations: lemon squeezer + strainer (unlocks
ليمون / ليمون بالنعناع), a bigger or double كنكة, two monobloc chairs round a stool table, and the
decorations (stickers incl. صلّي على النبي, hand of Fatima / blue-eye charm, tassel fringe, fairy
lights, LED strips in the trunk, a shelf of glasses, floor storage). Kit that gates drinks fits
`equipment.json` as it is (a slot per kit); decorations and seating need a little more (ids,
prices and effects below are placeholders, not decisions):
```json
{
  "id": "lemon_squeezer",
  "slot": "lemon",
  "category": "kit",
  "cost_egp": 150,
  "unlocks_menu": ["lemon", "lemon_mint"],
  "rack": "lemon"
}
```
```json
{ "id": "charm_fatima", "category": "decor", "cost_egp": 60, "effect": "patience_bonus_small" }
```
Either extend `equipment.json` with `category` / `effect` or split decorations into
`upgrades.json`; decide when B starts. The squeezer's rack model is parked in
`later/snippets/prep_rig.lemon_rack_and_blender.gd`. A daily goal and the day-7 milestone (saving
toward WAHSH) read the same purchase state.

### Planned: `data/customer_archetypes.json` (Phase D personas; regulars in B)
```json
{
  "archetypes": [
    { "id": "elderly_regular", "name_ar": "العم", "patience_sec": 90, "tip_multiplier": 0.8, "usual_item": "tea_koshari" },
    { "id": "taxi_driver", "name_ar": "سواق تاكسي", "patience_sec": 35, "tip_multiplier": 1.1, "usual_item": "tea_koshari" },
    { "id": "football_fan", "name_ar": "مشجع", "patience_sec": 50, "tip_multiplier": 1.0, "usual_item": null }
  ]
}
```
Phase B's 3–4 named regulars ("the usual") can start as a short list in this shape; D grows it into
full personas. `CustomerQueue` currently rolls patience from one range (`patience_range`).

### Planned: `data/shisha_items.json` (Phase D)
```json
{
  "shisha_items": [
    {
      "id": "shisha_qass",
      "name_ar": "شيشة قص",
      "flavored": false,
      "unlock_tier": 1,
      "session_price_egp": [15, 70],
      "hajar_price_egp": [5, 30],
      "lawlaat_before_hajar_change": 1
    },
    {
      "id": "shisha_tuffah",
      "name_ar": "شيشة تفاح",
      "flavored": true,
      "unlock_tier": 2,
      "session_price_egp": [50, 250],
      "hajar_price_egp": [20, 60],
      "lawlaat_before_hajar_change": 6
    }
  ]
}
```
`lawlaat_before_hajar_change: 1` means the unflavored حجر is effectively replaced every session (matches the "roughly every session" figure). For flavored, track a live `lawlaat_count` on the active shisha session; when it hits the item's threshold, fire a `hajar_refill_needed` signal the player (or an auto-managed تومباكشي, post-hire in Phase E) resolves mid-shift.

---

## 3. State Machines

### Customer patience state machine
```
ARRIVING → WAITING_TO_ORDER → ORDER_PLACED → WAITING_FOR_DRINK → SERVED (success)
                                      │
                                      └─(patience hits 0)→ LEFT_ANGRY (failure, reputation hit)
```
Tip on `SERVED`, as built (`main.gd`): `base_price × venue.price_multiplier × quality × speed`, where
quality is brew accuracy × sugar × pour, less 20% per mistake (floor 50%), and speed runs from
0.6 (about to walk off) to 1.0 (served at once). Phase D multiplies in `archetype.tip_multiplier`.

### Day cycle state machine
```
DAY_START (4 pm)
  → SETUP_BOOKEND (Phase B: 1–2 s, tap to skip; variant from owned upgrades)
  → OPEN_FOR_BUSINESS (order → prepare → serve, looping; + shisha from Phase D)
  → CLOSING_TRIGGER (4 am, or the player taps روّح; an order being made is handed over first)
  → TEARDOWN_BOOKEND (Phase B, reverse of setup)
  → DAY_SUMMARY (the dawn receipt: served, lost, takings; Phase B adds the shop and the daily goal)
  → DAY_START (next day)
```
Built today: DAY_START, OPEN_FOR_BUSINESS, CLOSING_TRIGGER and DAY_SUMMARY (`DayClock`,
`main.gd`, `DaySummary`). The bookends support `skip_requested` (tap-to-skip) and the persisted
`auto_skip_after_day` setting.

### Shisha session sub-state (Phase D)
```
SHISHA_IDLE → COAL_LIT → SMOKING (lawlaat_count++ per rotation cycle)
                              │
                              ├─(lawlaat_count < threshold)→ SMOKING (loop)
                              └─(lawlaat_count == threshold)→ HAJAR_REFILL_PROMPT → SMOKING (after purchase) or SHISHA_IDLE (declined)
```

---

## 4. Save System
A versioned Godot `Resource` (not raw JSON), so `ResourceSaver`/`ResourceLoader` handle
serialization; a JSON export (`SaveSystem.export_json()` / `import_json()`) is kept for debugging.
Saved to `user://save.tres` at day end, after a purchase, and when the app is paused or closed.

```gdscript
# scripts/save/save_data.gd
class_name SaveData
extends Resource

const CURRENT_VERSION := 1

@export var save_version: int = CURRENT_VERSION
@export var day_number: int = 1
@export var currency_egp: int = 0
@export var current_venue_tier: int = 0
@export var current_vehicle_id: String = "fifi"
@export var owned_upgrades: Array[String] = []
@export var unlocked_menu_items: Array[String] = ["tea_koshari"]
@export var seasonal_event_state: Dictionary = {}
@export var tutorials_seen: Dictionary = {}
@export var settings: Dictionary = {"skip_cutscenes": false, "auto_skip_after_day": 3}
# settings also holds "rack_spots" (PrepRig's movable racks) and "show_fps".
```
`save_version` exists from day one so a schema change can migrate old saves instead of breaking
them: bump `CURRENT_VERSION` and add a step to `SaveSystem.migrate_old_save()`, never editing an
old step.

Content changes need no migration. A save can name content the build doesn't have (parked for a
later phase, or from a newer build): `Economy._fit_to_content()` pulls `current_venue_tier` into the
venues that exist; unknown upgrade and drink ids stay in the save but count for nothing
(`Economy.owns()`, the `owned_upgrades` / `unlocked_menu_items` getters); `PrepRig` ignores rack spots
for racks it doesn't have and keeps them when it saves.

---

## 5. Telemetry and crash reporting — PostHog + Sentry (Phase B)
**PostHog over HTTP** replaces the earlier GameAnalytics plan: no SDK to embed, works the same on
Web, Android and desktop builds (an `HTTPRequest` posting to PostHog's capture endpoint, batched
and sent at day end and on pause), with funnels and retention out of the box. **Sentry**
(`sentry-godot`) reports crashes and script errors. Both land in Phase B; Phase C's exit needs
telemetry flowing from the public build.

Minimum event set (PostHog `event` + `properties`, with an anonymous `distinct_id` kept in the save):

```json
{ "event": "session_start", "properties": { "day_number": 1, "platform": "web" } }
{ "event": "day_complete", "properties": { "day_number": 1, "tips_earned": 340, "orders_served": 12, "orders_failed": 1 } }
{ "event": "order_served", "properties": { "item_id": "tea_koshari", "station": "heat", "time_taken_sec": 11.2, "mistakes": 0 } }
{ "event": "order_failed", "properties": { "item_id": "coffee_turkish", "reason": "patience_expired" } }
{ "event": "upgrade_purchased", "properties": { "upgrade_id": "lemon_squeezer", "cost_egp": 150 } }
{ "event": "tutorial_step", "properties": { "id": "first_sugar", "skipped": false } }
{ "event": "cutscene_skipped", "properties": { "type": "setup_bookend" } }
```
Phase B's exit reads the funnel of players finishing day 3. `Economy` already counts each day's
served and failed orders for the receipt; those feed `day_complete`. A privacy policy is required
before any public release (itch.io included, Phase C) once telemetry is on.

---

## 6. Fonts (Arabic RTL — validate on devices in Phase A, don't assume)
Godot 4's **Advanced** text server (ICU/HarfBuzz-backed) is required for correct Arabic shaping/RTL — confirm it's active in Project Settings → Internationalization (official builds ship it by default, but verify rather than assume).

In use:
- **Cairo** (Google Fonts, OFL) — modern geometric sans, Arabic + Latin subsets, for the HUD and UI.

Candidates still open:
- **Amiri** or **Markazi Text** — more traditional Naskh-style, for the chalk menu board / the FIFI-WAHSH wordmark.

Phase A's RTL and aspect-ratio device checks cover the tickets, the receipt and the menu board.

---

## 7. Project Settings — Aspect Ratio / Stretch Mode
```ini
[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/size/viewport_width=1080
window/size/viewport_height=1920
window/handheld/orientation=1   ; portrait

[rendering]
renderer/rendering_method="mobile"
scaling_3d/scale=0.75           ; the 3D renders at 75%, the 2D UI stays sharp
```
HUD anchors are designed against the 1080×1920 safe rect; wider or shorter screens show more of
the street rather than stretching the UI, and the prep camera holds FIFI's width on tall screens
and the design height on wide ones (`PrepRig._fit_camera()`). Device checks across aspect ratios
are part of Phase A.

---

## 8. Tutorial System State Machine
```
FIRST_LAUNCH → ui_intro (street: day/clock/wallet, going home, the first customer, the trunk)
                     │
            (first order) → first_quickbar (the order, the quick bar)
            (each new kind of step) → first_sugar / first_leaves / first_pot / first_milk /
                                      first_mint / first_light / first_teabag / first_stir /
                                      first_gentle / first_ice
            (first time on the stove) → hot_station
            (first drink in hand) → first_serve; (first tips) → first_tips
            (first tap on a newly bought station, Phase D on) → <station>_station
```
Backing data: `tutorials_seen: Dictionary` in `SaveData` (e.g. `{"ui_intro": true, "hot_station": true, ...}`,
plus `"skipped"` when the player turns them off). The `Tutorial` autoload plays a list of steps
(text, a spotlight target, optionally a signal to wait for) once and flips the flag; scenes build
the steps because they know where things are. The blender's `cold_station` tutorial is parked with
the blender (Phase E, `later/`); the shisha corner and the other new stations add theirs the same way
in Phase D (new-station tutorial triggers).

---

## 9. Save System — Local Only (Confirmed)
No cloud-save/cross-device sync for v1 — confirmed decision, not a gap. Note for the whole team (even if that's just you): **the GitHub repo version-controls source code; it is not a player save-game backup system.** Player progress lives in the local `SaveData` resource on-device only (see §4 above in this doc for the schema). If cross-device save sync becomes a priority later, that's a distinct feature to design separately, not something the repo already provides.

---

## 10. Open Items
- [x] SUV-tier vehicle name — **WAHSH** (locked)
- [x] Telemetry approach — **PostHog over HTTP + Sentry** (Phase B; replaces the GameAnalytics plan)
- [ ] Validate Godot's ICU text server + Cairo against real RTL screens on devices (Phase A)
- [ ] Phase B: extend `equipment.json` for the upgrade shop, or split decorations into `upgrades.json` (§2)
- [ ] Confirm shisha real-world pricing bands (supplied, not independently sourced) still feel right after a local sanity-check (Phase D)
- [ ] Decide whether `venues.json` multipliers apply globally or per item (iced specialty drinks only exist at the café tiers) — before WAHSH (Phase D)
