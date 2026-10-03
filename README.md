# 2ahwa Sim (قهوجي)

An Egyptian-Arabic ahwa/bartending-style game. You play as **سيد (Sayed)**, starting out of the trunk of his hatchback **FIFI**, upgrading to the **WAHSH** SUV stand, and working his way up to running a full ahwa.

- **Engine:** Godot 4.x
- **Language:** Egyptian Ammiya Arabic (RTL) at launch; English toggle added in Phase 6
- **Launch platform:** itch.io first; mobile app stores as a later stretch goal
- **Telemetry:** GameAnalytics SDK
- **Design bible:** see `roadmap.md` (production plan — phases, menu, economy, benchmarks)
- **Implementation reference:** see `technical-blueprint.md` (folder structure, data schemas, state machines, save system, telemetry, fonts)
- **Production status:** see `production-checklist.md` (art style guide, onboarding, QA loop, store/legal readiness, performance budget)

## Status
Phase 0 (Foundation) — premise, art style, engine, vehicle names (FIFI + WAHSH), and launch platform locked.

Phase 1 (Core Minigame) — in progress. Playable loop: tap FIFI's trunk → the camera moves behind her into the
trunk → make the order with the quick bar of ingredients and gestures on the kit (شاي كشري، فتلة، على مية بيضا،
شاي بالنعناع، شاي بلبن، قهوة تركي، كركديه، ينسون، قرفة، قرفة باللبن; the iced ones — كركديه ساقع, شاي ساقع — are
brewed then get ice cubes) → back to the street to hand it over. Everything is blocky 3D (voxel-style low-poly) built
in code. FIFI's menu is hot drinks only (there's no blender in her trunk); the fruit juices stay in the data as
placeholders for the later tiers.
The first order is always شاي كشري, then orders rotate at random.

Phase 2 (Station Loop) — in progress: customers, order tickets, patience, serving and tips on the street.
First launch plays Sayed's tutorial (street, first order, each tool the first time it's used).

## Play it
- **Web / iPhone:** https://3amjams.github.io/2ahwa-Sim/ (built and published by `.github/workflows/web.yml` on every
  merge to `main`; one-time setup: repo Settings → Pages → Source: **GitHub Actions**). On iPhone open it in Safari,
  then Share → **Add to Home Screen**: it installs like an app, full screen, with its own icon. (A native iOS app
  needs a Mac with Xcode and a paid Apple developer account, so the web app is the iOS route for now.)
- **Android:** install the APK (export preset "Android", arm64).

## Running Phase 1
Open the folder in Godot 4.3+ and press Play (`scenes/main.tscn`).
- **Customers pull up to FIFI**, parked in the slow lane (البطيء): most drive up, stop behind her or beside the
  trunk, wind the window down and order; the rest walk up the pavement. Each shouts their order; it's clipped to a ticket at the top of the screen with a
  patience bar. **Tap the trunk** (makes whoever is most impatient), the ticket, or the customer to make an order;
  once it's made, **tap the customer to serve it** (the cup goes in through the car window, then they drive off). Tips are paid on serving and shrink the longer they waited;
  customers who run out of patience walk off. Space/Enter opens the trunk on desktop.
- **Make it with the quick bar and your fingers.** Along the bottom is a dock of ingredients, always in the
  same order (سكر، شاي، فتلة، بن، كركديه، نعناع، لبن، ينسون، قرفة، تلج — only what today's menu uses; more than
  seven wrap onto a second row). Tap one (or its jar on the counter) to add it now. On the kit: **tap the كنكة** to
  light the fire and again to take it off; **hold** to pour gently; **swipe down on the glass** to dunk a tea bag;
  **circle round the glass** to stir; at the juice tiers, **tap the blender** to start it. Do the drink's steps in order (in `menu_items.json`); doing something before its time shakes the view and
  takes 20% off the tip (down to half). Wait a moment and Sayed hints at what's next.
- **Sayed's tutorial** runs on a new save: he walks you round the street, through your first order, and
  explains the stove, each new kind of step (mint, milk…) and, at the juice tiers, the blender the first time. "تخطّي الشرح" turns it off for that save.
