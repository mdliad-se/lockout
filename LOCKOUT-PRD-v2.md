# Product Requirement Document — LOCKOUT

**Product**: LOCKOUT — offline strength training tracker
**Version**: 2.0 (supersedes 1.0.0)
**Platform**: Android 8.0+ (API 26), free and open source, distributed as a standalone APK
**Design system**: Jinatra Neubrutalist Product System v1.1
**Publisher**: Jinatra Ltd.
**Status**: Specification — pre-development

---

## 1. Product vision

LOCKOUT is a strength training tracker that works with no account, no network, and no third-party services. It starts empty: the user builds their own splits, their own exercises, their own targets. It logs what actually happened in the gym — weight, reps, volume, bodyweight, food — and gets out of the way.

A lockout is the completed end of a rep. The name is the promise: finish the set, log it, done.

### Product principles

1. **Offline is not a feature, it is the architecture.** No network calls exist in the codebase. The app requests no INTERNET permission.
2. **The user owns the data.** Everything is on-device and exportable to a plain JSON file at any time.
3. **Empty by default.** No stock routines, no exercise database, no suggested programmes. The user's first routine is the one they build.
4. **Free and open source.** GPL-3.0-or-later, reproducible builds, no proprietary dependencies, no analytics, no ads, no crash reporting.
5. **Neutral, not motivational.** The app reports facts. It does not shame missed sessions, prescribe calorie targets, or set weight goals on the user's behalf.

---

## 2. Out of scope

Explicitly not in this product, at any version:

- User accounts, cloud sync, or any server component
- Social features, sharing, leaderboards, or friend feeds
- Ads, sponsorships, in-app purchases, or upsells
- Analytics, telemetry, crash reporting, or any outbound request
- A bundled exercise or food database (both require licensing and/or network)
- AI coaching, form checking, or programme generation
- Wearable, heart-rate, or health-platform integrations
- Barcode scanning for food (requires a remote food database — incompatible with principle 1)

---

## 3. Responsible design constraints

These are requirements, not guidelines. Fitness trackers are used by people with complicated relationships to food and body weight, and the defaults matter.

- **Calorie and macro targets are user-entered only.** The app never calculates, recommends, or suggests a target, and never labels a target as a deficit, surplus, or maintenance figure.
- **No negative framing.** No "over budget" red states, no warnings for exceeding intake, no guilt copy. The calorie bar reports consumed versus target and stops there.
- **No goal weight field.** Body weight is logged and trended; it is not scored against a destination.
- **BMI is presented with context.** It is shown as one number among several, with a one-line note that it does not distinguish muscle from fat and is a poor fit for people who lift. Waist measurement and bodyweight trend are given equal or greater prominence.
- **Missed sessions are neutral.** Status is `logged`, `rescheduled`, or `skipped`. No streak-break animations, no scolding copy, no push notifications about inactivity.
- **Streaks tolerate rest.** See §6.5.
- **Nutrition tracking is optional and can be hidden entirely** from Settings, removing the tab for users who do not want to track food.

---

## 4. Design system application

LOCKOUT implements Jinatra Neubrutalist Product System v1.1. Sections 09–14 of that document govern; the rulings below resolve conflicts specific to a 360–430px Android viewport.

### 4.1 Colour

| Token | Hex | Role in LOCKOUT |
|---|---|---|
| Sweet Cream | `#FFEACF` | App canvas, every screen background |
| Paper | `#FFFFFF` | Card and input interiors, always inside an Ink border |
| Mist Teal | `#E0F0EE` | Secondary surfaces, alternating rows, completed-set fills |
| Deep Teal | `#0A756C` | Primary buttons, active tab, table headers, progress fills |
| Teal Deep | `#06554F` | Pressed state of Teal surfaces |
| Ink | `#1A1A1A` | Every border, every shadow, all body text |
| Signal | `#FF6B35` | Focus rings, rest-timer completion, one highlight per screen |

**Signal budget ruling.** The one-Signal-per-view rule applies to interactive chrome. The calendar grid is exempt as a data surface: missed days render as a diagonal Ink hatch on Cream, not as Signal fills, and Signal is used only for the single missed-day count badge above the grid.

