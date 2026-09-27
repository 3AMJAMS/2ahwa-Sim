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
boil one شاي كشري in the كنكة and pour it → tips paid → fade back to the street.

## Running Phase 1
Open the folder in Godot 4.3+ and press Play (`scenes/main.tscn`).
- **Tap FIFI's glowing trunk** (or press Space/Enter on desktop) to start an order.
- **Tap the stove** when the foam (الوش) rises over the كنكة's rim and the side bar turns green (65–85%):
  Sayed takes it off the fire and pours it into the glass. A perfect brew pays full tips; outside the
  green pays half; leaving it on until the bar tops out boils it over and burns the tea.
- Progress (money, day) is saved to `user://save.tres` on day end, on purchase, and when the app is paused/closed.

### Project layout
| Path | What |
|---|---|
| `scripts/main.gd` | WORLD ↔ PREP state machine + fades |
| `scripts/stations/heat_gauge.gd` | Hot brew timing + scoring (tap in the green zone) |
| `scripts/stations/kanaka_stove.gd` | Stove art: gas ring, كنكة, boiling/foam, pour and boil-over animations |
| `scripts/stations/blend_gauge.gd` | Cold blender gauge (hold to boost, don't overheat) — hidden until Phase 2 |
| `scripts/stations/prep_station.gd` | Shows the order, routes it to a gauge, pays tips |
| `scripts/world/` | Isometric street + placeholder FIFI (procedural Fiat 127-style hatchback, swap for art later) |
| `scripts/autoload/` | `GameData` (JSON content), `SaveSystem`, `Economy` |
| `data/*.json` | Menu, equipment/upgrades, venue tiers — edit these, not scripts, to tune |
| `localization/ar_EG.csv` | All UI strings as translation keys |
| `assets/fonts/` | Cairo (OFL) — Arabic + Latin subsets |

## Live roadmap
https://claude.ai/artifact/NtcwuP77SRERwZJrs6BeEo
