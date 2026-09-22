# Technical Blueprint — 2ahwa Sim (Qahwagi)

Companion to `roadmap.md` (the production bible). This doc is the implementation
handoff for Godot / Claude Code: folder structure, data schemas, and state machines.
It does not repeat scope or narrative decisions — see the roadmap for those.

---

## 1. Godot Project Folder Structure

```
2ahwa-sim/
├── project.godot
├── addons/
├── assets/
│   ├── sprites/
│   │   ├── sayed/                # player character, both iso + flat rigs
│   │   ├── customers/            # one folder per archetype
│   │   ├── fifi/                 # truck art, per upgrade tier
│   │   ├── wahsh/                 # WAHSH SUV-tier vehicle art, per upgrade tier
│   │   ├── shisha/                # القلب, الحجر, الكالوش/الصينية, الشربوش/الكسوة, الرفاس — per tier skin
│   │   └── ui/
│   ├── fonts/                    # Arabic-supporting fonts (test RTL early)
│   ├── audio/
│   │   ├── sfx/
│   │   └── voice/                 # Egyptian Arabic voice lines, order-calls
│   └── tilesets/                  # isometric 2:1 tileset(s)
├── scenes/
│   ├── main.tscn
│   ├── world/
│   │   ├── isometric_world.tscn   # the truck/café scene, Y-sorted
│   │   ├── day_bookend.tscn       # setup/teardown time-lapse (AnimationPlayer-driven)
│   │   └── customer.tscn
│   ├── stations/
│   │   ├── hot_station.tscn       # flat "Right Mix" view — sand-bath gauge
│   │   └── cold_station.tscn      # flat "Right Mix" view — blender gauge
│   ├── shisha/
│   │   └── shisha_station.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── ticket.tscn
│       └── upgrade_shop.tscn
├── data/                           # see schemas below — JSON or .tres Resources
│   ├── menu_items.json
│   ├── shisha_items.json
│   ├── upgrades.json
│   ├── venue_tiers.json
│   └── customer_archetypes.json
├── scripts/
│   ├── autoload/
│   │   ├── economy.gd              # tips, currency, upgrade state (Autoload singleton)
│   │   ├── day_cycle.gd            # day state machine (see §3)
│   │   └── save_system.gd
│   ├── customer/
│   │   └── customer_state_machine.gd   # see §3
│   └── stations/
│       ├── right_mix_base.gd        # shared gauge logic
│       ├── hot_station.gd
│       └── cold_station.gd
└── localization/
    └── ar_EG.csv                    # even though Arabic is the base language, keep
                                      # strings in a translation table from day one —
                                      # makes the eventual English pass trivial later
```