**Contrast.** Body copy is Ink on Cream or Paper. Deep Teal is permitted for headings, links, and filled surfaces, never for text below 16sp.

**Dark mode.** Not in v1.0. The brand has no dark palette and inventing one ad hoc would fork the design system. If gym-lighting feedback demands it, it ships as a v1.2 brand supplement first (Ink canvas, Cream text, Signal unchanged) and only then as an app setting.

### 4.2 Structure on mobile

- Border radius `0dp` everywhere, no exceptions.
- Borders: `3dp` Ink on cards, buttons, inputs; `4dp` on modals and the active-session hero; `2dp` on internal dividers.
- Shadows: hard offset down-right, zero blur, zero spread. `3dp` controls, `6dp` cards, `10dp` the single hero element per screen.
- **Shadow safe area.** A shadow is part of the element's footprint. Screen gutters are `16dp` minimum, and no shadowed element may sit within `16dp` of another, so shadows never overlap a neighbouring border. At 360dp width, a full-width card is `16dp` inset left and `22dp` right (16 + 6 shadow).
- Spacing grid: 8dp — 8 / 16 / 24 / 32 / 48 / 64.
- Slab-in-slab drops its shadow and keeps only the border.

### 4.3 Interaction

- **Press**: element translates down-right by its shadow offset, shadow collapses to zero, 60ms. Default Android tap highlight and ripple are disabled everywhere.
- **Touch targets**: 48dp minimum regardless of visual size. Set-completion checkboxes render at 32dp with a 48dp hit area.
- **Focus**: `3dp` Signal outline, offset `3dp`, on every focusable control. Never removed.
- **Reduced motion**: when the system setting is on, state changes are instant — no translate, no transition — but remain visually distinct.
- **Transitions**: tabs switch instantly. No cross-fades, no slide, no shared-element animation.

### 4.4 Typography

Archivo (heavy, tracking −2%, line-height 1.02) for headings. Inter for body and controls. JetBrains Mono Bold for all numerals the user reads as data: weights, reps, volume, timers, dates, calories. Fonts are bundled in the APK under the SIL Open Font License; no runtime font download.

---

## 5. Information architecture

Five bottom-nav tabs plus a Settings screen reached from the header of any tab.

```
┌─────────────────────────────────────────┐
│  Header: screen title · [⚙ settings]    │
├─────────────────────────────────────────┤
│                                         │
│              Tab content                │
│                                         │
├─────────────────────────────────────────┤
│  ROUTINES │ TODAY │ FOOD │ BODY │ LOG   │
└─────────────────────────────────────────┘
```

Bottom nav: fixed, `3dp` Ink top border, Cream fill. Active tab is a filled Deep Teal block with Ink border and Cream label. Inactive labels are Ink. Signal is never used in the nav.

**Hardware back button** is explicitly handled on every screen. From a tab root it exits the app; from a nested screen it navigates up; from an active workout it opens a confirm dialog ("End this session? Logged sets are kept."). It never silently discards data.

---

## 6. Features

### 6.1 Tab 1 — Routines

Build and maintain training splits from an empty slate.

**Routine**
- Create, rename, duplicate, archive, delete. Deletion requires typed confirmation and does not remove historical logs.
- A routine contains an ordered list of training days.
- **Scheduling mode** is set per routine and is a data-model decision, not a display toggle:
  - `WEEKDAY` — days are pinned to days of the week (Saturday Push, Monday Legs).
  - `ROTATING` — days advance in sequence each time one is completed, independent of the calendar (Push → Pull → Legs → repeat), with an optional "rest day after N sessions".
- Only one routine is active at a time. Switching active routines does not alter history.

**Training day**
- Name and colour-free tag (`PUSH`, `LEGS-MODIFIED`), max 16 characters, mono uppercase.
- Three ordered sections, each optional: Warm-up, Main work, Finisher.

**Warm-up entry**: name, duration (mm:ss) or reps, optional note.

