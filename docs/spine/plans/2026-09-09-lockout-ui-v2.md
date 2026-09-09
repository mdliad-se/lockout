# Lockout UI v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-dev (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild all five tabs of the Lockout Flutter app on a rounded neubrutalist design system v2, and fix three defects: duplicate training-day colours, missing calories-burned data, and a food search that cannot find items it already holds.

**Architecture:** Design tokens and an authored 8-colour accent ramp land first (Task 1), then five shared widgets built on them (Task 2). Every screen then consumes that vocabulary, so the layout work is additive rather than five parallel reinventions. The three defect fixes are pure-Dart modules behind small seams (`DayColours`, `EnergyEstimator`, `TextSearch`) so they are unit-testable without pumping a widget.

**Tech Stack:** Flutter 3.x / Dart, sqflite (schema version 3 → 4), google_fonts, flutter_test. No network at runtime beyond google_fonts' own font fetch (pre-existing).

## Global Constraints

- Design spec: `docs/spine/specs/2026-09-09-lockout-ui-v2-design.md`. It is authoritative; this plan implements it.
- Test runner: `C:\src\flutter\bin\flutter.bat test --concurrency=1`. **Serial is mandatory** — the suites share one sqflite file and the default parallel run yields ~10 spurious failures. Baseline at `73c35e9`: **91 passed**.
- Flutter is NOT on PATH. Always invoke `C:\src\flutter\bin\flutter.bat` by absolute path.
- Radius tokens: card `14.0`, tile `12.0`, pill `999.0`. Border `3.0` ink. Shadows stay zero-blur at `3/6/10`.
- Colours resolve through `AppPalette.current` at build time. Never store a palette colour in a `const`, and never hardcode a hex in a widget — a theme switch must repaint everything.
- Every palette authors exactly **8** accents. Hue derivation by HSL rotation is deleted, not kept as a fallback.
- Estimated numbers are always rendered with a `~` prefix.
- The daily calorie target is never adjusted by workout burn.
- Migrations use `_addColumnIfMissing`. No destructive table recreate, ever.
- Labels are uppercase mono (`JinatraTokens.monoData`); headings use `displayHeader`/`sectionHeader`; body copy uses `bodyText`.
- Widget tests MUST disable google_fonts runtime fetching in `setUpAll`:
  `GoogleFonts.config.allowRuntimeFetching = false;`
- Tests that touch the database MUST bootstrap ffi in `setUpAll`:
  `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`
- Commit after every task. Conventional commit prefixes: `feat:`, `fix:`, `refactor:`, `test:`.

---

## File Structure and Seams

| File | Responsibility | Seam (the interface callers depend on) |
|---|---|---|
| `lib/theme/app_palette.dart` (modify) | Palette data, now including an authored accent ramp | `AppPalette.accents` → `List<Color>` of exactly 8 |
| `lib/theme/jinatra_tokens.dart` (modify) | Token lookup over the active palette | `radiusCard/radiusTile/radiusPill`, `cardDecoration({radius})`, `accents`, `onAccentColor(Color)` |
| `lib/widgets/hero_card.dart` (create) | The one saturated block per screen | `HeroCard({eyebrow, title, subtitle, background, actions})` |
| `lib/widgets/action_grid.dart` (create) | Coloured menu of destinations | `ActionItem(label, icon, color, onTap)`, `ActionGrid({items, columns})` |
| `lib/widgets/calm_row.dart` (create) | Low-emphasis navigable row | `CalmRow({icon, title, value, onTap, iconBackground})` |
| `lib/widgets/stat_tile.dart` (create) | Small bordered metric | `StatTile({label, value, background})` |
| `lib/widgets/sheet_scaffold.dart` (create) | Standard bottom sheet chrome | `showJinatraSheet<T>({context, title, builder})` |
| `lib/widgets/home_hub.dart` (create) | HOME's presentation, no data access | `HomeHubSummary`, `HomeHub({eyebrow, title, heroColor, summary, actions, …})` |
| `lib/widgets/day_row.dart` (create) | One compact day in the training week | `dayRowSummary(TrainingDay)`, `DayRow({day, accent, summary, isToday, onTap})` |
| `lib/widgets/progress_hero.dart` (create) | Hero whose subject is a proportion | `ProgressHero({eyebrow, title, subtitle, progress, background})` |
| `lib/widgets/meal_section.dart` (create) | One meal's entries with a subtotal | `mealSubtotalKcal(List<FoodEntry>)`, `MealSection({title, entries, onDelete})` |
| `lib/widgets/sparkline.dart` (create) | Minimal trend line, no axes | `sparklineNormalise(List<double>)`, `Sparkline({values, lineColor, height, strokeWidth})` |
| `lib/widgets/day_block.dart` (modify) | Day colour assignment | `DayColours.assign(List<TrainingDay>)` → `Map<String, Color>`; `DayColours.onColorFor(Color)` |
| `lib/services/energy_estimator.dart` (create) | Energy cost of a session | `EnergyEstimator.estimate({sets, dayName, bodyweightKg, durationSeconds})` → `double?` |
| `lib/data/food_search.dart` (create) | Normalising, alias-aware, typo-tolerant matching | `TextSearch.*`, `searchFoods(String)`, `searchExercises(String)` |
| `lib/models/models.dart` (modify) | `SessionLog.kcalBurned` | field + map round-trip |
| `lib/services/database_service.dart` (modify) | Schema version 4 | `_upgradeDB` adds `session_logs.kcal_burned` |

Each task's **Interfaces: Produces** block below is the committed seam. An implementer may choose the implementation behind it; renaming anything in that block requires updating this plan.

---

### Task 1: Design system v2 — radius tokens and authored accent ramps

**Files:**
- Modify: `lib/theme/app_palette.dart` (add `accents` to the class and to all 8 palette constants)
- Modify: `lib/theme/jinatra_tokens.dart` (radius tokens, `cardDecoration` radius parameter, `accents`, `onAccentColor`)
- Test: `test/theme_tokens_test.dart` (create)

**Interfaces:**
- Consumes: nothing — this is the first task.
- Produces:
  - `AppPalette.accents` → `List<Color>`, exactly 8 entries, required in the constructor.
  - `JinatraTokens.radiusCard = 14.0`, `JinatraTokens.radiusTile = 12.0`, `JinatraTokens.radiusPill = 999.0`.
  - `JinatraTokens.cardDecoration({Color? background, Color? borderColor, double borderWidth, double shadowOffset, bool hasShadow, double radius})` — `radius` defaults to `radiusCard`.
  - `JinatraTokens.accents` → `List<Color>`; `JinatraTokens.accentAt(int index)` → `Color` (wraps).
  - `JinatraTokens.onAccentColor(Color background)` → `Color` — `#111111` or `#FFFFFF`, whichever has higher WCAG contrast.

- [ ] **Step 1: Write the failing test**

Create `test/theme_tokens_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';

/// WCAG relative-contrast ratio, so "is this label readable" is a number
/// rather than an opinion.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Accent ramp', () {
    test('every palette authors exactly eight accents', () {
      for (final p in AppPalette.all) {
        expect(p.accents.length, 8, reason: p.key);
      }
    });

    test('accents within a palette are distinct', () {
      for (final p in AppPalette.all) {
        final values = p.accents.map((c) => c.toARGB32()).toList();
        expect(values.toSet().length, values.length, reason: p.key);
      }
    });

    test('every accent can carry a readable label', () {
      for (final p in AppPalette.all) {
        for (final accent in p.accents) {
          final on = JinatraTokens.onAccentColor(accent);
          expect(
            _contrast(accent, on),
            greaterThanOrEqualTo(3.0),
            reason: '${p.key} ${accent.toARGB32().toRadixString(16)}',
          );
        }
      }
    });

    test('accents follow the active palette', () {
      AppPalette.apply(AppPalette.paperPress);
      expect(JinatraTokens.accents, AppPalette.paperPress.accents);
      AppPalette.apply(AppPalette.voidMagenta);
      expect(JinatraTokens.accents, AppPalette.voidMagenta.accents);
      AppPalette.apply(AppPalette.fallback);
    });

    test('accentAt wraps past the end of the ramp', () {
      AppPalette.apply(AppPalette.paperPress);
      expect(JinatraTokens.accentAt(8), JinatraTokens.accentAt(0));
      expect(JinatraTokens.accentAt(11), JinatraTokens.accentAt(3));
    });

    test('on-accent picks the higher-contrast of ink-black and white', () {
      expect(JinatraTokens.onAccentColor(const Color(0xFFFFE24A)),
          const Color(0xFF111111));
      expect(JinatraTokens.onAccentColor(const Color(0xFF1E44D6)),
          const Color(0xFFFFFFFF));
    });
  });

  group('Radius tokens', () {
    test('v2 radii are the pinned values', () {
      expect(JinatraTokens.radiusCard, 14.0);
      expect(JinatraTokens.radiusTile, 12.0);
      expect(JinatraTokens.radiusPill, 999.0);
    });

    test('cardDecoration rounds to the card radius by default', () {
      final d = JinatraTokens.cardDecoration();
      expect(d.borderRadius, BorderRadius.circular(JinatraTokens.radiusCard));
    });

    test('cardDecoration honours an explicit radius', () {
      final d = JinatraTokens.cardDecoration(radius: JinatraTokens.radiusTile);
      expect(d.borderRadius, BorderRadius.circular(JinatraTokens.radiusTile));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/theme_tokens_test.dart`
Expected: FAIL — compile error, `The getter 'accents' isn't defined for the class 'AppPalette'`, plus `radiusCard`, `accentAt` and `onAccentColor` undefined.

- [ ] **Step 3: Add the accent field to AppPalette**

In `lib/theme/app_palette.dart`, add the field directly after the `onAccent` declaration:

```dart
  /// Eight authored colours used wherever many categories must be told apart
  /// at a glance: training-day rails, the HOME action grid, category chips.
  ///
  /// Authored rather than derived. Rotating a single primary through HSL
  /// produced collisions — two same-category days landed on one hue — and
  /// muddy mid-tones in several themes, so each palette states its own ramp.
  final List<Color> accents;
```

Add to the constructor, immediately after `required this.onAccent,`:

```dart
    required this.accents,
```

- [ ] **Step 4: Author the ramp for all eight palettes**

Add an `accents:` entry to each palette constant, after its `onAccent:` line.

`jinatraCream`:

```dart
    accents: [
      Color(0xFF0A756C), // teal
      Color(0xFFFF6B35), // coral
      Color(0xFFF2B01E), // amber
      Color(0xFF3E7D3A), // green
      Color(0xFF2B59FF), // blue
      Color(0xFFA64BC4), // purple
      Color(0xFFE0447E), // pink
      Color(0xFF17A2B8), // cyan
    ],
```

`paperPress`:

```dart
    accents: [
      Color(0xFFE23A2E), // red
      Color(0xFFFFE24A), // yellow
      Color(0xFFB6F53C), // lime
      Color(0xFF2CE0D4), // cyan
      Color(0xFF2B59FF), // blue
      Color(0xFFC77DFF), // purple
      Color(0xFFFF7AC4), // pink
      Color(0xFFFF8A3D), // orange
    ],
```

`mintLab`:

```dart
    accents: [
      Color(0xFF6C3FD4), // purple
      Color(0xFFB6F53C), // lime
      Color(0xFF00A5A5), // teal
      Color(0xFFFF5C8A), // pink
      Color(0xFFFFB020), // amber
      Color(0xFF2B6CFF), // blue
      Color(0xFF38B000), // green
      Color(0xFFFF6B35), // orange
    ],
```

`sunblock`:

```dart
    accents: [
      Color(0xFF1E44D6), // blue
      Color(0xFFFF3D9A), // pink
      Color(0xFF00A98F), // teal
      Color(0xFFFF8A00), // orange
      Color(0xFF7B2FF2), // purple
      Color(0xFFE23A2E), // red
      Color(0xFF2CB67D), // green
      Color(0xFF0FA3B1), // cyan
    ],
```

`carbonLime`:

```dart
    accents: [
      Color(0xFFB6F53C), // lime
      Color(0xFFFF6B35), // orange
      Color(0xFF2CE0D4), // cyan
      Color(0xFFFFD23F), // yellow
      Color(0xFFFF4D8D), // pink
      Color(0xFF9D7BFF), // violet
      Color(0xFF4CC9F0), // sky
      Color(0xFF7CD97C), // green
    ],
```

`midnightCyan`:

```dart
    accents: [
      Color(0xFF2CE0D4), // cyan
      Color(0xFFFF4D8D), // pink
      Color(0xFFFFC53D), // amber
      Color(0xFF7BD3FF), // sky
      Color(0xFFA78BFA), // violet
      Color(0xFF4ADE80), // green
      Color(0xFFFB923C), // orange
      Color(0xFFD4D700), // citron
    ],
```

`ashAmber`:

```dart
    accents: [
      Color(0xFFFFB020), // amber
      Color(0xFFFF4D4D), // red
      Color(0xFFA3E635), // lime
      Color(0xFF22D3EE), // cyan
      Color(0xFF93C5FD), // blue
      Color(0xFFC4B5FD), // violet
      Color(0xFFFDA4AF), // rose
      Color(0xFF6EE7B7), // mint
    ],
```

`voidMagenta`:

```dart
    accents: [
      Color(0xFFFF2BD1), // magenta
      Color(0xFF25F4EE), // cyan
      Color(0xFFFFE347), // yellow
      Color(0xFF7CFF6B), // green
      Color(0xFF6B8CFF), // blue
      Color(0xFFFF8A3D), // orange
      Color(0xFFC77DFF), // purple
      Color(0xFFFF5C7A), // rose
    ],
```

- [ ] **Step 5: Add radius tokens and accent helpers to JinatraTokens**

In `lib/theme/jinatra_tokens.dart`, insert directly above the `// Border & Shadow Dimensions` comment:

```dart
  // Corner Radii (v2). v1 was square at every scale; the rounded set is what
  // separates "clean neubrutalism" from "harsh". Border and shadow are
  // unchanged, so the style still reads as neubrutalist rather than material.
  static const double radiusCard = 14.0; // cards, sheets, hero blocks
  static const double radiusTile = 12.0; // action tiles, day rails, chips
  static const double radiusPill = 999.0; // buttons, toggles, active nav tile
```

Insert after `static bool get isDark => AppPalette.current.isDark;`:

```dart
  /// The active palette's authored eight-colour ramp.
  static List<Color> get accents => AppPalette.current.accents;

  /// The accent at [index], wrapping, so a caller with more than eight
  /// categories degrades to reuse instead of throwing.
  static Color accentAt(int index) {
    final ramp = accents;
    return ramp[index % ramp.length];
  }

  /// Label colour for content sitting on an arbitrary [background].
  ///
  /// Picks whichever of near-black and white has the higher WCAG contrast,
  /// rather than testing luminance against a fixed threshold: a mid-tone like
  /// coral (#FF6B35) sits below any sensible threshold yet still needs dark
  /// text, and a single threshold gets that case wrong.
  static const Color _onAccentDark = Color(0xFF111111);
  static const Color _onAccentLight = Color(0xFFFFFFFF);

  // Computed once, not hardcoded: an eyeballed constant here silently picked
  // white for #E23A2E when near-black scores higher.
  static final double _darkLuminance = _onAccentDark.computeLuminance();
  static final double _lightLuminance = _onAccentLight.computeLuminance();

  static double _contrastRatio(double a, double b) {
    final hi = a > b ? a : b;
    final lo = a > b ? b : a;
    return (hi + 0.05) / (lo + 0.05);
  }

  static Color onAccentColor(Color background) {
    final l = background.computeLuminance();
    final onDark = _contrastRatio(l, _darkLuminance);
    final onLight = _contrastRatio(l, _lightLuminance);
    return onDark >= onLight ? _onAccentDark : _onAccentLight;
  }
```

- [ ] **Step 6: Give cardDecoration a radius**

Replace the whole `cardDecoration` method in `lib/theme/jinatra_tokens.dart` with:

```dart
  // Standard Neubrutalist Box Decoration
  static BoxDecoration cardDecoration({
    Color? background,
    Color? borderColor,
    double borderWidth = borderControl,
    double shadowOffset = shadowMd,
    bool hasShadow = true,
    double radius = radiusCard,
  }) {
    return BoxDecoration(
      color: background ?? paper,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? ink, width: borderWidth),
      boxShadow: hasShadow ? [hardShadow(offset: shadowOffset)] : null,
    );
  }
```

- [ ] **Step 7: Run the new test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/theme_tokens_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 8: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 91 existing + 9 new = 100 tests. If `test/phase2_test.dart` fails to compile because it builds an `AppPalette` inline, give that construction an 8-colour `accents` list; do not make the field optional.

- [ ] **Step 9: Commit**

```bash
git add lib/theme/app_palette.dart lib/theme/jinatra_tokens.dart test/theme_tokens_test.dart
git commit -m "feat(theme): v2 radius tokens and authored 8-colour accent ramps"
```

---

### Task 2: Shared v2 widgets

**Files:**
- Create: `lib/widgets/hero_card.dart`
- Create: `lib/widgets/action_grid.dart`
- Create: `lib/widgets/calm_row.dart`
- Create: `lib/widgets/stat_tile.dart`
- Create: `lib/widgets/sheet_scaffold.dart`
- Modify: `lib/widgets/jinatra_button.dart` (pill radius)
- Modify: `lib/widgets/jinatra_card.dart` (radius passthrough)
- Modify: `lib/widgets/jinatra_input.dart` (tile radius)
- Test: `test/widgets_v2_test.dart` (create)

**Interfaces:**
- Consumes: `JinatraTokens.radiusCard/radiusTile/radiusPill`, `JinatraTokens.accentAt(int)`, `JinatraTokens.onAccentColor(Color)` from Task 1.
- Produces:
  - `HeroCard({Key? key, required String eyebrow, required String title, String? subtitle, required Color background, List<Widget> actions = const []})`
  - `ActionItem({required String label, required IconData icon, required Color color, required VoidCallback onTap})`
  - `ActionGrid({Key? key, required List<ActionItem> items, int columns = 4})`, `ActionTile({required ActionItem item})`
  - `CalmRow({Key? key, required IconData icon, required String title, String? value, VoidCallback? onTap, Color? iconBackground})`
  - `StatTile({Key? key, required String label, required String value, Color? background})`
  - `SheetScaffold({Key? key, required String title, required Widget child, Widget? footer})`
  - `Future<T?> showJinatraSheet<T>({required BuildContext context, required String title, required WidgetBuilder builder})`
  - `JinatraCard` gains `double radius` (default `JinatraTokens.radiusCard`).

