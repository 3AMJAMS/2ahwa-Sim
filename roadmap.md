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
- **Lighting:** single warm key light from the string-light canopy (~45° down-front), consistent across every tier; cool dim ambient night-sky fill for silhouette separation.

---

## Vehicle Naming (Resolved)
**FIFI** — 127-styled silhouette, original name/logo. **WAHSH (الوحش)** — SUV tier, boxy-90s silhouette, no Jeep grille/Cherokee echo.

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

## Phase 1 · Core Minigame (Weeks 4–8)
Hot sand-bath gauge + cold blender gauge, in isolation. **Also:** aspect-ratio/stretch-mode implementation, RTL font validation, translation-key architecture, tutorial Stages 1–2.
**Exit benchmark:** both loops satisfying 10–15 min, tested across aspect ratios + mid-range Android + desktop.

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
Retention (regulars with memory, loyalty card, badges) · Atmosphere (radio/ambient events, seasonal weather, khamaseen wind) · Cultural (café-history trivia notebook) · Economy (Ramadan iftar pricing, daily special) · Sharing (photo-mode/receipt screen)

---

## Core Loop
Take Order → Prepare (🔥 hot gauge / 🧊 cold blender) → Shisha (coal timer, حجر refill) → Serve. Scoring: speed×accuracy → tips → unlocks/progression.

## Day Bookend Sequence
2–4 sec time-lapse: park → trunk open → shelves stocked (side/roof per upgrade) → power on → gameplay; reversed at close. Tap-to-skip + auto-skip. Day 1 deliberately bare.

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
**Cold:** كركديه بارد/ينسون بارد (dual) · مانجو · تمر هندي · سوبيا (seasonal) · عرقسوس · قصب · خروب · قمر الدين (seasonal) · ليمون بالنعناع · بطيخ بالنعناع · جوافة/موز بلبن · آيس لاتيه/موكا/كولد برو (Modern unlock)

---

## Progression Ladder
1. FIFI trunk stand · 2. WAHSH stand · 3. Street baladi ahwa · 4. Busy baladi ahwa · 5. Historic café (El-Fishawy) · 6. Modern كافيه

## Store Upgrades
| Category | FIFI | WAHSH | Fixed venues |
|---|---|---|---|
| Equipment | Basic burner+blender | Dual burner, upgraded blender | Bigger رملة, espresso machine |
| Snacks | Small chip rack | Chip+noodle rack | Full snack cooler |
| Décor | Fairy lights | Neon+LED, stools | Marble tables, mashrabiya |
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
