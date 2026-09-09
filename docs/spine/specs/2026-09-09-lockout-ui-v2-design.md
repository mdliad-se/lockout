# Lockout UI v2 — design

Date: 2026-09-09
Branch base: `73c35e9`
Stage: FRAME (design for approval)

## 1. Problem

Four issues, reported from screenshots of the running app:

1. **Duplicate day colours.** In the Routines training week, "Upper Body + Core" (WED) and "Upper Body" (THU) render the same magenta, so the week no longer reads at a glance.
2. **No calories burned.** The Training Log shows duration, sets and volume, but nothing about energy cost.
3. **Food log appears to miss common dishes** — egg omelette, ruti, paratha, chicken curry, beef curry, fish curry.
4. **The UI is confusing.** The reference screenshot (a mining/wallet app in the same neubrutalist family) is cited as cleaner: one hero card, a colour-coded action grid, calm secondary rows, restrained use of saturated colour.

### Root causes found in the code

| # | Finding |
|---|---|
| 1 | `lib/widgets/day_block.dart:15` — `DayPalette._categoryOf` maps both names to category 5 (`upper`/`full`), and `forDay` derives hue solely from that category. Any two days of the same category collide by construction. |
| 2 | `lib/models/models.dart:337` — `SessionLog` has `durationSeconds`, `totalVolumeKg`, `totalSets`; no energy field exists anywhere in the schema (version 3). |
| 3 | **The data is not missing.** The library holds 432 items including `Paratha`, `Aloo Paratha`, `Roti / Chapati`, `Tandoori Roti`, `Plain Omelette`, `Dim Bhaji (Bengali Omelette)`, `Chicken Curry (Bengali)`, `Beef Curry (Bengali)`, `Rui Macher Jhol (Rohu Curry)`. `LibraryFood.matches` (`lib/data/food_library.dart:39`) is a plain case-insensitive substring test, so `omlet`, `ruti`, `murgir` and any misspelling return zero results. This is a retrieval defect that reads as a coverage defect. |
| 4 | Every screen currently competes for attention: multiple saturated fills per screen, inline forms above content, `shadowLg` used widely, chips filled rather than outlined, 0px radius everywhere. |

## 2. Decisions locked in FRAME

Each of these was asked and answered; they are settled inputs, not open questions.

| Decision | Chosen |
|---|---|
| Redesign scope | **All 5 tabs, full redesign**, information architecture included |
| Corner radius | **Adopt rounded** — 14px cards, 12px tiles, full-pill buttons; keep 3px ink border and zero-blur hard shadow. Supersedes the v1 "0px radius" convention |
| Palette model | **Authored 8-colour `accents` ramp per theme**; all 8 themes kept, hue-rotation derivation dropped |
| Day colours | **Category-seeded, unique per day** — collisions resolve forward to the next free accent |
| Calories burned | **MET × bodyweight × duration**, MET chosen by the session's dominant muscle group |
| Net calories | **Burn is displayed, targets are unchanged** — activity is already priced into the target via `ActivityLevel`, so adding burn would double-count |
| Nav & landing | **TODAY becomes HOME**, first tab and default landing screen; 5 destinations kept |
| Food log | **Fix search (aliases + typo tolerance) and add genuinely missing dishes** |
| Toolchain | **Flutter SDK installed** at `C:\src\flutter` (git stable clone, not on PATH) |

## 3. Design system v2

Changes land in `lib/theme/` and `lib/widgets/` before any screen is re-laid-out.

### 3.1 Shape and elevation

```
radiusCard   = 14.0   // cards, sheets, hero blocks
radiusTile   = 12.0   // action-grid tiles, day rails, chips
radiusPill   = 999.0  // buttons, toggles, active nav tile
borderControl = 3.0   // unchanged
shadowSm/Md/Lg = 3/6/10, zero blur   // unchanged
```

