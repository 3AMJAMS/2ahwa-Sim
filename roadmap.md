---
name: development-roadmap
description: Production roadmap for 2ahwa Sim (v6) — what is built so far (Phase 0 and the FIFI loop), then seven lettered phases A–G (lock the frame and look on the Galaxy A70, the replayable FIFI week, ship the FIFI slice on itch.io, WAHSH and shisha, fixed venues and staff, authenticity + English + paid launch, live ops), why this order, what was cut, game files parked in later/, PostHog + Sentry telemetry, and the reference sections (art style, menu, economy, upgrades, risks)
sources: [chat]
aliases: [phase plan, timeline, production schedule]
---

# 2ahwa Sim Development Roadmap (v6)

## Overview
Built solo (art in-house; friends' contributions are casual AI-assisted tweaks, not a formal team; full voice work dropped for voiced barks; street ambience via a separate AI agent and own recordings). Player character: **سيد (Sayed)** — no role-name UI; does every job himself until staff are unlocked. Fully Egyptian Ammiya Arabic + RTL; **English toggle added in Phase F** (translation-key architecture in place since the start). Opens on the **FIFI** hatchback trunk stand; second vehicle tier is **WAHSH** (الوحش, locked name, boxy-90s-SUV silhouette). Visual architecture: blocky 3D — an isometric (2:1) street view and a 3D prep view inside FIFI's trunk. **Engine: Godot.** **Launch: itch.io first** — the FIFI slice goes public in Phase C, the paid full version in Phase F; mobile stores are a later stretch goal.

**What changed in v6 (9 Oct 2026):** the six numbered phases are replaced by seven lettered phases, A–G. Phase 0 and most of the old Phases 1–2 are built (see "Built so far"). The rest is reordered: fix performance once against a written budget, make the FIFI week worth replaying, ship it as a small public slice for real data, then grow to WAHSH, the fixed venues and the paid launch. Telemetry moves from GameAnalytics to PostHog, with Sentry for crashes. Game files meant for later phases are parked in `later/` until their phase.

---

## Plan at a glance
| Phase | Length | What it delivers | Exit benchmark |
|---|---|---|---|
| Built so far | Weeks 1–~6 (to 4 Oct) | Foundation + the FIFI loop in blocky 3D | — |
| **A · Lock the frame and the look** (current) | ~1–2 weeks | On-device profiling on the A70, a written budget, quality presets, cheap polish, CI budget check, device checks | 30+ fps on the A70 in both views at Med; prep looks right; Phase-1 playtest done |
| **B · The FIFI week, worth replaying** | ~3–4 weeks | Upgrade shop on the dawn receipt, menu growing over days 1–7, daily goal + day-7 milestone, regulars, reactions, audio, day bookends, PostHog + Sentry | A stranger plays days 1–7 unaided; PostHog funnel shows players finishing day 3; testers ask for more |
| **C · Ship the FIFI slice** | ~1 week | itch.io page (Web + Android + Windows) via butler from CI, screenshots, trailer, devlog, shareable receipt | Public link, telemetry flowing, first outside feedback |
| **D · WAHSH and shisha** | ~4–6 weeks | Buy WAHSH, dual burner, espresso, two glasses, shisha mini corner, personas, sugar ladder, snack rack, first fruit drinks, cat animations | First-7-day retention holds or improves after the WAHSH unlock |
| **E · Fixed venues and staff** | ~6–8 weeks | Street then busy baladi ahwa, interiors, رملة, staff, seating, rounder people, Rush Hour, blender + juice tiers | A full busy-ahwa shift with staff runs at 30+ fps on the A70 at Med, and testers want to replay Rush Hour (proposed) |
| **F · Authenticity, English, launch** | ~4–6 weeks | Original tarab-style music, voiced barks, trivia notebook, English + toggle, paid itch.io launch | Egyptian playtesters recognise it as authentic; paid page live (proposed) |
| **G · Live ops / post-launch** | Ongoing | Seasonal events, historic café, modern كافيه, عصارة, Empire Mode prototype, soft-drinks factory | Each event judged by its PostHog numbers |

**Old phase numbers → new letters** (for any older note or doc that still uses them):
| Old phase | Goes to |
|---|---|
| Phase 0 · Foundation | Done |
| Phase 1 · Core Minigame | Done; the device checks and exit playtest → **A** |
| Phase 2 · Station Loop MVP (incl. GameAnalytics) | Done; day bookends, "ask to repeat" and telemetry (now PostHog) → **B**; shisha → **D** |
| Phase 3 · Personas & Economy (store upgrades, tier gate, new-station tutorial triggers) | Upgrade shop → **B**; personas, sugar ladder, snacks, WAHSH gate, shisha, new-station triggers → **D** |
| Phase 4 · Modes & Authenticity (modes, voice, music) | Rush Hour → **E**; music, barks, quotes check → **F**; Story Mode shrunk, co-op cut |
| Phase 5 · Platform & Launch Prep | itch.io page, privacy policy, legal sign-off → **C**; paid launch, final QA → **F** |
| Phase 6 · Launch & Live Ops (English, live ops, venues, mobile) | English + mobile stretch → **F**; seasonal events, later venues → **G** |
| "Phase 7" (Empire Mode) | **G** |

---

## Phase A · Lock the frame and the look (current, ~1–2 weeks)
Make the FIFI build run well on the phone it is actually tested on, write the budget down once, and give every later phase a check that stops it slipping.

**Already done in A:**
- Per-view lighting (4 Oct): per-pixel on everything near the camera (the kit, FIFI, people, cars), per-vertex on the big flat street surfaces
- Prep-station polygon pass (4 Oct): ≈55k → ≈85k triangles in the trunk with the same draw calls
- FPS readout (3 Oct): hold the day/clock/money line for a second to show or hide it

**To do:**
- **On-device profiling on the Samsung Galaxy A70:** Godot remote debug + the in-game FPS/draw-call readout; Android GPU Inspector for what the GPU is actually spending time on
- **A written per-view budget:** street and prep, draw calls + triangles, recorded in the Performance Budget section below
- **Graphics quality presets:** Low / Med / High (render scale, shadows, per-pixel lighting reach, prop density), picked automatically on first launch and changeable in settings
- **Cheap polish:** baked vertex ambient occlusion in the Vox builder (soft corner darkening for free); a matcap shader for brass, steel and glass; hide the street the prep camera can't see; MultiMesh + visibility ranges for repeated street props
- **CI:** headless flow tests + a triangle/draw-call budget check that fails a PR going over budget
- **RTL + aspect-ratio device checks** (the one item left from old Phase 1): Arabic text in every HUD element, and the test matrix (9:20 phone, 3:4 tablet, 16:9 desktop, 21:9 ultrawide)
- **The Phase-1 exit playtest** (10–15 minutes on the FIFI build)

**Exit:** 30+ fps on the A70 in both views at Med; the prep station looks right; the Phase-1 playtest done.

---

## Phase B · The FIFI week, worth replaying (~3–4 weeks)
Give the tips somewhere to go and give the street a sound, so twelve drinks become a week someone wants to play.

- **Upgrade shop on the dawn receipt** (spend the tips):
  - Lemon squeezer + tea strainer — unlocks ليمون and ليمون بالنعناع (the squeezer and strainer are parked in `later/` until then)
  - A bigger / double كنكة
  - Customer seating: two monobloc plastic chairs round a woven-look plastic stool table on the pavement
  - The prep-station decorations removed on 1 Oct come back as purchases: stickers (incl. صلّي على النبي), the hand of Fatima / blue-eye charm, the tassel fringe, fairy lights, LED strips in the trunk, a shelf of glasses and cups, floor storage. Detail becomes earned progression instead of frame cost, each piece checked against Phase A's budget
- **The menu grows over days 1–7:** day 1 is شاي كشري + شاي فتلة; a drink or two more each day, introduced by Sayed
- **A daily goal** on the receipt, and a **day-7 milestone**: saving toward WAHSH
- **Regulars:** 3–4 named customers who come back and order "the usual" (this also covers the old "ask to repeat" idea)
- **More reactions:** customers pointing at the menu board, reacting to honks and near misses, kids tugging at their parent, Sayed greeting regulars by name
- **Audio pass:** kit SFX, coins, traffic and horns, customers' shouts, Sayed's radio, street ambience from evening into night. Sources: sfxr/jsfxr, Freesound CC0, own Cairo recordings
- **Short day bookends** (1–2 s, tap to skip) — see Day Bookend Sequence
- **Telemetry:** PostHog over HTTP (replaces the GameAnalytics plan) + crash reporting with Sentry (sentry-godot) — see Telemetry
- **A light story** told through Sayed's receipt lines and the regulars (what is left of Story Mode)
- **Sayed's portrait** in the tutorial bubble and on the receipt redrawn from his blocky 3D figure (from the old "Later" list; the receipt is being reworked for the shop anyway)

**Exit:** a stranger plays days 1–7 unaided; the PostHog funnel shows players finishing day 3; testers ask for more.

---

## Phase C · Ship the FIFI slice (~1 week)
Put the FIFI week in front of people outside the friends circle and start collecting real numbers.

- **itch.io page** with Web + Android + Windows builds, uploaded by butler from CI
- Screenshots, a short trailer, a devlog post
- **Shareable dawn-receipt image**
- Optional **feedback button** (a PostHog survey or a form link)
- **Google Play internal testing** only if there are more than ~5 Android testers
- Before the link goes public (carried from old Phase 5): a short privacy policy (PostHog + Sentry are active), the local-save wording on the page, and a final check that FIFI and WAHSH read as original designs

**Exit:** a public link, telemetry flowing, the first outside feedback.

---

## Phase D · WAHSH and shisha (~4–6 weeks)
The first tier gate: Sayed buys the bigger vehicle and the game gets its second station.

- **Buy WAHSH** — the vehicle/venue tier gate; a new blocky stand and more street variety (Downtown façades, a mosque, a kiosk; the daily-changing street from the backlog fits here). WAHSH's venue data is parked in `later/`
- **Equipment:** dual burner; the **espresso machine** (1,200 EGP; its data is parked in `later/`); **two glasses at once**
- **Shisha mini corner:** coal rotation and the حجر economy (unflavoured at this tier, see Pricing), with its own **new-station tutorial trigger**
- **Customer archetypes / personas:** elderly regular, domino pair, football fans, taxi drivers, students, المعلم
- **The full sugar ladder** as a difficulty axis (سادة → ريحة → مظبوط → مانو → زيادة → سرياقوسي), and streak/combo scoring (from old Phase 3)
- **Snack rack:** chips + noodles, with the noodle-pack art (colour-coded, unbranded); the roof-rack shelf upgrade that swaps the day-bookend variant
- **The first fruit drinks:** mango and the like, iced not blended, fruit from Sayed's ice box (mango's menu item, ingredient, icon, jar/crate and shouts are parked in `later/`)
- More hot drinks to consider for the WAHSH menu: سحلب (milk, sahlab powder, nuts on top), حلبة, جنزبيل, نسكافيه باللبن, كاكاو (the winter ones also suit G's seasonal events)
- **Cat animations** (any spare time; good marketing clips): jumping down off FIFI, walking the pavement, sitting, stretching, grooming, rubbing round customers' legs, curling up under the chair, begging at the ice box; customers who stop to pet it

**Exit:** first-7-day retention holds or improves after the WAHSH unlock.

---

## Phase E · Fixed venues and staff (~6–8 weeks)
Four walls: Sayed stops working out of a car and starts hiring.

- **Research pass first** (see the Research rule under Beverages Chain), then the **street baladi ahwa**, then the **busy baladi ahwa**
- **Blocky interiors** for the fixed venues; the **رملة** sand bath as the heat-slot upgrade
- **Staff** taking over Sayed's jobs (نصبجي at tier 3, تومباكشي at tier 4); **full ahwa seating**; the backgammon and dominoes crowd, marble tables, the radio
- Full shisha corner with staff, flavoured معسل from the street ahwa on, and the shisha asset detail pass (القلب, الحجر, الكالوش/الصينية, الشربوش/الكسوة, الرفاس as upgrade-tier skins)
- **Rounder people:** more polygons on customers, Sayed and the drivers (round heads, limbs and hands)
- **Rush Hour mode:** timed, with match-time and Ramadan-night variants
- **The blender returns** with the juice tiers: blender + juicers (orange, carrot and more), its blend gauge and first-use tutorial brought back from `later/`

**Exit (proposed, confirm at the start of E):** a full busy-ahwa shift with staff runs at 30+ fps on the A70 at Med, and testers want to replay Rush Hour.

---

## Phase F · Authenticity, English, launch (~4–6 weeks)
Make it unmistakably Egyptian, open it to English speakers, and charge for it.

- **Original tarab-style music** (no real Umm Kulthum/Fairuz — see Risk Register)
- **Voiced barks only:** customers' shouts and Sayed's one-liners, not full voice work; every quoted line verified against its source
- **Café-history trivia notebook**
- **English pass + Settings language toggle**
- Final RTL + aspect-ratio QA pass across every menu and HUD element
- **Paid itch.io launch** ("full version"); mobile stores as a stretch (revisit the deferred Google Play/Apple accounts and age ratings then)

**Exit (proposed, confirm at the start of F):** Egyptian playtesters recognise the slang and setting as authentic ("this is exactly my local ahwa"), and the paid page is live.

---

## Phase G · Live ops / post-launch
- **Seasonal events:** Ramadan iftar pricing (and a Ramadan night shift), khamaseen, سوبيا and قمر الدين as limited-time drinks
- **Historic café** (El-Fishawy-style; a full team of white-galabiya waiters, mashrabiya, gilded mirrors) and the **modern كافيه** (espresso, iced latte/mocha/cold brew)
- **عصارة juice shop:** cane press, juicers, blenders, fruit display
- **Empire Mode prototype** (small first — see Empire Mode)
- **Soft-drinks factory** (far future)
- Regional variants (Upper-Egypt dominoes, Alexandria "كراميل" grade), community feedback feeding difficulty/economy tuning, backlog mining

**Exit:** none; each event is judged by its PostHog numbers.

---

## Why this order
- **Performance once, with a budget.** Every batch since 30 Sep has paid for frame rate again. Profiling on the real phone and writing the per-view budget down in A, with CI checking it, means later phases add content inside a known limit instead of re-fixing lag.
- **A money sink and sound turn the content into a game.** The twelve drinks, the customers and the street are there; what is missing is a reason to keep the tips and a street you can hear. B adds both before any new tier.
- **Ship a small slice early for data.** One week of FIFI on itch.io (C) gives real PostHog funnels and outside feedback before the big WAHSH and venue phases, so D–F are shaped by what players do, not guesses.
- **Decorations as purchases settle detail vs frame rate.** The trunk decorations were cut on 1 Oct for frame cost. Selling them back one at a time in B makes detail something the player earns, and each one can be checked against A's budget as it lands.
- **Batter Days reuses Phase A tooling.** The profiling routine, the budget check in CI and the quality presets carry straight over to the waffle game, so the time spent in A pays twice.

## Cut / shrunk
- **Co-op:** cut
- **Story Mode** → a light story told through Sayed's receipt lines and the regulars (B onward)
- **Full Arabic voice work** → voiced barks only (F)
- **Animated prep-station sky** → decide after Phase C feedback
- **Equipment wear / repairs** → only if Phase B's economy needs a second money sink
- **Recipe-memory idea** (hints that fade as you learn) → stays dropped; staff take over Sayed's work at higher tiers
- Superseded by the 3D rebuild, not cut: the isometric TileMap + Y-sort plan (the street is now 3D through an orthographic camera) and the old performance floor (Galaxy A73/A54, 60 fps on flat stations), replaced by the A70 budget

## Parked for later
The game files for later phases live in the repo's **`later/`** folder (Godot ignores it), so the FIFI build only carries what FIFI uses. Each set comes back in its phase:
- **Blender and the juice minigame** — `blender3d.gd`, `blend_gauge.gd`, the blend wiring, the blender tool, its icon, its tutorial, the blender in FIFI's trunk kit on the street → **E** (juice tiers) / **G** (عصارة)
- **Mango** — the `mango_juice` menu item, the mango ingredient, its icon, jar/crate, shouts and strings, and the fruit heaped on Sayed's ice box in the street view (the ice box itself stays) → **D** (first fruit drinks)
- **Trunk charms in the street view** — the prayer beads and hand-of-Fatima charm hanging in FIFI's trunk → **B** (decorations bought in the upgrade shop)
- **Espresso machine** (`espresso_none`, `espresso_basic`) → **D**; **`blend_basic`** → **E**
- **Venues other than FIFI** (`venues.json` ids 1–5: WAHSH, the two baladi ahwas, the historic café, the modern كافيه) → **D / E / G**
- **Lemon squeezer + tea strainer** on the prep-station rail → **B** (bought in the upgrade shop)

`later/README.md` indexes every parked piece: where it lived, its phase, and how to wire it back.

What stays in the FIFI build: all 12 drinks (incl. the ice step and the ice bucket), both kanakas (steel + brass coffee one), the rail of spare kanakas + ladle, the menu board, FIFI's LED strips, Sayed's chair and radio, the cat, customers, traffic, the FPS meter, and the tutorial (minus the blender part).

---

## Built so far
History, kept so nothing gets re-litigated. Dated batches are as logged at the time; the 2D-era items are compressed because the 3D rebuild of 30 Sep replaced them.

### Phase 0 · Foundation (Weeks 1–3) — done
Design bible, FIFI+WAHSH locked, Egyptian Ammiya UI (translation-key architecture adopted), shisha kept in scope, Art Style Guide locked, engine (Godot) decided, aspect-ratio *approach* decided, itch.io-first decided.

**Moved out of Phase 0 at the time (and where it is now):** aspect-ratio/RTL implementation → old Phase 1 (stretch mode built; device checks → A) · noodle-pack art → D · tutorial hooks → old Phase 1 (built; new-station triggers → D) · telemetry SDK → B (PostHog) · formal app-store paperwork → deferred until mobile is pursued (F stretch).

**Exit benchmark (met):** premise, language architecture, art style, engine, vehicle names, launch platform signed off in writing.

### Old Phase 1 · Core Minigame (Weeks 4–8) — built 26–29 Sep
Planned as: the hot boil-and-pour gauge (كنكة on FIFI's gas ring; رملة later as a heat-slot upgrade) + the cold blender gauge, in isolation; aspect-ratio/stretch mode, RTL font validation, translation keys, tutorial Stages 1–2. Exit benchmark was "both loops satisfying for 10–15 min, tested across aspect ratios + mid-range Android + desktop": the playtest and device checks are now in A, and the blender loop is parked for E.

**Still standing from this phase** (items since replaced or parked are marked):
- Loop: tap FIFI's trunk → the prep station → brew → tips → back to the street
- Heat gauge as a real stove: gas ring + كنكة, rising foam, steam, lift-tilt-pour into a tea glass, boil-over with spill + smoke (rebuilt in 3D on 30 Sep)
- Translation keys (`ar_EG.csv`), Cairo font, portrait `canvas_items` + `expand` stretch, local save. (The 2D panel also showed the espresso slot locked with its price; that went with the 2D panel, and the espresso machine's data is parked in `later/` for D)
- Blend gauge: blender with ice/hibiscus chunks blending down, vortex, motor heat lights + smoke, pour into a tall glass with ice and a straw. Overheating trips the motor's thermal cut-out: it stops until it cools, costing time and tips but never the drink. (Out of FIFI since 3 Oct; parked for E)
- Day/night clock: starts at 4 pm and runs 1 game minute every 2.5 real seconds (slowed from 1 per second on 29 Sep), with the sky, ambient light and streetlights following it; "go home" (روّح) shows the day's takings and starts the next day (now inside a 15-minute shift, below)
- Game feel: gold spark burst and floating "+tips" on a good pour, screen shake + phone vibration on boil-over and motor cut-out, wallet bounce when money comes in
- Sayed's pitch on the pavement: his folding lawn chair (aluminium frame, green-and-white woven strips, armrest pads) with a glass of tea on its saucer and his transistor radio. Customer seating (monobloc chairs round a stool table) held back as an upgrade (now B)
- Shelf goods are generic corner-shop packs: no real brands, logos or copied pack designs (still the rule)
- Make the drink: pick the ingredients, then the tool (الكنكة on the fire, or الخلاط), then play its gauge; wrong picks shake the car and dock 20% of the tip each (floor 50%). Recipes live in `menu_items.json` (`ingredients`), pickable items and tools in `prep_items.json`. (The pick cards were replaced by the quick bar on 30 Sep)
- Tutorial system (TutorialManager autoload, `tutorials_seen` in the save): Sayed talks the player through it in a speech bubble with his portrait, a spotlight dims everything else, and a pointing hand shows where to tap. Stage 1 (first launch): welcome, day/clock/wallet, going home, tapping the trunk. Stage 2 (first order): reading the order, picking the ingredient, picking the tool; then the stove's first use (take it off in the green, don't let it boil over), the blender's first use (hold for turbo, watch the motor; now parked), and where the tips go. On "do it" steps only the spotlit target takes taps, so the first order can't go wrong. "تخطّي الشرح" turns tutorials off for the save

**The 2D era (26–29 Sep), replaced by the 3D rebuild on 30 Sep.** Before the blocky world everything was drawn in 2D: FIFI as a yellow Fiat 127-style hatchback at the kerb (the trunk tap covering the whole rear) with the hatch up and the Day-1 kit in the trunk (gas ring + كنكة, blender, a wooden rack of tea/sugar/hibiscus/coffee jars), LED strips round the trunk and hatch (chasing red/purple/yellow bands, later eight colours breathing in a slow wave, drawn once to fix the lag); five orders rotating at random with no repeats back to back (شاي كشري, قهوة تركي in a فنجان, كركديه سخن, كركديه ساقع, عصير مانجا with fruit from Sayed's ice box on the pavement); a street that grew from an isometric placeholder (pulled forward from old Phase 2 to host the trunk tap) into a four-lane road with dashed lane lines, a manhole and patches, black-and-white kerbs, pavements both sides and plain galvanised Cairo sodium streetlights (swan-neck arms, cobra-head lanterns, light cones and pools; the string lights removed); Godot's 2D effects (HDR glow, real 2D lights from the lamps and LED spill, moths and dust in the beams, heat shimmer over the gas ring, a night vignette); traffic redrawn at 80% of FIFI's scale in six kinds (white taxi with chequered band and roof sign, saloons, microbus with stripe and roof bundle, pickup with watermelons or oranges, a Bajaj-style tuk-tuk with tasselled fringe, a delivery scooter), one stream per lane, braking behind slower vehicles and overtaking tuk-tuks by switching lanes at ≈5.5–8.5 tiles/s; a prep panel drawn as FIFI's rear (3:4, then a fixed 9:16 panel with the street round it; the raised hatch in perspective with its rear windscreen showing sky, stars, a streetlight, heater lines, wiper and streaks; two work bulbs; a rack of supplies (paper cups, tea glasses, jars, a loose-tea carton, a kraft bag of ground coffee, a box of 3-in-1 sachets, an aluminium براد, matchboxes, water); the idle appliance waiting at the back; a cup of straws; the order written on the rear windscreen; a see-through gas flame; no layout jump when holding turbo; the espresso sticker taken off the glass); a detail pass (rounded vehicles with framed glass, rims, grilles and plates; hammered كنكة, gas cylinder with seam, regulator and hose; faceted tea glass; blender with dial, feet and cord; labelled jars, printed cups; FIFI's fuel flap, "127" badge, mud flap and aerial); and `MeshCanvas`, which baked each object into one vertex-coloured mesh and cut the street's draw calls ≈1,020 → ≈250 to fix the first phone lag.

### Old Phase 2 · Station Loop MVP (Weeks 9–16) — built 28 Sep → 4 Oct
Planned as: the full loop (order → prepare → shisha → serve) + day bookends, isometric grid + Y-sort, GameAnalytics; exit "a full shift end-to-end incl. the camera cut, across the device/aspect-ratio matrix". Where the unbuilt parts went: shisha → D; day bookends → B; GameAnalytics → PostHog in B; "ask to repeat" → B (regulars); device/aspect-ratio matrix → A; isometric TileMap + Y-sort → superseded by the 3D street.

**Customer loop and the FIFI menu (28–29 Sep):**
- Customers follow the blueprint's patience state machine: they walk up to one of three spots by the trunk, shout their order in Ammiya in a speech bubble, and wait with a patience bar over their head
- Order tickets clip onto a rail at the top of the street view (drink icon, name, patience bar, on-the-stove / ready marks); tapping a ticket, the customer or the trunk makes that order (the trunk picks whoever is most impatient)
- Serve: back on the street, tap the customer to hand the drink over. Tips are paid on serving: price × venue × drink quality (brew accuracy × pick penalty) × speed (60–100% by patience left). Customers who run out of patience leave angry and the ticket tears off
- Day summary with orders served and customers lost; tutorial extended to the first customer (who waits forever), their ticket, the trunk, and handing the first drink over
- App icon, hidden five-tap save reset for testers, Android APK + Web builds for friends
- Drive-bys: FIFI parks in the slow lane (البطيء) by the kerb. About two in three customers pull in by car (sedan, taxi, pickup, microbus) behind FIFI or beside her trunk in the next lane, wind the window down (arm on the sill), order, take the drink through the window and pull away, some leaving the window down. The rest walk up the pavement with a proper walk cycle
- FIFI's menu is hot drinks only: iced drinks are made on the كنكة, then an "add ice" step (tap the ice once per cube). كركديه ساقع and the new شاي ساقع work this way; mango left FIFI's menu for a later tier and, like every fruit drink, gets ice added after rather than blended
- **Sugar grades on every tea and coffee order** (shout, ticket, prep title): tea سادة/مظبوط/زيادة, Turkish coffee adds عالريحة and مانو (half-spoon taps: ½ / 1 / 1½ / 2). Tap the sugar per spoon; each spoon off docks quality
- **Tea built in the glass:** شاي كشري (sugar → loose tea → boiling water from the كنكة → stir), **شاي فتلة** (sugar → water → dunk the bag → stir) and **شاي على مية بيضا** (tea under a thick sugar layer — مظبوط 2, زيادة 3 spoons — then hold-to-pour the water down the side without piercing the sugar, a flow meter showing how hard, then stir, darkening gradually). Coffee's sugar goes in the كنكة
- **A shift lasts 15 minutes:** 4 pm to 4 am, then Sayed packs up by himself (روّح still ends it early; an order being made is handed over first)
- **The street cat** (ginger and white, ringed tail, from Sayed's real cat photos) asleep on FIFI's roof: breathing, ear twitches, tail flicks, lifting its head, blinking, yawning
- **Better bodies:** customers at ~5 heads tall (faces, varied hair, glasses, beards, clothing details, hands, shoes); Sayed sits in his lawn chair between orders, towel on his shoulder, sipping his tea
- **End of day is a dawn receipt:** pre-dawn sky over the rooftops, Sayed's day written up like a café receipt (orders served, customers lost, takings counting up, a red "خالص" stamp), his line for the day, and a "يوم جديد" button
- **Play links:** the Web build is published to GitHub Pages by a workflow on every merge (installable on iPhone via Safari → Add to Home Screen); Android APK for testers
- 2D prep-station passes, replaced by the 3D trunk on 30 Sep: the Fiat 127 hatch interior (painted steel, pressed rib, lightening holes, lock and latch hook, bump stops); a static sky in the windscreen (clouds rolled per day, the sun on its arc, stars and the moon in its phase for the game day); asphalt and the car's shadow under the bumper; a fixed 1080×1440 layout scaled to fit every screen; the car redrawn from behind at hatch height after the Renault 4 coffee-car photo; and movable racks (tap رتّب, drag, خلاص; kept in the save) with spare كنكة in three sizes, ladle, milk pan, tongs, the lemon squeezer with a tea strainer and checked towel, a chalk menu board, a water jerrycan, power strip and cables, a ribbed rubber mat, and light pools and shadows for depth

**The blocky world (30 Sep, second batch).** Everything moved to blocky 3D:
- **Street:** four-lane road with patches, cracks, faded lane lines, a zebra crossing, manholes and drain grates; black-and-white kerbs; stone pavements; a front garden behind railings with bushes and trees on our side; across the road a row of Cairo blocks with shops at street level (lit signs in Arabic, open shopfronts with shelves of goods, fruit crates and drinks fridges, pulled-down shutters, awnings) and flats above (louvred shutters, balconies with washing and plants, AC units, lit windows at night). Galvanised streetlights with swan-neck arms and cobra heads throw real sodium light pools after dusk, with moths. A bin, an electricity cabinet, a no-parking sign, a tree in a painted pit, a parked motorbike
- **Day and night** from real lights: a low sun that swings west and goes orange at sunset, a dim blue moon, sky-coloured ambient light; shadows
- **FIFI** as a blocky Fiat 127: taller roof and lower tail for a bigger opening, glass all round, chrome bumpers with rubber overriders, lamps, the plate (**ش ا ي ١٢٧**), the trunk kit, LED strips that breathe colour by colour, work bulbs lighting the trunk, and a gold frame that pulses round the opening when there's an order to make
- **Traffic** rebuilt in blocks (taxi with its chequered band and lit roof sign, saloons, microbus with luggage and passengers, pickup with watermelons or oranges, tuk-tuk with fringe, delivery scooter) with drivers visible through tinted glass; the near window winds down for drive-by customers, whose driver reaches out for the drink
- **Customers from a generator:** eleven skin tones, heights and builds, kids; shirts (plain, checked, striped), t-shirts, polos, suits and ties, sweaters, cardigans, jackets, tracksuits, football shirts (red / Zamalek white), school uniforms, doctor's white coats, hi-vis vests; galabeyas (plain or striped) with kufi, Upper-Egypt turban or wool shawl; an Azhari sheikh's kaftan and tarboush; abayas with hijab, niqab, long skirts, jeans; aunties in black with a headscarf and a basket; mothers with a child by the hand; tourists, bread sellers with a tray of عيش on the head, delivery riders in helmets; hair, beards, glasses, watches, and things they carry (phone, keys, newspaper, prayer beads, cane, briefcase, handbag, backpack, book, camera). They walk with swinging arms and legs, shift their weight, look round, smile when served and scowl when they give up
- **Sayed** in blocks in his lawn chair with his radio on a stool, sipping his tea; the **cat** asleep on FIFI's roof (breathing, ear twitches, tail flicks, lifting its head, blinking, yawning)
- **Prep station inside FIFI's trunk, in 3D.** The camera moves behind the car at hatch height; the real street and its traffic go on around it. The tail: lamp clusters with chrome bezels and ribbed lenses, the plate in its rubber frame, a round-edged chrome bumper wrapping the corners with a rubber strip and rounded overriders, a صلّي على النبي sticker and a little flag. The raised hatch from below: frame thickness, the glass with heater lines (the street shows through), the pressed inner panel with ribs and lightening holes, latch and striker, seal, hinges, gas struts, LED strip and a swag of fairy lights. Inside: a wooden counter across the sill (rubber mat, towel, spoons), the jars and tins (sugar tin with its spoon, tea, coffee, karkade, the tea-bag box, an ice bucket), a shelf on the seat back (tea-glass towers, cups, spare jars, the kettle, water bottles, plastic flowers), the jerrycan, a crate of lemons and mangoes, paper cups, a spare gas bottle, the power strip and its cables, a clip-on fan turning, hanging bulbs, a hand of Fatima and a blue-eye charm, a fringe of tassels along the roof edge. **Sayed's racks** on a rail across the top of the opening: the spare كنكة, ladle, milk pan and tongs; a proper **lemon squeezer** (two long yellow hinged handles round a perforated cup with its press dome), a tea strainer, the checked towel and a net of lemons; the **chalk menu board** mounted on the hatch. رتّب still lets you slide them
- **The kit, in 3D:** the gas cylinder with its valve and burner, a flickering blue flame, the hammered كنكة (steam, bubbles, the foam rising, boil-over with drips and smoke), lifted and tilted to pour a real stream into the glass; the tea glass on its gold-rimmed saucer building up sugar, leaves, water that darkens from the bottom as it steeps, the tea bag on its string with its tag, the teaspoon circling as you stir, ice cubes that splash in; the coffee فنجان with its foam; the blender with heat lights, glowing vents, blades, fruit chunks and a tall glass with a straw
- **The cards are gone: a quick bar and gestures.** A dock of ingredients along the bottom, always in the same order (سكر، شاي، فتلة، بن، كركديه، مانجا، تلج), only showing what today's menu uses so it never gives the recipe away; tap one (or its jar) to add it now, with a spoon swinging over from the jar. Sugar is tapped once per spoon (a count shows on the slot) and ends when you move on. On the kit itself: tap the كنكة to light the fire and again to take it off in the green; hold to pour gently; swipe down on the glass to dunk the bag; circle a finger round the glass to stir. Each recipe is a list of steps (bracketed ones in either order, like coffee and its sugar); doing something before its time counts as a mistake. After a pause (2.5 s on the first three days, 6 s after) Sayed hints: the right slot pulses and the thing to touch gets a ring, with a line saying what to do. His first-time tips walk through each kind of step
- **Frame budget (for the Galaxy A70):** the prep view went from ≈530 draw calls and ≈400k triangles a frame to ≈170 and ≈115k. The quick bar's icons (hundreds of little polygons) are painted once into a texture per order; the order tickets' drink icons are baked once and reused; the work bulb no longer casts shadows (that alone was ≈230k triangles); the paving slabs are just their tops. The street view sits at ≈145 draw calls. FIFI's pink LED glow switches off behind the camera in the prep view (it was washing the trunk pink after dark). The web build (iPhone) was coming out washed-out and lavender because its renderer ignored the blocks' colour space; it now matches the phone

**Lag, a plainer prep station, smoother shapes (1 Oct).**
- **Lag:** measured at the Galaxy A70's resolution, a frame now costs about a third of what it did (night street ≈451 → ≈135 ms, prep ≈780 → ≈237 ms on the test machine's software renderer). What was slow, and the fix: real-time lights (each one costs on every pixel it touches, and the road and pavements fill the screen) — the ground is now on its own render layer the streetlights and FIFI's bulb skip, the lamps' pools and FIFI's pink LED spill are painted on as glowing discs, the trunk has one work bulb, and in the prep view the street lamps' glow is folded into the ambient light; full-resolution 3D — now 75% (the UI stays sharp); shadows — a 2048 map, and none from the faint moon. The stove was also re-creating its bubble and steam particles every frame
- **Prep station simplified:** the صلّي على النبي sticker, the other stickers and flag, the hand of Fatima and blue-eye charm, the tassel fringe, the fairy lights and LED strips in the trunk, the clip-on fan, the shelf of glasses, cups, kettle, bottles and flowers, the floor storage (jerrycan, fruit crate, paper cups, spare gas, power strip and cables), the rag and spoons, the milk pan, tongs, towel and net of lemons are gone (the decorations come back as Phase B purchases). Left: the tail (lamps, plate, rounded bumper), the hatch and its struts, the counter with the kit and the jars, two work bulbs, the rail of kanakas and the ladle, the lemon squeezer and strainer (parked for B since 9 Oct), and the menu board
- **More polygons:** every round thing (kanakas, glasses, the gas cylinder, jars, wheels, poles, trees and bushes, the bumper's corners) gets 1.5× the sides, and lathed shapes are smooth-shaded so they read as round instead of faceted

**More hot drinks, two كنكة, better tyres, frame rate (3 Oct).**
- **No blender in FIFI:** her menu is hot drinks; the blender is only built when a juice order comes up at the later tiers, so in FIFI it costs nothing. The cold juices (mango) stay in the data as placeholders for those tiers (moved to `later/` on 9 Oct); the iced karkade and iced tea (brewed, then ice) stay
- **Five new hot drinks, four new ingredients (نعناع، لبن، ينسون، قرفة):** شاي بالنعناع (a mint sprig in the glass), شاي بلبن (milk boiled in the كنكة, then a tea bag dunked), ينسون and قرفة (boiled in the كنكة, sugar in the glass), قرفة باللبن (cinnamon boiled in milk). Each has its shouts, icon, jar on the counter, hint and Sayed's first-time tip. The quick bar wraps onto a second row past seven slots
- **Two كنكة:** the tea water and the milk boil in a plain polished steel kanaka (the dents are gone); Turkish coffee is made in a brass one modelled on Sayed's photo: a base ring, a belly narrowing to a waist and flaring to a rolled lip, a pinched spout, a silver bracket with rivets, a brass collar, a long black turned wooden handle with a ring at its end. The one not in use waits on the counter
- **Espresso machine** (the WAHSH tier upgrade) down from 3,000 to 1,200 EGP — about a week of good days rather than three
- **Tyres:** a black tyre with rounded shoulders flush with the body, a steel wheel and chrome hubcap, the sill and the taxi's checks stop at the arches, and the checks are big enough to stay checks at the street camera's distance
- **Frame rate:** lighting worked out per vertex instead of per pixel (on flat-shaded blocks it looks the same): about a third off the frame on the test machine at the A70's resolution. Detail traded away (people untouched): half the garden railing bars, fewer and simpler bushes and trees, shop goods in blocks, plain shutters, fewer shutter ribs, no moths, coarser painted lamp pools, fewer LED cubes on FIFI; flat ground casts no shadows and the shadows are hard. The scene went from ≈145k to ≈100k triangles
- **FPS readout for testing:** hold the day/clock/money line for a second to show or hide it

**Livelier people, the microbus's front (3 Oct).**
- **Customers stop staring at the camera:** they stand three-quarters on to the trunk and pass the wait doing something: checking their phone or watch, arms crossed, hands on hips, scratching their head, stretching, tapping a foot when they're getting impatient, or chatting with whoever's next to them (both turn to face each other, one gesturing). Their eyes wander: a passing car, the cat on the roof, the shops across the road, the garden, Sayed, the trunk. When a new customer orders the others glance over; when their drink is ready they look at the trunk and wave; served, they sip from the glass as they go
- **Sayed** in his chair sips his tea, nods along to the radio, fans himself with the towel, stretches, and glances at each new customer. Tap him and he raises his glass with a line (أهلاً يا باشا!، اشرب شاي ومتشيلش هم ...); tap the sleeping cat and it wakes up and looks round
- **Microbus front:** a flat upright face with a short bonnet like a real Toyota HiAce, the lamps flush with it, instead of the sloping wedge

**Prep station: the good lighting back, many more polygons (4 Oct)** — the first two items of Phase A.
- **Lighting:** per-pixel lighting is back on everything close to the camera (the kit, FIFI, people, cars), so the work bulb throws a warm pool over the counter and the kanakas and glass catch highlights. What it cost before was mostly the specular shine on every matte surface; matte things now skip it (metal and glass keep it), and the screen-filling road, pavements, garden, buildings and the hatch stay lit per vertex. Same frame cost on the street; the night prep view about +10–15% on the test machine, almost all from the extra polygons below
- **Polygons and shape in the trunk (≈55k → ≈85k triangles, same draw calls):** tail lamps with rolled chrome bezels and ribbed lenses; a rubber-framed plate with domed screws; the bumper wrapping the corners on real arcs, rounded overriders, tow ring and exhaust; chrome parts get a sky-and-street reflection baked into their colours; a counter of six rounded planks with grain, knots and nails, a steel edge and a ribbed mat; jars turned round with shoulders, labels and screw lids, an enamel sugar tin, a ribbed ice bucket with a wire handle; a torn-open tea-bag box; padded seat back and headliner, rubber seals; ceiling roses and pear bulbs; the hatch glass in a round seal, rolled flanges on its holes, a chrome striker and lock barrel; struts with ball joints; hanging kanakas that show their insides, S-hooks, rails with end knobs; the menu board with a rounded frame and chalk; the gas cylinder with foot ring, weld seam, wrap-round sticker, brass valve and red handwheel; a burner ring of flame holes; a heavy-footed tea glass with pressed panels, a saucer with a gold line, a rounder coffee cup and spoons
- Shadows behind FIFI only reach 14 m (they were drawing speckles on the roof edge and hatch)

**Where the old open items went.** The "Later" list after these batches and the "Remaining" lines of old Phases 1–2 are now in the phases: device/aspect-ratio checks and the exit playtest → A; cheap extra polish (baked AO, matcap, hiding the unseen street, MultiMesh + visibility ranges, CI budget job) → A; graphics setting → A (quality presets); prep-station decorations → B (purchases); more reactions → B; the menu growing over the first week → B; "ask to repeat" → B (regulars); day-start/day-end time-lapse → B (short bookends); GameAnalytics → B (PostHog + Sentry); Sayed's portrait redrawn from his 3D figure → B; shisha coal-rotation station → D; two or three glasses in parallel → D (two glasses at once); more hot drinks to consider → D; cat animations → D; blocky interiors for later venues + street variety per venue → D (WAHSH stand, street variety) / E (ahwa interiors) / G (juice shop); rounder people → E; recipe-memory idea → stays dropped.

---

## Art Style Guide (Locked — adjustable as we go)
- **Blocky 3D ("voxel" low-poly), from 30 Sep 2026:** the whole world is built from blocks in Godot 3D — street, FIFI, traffic, people, the cat, the prep station. Flat-shaded, colours in the vertices, merged into one mesh per object; rounded where it matters (bumpers, roofs, kanakas, glasses). The street is seen through an orthographic camera at the same 2:1 isometric angle and scale as the old 128×64 tiles; the prep station through a perspective camera behind FIFI's tail
- **Characters:** blocky, ~5 heads tall (3.5 cm per block unit), jointed at neck, shoulders and hips; faces with eyes, brows, nose, mouth that changes with mood. Rounder people (more polygons) in Phase E
- **Palette:** deep indigo/navy night base; warm amber/gold practicals (sodium lamps, LED strips, neon, coal); warm-neutral stone/pavement; period-appropriate FIFI/WAHSH body colours. (The roadmap page's own sand/terracotta/teal/gold is UI chrome only — the game world reads as a lit night street.)
- **Lighting:** warm key light from the sodium streetlights (~45° down-front) on the street and from FIFI's work bulb in the trunk, consistent across every tier; cool dim ambient night-sky fill for silhouette separation. Per-pixel near the camera, per-vertex on the big flat street (4 Oct)
- **Packs and signs:** generic only — no real brands, logos or copied pack designs
- **Detail budget:** new detail in the trunk arrives as Phase B purchases and is checked against the per-view budget from Phase A

---

## Vehicle Naming (Resolved)
**FIFI** — 127-styled silhouette, yellow, original name/logo. **WAHSH (الوحش)** — SUV tier, boxy-90s silhouette, no Jeep grille/Cherokee echo.

---

## Localization: English Toggle (Phase F)
Arabic-only until Phase F. Translation-key architecture built from the start (key → Arabic string in `ar_EG.csv`). English pass + Settings toggle built in Phase F.

---

## Tutorial System (Multi-Staged, Diegetic)
1. **Stage 1** (first launch, built): UI/controls walkthrough — welcome, day/clock/wallet, going home, tapping the trunk.
2. **Stage 2** (first order, built): reading the order, the quick bar, the stove's first use, the ice step, handing the first drink over, where the tips go.
3. **Stage 3+**: each new station gets its own first-use trigger — kit bought in the Phase B upgrade shop (e.g. the lemon squeezer; a first-time tip from Sayed), the shisha corner and the espresso machine (D), juice / the blender (E; the blender's first-use tutorial is parked in `later/`), and any other purchased station after that.

`tutorials_seen` dict in save data; TutorialManager autoload fires each sequence once. Structural hooks: built (old Phase 1). New-station triggers: Phase D (first with shisha).

---

## Distribution: itch.io First
No developer-account fees, no formal age-rating questionnaire, permissive content policy (shisha is a non-issue). **Phase C:** the FIFI slice on itch.io with Web + Android + Windows builds, uploaded by butler from CI (until then: the GitHub Pages web build and a tester APK). **Phase F:** the paid full version on itch.io; Mac/Linux exports if there is demand. Google Play internal testing ($25 one-time account) only if there are more than ~5 Android testers (C). Mobile stores (Google Play, Apple $99/yr, age-rating paperwork) = post-launch stretch goal (F).

## Telemetry: PostHog + Sentry (Decided 9 Oct 2026)
Switched from the GameAnalytics plan on 9 Oct 2026. **PostHog** over HTTP: events are posted from GDScript to PostHog's capture API (no native plugin needed, so the same code works on Web, Android and Windows), with an anonymous install id. Its funnels and retention answer the B exit (players finishing day 3) and the D exit (first-7-day retention after WAHSH); its surveys can serve as the C feedback button. **Sentry** (the sentry-godot SDK) catches crashes and script errors with device info on the Android and Windows builds. Integrated in Phase B. Event schema (unchanged): session_start, day_complete, order_served, order_failed, upgrade_purchased, cutscene_skipped. A short privacy policy is required before the public link in Phase C.

## Save System — Local + Source-Control Clarification
Local device saves, confirmed. **Note:** GitHub backs up source code, not player save games — those live on-device only. Cross-device cloud save is a separate system, out of scope for v1. Versioned save schema in technical-blueprint.md §4. The itch.io page says saves are local-only (Phase C).

## QA / Feedback Loop (Very Optional)
An optional feedback button from Phase C: a PostHog survey or a link to a short form. Nothing mandatory or blocking.

## Performance Budget
**Test phone: Samsung Galaxy A70** (Snapdragon 675 / Adreno 612) — the phone the game is actually tested on. **Target: 30+ fps in both views (street and prep) at the Med preset on the A70**; newer phones get more (higher frame rate, or the High preset). Graphics quality presets Low / Med / High, picked automatically on first launch (Phase A). Min OS: Android 10+ (API 29+).

**Per-view budget:** written in Phase A from on-device numbers. Until then, the last test-machine figures: street ≈145 draw calls and ≈100k triangles (3 Oct); prep ≈170 draw calls with ≈85k triangles in the trunk (4 Oct); 3D at 75% render scale with the UI at full resolution. From Phase A on, CI fails a PR that goes over the budget.

Replaced: the old floor (Galaxy A73 5G / A54 5G class, 60 fps on the flat stations, the isometric world flexing to 30 fps) — it was written for a 2D game and a phone nobody tests on.

## Business/Ownership
Project: **2ahwa Sim**. Effectively solo (you + AI assistance); friends' input is casual AI-assisted suggestions, not formal collaboration — no revenue-share paperwork needed unless that changes.

---

## Feature Ideas Backlog
Retention (regulars with memory → B; loyalty card, badges) · Atmosphere (animated prep-station sky: drifting clouds, twinkling stars, maybe the moon rising — decide after Phase C feedback; radio/ambient events → Sayed's radio in B's audio pass, original music in F; seasonal weather, khamaseen wind → G; a daily-changing street: pavement on either side of FIFI, then new spots each day with trees, street corners, cats/dogs → D street variety) · Cultural (café-history trivia notebook → F) · Economy (Ramadan iftar pricing → G; daily special; equipment wear: a blender pushed too hard can break and need a paid repair — only if Phase B's economy needs a second money sink; the free thermal cut-out is parked with the blender) · Sharing (shareable dawn-receipt image → C; photo mode later)

---

## Core Loop
Take Order → Prepare (quick bar + gestures on the kit: 🔥 كنكة on the gas ring, then the ice step for iced drinks; espresso from D, 🧊 blender from E) → Shisha (from D: coal timer, حجر refill) → Serve. Scoring: speed×accuracy → tips → upgrade shop (B) → WAHSH and beyond (D+).

## Day Bookend Sequence
1–2 sec time-lapse (Phase B): park → trunk open → ice box carried from FIFI's passenger seat to the pavement → shelves stocked (side/roof per upgrade; roof rack in D) → power on (LED strips light up) → gameplay; reversed at close. Tap to skip, with an auto-skip toggle. Day 1 deliberately bare; what the player buys in the B shop shows up in it.

---

## Realistic Pricing Reference
Source: Masrawy field report, 17 Sep 2026 (tea); shisha figures supplied directly. Rebalance after Phase B's playtests show how fast real prices make progression.

| Real tier | Real avg. tea | Our tier | Band |
|---|---|---|---|
| — | — | FIFI/WAHSH | 5–12 EGP |
| الشعبية | ~12.5 (6–15) | Street/busy baladi | 10–15→15–25 EGP |
| التراثية | ~32.5 | Historic café | 25–40 EGP |
| متوسطة→راقية→عالمية | 60→82.5→97.5 | Modern كافيه | 50–110 EGP |

Cold drinks ~1.5–2× tea baseline.

| Shisha | Session | حجر refill | Notes |
|---|---|---|---|
| Unflavoured (قص/سلوم) | 15–70 EGP | 5–30 EGP | ~every session; WAHSH tier+ (D) |
| Flavoured (معسل) | 50–250 EGP | 20–60 EGP | lasts 5–7 ولعات; street ahwa+ (E) |

---

## "Empire Mode" (Assessed, Not Committed)
Idle/incremental layer, an optional post-launch bolt-on in **Phase G** — prototype small first (e.g. one auto-managed side location while Sayed still runs the main one).

---

## Hot & Cold Menu
**FIFI now — 12 drinks, hot drinks plus iced versions made the same way** (brew on the كنكة, then add ice cubes from the ice bucket; no blending): شاي كشري, شاي فتلة, شاي على مية بيضا, قهوة تركي, كركديه سخن, شاي بالنعناع, شاي بلبن, ينسون, قرفة, قرفة باللبن, كركديه ساقع, شاي ساقع. Tea and coffee orders carry a sugar grade (tea: سادة/مظبوط/زيادة; عالريحة and مانو are for Turkish coffee only).
**Phase B:** the menu grows over days 1–7 (day 1 شاي كشري + فتلة); ليمون / ليمون بالنعناع once the lemon squeezer is bought.
**Hot:** شاي (full ladder) · قهوة تركي (سادة→سرياقوسي) · سحلب · كركديه/ينسون (dual) · حلبة · قرفة · زنجبيل · كاكاو · الحلبسة
**Cold (brewed + ice, any tier):** كركديه ساقع · شاي ساقع · ينسون ساقع · تمر هندي · عرقسوس · خروب · سوبيا (seasonal, G) · قمر الدين (seasonal, G)
**Fruit drinks (Phase D, WAHSH):** مانجو first (iced, not blended), then other fruit drinks made the same way. Fruit lives in Sayed's ice box (rides in FIFI's passenger seat, set on the pavement each day).
**Juices and cocktails (Phase E, with the blender + juicers; Phase G at the عصارة):** برتقال · جزر · جوافة · فراولة · بطيخ بالنعناع · موز بلبن · كوكتيل (layered fruit) · قصب (G). **Modern كافيه (G):** آيس لاتيه/موكا/كولد برو.

## Tools & Prep Station Expansion
- **Lemon squeezer + tea strainer** (Phase B, bought in the upgrade shop), hung on the **movable rack** — رتّب already lets the player slide the racks where they like them
- **More pots and tools:** bigger and double كنكة (B); a tea kettle, a سحلب pot, a milk pan, more strainers (with the drinks that need them, D onward); each with its own look on the rack
- **Juicers** (Phase E): orange juicer, carrot juicer and more, each a station slot with its own minigame; the sugar-cane press for the juice shop (G)

## Beverages Chain & Branches
All the places Sayed opens sit under one **beverages chain** (name TBD), each branch with its own menu focus:
- **FIFI / WAHSH / ahwas / cafés:** the main ladder (below), hot drinks first
- **عصارة (محل عصاير)** (Phase G): a juice shop like the ones selling قصب (sugar-cane) — mainly cold drinks, fresh juices and cocktails; cane press, juicers, blenders, fruit display
- **Soft-drinks factory** (Phase G, far future): the chain bottling its own drinks
- **Research rule:** when each new place is reached, do a fresh research pass on that kind of place (real menus, prices, equipment, décor, customers) before building it

---

## Progression Ladder
1. FIFI trunk stand (now; B–C) · 2. WAHSH stand (D) · 3. Street baladi ahwa (E) · 4. Busy baladi ahwa (E) · 5. Historic café (El-Fishawy) (G) · 6. Modern كافيه (G). Side branch: عصارة juice shop (G).

## Store Upgrades
| Category | FIFI now | FIFI, bought in Phase B | WAHSH (D) | Fixed venues (E, G) |
|---|---|---|---|---|
| Equipment | Gas burner; a steel and a brass coffee كنكة; the rail of spare kanakas + ladle; ice bucket (no blender: hot drinks only) | Lemon squeezer + strainer; bigger/double كنكة | Dual burner, espresso machine (1,200 EGP), two glasses at once | Bigger رملة and premium brass kanakas (E); blender (then an upgraded one) and juicers at the juice tiers (E); cane press at the عصارة (G) |
| Snacks | None | — | Chip + noodle rack (colour-coded, unbranded); roof-rack shelf | Full snack cooler |
| Décor | LED strips round the trunk and hatch; the chalk menu board | Stickers (incl. صلّي على النبي), hand of Fatima / blue-eye charm, tassel fringe, green tinsel trim, fairy lights, LED strips in the trunk, shelf of glasses/cups, floor storage | Neon signs + less-local, more modern décor, stools | Marble tables, wall photos, radio (E); mashrabiya (G) |
| Seating | Sayed's lawn chair only | Two monobloc plastic chairs round a woven-look plastic stool table on the pavement | More plastic chairs and stools | Full ahwa seating (E) |
| Shisha | None | — | Mini corner, unflavoured; FIFI can add a small shisha tray once shisha is in | Full corner + staff, flavoured from tier 3 (E) |
| Staff | Sayed only | — | Sayed only | نصبجي T3, تومباكشي T4 (E), waiters T5 (G) |

---

## Engine: Godot (over Three.js)
Built-in UI/save/audio, exports Android/iOS/Web/PC, ICU RTL text server, `canvas_items`+`expand` handles aspect ratio. The original TileMap+Y-sort reason no longer applies since the 30 Sep 3D rebuild (an orthographic camera and the depth buffer do that job); everything else still holds.

## Design References
Bartender: The Right Mix · Cook, Serve, Delicious! · Papa's Freezeria · Diner Dash · Good Pizza, Great Pizza · Overcooked (staff role split; co-op itself is cut) · Coffee Talk/VA-11 Hall-A (for the light story told through the regulars)

---

## Risk Register
| Risk | Severity | Mitigation | Phase |
|---|---|---|---|
| Shisha content policy | LOW (itch.io)/HIGH (mobile later) | Stylized toggle; formal disclosure only if mobile pursued | 0; D (shisha arrives); revisit if mobile (F) |
| RTL Arabic UI breaks in text renderer | HIGH | Test ICU text server + font on device | A, final pass F |
| Frame rate on the A70 slips as content lands | MEDIUM | Written per-view budget, quality presets, CI budget check on PRs | A, then every phase |
| Real Umm Kulthum/Fairuz music without license | HIGH | Original compositions instead | F |
| Vehicle naming/trade-dress | RESOLVED | FIFI+WAHSH locked, original names; final art check before the public link | 0, C |
| Isometric↔prep camera move fragile | LOW (built 30 Sep) | Check on device with the rest of the A pass | A |
| Aspect-ratio/device fragmentation | MEDIUM | Stretch-mode+safe-rect; test matrix every phase | A–F |
| Slang confuses players | MEDIUM | Menu board, Sayed's hints, regulars and "the usual" (covers "ask to repeat"); a visual "recipe book" if testers still struggle | B |
| Early-game churn | MEDIUM | PostHog day-3 funnel (B), first-7-day retention after WAHSH (D) | B, D |
| Seasonal cold-menu items | LOW | Gate as limited-time | G |
| Unattributed quotes | LOW | Verified lines only | F |
| Time-lapse tedium | LOW | 1–2 s, tap/auto-skip | B |
| GitHub repo ≠ player cloud save (player confusion) | LOW | Clarify saves are local-only for v1 | C |

---

## Companion Documents
`technical-blueprint.md` — folder structure, schemas, state machines, save system, telemetry, fonts
`production-checklist.md` — art style guide, onboarding, QA loop, store/legal readiness, performance budget

## Live Artifact
https://claude.ai/artifact/NtcwuP77SRERwZJrs6BeEo
