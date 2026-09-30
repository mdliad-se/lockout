# LOCKOUT — Material 3 Expressive redesign

Date: 2026-09-28
Branch: feat/ui-v2
Stage: FRAME (design, pre-plan)

---

## 1. Problem

Three separate problems, one branch.

1. **The visual system is wrong for the product.** The app ships "Jinatra Neubrutalism v2":
   3px ink borders, zero-blur hard shadows, 8 loud swappable palettes, all-caps mono labels.
   The product is a disciplined long-horizon fitness tracker; the UI reads as a poster.
2. **The routine screen has no focus.** `lib/screens/routines_tab.dart:636` (`_buildRoutineCard`)
   renders a `DayRow` for every training day of every routine. Seven near-identical rows per
   routine card means the one day that matters today has no more weight than the other six.
3. **The chosen typography never ships.** `assets/` is empty and `google_fonts` fetches
   typefaces over HTTP at first paint. The APK is zero-network on device, so Archivo / Inter /
   JetBrains Mono silently fall back to Roboto in production. The design intent has never
   actually been seen on a phone.

## 2. Goals

- A single coherent Material 3 Expressive system: dark-first, calm, premium, minimal colour.
- Routines leads with **today** and keeps the rest of the week reachable.
- Type that actually renders on an offline device.
- Theming that can follow the phone's own Material You colours.

Non-goal: changing what the app *does*. This branch is UI-only.

## 3. Scope

**In scope**

- New theme layer (`lib/theme/`), replacing `JinatraTokens` + `AppPalette` wholesale.
- 7 themes: 3 authored dark, 3 authored light, 1 dynamic (Material You).
- Bundled Inter + JetBrains Mono; `google_fonts` removed.
- Navigation restructure to `Home / Workout / Progress / Food / Profile`.
- Every screen rebuilt: Home, live session, Workout (routines), Progress (Body+Log merged),
  Food, Profile (Settings), plus the exercise-video screen.
- Every shared widget and bottom sheet in `lib/widgets/`.
- Routines: today featured, full week collapsible.
- Test suite updated to assert the new system.

**Explicitly out of scope**

- Database schema, migrations, `lib/services/**` behaviour. No data model changes.
- New product features (no new tracking, no new metrics, no new screens beyond the merge).
- Backup format, notification scheduling logic, exercise/food libraries.
- iOS/web/desktop polish. Android phone is the target surface.
- Onboarding flow (does not exist today, not added here).

## 4. Decisions taken in FRAME

| # | Decision | Chosen |
|---|---|---|
| 1 | Routines "current day only" | Today featured as a large card; other days behind a `FULL WEEK (n)` expander so the builder stays usable |
| 2 | Palettes | 3 dark + 3 light authored, re-cut for Material Expressive, **plus** a dynamic Material You option. App name stays **LOCKOUT** ("LIAD" in the brief is a reference name only) |
| 3 | Navigation | `Home / Workout / Progress / Food / Profile`. Progress = Body + Log under a segmented control. Settings becomes the Profile tab |
| 4 | Fonts | Bundle Inter + JetBrains Mono under `assets/fonts/`, drop `google_fonts` |
| 5 | Theme layer | Real `ThemeData` + `Theme.of(context)`. Static colour access is deleted |
| 6 | Scope | All screens + nav restructure in this branch |

## 5. Design system

### 5.1 Colour

Each theme is an **explicit `ColorScheme`** — every role stated, not derived by rotating a
seed. `ColorScheme.fromSeed` is used once during authoring to get a starting ramp, then the
literal is hand-corrected and committed. Rationale: the existing `AppPalette` doc comment
already records that seed-rotation produced colour collisions and muddy mid-tones; the same
trap applies to `fromSeed` overrides, which silently re-derive every role you did not name.

**Graphite (default dark)** — the palette from the brief, mapped to M3 roles:

| M3 role | Value |
|---|---|
| `surface` | `#080A0D` |
| `surfaceContainerLowest` | `#0B0E12` |
| `surfaceContainerLow` | `#101419` |
| `surfaceContainer` | `#151A20` |
| `surfaceContainerHigh` | `#1B2128` |
| `surfaceContainerHighest` | `#222931` |
| `onSurface` | `#F5F7FA` |
| `onSurfaceVariant` | `#9BA5B1` |
| `outline` | `#272E36` |
| `outlineVariant` | `#222931` |
| `primary` | `#A3E86D` |
| `onPrimary` | `#101419` |
| `primaryContainer` | `#26401A` |
| `onPrimaryContainer` | `#C4F59A` |
| `secondary` | `#75D9FF` |
| `onSecondary` | `#101419` |
| `secondaryContainer` | `#123647` |
| `onSecondaryContainer` | `#B0E9FF` |
| `tertiary` | `#FFC857` |
| `error` | `#FF7777` |