`JinatraTokens.cardDecoration` gains a `radius` parameter defaulting to `radiusCard`, so existing call sites move to rounded corners without edits. `BorderRadius.zero` literals in widget code are replaced.

### 3.2 Authored accent ramp

`AppPalette` gains `final List<Color> accents` — exactly 8 authored colours per palette, ordered so adjacent entries are visually distinct, plus a derived `onAccentFor(Color)` chosen by luminance. Light themes get saturated colours on cream; dark themes get dark-safe variants at matched hue.

This single change serves three consumers: the day rails, the HOME action grid, and category chips. `forDay`'s HSL rotation is deleted.

### 3.3 Colour discipline (the rule that makes it read as "clean")

- **One hero per screen.** Exactly one large saturated block. Everything below it sits on `surface` over `canvas`.
- **The action grid is the exception** — it is allowed many colours because it is a menu, not content.
- Chips lose their fills: 2px outline plus ink text, except the single "active"/"today" state.
- `shadowLg` is reserved for the hero; content cards use `shadowMd`; controls use `shadowSm`.
- Section spacing goes from 16 to 28; card internal padding 16 → 18.

### 3.4 Shared widgets added

| Widget | Purpose |
|---|---|
| `HeroCard` | The one saturated block per screen: eyebrow label, large value, optional pill actions |
| `ActionGrid` / `ActionTile` | 4-per-row coloured tiles from `accents`, icon over label |
| `CalmRow` | Bordered surface row: leading icon box, title, optional value, chevron |
| `StatTile` | Small bordered metric: label above value, mono numerals |
| `SheetScaffold` | Standard bottom sheet used by every form that currently sits inline |

## 4. Per-tab information architecture

### 4.1 HOME (was TODAY) — `lib/screens/today_tab.dart`

Idle state:

```
┌───────────────────────────────────┐
│ TODAY · MON                       │  hero, accent 0
│ LEGS                              │
│ 4 EX · 12 SETS · ~50 MIN          │
│ ( START SESSION )  ( VIEW PLAN )  │
└───────────────────────────────────┘
┌───────────────────────────────────┐
│ [icon] 1,240 / 1,850 kcal      >  │  calm row: intake
└───────────────────────────────────┘
┌───────────────────────────────────┐
│ [icon] 72.5 kg · −0.4 this week >  │  calm row: bodyweight
└───────────────────────────────────┘
QUICK ACTIONS
[LOG FOOD] [WEIGH IN] [ROUTINES] [HISTORY]
[ CUSTOM ] [ STREAK ] [  PLAN  ] [SETTINGS]
```

Rest day swaps the hero for a rest hero with `START CUSTOM SESSION`. The live-session UI keeps its current mechanics — exercise cards, set rows, rest bar — restyled to v2 and with the rest bar promoted to a persistent bottom bar instead of an inline block.

### 4.2 ROUTINES — `lib/screens/routines_tab.dart`

- Routine header becomes a compact card: name, outlined chips (mode / day count), one filled `ACTIVE` chip, overflow menu for delete and set-active.
- The training week becomes seven **compact day rows**: a 56px coloured rail with the weekday, the day name, and a one-line summary. No inline expansion.
- Tapping a day opens a **detail sheet** (`SheetScaffold`) holding warm-up, exercises, finisher and the edit affordances. This removes the deepest nesting in the app and is the largest single clarity win in this tab.
- All creation/edit forms move into sheets.

### 4.3 FOOD — `lib/screens/food_tab.dart`

- Hero: kcal used vs target with a horizontal progress bar, protein/carb/fat under it as three `StatTile`s.
- Entries grouped into **BREAKFAST / LUNCH / DINNER / SNACK** sections with per-section kcal subtotals, replacing one flat list.
- The log form moves out of the top of the page into a sheet opened by a pill `+ LOG FOOD` action.
- Food picker gains the new search (section 6) and shows why a result matched when it matched by alias.

### 4.4 BODY — `lib/screens/body_tab.dart`