- [ ] **Step 1: Write the failing test**

Create `test/widgets_v2_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';
import 'package:lockout/widgets/stat_tile.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  setUpAll(() {
    // A widget test must never reach the network for a font file.
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  testWidgets('HeroCard renders eyebrow, title, subtitle and actions',
      (tester) async {
    await tester.pumpWidget(_host(HeroCard(
      eyebrow: 'TODAY - MON',
      title: 'LEGS',
      subtitle: '4 EX - 12 SETS',
      background: JinatraTokens.accentAt(0),
      actions: [
        ElevatedButton(onPressed: () {}, child: const Text('START')),
      ],
    )));

    expect(find.text('TODAY - MON'), findsOneWidget);
    expect(find.text('LEGS'), findsOneWidget);
    expect(find.text('4 EX - 12 SETS'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('ActionGrid renders one tile per item and fires onTap',
      (tester) async {
    var tapped = '';
    final items = List.generate(
      8,
      (i) => ActionItem(
        label: 'ACT$i',
        icon: Icons.circle,
        color: JinatraTokens.accentAt(i),
        onTap: () => tapped = 'ACT$i',
      ),
    );

    await tester.pumpWidget(_host(ActionGrid(items: items)));

    expect(find.byType(ActionTile), findsNWidgets(8));
    await tester.tap(find.text('ACT5'));
    expect(tapped, 'ACT5');
  });

  testWidgets('CalmRow shows a value and is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(CalmRow(
      icon: Icons.restaurant,
      title: 'CALORIES',
      value: '1240 / 1850',
      onTap: () => tapped = true,
    )));

    expect(find.text('CALORIES'), findsOneWidget);
    expect(find.text('1240 / 1850'), findsOneWidget);
    await tester.tap(find.byType(CalmRow));
    expect(tapped, isTrue);
  });

  testWidgets('StatTile shows label and value', (tester) async {
    await tester.pumpWidget(_host(
      const StatTile(label: 'BMI', value: '23.4'),
    ));
    expect(find.text('BMI'), findsOneWidget);
    expect(find.text('23.4'), findsOneWidget);
  });

  testWidgets('showJinatraSheet presents a titled sheet and returns a value',
      (tester) async {
    String? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showJinatraSheet<String>(
                context: ctx,
                title: 'LOG FOOD',
                builder: (sheetCtx) => TextButton(
                  onPressed: () => Navigator.pop(sheetCtx, 'saved'),
                  child: const Text('SAVE'),
                ),
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(SheetScaffold), findsOneWidget);
    expect(find.text('LOG FOOD'), findsOneWidget);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(result, 'saved');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/widgets_v2_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/widgets/hero_card.dart'`, and the same for the other four new files.

- [ ] **Step 3: Create HeroCard**

Create `lib/widgets/hero_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// The single saturated block a screen is allowed.
///
/// v1 gave several blocks per screen a filled accent, which is why the app
/// read as noisy: nothing was clearly the most important thing. Exactly one
/// HeroCard per screen is the rule the rest of the layout hangs off.
class HeroCard extends StatelessWidget {
  /// Small mono label above the title — context, not content.
  final String eyebrow;

  /// The one thing this screen is about.
  final String title;

  /// Optional mono detail line under the title.
  final String? subtitle;

  /// Saturated fill, normally `JinatraTokens.accentAt(n)`.
  final Color background;

  /// Pill actions laid out in a wrap under the text.
  final List<Widget> actions;

  const HeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.background,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final on = JinatraTokens.onAccentColor(background);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: JinatraTokens.cardDecoration(
        background: background,
        shadowOffset: JinatraTokens.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: on.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: JinatraTokens.displayHeader(fontSize: 30, color: on),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: JinatraTokens.monoData(
                fontSize: 12,
                color: on.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Create ActionGrid**

Create `lib/widgets/action_grid.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// One destination in the quick-action grid.
class ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// A grid of coloured tiles.
///
/// The one place many saturated colours are allowed at once: this is a menu,
/// not content, so colour identifies rather than competes for attention.
class ActionGrid extends StatelessWidget {
  final List<ActionItem> items;
  final int columns;

  const ActionGrid({super.key, required this.items, this.columns = 4});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: items.map((i) => ActionTile(item: i)).toList(),
    );
  }
}

/// A single tile. Stateful only to carry the press-in shadow collapse that
/// every neubrutalist control in this app shares.
class ActionTile extends StatefulWidget {
  final ActionItem item;