The other two darks (**Ember**, warm neutral ground with an amber primary; **Indigo**, cool
ground with a periwinkle primary) and the three lights (**Paper**, **Linen**, **Frost**) follow
the same role table with their own authored values. Disabled text resolves from
`onSurface.withValues(alpha: 0.38)` per M3, not a fourth authored grey.

**Colour discipline** (carried from the brief, enforced in review):

- `primary` means progress / complete / commit. Nothing decorative uses it.
- `secondary` means cardio, water, information.
- `tertiary` warns. `error` blocks.
- Everything else is a surface tone. No gradients, no neon, no per-card hues.

**Semantic roles that M3 has no slot for** live in one `ThemeExtension<LockoutSemantics>`:
`success`, `warning`, `danger`, `restDay`, `chartLine`, `chartFill`, and the 8-colour
`categoryRamp` used by day rails and action tiles. A `ThemeExtension` is context-resolved, so
it inherits dynamic colour and theme switching for free — unlike a static list.

### 5.2 Dynamic (Material You)

`dynamic_color` supplies `ColorScheme`s derived from the phone's wallpaper on Android 12+. When
the user selects the Dynamic theme:

- available — use the platform light/dark scheme, then overwrite `error`, `tertiary` and the
  `LockoutSemantics` ramp with our authored values so warnings and rest days never land on a
  wallpaper hue that reads as "go".
- unavailable (Android 11-, or the plugin returns null) — the Dynamic option is **hidden from
  the picker entirely** rather than shown and silently falling back. If it was already the
  saved selection, resolve to Graphite.

### 5.3 Typography

Inter for everything, JetBrains Mono for numerics that must align in columns (set/rep/weight
tables, the rest timer, the log). Bundled as static weight files; the M3 `TextTheme` is stated
explicitly rather than scaled from a single size.

| M3 style | Size / weight | Used for |
|---|---|---|
| `displaySmall` | 36 / w700 | the one big number on a screen (current weight, timer) |
| `headlineMedium` | 28 / w700 | screen titles |
| `titleMedium` | 18 / w600 | card titles, day names |
| `bodyMedium` | 14 / w400 | body copy |
| `labelLarge` | 14 / w600 | button labels |
| `labelMedium` | 12 / w500 | field labels, chips |
| `labelSmall` | 11 / w500 | metadata |

All-caps is retired as a default. It survives only on small metadata labels (`labelSmall`) and
the weekday rail, where it aids scanning. Letter-spacing follows the M3 defaults.

### 5.4 Shape, elevation, spacing, motion

Shape (wired into the component themes): button 14, card 18, dialog 24, bottom sheet 28 (top
corners only), text field 14, chip/pill 999, progress track 999.

Elevation: card 1, elevated card 3, modal 6, FAB 4. Dark themes lift with `surfaceContainer*`
tones first and shadow second — no heavy drop shadows anywhere. Every `hardShadow` call site is
deleted.

Spacing: 8dp grid. Card padding 16, screen padding 20, section gap 24. Minimum touch target
48dp, enforced in the widget tests that already measure it.

Motion: framework `Durations.short4` (200ms) / `Durations.medium2` (300ms) with
`Easing.standard` and `Easing.emphasized`. Expansion, tab change and sheet entry animate;
nothing bounces, nothing overshoots.

### 5.5 What "Expressive" means here

Flutter 3.47.2 does not ship `ButtonGroup` / `SplitButton` / the expressive loading indicator.
Expressive is therefore delivered through what *is* available: the large shape scale, tonal
surface layering, `NavigationBar` with a pill indicator, `SegmentedButton`, `CarouselView`
where a horizontal set of peers exists, emphasized motion, and generous type contrast between
a single large number and quiet supporting text.

## 6. Navigation

```
NavigationBar (80dp, pill indicator, filled icon active / outlined inactive)
|-- Home       today's session, quick actions, at-a-glance summary
|-- Workout    routines: today featured + collapsible week
|-- Progress   SegmentedButton [ Weight | History ]   <- Body + Log merged
|-- Food       (hidden when food_tab_enabled = false -> 4 tabs)
|-- Profile    settings, backup, about
```