- Hero: current weight, delta vs. the previous entry, and a compact sparkline of logged history.
- Below it a 2×2 `StatTile` grid: BMI, target weight, daily intake target, weeks remaining.
- Goal card and recommended-plan card collapse behind `CalmRow`s that open sheets — they are reference material, not daily reading.
- Measurement form moves to a sheet.

### 4.5 LOG — `lib/screens/log_tab.dart`

- Hero: streak, with workouts and total volume as two inline stats (close to today's, restyled).
- Archive cards collapsed by default, showing `day · date · duration · sets · volume · ~kcal`. Expanded state keeps the per-exercise set chips.
- Delete moves from an always-visible link to the expanded state.

### 4.6 Bottom nav — `lib/widgets/bottom_nav.dart`

Order becomes `HOME · ROUTINES · FOOD · BODY · LOG`; `main.dart` / `main_screen.dart` default index changes to HOME. The active destination becomes a filled pill tile (accent fill, ink border) rather than a full-height red block; inactive items are icon + label in ink at 60% alpha. Vertical dividers are removed.

## 5. Calories burned

### 5.1 Model

```
kcal = MET × 3.5 × bodyweightKg ÷ 200 × durationMinutes
```

MET is selected from the session's **dominant muscle group**, computed from the session's `SetLog`s by resolving each `exerciseName` through `ExerciseLibrary` to a muscle group and taking the group with the most sets. When no sets resolve, fall back to keyword matching on `SessionLog.dayName` (the same category logic the day palette uses).

| Dominant group | MET | Rationale |
|---|---|---|
| Cardio | 8.0 | Compendium: vigorous cardio |
| Legs, Glutes, full-body | 6.0 | Vigorous multi-joint resistance work |
| Chest, Back, Shoulders | 5.0 | Upper-body compound |
| Core | 4.5 | Calisthenic, mostly bodyweight |
| Biceps, Triceps, Calves, Forearms | 3.5 | Isolation |
| Rest / no duration | 0 | No estimate shown |

Bodyweight resolution order: latest `BodyEntry` → `GoalProfile.targetWeightKg` → no estimate rendered. Values are always prefixed `~` in the UI, because they are estimates.

### 5.2 Persistence

- Schema version 3 → 4. Add `kcal_burned REAL NOT NULL DEFAULT 0` to `session_logs` using the existing idempotent add-column helper (`database_service.dart:39`). No destructive recreate.
- Computed once at session save and stored, so history does not silently change when bodyweight changes.
- Rows written before the migration keep `0`; the Log tab computes an estimate for those on read (from stored duration and current bodyweight) without persisting it.
- `SessionLog.toMap`/`fromMap` carry the field, so backup export/import round-trips it. `backup_service.dart` needs no structural change — the existing table-driven export picks the column up — but the round-trip test is extended to assert it.

### 5.3 Where it appears

HOME calm row (today's burn), LOG archive card header, and the session-finished summary. **The daily calorie target is not adjusted** — see the locked decision in section 2.

## 6. Food search

### 6.1 Matching pipeline

New `lib/data/food_search.dart`, so `LibraryFood.matches` stays a simple predicate and the ranking logic is testable on its own.

1. **Normalise** query and candidate: lowercase, strip diacritics and punctuation, collapse whitespace, drop parenthesised qualifiers for token comparison.
2. **Alias expansion.** A curated transliteration/synonym table maps user spellings to canonical tokens, both directions of common Bengali/Hindi usage:
   `ruti|rooti|rooty → roti` · `porota → paratha` · `omlet|omlette|omelet|omelete → omelette` · `dim → egg` · `murgi|murgir|murog|morog → chicken` · `gorur|gorur mangsho → beef` · `mach|machh|maach|macher|machher → fish` · `chingri → prawn` · `ilish → hilsa` · `bhat → rice` · `daal|dhal → dal` · `khichdi → khichuri` · `mangsho → meat` · `misti|mishti → sweet` · `torkari → vegetable` · `bhorta → mash` · `jhol → curry` — plus British/US spelling pairs (`yoghurt/yogurt`, `aubergine/eggplant`, `courgette/zucchini`, `prawn/shrimp`, `chips/fries`).
3. **Typo tolerance.** Per-token Damerau–Levenshtein: distance ≤1 for tokens of 4–6 characters, ≤2 for 7+, exact for ≤3. Guards against `cury`, `chiken`, `parata`.
4. **Rank**, best first: exact name → name prefix → all query tokens present in name → alias-resolved name hit → fuzzy name hit → category hit → ingredient hit. Ties break on the library's own order, so staples stay above obscure items.
5. Results that matched by alias or fuzz show a small `≈ matched "ruti"` note, so a surprising hit is explainable rather than mysterious.

The same pipeline is applied to `ExerciseLibrary.matches`, which has the identical substring limitation.

### 6.2 Library additions

An audit pass over the 432 entries fills genuine gaps, roughly 35–45 new items, concentrated where everyday logging currently forces "ADD CUSTOM":

- **Eggs**: Cheese Omelette, Masala Omelette, Egg Bhurji, Poached Egg, Egg Curry (generic), Omelette (3-egg)
- **Breads**: Cheese Paratha, Egg Paratha, Roti with Ghee, Chapati (wholewheat, 1 large), Ruti (Bangladeshi, atta)
- **Generic curries** distinct from the named Bengali versions: Chicken Curry (generic), Fish Curry (generic), Prawn Curry, Vegetable Curry, Egg Curry, Mutton Bhuna, Duck Curry (Hasher Mangsho), Chicken Bhuna
- **Everyday Bengali gaps**: Tehari (Chicken), Chicken Khichuri, Dim Khichuri, Alu Bhorta with Mustard Oil, Shorshe Bata Mach, Chicken Jhol, Lau Chingri
- **Common staples**: Mixed Fruit Salad, Boiled Chickpea Salad (Chola), Puffed Rice Snack, Instant Coffee, Sugar-free Tea, Whole Wheat Bread (2 slices)

Each entry carries `serving`, `kcal`, macros and `ingredients`, matching the file's existing convention. A test asserts `kcalFromMacros` stays within 12% of the stated `kcal` for every new item, and that names remain unique.

## 7. Day colour uniqueness

```dart
// Category seeds the hue; the routine resolves collisions.
// keyed by TrainingDay.id, days passed in weekday order
Map<String, Color> assignDayColours(List<TrainingDay> days)
```

- Rest days take `surfaceAlt` and never consume an accent slot.
- Each training day proposes `accents[categoryIndex % 8]`. If that accent is already taken by an earlier day in the same routine, walk forward modulo 8 to the first free one.
- More than 8 training days in one routine (possible with rotating schedules) wraps and permits reuse — with a deterministic order, so it is stable across rebuilds.
- Assignment is per routine and computed from the day list, not from global state, so two routines can each start at their category colour.
- `onColorFor` continues to pick ink/white by luminance.

## 8. Scope

### In scope

- `lib/theme/` — radius tokens, accent ramps for all 8 palettes, `cardDecoration` radius parameter
- `lib/widgets/` — new shared widgets; `day_block.dart` colour assignment; `bottom_nav.dart`; `jinatra_button.dart`, `jinatra_card.dart`, `jinatra_input.dart` restyle; `food_picker.dart` and `exercise_picker.dart` search
- `lib/screens/` — all five tabs re-laid-out; `settings_screen.dart` restyled to v2 (no IA change); `exercise_video_screen.dart` restyled
- `lib/data/` — `food_search.dart` (new), `food_library.dart` additions, `exercise_library.dart` matcher delegation
- `lib/models/models.dart` + `lib/services/database_service.dart` — `kcalBurned` field and the version 4 migration
- New service `lib/services/energy_estimator.dart`
- `main_screen.dart` / `main.dart` — default landing tab
- Tests for every one of the above

### Out of scope

- Notifications (`notification_service.dart`) — behaviour untouched
- Backup/restore logic beyond carrying the new column
- Nutrition/training planner formulas (`nutrition_planner.dart`, `training_planner.dart`) — targets keep their current maths
- Settings information architecture — restyle only, no reorganisation
- Any network feature; the app stays offline
- Localisation / Bengali UI strings (aliases are search-only)
- Android/iOS platform config, app icon, splash
- **Observation, not addressed here:** `google_fonts: ^8.2.1` fetches font files at runtime, which sits awkwardly with the zero-network claim. Pre-existing; worth a separate task to bundle the four families as assets.

## 9. Approaches considered

**A. Token-first, then screens (recommended).** Land design-system v2 (radius, accents, shared widgets) as the first tasks, then re-lay each tab on top of it. Every screen inherits the same rules by construction, and the five screen tasks are independent of each other once the system exists. Costs one extra sequencing step before anything visible changes.

**B. Screen-by-screen rewrite, extract shared parts later.** Visible progress sooner, but the first two screens set precedents the later three then have to be refactored to match — the usual outcome is five nearly-identical hero implementations.

**C. Parallel v2 widget library behind a flag, switch at the end.** Safest rollback story, but this is a single-user offline app with no staged release; the flag would be paid for and never used, and it doubles the surface during the change.

**Chosen: A.** The dependency is real (all five screens consume `accents`, `HeroCard`, `ActionGrid`), and it is the only ordering where the last screen is no harder than the first.

## 10. Delivery order

1. Design-system v2 — radius tokens, `accents` on all 8 palettes, `cardDecoration` radius
2. Shared widgets — `HeroCard`, `ActionGrid`, `CalmRow`, `StatTile`, `SheetScaffold`
3. Day colour assignment + Routines re-lay (week rows, day detail sheet)
4. `kcalBurned` — model, migration 3→4, `EnergyEstimator`, backup round-trip
5. `food_search.dart` — aliases, fuzzy matching, ranking; wired into both pickers
6. Food library additions + macro-consistency test
7. HOME rebuild (hero, action grid, calm rows) + nav order and default tab
8. FOOD re-lay (hero, meal sections, sheet form)
9. BODY re-lay (trend hero, stat grid, sheets)
10. LOG re-lay (streak hero, collapsed archive with kcal)
11. Settings + video screen restyle pass

## 11. Verification

- Runner: `C:\src\flutter\bin\flutter.bat test --concurrency=1`. **Serial is mandatory** — the suites share one sqflite file, and the default parallel run produces about ten spurious failures. Verified serial baseline at `73c35e9`: **91 passed**.
- New unit tests: accent ramp completeness (8 distinct colours per palette, adequate contrast against ink), day-colour uniqueness across a 7-day week including the reported WED/THU case, MET selection and kcal arithmetic, migration 3→4 idempotence, food-search alias/fuzzy/ranking cases (`omlet`, `ruti`, `murgir`, `beef cury`, `parata`), new-food macro consistency.
- New widget tests: HOME renders a hero and eight action tiles; nav opens on HOME; Routines day rows expose distinct rail colours; Log card shows a kcal value; the food picker finds `ruti`.
- Manual: `flutter run` on Android for each tab in a light and a dark palette. Note `flutter pub get` wants Windows Developer Mode for desktop plugin symlinks — irrelevant to `flutter test` and to the Android target.

## 12. Assumptions (≥90% confidence, stated rather than asked)

1. Existing session history is kept; no data migration beyond the added column.
2. All 8 themes remain user-selectable; each gets an authored accent ramp rather than the theme list being trimmed.
3. Icons stay Material icons; no custom icon set is commissioned.
4. Copy stays English and uppercase-mono for labels, matching the current voice.
5. Estimated values are always marked `~` so they are never mistaken for measurements.
6. `flutter pub get` side effects on `analysis_options.yaml` and `pubspec.lock` were reverted; dependency versions stay as committed.