  const ActionTile({super.key, required this.item});

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final on = JinatraTokens.onAccentColor(widget.item.color);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.item.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(
          _pressed ? 3.0 : 0.0,
          _pressed ? 3.0 : 0.0,
          0.0,
        ),
        decoration: JinatraTokens.cardDecoration(
          background: widget.item.color,
          shadowOffset: _pressed ? 0.0 : JinatraTokens.shadowSm,
          radius: JinatraTokens.radiusTile,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.item.icon, size: 24, color: on),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                widget.item.label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: JinatraTokens.monoData(fontSize: 9, color: on),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create CalmRow**

Create `lib/widgets/calm_row.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// A low-emphasis navigable row: icon box, title, optional value, chevron.
///
/// This is what secondary information looks like in v2. It replaces the
/// filled cards v1 used for everything, which is what made the hierarchy
/// unreadable.
class CalmRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  /// Defaults to the palette's secondary surface. Pass an accent only when
  /// the row genuinely needs identifying, which is rare.
  final Color? iconBackground;

  const CalmRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = iconBackground ?? JinatraTokens.mistTeal;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: JinatraTokens.cardDecoration(
          shadowOffset: JinatraTokens.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: JinatraTokens.cardDecoration(
                background: iconBg,
                borderWidth: JinatraTokens.borderDivider,
                hasShadow: false,
                radius: JinatraTokens.radiusTile,
              ),
              child: Icon(
                icon,
                size: 20,
                color: JinatraTokens.onAccentColor(iconBg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: JinatraTokens.monoData(fontSize: 12),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: JinatraTokens.monoData(
                  fontSize: 13,
                  color: JinatraTokens.deepTeal,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: JinatraTokens.ink.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create StatTile**

Create `lib/widgets/stat_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// A small bordered metric: mono label above a mono value.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? background;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? JinatraTokens.paper;
    final on = JinatraTokens.onAccentColor(bg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: JinatraTokens.cardDecoration(
        background: bg,
        borderWidth: JinatraTokens.borderDivider,
        shadowOffset: JinatraTokens.shadowSm,
        radius: JinatraTokens.radiusTile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 9,
              color: on.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: JinatraTokens.monoData(fontSize: 16, color: on),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Create SheetScaffold**

Create `lib/widgets/sheet_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// Standard chrome for every form in the app.
///
/// v1 put creation forms inline at the top of a screen, so a screen showed a
/// form the user was not filling in above the content they came to read.
/// Forms live in sheets now; the content is the page.
class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;

  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    // maybeOf, not of: the keyboard inset is a nicety, and a sheet built
    // outside showJinatraSheet must not crash for want of a MediaQuery.
    final inset = MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0;

    return Container(
      padding: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: JinatraTokens.paper,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(JinatraTokens.radiusCard),
        ),
        border: Border(
          top: BorderSide(
            color: JinatraTokens.ink,
            width: JinatraTokens.borderControl,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: JinatraTokens.sectionHeader(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: JinatraTokens.ink),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens [builder] inside a [SheetScaffold]. Returns whatever the sheet pops.
Future<T?> showJinatraSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SheetScaffold(title: title, child: builder(ctx)),
  );
}
```

- [ ] **Step 8: Round the existing primitives**

In `lib/widgets/jinatra_button.dart`, replace `borderRadius: BorderRadius.zero,` with:

```dart
          borderRadius: BorderRadius.circular(JinatraTokens.radiusPill),
```

In `lib/widgets/jinatra_card.dart`, add a field after `margin`:

```dart
  final double radius;
```

add to the constructor after `this.margin = const EdgeInsets.only(bottom: 16),`:

```dart
    this.radius = JinatraTokens.radiusCard,
```

and pass it through in `build`:

```dart
      decoration: JinatraTokens.cardDecoration(
        background: background,
        shadowOffset: shadowOffset,
        radius: radius,
      ),
```

In `lib/widgets/jinatra_input.dart`, run `grep -n "BorderRadius.zero" lib/widgets/jinatra_input.dart` and replace every hit with `BorderRadius.circular(JinatraTokens.radiusTile)`.

- [ ] **Step 9: Sweep the remaining square corners**

Run: `grep -rn "BorderRadius.zero" lib/`
Replace each remaining hit: `JinatraTokens.radiusTile` for chips, rails and small controls; `JinatraTokens.radiusCard` for anything card-sized. Mechanical, no behaviour change.

- [ ] **Step 10: Run the new test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/widgets_v2_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 11: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 105 tests.

- [ ] **Step 12: Commit**

```bash
git add lib/widgets test/widgets_v2_test.dart
git commit -m "feat(ui): shared v2 widgets - hero card, action grid, calm row, stat tile, sheet"
```

---

### Task 3: Day colours — unique per day, category-seeded

This is the fix for the reported defect: WED "Upper Body + Core" and THU "Upper Body" both render magenta because `DayPalette._categoryOf` collapses both to category 5 and `forDay` derives the hue from the category alone.

**Files:**
- Modify: `lib/widgets/day_block.dart` (replace `DayPalette` with `DayColours`)
- Modify: `lib/screens/routines_tab.dart:922-930` (the `_buildDayCard` call sites)
- Test: `test/day_colours_test.dart` (create)

**Interfaces:**
- Consumes: `JinatraTokens.accents`, `JinatraTokens.accentAt(int)`, `JinatraTokens.onAccentColor(Color)`, `JinatraTokens.mistTeal` from Task 1.
- Produces:
  - `DayColours.categoryOf(TrainingDay day)` → `int` in `0..5`
  - `DayColours.assign(List<TrainingDay> days)` → `Map<String, Color>` keyed by `TrainingDay.id`; every day in the list gets an entry
  - `DayColours.onColorFor(Color background)` → `Color`
  - `DayColours.restColour` → `Color`
- Removed: `DayPalette.forDay(TrainingDay)`, `DayPalette.onColorFor(TrainingDay)`. Any caller must migrate; `grep -rn "DayPalette" lib/ test/` finds them all (currently two lines in `routines_tab.dart`).

- [ ] **Step 1: Write the failing test**

Create `test/day_colours_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';
import 'package:lockout/widgets/day_block.dart';

TrainingDay _day(
  String id,
  String name, {
  String focus = '',
  bool rest = false,
  int order = 0,
}) =>
    TrainingDay(
      id: id,
      routineId: 'r1',
      name: name,
      tag: id,
      orderIndex: order,
      focus: focus,
      isRestDay: rest,
    );

/// The exact week from the bug report.
List<TrainingDay> _reportedWeek() => [
      _day('sat', 'Push', focus: 'Chest, Shoulders, Triceps', order: 0),
      _day('sun', 'Pull', focus: 'Back, Biceps', order: 1),
      _day('mon', 'Legs', focus: 'Legs', order: 2),
      _day('tue', 'Rest', rest: true, order: 3),
      _day('wed', 'Upper Body + Core', focus: 'Upper Body', order: 4),
      _day('thu', 'Upper Body', focus: 'Upper-focused, light hip-hinge', order: 5),
      _day('fri', 'Off', rest: true, order: 6),
    ];

void main() {
  setUp(() => AppPalette.apply(AppPalette.paperPress));

  group('DayColours.assign', () {
    test('every day in the list gets a colour', () {
      final colours = DayColours.assign(_reportedWeek());
      expect(colours.length, 7);
      for (final d in _reportedWeek()) {
        expect(colours.containsKey(d.id), isTrue, reason: d.id);
      }
    });

    test('the reported WED/THU collision is gone', () {
      final colours = DayColours.assign(_reportedWeek());
      expect(colours['wed'], isNot(colours['thu']));
    });

    test('all training days in a week are distinct', () {
      final colours = DayColours.assign(_reportedWeek());
      final training = _reportedWeek().where((d) => !d.isRestDay);
      final used = training.map((d) => colours[d.id]).toList();
      expect(used.toSet().length, used.length);
    });

    test('rest days take the muted surface and consume no accent', () {
      final week = _reportedWeek();
      final colours = DayColours.assign(week);
      expect(colours['tue'], DayColours.restColour);
      expect(colours['fri'], DayColours.restColour);

      // Five accents remain available to five training days, so a week of
      // five training days never has to reuse one.
      final training = week.where((d) => !d.isRestDay);
      final used = training.map((d) => colours[d.id]).toSet();
      expect(used.contains(DayColours.restColour), isFalse);
    });

    test('a day keeps its category colour when nothing else claims it', () {
      final colours = DayColours.assign(_reportedWeek());
      expect(colours['sat'], JinatraTokens.accentAt(DayColours.categoryOf(
        _day('sat', 'Push', focus: 'Chest, Shoulders, Triceps'),
      )));
    });

    test('assignment is deterministic across calls', () {
      final a = DayColours.assign(_reportedWeek());
      final b = DayColours.assign(_reportedWeek());
      expect(a, b);
    });

    test('more than eight training days wraps instead of throwing', () {
      final days = List.generate(
        11,
        (i) => _day('d$i', 'Session $i', focus: 'Full Body', order: i),
      );
      final colours = DayColours.assign(days);
      expect(colours.length, 11);
    });

    test('two routines each start from their own category colour', () {
      final routineA = [_day('a1', 'Legs', focus: 'Legs')];
      final routineB = [_day('b1', 'Legs', focus: 'Legs')];
      expect(
        DayColours.assign(routineA)['a1'],
        DayColours.assign(routineB)['b1'],
      );
    });
  });

  group('DayColours.categoryOf', () {
    test('recognises the six session families', () {
      expect(DayColours.categoryOf(_day('1', 'Push', focus: 'Chest')), 0);
      expect(DayColours.categoryOf(_day('2', 'Pull', focus: 'Back')), 1);
      expect(DayColours.categoryOf(_day('3', 'Legs', focus: 'Quads')), 2);
      expect(DayColours.categoryOf(_day('4', 'Shoulders', focus: 'Delts')), 3);
      expect(DayColours.categoryOf(_day('5', 'Arms', focus: 'Triceps')), 4);
      expect(DayColours.categoryOf(_day('6', 'Upper Body', focus: 'Upper')), 5);
    });

    test('an unrecognised name still returns a stable category', () {
      final d = _day('7', 'Conditioning', focus: 'Mixed');
      expect(DayColours.categoryOf(d), DayColours.categoryOf(d));
      expect(DayColours.categoryOf(d), inInclusiveRange(0, 5));
    });
  });

  group('DayColours.onColorFor', () {
    test('delegates to the token contrast rule', () {
      const yellow = Color(0xFFFFE24A);
      expect(DayColours.onColorFor(yellow),
          JinatraTokens.onAccentColor(yellow));
    });
  });
}
```

Add `import 'package:flutter/material.dart';` at the top of the test file — the last group constructs a `Color`.

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/day_colours_test.dart`
Expected: FAIL — `Undefined name 'DayColours'`.

- [ ] **Step 3: Replace DayPalette with DayColours**

In `lib/widgets/day_block.dart`, delete the entire `DayPalette` class (its doc comment, `_categoryOf`, `forDay`, `onColorFor`) and put this in its place. Keep the file's other classes (`SectionHeading`, `SubItemRow`, `AddLink`) untouched.

```dart
/// Colour coding per training day, so a week reads at a glance.
///
/// Two rules, in this order:
///  1. A day proposes the accent for its category, so Push/Pull/Legs keep a
///     recognisable colour across routines and across themes.
///  2. Within one routine, no two training days may share a colour. v1 broke
///     here: "Upper Body + Core" and "Upper Body" are both category 5, so
///     both rendered the same magenta and the week stopped being scannable.
///     A day whose category accent is already taken walks forward to the
///     first free one.
///
/// Colours come from the palette's authored ramp rather than HSL rotation of
/// the primary — rotation produced muddy mid-tones in several themes and
/// could not guarantee distinctness in the first place.
class DayColours {
  DayColours._();

  /// Rest days recede rather than compete, and never consume an accent.
  static Color get restColour => JinatraTokens.mistTeal;

  /// Day categories in a fixed order, so the same kind of session keeps the
  /// same colour everywhere in the app.
  static int categoryOf(TrainingDay day) {
    final key = '${day.name} ${day.focus}'.toLowerCase();
    if (key.contains('push') || key.contains('chest')) return 0;
    if (key.contains('pull') ||
        key.contains('back') ||
        key.contains('bicep')) {
      return 1;
    }
    if (key.contains('leg') || key.contains('lower') || key.contains('quad')) {
      return 2;
    }
    if (key.contains('shoulder') || key.contains('delt')) return 3;
    if (key.contains('arm') || key.contains('tricep')) return 4;
    if (key.contains('upper') || key.contains('full')) return 5;
    // Anything unrecognised still gets a stable category rather than a
    // default, so the same custom day name always looks the same.
    return day.name.isEmpty ? 0 : day.name.codeUnitAt(0) % 6;
  }

  /// Colour per day for one routine, keyed by [TrainingDay.id].
  ///
  /// Pass the routine's days in display order; the order decides who keeps
  /// their category colour when two days want the same one.
  static Map<String, Color> assign(List<TrainingDay> days) {
    final ramp = JinatraTokens.accents;
    final result = <String, Color>{};
    final taken = <int>{};

    for (final day in days) {
      if (day.isRestDay) {
        result[day.id] = restColour;
        continue;
      }

      final seed = categoryOf(day) % ramp.length;
      var slot = seed;
      // Walk forward to the first free slot. Once every slot is taken — more
      // than eight training days in one routine, possible with a rotating
      // schedule — fall back to the category colour and allow the reuse.
      if (taken.length < ramp.length) {
        var steps = 0;
        while (taken.contains(slot) && steps < ramp.length) {
          slot = (slot + 1) % ramp.length;
          steps++;
        }
      }

      taken.add(slot);
      result[day.id] = ramp[slot];
    }

    return result;
  }

  /// Text and icons drawn on a day colour.
  static Color onColorFor(Color background) =>
      JinatraTokens.onAccentColor(background);
}
```

- [ ] **Step 4: Run the new test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/day_colours_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 5: Migrate the Routines call sites**

`lib/screens/routines_tab.dart` currently calls the deleted API at lines 927-928:

```dart
    final accent = DayPalette.forDay(day);
    final onAccent = DayPalette.onColorFor(day);
```

Change `_buildDayCard`'s signature so the colour is passed in rather than derived per card — the assignment is a property of the routine, not of one day. Find the declaration (near line 922) and add a `Color accent` parameter:

```dart
  Widget _buildDayCard(
    Routine routine,
    TrainingDay day,
    Color accent, {
    // keep every existing named parameter of this method unchanged
  }) {
    final onAccent = DayColours.onColorFor(accent);
```

Delete the two `DayPalette` lines. Then, in `_buildRoutineCard` where the day cards are built (the `TRAINING WEEK` section near line 872), compute the map once before the loop and pass each day's colour in:

```dart
              // One assignment per routine: the uniqueness rule is only
              // meaningful across the whole week.
              ...(() {
                final colours = DayColours.assign(routine.days);
                return routine.days
                    .map((day) => _buildDayCard(
                          routine,
                          day,
                          colours[day.id] ?? DayColours.restColour,
                        ))
                    .toList();
              })(),
```

If `routine.days` is not the collection the existing code iterates, use whatever list it already passes to `_buildDayCard`; the requirement is that `assign` is called once per routine with that same list, in the same order.

- [ ] **Step 6: Confirm no stale references remain**

Run: `grep -rn "DayPalette" lib/ test/`
Expected: no output.

- [ ] **Step 7: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 116 tests.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/day_block.dart lib/screens/routines_tab.dart test/day_colours_test.dart
git commit -m "fix(routines): give every training day in a week a distinct colour"
```

---

### Task 4: Calories burned per session

**Files:**
- Create: `lib/services/energy_estimator.dart`
- Modify: `lib/models/models.dart` (`SessionLog.kcalBurned`)
- Modify: `lib/services/database_service.dart` (version 3 → 4, `session_logs.kcal_burned`)
- Modify: `lib/screens/today_tab.dart:227-237` (populate it on save)
- Modify: `lib/screens/log_tab.dart:200-250` (render it)
- Test: `test/energy_estimator_test.dart` (create)
- Test: `test/backup_roundtrip_test.dart` (extend)

**Interfaces:**
- Consumes: `SetLog`, `SessionLog` from `lib/models/models.dart`; `ExerciseLibrary.findByName` from `lib/data/exercise_library.dart`.
- Produces:
  - `EnergyEstimator.metByGroup` → `Map<String, double>`
  - `EnergyEstimator.metForGroup(String muscleGroup)` → `double`
  - `EnergyEstimator.dominantGroup({required List<SetLog> sets, required String dayName})` → `String`
  - `EnergyEstimator.kcal({required double met, required double bodyweightKg, required int durationSeconds})` → `double`
  - `EnergyEstimator.estimate({required List<SetLog> sets, required String dayName, required double? bodyweightKg, required int durationSeconds})` → `double?` (null when no estimate is possible)
  - `SessionLog.kcalBurned` → `double`, constructor parameter `this.kcalBurned = 0.0`, map key `kcal_burned`
  - `SessionLog.kcalLabel` → `String` — `'~388 kcal'`, or `''` when the value is 0

- [ ] **Step 1: Write the failing test**

Create `test/energy_estimator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/services/energy_estimator.dart';

SetLog _set(String exerciseName, {int index = 1}) => SetLog(
      id: '$exerciseName-$index',
      sessionExerciseId: 'ex',
      sessionId: 's1',
      exerciseName: exerciseName,
      setIndex: index,
      weightKg: 30.0,
      reps: 10,
      isCompleted: true,
    );

void main() {
  group('metForGroup', () {
    test('cardio is the most expensive family', () {
      expect(EnergyEstimator.metForGroup('Cardio'), 8.0);
    });

    test('multi-joint lower body outranks upper compound', () {
      expect(
        EnergyEstimator.metForGroup('Legs'),
        greaterThan(EnergyEstimator.metForGroup('Chest')),
      );
      expect(EnergyEstimator.metForGroup('Legs'), 6.0);
      expect(EnergyEstimator.metForGroup('Glutes'), 6.0);
      expect(EnergyEstimator.metForGroup('Full Body'), 6.0);
    });

    test('upper compound sits at 5.0', () {
      expect(EnergyEstimator.metForGroup('Chest'), 5.0);
      expect(EnergyEstimator.metForGroup('Back'), 5.0);
      expect(EnergyEstimator.metForGroup('Shoulders'), 5.0);
    });

    test('core is calisthenic', () {
      expect(EnergyEstimator.metForGroup('Core'), 4.5);
    });

    test('isolation work is the cheapest', () {
      expect(EnergyEstimator.metForGroup('Biceps'), 3.5);
      expect(EnergyEstimator.metForGroup('Triceps'), 3.5);
      expect(EnergyEstimator.metForGroup('Calves'), 3.5);
      expect(EnergyEstimator.metForGroup('Forearms'), 3.5);
    });

    test('an unknown group falls back to the resistance default', () {
      expect(EnergyEstimator.metForGroup('Interpretive Dance'), 5.0);
      expect(EnergyEstimator.metForGroup(''), 5.0);
    });
  });

  group('dominantGroup', () {
    test('picks the group with the most sets', () {
      final sets = [
        _set('Leg Press', index: 1),
        _set('Leg Press', index: 2),
        _set('Leg Press', index: 3),
        _set('Plank', index: 1),
      ];
      expect(
        EnergyEstimator.dominantGroup(sets: sets, dayName: 'MON - Legs'),
        'Legs',
      );
    });

    test('falls back to the day name when no set resolves', () {
      final sets = [_set('Freestyle Nonsense Lift')];
      expect(
        EnergyEstimator.dominantGroup(sets: sets, dayName: 'Leg Day'),
        'Legs',
      );
      expect(
        EnergyEstimator.dominantGroup(sets: sets, dayName: 'Push'),
        'Chest',
      );
      expect(
        EnergyEstimator.dominantGroup(sets: const [], dayName: 'Cardio Blast'),
        'Cardio',
      );
    });

    test('an unrecognisable day name yields the resistance default', () {
      expect(
        EnergyEstimator.dominantGroup(sets: const [], dayName: 'Session 4'),
        '',
      );
    });
  });

  group('kcal', () {
    test('matches the MET formula', () {
      // 6.0 MET, 72.5 kg, 51 min -> 6.0 * 3.5 * 72.5 / 200 * 51
      final v = EnergyEstimator.kcal(
        met: 6.0,
        bodyweightKg: 72.5,
        durationSeconds: 51 * 60,
      );
      expect(v, closeTo(388.7, 0.5));
    });

    test('scales linearly with duration and weight', () {
      final base = EnergyEstimator.kcal(
        met: 5.0,
        bodyweightKg: 80.0,
        durationSeconds: 1800,
      );
      final twiceTime = EnergyEstimator.kcal(
        met: 5.0,
        bodyweightKg: 80.0,
        durationSeconds: 3600,
      );
      final twiceWeight = EnergyEstimator.kcal(
        met: 5.0,
        bodyweightKg: 160.0,
        durationSeconds: 1800,
      );
      expect(twiceTime, closeTo(base * 2, 0.001));
      expect(twiceWeight, closeTo(base * 2, 0.001));
    });

    test('zero duration costs nothing', () {
      expect(
        EnergyEstimator.kcal(met: 6.0, bodyweightKg: 70, durationSeconds: 0),
        0.0,
      );
    });
  });

  group('estimate', () {
    test('produces a value from sets, weight and duration', () {
      final v = EnergyEstimator.estimate(
        sets: [_set('Leg Press'), _set('Leg Press', index: 2)],
        dayName: 'MON - Legs',
        bodyweightKg: 72.5,
        durationSeconds: 51 * 60,
      );
      expect(v, isNotNull);
      expect(v!, closeTo(388.7, 0.5));
    });

    test('returns null without a bodyweight', () {
      expect(
        EnergyEstimator.estimate(
          sets: [_set('Leg Press')],
          dayName: 'Legs',
          bodyweightKg: null,
          durationSeconds: 3060,
        ),
        isNull,
      );
    });

    test('returns null for a zero-length session', () {
      expect(
        EnergyEstimator.estimate(
          sets: [_set('Leg Press')],
          dayName: 'Legs',
          bodyweightKg: 72.5,
          durationSeconds: 0,
        ),
        isNull,
      );
    });

    test('a nonsense bodyweight is rejected rather than trusted', () {
      expect(
        EnergyEstimator.estimate(
          sets: [_set('Leg Press')],
          dayName: 'Legs',
          bodyweightKg: 0.0,
          durationSeconds: 3060,
        ),
        isNull,
      );
    });
  });

  group('SessionLog.kcalBurned', () {
    test('defaults to zero and round-trips through its map form', () {
      final log = SessionLog(
        id: 's1',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
        totalSets: 22,
      );
      expect(log.kcalBurned, 0.0);

      final withBurn = SessionLog(
        id: 's2',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
        totalSets: 22,
        kcalBurned: 388.7,
      );
      final back = SessionLog.fromMap(withBurn.toMap());
      expect(back.kcalBurned, closeTo(388.7, 0.001));
    });

    test('a row written before the migration reads as zero', () {
      final legacy = {
        'id': 's3',
        'day_name': 'MON - Legs',
        'date_str': '2026-09-07',
        'duration_seconds': 3060,
        'total_volume_kg': 2295.0,
        'status': 'completed',
        'routine_id': '',
        'day_id': '',
        'total_sets': 22,
      };
      expect(SessionLog.fromMap(legacy).kcalBurned, 0.0);
    });

    test('the label marks the value as an estimate', () {
      final log = SessionLog(
        id: 's4',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
        kcalBurned: 388.7,
      );
      expect(log.kcalLabel, '~389 kcal');
    });

    test('no burn means no label rather than a zero', () {
      final log = SessionLog(
        id: 's5',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
      );
      expect(log.kcalLabel, '');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/energy_estimator_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/services/energy_estimator.dart'`.

- [ ] **Step 3: Create the estimator**

Create `lib/services/energy_estimator.dart`:

```dart
import '../data/exercise_library.dart';
import '../models/models.dart';

/// Estimated energy cost of a training session.
///
/// Uses the standard MET relation
///
///     kcal = MET * 3.5 * bodyweightKg / 200 * minutes
///
/// with the MET taken from the session's dominant muscle group, because a leg
/// day and an arms day of equal length do not cost the same. Values are
/// estimates and every caller renders them with a `~` prefix.
class EnergyEstimator {
  EnergyEstimator._();

  /// MET per muscle group, from the Compendium of Physical Activities'
  /// resistance-training entries.
  static const Map<String, double> metByGroup = {
    'Cardio': 8.0,
    'Legs': 6.0,
    'Glutes': 6.0,
    'Full Body': 6.0,
    'Chest': 5.0,
    'Back': 5.0,
    'Shoulders': 5.0,
    'Core': 4.5,
    'Biceps': 3.5,
    'Triceps': 3.5,
    'Calves': 3.5,
    'Forearms': 3.5,
    'Mobility': 2.5,
  };

  /// General resistance training, used when the group is unknown. Deliberately
  /// mid-range: an unknown session should not be flattered or penalised.
  static const double defaultMet = 5.0;

  static double metForGroup(String muscleGroup) =>
      metByGroup[muscleGroup] ?? defaultMet;

  /// The muscle group that accounts for the most sets in [sets].
  ///
  /// Falls back to keyword matching on [dayName] when no exercise resolves —
  /// ad-hoc sessions and sessions logged before the exercise library covered
  /// an exercise both land here. Returns `''` when neither source says
  /// anything, which [metForGroup] turns into [defaultMet].
  static String dominantGroup({
    required List<SetLog> sets,
    required String dayName,
  }) {
    final counts = <String, int>{};
    for (final s in sets) {
      final def = ExerciseLibrary.findByName(s.exerciseName);
      if (def == null || def.muscleGroup.isEmpty) continue;
      counts[def.muscleGroup] = (counts[def.muscleGroup] ?? 0) + 1;
    }

    if (counts.isNotEmpty) {
      // Ties break on the library's group order, so the result is stable.
      var best = '';
      var bestCount = -1;
      for (final group in ExerciseLibrary.muscleGroups) {
        final c = counts[group] ?? 0;
        if (c > bestCount) {
          best = group;
          bestCount = c;
        }
      }
      if (bestCount > 0) return best;
    }

    return _groupFromDayName(dayName);
  }

  static String _groupFromDayName(String dayName) {
    final key = dayName.toLowerCase();
    if (key.contains('cardio') || key.contains('run') || key.contains('hiit')) {
      return 'Cardio';
    }
    if (key.contains('leg') || key.contains('lower') || key.contains('quad')) {
      return 'Legs';
    }
    if (key.contains('glute') || key.contains('hip')) return 'Glutes';
    if (key.contains('full') || key.contains('upper')) return 'Full Body';
    if (key.contains('push') || key.contains('chest')) return 'Chest';
    if (key.contains('pull') || key.contains('back')) return 'Back';
    if (key.contains('shoulder') || key.contains('delt')) return 'Shoulders';
    if (key.contains('core') || key.contains('abs')) return 'Core';
    if (key.contains('arm') || key.contains('bicep') || key.contains('tricep')) {
      return 'Biceps';
    }
    return '';
  }

  static double kcal({
    required double met,
    required double bodyweightKg,
    required int durationSeconds,
  }) {
    final minutes = durationSeconds / 60.0;
    return met * 3.5 * bodyweightKg / 200.0 * minutes;
  }

  /// Null when no honest estimate is possible: no bodyweight on record, or a
  /// session with no measured duration. A missing number is better than a
  /// fabricated one.
  static double? estimate({
    required List<SetLog> sets,
    required String dayName,
    required double? bodyweightKg,
    required int durationSeconds,
  }) {
    if (bodyweightKg == null || bodyweightKg <= 0) return null;
    if (durationSeconds <= 0) return null;

    final group = dominantGroup(sets: sets, dayName: dayName);
    return kcal(
      met: metForGroup(group),
      bodyweightKg: bodyweightKg,
      durationSeconds: durationSeconds,
    );
  }
}
```

- [ ] **Step 4: Add the field to SessionLog**

In `lib/models/models.dart`, inside `class SessionLog`, add after `final int totalSets;`:

```dart
  /// Estimated energy cost, kcal. Zero means "not estimated" — either the
  /// session predates the field or no bodyweight was on record when it was
  /// saved. Stored rather than derived so history does not silently change
  /// when the user's bodyweight does.
  final double kcalBurned;
```

Add to the constructor after `this.totalSets = 0,`:

```dart
    this.kcalBurned = 0.0,
```

Add to `toMap`, after `'total_sets': totalSets,`:

```dart
      'kcal_burned': kcalBurned,
```

Add to `fromMap`, after `totalSets: map['total_sets'] ?? 0,`:

```dart
      kcalBurned: (map['kcal_burned'] as num?)?.toDouble() ?? 0.0,
```

Add the label getter next to `durationLabel`:

```dart
  /// Always prefixed `~`: this is an estimate, not a measurement. Empty when
  /// there is no estimate, so callers render nothing rather than "0 kcal".
  String get kcalLabel =>
      kcalBurned <= 0 ? '' : '~${kcalBurned.round()} kcal';
```

- [ ] **Step 5: Run the estimator test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/energy_estimator_test.dart`
Expected: PASS, 17 tests.

- [ ] **Step 6: Migrate the schema to version 4**

In `lib/services/database_service.dart`, change the version in `_initDB`:

```dart
      version: 4,
```

Add the new column to the `CREATE TABLE session_logs` statement in `_createDB`, after `total_sets INTEGER NOT NULL DEFAULT 0`:

```dart
        ,kcal_burned REAL NOT NULL DEFAULT 0.0
```

(Write it as a normal trailing column — `total_sets INTEGER NOT NULL DEFAULT 0,` then `kcal_burned REAL NOT NULL DEFAULT 0.0` — matching the file's existing formatting.)

Add the upgrade branch at the end of `_upgradeDB`:

```dart
    if (oldVersion < 4) {
      // v4: estimated energy cost per session. Additive and idempotent, so a
      // database created at any earlier version lands in the same shape.
      await _addColumnIfMissing(
        db,
        'session_logs',
        'kcal_burned',
        'REAL NOT NULL DEFAULT 0.0',
      );
    }
```

- [ ] **Step 7: Extend the backup round-trip test**

In `test/backup_roundtrip_test.dart`, find the test named `a full round trip preserves every table` and the helper that builds the session row it inserts. Give that session a burn value and assert it survives. Add this test to the same group:

```dart
    test('estimated burn survives an export and import', () async {
      final db = await DatabaseService.instance.database;
      await db.insert('session_logs', {
        'id': 'burn-1',
        'day_name': 'MON - Legs',
        'date_str': '2026-09-07',
        'duration_seconds': 3060,
        'total_volume_kg': 2295.0,
        'status': 'completed',
        'routine_id': '',
        'day_id': '',
        'total_sets': 22,
        'kcal_burned': 388.7,
      });

      final doc = await BackupService.instance.exportToJson();
      for (final table in DatabaseService.backupTables) {
        await db.delete(table);
      }
      final result = await BackupService.instance.importFromJson(doc);
      expect(result.isSuccess, isTrue);

      final rows = await db.query('session_logs', where: 'id = ?',
          whereArgs: ['burn-1']);
      expect(rows.single['kcal_burned'], closeTo(388.7, 0.001));
    });
```

If the existing file's export/import helper names differ (`exportToJson` / `importFromJson` / `isSuccess`), use the names the file already uses — read the top of the file first and match them exactly.

- [ ] **Step 8: Populate it when a session is saved**

In `lib/screens/today_tab.dart`, add the imports:

```dart
import '../services/energy_estimator.dart';
import '../services/goal_service.dart';
```

In `_finishSession`, the `setRows` list is built after the `SessionLog` is constructed. Move the `SessionLog` construction below the `setRows` loop so the estimate can see the sets, then build it like this (replacing the existing `final session = SessionLog(...)`):

```dart
    // Bodyweight for the estimate: what the user last logged, else their
    // stated target, else no estimate at all.
    final snapshot = await GoalService.instance.snapshot();
    final bodyweightKg = snapshot.currentWeightKg ??
        (snapshot.profile.isConfigured
            ? snapshot.profile.targetWeightKg
            : null);

    final burn = EnergyEstimator.estimate(
      sets: setRows.map(SetLog.fromMap).toList(),
      dayName: _sessionTitle,
      bodyweightKg: bodyweightKg,
      durationSeconds: duration,
    );

    final session = SessionLog(
      id: sessionId,
      dayName: _sessionTitle,
      dateStr: ScheduleService.dateKey(DateTime.now()),
      durationSeconds: duration,
      totalVolumeKg: _sessionVolumeKg,
      status: 'completed',
      routineId: sched?.routine.id ?? '',
      dayId: sched?.day.id ?? '',
      totalSets: _sessionCompletedSets,
      kcalBurned: burn ?? 0.0,
    );
```

- [ ] **Step 9: Show it on the Log archive card**

In `lib/screens/log_tab.dart`, inside `_buildLogCard`, the header's mono detail line currently reads:

```dart
                        '${log.dateStr}  -  ${log.durationLabel}  -  ${log.totalSets} sets',
```

Replace it with a line that appends the burn only when there is one:

```dart
                        [
                          log.dateStr,
                          log.durationLabel,
                          '${log.totalSets} sets',
                          if (log.kcalLabel.isNotEmpty) log.kcalLabel,
                        ].join('  -  '),
```

- [ ] **Step 10: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 134 tests.

- [ ] **Step 11: Commit**

```bash
git add lib/services/energy_estimator.dart lib/models/models.dart lib/services/database_service.dart lib/screens/today_tab.dart lib/screens/log_tab.dart test/energy_estimator_test.dart test/backup_roundtrip_test.dart
git commit -m "feat(log): estimate and store calories burned per session"
```

---

### Task 5: Food and exercise search — aliases, typo tolerance, ranking

This is the fix for the second reported defect. The library already contains `Paratha`, `Roti / Chapati`, `Plain Omelette`, `Dim Bhaji (Bengali Omelette)`, `Chicken Curry (Bengali)`, `Beef Curry (Bengali)` and `Rui Macher Jhol (Rohu Curry)`; `LibraryFood.matches` is a plain substring test, so `omlet`, `ruti` and `murgir` all return nothing.

**Files:**
- Create: `lib/data/food_search.dart`
- Modify: `lib/data/food_library.dart` (`FoodLibrary.search` delegates)
- Modify: `lib/data/exercise_library.dart` (`ExerciseLibrary.search` added, delegates)
- Modify: `lib/widgets/food_picker.dart:73-80` (use the ranked search, show why a row matched)
- Modify: `lib/widgets/exercise_picker.dart` (use the ranked search)
- Test: `test/food_search_test.dart` (create)

**Interfaces:**
- Consumes: `LibraryFood` from `lib/data/food_library.dart`, `LibraryExercise` from `lib/data/exercise_library.dart`.
- Produces:
  - `TextSearch.normalise(String input)` → `String` — lowercased, diacritics folded, punctuation to spaces, whitespace collapsed
  - `TextSearch.tokenise(String input)` → `List<String>`
  - `TextSearch.aliases` → `Map<String, String>`
  - `TextSearch.canonicalise(List<String> tokens)` → `List<String>` — alias-substituted
  - `TextSearch.editDistance(String a, String b)` → `int` (Damerau–Levenshtein)
  - `TextSearch.fuzzyTokenMatch(String queryToken, String candidateToken)` → `bool`
  - `SearchHit<T>({required T item, required int rank, String? matchedVia})` — lower `rank` is better
  - `searchFoods(String query, {List<LibraryFood>? source})` → `List<SearchHit<LibraryFood>>`
  - `searchExercises(String query, {List<LibraryExercise>? source})` → `List<SearchHit<LibraryExercise>>`
  - `FoodLibrary.search(String needle)` → `List<LibraryFood>` (unchanged signature, new behaviour)
  - `ExerciseLibrary.search(String needle)` → `List<LibraryExercise>`

- [ ] **Step 1: Write the failing test**

Create `test/food_search_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/data/exercise_library.dart';
import 'package:lockout/data/food_library.dart';
import 'package:lockout/data/food_search.dart';

List<String> _names(String query) =>
    searchFoods(query).map((h) => h.item.name).toList();

void main() {
  group('normalise and tokenise', () {
    test('folds case, punctuation and repeated whitespace', () {
      expect(TextSearch.normalise('  Roti / Chapati  '), 'roti chapati');
      expect(TextSearch.normalise('Chicken Curry (Bengali)'),
          'chicken curry bengali');
      expect(TextSearch.normalise("Shepherd's Pie"), 'shepherd s pie');
    });

    test('tokenise drops empties', () {
      expect(TextSearch.tokenise('Beef  Curry '), ['beef', 'curry']);
      expect(TextSearch.tokenise('   '), isEmpty);
    });
  });

  group('editDistance', () {
    test('counts substitutions, insertions and deletions', () {
      expect(TextSearch.editDistance('roti', 'roti'), 0);
      expect(TextSearch.editDistance('ruti', 'roti'), 1);
      expect(TextSearch.editDistance('chiken', 'chicken'), 1);
      expect(TextSearch.editDistance('cury', 'curry'), 1);
      expect(TextSearch.editDistance('parata', 'paratha'), 1);
    });

    test('counts a transposition as one edit', () {
      expect(TextSearch.editDistance('omlette', 'omelette'), 1);
      expect(TextSearch.editDistance('beff', 'beef'), 1);
    });
  });

  group('fuzzyTokenMatch', () {
    test('short tokens must be exact', () {
      expect(TextSearch.fuzzyTokenMatch('egg', 'egg'), isTrue);
      expect(TextSearch.fuzzyTokenMatch('egg', 'ego'), isFalse);
    });

    test('medium tokens tolerate one edit', () {
      expect(TextSearch.fuzzyTokenMatch('ruti', 'roti'), isTrue);
      expect(TextSearch.fuzzyTokenMatch('rice', 'ruti'), isFalse);
    });

    test('long tokens tolerate two edits', () {
      expect(TextSearch.fuzzyTokenMatch('omlete', 'omelette'), isTrue);
      expect(TextSearch.fuzzyTokenMatch('chikn', 'chicken'), isTrue);
    });
  });

  group('the reported queries now find their dishes', () {
    test('omlet finds the omelettes', () {
      final names = _names('omlet');
      expect(names, contains('Plain Omelette'));
      expect(names, contains('Dim Bhaji (Bengali Omelette)'));
    });

    test('ruti finds roti', () {
      expect(_names('ruti'), contains('Roti / Chapati'));
    });

    test('porota finds paratha', () {
      expect(_names('porota'), contains('Paratha'));
    });

    test('murgir finds the chicken dishes', () {
      final names = _names('murgir mangsho');
      expect(names, contains('Chicken Curry (Bengali)'));
    });

    test('beef cury finds beef curry despite the typo', () {
      expect(_names('beef cury'), contains('Beef Curry (Bengali)'));
    });

    test('macher jhol finds the fish curries', () {
      final names = _names('macher jhol');
      expect(names, contains('Rui Macher Jhol (Rohu Curry)'));
    });

    test('parata finds paratha despite the typo', () {
      expect(_names('parata'), contains('Paratha'));
    });

    test('yoghurt and yogurt are the same query', () {
      expect(_names('yoghurt'), isNotEmpty);
      expect(_names('yoghurt').first, _names('yogurt').first);
    });
  });

  group('ranking', () {
    test('an exact name wins', () {
      expect(_names('Paratha').first, 'Paratha');
    });

    test('a name prefix beats an ingredient mention', () {
      final hits = searchFoods('chicken curry');
      expect(hits.first.item.name.toLowerCase(), startsWith('chicken curry'));
    });

    test('a name match outranks a category match', () {
      final hits = searchFoods('bengali');
      expect(hits, isNotEmpty);
      // Every Bengali-category item is reachable, and nothing outranks a
      // literal name hit.
      expect(hits.first.rank, lessThanOrEqualTo(hits.last.rank));
    });

    test('hits come back sorted by rank', () {
      final ranks = searchFoods('curry').map((h) => h.rank).toList();
      final sorted = [...ranks]..sort();
      expect(ranks, sorted);
    });

    test('an alias or fuzzy hit says how it matched', () {
      final hit = searchFoods('ruti').first;
      expect(hit.matchedVia, isNotNull);
      expect(hit.matchedVia, contains('ruti'));
    });

    test('an exact hit needs no explanation', () {
      expect(searchFoods('Paratha').first.matchedVia, isNull);
    });
  });

  group('degenerate queries', () {
    test('an empty query returns the whole library in order', () {
      expect(searchFoods('').length, FoodLibrary.all.length);
      expect(searchFoods('   ').first.item.name, FoodLibrary.all.first.name);
    });

    test('a query matching nothing returns nothing', () {
      expect(searchFoods('zzzzqqqq'), isEmpty);
    });
  });

  group('FoodLibrary.search delegates', () {
    test('it returns the ranked items', () {
      expect(FoodLibrary.search('ruti').map((f) => f.name),
          contains('Roti / Chapati'));
    });
  });

  group('exercise search shares the pipeline', () {
    test('a misspelling still finds the exercise', () {
      final names =
          searchExercises('bench pres').map((h) => h.item.name).toList();
      expect(names.any((n) => n.contains('Bench Press')), isTrue);
    });

    test('ExerciseLibrary.search delegates', () {
      expect(ExerciseLibrary.search('deadlift'), isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_search_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/data/food_search.dart'`.

- [ ] **Step 3: Create the search module**

Create `lib/data/food_search.dart`:

```dart
import 'dart:math' as math;

import 'exercise_library.dart';
import 'food_library.dart';

/// One result, with why it matched.
///
/// [rank] is a small integer where lower is better, so callers sort rather
/// than score. [matchedVia] is set only when the match was not literal — an
/// alias or a corrected typo — so the UI can explain a surprising hit
/// instead of leaving the user to wonder.
class SearchHit<T> {
  final T item;
  final int rank;
  final String? matchedVia;

  const SearchHit({required this.item, required this.rank, this.matchedVia});
}

/// Normalising, alias-aware, typo-tolerant text matching.
///
/// The substring test this replaces could not find items the library already
/// held: a user typing `ruti` or `omlet` got an empty list and reasonably
/// concluded the food was missing.
class TextSearch {
  TextSearch._();

  /// Transliteration and synonym pairs, mapping what a user types to the
  /// token the library actually uses. Bengali/Hindi romanisation varies by
  /// person, so both the common spellings and the English word are accepted.
  static const Map<String, String> aliases = {
    // breads
    'ruti': 'roti',
    'rooti': 'roti',
    'rooty': 'roti',
    'porota': 'paratha',
    'parotha': 'paratha',
    'porata': 'paratha',
    'luchee': 'luchi',
    'nan': 'naan',
    // eggs
    'omlet': 'omelette',
    'omlette': 'omelette',
    'omelet': 'omelette',
    'omelete': 'omelette',
    'dim': 'egg',
    'deem': 'egg',
    // meat
    'murgi': 'chicken',
    'murgir': 'chicken',
    'murog': 'chicken',
    'morog': 'chicken',
    'murgh': 'chicken',
    'gorur': 'beef',
    'goru': 'beef',
    'khashi': 'mutton',
    'khasi': 'mutton',
    'hasher': 'duck',
    'mangsho': 'meat',
    'mangso': 'meat',
    // fish and seafood
    'mach': 'fish',
    'machh': 'fish',
    'maach': 'fish',
    'macher': 'fish',
    'machher': 'fish',
    'machh er': 'fish',
    'chingri': 'prawn',
    'shrimp': 'prawn',
    'ilish': 'hilsa',
    'rui': 'rohu',
    'shutki': 'dried fish',
    // staples
    'bhat': 'rice',
    'polao': 'pulao',
    'pulao': 'pulao',
    'khichdi': 'khichuri',
    'khichri': 'khichuri',
    'daal': 'dal',
    'dhal': 'dal',
    'chola': 'chickpeas',
    'chhola': 'chickpeas',
    // dishes and preparations
    'jhol': 'curry',
    'jhal': 'curry',
    'torkari': 'vegetable',
    'tarkari': 'vegetable',
    'bhorta': 'bhorta',
    'vorta': 'bhorta',
    'bhaji': 'bhaji',
    'vaji': 'bhaji',
    'misti': 'sweet',
    'mishti': 'sweet',
    'doi': 'yogurt',
    // British / US spelling pairs
    'yoghurt': 'yogurt',
    'aubergine': 'aubergine',
    'eggplant': 'aubergine',
    'courgette': 'courgette',
    'zucchini': 'courgette',
    'chips': 'chips',
    'fries': 'chips',
    'coriander': 'coriander',
    'cilantro': 'coriander',
    'chickpea': 'chickpeas',
    'garbanzo': 'chickpeas',
  };

  /// Lowercase, fold diacritics, punctuation to spaces, collapse whitespace.
  static String normalise(String input) {
    final lower = input.toLowerCase();
    final folded = StringBuffer();
    for (final ch in lower.split('')) {
      folded.write(_diacritics[ch] ?? ch);
    }
    final cleaned = folded
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  static const Map<String, String> _diacritics = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  static List<String> tokenise(String input) {
    final n = normalise(input);
    if (n.isEmpty) return const [];
    return n.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Replaces every token that has an alias with its canonical form.
  static List<String> canonicalise(List<String> tokens) =>
      tokens.map((t) => aliases[t] ?? t).toList();

  /// Damerau–Levenshtein distance. A transposition counts as one edit, which
  /// matters because most real misspellings are transpositions.
  static int editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final rows = a.length + 1;
    final cols = b.length + 1;
    final d = List.generate(rows, (_) => List<int>.filled(cols, 0));

    for (var i = 0; i < rows; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j < cols; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var best = math.min(
          d[i - 1][j] + 1,
          math.min(d[i][j - 1] + 1, d[i - 1][j - 1] + cost),
        );
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1]) {
          best = math.min(best, d[i - 2][j - 2] + 1);
        }
        d[i][j] = best;
      }
    }

    return d[a.length][b.length];
  }

  /// Tolerance scales with length: a three-letter word has no room for a typo
  /// without becoming a different word, a long one has plenty.
  static bool fuzzyTokenMatch(String queryToken, String candidateToken) {
    if (queryToken == candidateToken) return true;
    if (candidateToken.startsWith(queryToken) && queryToken.length >= 4) {
      return true;
    }

    final len = math.max(queryToken.length, candidateToken.length);
    final allowed = len <= 3
        ? 0
        : len <= 6
            ? 1
            : 2;
    if (allowed == 0) return false;
    return editDistance(queryToken, candidateToken) <= allowed;
  }
}

/// Rank bands. Lower is better; the gaps leave room to insert a band later
/// without renumbering the ones around it.
class _Rank {
  static const exactName = 0;
  static const namePrefix = 10;
  static const allTokensInName = 20;
  static const aliasName = 30;
  static const fuzzyName = 40;
  static const category = 50;
  static const ingredients = 60;
}

/// Scores one candidate against a query. Returns null when nothing matched.
///
/// Shared by foods and exercises so the two pickers cannot drift apart: the
/// exercise picker had the identical substring limitation.
SearchHit<T>? _score<T>({
  required T item,
  required String name,
  required List<String> secondary,
  required String rawQuery,
  required List<String> queryTokens,
  required List<String> canonicalQuery,
}) {
  final normName = TextSearch.normalise(name);
  final nameTokens = TextSearch.tokenise(name);
  final canonicalName = TextSearch.canonicalise(nameTokens);
  final normQuery = TextSearch.normalise(rawQuery);

  if (normName == normQuery) {
    return SearchHit(item: item, rank: _Rank.exactName);
  }
  if (normName.startsWith(normQuery)) {
    return SearchHit(item: item, rank: _Rank.namePrefix);
  }
  if (queryTokens.every((q) => normName.contains(q))) {
    return SearchHit(item: item, rank: _Rank.allTokensInName);
  }

  // Alias band: the query means the same thing as the name once both sides
  // are canonicalised. This is what makes "ruti" find "Roti / Chapati".
  final aliasMatched = canonicalQuery.every(
    (q) => canonicalName.any((n) => n == q) || normName.contains(q),
  );
  if (aliasMatched) {
    return SearchHit(
      item: item,
      rank: _Rank.aliasName,
      matchedVia: rawQuery.trim(),
    );
  }

  // Fuzzy band: every query token is within edit distance of some name token.
  final fuzzyMatched = canonicalQuery.every(
    (q) => canonicalName.any((n) => TextSearch.fuzzyTokenMatch(q, n)),
  );
  if (fuzzyMatched) {
    return SearchHit(
      item: item,
      rank: _Rank.fuzzyName,
      matchedVia: rawQuery.trim(),
    );
  }

  // Secondary fields, in the order they were passed: category before
  // ingredients, so "bengali" surfaces the cuisine rather than every dish
  // that happens to mention it.
  for (var i = 0; i < secondary.length; i++) {
    final normField = TextSearch.normalise(secondary[i]);
    if (queryTokens.every((q) => normField.contains(q))) {
      return SearchHit(
        item: item,
        rank: i == 0 ? _Rank.category : _Rank.ingredients,
      );
    }
  }

  return null;
}

List<SearchHit<T>> _rank<T>(List<SearchHit<T>> hits) {
  // A stable sort keeps the library's own order inside a band, so staples
  // stay above obscure items.
  final indexed = hits.asMap().entries.toList();
  indexed.sort((a, b) {
    final byRank = a.value.rank.compareTo(b.value.rank);
    return byRank != 0 ? byRank : a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

/// Ranked food search. An empty query returns the whole library in order.
List<SearchHit<LibraryFood>> searchFoods(
  String query, {
  List<LibraryFood>? source,
}) {
  final items = source ?? FoodLibrary.all;
  final tokens = TextSearch.tokenise(query);

  if (tokens.isEmpty) {
    return items
        .map((f) => SearchHit(item: f, rank: _Rank.exactName))
        .toList();
  }

  final canonical = TextSearch.canonicalise(tokens);
  final hits = <SearchHit<LibraryFood>>[];

  for (final food in items) {
    final hit = _score<LibraryFood>(
      item: food,
      name: food.name,
      secondary: [food.category, food.ingredients],
      rawQuery: query,
      queryTokens: tokens,
      canonicalQuery: canonical,
    );
    if (hit != null) hits.add(hit);
  }

  return _rank(hits);
}

/// Ranked exercise search, same pipeline as [searchFoods].
List<SearchHit<LibraryExercise>> searchExercises(
  String query, {
  List<LibraryExercise>? source,
}) {
  final items = source ?? ExerciseLibrary.all;
  final tokens = TextSearch.tokenise(query);

  if (tokens.isEmpty) {
    return items
        .map((e) => SearchHit(item: e, rank: _Rank.exactName))
        .toList();
  }

  final canonical = TextSearch.canonicalise(tokens);
  final hits = <SearchHit<LibraryExercise>>[];

  for (final ex in items) {
    final hit = _score<LibraryExercise>(
      item: ex,
      name: ex.name,
      secondary: [ex.muscleGroup, ex.equipment],
      rawQuery: query,
      queryTokens: tokens,
      canonicalQuery: canonical,
    );
    if (hit != null) hits.add(hit);
  }

  return _rank(hits);
}
```

- [ ] **Step 4: Delegate the library search helpers**

In `lib/data/food_library.dart`, replace the body of `FoodLibrary.search` with a delegation. It currently reads:

```dart
  static List<LibraryFood> search(String needle) =>
      all.where((f) => f.matches(needle)).toList();
```

Replace with:

```dart
  /// Ranked search. Delegates to the shared pipeline in `food_search.dart`
  /// so the picker and any other caller cannot disagree about what matches.
  static List<LibraryFood> search(String needle) =>
      searchFoods(needle).map((h) => h.item).toList();
```

and add the import at the top of the file:

```dart
import 'food_search.dart';
```

In `lib/data/exercise_library.dart`, add the same import and a `search` static inside `ExerciseLibrary`, next to `findByName`:

```dart
  /// Ranked search, shared with the food picker's pipeline.
  static List<LibraryExercise> search(String needle) =>
      searchExercises(needle).map((h) => h.item).toList();
```

Leave `LibraryFood.matches` and `LibraryExercise.matches` in place — existing tests assert their behaviour and they remain a valid cheap predicate.

- [ ] **Step 5: Run the search test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_search_test.dart`
Expected: PASS, 24 tests. If the `ranking` group's `chicken curry` expectation fails because a generic "Chicken Curry" item does not exist yet, leave it failing and note it — Task 6 adds that item. Do not weaken the test.

- [ ] **Step 6: Wire the food picker**

In `lib/widgets/food_picker.dart`, add the import:

```dart
import '../data/food_search.dart';
```

Replace the filter block at lines 73-75, which currently reads:

```dart
    if (_query.isNotEmpty) {
      list = list.where((f) => f.matches(_query)).toList();
    }
```

with a ranked search that keeps the explanation for each row:

```dart
    // Ranked, alias-aware search. `_matchNotes` carries why a surprising row
    // is in the list so the UI can say so.
    final notes = <String, String>{};
    if (_query.trim().isNotEmpty) {
      final hits = searchFoods(_query, source: list);
      list = hits.map((h) => h.item).toList();
      for (final h in hits) {
        if (h.matchedVia != null) notes[h.item.name] = h.matchedVia!;
      }
    }
    _matchNotes = notes;
```

Add the field to the state class next to `_query`:

```dart
  /// Food name -> the query that matched it by alias or typo correction.
  Map<String, String> _matchNotes = const {};
```

In the row builder for a library food, add the note under the name when one exists:

```dart
              if (_matchNotes[food.name] != null)
                Text(
                  '~ matched "${_matchNotes[food.name]}"',
                  style: JinatraTokens.monoData(
                    fontSize: 9,
                    color: JinatraTokens.ink.withValues(alpha: 0.55),
                  ),
                ),
```

- [ ] **Step 7: Wire the exercise picker**

In `lib/widgets/exercise_picker.dart`, find the filter that calls `matches` (run `grep -n "matches" lib/widgets/exercise_picker.dart`) and replace it with:

```dart
    if (_query.trim().isNotEmpty) {
      list = searchExercises(_query, source: list).map((h) => h.item).toList();
    }
```

adding the import:

```dart
import '../data/food_search.dart';
```

- [ ] **Step 8: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 158 tests — except the `chicken curry` ranking case if Task 6 has not run yet.

- [ ] **Step 9: Commit**

```bash
git add lib/data/food_search.dart lib/data/food_library.dart lib/data/exercise_library.dart lib/widgets/food_picker.dart lib/widgets/exercise_picker.dart test/food_search_test.dart
git commit -m "fix(food): alias-aware, typo-tolerant ranked search for foods and exercises"
```

---

### Task 6: Food library additions

The reported dishes were all present; these are the genuine gaps found while auditing the 432 entries — the places where daily logging currently forces "ADD CUSTOM".

**Files:**
- Modify: `lib/data/food_library.dart` (append 40 entries)
- Test: `test/food_library_test.dart` (create)

**Interfaces:**
- Consumes: `LibraryFood` (unchanged), `FoodLibrary.categories` (unchanged).
- Produces: no new API. `FoodLibrary.all.length` becomes 472.

- [ ] **Step 1: Write the failing test**

Create `test/food_library_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/data/food_library.dart';

void main() {
  group('Library integrity', () {
    test('names are unique so lookups are unambiguous', () {
      final names = FoodLibrary.all.map((f) => f.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('every item declares a known category', () {
      for (final f in FoodLibrary.all) {
        expect(FoodLibrary.categories, contains(f.category), reason: f.name);
      }
    });

    test('every item states a serving and ingredients', () {
      for (final f in FoodLibrary.all) {
        expect(f.serving.trim(), isNotEmpty, reason: f.name);
        expect(f.ingredients.trim(), isNotEmpty, reason: f.name);
      }
    });

    test('stated calories agree with the macro breakdown', () {
      for (final f in FoodLibrary.all) {
        if (f.kcal < 20) continue; // rounding dominates at trace calories
        final implied = f.kcalFromMacros;
        final drift = (implied - f.kcal).abs() / f.kcal;
        expect(
          drift,
          lessThanOrEqualTo(0.12),
          reason: '${f.name}: stated ${f.kcal}, macros ${implied.round()}',
        );
      }
    });

    test('the audit added the everyday gaps', () {
      final names = FoodLibrary.all.map((f) => f.name).toSet();
      for (final expected in [
        'Cheese Omelette',
        'Masala Omelette',
        'Egg Bhurji',
        'Omelette (3-egg)',
        'Egg Curry',
        'Cheese Paratha',
        'Egg Paratha',
        'Paneer Paratha',
        'Roti with Ghee',
        'Ruti (Atta, large)',
        'Suji Ruti',
        'Chicken Curry',
        'Fish Curry',
        'Prawn Curry',
        'Vegetable Curry',
        'Chicken Bhuna',
        'Mutton Bhuna',
        'Duck Curry (Hasher Mangsho)',
        'Chicken Jhol',
        'Shorshe Bata Mach',
        'Shorshe Chingri',
        'Chingri Bhorta',
        'Lau Chingri',
        'Fish Fry (Bengali)',
        'Chicken Fry (Bengali)',
        'Dim Bhuna',
        'Tehari (Chicken)',
        'Tehari (Mutton)',
        'Chicken Khichuri',
        'Dim Khichuri',
        'Vegetable Khichuri',
        'Dal Bhat',
        'Aloo Bhorta with Mustard Oil',
        'Chola Boot',
        'Mixed Fruit Salad',
        'Whole Wheat Bread (2 slices)',
        'Cheese Toast',
        'Chicken Sandwich',
        'Instant Coffee (black)',
        'Sugar-free Tea with Milk',
      ]) {
        expect(names, contains(expected), reason: expected);
      }
    });

    test('the library grew to 472 items', () {
      expect(FoodLibrary.all.length, 472);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_library_test.dart`
Expected: FAIL — `the audit added the everyday gaps` and `the library grew to 472 items`. The integrity tests should already pass; if `stated calories agree with the macro breakdown` fails on an existing item, fix that item's numbers rather than loosening the tolerance.

- [ ] **Step 3: Append the eggs**

In `lib/data/food_library.dart`, inside `static const List<LibraryFood> all = [`, add at the end of the list (before the closing `];`), keeping the file's one-line-per-entry formatting:

```dart
    // ---------------- V2 AUDIT: EGGS ----------------
    LibraryFood(name: 'Cheese Omelette', category: 'Eggs & Dairy', serving: '2 eggs + 20g cheese', kcal: 225, proteinG: 17.0, carbG: 1.0, fatG: 17.0, ingredients: 'Eggs, cheddar, butter, salt'),
    LibraryFood(name: 'Masala Omelette', category: 'Eggs & Dairy', serving: '2 eggs', kcal: 212, proteinG: 13.0, carbG: 4.0, fatG: 16.0, ingredients: 'Eggs, onion, green chilli, coriander, oil'),
    LibraryFood(name: 'Egg Bhurji', category: 'Eggs & Dairy', serving: '2 eggs', kcal: 225, proteinG: 13.0, carbG: 5.0, fatG: 17.0, ingredients: 'Eggs, onion, tomato, chilli, oil, turmeric'),
    LibraryFood(name: 'Poached Egg', category: 'Eggs & Dairy', serving: '1 egg', kcal: 70, proteinG: 6.3, carbG: 0.4, fatG: 4.8, ingredients: 'Egg, water, vinegar'),
    LibraryFood(name: 'Omelette (3-egg)', category: 'Eggs & Dairy', serving: '3 eggs', kcal: 273, proteinG: 19.0, carbG: 2.0, fatG: 21.0, ingredients: 'Eggs, butter, salt'),
    LibraryFood(name: 'Egg Curry', category: 'Eggs & Dairy', serving: '2 eggs in gravy', kcal: 268, proteinG: 14.0, carbG: 8.0, fatG: 20.0, ingredients: 'Boiled eggs, onion, tomato, oil, spices'),
    LibraryFood(name: 'Dim Bhuna', category: 'Bengali', serving: '2 eggs', kcal: 242, proteinG: 14.0, carbG: 6.0, fatG: 18.0, ingredients: 'Eggs, onion, garlic, mustard oil, bhuna spices'),
```

- [ ] **Step 4: Append the breads**

```dart
    // ---------------- V2 AUDIT: BREADS ----------------
    LibraryFood(name: 'Cheese Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 354, proteinG: 10.0, carbG: 38.0, fatG: 18.0, ingredients: 'Atta flour, cheese, ghee or oil'),
    LibraryFood(name: 'Egg Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 345, proteinG: 12.0, carbG: 36.0, fatG: 17.0, ingredients: 'Atta flour, egg, oil'),
    LibraryFood(name: 'Paneer Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 354, proteinG: 12.0, carbG: 36.0, fatG: 18.0, ingredients: 'Atta flour, paneer, ghee, spices'),
    LibraryFood(name: 'Roti with Ghee', category: 'Bread & Bakery', serving: '1 roti + 1 tsp ghee', kcal: 138, proteinG: 3.0, carbG: 18.0, fatG: 6.0, ingredients: 'Atta flour, water, ghee'),
    LibraryFood(name: 'Ruti (Atta, large)', category: 'Bread & Bakery', serving: '1 large piece', kcal: 140, proteinG: 4.5, carbG: 27.0, fatG: 1.5, ingredients: 'Wholewheat atta flour, water, no oil'),
    LibraryFood(name: 'Suji Ruti', category: 'Bread & Bakery', serving: '1 piece', kcal: 154, proteinG: 4.0, carbG: 30.0, fatG: 2.0, ingredients: 'Semolina, water, pinch of salt, light oil'),
    LibraryFood(name: 'Whole Wheat Bread (2 slices)', category: 'Bread & Bakery', serving: '2 slices', kcal: 154, proteinG: 7.0, carbG: 26.0, fatG: 2.5, ingredients: 'Wholewheat flour, yeast, salt'),
    LibraryFood(name: 'Cheese Toast', category: 'Breakfast', serving: '2 slices + 30g cheese', kcal: 289, proteinG: 15.0, carbG: 28.0, fatG: 13.0, ingredients: 'Bread, cheddar, butter'),
    LibraryFood(name: 'Chicken Sandwich', category: 'Western', serving: '1 sandwich', kcal: 340, proteinG: 24.0, carbG: 34.0, fatG: 12.0, ingredients: 'Bread, grilled chicken, mayonnaise, lettuce, tomato'),
```

- [ ] **Step 5: Append the generic curries**

These sit alongside the named Bengali versions rather than replacing them: a user who cooked an ordinary chicken curry should not have to decide whether it was a Rezala.

```dart
    // ---------------- V2 AUDIT: GENERIC CURRIES ----------------
    LibraryFood(name: 'Chicken Curry', category: 'South Asian', serving: '150g with gravy', kcal: 250, proteinG: 25.0, carbG: 6.0, fatG: 14.0, ingredients: 'Chicken, onion, tomato, garlic, ginger, oil, spices'),
    LibraryFood(name: 'Fish Curry', category: 'South Asian', serving: '150g with gravy', kcal: 220, proteinG: 22.0, carbG: 6.0, fatG: 12.0, ingredients: 'White fish, onion, tomato, oil, turmeric, spices'),
    LibraryFood(name: 'Prawn Curry', category: 'South Asian', serving: '120g with gravy', kcal: 203, proteinG: 20.0, carbG: 6.0, fatG: 11.0, ingredients: 'Prawns, onion, coconut or tomato base, oil, spices'),
    LibraryFood(name: 'Vegetable Curry', category: 'South Asian', serving: '200g', kcal: 170, proteinG: 4.0, carbG: 16.0, fatG: 10.0, ingredients: 'Mixed vegetables, onion, tomato, oil, spices'),
    LibraryFood(name: 'Chicken Bhuna', category: 'Bengali', serving: '150g', kcal: 272, proteinG: 26.0, carbG: 6.0, fatG: 16.0, ingredients: 'Chicken, onion, mustard oil, bhuna spices, minimal gravy'),
    LibraryFood(name: 'Mutton Bhuna', category: 'Bengali', serving: '150g', kcal: 314, proteinG: 24.0, carbG: 5.0, fatG: 22.0, ingredients: 'Mutton, onion, mustard oil, bhuna spices'),
    LibraryFood(name: 'Duck Curry (Hasher Mangsho)', category: 'Bengali', serving: '150g', kcal: 342, proteinG: 22.0, carbG: 5.0, fatG: 26.0, ingredients: 'Duck, onion, coconut, mustard oil, spices'),
    LibraryFood(name: 'Chicken Jhol', category: 'Bengali', serving: '200g light curry', kcal: 201, proteinG: 24.0, carbG: 6.0, fatG: 9.0, ingredients: 'Chicken, potato, thin gravy, mustard oil, turmeric'),
```

- [ ] **Step 6: Append the Bengali everyday gaps**

```dart
    // ---------------- V2 AUDIT: BENGALI EVERYDAY ----------------
    LibraryFood(name: 'Shorshe Bata Mach', category: 'Bengali', serving: '150g', kcal: 252, proteinG: 22.0, carbG: 5.0, fatG: 16.0, ingredients: 'Fish, mustard paste, mustard oil, green chilli, turmeric'),
    LibraryFood(name: 'Shorshe Chingri', category: 'Bengali', serving: '120g', kcal: 222, proteinG: 19.0, carbG: 5.0, fatG: 14.0, ingredients: 'Prawns, mustard paste, mustard oil, green chilli'),
    LibraryFood(name: 'Chingri Bhorta', category: 'Bengali', serving: '100g', kcal: 162, proteinG: 14.0, carbG: 4.0, fatG: 10.0, ingredients: 'Prawns, onion, green chilli, mustard oil, coriander'),
    LibraryFood(name: 'Lau Chingri', category: 'Bengali', serving: '200g', kcal: 161, proteinG: 12.0, carbG: 8.0, fatG: 9.0, ingredients: 'Bottle gourd, prawns, mustard oil, panch phoron'),
    LibraryFood(name: 'Fish Fry (Bengali)', category: 'Bengali', serving: '100g coated fillet', kcal: 230, proteinG: 18.0, carbG: 8.0, fatG: 14.0, ingredients: 'Fish, semolina or breadcrumb coating, oil, spices'),
    LibraryFood(name: 'Chicken Fry (Bengali)', category: 'Bengali', serving: '1 piece', kcal: 239, proteinG: 20.0, carbG: 6.0, fatG: 15.0, ingredients: 'Chicken, marinade spices, oil, light batter'),
    LibraryFood(name: 'Aloo Bhorta with Mustard Oil', category: 'Bengali', serving: '100g', kcal: 152, proteinG: 2.0, carbG: 18.0, fatG: 8.0, ingredients: 'Boiled potato, onion, green chilli, mustard oil, salt'),
    LibraryFood(name: 'Tehari (Chicken)', category: 'Bengali', serving: '300g', kcal: 532, proteinG: 26.0, carbG: 62.0, fatG: 20.0, ingredients: 'Chinigura rice, chicken, mustard oil, tehari spices'),
    LibraryFood(name: 'Tehari (Mutton)', category: 'Bengali', serving: '300g', kcal: 574, proteinG: 25.0, carbG: 60.0, fatG: 26.0, ingredients: 'Chinigura rice, mutton, mustard oil, tehari spices'),
    LibraryFood(name: 'Chicken Khichuri', category: 'Bengali', serving: '350g', kcal: 472, proteinG: 24.0, carbG: 58.0, fatG: 16.0, ingredients: 'Rice, moong dal, chicken, ghee, spices'),
    LibraryFood(name: 'Dim Khichuri', category: 'Bengali', serving: '350g', kcal: 447, proteinG: 18.0, carbG: 60.0, fatG: 15.0, ingredients: 'Rice, moong dal, egg, ghee, spices'),
    LibraryFood(name: 'Vegetable Khichuri', category: 'Bengali', serving: '350g', kcal: 404, proteinG: 12.0, carbG: 62.0, fatG: 12.0, ingredients: 'Rice, moong dal, mixed vegetables, ghee, spices'),
    LibraryFood(name: 'Dal Bhat', category: 'Bengali', serving: '350g', kcal: 374, proteinG: 12.0, carbG: 68.0, fatG: 6.0, ingredients: 'White rice, masoor dal, oil, turmeric'),
```

- [ ] **Step 7: Append the remaining staples**

```dart
    // ---------------- V2 AUDIT: STAPLES AND DRINKS ----------------
    LibraryFood(name: 'Chola Boot', category: 'Legumes & Beans', serving: '150g', kcal: 205, proteinG: 10.0, carbG: 30.0, fatG: 5.0, ingredients: 'Boiled chickpeas, onion, green chilli, mustard oil, lemon'),
    LibraryFood(name: 'Mixed Fruit Salad', category: 'Fruit', serving: '200g', kcal: 110, proteinG: 1.5, carbG: 25.0, fatG: 0.5, ingredients: 'Seasonal fruit, no added sugar'),
    LibraryFood(name: 'Instant Coffee (black)', category: 'Drinks', serving: '1 cup', kcal: 3, proteinG: 0.2, carbG: 0.5, fatG: 0.0, ingredients: 'Instant coffee, water'),
    LibraryFood(name: 'Sugar-free Tea with Milk', category: 'Drinks', serving: '1 cup', kcal: 28, proteinG: 1.5, carbG: 2.0, fatG: 1.5, ingredients: 'Tea, milk, sweetener'),
```

- [ ] **Step 8: Run the library test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_library_test.dart`
Expected: PASS, 6 tests. If `the library grew to 472 items` reports a different count, you have added the wrong number of entries — count them rather than editing the expectation.

- [ ] **Step 9: Run the search test again**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_search_test.dart`
Expected: PASS, 24 tests. The `chicken curry` ranking case now has a generic `Chicken Curry` to find.

- [ ] **Step 10: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 164 tests.

- [ ] **Step 11: Commit**

```bash
git add lib/data/food_library.dart test/food_library_test.dart
git commit -m "feat(food): add 40 everyday dishes found missing in the library audit"
```

---

### Task 7: HOME — hub rebuild, nav order and default landing tab

**Files:**
- Modify: `lib/screens/today_tab.dart` (replace `_buildPreSession`, `_buildRestDay`, `_buildScheduledPreview`; add the hub sections)
- Modify: `lib/widgets/bottom_nav.dart` (order, pill active tile, no dividers)
- Modify: `lib/screens/main_screen.dart` (screen order, tab ids, default index)
- Test: `test/home_tab_test.dart` (create)

**Interfaces:**
- Consumes: `HeroCard`, `ActionItem`, `ActionGrid`, `CalmRow` from Task 2; `EnergyEstimator` and `SessionLog.kcalLabel` from Task 4; `JinatraTokens.accentAt` from Task 1.
- Produces:
  - `TodayTabState.onNavigate` — a `void Function(String tabId)?` callback the hub uses to switch tabs. Tab ids are exactly `'home'`, `'routines'`, `'food'`, `'body'`, `'log'`.
  - `TodayTab({Key? key, void Function(String tabId)? onNavigate, VoidCallback? onOpenSettings})`
  - `HomeHubSummary({required int kcalEaten, required int? kcalTarget, required double? weightKg, required double? weightDeltaKg, required double? burnedTodayKcal})` — the value object the hub renders, exposed so a test can build the hub without a database.
  - `BottomNav` tab order is `HOME, ROUTINES, FOOD, BODY, LOG`; `MainScreen` opens at index 0.

- [ ] **Step 1: Write the failing test**

Create `test/home_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/bottom_nav.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/hero_card.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  group('BottomNav', () {
    testWidgets('HOME is the first destination and LOG the last',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNav(currentIndex: 0, onTap: (_) {}),
        ),
      ));

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('ROUTINES'), findsOneWidget);
      expect(find.text('FOOD'), findsOneWidget);
      expect(find.text('BODY'), findsOneWidget);
      expect(find.text('LOG'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('tapping a destination reports its index', (tester) async {
      var tappedIndex = -1;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar:
              BottomNav(currentIndex: 0, onTap: (i) => tappedIndex = i),
        ),
      ));

      await tester.tap(find.text('BODY'));
      expect(tappedIndex, 3);
    });

    testWidgets('hiding the food tab shifts the later indices', (tester) async {
      var tappedIndex = -1;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNav(
            currentIndex: 0,
            foodTabEnabled: false,
            onTap: (i) => tappedIndex = i,
          ),
        ),
      ));

      expect(find.text('FOOD'), findsNothing);
      await tester.tap(find.text('BODY'));
      expect(tappedIndex, 2);
    });
  });

  group('HomeHub', () {
    testWidgets('renders one hero, the calm rows and eight action tiles',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeHub(
              eyebrow: 'TODAY - MON',
              title: 'LEGS',
              subtitle: '4 EX - 12 SETS',
              heroColor: Colors.orange,
              heroActions: const [],
              summary: const HomeHubSummary(
                kcalEaten: 1240,
                kcalTarget: 1850,
                weightKg: 72.5,
                weightDeltaKg: -0.4,
                burnedTodayKcal: 388.0,
              ),
              actions: List.generate(
                8,
                (i) => ActionItem(
                  label: 'A$i',
                  icon: Icons.circle,
                  color: Colors.blue,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ));

      expect(find.byType(HeroCard), findsOneWidget);
      expect(find.byType(CalmRow), findsNWidgets(3));
      expect(find.byType(ActionTile), findsNWidgets(8));
      expect(find.text('LEGS'), findsOneWidget);
      expect(find.text('1240 / 1850 kcal'), findsOneWidget);
      expect(find.text('72.5 kg  -0.4'), findsOneWidget);
      expect(find.text('~388 kcal'), findsOneWidget);
    });

    testWidgets('missing data shows a prompt rather than a fake number',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeHub(
              eyebrow: 'TODAY - TUE',
              title: 'REST DAY',
              heroColor: Colors.grey,
              heroActions: const [],
              summary: const HomeHubSummary(
                kcalEaten: 0,
                kcalTarget: null,
                weightKg: null,
                weightDeltaKg: null,
                burnedTodayKcal: null,
              ),
              actions: const [],
            ),
          ),
        ),
      ));

      expect(find.text('SET A GOAL'), findsOneWidget);
      expect(find.text('LOG A WEIGHT'), findsOneWidget);
      expect(find.text('NO SESSION YET'), findsOneWidget);
    });
  });
}
```

Add the import for the hub once it exists:

```dart
import 'package:lockout/widgets/home_hub.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/home_tab_test.dart`
Expected: FAIL — `HOME` not found (nav still says `TODAY`), and `Undefined name 'HomeHub'`.

- [ ] **Step 3: Extract the hub as its own widget**

`today_tab.dart` is 874 lines and owns the whole live-session state machine. The hub is pure presentation, so it goes in its own file — that is what lets the test above build it with no database.

Create `lib/widgets/home_hub.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import 'action_grid.dart';
import 'calm_row.dart';
import 'hero_card.dart';

/// Everything the hub needs to render, resolved by the caller.
///
/// Nulls are meaningful: they mean "not on record", and the hub renders a
/// prompt instead of a number. A zero would be a lie.
class HomeHubSummary {
  final int kcalEaten;
  final int? kcalTarget;
  final double? weightKg;
  final double? weightDeltaKg;
  final double? burnedTodayKcal;

  const HomeHubSummary({
    required this.kcalEaten,
    required this.kcalTarget,
    required this.weightKg,
    required this.weightDeltaKg,
    required this.burnedTodayKcal,
  });
}

/// The HOME landing screen: one hero, three calm rows, a colour action grid.
///
/// Presentation only — every value and every tap handler is passed in, so
/// this file has no dependency on the database or on the session state
/// machine that lives in `today_tab.dart`.
class HomeHub extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Color heroColor;
  final List<Widget> heroActions;
  final HomeHubSummary summary;
  final List<ActionItem> actions;
  final VoidCallback? onOpenFood;
  final VoidCallback? onOpenBody;
  final VoidCallback? onOpenLog;

  const HomeHub({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.heroColor,
    required this.heroActions,
    required this.summary,
    required this.actions,
    this.onOpenFood,
    this.onOpenBody,
    this.onOpenLog,
  });

  String get _intakeValue {
    final target = summary.kcalTarget;
    if (target == null) return 'SET A GOAL';
    return '${summary.kcalEaten} / $target kcal';
  }

  String get _weightValue {
    final w = summary.weightKg;
    if (w == null) return 'LOG A WEIGHT';
    final delta = summary.weightDeltaKg;
    if (delta == null) return '${w.toStringAsFixed(1)} kg';
    final sign = delta > 0 ? '+' : '';
    return '${w.toStringAsFixed(1)} kg  $sign${delta.toStringAsFixed(1)}';
  }

  String get _burnValue {
    final b = summary.burnedTodayKcal;
    if (b == null || b <= 0) return 'NO SESSION YET';
    return '~${b.round()} kcal';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroCard(
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          background: heroColor,
          actions: heroActions,
        ),
        CalmRow(
          icon: Icons.restaurant,
          title: 'CALORIES',
          value: _intakeValue,
          onTap: onOpenFood,
        ),
        CalmRow(
          icon: Icons.monitor_weight,
          title: 'BODYWEIGHT',
          value: _weightValue,
          onTap: onOpenBody,
        ),
        CalmRow(
          icon: Icons.local_fire_department,
          title: 'BURNED TODAY',
          value: _burnValue,
          onTap: onOpenLog,
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'QUICK ACTIONS',
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: JinatraTokens.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          ActionGrid(items: actions),
        ],
        const SizedBox(height: 28),
      ],
    );
  }
}
```

- [ ] **Step 4: Rebuild the nav**

Replace the `tabs` list and the tile decoration in `lib/widgets/bottom_nav.dart`. The list becomes:

```dart
    final tabs = [
      {'label': 'HOME', 'icon': Icons.home},
      {'label': 'ROUTINES', 'icon': Icons.fitness_center},
      if (foodTabEnabled) {'label': 'FOOD', 'icon': Icons.restaurant},
      {'label': 'BODY', 'icon': Icons.monitor_weight},
      {'label': 'LOG', 'icon': Icons.calendar_month},
    ];
```

and the per-tab `AnimatedContainer` becomes a pill tile with no dividers:

```dart
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: isActive
                        ? JinatraTokens.cardDecoration(
                            background: JinatraTokens.deepTeal,
                            shadowOffset: JinatraTokens.shadowSm,
                            radius: JinatraTokens.radiusPill,
                          )
                        : const BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: isActive
                              ? JinatraTokens.onPrimary
                              : JinatraTokens.ink.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['label'] as String,
                          style: JinatraTokens.monoData(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? JinatraTokens.onPrimary
                                : JinatraTokens.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
```

- [ ] **Step 5: Reorder MainScreen and land on HOME**

In `lib/screens/main_screen.dart`, `_currentIndex` already starts at 0, which is now HOME. Reorder both lists so the index the nav reports lines up:

```dart
  List<Widget> get _screens => [
        TodayTab(key: _todayKey, onNavigate: _goToTab),
        RoutinesTab(key: _routinesKey),
        if (_foodTabEnabled) FoodTab(key: _foodKey),
        BodyTab(key: _bodyKey),
        LogTab(key: _logKey),
      ];

  /// Labels aligned with `_screens`, used to decide which key to refresh.
  List<String> get _tabIds => [
        'home',
        'routines',
        if (_foodTabEnabled) 'food',
        'body',
        'log',
      ];
```

Update `_refreshVisibleTab`'s switch so `'home'` refreshes `_todayKey` (rename the `'today'` case to `'home'`; leave the other cases alone).

Add the id-based navigation the hub's tiles use:

```dart
  /// Lets HOME's action grid switch tabs by id. Ids rather than indices,
  /// because hiding the Food tab shifts every index after it.
  void _goToTab(String tabId) {
    final index = _tabIds.indexOf(tabId);
    if (index < 0) return;
    _onTabTapped(index);
  }
```

- [ ] **Step 6: Use the hub in TodayTab**

In `lib/screens/today_tab.dart`:

Add the constructor parameter:

```dart
class TodayTab extends StatefulWidget {
  /// Switches tabs by id — 'routines', 'food', 'body', 'log'. Supplied by
  /// MainScreen; null in tests that pump this tab on its own.
  final void Function(String tabId)? onNavigate;

  const TodayTab({super.key, this.onNavigate});

  @override
  State<TodayTab> createState() => TodayTabState();
}
```

Add the imports:

```dart
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../widgets/action_grid.dart';
import '../widgets/home_hub.dart';
```

Add hub state next to `_scheduled`:

```dart
  HomeHubSummary _summary = const HomeHubSummary(
    kcalEaten: 0,
    kcalTarget: null,
    weightKg: null,
    weightDeltaKg: null,
    burnedTodayKcal: null,
  );
```

Extend `_loadSchedule` to fill it. Add this method and call it from `_loadSchedule` after the existing `setState`:

```dart
  /// Resolves the three calm-row values. Every one of them can legitimately
  /// be unknown, and the hub renders a prompt for a null rather than a zero.
  Future<void> _loadSummary() async {
    final today = ScheduleService.dateKey(DateTime.now());
    final db = DatabaseService.instance;

    final foodRows = await db.getFoodLogsForDate(today);
    final eaten = foodRows.fold<int>(
      0,
      (sum, row) => sum + ((row['kcal'] as num?)?.toInt() ?? 0),
    );

    final snapshot = await GoalService.instance.snapshot();

    final bodyRows = await db.getBodyLogs();
    double? delta;
    if (bodyRows.length >= 2) {
      final latest = (bodyRows[0]['weight_kg'] as num).toDouble();
      final previous = (bodyRows[1]['weight_kg'] as num).toDouble();
      delta = latest - previous;
    }

    final sessionRows = await db.getSessionLogs();
    final burnedToday = sessionRows
        .where((r) => r['date_str'] == today)
        .fold<double>(
          0.0,
          (sum, r) => sum + ((r['kcal_burned'] as num?)?.toDouble() ?? 0.0),
        );

    if (!mounted) return;
    setState(() {
      _summary = HomeHubSummary(
        kcalEaten: eaten,
        kcalTarget: snapshot.nutrition?.targetKcal,
        weightKg: snapshot.currentWeightKg,
        weightDeltaKg: delta,
        burnedTodayKcal: burnedToday > 0 ? burnedToday : null,
      );
    });
  }
```

If `getBodyLogs()` does not already return newest-first, sort by `date_str` descending before taking `[0]` and `[1]`. If `NutritionPlan`'s calorie field is not named `targetKcal`, use its actual name — `grep -n "class NutritionPlan" -A 15 lib/services/nutrition_planner.dart`.

Replace `_buildPreSession`, `_buildRestDay` and `_buildScheduledPreview` with a single hub builder:

```dart
  // --- PRE-SESSION (the HOME hub) ---

  Widget _buildPreSession() {
    final sched = _scheduled;
    final code = ScheduleService.weekdayCode(DateTime.now());
    final isRest = sched == null;

    return SingleChildScrollView(
      child: HomeHub(
        eyebrow: 'TODAY - $code',
        title: isRest ? 'REST DAY' : sched.day.name,
        subtitle: isRest
            ? 'Nothing scheduled. Train off-plan or take the day.'
            : _scheduleSubtitle(sched),
        heroColor: JinatraTokens.accentAt(isRest ? 7 : 0),
        heroActions: [
          if (!isRest)
            JinatraButton(
              label: 'START SESSION',
              onPressed: _startScheduledSession,
            ),
          JinatraButton(
            label: 'CUSTOM SESSION',
            isSignal: true,
            onPressed: _startCustomSession,
          ),
        ],
        summary: _summary,
        onOpenFood: () => widget.onNavigate?.call('food'),
        onOpenBody: () => widget.onNavigate?.call('body'),
        onOpenLog: () => widget.onNavigate?.call('log'),
        actions: _quickActions(),
      ),
    );
  }

  String _scheduleSubtitle(ScheduledDay sched) {
    final sets = sched.exercises.fold<int>(0, (s, e) => s + e.targetSets);
    return '${sched.exercises.length} EX - $sets SETS';
  }

  List<ActionItem> _quickActions() {
    final go = widget.onNavigate;
    return [
      ActionItem(
        label: 'LOG FOOD',
        icon: Icons.restaurant,
        color: JinatraTokens.accentAt(0),
        onTap: () => go?.call('food'),
      ),
      ActionItem(
        label: 'WEIGH IN',
        icon: Icons.monitor_weight,
        color: JinatraTokens.accentAt(1),
        onTap: () => go?.call('body'),
      ),
      ActionItem(
        label: 'ROUTINES',
        icon: Icons.fitness_center,
        color: JinatraTokens.accentAt(2),
        onTap: () => go?.call('routines'),
      ),
      ActionItem(
        label: 'HISTORY',
        icon: Icons.calendar_month,
        color: JinatraTokens.accentAt(3),
        onTap: () => go?.call('log'),
      ),
      ActionItem(
        label: 'CUSTOM',
        icon: Icons.add,
        color: JinatraTokens.accentAt(4),
        onTap: _startCustomSession,
      ),
      ActionItem(
        label: 'STREAK',
        icon: Icons.local_fire_department,
        color: JinatraTokens.accentAt(5),
        onTap: () => go?.call('log'),
      ),
      ActionItem(
        label: 'PLAN',
        icon: Icons.insights,
        color: JinatraTokens.accentAt(6),
        onTap: () => go?.call('body'),
      ),
      ActionItem(
        label: 'EXERCISES',
        icon: Icons.list,
        color: JinatraTokens.accentAt(7),
        onTap: () => go?.call('routines'),
      ),
    ];
  }
```

Update `reload()` so both loads run:

```dart
  Future<void> reload() async {
    await _loadSchedule();
    await _loadSummary();
  }
```

and call `_loadSummary()` at the end of `initState`'s load chain by replacing `_loadSchedule();` with `reload();`.

- [ ] **Step 7: Restyle the live session to v2**

Still in `today_tab.dart`, in `_buildActiveSession` and `_buildExerciseCard`, no structural change: they already use `JinatraCard` and `JinatraButton`, which became rounded in Task 2. Two adjustments:

- The elapsed/volume header block becomes a `HeroCard` so the active session also has exactly one saturated block. Replace the header container with:

```dart
        HeroCard(
          eyebrow: 'IN SESSION - $_sessionTitle',
          title: _elapsedLabel,
          subtitle: '$_sessionCompletedSets SETS - ${_sessionVolumeKg.toInt()} KG',
          background: JinatraTokens.accentAt(0),
        ),
```

using whatever the file already calls the elapsed-time string; if there is no getter, add `String get _elapsedLabel` returning `'${_elapsedSeconds ~/ 60}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}'`.

- `_buildRestBar` moves from an inline block to the Scaffold's `bottomNavigationBar` slot, so it stays visible while the user scrolls. In `build`, when `_sessionActive && _restRunning`, pass `bottomNavigationBar: _buildRestBar()`.

- [ ] **Step 8: Run the home test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/home_tab_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 9: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 169 tests.

- [ ] **Step 10: Commit**

```bash
git add lib/widgets/home_hub.dart lib/widgets/bottom_nav.dart lib/screens/today_tab.dart lib/screens/main_screen.dart test/home_tab_test.dart
git commit -m "feat(home): hub landing screen, HOME-first nav, pill active tile"
```

---

### Task 8: ROUTINES — week rows and a day detail sheet

The routine list is the most deeply nested screen in the app: a routine card holds day cards, which expand inline to hold warm-up, exercise and finisher blocks. v2 flattens it — the week is seven rows, and a day's detail opens in a sheet.

**Files:**
- Create: `lib/widgets/day_row.dart`
- Modify: `lib/screens/routines_tab.dart` (`_buildRoutineCard`, `_buildDayCard` → row + sheet; forms into sheets)
- Test: `test/day_row_test.dart` (create)

**Interfaces:**
- Consumes: `DayColours.assign` and `DayColours.onColorFor` from Task 3; `showJinatraSheet` from Task 2.
- Produces:
  - `DayRow({Key? key, required TrainingDay day, required Color accent, required String summary, required bool isToday, required VoidCallback onTap})`
  - `dayRowSummary(TrainingDay day)` → `String` — `'REST'`, `'EMPTY'`, or `'4 EX - 12 SETS'`

- [ ] **Step 1: Write the failing test**

Create `test/day_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/day_row.dart';

TrainingDay _day({
  String id = 'mon',
  String name = 'Legs',
  String tag = 'MON',
  bool rest = false,
  List<ExerciseDef> exercises = const [],
}) =>
    TrainingDay(
      id: id,
      routineId: 'r1',
      name: name,
      tag: tag,
      orderIndex: 0,
      isRestDay: rest,
      exercises: exercises,
    );

ExerciseDef _ex(String name, int sets) => ExerciseDef(
      id: name,
      dayId: 'mon',
      name: name,
      targetSets: sets,
      targetRepsMin: 8,
      targetRepsMax: 12,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  group('dayRowSummary', () {
    test('a rest day says REST', () {
      expect(dayRowSummary(_day(name: 'Off', rest: true)), 'REST');
    });

    test('a training day with no exercises says EMPTY', () {
      expect(dayRowSummary(_day()), 'EMPTY');
    });

    test('a populated day counts exercises and sets', () {
      final day = _day(exercises: [
        _ex('Leg Press', 4),
        _ex('Leg Curl', 3),
      ]);
      expect(dayRowSummary(day), '2 EX - 7 SETS');
    });
  });

  group('DayRow', () {
    testWidgets('shows the weekday tag, name and summary', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayRow(
            day: _day(exercises: [_ex('Leg Press', 4)]),
            accent: Colors.green,
            summary: '1 EX - 4 SETS',
            isToday: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('MON'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('1 EX - 4 SETS'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('marks today and reports a tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayRow(
            day: _day(),
            accent: Colors.green,
            summary: 'EMPTY',
            isToday: true,
            onTap: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('TODAY'), findsOneWidget);
      await tester.tap(find.byType(DayRow));
      expect(tapped, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/day_row_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/widgets/day_row.dart'`.

- [ ] **Step 3: Create DayRow**

Create `lib/widgets/day_row.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';
import 'day_block.dart';

/// One line of summary for a day, so the week reads without expanding
/// anything.
String dayRowSummary(TrainingDay day) {
  if (day.isRestDay) return 'REST';
  if (day.exercises.isEmpty) return 'EMPTY';
  final sets = day.exercises.fold<int>(0, (s, e) => s + e.targetSets);
  return '${day.exercises.length} EX - $sets SETS';
}

/// A compact day in the training week: a coloured rail carrying the weekday,
/// then the day name and its one-line summary.
///
/// v1 filled the whole card with the day colour and expanded detail inline.
/// Seven saturated cards stacked meant the week had no visual hierarchy at
/// all, and the inline expansion nested a third level of bordered boxes. The
/// colour now identifies from a rail; the detail lives in a sheet.
class DayRow extends StatelessWidget {
  final TrainingDay day;
  final Color accent;
  final String summary;
  final bool isToday;
  final VoidCallback onTap;

  const DayRow({
    super.key,
    required this.day,
    required this.accent,
    required this.summary,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onAccent = DayColours.onColorFor(accent);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: JinatraTokens.cardDecoration(
          shadowOffset: JinatraTokens.shadowSm,
          borderColor: isToday ? JinatraTokens.signal : JinatraTokens.ink,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(JinatraTokens.radiusCard - 3),
                  bottomLeft: Radius.circular(JinatraTokens.radiusCard - 3),
                ),
              ),
              child: Text(
                day.tag.toUpperCase(),
                style: JinatraTokens.monoData(fontSize: 11, color: onAccent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          day.name,
                          overflow: TextOverflow.ellipsis,
                          style: JinatraTokens.sectionHeader(fontSize: 15),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: JinatraTokens.cardDecoration(
                            background: JinatraTokens.signal,
                            borderWidth: JinatraTokens.borderDivider,
                            hasShadow: false,
                            radius: JinatraTokens.radiusPill,
                          ),
                          child: Text(
                            'TODAY',
                            style: JinatraTokens.monoData(
                              fontSize: 8,
                              color: JinatraTokens.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    style: JinatraTokens.monoData(
                      fontSize: 10,
                      color: JinatraTokens.ink.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: JinatraTokens.ink.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace the day cards with rows**

In `lib/screens/routines_tab.dart`, add the imports:

```dart
import '../widgets/day_row.dart';
import '../widgets/sheet_scaffold.dart';
```

In the `TRAINING WEEK` section of `_buildRoutineCard`, replace the day-card loop written in Task 3 with rows that open a sheet:

```dart
              ...(() {
                final colours = DayColours.assign(routine.days);
                final todayCode = ScheduleService.weekdayCode(DateTime.now());
                return routine.days.map((day) {
                  return DayRow(
                    day: day,
                    accent: colours[day.id] ?? DayColours.restColour,
                    summary: dayRowSummary(day),
                    isToday: day.tag.toUpperCase() == todayCode,
                    onTap: () => _openDaySheet(routine, day),
                  );
                }).toList();
              })(),
```

Add the sheet opener. It reuses the existing `_buildDayDetail` body verbatim — that method already renders warm-up, exercises and finisher, and it does not need rewriting, only rehousing:

```dart
  /// Opens a day's detail in a sheet rather than expanding it inline.
  ///
  /// The routine list was three levels of bordered box deep; a sheet gives
  /// the detail the whole screen and leaves the week scannable behind it.
  Future<void> _openDaySheet(Routine routine, TrainingDay day) async {
    await showJinatraSheet<void>(
      context: context,
      title: '${day.tag} - ${day.name}',
      builder: (ctx) => _buildDayDetail(routine, day),
    );
    if (!mounted) return;
    await reload();
  }
```

Match `_buildDayDetail`'s existing parameter list; if it takes more arguments (an expansion flag, callbacks), drop the ones that only existed to drive inline expansion and pass the rest unchanged.

Then delete `_buildDayCard` and the `_expanded`-style state that only served inline expansion. Run `grep -n "_expandedDays\|_buildDayCard" lib/screens/routines_tab.dart` and remove every hit.

- [ ] **Step 5: Move the routine and day forms into sheets**

`routines_tab.dart` has four inline form blocks: create routine (near line 140), add/edit day (near line 316), add warm-up/finisher item (near line 436), and add/edit exercise (near line 580). Each is already a self-contained builder. For each one, replace the surrounding inline container with a sheet call, e.g. for the create form:

```dart
  Future<void> _openCreateRoutineSheet() async {
    await showJinatraSheet<void>(
      context: context,
      title: 'CREATE NEW ROUTINE',
      builder: (ctx) => _buildCreateRoutineForm(),
    );
    if (!mounted) return;
    await reload();
  }
```

renaming each existing builder to `_build...Form` and having it return just the fields plus its save button. The `+ NEW` button in the header calls `_openCreateRoutineSheet`.

- [ ] **Step 6: Compact the routine header**

In `_buildRoutineCard`, the header currently renders the name, three filled tags and a delete icon. Make the tags outlines and move destructive actions into a menu:

```dart
            Row(
              children: [
                Expanded(
                  child: Text(
                    routine.name,
                    style: JinatraTokens.sectionHeader(fontSize: 18),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: JinatraTokens.ink),
                  onSelected: (v) {
                    if (v == 'active') _setActive(routine);
                    if (v == 'delete') _confirmDelete(routine);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'active', child: Text('SET AS ACTIVE')),
                    PopupMenuItem(value: 'delete', child: Text('DELETE')),
                  ],
                ),
              ],
            ),
```

using the existing method names for set-active and delete (`grep -n "SET AS ACTIVE" -B 20 lib/screens/routines_tab.dart` to find them).

Change `_tag(...)` so the chip is an outline, keeping the filled variant only for `ACTIVE`:

```dart
  Widget _tag(String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: JinatraTokens.cardDecoration(
        background: filled ? color : Colors.transparent,
        borderColor: filled ? JinatraTokens.ink : color,
        borderWidth: JinatraTokens.borderDivider,
        hasShadow: false,
        radius: JinatraTokens.radiusPill,
      ),
      child: Text(
        label,
        style: JinatraTokens.monoData(
          fontSize: 9,
          color: filled ? JinatraTokens.onAccentColor(color) : color,
        ),
      ),
    );
  }
```

Update the existing `_tag('ACTIVE', ...)` call to pass `filled: true`; every other call keeps the default.

- [ ] **Step 7: Run the day row test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/day_row_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 8: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 174 tests.

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/day_row.dart lib/screens/routines_tab.dart test/day_row_test.dart
git commit -m "refactor(routines): flatten the week to rows and move day detail into a sheet"
```

---

### Task 9: FOOD — kcal hero, macro tiles, meal sections

**Files:**
- Create: `lib/widgets/meal_section.dart`
- Create: `lib/widgets/progress_hero.dart`
- Modify: `lib/screens/food_tab.dart`
- Test: `test/food_tab_test.dart` (create)

**Interfaces:**
- Consumes: `HeroCard`, `StatTile`, `showJinatraSheet` from Task 2; `FoodEntry` from `lib/models/models.dart`.
- Produces:
  - `ProgressHero({Key? key, required String eyebrow, required String title, required String subtitle, required double progress, required Color background})` — `progress` clamped to `0.0..1.0`
  - `MealSection({Key? key, required String title, required List<FoodEntry> entries, required void Function(FoodEntry) onDelete})`
  - `mealSubtotalKcal(List<FoodEntry> entries)` → `int`

- [ ] **Step 1: Write the failing test**

Create `test/food_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/meal_section.dart';
import 'package:lockout/widgets/progress_hero.dart';

FoodEntry _entry(String name, int kcal, String slot) => FoodEntry(
      id: name,
      dateStr: '2026-09-09',
      mealSlot: slot,
      name: name,
      kcal: kcal,
      proteinG: 10.0,
      carbG: 20.0,
      fatG: 5.0,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  group('mealSubtotalKcal', () {
    test('sums the entries', () {
      expect(
        mealSubtotalKcal([
          _entry('Paratha', 354, 'Breakfast'),
          _entry('Cheese Omelette', 225, 'Breakfast'),
        ]),
        579,
      );
    });

    test('an empty meal is zero', () {
      expect(mealSubtotalKcal(const []), 0);
    });
  });

  group('ProgressHero', () {
    testWidgets('renders its text and clamps an over-target progress',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProgressHero(
            eyebrow: 'TODAY',
            title: '1240 / 1850 KCAL',
            subtitle: '610 LEFT',
            progress: 1.8,
            background: Colors.orange,
          ),
        ),
      ));

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('1240 / 1850 KCAL'), findsOneWidget);
      expect(find.text('610 LEFT'), findsOneWidget);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 1.0);
    });

    testWidgets('a negative progress clamps to zero', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProgressHero(
            eyebrow: 'TODAY',
            title: '0 / 1850 KCAL',
            subtitle: '1850 LEFT',
            progress: -3.0,
            background: Colors.orange,
          ),
        ),
      ));

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.0);
    });
  });

  group('MealSection', () {
    testWidgets('shows the title, subtotal and every entry', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Breakfast',
            entries: [
              _entry('Paratha', 354, 'Breakfast'),
              _entry('Cheese Omelette', 225, 'Breakfast'),
            ],
            onDelete: (_) {},
          ),
        ),
      ));

      expect(find.text('BREAKFAST'), findsOneWidget);
      expect(find.text('579 kcal'), findsOneWidget);
      expect(find.text('Paratha'), findsOneWidget);
      expect(find.text('Cheese Omelette'), findsOneWidget);
    });

    testWidgets('an empty meal renders nothing at all', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Snacks',
            entries: const [],
            onDelete: (_) {},
          ),
        ),
      ));

      expect(find.text('SNACKS'), findsNothing);
    });

    testWidgets('deleting an entry reports it', (tester) async {
      FoodEntry? deleted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Lunch',
            entries: [_entry('Dal Bhat', 374, 'Lunch')],
            onDelete: (e) => deleted = e,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.close));
      expect(deleted?.name, 'Dal Bhat');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_tab_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/widgets/meal_section.dart'`.

- [ ] **Step 3: Create ProgressHero**

Create `lib/widgets/progress_hero.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// A hero card whose subject is a proportion — calories against a target.
///
/// The bar is clamped rather than allowed to overflow: going 300 kcal over
/// should read as "full and then some", not break the layout.
class ProgressHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  /// 0.0 to 1.0. Values outside that range are clamped.
  final double progress;

  final Color background;

  const ProgressHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final on = JinatraTokens.onAccentColor(background);
    final value = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: JinatraTokens.cardDecoration(
        background: background,
        shadowOffset: JinatraTokens.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: on.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: JinatraTokens.displayHeader(fontSize: 26, color: on),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: on, width: JinatraTokens.borderDivider),
              borderRadius: BorderRadius.circular(JinatraTokens.radiusPill),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(JinatraTokens.radiusPill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(on),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: on.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Create MealSection**

Create `lib/widgets/meal_section.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';

int mealSubtotalKcal(List<FoodEntry> entries) =>
    entries.fold<int>(0, (sum, e) => sum + e.kcal);

/// One meal's entries under a labelled rule with a subtotal.
///
/// v1 showed the day as one flat list, so "how much was lunch" could not be
/// answered without adding rows up by eye. An empty meal renders nothing
/// rather than an empty heading.
class MealSection extends StatelessWidget {
  final String title;
  final List<FoodEntry> entries;
  final void Function(FoodEntry) onDelete;

  const MealSection({
    super.key,
    required this.title,
    required this.entries,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: JinatraTokens.monoData(fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 2,
                  color: JinatraTokens.ink.withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${mealSubtotalKcal(entries)} kcal',
                style: JinatraTokens.monoData(
                  fontSize: 11,
                  color: JinatraTokens.deepTeal,
                ),
              ),
            ],
          ),
        ),
        ...entries.map((e) => _row(e)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _row(FoodEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: JinatraTokens.cardDecoration(
        borderWidth: JinatraTokens.borderDivider,
        shadowOffset: JinatraTokens.shadowSm,
        radius: JinatraTokens.radiusTile,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: JinatraTokens.bodyText(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'P ${e.proteinG.toStringAsFixed(0)}  '
                  'C ${e.carbG.toStringAsFixed(0)}  '
                  'F ${e.fatG.toStringAsFixed(0)}',
                  style: JinatraTokens.monoData(
                    fontSize: 9,
                    color: JinatraTokens.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${e.kcal}',
            style: JinatraTokens.monoData(fontSize: 13),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onDelete(e),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              size: 16,
              color: JinatraTokens.ink.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rebuild the Food tab body**

In `lib/screens/food_tab.dart`, add the imports:

```dart
import '../widgets/meal_section.dart';
import '../widgets/progress_hero.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/stat_tile.dart';
```

Replace the screen body (the inline `LOG MEAL ITEM` form plus the flat `NUTRITION LOG` list) with hero, macro tiles, a log pill and the meal sections:

```dart
  @override
  Widget build(BuildContext context) {
    final eaten = _foodLogs.fold<int>(0, (s, f) => s + f.kcal);
    final target = _targetKcal;
    final left = target == null ? null : target - eaten;

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProgressHero(
            eyebrow: 'TODAY',
            title: target == null
                ? '$eaten KCAL'
                : '$eaten / $target KCAL',
            subtitle: left == null
                ? 'SET A GOAL IN SETTINGS'
                : left >= 0
                    ? '$left LEFT'
                    : '${left.abs()} OVER',
            progress: target == null || target == 0 ? 0.0 : eaten / target,
            background: JinatraTokens.accentAt(0),
          ),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'PROTEIN',
                  value: '${_totalProtein.toStringAsFixed(0)} g',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'CARBS',
                  value: '${_totalCarb.toStringAsFixed(0)} g',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'FAT',
                  value: '${_totalFat.toStringAsFixed(0)} g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          JinatraButton(
            label: '+ LOG FOOD',
            icon: Icons.add,
            onPressed: _openLogSheet,
          ),
          const SizedBox(height: 20),
          ...FoodTabState.mealSlots.map(
            (slot) => MealSection(
              title: slot,
              entries: _foodLogs.where((f) => f.mealSlot == slot).toList(),
              onDelete: _deleteEntry,
            ),
          ),
          MealSection(
            title: 'Other',
            entries: _foodLogs
                .where((f) => !FoodTabState.mealSlots.contains(f.mealSlot))
                .toList(),
            onDelete: _deleteEntry,
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Future<void> _openLogSheet() async {
    await showJinatraSheet<void>(
      context: context,
      title: 'LOG MEAL ITEM',
      builder: (ctx) => _buildLogForm(),
    );
    if (!mounted) return;
    await reload();
  }
```

Rename the existing inline form builder to `_buildLogForm()` and have it return only the fields plus the save button. Add `_totalProtein`, `_totalCarb` and `_totalFat` getters if the file does not already have them:

```dart
  double get _totalProtein =>
      _foodLogs.fold<double>(0, (s, f) => s + f.proteinG);
  double get _totalCarb => _foodLogs.fold<double>(0, (s, f) => s + f.carbG);
  double get _totalFat => _foodLogs.fold<double>(0, (s, f) => s + f.fatG);
```

`_targetKcal` is the daily target; if the file does not already load it, read it in `reload()` from `GoalService.instance.snapshot()` the same way Task 7's `_loadSummary` does, and store it as `int? _targetKcal`. Add `_deleteEntry(FoodEntry)` if it does not exist, calling the existing delete path the flat list used.

- [ ] **Step 6: Run the food test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_tab_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 7: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 181 tests.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/meal_section.dart lib/widgets/progress_hero.dart lib/screens/food_tab.dart test/food_tab_test.dart
git commit -m "feat(food): kcal hero, macro tiles and per-meal sections"
```

---

### Task 10: BODY — trend hero, stat grid, reference behind rows

**Files:**
- Create: `lib/widgets/sparkline.dart`
- Modify: `lib/screens/body_tab.dart`
- Test: `test/body_tab_test.dart` (create)

**Interfaces:**
- Consumes: `StatTile`, `CalmRow`, `showJinatraSheet` from Task 2; `GoalService.snapshot()`.
- Produces:
  - `Sparkline({Key? key, required List<double> values, required Color lineColor, double height = 44, double strokeWidth = 2.5})`
  - `sparklineNormalise(List<double> values)` → `List<double>` — maps to `0.0..1.0`; a flat series returns all `0.5`; fewer than two values returns `const []`

- [ ] **Step 1: Write the failing test**

Create `test/body_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/sparkline.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  group('sparklineNormalise', () {
    test('maps the range onto 0..1', () {
      expect(sparklineNormalise([70.0, 72.0, 74.0]), [0.0, 0.5, 1.0]);
    });

    test('a flat series sits in the middle rather than dividing by zero', () {
      expect(sparklineNormalise([72.0, 72.0, 72.0]), [0.5, 0.5, 0.5]);
    });

    test('a series too short to draw returns nothing', () {
      expect(sparklineNormalise([72.0]), isEmpty);
      expect(sparklineNormalise(const []), isEmpty);
    });

    test('a descending series normalises without reordering', () {
      expect(sparklineNormalise([74.0, 72.0, 70.0]), [1.0, 0.5, 0.0]);
    });
  });

  group('Sparkline', () {
    testWidgets('draws when it has data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Sparkline(
            values: const [70.0, 71.5, 71.0, 72.4],
            lineColor: Colors.black,
          ),
        ),
      ));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders an empty box rather than failing on one point',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Sparkline(values: const [70.0], lineColor: Colors.black),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/body_tab_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/widgets/sparkline.dart'`.

- [ ] **Step 3: Create Sparkline**

Create `lib/widgets/sparkline.dart`:

```dart
import 'package:flutter/material.dart';

/// Scales [values] onto 0..1 for drawing, preserving order.
///
/// A flat series would divide by a zero range, so it is drawn as a centre
/// line instead. Fewer than two points cannot make a line at all.
List<double> sparklineNormalise(List<double> values) {
  if (values.length < 2) return const [];

  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  final range = max - min;

  if (range == 0) return values.map((_) => 0.5).toList();
  return values.map((v) => (v - min) / range).toList();
}

/// A minimal trend line — no axes, no labels, no grid.
///
/// The number beside it carries the value; this only has to show direction,
/// which is the one thing a column of logged weights does not communicate.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  final double height;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.values,
    required this.lineColor,
    this.height = 44,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final normalised = sparklineNormalise(values);
    if (normalised.isEmpty) return SizedBox(height: height);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: normalised,
          color: lineColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double strokeWidth;

  _SparklinePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final stepX = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      // Invert: 1.0 is the highest value, which is the top of the box.
      final y = size.height - (points[i] * size.height);
      final x = stepX * i;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
```

- [ ] **Step 4: Rebuild the Body tab body**

In `lib/screens/body_tab.dart`, add the imports:

```dart
import '../widgets/calm_row.dart';
import '../widgets/hero_card.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/sparkline.dart';
import '../widgets/stat_tile.dart';
```

Replace the screen body — the inline `LOG BODY METRICS` form, the BMI card, the goal card, the plan card and the history list — with a hero, a stat grid and rows. The existing `_buildBmiCard`, `_buildGoalCard`, `_buildPlanCard` and `_buildHistoryRow` builders are reused as sheet contents, not deleted.

```dart
  @override
  Widget build(BuildContext context) {
    final weights = _logs.map((l) => l.weightKg).toList().reversed.toList();
    final latest = weights.isEmpty ? null : weights.last;
    final delta = weights.length < 2
        ? null
        : weights.last - weights[weights.length - 2];

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeroCard(
            eyebrow: 'BODYWEIGHT',
            title: latest == null
                ? 'NO DATA YET'
                : '${latest.toStringAsFixed(1)} KG',
            subtitle: delta == null
                ? 'LOG A SECOND WEIGHT TO SEE A TREND'
                : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} KG '
                    'SINCE LAST ENTRY',
            background: JinatraTokens.accentAt(2),
            actions: [
              JinatraButton(
                label: '+ LOG MEASUREMENT',
                onPressed: _openMeasurementSheet,
              ),
            ],
          ),
          if (weights.length >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: JinatraTokens.cardDecoration(
                  shadowOffset: JinatraTokens.shadowSm,
                ),
                child: Sparkline(
                  values: weights,
                  lineColor: JinatraTokens.deepTeal,
                ),
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              StatTile(
                label: 'BMI',
                value: _bmi == null ? '--' : _bmi!.toStringAsFixed(1),
              ),
              StatTile(
                label: 'TARGET',
                value: _targetWeightKg == null
                    ? '--'
                    : '${_targetWeightKg!.toStringAsFixed(1)} kg',
              ),
              StatTile(
                label: 'DAILY INTAKE',
                value: _targetKcal == null ? '--' : '$_targetKcal kcal',
              ),
              StatTile(
                label: 'ENTRIES',
                value: '${_logs.length}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          CalmRow(
            icon: Icons.flag,
            title: 'GOAL PROGRESS',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'GOAL PROGRESS',
              builder: (ctx) => _buildGoalCard(),
            ),
          ),
          CalmRow(
            icon: Icons.insights,
            title: 'RECOMMENDED PLAN',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'RECOMMENDED TRAINING PLAN',
              builder: (ctx) => _buildPlanCard(),
            ),
          ),
          CalmRow(
            icon: Icons.straighten,
            title: 'HOW THIS BMI IS CALCULATED',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'BMI',
              builder: (ctx) => _buildBmiCard(),
            ),
          ),
          CalmRow(
            icon: Icons.history,
            title: 'LOG HISTORY',
            value: '${_logs.length}',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'LOG HISTORY',
              builder: (ctx) => Column(
                children: _logs.map(_buildHistoryRow).toList(),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Future<void> _openMeasurementSheet() async {
    await showJinatraSheet<void>(
      context: context,
      title: 'LOG BODY METRICS',
      builder: (ctx) => _buildMeasurementForm(),
    );
    if (!mounted) return;
    await reload();
  }
```

Rename the existing inline measurement form builder to `_buildMeasurementForm()`. Add `_bmi`, `_targetWeightKg` and `_targetKcal` fields if the file does not already hold them — the existing `_buildBmiCard` and `_buildGoalCard` read these values today, so reuse whatever they already read from `GoalSnapshot` rather than adding a second source.

- [ ] **Step 5: Run the body test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/body_tab_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 187 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/sparkline.dart lib/screens/body_tab.dart test/body_tab_test.dart
git commit -m "feat(body): weight trend hero, sparkline and stat grid"
```

---

### Task 11: LOG — streak hero and a compact archive

**Files:**
- Modify: `lib/screens/log_tab.dart`
- Test: `test/log_tab_test.dart` (create)

**Interfaces:**
- Consumes: `HeroCard`, `StatTile` from Task 2; `SessionLog.kcalLabel` from Task 4.
- Produces:
  - `sessionArchiveLine(SessionLog log)` → `String` — the archive card's mono detail line, joining date, duration, sets and (when present) the burn estimate with `'  -  '`

- [ ] **Step 1: Write the failing test**

Create `test/log_tab_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/screens/log_tab.dart';

SessionLog _log({double kcal = 0.0}) => SessionLog(
      id: 's1',
      dayName: 'MON - Legs',
      dateStr: '2026-09-07',
      durationSeconds: 3060,
      totalVolumeKg: 2295.0,
      status: 'completed',
      totalSets: 22,
      kcalBurned: kcal,
    );

void main() {
  group('sessionArchiveLine', () {
    test('includes the burn estimate when there is one', () {
      expect(
        sessionArchiveLine(_log(kcal: 388.7)),
        '2026-09-07  -  51 min  -  22 sets  -  ~389 kcal',
      );
    });

    test('omits the burn entirely when there is none', () {
      expect(
        sessionArchiveLine(_log()),
        '2026-09-07  -  51 min  -  22 sets',
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/log_tab_test.dart`
Expected: FAIL — `Undefined name 'sessionArchiveLine'`.

- [ ] **Step 3: Extract the archive line**

At the top of `lib/screens/log_tab.dart`, above the `LogTab` class, add:

```dart
/// The archive card's detail line.
///
/// A top-level function rather than a private method so it can be tested
/// without pumping the screen, and so the burn's presence rule lives in one
/// place: no estimate means the segment is absent, never "0 kcal".
String sessionArchiveLine(SessionLog log) => [
      log.dateStr,
      log.durationLabel,
      '${log.totalSets} sets',
      if (log.kcalLabel.isNotEmpty) log.kcalLabel,
    ].join('  -  ');
```

Replace the inline list built in Task 4 step 9 with a call to it:

```dart
                        sessionArchiveLine(log),
```

- [ ] **Step 4: Replace the streak block with a hero**

In `lib/screens/log_tab.dart`, the `CONSISTENCY` block is currently a filled container built inline. Replace it with:

```dart
          HeroCard(
            eyebrow: 'CONSISTENCY',
            title: _streakLabel,
            subtitle: '${_logs.length} WORKOUTS - '
                '${_totalVolumeAllTime.toInt()} KG TOTAL',
            background: JinatraTokens.accentAt(0),
          ),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'WORKOUTS',
                  value: '${_logs.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'TOTAL BURNED',
                  value: _totalBurnedLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
```

adding the imports:

```dart
import '../widgets/hero_card.dart';
import '../widgets/stat_tile.dart';
```

and the burn total next to `_totalVolumeAllTime`:

```dart
  double get _totalBurnedKcal =>
      _logs.fold<double>(0, (s, l) => s + l.kcalBurned);

  /// Estimates stay marked as estimates even in an aggregate.
  String get _totalBurnedLabel =>
      _totalBurnedKcal <= 0 ? '--' : '~${_totalBurnedKcal.round()} kcal';
```

`_streakLabel` is the existing streak string (the method that returns `'NO ACTIVE STREAK'` near line 103); use its real name.

- [ ] **Step 5: Collapse the archive cards and move delete into the expansion**

In `_buildLogCard`, the `DELETE ENTRY` link currently renders unconditionally. Move it inside the `if (isOpen)` branch, after the set list, so a closed card is header-only:

```dart
            GestureDetector(
              onTap: () => _confirmDelete(log),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'DELETE ENTRY',
                  style: JinatraTokens.monoData(
                    fontSize: 10,
                    color: JinatraTokens.signal,
                  ),
                ),
              ),
            ),
```

using the existing delete method's real name. `_expanded` already starts empty, so cards are closed by default — confirm nothing pre-populates it.

- [ ] **Step 6: Run the log test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/log_tab_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 7: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 189 tests.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/log_tab.dart test/log_tab_test.dart
git commit -m "feat(log): streak hero, burn totals and a header-only archive card"
```

---

### Task 12: Settings and video screen restyle

Restyle only — no information architecture change, per the spec's out-of-scope list.

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/screens/exercise_video_screen.dart`
- Test: `test/settings_restyle_test.dart` (create)

**Interfaces:**
- Consumes: `JinatraTokens.radiusCard/radiusTile/radiusPill`, `CalmRow`, `StatTile` from Tasks 1 and 2.
- Produces: no new public API.

- [ ] **Step 1: Write the failing test**

Create `test/settings_restyle_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

/// A structural guard rather than a behavioural test: the v2 sweep is only
/// finished when no widget draws a square corner or a raw hex colour.
void main() {
  group('v2 style sweep', () {
    test('no widget or screen uses BorderRadius.zero', () {
      final offenders = <String>[];
      for (final dir in ['lib/widgets', 'lib/screens']) {
        for (final f in Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
          if (f.readAsStringSync().contains('BorderRadius.zero')) {
            offenders.add(f.path);
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('screens do not hardcode palette colours', () {
      final offenders = <String>[];
      final hex = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
      for (final f in Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (hex.hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
      expect(offenders, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/settings_restyle_test.dart`
Expected: FAIL, listing the files that still hold a square corner or a hex colour. If it already passes, the earlier tasks' sweeps caught everything — go to step 4 and do the settings restyle anyway.

- [ ] **Step 3: Fix every offender**

For each file the test named:
- Replace `BorderRadius.zero` with `BorderRadius.circular(JinatraTokens.radiusTile)` for chips and controls, `radiusCard` for card-sized containers, `radiusPill` for buttons and toggles.
- Replace a hardcoded `Color(0xFF...)` with the semantic token it is standing in for: `JinatraTokens.ink`, `paper`, `sweetCream`, `mistTeal`, `deepTeal`, `signal`, or `JinatraTokens.accentAt(n)`. If the colour genuinely has no semantic role, it belongs in the palette — do not leave it in a screen.

- [ ] **Step 4: Restyle the settings sections**

In `lib/screens/settings_screen.dart`, keep every section and every control exactly where it is. Change only the chrome:

- Section headers become the `SectionHeading`-style rule already used in `day_block.dart` rather than filled bars.
- Each settings group sits in a `JinatraCard` at `shadowMd`.
- Toggle rows become `CalmRow`s where the row is purely navigational (e.g. "Backup & restore"); rows with an inline switch keep the switch and only take the rounded border.
- The theme picker's swatches become `radiusTile` squares and gain the palette's accent ramp as eight small dots under each palette name, so a user can see what they are choosing:

```dart
              Row(
                children: [
                  for (final accent in palette.accents)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: JinatraTokens.ink,
                          width: 1,
                        ),
                      ),
                    ),
                ],
              ),
```

- [ ] **Step 5: Restyle the video screen**

In `lib/screens/exercise_video_screen.dart`, the only changes are the rounded chrome inherited from the tokens plus wrapping the webview in a `radiusCard` clip so the corners match everything else:

```dart
        ClipRRect(
          borderRadius: BorderRadius.circular(JinatraTokens.radiusCard),
          child: /* the existing WebViewWidget */,
        ),
```

- [ ] **Step 6: Run the sweep test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/settings_restyle_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 7: Run the whole suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: PASS, 191 tests.

- [ ] **Step 8: Verify in the real app**

Run: `C:\src\flutter\bin\flutter.bat run -d <android device id>`
Walk all five tabs in a light palette (`Paper Press`) and a dark one (`Carbon Lime`). Check: one saturated hero per screen, no two training days sharing a colour, a kcal figure on a logged session, `ruti` finding Roti in the food picker.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/settings_screen.dart lib/screens/exercise_video_screen.dart test/settings_restyle_test.dart
git commit -m "refactor(ui): finish the v2 style sweep across settings and the video screen"
```

---

## Self-Review

**Spec coverage.** Every section of `docs/spine/specs/2026-09-09-lockout-ui-v2-design.md` maps to a task: §3.1 radii → Task 1; §3.2 accent ramp → Task 1; §3.3 colour discipline → Tasks 2, 8, 12; §3.4 shared widgets → Task 2; §4.1 HOME → Task 7; §4.2 ROUTINES → Task 8; §4.3 FOOD → Task 9; §4.4 BODY → Task 10; §4.5 LOG → Task 11; §4.6 nav → Task 7; §5 calories burned → Task 4; §6.1 search pipeline → Task 5; §6.2 library additions → Task 6; §7 day colours → Task 3; §8 in-scope files → Tasks 1-12; §11 verification → every task's run steps plus Task 12 step 8.

**Deviation from the spec's delivery order.** The spec lists 11 steps; this plan has 12 tasks because the spec's step 3 ("day colour assignment + Routines re-lay") is two independently reviewable deliverables — the colour rule is pure logic with a unit test, the re-lay is a screen rebuild. They are Tasks 3 and 8 here. The defect fixes (Tasks 3-6) also run before the screen rebuilds (7-12), so the three reported bugs are shippable without waiting for the redesign.

**Interface consistency.** `DayColours.assign` / `onColorFor` are used with those exact names in Tasks 3, 8 and 10's imports. `JinatraTokens.accentAt(int)` is defined in Task 1 and used in Tasks 2, 7, 8, 9, 10, 11. `SessionLog.kcalLabel` is defined in Task 4 and used in Tasks 4 and 11. `showJinatraSheet` is defined in Task 2 and used in Tasks 8, 9, 10. `HomeHubSummary`'s five fields are the same five in Task 7's test and its widget. `mealSubtotalKcal`, `sparklineNormalise` and `sessionArchiveLine` are each defined and consumed within one task.

**Known risks the implementer should expect.**
1. Several steps say "use the existing method's real name" for private members of large screen files (`routines_tab.dart` is 1324 lines, `settings_screen.dart` 1005). This is deliberate — inventing a name would silently create a second code path. Grep first.
2. `test/phase2_test.dart` asserts `AppPalette` shape and may need an `accents` list added to an inline construction (Task 1, step 8).
3. The parallel-test flakiness is pre-existing and unrelated to this work. Never "fix" a failure by switching off `--concurrency=1`.
4. `google_fonts` fetches font files at runtime, which conflicts with the app's zero-network claim. Out of scope here; worth its own task to bundle the four families as assets.