`BottomNav.visibleTabs` stays the single source of truth for order and visibility, and
`MainScreen._screenFor` stays an exhaustive switch over the `NavTab` enum, so a tab added
without a screen is still a compile error. Both properties are preserved deliberately.

Consequences to handle:

- `SettingsScreen` currently is a *pushed route* with an `AppBar`, a back button and an
  `onSettingsUpdated` callback. As a tab it loses the route; the callback becomes a direct
  `MainScreen` reload. Its sub-pages (backup, about, theme picker) become pushed routes from
  the Profile tab.
- `MainScreen`'s global `AppBar` (with the `lockout` chip and the settings gear) is removed.
  Each tab owns its own large-title header, which is what lets Home read as a dashboard.
- `LogTab` and `BodyTab` keep their own `State` and `GlobalKey` reload contracts; the Progress
  tab hosts both and forwards `reload()` to the visible segment.

## 7. Screens

Mobbin references were used to fix the layout patterns before any code. Cited per screen.

### 7.1 Home

Large greeting header, then: **today's session hero card** (day name, `N EX / N SETS`, a filled
`START SESSION`), weight progress card with a smooth sparkline and remaining-to-goal, nutrition
row (protein / calories / water as 8dp pill progress bars), then a compact quick-action grid.
Pattern reference: [Apple Fitness summary](https://mobbin.com/screens/5b8d5290-6c52-436f-bac3-9d0a531db829),
[Garmin Connect at-a-glance](https://mobbin.com/screens/99ec915b-326d-432e-9e0b-914a7e4f3123).

The existing `HomeHub` / `HeroCard` / `ActionGrid` / `StatTile` composition survives
conceptually and is rebuilt on M3 cards.

### 7.2 Live session

Sticky header carrying three figures — **Duration · Volume · Sets** — with a `Finish` action at
its trailing edge and a linear progress indicator across exercises beneath. Exercise cards with
a set table; each set row is `SET / PREVIOUS / KG / REPS / done` with `-` and `+` steppers on
weight and reps and a check to complete. **A completed set tints its whole row** in the success
role rather than only ticking a box, so progress down the card is readable at a glance.

Rest timer as a persistent bottom bar — a thin progress line, the countdown, then `-15s`,
`+15s`, `Skip`. Not a dialog: the set table must stay visible and scrollable while resting.

Finishing opens a summary sheet with the same Duration / Volume / Sets triple before the session
is written, so the numbers the log will show are confirmed rather than discovered later.

Flow reference: [Hevy — logging a workout](https://mobbin.com/flows/7b6374ff-8ff6-4d7b-babe-077e72b6ee1f)
(21 screens: quick start, set table, rest bar, save screen),
[Runna — completing a strength workout](https://mobbin.com/flows/d88683b7-90c0-4cf1-8a45-296099e59a3b).
Screen reference: [Hevy set logging](https://mobbin.com/screens/fa1b4fe1-5d63-4e97-ac9a-ccdf41b86d7c),
[Ladder set table](https://mobbin.com/screens/3daed3ec-2832-48af-9f73-0aab0d428f51),
[Bevel in-session](https://mobbin.com/screens/e94afd68-a93b-473f-992b-c3467789a29c).

The leg-safety notice from the brief renders here and on the day sheet as a low-emphasis
`tertiaryContainer` card: *"Pain-free movement only — use moderate load, avoid forcing painful
reps."*

### 7.3 Workout (routines) — the current-day change

```
+- PUSH / PULL / LEGS ------------ : -+
| WEEKDAY . 6 DAYS . ACTIVE           |
|                                     |
| +- TODAY . MON -------------------+ |
| | UPPER PUSH                      | |
| | 5 EX . 18 SETS                  | |
| | [ START SESSION ]               | |
| +---------------------------------+ |
|                                     |
|  FULL WEEK (6)                   v  |
+-------------------------------------+
```

Rules:

- The featured card is today's `TrainingDay` for a routine in `SchedulingMode.weekday`. It
  carries the day's colour from the category ramp as an accent, not as a fill.
- **Rest day today** — the featured card says so and offers no `START SESSION`.
- **No day scheduled today** (gap in the week) — featured card reads "Nothing scheduled today"
  and offers `CUSTOM SESSION`; the week expander is still there.
- **`SchedulingMode` is not weekday** (rotation/sequence) — there is no "today" to feature, so
  the card shows the *next up* day in the same slot, labelled `NEXT` instead of `TODAY`.
- **Inactive routine** — no featured card at all; it opens straight to the collapsed week, since
  "today" is only meaningful for the routine actually being followed.
- The expander is collapsed by default and its state is per-routine and ephemeral (not
  persisted) — reopening the tab returns to the focused view, which is the point of the change.
- Expanded rows are compact `ListTile`-shaped rows, not the current bordered cards.
- `+ ADD DAY` lives inside the expanded week, so building a routine means opening the week.

Pattern reference: [Centr "UP NEXT" + program list](https://mobbin.com/screens/0f98ff15-3fca-4008-b431-ae66678f023e),
[Equinox+ required sessions](https://mobbin.com/screens/f97dc968-1dc0-4f91-863c-69fe70e88140),
[Hevy program detail](https://mobbin.com/screens/7cd9818f-46af-43a5-b1a5-f114feeeb6df).

### 7.4 Progress

`SegmentedButton [ Weight | History ]` under the title.

- **Weight**: current weight as a `displaySmall` number, goal and remaining beneath, smooth
  line chart with a range selector, then BMI and plan cards.
- **History**: session log list, grouped by month, each entry a quiet row with volume and
  duration.

Pattern reference: [Cal AI progress](https://mobbin.com/screens/8d3cf983-af91-4151-9dc2-0c250e57421b),
[MacroFactor scale weight](https://mobbin.com/screens/c2f3e235-31c3-42fe-8039-a11673634cff),
[Hevy measurements](https://mobbin.com/screens/3af37b11-e24c-4b43-8179-d1967bd318e2).

`Sparkline` is upgraded from straight segments to a smooth curve, per the brief's "smooth
curve, weekly average".

### 7.5 Food

Daily totals as three pill progress bars (protein, calories, water). Calories read
`963 / 2,930` with **`1,967 left`** on the trailing edge — the remaining number is what a
person actually decides on, so it is stated rather than left to be subtracted. Meal sections
as cards, each row a food with its own `+`. Food picker as an M3 search sheet with filter
chips. No new analytics — the brief explicitly says avoid complex calorie analytics.

Pattern reference: [MyFitnessPal daily totals](https://mobbin.com/screens/32b82d20-deb0-493f-a643-c170d9e46b8b)
(calories-left figure, macro row), [Yazio meal list and water tracker](https://mobbin.com/screens/7157507b-da8e-40f7-85b3-37017cc7002f)
(per-meal `+`), [Life Reset dark macro bars](https://mobbin.com/screens/4ec121e3-6681-4954-bae5-6313bebff8d7).

### 7.6 Profile

Grouped settings on `surfaceContainer` cards, each group under a quiet `labelSmall` caption
(APPEARANCE, UNITS, TRAINING, FOOD, NOTIFICATIONS, DATA, ABOUT). Rows state their current value
on the trailing edge rather than only a chevron, so the screen reads without opening anything.
Theme picker is a 7-swatch grid (3 dark, 3 light, Dynamic). Destructive actions in `error` as a
full-width control at the very bottom, behind the existing confirmation.

Pattern reference: [theScore account groups](https://mobbin.com/screens/0ca2cf67-c941-428a-8d03-6bcf28175c32),
[Crypto.com account rows](https://mobbin.com/screens/036aab09-919c-438e-9208-4789bf516113)
(value-on-the-right rows on a dark ground), [Base display settings](https://mobbin.com/screens/3f573b95-4bbb-4978-957e-56178543e8e7)
(theme swatch + appearance mode as two separate rows).

## 8. Component migration map

| Deleted | Replaced by |
|---|---|
| `theme/jinatra_tokens.dart` | `theme/lockout_theme.dart` (ThemeData builder) + `theme/lockout_semantics.dart` (ThemeExtension) |
| `theme/app_palette.dart` | `theme/schemes.dart` (6 authored `ColorScheme` pairs) + `theme/theme_controller.dart` |
| `widgets/jinatra_card.dart` | framework `Card` via `CardThemeData` |
| `widgets/jinatra_button.dart` | `FilledButton` / `FilledButton.tonal` / `OutlinedButton` / `TextButton` via button themes |
| `widgets/jinatra_input.dart` | `TextField` via `InputDecorationTheme` (filled, 14dp) |
| `widgets/bottom_nav.dart` (custom) | `NavigationBar` via `NavigationBarThemeData`; `NavTab` enum and `visibleTabs` kept |
| `widgets/day_row.dart` | `widgets/today_day_card.dart` (featured) + `widgets/week_day_row.dart` (collapsed list) |
| `widgets/day_block.dart` — the neubrutalist shell only | `DayColours` moves onto the `LockoutSemantics` ramp; `SectionHeading` / `SubItemRow` / `AddLink` are kept and restyled, since the day sheet still needs all three |
| hard-shadow / 3px-border helpers | tonal `surfaceContainer*` layering |

Kept with restyle: `sheet_scaffold`, `exercise_picker`, `food_picker`, `meal_section`,
`undo_banner` (logic intact, presented as an M3 `SnackBar`), `sparkline` (curve upgrade),
`action_grid`, `home_hub`, `hero_card`, `progress_hero`, `stat_tile`, `calm_row`.

## 9. Approach

Staged so the tree compiles and tests pass at every step:

1. **Fonts + dependency swap.** Bundle Inter/JetBrains Mono, add `dynamic_color`, remove
   `google_fonts`. `JinatraTokens` text styles temporarily point at the bundled families.
2. **New theme layer alongside the old.** `lockout_theme.dart`, the six schemes, the extension,
   the controller. Nothing consumes it yet.
3. **App shell.** `main.dart` and `MainScreen` adopt `ThemeData`; navigation restructures to the
   5 tabs; Progress and Profile hosts created.
4. **Shared widget kit.** Card/button/input/sheet/nav replaced. Screens still compile because
   they call the same widget names where the names survive.
5. **Screens, one task each**, each with its own tests: Home, live session, Workout (includes
   the current-day change), Progress, Food, Profile.
6. **Delete the old layer.** `JinatraTokens` and `AppPalette` removed; a grep for `Jinatra` in
   `lib/` must return nothing. This is the step that proves the migration is complete rather
   than partial.

Two approaches were rejected: pushing a dynamic scheme into the existing static token class
(keeps the static-colour footgun and lags dynamic colour by a frame), and re-authoring the
token values only (leaves the neubrutalist structure, so it would not read as M3 at all).

## 10. Testing

Serial runner only: `C:\src\flutter\bin\flutter.bat test --concurrency=1`. Baseline to beat:
91 passing.

- `theme_tokens_test`, `day_colours_test`, `widgets_v2_test`, `settings_restyle_test` assert
  neubrutalist specifics and are **rewritten**, not deleted — the invariants they protect
  (contrast, touch target, palette completeness) carry over to the new system.
- New: every authored `ColorScheme` is complete and each foreground role meets 4.5:1 against
  its background — the existing `onAccentColor` contrast maths moves into a test.
- New: theme switch repaints without remounting an in-progress live session.
- New: Routines shows exactly one featured day, collapsed by default, and every rule in section
  7.3 (rest day, no day scheduled, non-weekday mode, inactive routine) gets a case.
- New: the Progress segmented control forwards `reload()` to the visible segment only.
- Existing service, migration and backup suites must pass **unchanged** — that is the proof
  this branch is UI-only.
- Device QA on the `lockout_qa` emulator (Android 16 / API 36, 1080x2400) before FINISH, per
  the pattern already recorded in `.spine/progress.md`, including the edge-to-edge
  navigation-bar inset check that caught `b42586d`.

## 11. Risks

| Risk | Mitigation |
|---|---|
| ~400 static colour call sites migrating to `context` | Staged per screen; the final grep-for-`Jinatra` step makes a partial migration impossible to miss |
| `dynamic_color` is Android-only and can return null | Option hidden when unavailable; saved selection resolves to Graphite |
| Large diff makes review hard | One task per screen, per-task review, plus the whole-branch review at the Review Gate |
| Font bundling grows the APK | Static weights only (~1-2 MB); measured and reported at FINISH |
| Test churn hides a real regression | Service/migration/backup suites are frozen — any change there is a scope violation |
| Deep widget nesting in `routines_tab.dart` (1451 lines) | The featured-day extraction is a genuine simplification; file expected to shrink |

## 12. Assumptions (stated, not asked)

- `food_tab_enabled` keeps its current behaviour; hiding Food yields a 4-tab bar.
- The 8-colour category ramp concept survives (day rails, action tiles) as a themed extension.
- No onboarding, no first-run theme prompt; Graphite dark is the default for a fresh install.
- The saved `theme_key` setting is reused; unknown legacy keys (e.g. `jinatra_cream`) map to
  the nearest new theme rather than erroring.
- Icons stay Material icons; no custom icon set is commissioned.
