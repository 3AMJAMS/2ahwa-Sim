# Production Checklist — Status

Companion to `roadmap.md` and `technical-blueprint.md`. Most items below are now
resolved; kept here as a single reference so nothing gets re-litigated by accident.

---

## 1. Art & Visual Style Guide — LOCKED
See roadmap.md's "Art Style Guide" section: 128×64px isometric tile, ~4-heads-tall
character proportions, night-street palette (indigo base + warm amber practicals),
single warm key light from the string-light canopy. Adjustable as real sprites land,
but this is the starting reference — no longer an open gap.

## 2. Onboarding / Tutorial — DESIGNED
Multi-staged, diegetic (no popup walls, since the UI is Arabic-only):
1. First launch → brief UI/controls walkthrough
2. First tap on the brewing area → guided first drink, using the existing highlighted-ticket approach
3. Same pattern for the shisha station, cold station, and any newly-purchased station — each fires its own first-use trigger

See `technical-blueprint.md` §8 for the state machine and save-data structure
(`tutorials_seen` dict + `TutorialManager` autoload). Structural hooks: Phase 1.
New-station triggers: Phase 3.

## 3. Save System — CONFIRMED (local only)
Local device saves only for v1 — confirmed, not an oversight. **Worth remembering:**
the GitHub repo backs up and version-controls the game's *source code*; it is a
completely separate system from *player save games*, which live only on each
player's own device. If cross-device save sync ever becomes a priority, that's a
distinct feature to design later — the repo doesn't already provide it.

## 4. Telemetry / Analytics — DECIDED (GameAnalytics SDK)
Free tier, has a Godot plugin, ships with reasonable indie-friendly privacy-policy
guidance out of the box. Integrated in Phase 2 (first phase with a real loop worth
logging). Event schema in `technical-blueprint.md` §5. A privacy policy is still
required before any public release once this is active — see §6 below.

## 5. QA / Playtest Feedback Loop — KEPT DELIBERATELY LIGHT
A single button in the main menu linking to a short feedback form. Nothing
mandatory, nothing blocking any phase's exit benchmark. Revisit a more structured
loop later only if it turns out to be genuinely useful.

## 6. Distribution & Legal Readiness — itch.io FIRST (lightened)
Launch platform: **itch.io**. This meaningfully lightens what used to be a heavy
Phase 5 compliance list:
- No developer-account fee, no formal age-rating questionnaire, permissive content
  policy — the shisha content is a non-issue on itch.io specifically.
- **Still needed regardless of platform:** a privacy policy, since GameAnalytics is
  active (see §4). Keep it short and honest — doesn't need to be elaborate for a v1
  itch.io release.
- **Deferred, not required for v1:** Google Play ($25 one-time) / Apple ($99/yr)
  developer accounts and their formal age-rating paperwork — only relevant if/when
  mobile-store distribution is pursued as a post-launch stretch goal. Expect the
  shisha content to push any future mobile rating up a tier regardless of styling.

## 7. Performance Budget — SET
Floor: a mid-range Samsung Galaxy A-series device (closest real matches to "A74":
**Galaxy A73 5G or A54 5G**, ~2022-era, Snapdragon 7-gen/Exynos 1280 class,
6–8GB RAM) up through the newest flagships.
- 60fps floor on the flat "Right Mix" station minigames even on the A73/A54 class
  (these are timing-sensitive, so this floor matters most).
- Isometric world can flex down to 30fps only on the weakest supported devices.
- Quality-scaling settings (texture res, particle density, lighting) so flagships
  get a visibly richer scene without raising the floor requirement.
- Minimum OS target: roughly Android 10+ (API 29+).

## 8. Business/Ownership — CONFIRMED (effectively solo)
Project: **2ahwa Sim**. You + AI assistance is the real team; friends' contributions
are casual AI-assisted suggestions, not formal collaboration — no revenue-share or
credit paperwork needed unless that changes down the line.

---

## Still-Open (genuinely, not just unconfirmed)
- [ ] Final in-game/store-page wording clarifying saves are local-only for v1 (Phase 5)
- [ ] Privacy-policy draft, once GameAnalytics is wired up (Phase 2)
- [ ] Sanity-check the supplied shisha pricing bands against a real local price-check (any phase before Phase 3 balancing)
