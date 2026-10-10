# Production Checklist — Status

Companion to `roadmap.md` (v6, phases A–G) and `technical-blueprint.md`. Most items below are
resolved; kept here as a single reference so nothing gets re-litigated by accident.

Old phase numbers map to the new letters as follows: old Phase 1 → done / A · old Phase 2 → done / B
(telemetry now PostHog) · old Phase 3 → B (upgrade shop) and D (personas, WAHSH gate, shisha,
new-station triggers) · old Phase 4 → E (Rush Hour) and F · old Phase 5 → C (itch.io page) and F
(paid launch) · old Phase 6 → F and G. See roadmap.md's "Plan at a glance".

---

## 1. Art & Visual Style Guide — LOCKED
See roadmap.md's "Art Style Guide" section: blocky 3D ("voxel" low-poly) since the 30 Sep 2026
rebuild — flat-shaded, colours in the vertices, one mesh per object, rounded where it matters. The
street keeps the old 2:1 isometric angle and scale through an orthographic camera; the prep station
is a perspective view inside FIFI's trunk. Characters are blocky, ~5 heads tall. Night-street palette
(indigo base + warm amber practicals). Warm key light from the sodium streetlights on the street and
from FIFI's work bulb in the trunk; per-pixel lighting near the camera, per-vertex on the big flat
street. Generic packs and signs only, no real brands. Adjustable as we go, but no longer an open gap.

## 2. Onboarding / Tutorial — STAGES 1–2 BUILT
Multi-staged, diegetic (no popup walls, since the UI is Arabic-only): Sayed talks the player through
it in a speech bubble, with a spotlight and a pointing hand.
1. First launch → UI/controls walkthrough (built)
2. First order → guided first drink: the quick bar, the stove, the ice step, the first hand-over (built)
3. Same pattern for each new station — kit bought in the Phase B upgrade shop (e.g. the lemon
   squeezer), the shisha corner and espresso machine (D), juice / the blender (E; its first-use
   tutorial is parked in `later/`) — each fires its own first-use trigger

See `technical-blueprint.md` §8 for the state machine and save-data structure
(`tutorials_seen` dict + `TutorialManager` autoload). Structural hooks: built.
New-station triggers: Phase D.

## 3. Save System — CONFIRMED (local only)
Local device saves only for v1 — confirmed, not an oversight. **Worth remembering:**
the GitHub repo backs up and version-controls the game's *source code*; it is a
completely separate system from *player save games*, which live only on each
player's own device. If cross-device save sync ever becomes a priority, that's a
distinct feature to design later — the repo doesn't already provide it.

## 4. Telemetry / Analytics — DECIDED (PostHog + Sentry)
Switched from the GameAnalytics plan on 9 Oct 2026. **PostHog** over HTTP (events posted from
GDScript, so the same code works on Web, Android and Windows) for funnels and retention;
**Sentry** (sentry-godot) for crash reporting. Integrated in Phase B (the day-3 funnel is part of
B's exit). Event schema in `technical-blueprint.md` §5 (unchanged: session_start, day_complete,
order_served, order_failed, upgrade_purchased, cutscene_skipped). A privacy policy is required
before the public link in Phase C — see §6 below.

## 5. QA / Playtest Feedback Loop — KEPT DELIBERATELY LIGHT
An optional feedback button from Phase C: a PostHog survey or a link to a short form. Nothing
mandatory, nothing blocking any phase's exit benchmark. Revisit a more structured loop later only
if it turns out to be genuinely useful.

## 6. Distribution & Legal Readiness — itch.io FIRST (lightened)
Launch platform: **itch.io**. The FIFI slice goes public in **Phase C** (Web + Android + Windows,
uploaded by butler from CI); the paid full version in **Phase F**. This keeps what used to be a
heavy Phase 5 compliance list small:
- No developer-account fee, no formal age-rating questionnaire, permissive content
  policy — the shisha content is a non-issue on itch.io specifically.
- **Needed before the Phase C link goes public:** a privacy policy, since PostHog and Sentry are
  active (see §4) — short and honest; the local-save wording on the page (§3); a final check that
  FIFI and WAHSH read as original designs.
- **Phase C, only if needed:** Google Play internal testing ($25 one-time account) if there are
  more than ~5 Android testers.
- **Deferred, not required for v1 (Phase F stretch):** Google Play / Apple ($99/yr) store releases
  and their formal age-rating paperwork — only relevant if/when mobile-store distribution is
  pursued. Expect the shisha content (from Phase D) to push any future mobile rating up a tier
  regardless of styling.

## 7. Performance Budget — SET (written per view in Phase A)
Test phone: **Samsung Galaxy A70** (Snapdragon 675 / Adreno 612) — the phone the game is
actually tested on.
- **30+ fps in both views (street and prep) at the Med preset on the A70**; newer phones get more.
- Graphics quality presets Low / Med / High, picked automatically on first launch (Phase A).
- A per-view budget (draw calls + triangles for the street and the prep view) written in Phase A
  from on-device profiling, and checked by CI on every PR from then on.
- Minimum OS target: roughly Android 10+ (API 29+).

(Replaces the old floor of a Galaxy A73/A54-class phone with 60 fps on flat station minigames,
which was written for the 2D game.)

## 8. Business/Ownership — CONFIRMED (effectively solo)
Project: **2ahwa Sim**. You + AI assistance is the real team; friends' contributions
are casual AI-assisted suggestions, not formal collaboration — no revenue-share or
credit paperwork needed unless that changes down the line.

---

## Still-Open (genuinely, not just unconfirmed)
- [ ] Per-view performance budget written from on-device numbers on the A70 (Phase A)
- [ ] Privacy-policy draft, once PostHog + Sentry are wired up (Phase B; needed before Phase C)
- [ ] Final in-game/store-page wording clarifying saves are local-only for v1 (Phase C)
- [ ] Sanity-check the supplied shisha pricing bands against a real local price-check (before Phase D balancing)
