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

Phase 1 (Core Minigame) — in progress. Playable loop: tap FIFI's trunk → fade to the flat prep station →
pick the ingredients from the tray → pick the tool (the كنكة on the fire or the blender) → make the order
(شاي كشري, قهوة تركي, كركديه; the iced ones — كركديه ساقع, شاي ساقع — are brewed then get ice cubes) →
fade back to the street and hand it over. FIFI's menu is hot drinks only for now; fruit drinks come at higher tiers.
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
- **Pick what goes in it** from the tray at the bottom — شاي, بن, كركديه — then **pick the tool** (الكنكة).
  Iced drinks then ask for ice: **tap the ice card once per cube** and watch them drop into the glass. Each wrong pick shakes
  the car and takes 20% off the tip (down to half).
- **Sayed's tutorial** runs on a new save: he walks you round the street, through your first order, and
  explains the stove and the blender the first time you use each. "تخطّي الشرح" turns it off for that save.
- **Sugar by the spoon.** Every tea and coffee order comes with a sugar grade (on the ticket and in the shout):
  tea is سادة / مظبوط / زيادة (0 / 2 / 3 spoons; على مية بيضا packs the same spoons into a thicker layer); Turkish coffee also has عالريحة and مانو, and each tap is half a
  spoon (سادة 0, عالريحة ½, مظبوط 1, مانو 1½, زيادة 2). Tap the sugar once per spoon, then خلاص; each spoon off
  the order takes a quarter off the drink's quality. The first three days the tray spells out the spoons.
- **Tea is built in the glass**, the Egyptian way:
  - **شاي كشري:** sugar first, then the loose tea on top, then boil water in the كنكة and pour it over (it darkens
    from the leaves up), then **stir** (tap قلّب four times) until the sugar's gone and it's one colour.
  - **شاي فتلة:** sugar, boiling water, then **dunk the tea bag** three times (the colour clouds down from it), stir.
  - **شاي على مية بيضا:** tea at the bottom under a thick layer of sugar; boil the water, then **hold to pour it
    down the side of the glass** — holding speeds the flow up, and if the meter hits red the stream punches
    through the sugar and the tea darkens at once (quality docked). Poured gently the water stays clear over the
    sugar; stirring darkens it gradually.
  - **قهوة تركي:** the sugar goes into the كنكة with the coffee before it goes on the fire.
- **Hot orders — tap the stove** when the foam (الوش) rises over the كنكة's rim and the side bar turns green (65–85%):
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
- **Sayed's racks are movable.** Tap **رتّب** in the prep station's corner, drag the rail of kanakas, the lemon-squeezer
  rack or the chalk menu board wherever you like, then خلاص. Positions are kept in the save.
- Progress (money, day) is saved to `user://save.tres` on day end, on purchase, and when the app is paused/closed.

### Visual effects
The project uses Godot's built-in effects, so run it with the **Mobile** (or Forward+) renderer to see them:
HDR 2D + glow (`rendering/viewport/hdr_2d`, `WorldEnvironment` in `scenes/main.tscn`), `PointLight2D` streetlights,
`CPUParticles2D` moths/dust, and shaders in `shaders/` (heat haze over the stove, screen vignette).
Anything that should glow is drawn with a colour brighter than white (`StationArt.hdr()`).
Haptics use `Input.vibrate_handheld()`: add the **VIBRATE** permission when you set up the Android export preset.