**Exercise entry**
- Name (free text, autocompletes from the user's own previously entered exercises).
- Target sets; target reps as a fixed number or a range (`8` or `8–12`).
- Target weight with unit; `bodyweight` and `assisted` are valid weight modes.
- Optional: note, rest duration default, form-video URL.
- **Form-video URL** opens in the system browser via an intent. No embedded player, no INTERNET permission, no preview fetch. Field is clearly labelled as opening an external app.

**Finisher entry**: rounds, exercise name, work duration, rest duration.

**Acceptance criteria**
- A user can go from a fresh install to a saved 5-day split with 6 exercises per day without ever seeing pre-filled content.
- Reordering exercises is drag-free: each row has explicit up/down controls (drag targets are unreliable inside a scrolling list at these border weights).
- Duplicating a routine copies all days, exercises, and targets, and appends `(copy)` to the name.

### 6.2 Tab 2 — Today

The live session. This is the screen the app is judged on.

**Pre-session**
- Shows today's scheduled day for the active routine, or a day picker if the routine is `ROTATING` or nothing is scheduled.
- "Start session" is the single `10dp`-shadow hero element on the screen.
- Any unfinished session from an earlier time is offered for resume before a new one can start.

**During the session**
- One exercise in focus at a time, with a compact list of the rest below.
- Per set: a completion checkbox, an actual-weight field, an actual-reps field. Fields pre-fill with the target, so a set that goes to plan is one tap.
- **Last-time reference.** Every exercise shows the same exercise's most recent logged session inline, in mono: `LAST: 60kg × 8, 8, 7 · 14 Nov`. This is a v1.0 requirement, not an enhancement.
- Running session volume (Σ weight × reps) displayed in the header, updating on each completed set.
- Optional per-set RPE (1–10) and a per-exercise note, both collapsed by default.
- Sets can be added or removed mid-exercise without editing the routine.
- Exercises can be skipped; skipped exercises are recorded as skipped, not deleted.

**Rest timer**
- Presets 30s / 60s / 90s / 120s plus a custom value, and a per-exercise default that auto-starts on set completion when configured.
- Large JetBrains Mono countdown on a `4dp`-bordered bar docked above the bottom nav; expandable to a full-screen modal.
- +15s / −15s / skip controls.
- **The timer is timestamp-based.** It stores an absolute end time and recomputes remaining time on every resume. It never relies on an interval loop surviving in the background.
- **Completion fires reliably even when the app is backgrounded or the screen is off**, via a scheduled notification plus vibration. Audio is optional and off by default (gyms have headphones).
- The screen stays awake for the duration of an active session, released when the session ends or is backgrounded.

**Session end**
- Summary: total volume, working sets completed, duration, per-exercise breakdown, and any new best (heaviest set, or highest volume for that exercise).
- Session is written to history and the calendar on save.

**Crash and interruption safety**
- Session state is persisted after every single mutation (set completed, weight edited, timer started). A process kill loses at most the keystroke in progress.
- On relaunch, an interrupted session is restored exactly, including remaining rest-timer time computed from its stored end timestamp.

**Acceptance criteria**
- Timer completion alert fires within 1s of target with the app backgrounded and the screen off, on a device with battery optimisation enabled.
- Force-stopping the app mid-session and reopening restores every logged set.
- A three-exercise, nine-set session can be completed with fewer than 25 taps when everything hits target.

### 6.3 Tab 3 — Food

Optional. Can be disabled in Settings, which removes the tab.

- **Meal log** by day, grouped into Breakfast / Lunch / Dinner / Snack (labels editable).
- **Entry**: name, serving size, calories, protein, carbs, fat. Only calories is mandatory.
- **Saved foods library.** Any logged entry can be saved with its macros and re-added in one tap, with a serving multiplier (`×0.5`, `×2`, custom). Without this the feature is unusable past the first week; it is a v1.0 requirement.
- **Saved meals**: a named group of saved foods logged together.
- **Calorie bar**: Deep Teal fill inside a `3dp` Ink border, consumed versus user-set target. Over target renders as a Mist Teal overflow segment, never red, with no warning copy.
- **Energy expenditure log**: manual entry only, plainly labelled as a user estimate. Never auto-subtracted from the calorie target; shown as a separate figure.
- Daily macro totals in mono, plus a 7-day average.

### 6.4 Tab 4 — Body

- **Bodyweight log** with automatic timestamps, one entry per day maximum (editable), unit follows the global setting.
- **Trend** over 30 / 90 / 365 days as a squared-off line chart: Ink axis, Teal line, no curve smoothing, no gradient fill.
- **Waist measurement** log, given equal prominence to weight.
- **BMI**: computed from height (set once in Settings) and latest weight, shown with its category and a permanent one-line caveat about muscle mass. Never used to trigger anything.
- **History table**: date, weight, waist, BMI, delta from previous entry.
- Optional additional measurements (chest, arm, thigh, hip), off by default.

### 6.5 Tab 5 — Log

- **Month calendar grid**: completed sessions render as filled Deep Teal cells with the day number in Cream; scheduled rest days as Mist Teal; skipped scheduled days as a diagonal Ink hatch on Cream; unscheduled days plain Cream.
- **Tap any date** to open the full archive for that day: every exercise, every set with actual weight and reps, total volume, session duration, notes.
- **Consistency counter**: consecutive weeks in which the user completed at least their configured minimum number of sessions (default 1). Weeks, not days — a rest day or a sick day cannot break it. A single missed week reduces the count; it does not zero it.
- **Rescheduling**: a scheduled day that was not trained can be marked `rescheduled` and moved to another date, or marked `skipped` with an optional reason. Both are neutral states in the UI.
- **Exercise history**: search any exercise by name and see every session it appears in, with a volume and top-set progression chart.
- **Personal bests** per exercise: heaviest set, best estimated 1RM (Epley, labelled as an estimate), highest session volume.

### 6.6 Settings

Reached from the header on every tab.

- Profile: height, units (kg/lb, cm/in) — a single global setting, applied at display time.
- Calorie and macro targets (user-entered, blank by default).
- Nutrition tab: on/off.
- Default rest duration.
- Timer: vibration on/off, sound on/off (default off), keep screen awake on/off.
- Week start day; **day rollover hour** (default 04:00, so a session logged at 01:00 belongs to the previous training day).
- Export data / Import data.
- Delete all data (typed confirmation).
- About: version, licence, source repository URL, third-party licences.

---

## 7. Data model

Canonical storage rules:

- **All weights are stored in kilograms** as a decimal, converted only for display. All lengths in centimetres.
- **All timestamps are stored as UTC epoch millis** plus the device's UTC offset at write time, so historical entries survive travel and DST.
- **A training date is derived**, not stored raw: it is the calendar date after applying the user's rollover hour.
- Every row carries `created_at` and `updated_at`.
- Deletes are soft where history depends on the row (exercises, routines); hard only for logs the user explicitly removes.

### Entities

```
Routine          id, name, scheduling_mode, is_active, archived_at
TrainingDay      id, routine_id, name, tag, order_index, weekday|sequence_index
WarmupItem       id, day_id, name, duration_s, reps, note, order_index
ExerciseDef      id, day_id, name, target_sets, target_reps_min, target_reps_max,
                 target_weight_kg, weight_mode, rest_default_s, note, video_url, order_index
FinisherItem     id, day_id, name, rounds, work_s, rest_s, order_index

Session          id, routine_id, day_id, started_at, ended_at, status, total_volume_kg, note
SessionExercise  id, session_id, exercise_name, order_index, status
SetLog           id, session_exercise_id, set_index, weight_kg, reps, rpe, is_warmup, completed_at

FoodEntry        id, training_date, meal_slot, name, serving, kcal, protein_g, carb_g, fat_g,
                 saved_food_id
SavedFood        id, name, serving, kcal, protein_g, carb_g, fat_g, use_count
SavedMeal        id, name  /  SavedMealItem  meal_id, saved_food_id, multiplier
BurnEntry        id, training_date, name, kcal, note

BodyEntry        id, training_date, weight_kg, waist_cm, extras_json
UserProfile      height_cm, unit_weight, unit_length, kcal_target, macro_targets,
                 week_start, rollover_hour, flags

DayStatus        training_date, routine_id, day_id, status  -- logged|rescheduled|skipped|rest
```

`SessionExercise` stores the **exercise name as text**, not a foreign key. Renaming or deleting an exercise definition must never rewrite or orphan history.

---

## 8. Storage and persistence

**SQLite via Room.** The v1.0 draft specified `localStorage`; that is replaced for four reasons: a ~5MB cap that years of set logs will exceed, string-only storage requiring full-collection serialisation on every write, synchronous writes that stall the frame during set logging, and eviction risk — Android may clear WebView storage under pressure, and some upgrade paths wipe it. Training history is not disposable data.

- All queries are asynchronous, exposed as observable flows.
- Writes during an active session are individually committed, never batched.
- Schema migrations are explicit and tested; no destructive fallback migration is permitted in a release build.
- Database file lives in app-private storage. No external storage read/write permission.

---

## 9. Backup, export, import

**Export**
- Single `.json` file, human-readable, containing every entity plus a header:
  `{ "app": "lockout", "schemaVersion": 3, "exportedAt": "...", "appVersion": "1.0.0", "data": { ... } }`
- Written via the Storage Access Framework so the user picks the destination. No storage permission required.
- Default filename `lockout-backup-YYYY-MM-DD.json`.
- Optional CSV export of set logs for spreadsheet users.

**Import**
- User picks a file; the app validates `app` and `schemaVersion` before touching the database.
- Older schema versions are migrated forward through the same migration chain as the database. A newer-than-supported version is rejected with a clear message naming the required app version.
- Two modes: **Replace** (wipes and restores, typed confirmation) and **Merge** (adds entries whose ids are absent, keeps existing on conflict).
- Import runs in a transaction. Any failure rolls back completely and leaves existing data untouched.

**Reminder**: Settings shows the date of the last export. If none has been taken in 60 days, a passive inline note appears on the Settings screen. No notification, no modal, no nag.

---

## 10. Non-functional requirements

**Performance**
- 60fps scrolling and interaction on a mid-range 2021 device; no frame budget overrun during set logging.
- Cold start to interactive under 1.5s.
- Tab switches instant (no animation to budget for).
- APK under 15MB.

**Permissions** — the full manifest list, and the reason each exists:
- `VIBRATE` — rest-timer completion.
- `POST_NOTIFICATIONS` (API 33+) — rest-timer completion only, requested at first timer use, never at launch.
- `SCHEDULE_EXACT_ALARM` or a foreground service, whichever proves reliable across OEM battery managers, for timer completion.
- **No `INTERNET`.** No storage permissions. No location, camera, contacts, or health permissions.

**Accessibility**
- Ink on Cream body text at 14:1.
- Every control 48dp minimum touch target, with content descriptions.
- Full TalkBack traversal of the live-session screen, including set state announcements.
- Respects system font scaling up to 200% without clipping — cards grow, they do not scroll internally.
- Respects reduced-motion.

**Localisation**
- English (en) at v1.0. All strings externalised from day one; no hardcoded text in layouts.
- Bengali (bn) as the first added locale.
- Numbers, dates, and units formatted per locale; the mono data typeface must render Bengali digits or fall back cleanly.

---

## 11. Build, licence, and distribution

### Stack

**Kotlin + Jetpack Compose + Room, built with Gradle.** This replaces the v1.0 draft's Capacitor/WebView approach. The reasons are specific to this product's goals rather than general preference:

- **Reproducible builds.** F-Droid builds from source with no network access at build time. A pure Gradle project is straightforward to make reproducible; a Node/npm dependency tree is the single most common cause of F-Droid build failures and rejections.
- **Background timer reliability.** Foreground services and exact alarms are first-class on native; WebView JS timers are throttled aggressively and the workarounds are fragile across OEM battery managers.
- **Frame budget.** The 60fps target with per-keystroke persistence is comfortable natively and marginal in a WebView.
- **Permission surface.** A native app can ship with genuinely zero network permissions. A WebView shell frequently drags `INTERNET` in through tooling defaults.

An alternative Capacitor specification is retained in Appendix A if this decision is reversed.

### Licence

- **GPL-3.0-or-later.** Copyleft keeps derivative forks open, which matters for a health-adjacent app where users are trusting the offline claim; it is also the licence F-Droid users most readily trust.
- `LICENSE`, `REUSE`-compliant headers, and a `NOTICE` listing bundled font licences (Archivo, Inter, JetBrains Mono — all SIL OFL).
- No dependency may be added without a licence check. No Google Play Services, no Firebase, no proprietary SDKs of any kind.

### Repository

```
/app                     Kotlin sources
/fastlane/metadata/android/en-US/
    title.txt  short_description.txt  full_description.txt
    images/icon.png  images/phoneScreenshots/*
    changelogs/<versionCode>.txt
/docs                    this PRD, design system reference
LICENSE  README.md  CHANGELOG.md
```

- `versionCode` is a monotonically increasing integer; `versionName` is semver.
- Every release is a signed git tag with a matching `fastlane` changelog entry.
- Reproducible-build settings pinned: fixed Gradle and AGP versions, `SOURCE_DATE_EPOCH` respected, no timestamps or build-host paths in the APK.
- CI builds the release APK from a clean checkout and publishes the SHA-256 in the release notes so users can verify what they install.

### Distribution path

1. **GitHub Releases** — signed APK plus SHA-256, from day one. Works immediately with Obtainium for auto-updates.
2. **IzzyOnDroid** — accepts APKs built from a public repo with far less friction than the main F-Droid repo. Realistic second step.
3. **F-Droid main repository** — submit once builds are demonstrably reproducible and metadata is stable. Expect a review period; treat it as a milestone, not a launch requirement.
4. **Accrescent** — optional, worth evaluating for its stricter update model.

Google Play is not a target. The app would need a privacy policy, data-safety declarations, and a developer account for a product that collects nothing.

---

## 12. Release scope

**v1.0 — must ship together**
Routines with both scheduling modes · live session with last-time reference · reliable background rest timer · session crash recovery · calendar with day archive · bodyweight and BMI · JSON export and import · settings · English.

**v1.1**
Saved meals · exercise history charts · personal bests · CSV export · plate calculator · Bengali locale.

**v1.2**
Programme templates the user can save and reuse across routines · deload week marking · optional dark palette, contingent on a Jinatra v1.2 brand supplement.

**Deliberately deferred until asked for**
Supersets and circuits as a first-class structure · interval timer for finishers · widget · Wear OS.

---

## 13. Open decisions

1. **Exercise definitions are currently scoped to a training day.** A shared exercise library across routines would reduce duplication but complicates the "clean slate" promise. Decide before writing migrations.
2. **Superset representation.** If it is likely by v1.2, the `SessionExercise` model should carry a `group_id` from v1.0 to avoid a painful migration later.
3. **Exact alarms vs foreground service** for timer completion — needs device testing on Xiaomi, Samsung, and Oppo battery managers before committing.
4. **Minimum API level.** 26 covers ~95% of devices; 24 adds coverage at the cost of notification and alarm compatibility branches.

---

## Appendix A — Capacitor alternative

If the WebView stack is retained, the following change relative to §11:

- Storage becomes SQLite via `@capacitor-community/sqlite`, not `localStorage` or IndexedDB. The §7 model and §8 rules apply unchanged.
- Required plugins: LocalNotifications (timer completion), Haptics (vibration), KeepAwake (session), App (hardware back interception, resume events), Filesystem + Share (export), Browser (form-video links).
- Hardware back must be intercepted explicitly on every route; the default behaviour exits the app.
- Audio must be unlocked by a user gesture; prime it on session start.
- Vendor `node_modules` or pin exact versions with integrity hashes if F-Droid inclusion is still intended, and expect a longer review.
- Verify that no plugin pulls `INTERNET` into the merged manifest — check the built APK, not the source.

---

*LOCKOUT is a Jinatra product. Interface specification governed by Jinatra Neubrutalist Product System v1.1.*