**Notes:**
- Keep `assets/sprites/fifi/` split by upgrade tier (`tier0_bare/`, `tier1_neon/`, `tier2_roofrack/`) so the day-bookend sequence and the isometric world can both pull the correct variant from one source of truth (`economy.gd`'s current upgrade state).
- Test the Arabic font + RTL layout against `scenes/ui/` mockups in Phase 0/1 — don't wait until content is full.

---

## 2. Data Schemas

Keep game content in flat JSON (or convert to Godot `.tres` Resources once the schema is stable) so designers can edit menu/pricing without touching scripts.

### `data/menu_items.json`
```json
{
  "menu_items": [
    {
      "id": "tea_koshari",
      "name_ar": "شاي كشري",
      "station": "hot",
      "unlock_tier": 0,
      "base_price_egp": 8,
      "prep_time_sec": 12,
      "difficulty": 1,
      "sugar_grade": null
    },
    {
      "id": "coffee_mazbut",
      "name_ar": "قهوة مظبوط",
      "station": "hot",
      "unlock_tier": 0,
      "base_price_egp": 10,
      "prep_time_sec": 15,
      "difficulty": 2,
      "sugar_grade": "مظبوط"
    },
    {
      "id": "karkade_cold",
      "name_ar": "كركديه بارد",
      "station": "cold",
      "unlock_tier": 0,
      "base_price_egp": 12,
      "prep_time_sec": 10,
      "difficulty": 1,
      "seasonal": false
    },
    {
      "id": "qamar_eldin",
      "name_ar": "قمر الدين",
      "station": "cold",
      "unlock_tier": 2,
      "base_price_egp": 15,
      "prep_time_sec": 10,
      "difficulty": 1,
      "seasonal": "ramadan"
    }
  ]
}
```
`base_price_egp` should start at the values in the roadmap's Realistic Pricing Reference table for `unlock_tier`'s venue, then get a per-tier multiplier applied at runtime (see `venue_tiers.json`) rather than hardcoding a price per tier per item.

### `data/venue_tiers.json`
```json
{
  "venue_tiers": [
    { "id": 0, "name_ar": "عربية فيفي", "price_multiplier": 0.6, "seating": false },
    { "id": 1, "name_ar": "جيب", "price_multiplier": 0.8, "seating": false },
    { "id": 2, "name_ar": "قهوة بلدي", "price_multiplier": 1.0, "seating": true },
    { "id": 3, "name_ar": "قهوة بلدي مزدحمة", "price_multiplier": 1.6, "seating": true },
    { "id": 4, "name_ar": "قهوة تراثية", "price_multiplier": 2.6, "seating": true },
    { "id": 5, "name_ar": "كافيه حديث", "price_multiplier": 6.0, "seating": true }
  ]
}
```
Multipliers are derived from the Masrawy pricing survey (12.5 → 32.5 → ~80 EGP average bands) — tune once Phase 3 playtesting runs.

### `data/upgrades.json`
```json
{
  "upgrades": [
    {
      "id": "roof_rack",
      "category": "snacks_sides",
      "unlock_tier": 1,
      "cost_egp": 1200,
      "effect": "shelf_mount_roof",
      "changes_day_bookend_variant": true
    },
    {
      "id": "neon_sign",
      "category": "decor",
      "unlock_tier": 1,
      "cost_egp": 900,
      "effect": "patience_bonus_small"
    },
    {
      "id": "hire_nasbagi",
      "category": "staff",
      "unlock_tier": 2,
      "cost_egp": 4000,
      "effect": "auto_hot_station_assist"
    }
  ]
}
```

### `data/customer_archetypes.json`
```json
{
  "archetypes": [
    { "id": "elderly_regular", "name_ar": "العم", "patience_sec": 90, "tip_multiplier": 0.8, "usual_item": "tea_koshari" },
    { "id": "taxi_driver", "name_ar": "سواق تاكسي", "patience_sec": 35, "tip_multiplier": 1.1, "usual_item": "seklans" },
    { "id": "football_fan", "name_ar": "مشجع", "patience_sec": 50, "tip_multiplier": 1.0, "usual_item": null }
  ]
}
```

### `data/shisha_items.json` (new)
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
`lawlaat_before_hajar_change: 1` means the unflavored حجر is effectively replaced every session (matches the "roughly every session" figure). For flavored, track a live `lawlaat_count` on the active shisha session; when it hits the item's threshold, fire a `hajar_refill_needed` signal the player (or an auto-managed تومباكشي, post-hire) resolves mid-shift.

---

## 3. State Machines

### Customer patience state machine
```
ARRIVING → WAITING_TO_ORDER → ORDER_PLACED → WAITING_FOR_DRINK → SERVED (success)
                                      │
                                      └─(patience hits 0)→ LEFT_ANGRY (failure, reputation hit)
```
Tip calculation on `SERVED`: `base_price × venue_multiplier × speed_accuracy_score × archetype.tip_multiplier`.

### Day cycle state machine (owns the Day Bookend feature)
```
DAY_START
  → SETUP_TIMELAPSE (variant chosen by unlocked upgrades, e.g. roof_rack)
  → OPEN_FOR_BUSINESS (main loop: order → prepare → shisha → serve, looping)
  → CLOSING_TRIGGER (time limit or manual "close up" action)
  → TEARDOWN_TIMELAPSE (reverse of setup, same variant logic)
  → DAY_SUMMARY (tips earned, upgrades affordable, seasonal-event check)
  → DAY_START (next day)
```
Both time-lapse states support `skip_requested` (tap-to-skip) and a persisted `auto_skip_after_day` counter.

### Shisha session sub-state (new)
```
SHISHA_IDLE → COAL_LIT → SMOKING (lawlaat_count++ per rotation cycle)
                              │
                              ├─(lawlaat_count < threshold)→ SMOKING (loop)
                              └─(lawlaat_count == threshold)→ HAJAR_REFILL_PROMPT → SMOKING (after purchase) or SHISHA_IDLE (declined)
```

---

## 4. Save System
Use a versioned Godot `Resource` (not raw JSON) so `ResourceSaver`/`ResourceLoader` handle serialization, with a manual JSON export path kept only for debugging.

```gdscript
# scripts/autoload/save_system.gd (sketch)
class_name SaveData
extends Resource

@export var save_version: int = 1
@export var day_number: int = 1
@export var currency_egp: int = 0
@export var current_venue_tier: int = 0
@export var current_vehicle_id: String = "fifi"
@export var owned_upgrades: Array[String] = []
@export var unlocked_menu_items: Array[String] = []
@export var seasonal_event_state: Dictionary = {}
@export var settings: Dictionary = {"skip_cutscenes": false, "auto_skip_after_day": 3}
```
`save_version` exists from day one so a later schema change (e.g. adding the SUV tier's final name, or a new upgrade category) can migrate old saves instead of breaking them. Write a `migrate(old: SaveData) -> SaveData` function per version bump rather than editing the schema in place.

---

## 5. Telemetry / Analytics — GameAnalytics SDK (Decided)
Chosen over a custom endpoint: free tier, has a Godot plugin, ships with indie-friendly default privacy-policy guidance. Integrate in Phase 2, once a real gameplay loop exists to log. Minimum event schema:

```json
{ "event": "session_start", "ts": "...", "day_number": 1 }
{ "event": "day_complete", "ts": "...", "day_number": 1, "tips_earned": 340, "orders_served": 12, "orders_failed": 1 }
{ "event": "order_served", "ts": "...", "item_id": "tea_koshari", "station": "hot", "time_taken_sec": 11.2 }
{ "event": "order_failed", "ts": "...", "item_id": "coffee_mazbut", "reason": "patience_expired" }
{ "event": "upgrade_purchased", "ts": "...", "upgrade_id": "roof_rack", "cost_egp": 1200 }
{ "event": "cutscene_skipped", "ts": "...", "type": "setup_timelapse" }
```
A privacy policy is required before any public release (itch.io included) once this SDK is active.

---

## 6. Fonts (Arabic RTL — validate in Phase 1, don't assume)
Godot 4's **Advanced** text server (ICU/HarfBuzz-backed) is required for correct Arabic shaping/RTL — confirm it's active in Project Settings → Internationalization (official builds ship it by default, but verify rather than assume).

Starting fonts (open-license, good Arabic shaping):
- **Cairo** (Google Fonts) — modern geometric sans, good for HUD/UI text at small sizes
- **Amiri** or **Markazi Text** — more traditional Naskh-style, for menu boards / the FIFI-WAHSH wordmark reference sheet

Test both against a real ticket + menu screen mockup in Phase 1 before committing.

---

## 7. Project Settings — Aspect Ratio / Stretch Mode
```ini
[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/size/viewport_width=1080
window/size/viewport_height=1920
window/handheld/orientation="portrait"
```
Design all HUD anchors against the 1080×1920 safe rect; wider/shorter ratios reveal more isometric world around it rather than stretching UI elements. Implemented and tested in Phase 1.

---

## 8. Tutorial System State Machine
```
FIRST_LAUNCH → STAGE1_UI_INTRO (controls/ticket-rail walkthrough, once)
                     │
            (first tap on hot station) → STAGE2_HOT_TUTORIAL (guided first drink)
            (first tap on cold station) → STAGE_COLD_TUTORIAL
            (first tap on shisha station) → STAGE_SHISHA_TUTORIAL
            (first tap on any newly-purchased station) → STAGE_<STATION>_TUTORIAL
```
Backing data: `tutorials_seen: Dictionary` in `SaveData` (e.g. `{"ui_intro": true, "hot_station": false, ...}`). A `TutorialManager` autoload checks this dict on the relevant interaction signal and fires the matching sequence exactly once, then flips the flag. Structural hooks built in Phase 1 (covers hot/cold); shisha + future purchased stations extend the same system in Phase 3.

---

## 9. Save System — Local Only (Confirmed)
No cloud-save/cross-device sync for v1 — confirmed decision, not a gap. Note for the whole team (even if that's just you): **the GitHub repo version-controls source code; it is not a player save-game backup system.** Player progress lives in the local `SaveData` resource on-device only (see §4 above in this doc for the schema). If cross-device save sync becomes a priority later, that's a distinct feature to design separately, not something the repo already provides.

---

## 10. Open Items for Phase 0/1
- [x] SUV-tier vehicle name — **WAHSH** (locked)
- [x] Telemetry approach — **GameAnalytics SDK** (locked)
- [ ] Validate Godot's ICU text server + chosen font(s) against a real RTL Arabic UI mockup (Phase 1)
- [ ] Confirm shisha real-world pricing bands (supplied, not independently sourced) still feel right after a local sanity-check
- [ ] Decide whether `venue_tiers.json` multipliers apply globally or per-item (iced specialty drinks only exist at Tier 5+)

