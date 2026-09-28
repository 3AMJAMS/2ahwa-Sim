---
name: development-roadmap
description: Production roadmap for 2ahwa Sim — Sayed/FIFI/WAHSH vehicles, art style guide, itch.io-first launch, GameAnalytics telemetry, tutorial system, trimmed Phase 0, 6 phases
sources: [chat]
aliases: [phase plan, timeline, production schedule]
---

# 2ahwa Sim Development Roadmap (v5)

## Overview
Six-phase production plan, built solo (art in-house; friends' contributions are casual AI-assisted tweaks, not a formal team; voice work deferred; street ambience via a separate AI agent). Player character: **سيد (Sayed)** — no role-name UI; does every job himself until staff unlocked. Fully Egyptian Ammiya Arabic + RTL at launch; **English toggle added in Phase 6** (translation-key architecture from Phase 1). Opens on **FIFI** hatchback trunk stand; second vehicle tier is **WAHSH** (الوحش, locked name, boxy-90s-SUV silhouette). Visual architecture: isometric (2:1 dimetric) + flat "Right Mix" station view. **Engine: Godot.** **Launch: itch.io first**, mobile stores as a later stretch goal.

---

## Phase 0 · Foundation (Weeks 1–3) — trimmed
Design bible, FIFI+WAHSH locked, Egyptian Ammiya UI (translation-key architecture adopted), shisha kept in scope, Art Style Guide locked, engine (Godot) decided, aspect-ratio *approach* decided, itch.io-first decided.

**Moved OUT of Phase 0:** aspect-ratio/RTL implementation → Phase 1 · noodle-pack art → Phase 3 · tutorial hooks → Phase 1 (new-station triggers → Phase 3) · telemetry SDK integration → Phase 2 · formal app-store paperwork → deferred until mobile pursued.

**Exit benchmark:** premise, language architecture, art style, engine, vehicle names, launch platform signed off in writing.

---

## Art Style Guide (Locked — adjustable as we go)
- **Isometric tile:** 128×64px (2:1 dimetric), authored at 2× for high-DPI
- **Character proportions:** ~4 heads tall, slightly oversized head/hands (Moonlighter/Graveyard Keeper register)
- **Palette:** deep indigo/navy night base; warm amber/gold practicals (string lights, neon, coal); warm-neutral stone/pavement; period-appropriate FIFI/WAHSH body colors. (The roadmap page's own sand/terracotta/teal/gold is UI chrome only — the game world reads as a lit night street.)
- **Lighting:** warm key light from the sodium streetlights (~45° down-front), consistent across every tier; cool dim ambient night-sky fill for silhouette separation.

---

## Vehicle Naming (Resolved)
**FIFI** — 127-styled silhouette, yellow, original name/logo. **WAHSH (الوحش)** — SUV tier, boxy-90s silhouette, no Jeep grille/Cherokee echo.

---

## Localization: English Toggle (Deferred to Phase 6)
Arabic-only through Phase 5. Translation-key architecture from Phase 1 (key → Arabic string in a lookup table). English pass + Settings toggle built in Phase 6.

---

## Tutorial System (Multi-Staged, Diegetic)
1. **Stage 1** (first launch): UI/controls walkthrough.
2. **Stage 2** (first tap on brewing area): contextual mini-tutorial, guides first drink.
3. **Stage 3+**: shisha station, cold station, and any new station bought later — each gets its own first-use trigger.

`tutorials_seen` dict in save data; TutorialManager autoload fires each sequence once. Structural hooks: Phase 1. New-station triggers: Phase 3.

---

## Phase 1 · Core Minigame (Weeks 4–8) — in progress
Hot boil-and-pour gauge (كنكة on FIFI's gas ring; رملة sand bath comes later as a heat-slot upgrade) + cold blender gauge, in isolation. **Also:** aspect-ratio/stretch-mode implementation, RTL font validation, translation-key architecture, tutorial Stages 1–2.
**Exit benchmark:** both loops satisfying 10–15 min, tested across aspect ratios + mid-range Android + desktop.

**Built (as of 28 Sep 2026):**
- Loop: tap FIFI's trunk → fade to prep station → brew → tips → fade back to the street
- Heat gauge drawn as a real stove: gas ring + كنكة, rising foam, steam, lift-tilt-pour into a tea glass, boil-over with spill + smoke
- Placeholder FIFI redrawn as a Fiat 127-style hatchback; trunk tap area covers the whole rear
- Isometric street placeholder (pulled forward from Phase 2 to host the trunk tap)
- Translation keys (`ar_EG.csv`), Cairo font, portrait `canvas_items` + `expand` stretch, local save, locked espresso slot with price
- Blend gauge on screen: blender art with ice/hibiscus chunks blending down, vortex, motor heat lights + smoke, pour into a tall glass with ice and straw. Overheating trips the motor's thermal cut-out: it stops until it cools, costing time and tips but never the drink
- Five orders rotating at random (no repeats back to back): شاي كشري, قهوة تركي (in a فنجان), كركديه سخن, كركديه ساقع, عصير مانجا (fruit comes from Sayed's ice box)
- FIFI repainted yellow and parked at the kerb with the hatch up, showing the Day-1 kit in the trunk (gas ring + كنكة, blender, and a wooden rack across the trunk holding jars of tea/sugar/hibiscus/coffee)
- LED strips lining the trunk opening and the hatch edge, in chasing red/purple/yellow bands
- Street now has asphalt, a kerb and pavement slabs on FIFI's passenger side, with the fruit ice box set down on the pavement beside the trunk
- Day/night cycle: the clock starts at 4 pm and runs 1 game minute per real second through sunset and night (sky, ambient light, streetlights, string lights) and round the clock; the day only ends when the player taps "go home" (روّح), which shows the day's takings and starts the next day
- Street reworked: FIFI parked in the kerb lane of a wide four-lane road (dashed lane lines, manhole, resurfaced patches), black-and-white painted kerbs, pavements both sides, and Cairo sodium streetlights (tapered galvanised poles, swan-neck arms, cobra-head lanterns, light cones and pools at night); string lights removed
- Visual pass with Godot's built-in effects: HDR 2D + glow (LED strips, gas flame, lamp lenses, work bulbs and lit windows bloom), real 2D lights from the streetlights and FIFI's LED spill lighting the car and road, moths circling the lamps and dust drifting in their beams (particles), heat shimmer over the gas ring (shader), and a vignette that deepens at night
- Polish pass: prep panel widened to 3:4 so it reads as a car's rear; the idle appliance (blender while brewing, stove while blending) waits at the back of the trunk; a cup of striped straws on the rack; the order is written on the rear windscreen; LED strips in eight colours that breathe in a slow wave (drawn once, animated by fading only — fixes the LED lag); see-through additive gas flame; no more layout jump when holding turbo
- Game feel: gold spark burst and floating "+tips" on a good pour, screen shake + phone vibration on boil-over and motor cut-out, wallet bounce when money comes in
- Street life: passing traffic (Cairo black-and-white taxis, microbuses, tuk-tuks) in the three moving lanes, with headlights/taillights after dusk
- Prep view: the raised hatch now fills the top in perspective, its rear windscreen showing the sky, stars and a streetlight through the glass (heater lines, wiper, espresso sticker on the glass); two work bulbs hang under the roof
- Raised hatch's rear windscreen now reads as glass: sky reflection, the heater-element lines, wiper and light streaks
- Prep station is a fixed 9:16 panel; wider/taller screens show the street around it (apartment blocks, road, pavement with streetlight and ice box). Its car backdrop is drawn once and only the LED strips animate, fixing the lag
- Prep station drawn as the back of FIFI: raised hatch, pillars, trunk interior with a wooden rack of supplies (paper cups, tea glasses, jars, tea/coffee boxes, water), LED strips round the opening, and the rear panel with lamps, plate and bumper below the sill
- Shelf restocked with generic corner-shop packs (no real brands, logos or copied pack designs): a loose-tea carton, a kraft bag of ground coffee, a counter box of 3-in-1 coffee sachets, an aluminium teapot (براد) and matchboxes; the row shrinks to fit narrower screens. Espresso sticker taken off the glass for now
- Streetlights are now plain galvanised silver from foot to lantern (no painted bands), in the street and the prep view's surroundings
- Sayed's pitch on the pavement: his folding lawn chair (aluminium frame, green-and-white woven strips, armrest pads) with a glass of tea on its saucer and his transistor radio. Customer seating (monobloc plastic chairs round a woven-look plastic stool table) is held back as a later upgrade
- Traffic overhaul: vehicles built close to FIFI's real-world scale (80%) with rounded bodies (sloped windscreens, side glass, wheel arches, rims, lamp housings and plates), six kinds (Cairo white taxi with the chequered band and roof sign, private saloons in assorted colours, white microbus with coloured stripe and roof bundle, pickup loaded with watermelons or crates of oranges, tuk-tuk with tasselled fringe, delivery scooter with rider). Each lane feeds its own stream, sometimes in bunches; vehicles brake and follow slower ones instead of overlapping; tuk-tuks and scooters jiggle over the asphalt

- Prep station reworked into making the drink: the player picks the ingredients from a tray of cards (شاي, بن, كركديه, مانجا, تلج — كركديه ساقع needs كركديه + تلج), then the tool (الكنكة on the fire, or الخلاط), and only then plays that tool's gauge. The stove waits in front and the blender behind until the tool is chosen. Wrong picks shake the car and dock 20% of the tip each (floor 50%). Recipes live in `menu_items.json` (`ingredients`); the pickable items and tools in `prep_items.json`
- Tutorial system (TutorialManager autoload, `tutorials_seen` in the save): Sayed talks the player through it in a speech bubble with his portrait, a spotlight dims everything else, and a pointing hand shows where to tap. Stage 1 (first launch): welcome, day/clock/wallet, going home, tapping the trunk. Stage 2 (first order): reading the order, picking the ingredient, picking the tool; then the stove's first use (take it off in the green, don't let it boil over), the blender's first use (hold for turbo, watch the motor), and where the tips go. On "do it" steps only the spotlit card/trunk takes taps, so the first order can't go wrong. "تخطّي الشرح" turns tutorials off for the save
- Detail pass: vehicles rebuilt with rounded profiles, framed windscreens and door glass, door shut lines, handles, mirrors, five-spoke rims with tyre depth, grilles, headlights/tail lamps, bumpers, plates, exhaust, roof racks, ladders and bed walls; hammered كنكة with an engraved band, gas cylinder with weld seam, dents, chipped band, foot slots, shroud, regulator and hose, burner ports; faceted tea glass; blender with feet, cord, screws, speed dial and ribbed jug; shelf jars with contents, labels and ridged lids, printed paper cups, faceted glasses, rack brackets; FIFI gets a fuel flap, door keyhole and trim, "127" badge, reversing lamp, mud flap and aerial

**Remaining:**
- RTL + aspect-ratio device checks; exit playtest

## Phase 2 · Station Loop MVP (Weeks 9–16)
Full loop (order→prepare→shisha→serve) + day bookends. Isometric grid + Y-sort. **Also:** GameAnalytics SDK integration.
**Exit benchmark:** full shift end-to-end incl. camera cut, across device/aspect-ratio matrix.

## Phase 3 · Personas & Economy (Weeks 17–24)
Customer archetypes, sugar ladder, full menu (+ noodle-pack art), Store Upgrades, vehicle/venue tier gate, roof-rack upgrade, shisha حجر economy. **Also:** new-station tutorial triggers.
**Exit benchmark:** testers want "one more day"; watch first-3-day retention via GameAnalytics.

## Phase 4 · Modes & Authenticity Polish (Weeks 25–32)
Rush Hour + Story Mode + co-op. Full Arabic voice work. Original tarab-style ambience (no real Umm Kulthum/Fairuz). Shisha asset detail pass.
**Exit benchmark:** Egyptian playtesters recognize it as authentic.

## Phase 5 · Platform & Launch Prep (Weeks 33–38) — lightened by itch.io-first
RTL + aspect-ratio QA, vehicle art legal sign-off, itch.io page setup (description, screenshots, pricing). **Deferred:** age-rating paperwork, Google Play/Apple accounts — only if mobile pursued later.
**Exit benchmark:** itch.io page live with telemetry flowing.

## Phase 6 · Launch & Live Ops (Week 39+)
English translation pass + language toggle. Seasonal events, new venue tiers, backlog mining. Mobile app-store distribution as stretch goal.

---

## Distribution: itch.io First
No developer-account fees, no formal age-rating questionnaire, permissive content policy (shisha is a non-issue). Windows/Mac/Linux + HTML5/Web export. Mobile stores (Google Play $25 one-time, Apple $99/yr, age-rating paperwork) = post-launch stretch goal.

## Telemetry: GameAnalytics SDK (Decided)
Free tier, Godot plugin, indie-friendly privacy-policy guidance. Integrated Phase 2. Event schema: session_start, day_complete, order_served, order_failed, upgrade_purchased, cutscene_skipped. Privacy policy still required once live.

## Save System — Local + Source-Control Clarification
Local device saves, confirmed. **Note:** GitHub backs up source code, not player save games — those live on-device only. Cross-device cloud save is a separate system, out of scope for v1. Versioned save schema in technical-blueprint.md §4.

## QA / Feedback Loop (Very Optional)
Single main-menu button → short feedback form. Nothing mandatory or blocking.

## Performance Budget
Floor: mid-range Samsung Galaxy A-series (closest real models to "A74": **A73 5G / A54 5G**, ~2022, Snapdragon 7-gen/Exynos 1280, 6–8GB RAM) up to newest flagships. 60fps floor on flat stations even on the A73/A54 class; isometric world can flex to 30fps only on the weakest supported devices. Scaling settings (textures, particles, lighting) for flagships. Min OS: Android 10+ (API 29+).

## Business/Ownership
Project: **2ahwa Sim**. Effectively solo (you + AI assistance); friends' input is casual AI-assisted suggestions, not formal collaboration — no revenue-share paperwork needed unless that changes.

---

## Feature Ideas Backlog
Retention (regulars with memory, loyalty card, badges) · Atmosphere (radio/ambient events, seasonal weather, khamaseen wind, a daily-changing street: pavement on either side of FIFI, then new spots each day with trees, street corners, cats/dogs) · Cultural (café-history trivia notebook) · Economy (Ramadan iftar pricing, daily special, equipment wear: a blender pushed too hard can break and needs a paid repair — Phase 1 only has the free thermal cut-out) · Sharing (photo-mode/receipt screen)

---

## Core Loop
Take Order → Prepare (🔥 hot gauge / 🧊 cold blender) → Shisha (coal timer, حجر refill) → Serve. Scoring: speed×accuracy → tips → unlocks/progression.

## Day Bookend Sequence
2–4 sec time-lapse: park → trunk open → ice box carried from FIFI's passenger seat to the pavement → shelves stocked (side/roof per upgrade) → power on (LED strips light up) → gameplay; reversed at close. Tap-to-skip + auto-skip. Day 1 deliberately bare.

---

## Realistic Pricing Reference
Source: Masrawy field report, 17 Sep 2026 (tea); shisha figures supplied directly.

| Real tier | Real avg. tea | Our tier | Band |
|---|---|---|---|
| — | — | FIFI/WAHSH | 5–12 EGP |
| الشعبية | ~12.5 (6–15) | Street/busy baladi | 10–15→15–25 EGP |
| التراثية | ~32.5 | Historic café | 25–40 EGP |
| متوسطة→راقية→عالمية | 60→82.5→97.5 | Modern كافيه | 50–110 EGP |

Cold drinks ~1.5–2× tea baseline.

| Shisha | Session | حجر refill | Notes |
|---|---|---|---|
| Unflavored (قص/سلوم) | 15–70 EGP | 5–30 EGP | ~every session; WAHSH tier+ |
| Flavored (معسل) | 50–250 EGP | 20–60 EGP | lasts 5–7 ولعات; street ahwa+ |

---

## "Empire Mode" (Assessed, Not Committed)
Idle/incremental layer, optional **Phase 7** post-launch bolt-on — prototype small first.

---

## Hot & Cold Menu
**Hot:** شاي (full ladder) · قهوة تركي (سادة→سرياقوسي) · سحلب · كركديه/ينسون (dual) · حلبة · قرفة · زنجبيل · كاكاو · الحلبسة
**Cold:** كركديه بارد/ينسون بارد (dual) · مانجو (fruit kept in Sayed's ice box: rides in FIFI's passenger seat, set on the pavement each day) · تمر هندي · سوبيا (seasonal) · عرقسوس · قصب · خروب · قمر الدين (seasonal) · ليمون بالنعناع · بطيخ بالنعناع · جوافة/موز بلبن · آيس لاتيه/موكا/كولد برو (Modern unlock)

---

## Progression Ladder
1. FIFI trunk stand · 2. WAHSH stand · 3. Street baladi ahwa · 4. Busy baladi ahwa · 5. Historic café (El-Fishawy) · 6. Modern كافيه

## Store Upgrades
| Category | FIFI | WAHSH | Fixed venues |
|---|---|---|---|
| Equipment | Basic burner+blender | Dual burner, upgraded blender | Bigger رملة, espresso machine |
| Snacks | Small chip rack | Chip+noodle rack | Full snack cooler |
| Décor | LED strips lining the trunk (red, purple, yellow); later: stickers and signs on the hatch underside | Neon signs + less-local, more modern décor, stools | Marble tables, mashrabiya |
| Seating | Sayed's lawn chair only; upgrade: two monobloc plastic chairs round a woven-look plastic stool table on the pavement | More plastic chairs and stools | Full ahwa seating |
| Shisha | None | Mini corner, unflavored | Full corner+staff, flavored T3+ |
| Staff | Sayed only | Sayed only | نصبجي T3, تومباكشي T4, waiters T5 |

---

## Engine: Godot (over Three.js)
Native isometric TileMap+Y-sort, built-in UI/save/audio, exports Android/iOS/Web/PC, ICU RTL text server, `canvas_items`+`expand` handles aspect ratio.

## Design References
Bartender: The Right Mix · Cook, Serve, Delicious! · Papa's Freezeria · Diner Dash · Good Pizza, Great Pizza · Overcooked · Coffee Talk/VA-11 Hall-A

---

## Risk Register
| Risk | Severity | Mitigation | Phase |
|---|---|---|---|
| Shisha content policy | LOW (itch.io)/HIGH (mobile later) | Stylized toggle; formal disclosure only if mobile pursued | 0, revisit if mobile |
| RTL Arabic UI breaks in text renderer | HIGH | Test ICU text server + font early | 1 |
| Real Umm Kulthum/Fairuz music without license | HIGH | Original compositions instead | 4 |
| Vehicle naming/trade-dress | RESOLVED | FIFI+WAHSH locked, original names | 0 |
| Isometric↔flat transition fragile | MEDIUM | Prototype transition itself | 2 |
| Aspect-ratio/device fragmentation | MEDIUM | Stretch-mode+safe-rect; test every phase | 1–5 |
| Slang confuses players | MEDIUM | Recipe book + "ask to repeat" | 1–2 |
| Early-game churn | MEDIUM | Track first-3-day retention | 3 |
| Seasonal cold-menu items | LOW | Gate as limited-time | 3 & 6 |
| Unattributed quotes | LOW | Verified lines only | 4 |
| Time-lapse tedium | LOW | 2–4s, tap/auto-skip | 2 |
| GitHub repo ≠ player cloud save (player confusion) | LOW | Clarify saves are local-only for v1 | 5 |

---

## Companion Documents
`technical-blueprint.md` — folder structure, schemas, state machines, save system, telemetry, fonts
`production-checklist.md` — art style guide, onboarding, QA loop, store/legal readiness, performance budget

## Live Artifact
https://claude.ai/artifact/NtcwuP77SRERwZJrs6BeEo