- **Sugar by the spoon.** Every tea and coffee order comes with a sugar grade (on the ticket and in the shout):
  tea is سادة / مظبوط / زيادة (0 / 2 / 3 spoons; على مية بيضا packs the same spoons into a thicker layer); Turkish coffee also has عالريحة and مانو, and each tap is half a
  spoon (سادة 0, عالريحة ½, مظبوط 1, مانو 1½, زيادة 2). Tap the sugar once per spoon (the count shows on the slot),
  then carry on with the next thing; each spoon off the order takes a quarter off the drink's quality.
- **Tea is built in the glass**, the Egyptian way:
  - **شاي كشري:** sugar first, then the loose tea on top, then boil water in the كنكة and pour it over (it darkens
    from the leaves up), then **stir** (four circles round the glass) until the sugar's gone and it's one colour.
  - **شاي فتلة:** sugar, boiling water, then **dunk the tea bag** three times (the colour clouds down from it), stir.
  - **شاي على مية بيضا:** tea at the bottom under a thick layer of sugar; boil the water, then **hold to pour it
    down the side of the glass** — holding speeds the flow up, and if the meter hits red the stream punches
    through the sugar and the tea darkens at once (quality docked). Poured gently the water stays clear over the
    sugar; stirring darkens it gradually.
  - **شاي بالنعناع:** like كشري, with a sprig of mint into the glass before the water.
  - **شاي بلبن:** milk boils in the كنكة instead of water (it rises fast); pour it, dunk a tea bag, stir.
- **Brewed in the كنكة:** **قهوة تركي** (the coffee and its sugar go in before it goes on the fire, in the brass
  coffee كنكة), **كركديه**, **ينسون** and **قرفة** (sugar in the glass first), **قرفة باللبن** (cinnamon boiled in
  milk). Tea water and milk boil in the plain steel kanaka; the other one waits on the counter.
- **Hot orders — tap the كنكة** when the foam (الوش) rises over its rim and the side bar turns green (65–85%):
  Sayed takes it off the fire and pours it into the glass. A perfect brew pays full tips; outside the
  green pays half; leaving it on until the bar tops out boils it over and burns the tea.
- **Blended orders (later tiers) — the blender runs by itself.** Press and hold (or hold Space) for turbo: it finishes faster
  and pays more, but heats the motor. Let go when the lights and the thin bar turn red — stay in the red
  too long and the thermal cut-out trips: the motor stops until it cools, so the drink comes out later
  and tips drop.
- **A shift is 15 minutes.** The clock starts at 4 pm and runs through sunset (about 4 minutes in) and night
  (the sodium streetlights and LED strips come on) to 4 am, when Sayed packs up by himself (an order being made is
  handed over first). Tap **روّح** to go home earlier. Either way you see the day's takings, the day number goes up
  and the next day starts at 4 pm. The day ends on a dawn screen with Sayed's receipt for the day (orders
  served, customers lost, the takings, a "خالص" stamp) and a **يوم جديد** button.
- **Sayed's racks are movable.** Tap **رتّب** in the prep station's corner, slide the rail of kanakas or the lemon-squeezer
  rack across the top of the opening, or the chalk menu board over the hatch, then خلاص. Positions are kept in the save.
- Progress (money, day) is saved to `user://save.tres` on day end, on purchase, and when the app is paused/closed.

### Visual style and effects
The world is **blocky 3D**, built in code: `scripts/vox/vox.gd` bakes boxes, extruded profiles, lathed round things
(kanakas, glasses, wheels) and swept tubes into one vertex-coloured mesh per object, so a whole car or building is a
handful of draw calls. Flat faces are flat-shaded; round things get extra sides (`Vox.DETAIL`) and smooth shading so
they read as round. Lamps, lit windows, LEDs and flames use unshaded "glow" materials whose
brightness is set per group (`Vox.set_glow`), so they bloom through the `WorldEnvironment` glow. Lighting is real:
`DayLight3D` moves a sun/moon through the day (hard shadows by day; the faint moonlight casts none). To keep the frame
light on mid-range phones: lighting is worked out per vertex, not per pixel (`force_vertex_shading`: on flat-shaded
blocks it looks the same and costs far less); the 3D renders at 75% resolution (the 2D UI stays sharp); flat ground
casts no shadows; a real light costs something on every
pixel it touches, so the road, pavements, garden and buildings sit on their own render layer that the streetlights and
FIFI's bulb skip, and the lamps' pools and FIFI's pink LED spill are painted onto the ground as glowing discs; in the
prep view one work bulb lights the trunk and the street lamps' glow is folded into the ambient light; busy 2D drawings
(the quick bar, the ticket icons) are painted once into textures instead of redrawn from polygons each frame. **Testing
FPS on a phone:** press and hold the day/clock/money line for a second to show or hide a frame-rate readout. Haptics use `Input.vibrate_handheld()` (add the **VIBRATE** permission in the Android preset).