### Project layout
| Path | What |
|---|---|
| `scripts/main.gd` | WORLD ↔ PREP state machine + fades |
| `scripts/stations/heat_gauge.gd` | Hot brew timing + scoring (tap in the green zone) |
| `scripts/stations/kanaka_stove.gd` | Stove art: gas ring, كنكة, boiling/foam, pour into a glass or فنجان, boil-over; tea built in the glass (sugar layer, leaves, tea bag, colour steeping from bottom to top, stirring, the held side-pour and its flow meter) |
| `scripts/stations/blend_gauge.gd` | Cold blender timing + scoring (hold for turbo, don't overheat the motor) |
| `scripts/stations/blender_view.gd` | Blender art: chunks blending down, vortex, motor lights/smoke, pour, cut-out |
| `scripts/stations/trunk_backdrop.gd` | The prep screen's car (laid out at a fixed 1080×1440 and scaled to fit, so it looks the same on every screen), seen from behind at hatch height looking down into the trunk: body wider at the bumper tapering to the roof (the street shows round it), hatch overhead with its edge thickness, roof edge and wall thickness round the opening, trunk interior + supply rack, water jerrycan, power strip and cables, rubber mat, light pools and shadows for depth, LED strips, lamp clusters standing proud, plate, thick chrome bumper, road below |
| `scripts/stations/tool_racks.gd` | Movable racks over the trunk: a rail of hanging kanakas (three sizes), ladle, milk pan and tongs; the lemon squeezer, tea strainer and towel; the chalk menu board with today's prices; the arrange mode |
| `scripts/stations/sky_art.gd` | The prep station's static sky: clouds rolled per day, sun on its arc, stars, the moon in its phase for the game day |
| `scripts/stations/side_scenery.gd` | The street around the prep panel on wider/taller screens (buildings, road, painted kerb, pavement, streetlights) |
| `scripts/world/traffic.gd`, `street_vehicle.gd` | Passing traffic at FIFI's scale (taxis, saloons, microbuses, pickups, tuk-tuks, scooters) that keeps its distance in lane |
| `scripts/world/customer.gd`, `customer_queue.gd` | Customers: drive-bys (pull in behind or beside FIFI, window down, order, drive off) and walkers (animated walk cycle), shouting the order, patience, served/angry exits |
| `scripts/ui/ticket_rail.gd` | Order tickets along the top of the street view |
| `scripts/world/sidewalk_furniture.gd` | Sayed's folding lawn chair, his tea and his radio on the pavement (customer seating comes later as an upgrade) |
| `scripts/world/figure_art.gd` | Builds the street's people (customers and Sayed): ~5 heads tall, jaw, ears, eyes, varied hair, glasses, beards, collars, buttons, cuffs, hands, shoes; the limbs separate so they can swing |
| `scripts/world/sayed_figure.gd` | Sayed in his chair between orders: breathing, sipping his tea |
| `scripts/world/street_cat.gd` | The ginger-and-white street cat asleep on FIFI's roof: breathing, ear twitches, tail flicks, lifting its head to look round, blinking and yawning |
| `scripts/stations/station_art.gd` | Shared drawing kit for the station art (scene scaling, counter, glows, particles) |
| `scripts/stations/prep_station.gd` | Runs an order: ingredients → tool → gauge, pays tips (docked for wrong picks), tutorial hooks |
| `scripts/stations/prep_picker.gd`, `pick_card.gd`, `prep_icons.gd` | The pick tray, its cards, and their procedural icons (ingredients and tools) |
| `scripts/autoload/tutorial.gd`, `scripts/ui/` | Sayed's tutorial: plays each walkthrough once (`tutorials_seen` in the save); coach overlay with spotlight shader, speech bubble, portrait and pointing hand |
| `scripts/world/` | Isometric street (four-lane road, painted kerbs, pavements, Cairo streetlights) + placeholder FIFI (procedural yellow Fiat 127-style hatchback, hatch up with the kit in the trunk, LED strips, fruit ice box on the pavement; swap for art later) |
| `scripts/autoload/` | `GameData` (JSON content), `SaveSystem`, `Economy`, `DayClock` (time of day, sky and lighting), `Tutorial` |
| `data/*.json` | Menu (each drink's `ingredients` and its colours under `look`), pickable ingredients/tools (`prep_items.json`), equipment/upgrades, venue tiers — edit these, not scripts, to tune |
| `localization/ar_EG.csv` | All UI strings as translation keys |
| `assets/fonts/` | Cairo (OFL) — Arabic + Latin subsets |

## Live roadmap
https://claude.ai/artifact/NtcwuP77SRERwZJrs6BeEo
