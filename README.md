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
make the order (شاي كشري, قهوة تركي or كركديه on the stove; كركديه ساقع in the blender) →
tips paid → fade back to the street. The first order is always شاي كشري, then orders rotate at random.

## Running Phase 1
Open the folder in Godot 4.3+ and press Play (`scenes/main.tscn`).
- **Tap FIFI's glowing trunk** (or press Space/Enter on desktop) to start an order.
- **Hot orders — tap the stove** when the foam (الوش) rises over the كنكة's rim and the side bar turns green (65–85%):
  Sayed takes it off the fire and pours it into the glass. A perfect brew pays full tips; outside the
  green pays half; leaving it on until the bar tops out boils it over and burns the tea.
- **Cold orders — the blender runs by itself.** Press and hold (or hold Space) for turbo: it finishes faster
  and pays more, but heats the motor. Let go when the lights and the thin bar turn red — stay in the red
  too long and the thermal cut-out trips: the motor stops until it cools, so the drink comes out later
  and tips drop.
- Progress (money, day) is saved to `user://save.tres` on day end, on purchase, and when the app is paused/closed.

### Project layout
| Path | What |
|---|---|
| `scripts/main.gd` | WORLD ↔ PREP state machine + fades |
| `scripts/stations/heat_gauge.gd` | Hot brew timing + scoring (tap in the green zone) |
| `scripts/stations/kanaka_stove.gd` | Stove art: gas ring, كنكة, boiling/foam, pour into a glass or فنجان, boil-over |
| `scripts/stations/blend_gauge.gd` | Cold blender timing + scoring (hold for turbo, don't overheat the motor) |
| `scripts/stations/blender_view.gd` | Blender art: chunks blending down, vortex, motor lights/smoke, pour, cut-out |
| `scripts/stations/trunk_backdrop.gd` | The prep screen's car: raised hatch, trunk interior, rear panel, lamps, plate, bumper |
| `scripts/stations/station_art.gd` | Shared drawing kit for the station art (scene scaling, counter, glows, particles) |
| `scripts/stations/prep_station.gd` | Shows the order, routes it to a gauge, pays tips |
| `scripts/world/` | Isometric street + placeholder FIFI (procedural yellow Fiat 127-style hatchback, hatch up with the kit in the trunk; swap for art later) |
| `scripts/autoload/` | `GameData` (JSON content), `SaveSystem`, `Economy` |
| `data/*.json` | Menu (incl. each drink's colours under `look`), equipment/upgrades, venue tiers — edit these, not scripts, to tune |
| `localization/ar_EG.csv` | All UI strings as translation keys |
| `assets/fonts/` | Cairo (OFL) — Arabic + Latin subsets |

## Live roadmap
https://claude.ai/artifact/NtcwuP77SRERwZJrs6BeEo