### Project layout
| Path | What |
|---|---|
| `scripts/main.gd` | Street ↔ prep state machine, fades, serving (the cup flies to the hand or car window), tips |
| `scripts/vox/vox.gd` | The block-mesh builder: boxes, rounded boxes, extrusions, lathes, rods, balls, sweeps; materials (solid, glass, glow groups) |
| `scripts/vox/vox_person.gd` | Blocky people: the look generator (skin tones, builds, outfits, hair, headwear, faces, things they carry), jointed parts, walk/idle/raise-arm, moods; Sayed's look |
| `scripts/world/world_host.gd` | The street view: iso camera, overlay (labels, bubbles), taps by ray, entering/leaving the prep view |
| `scripts/world/street3d.gd` | Road, kerbs, pavements, garden, shops and flats, streetlights with light pools, street furniture |
| `scripts/world/day_light3d.gd` | Sun, moon, sky and ambient light through the day |
| `scripts/world/fifi3d.gd` | FIFI: the Fiat 127, her trunk kit, hatch, LED strips, bulbs, ice box, the tap glow |
| `scripts/world/street_vehicle.gd`, `traffic.gd` | Blocky traffic (six kinds, drivers behind tinted glass, winding windows) and its lane logic |
| `scripts/world/customer.gd`, `customer_queue.gd` | Customers on foot or by car: arrival, order bubble, patience bar, served/angry exits |
| `scripts/world/sidewalk_furniture.gd`, `sayed_figure.gd`, `street_cat.gd` | Sayed's chair and radio, Sayed sipping his tea, the cat on FIFI's roof |
| `scripts/stations/prep_rig.gd` | FIFI's tail and trunk up close: bumper, lamps, plate, the hatch from below, counter, jars, work bulbs, racks, the prep camera (decorations come later) |
| `scripts/stations/stove3d.gd` | The gas cylinder, flame and the two كنكة (steel for water and milk, brass with a wooden handle for coffee; boiling, foam, pour stream, boil-over), the tea glass or فنجان and everything built in it (sugar, leaves, the bag, mint) |
| `scripts/stations/blender3d.gd` | The blender for the juice tiers (heat lights, vents, blades, fruit) and the tall glass it pours into; not built in FIFI |
| `scripts/ui/fps_meter.gd` | The frame-rate readout for testing (hold the money line) |
| `scripts/stations/prep_station.gd` | The prep layer: the order, readouts, the quick bar, gestures, the recipe step engine, hints, Sayed's tips, scoring |
| `scripts/stations/quick_bar.gd`, `prep_icons.gd` | The ingredient dock and its procedural icons |
| `scripts/stations/heat_gauge.gd`, `blend_gauge.gd` | Brew timing and scoring (tap in the green; hold for turbo without tripping the motor) |
| `scripts/ui/` | Ticket rail, Sayed's tutorial overlay (spotlight, speech bubble, portrait, pointing hand), the dawn day receipt |
| `scripts/autoload/` | `GameData` (JSON content), `SaveSystem`, `Economy`, `DayClock` (time of day), `Tutorial` |
| `data/*.json` | Menu (each drink's `steps` and colours under `look`), ingredients, equipment/upgrades, venue tiers — edit these, not scripts, to tune |
| `localization/ar_EG.csv` | All UI strings as translation keys |
| `assets/fonts/` | Cairo (OFL) — Arabic + Latin subsets |

## Live roadmap
https://claude.ai/artifact/NtcwuP77SRERwZJrs6BeEo
