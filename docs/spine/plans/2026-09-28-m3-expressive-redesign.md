# LOCKOUT Material 3 Expressive Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-dev (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Jinatra neubrutalist UI with a Material 3 Expressive system driven by real `ThemeData`, restructure navigation to five tabs, and make the Workout tab lead with today's training day instead of listing the whole week.

**Architecture:** A new `lib/theme/` layer builds a complete `ThemeData` from one of six authored `ColorScheme`s (3 dark, 3 light) or a dynamic Material You scheme, plus a `ThemeExtension` carrying the semantic colours M3 has no slot for. Every widget reads colour, type and shape from `Theme.of(context)`; the static `JinatraTokens`/`AppPalette` classes are deleted in the final task. Screens are migrated one per task so the tree compiles and tests pass throughout.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13.2, sqflite, `dynamic_color`, bundled Inter + JetBrains Mono. No `google_fonts`.

## Global Constraints

- SDK is **not on PATH**. Always invoke `C:\src\flutter\bin\flutter.bat` by absolute path.
- Tests are **serial only**: `C:\src\flutter\bin\flutter.bat test --concurrency=1`. The default parallel run produces ~10 spurious failures because suites share one sqflite file.
- Baseline to beat: **91 tests passing** serially.
- This branch is **UI-only**. No schema change, no migration, no change to behaviour in `lib/services/**` other than the one pure rename in Task 11. Any edit to `database_service.dart`, `backup_service.dart`, or a migration is a scope violation.
- App name stays **LOCKOUT**. "LIAD" in the design brief is a reference name only; it must not appear in shipped strings.
- Colour, type and shape resolve through `Theme.of(context)` — never a static class, never a compile-time `Color` constant in a widget.
- Shape scale: button 14, card 18, dialog 24, bottom sheet 28, text field 14, pill 999.
- Spacing on an 8dp grid: card padding 16, screen padding 20, section gap 24. Minimum touch target 48dp.
- Motion uses framework `Durations` / `Easing` tokens, 200–300ms. No bounce, no overshoot.
- Zero network at runtime. No package may fetch an asset at first paint.
- Commit after every task. Conventional commit prefixes (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`).

## File Structure and Seams

| File | Responsibility | Seam (the interface callers depend on) |
|---|---|---|
| `lib/theme/lockout_semantics.dart` | Semantic colours M3 lacks | `LockoutSemantics.of(context)`, `.categoryAt(int)` |
| `lib/theme/schemes.dart` | Six authored `ColorScheme` + semantics pairs | `LockoutScheme.byKey(String)`, `.all`, `.dark`, `.light`, `.fallback` |
| `lib/theme/lockout_theme.dart` | Turns a scheme into `ThemeData` | `LockoutTheme.build(colors:, semantics:)` + shape/spacing constants |
| `lib/theme/theme_controller.dart` | Persisted selection, dynamic availability | `ThemeController.instance`, `.lightTheme`, `.darkTheme`, `.themeMode`, `.select(key)` |
| `lib/screens/progress_tab.dart` | Hosts Body + Log under a segmented control | `ProgressTab`, `ProgressTabState.reload()`, `.showSegment(ProgressSegment)` |
| `lib/screens/profile_tab.dart` | Hosts settings as a tab | `ProfileTab`, `ProfileTabState.reload()` |
| `lib/services/routine_focus.dart` | Which day a routine card features, and why | `RoutineFocus.resolve(...) -> RoutineFocusResult` |
| `lib/widgets/today_day_card.dart` | The featured day card | `TodayDayCard(...)` |
| `lib/widgets/week_day_row.dart` | One collapsed row in the full week | `WeekDayRow(...)` |

---

### Task 1: Bundle fonts, swap dependencies

**Files:**
- Create: `assets/fonts/Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`
- Create: `assets/fonts/JetBrainsMono-Regular.ttf`, `JetBrainsMono-Bold.ttf`
- Create: `assets/fonts/OFL-Inter.txt`, `assets/fonts/OFL-JetBrainsMono.txt`
- Modify: `pubspec.yaml`
- Modify: `lib/theme/jinatra_tokens.dart:88-130` (the four text-style helpers)
- Test: `test/fonts_bundled_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: font families `'Inter'` and `'JetBrainsMono'` resolvable via `TextStyle(fontFamily: ...)` with no network. `google_fonts` is gone from the dependency tree. `dynamic_color` is available.

- [ ] **Step 1: Write the failing test**

```dart
// test/fonts_bundled_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Inter and JetBrains Mono ship as bundled assets', () {
    for (final name in const [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Bold.ttf',
    ]) {
      final file = File('assets/fonts/$name');
      expect(file.existsSync(), isTrue, reason: 'missing assets/fonts/$name');
      expect(file.lengthSync(), greaterThan(10000), reason: '$name looks truncated');
    }
  });

  test('pubspec declares both families and no longer depends on google_fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('family: Inter'), isTrue);
    expect(pubspec.contains('family: JetBrainsMono'), isTrue);
    expect(pubspec.contains('dynamic_color:'), isTrue);
    expect(
      pubspec.contains('google_fonts:'),
      isFalse,
      reason: 'google_fonts fetches typefaces over HTTP; this app is offline',
    );
  });

  test('no Dart source imports google_fonts', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('google_fonts')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/fonts_bundled_test.dart`
Expected: FAIL — "missing assets/fonts/Inter-Regular.ttf".

- [ ] **Step 3: Fetch the font files**

Both families are SIL Open Font License 1.1, so redistribution inside the APK is permitted provided the licence travels with them.

```bash
mkdir -p assets/fonts
cd assets/fonts
curl -L -o Inter-Regular.ttf  "https://github.com/rsms/inter/raw/v4.1/docs/font-files/InterVariable.ttf"
```

If the variable font is used, Flutter needs static instances instead. Prefer the static release to keep `fontWeight` predictable:

```bash
cd assets/fonts
curl -L -o inter.zip "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip"
unzip -j inter.zip "extras/ttf/Inter-Regular.ttf" "extras/ttf/Inter-Medium.ttf" "extras/ttf/Inter-SemiBold.ttf" "extras/ttf/Inter-Bold.ttf" -d .
curl -L -o OFL-Inter.txt "https://github.com/rsms/inter/raw/v4.1/LICENSE.txt"
rm inter.zip

curl -L -o jbmono.zip "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
unzip -j jbmono.zip "fonts/ttf/JetBrainsMono-Regular.ttf" "fonts/ttf/JetBrainsMono-Bold.ttf" -d .
curl -L -o OFL-JetBrainsMono.txt "https://github.com/JetBrains/JetBrainsMono/raw/v2.304/OFL.txt"
rm jbmono.zip
```

If a URL 404s because the release was re-tagged, download the family from its official page rather than substituting a different typeface. Report BLOCKED rather than shipping a lookalike.

- [ ] **Step 4: Declare the fonts and swap dependencies in `pubspec.yaml`**

Remove the `google_fonts: ^8.2.1` line. Add `dynamic_color: ^1.7.0` in its place. Then replace the `flutter:` section's asset block:

```yaml
flutter:
  uses-material-design: true

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/JetBrainsMono-Bold.ttf
          weight: 700
```

- [ ] **Step 5: Point the existing token text styles at the bundled families**

The old token class must keep compiling until Task 15 deletes it. In `lib/theme/jinatra_tokens.dart`, remove the `google_fonts` import and replace the four helpers:

```dart
  static TextStyle displayHeader({Color? color, double fontSize = 28.0}) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? ink,
      height: 1.02,
      letterSpacing: -0.5,
    );
  }

  static TextStyle sectionHeader({Color? color, double fontSize = 20.0}) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color ?? ink,
      height: 1.05,
    );
  }

  static TextStyle bodyText({
    Color? color,
    double fontSize = 15.0,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      height: 1.3,
    );
  }

  static TextStyle monoData({
    Color? color,
    double fontSize = 13.0,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: 0.2,
    );
  }
```

Note: Archivo w900 is gone. Inter's heaviest bundled weight is 700, which is what the new type scale specifies anyway.

- [ ] **Step 6: Resolve dependencies**

Run: `C:\src\flutter\bin\flutter.bat pub get`
Expected: resolves with `dynamic_color` added and `google_fonts` absent.

- [ ] **Step 7: Run the new test and the full suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: the three new tests PASS; the previous 91 still pass (94 total).

- [ ] **Step 8: Commit**

```bash
git add assets/fonts pubspec.yaml pubspec.lock lib/theme/jinatra_tokens.dart test/fonts_bundled_test.dart
git commit -m "chore(fonts): bundle Inter and JetBrains Mono, drop google_fonts

google_fonts fetches typefaces over HTTP at first paint. The APK is
zero-network on device, so every chosen face silently fell back to Roboto
in production. Bundling them is the only way the type scale actually ships.
Adds dynamic_color for the Material You theme option."
```

---

### Task 2: Authored colour schemes and the semantics extension

**Files:**
- Create: `lib/theme/lockout_semantics.dart`
- Create: `lib/theme/schemes.dart`
- Test: `test/schemes_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class LockoutSemantics extends ThemeExtension<LockoutSemantics>` with fields `success`, `warning`, `danger`, `restDay`, `chartLine`, `chartFill`, `categoryRamp` (`List<Color>`, exactly 8); methods `copyWith`, `lerp`, `Color categoryAt(int index)`, `static LockoutSemantics of(BuildContext context)`.
  - `class LockoutScheme` with `final String key, name; final Brightness brightness; final ColorScheme colors; final LockoutSemantics semantics;`
  - `LockoutScheme.graphite / ember / indigo / paper / linen / frost`
  - `static const List<LockoutScheme> dark, light, all`
  - `static const LockoutScheme fallback = graphite`
  - `static const String dynamicKey = 'dynamic'`
  - `static LockoutScheme byKey(String key)` — maps legacy Jinatra keys onto the nearest new scheme.

- [ ] **Step 1: Write the failing test**

```dart
// test/schemes_test.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/schemes.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('three dark and three light schemes, all keys unique', () {
    expect(LockoutScheme.dark.length, 3);
    expect(LockoutScheme.light.length, 3);
    expect(LockoutScheme.all.length, 6);
    final keys = LockoutScheme.all.map((s) => s.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('brightness matches the list the scheme lives in', () {
    for (final s in LockoutScheme.dark) {
      expect(s.brightness, Brightness.dark, reason: s.key);
      expect(s.colors.brightness, Brightness.dark, reason: s.key);
    }
    for (final s in LockoutScheme.light) {
      expect(s.brightness, Brightness.light, reason: s.key);
      expect(s.colors.brightness, Brightness.light, reason: s.key);
    }
  });

  test('graphite carries the design brief values exactly', () {
    final c = LockoutScheme.graphite.colors;
    expect(c.surface, const Color(0xFF080A0D));
    expect(c.primary, const Color(0xFFA3E86D));
    expect(c.onPrimary, const Color(0xFF101419));
    expect(c.secondary, const Color(0xFF75D9FF));
    expect(c.outline, const Color(0xFF272E36));
    expect(c.error, const Color(0xFFFF7777));
  });

  test('every foreground role is readable on its own background', () {
    for (final s in LockoutScheme.all) {
      final c = s.colors;
      final pairs = <String, List<Color>>{
        'onSurface': [c.onSurface, c.surface],
        'onPrimary': [c.onPrimary, c.primary],
        'onSecondary': [c.onSecondary, c.secondary],
        'onError': [c.onError, c.error],
        'onPrimaryContainer': [c.onPrimaryContainer, c.primaryContainer],
        'onSecondaryContainer': [c.onSecondaryContainer, c.secondaryContainer],
      };
      pairs.forEach((name, pair) {
        expect(
          _contrast(pair[0], pair[1]),
          greaterThanOrEqualTo(4.5),
          reason: '${s.key} $name',
        );
      });
      // Secondary text is allowed the large-text threshold, not body 4.5.
      expect(
        _contrast(c.onSurfaceVariant, c.surface),
        greaterThanOrEqualTo(4.5),
        reason: '${s.key} onSurfaceVariant',
      );
    }
  });

  test('every scheme authors exactly eight distinct, labellable ramp colours', () {
    for (final s in LockoutScheme.all) {
      final ramp = s.semantics.categoryRamp;
      expect(ramp.length, 8, reason: s.key);
      expect(ramp.map((c) => c.toARGB32()).toSet().length, 8, reason: s.key);
      for (final colour in ramp) {
        expect(
          _contrast(colour, s.colors.surface),
          greaterThanOrEqualTo(3.0),
          reason: '${s.key} ${colour.toARGB32().toRadixString(16)}',
        );
      }
    }
  });

  test('categoryAt wraps instead of throwing', () {
    final semantics = LockoutScheme.graphite.semantics;
    expect(semantics.categoryAt(8), semantics.categoryAt(0));
    expect(semantics.categoryAt(11), semantics.categoryAt(3));
  });

  test('byKey resolves new keys, legacy Jinatra keys, and junk', () {
    expect(LockoutScheme.byKey('graphite').key, 'graphite');
    expect(LockoutScheme.byKey('carbon_lime').key, 'graphite');
    expect(LockoutScheme.byKey('midnight_cyan').key, 'indigo');
    expect(LockoutScheme.byKey('ash_amber').key, 'ember');
    expect(LockoutScheme.byKey('void_magenta').key, 'graphite');
    expect(LockoutScheme.byKey('jinatra_cream').key, 'paper');
    expect(LockoutScheme.byKey('paper_press').key, 'paper');
    expect(LockoutScheme.byKey('mint_lab').key, 'frost');
    expect(LockoutScheme.byKey('sunblock').key, 'linen');
    expect(LockoutScheme.byKey('nonsense').key, LockoutScheme.fallback.key);
  });

  test('lerp moves every semantic field', () {
    final a = LockoutScheme.graphite.semantics;
    final b = LockoutScheme.paper.semantics;
    final mid = a.lerp(b, 0.5);
    expect(mid.success, isNot(a.success));
    expect(mid.categoryRamp.length, 8);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/schemes_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/theme/schemes.dart'`.

- [ ] **Step 3: Write `lib/theme/lockout_semantics.dart`**

```dart
import 'package:flutter/material.dart';

/// The colours Material 3 has no role for.
///
/// A `ThemeExtension` rather than a static list, because these must follow
/// a theme switch and a dynamic (Material You) scheme exactly the way the
/// framework roles do. Reading them through `context` is what makes that
/// automatic instead of something every call site has to remember.
@immutable
class LockoutSemantics extends ThemeExtension<LockoutSemantics> {
  /// A completed set, a hit target, a finished session.
  final Color success;

  /// The leg-safety notice and anything else advisory.
  final Color warning;

  /// Destructive confirmation only. Distinct from `ColorScheme.error`, which
  /// the framework also paints on invalid form fields.
  final Color danger;

  /// A scheduled rest day, which is neither success nor absence.
  final Color restDay;

  /// The weight/progress chart stroke and its area fill.
  final Color chartLine;
  final Color chartFill;

  /// Eight authored colours for telling many categories apart at a glance:
  /// training-day rails, the home action grid, category chips.
  ///
  /// Authored per scheme rather than derived. Rotating one hue through HSL
  /// collided two same-category days onto a single colour and produced muddy
  /// mid-tones; that finding predates this redesign and still holds.
  final List<Color> categoryRamp;

  const LockoutSemantics({
    required this.success,
    required this.warning,
    required this.danger,
    required this.restDay,
    required this.chartLine,
    required this.chartFill,
    required this.categoryRamp,
  });

  /// The ramp colour at [index], wrapping, so a caller with more than eight
  /// categories degrades to reuse instead of throwing.
  Color categoryAt(int index) => categoryRamp[index % categoryRamp.length];

  /// Resolves the extension for [context].
  ///
  /// Throws rather than returning null: every `ThemeData` this app builds
  /// registers the extension, so a null here means a widget is sitting under
  /// a bare `MaterialApp` in a test, and a silent fallback would hide that.
  static LockoutSemantics of(BuildContext context) {
    final extension = Theme.of(context).extension<LockoutSemantics>();
    assert(
      extension != null,
      'No LockoutSemantics in the theme. Build the ThemeData with '
      'LockoutTheme.build(), or wrap the widget under test in one.',
    );
    return extension!;
  }

  @override
  LockoutSemantics copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? restDay,
    Color? chartLine,
    Color? chartFill,
    List<Color>? categoryRamp,
  }) {
    return LockoutSemantics(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      restDay: restDay ?? this.restDay,
      chartLine: chartLine ?? this.chartLine,
      chartFill: chartFill ?? this.chartFill,
      categoryRamp: categoryRamp ?? this.categoryRamp,
    );
  }

  @override
  LockoutSemantics lerp(covariant LockoutSemantics? other, double t) {
    if (other == null) return this;
    return LockoutSemantics(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      restDay: Color.lerp(restDay, other.restDay, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
      chartFill: Color.lerp(chartFill, other.chartFill, t)!,
      categoryRamp: [
        for (var i = 0; i < categoryRamp.length; i++)
          Color.lerp(categoryRamp[i], other.categoryRamp[i], t)!,
      ],
    );
  }
}
```

- [ ] **Step 4: Write `lib/theme/schemes.dart`**

Each scheme states every role it uses. `ColorScheme.fromSeed` is deliberately not used at runtime — it re-derives every role the caller did not name, which is how the previous palette system ended up with colliding accents.

```dart
import 'package:flutter/material.dart';

import 'lockout_semantics.dart';

/// One selectable appearance: a complete Material colour scheme plus the
/// semantic colours the framework has no role for.
@immutable
class LockoutScheme {
  /// Persisted in the `theme_key` setting.
  final String key;

  /// Shown in the picker.
  final String name;

  final Brightness brightness;
  final ColorScheme colors;
  final LockoutSemantics semantics;

  const LockoutScheme({
    required this.key,
    required this.name,
    required this.brightness,
    required this.colors,
    required this.semantics,
  });

  /// The key the picker uses for "follow my phone's colours". Not a
  /// `LockoutScheme`, because its colours come from the platform at runtime.
  static const String dynamicKey = 'dynamic';

  // --- DARK ---

  static const graphite = LockoutScheme(
    key: 'graphite',
    name: 'Graphite',
    brightness: Brightness.dark,
    colors: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFA3E86D),
      onPrimary: Color(0xFF101419),
      primaryContainer: Color(0xFF2B4A1B),
      onPrimaryContainer: Color(0xFFC9F5A4),
      secondary: Color(0xFF75D9FF),
      onSecondary: Color(0xFF101419),
      secondaryContainer: Color(0xFF12394B),
      onSecondaryContainer: Color(0xFFB6EBFF),
      tertiary: Color(0xFFFFC857),
      onTertiary: Color(0xFF241A00),
      tertiaryContainer: Color(0xFF4A3708),
      onTertiaryContainer: Color(0xFFFFE0A3),
      error: Color(0xFFFF7777),
      onError: Color(0xFF2B0505),
      errorContainer: Color(0xFF5C1A1A),
      onErrorContainer: Color(0xFFFFCFCF),
      surface: Color(0xFF080A0D),
      onSurface: Color(0xFFF5F7FA),
      onSurfaceVariant: Color(0xFF9BA5B1),
      surfaceContainerLowest: Color(0xFF05070A),
      surfaceContainerLow: Color(0xFF101419),
      surfaceContainer: Color(0xFF151A20),
      surfaceContainerHigh: Color(0xFF1B2128),
      surfaceContainerHighest: Color(0xFF222931),
      inverseSurface: Color(0xFFF5F7FA),
      onInverseSurface: Color(0xFF101419),
      outline: Color(0xFF272E36),
      outlineVariant: Color(0xFF222931),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    semantics: LockoutSemantics(
      success: Color(0xFFA3E86D),
      warning: Color(0xFFFFC857),
      danger: Color(0xFFFF7777),
      restDay: Color(0xFF9BA5B1),
      chartLine: Color(0xFFA3E86D),
      chartFill: Color(0x1FA3E86D),
      categoryRamp: [
        Color(0xFFA3E86D),
        Color(0xFF75D9FF),
        Color(0xFFFFC857),
        Color(0xFFFF9E7A),
        Color(0xFFB3A8FF),
        Color(0xFF6FE0C0),
        Color(0xFFFF9EC4),
        Color(0xFFD8DE7A),
      ],
    ),
  );
```

Author `ember` (warm neutral ground `0xFF12100E`, amber primary `0xFFF0A868`), `indigo` (cool ground `0xFF0A0C14`, periwinkle primary `0xFFA8C0FF`), and the three light schemes `paper` (`0xFFFAFAF7` ground, deep-olive primary `0xFF3F6212` with white `onPrimary`), `linen` (warm `0xFFFBF7F0` ground, burnt-amber primary `0xFF8A5A12`), `frost` (cool `0xFFF6F8FB` ground, teal primary `0xFF0F5F6B`) to the same role table. The test in Step 1 is the acceptance check: every `on*` role must clear 4.5:1 against its pair, every ramp must clear 3.0:1 against `surface`, and every ramp must hold 8 distinct colours. Tune the literal until it passes — do not relax the test.

Then the collections and the lookup:

```dart
  static const List<LockoutScheme> dark = [graphite, ember, indigo];
  static const List<LockoutScheme> light = [paper, linen, frost];
  static const List<LockoutScheme> all = [...dark, ...light];

  static const LockoutScheme fallback = graphite;

  /// Keys written by the previous Jinatra palette system, mapped onto the
  /// closest new scheme. Kept so an existing install does not lose its
  /// choice on upgrade and does not error on a key that no longer exists.
  static const Map<String, String> _legacyKeys = {
    'carbon_lime': 'graphite',
    'midnight_cyan': 'indigo',
    'ash_amber': 'ember',
    'void_magenta': 'graphite',
    'jinatra_cream': 'paper',
    'paper_press': 'paper',
    'mint_lab': 'frost',
    'sunblock': 'linen',
  };

  static LockoutScheme byKey(String key) {
    final resolved = _legacyKeys[key] ?? key;
    for (final scheme in all) {
      if (scheme.key == resolved) return scheme;
    }
    return fallback;
  }
}
```

- [ ] **Step 5: Run the test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/schemes_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/lockout_semantics.dart lib/theme/schemes.dart test/schemes_test.dart
git commit -m "feat(theme): six authored Material 3 colour schemes and a semantics extension

Every role is stated rather than derived from a seed. fromSeed silently
re-derives whatever the caller does not name, which is exactly how the old
palette system produced colliding accents. Contrast is a test, not a claim."
```

---

### Task 3: ThemeData builder

**Files:**
- Create: `lib/theme/lockout_theme.dart`
- Test: `test/lockout_theme_test.dart`

**Interfaces:**
- Consumes: `LockoutScheme`, `LockoutSemantics` (Task 2).
- Produces:
  - `LockoutTheme.build({required ColorScheme colors, required LockoutSemantics semantics}) -> ThemeData`
  - `LockoutTheme.textThemeFor(ColorScheme colors) -> TextTheme`
  - Constants: `radiusButton` 14, `radiusCard` 18, `radiusDialog` 24, `radiusSheet` 28, `radiusField` 14, `radiusPill` 999, `spaceXs` 4, `spaceSm` 8, `spaceMd` 16, `spaceLg` 24, `spaceXl` 32, `screenPadding` 20, `cardPadding` 16, `sectionGap` 24, `navBarHeight` 80, `minTouchTarget` 48.

- [ ] **Step 1: Write the failing test**

```dart
// test/lockout_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';

ThemeData _themeFor(LockoutScheme scheme) =>
    LockoutTheme.build(colors: scheme.colors, semantics: scheme.semantics);

void main() {
  test('build registers the semantics extension', () {
    final theme = _themeFor(LockoutScheme.graphite);
    expect(theme.extension<LockoutSemantics>(), isNotNull);
    expect(
      theme.extension<LockoutSemantics>()!.categoryRamp.length,
      8,
    );
  });

  test('build uses Material 3 and carries the scheme through', () {
    final theme = _themeFor(LockoutScheme.graphite);
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, LockoutScheme.graphite.colors.primary);
    expect(theme.scaffoldBackgroundColor, LockoutScheme.graphite.colors.surface);
    expect(theme.brightness, Brightness.dark);
  });

  test('shape scale is applied to the component themes', () {
    final theme = _themeFor(LockoutScheme.graphite);

    double radiusOf(ShapeBorder? shape) {
      final rounded = shape as RoundedRectangleBorder;
      return (rounded.borderRadius as BorderRadius).topLeft.x;
    }

    expect(radiusOf(theme.cardTheme.shape), LockoutTheme.radiusCard);
    expect(radiusOf(theme.dialogTheme.shape), LockoutTheme.radiusDialog);
    expect(
      (theme.bottomSheetTheme.shape as RoundedRectangleBorder)
          .borderRadius
          .resolve(TextDirection.ltr)
          .topLeft
          .x,
      LockoutTheme.radiusSheet,
    );
    expect(
      radiusOf(theme.filledButtonTheme.style!.shape!.resolve({})),
      LockoutTheme.radiusButton,
    );
  });

  test('every text style resolves to a bundled family', () {
    final theme = _themeFor(LockoutScheme.graphite);
    final text = theme.textTheme;
    for (final style in <TextStyle?>[
      text.displaySmall,
      text.headlineMedium,
      text.titleMedium,
      text.bodyMedium,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ]) {
      expect(style, isNotNull);
      expect(
        style!.fontFamily,
        anyOf('Inter', 'JetBrainsMono'),
        reason: 'unbundled family ${style.fontFamily}',
      );
    }
    expect(text.headlineMedium!.fontSize, 28);
    expect(text.titleMedium!.fontSize, 18);
    expect(text.bodyMedium!.fontSize, 14);
    expect(text.labelSmall!.fontSize, 11);
  });

  test('navigation bar is 80dp with a pill indicator', () {
    final theme = _themeFor(LockoutScheme.graphite);
    expect(theme.navigationBarTheme.height, LockoutTheme.navBarHeight);
    expect(theme.navigationBarTheme.indicatorShape, isA<StadiumBorder>());
  });

  test('no theme paints a hard border or a zero-blur shadow', () {
    for (final scheme in LockoutScheme.all) {
      final theme = _themeFor(scheme);
      expect(theme.cardTheme.elevation, lessThanOrEqualTo(3.0), reason: scheme.key);
      final side = (theme.cardTheme.shape as RoundedRectangleBorder).side;
      expect(side.width, lessThanOrEqualTo(1.0), reason: scheme.key);
    }
  });

  test('builds for every scheme without throwing', () {
    for (final scheme in LockoutScheme.all) {
      expect(() => _themeFor(scheme), returnsNormally, reason: scheme.key);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/lockout_theme_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/theme/lockout_theme.dart'`.

- [ ] **Step 3: Write `lib/theme/lockout_theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'lockout_semantics.dart';

/// Builds the app's `ThemeData` from a colour scheme.
///
/// There is no static colour accessor here on purpose. The previous token
/// class exposed colours without a `BuildContext`, which made a dynamic
/// (Material You) scheme impossible to deliver correctly — the platform
/// scheme only exists below the widget that resolves it.
class LockoutTheme {
  LockoutTheme._();

  // Shape scale.
  static const double radiusButton = 14;
  static const double radiusCard = 18;
  static const double radiusDialog = 24;
  static const double radiusSheet = 28;
  static const double radiusField = 14;
  static const double radiusPill = 999;

  // 8dp spacing grid.
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const double screenPadding = 20;
  static const double cardPadding = 16;
  static const double sectionGap = 24;

  static const double navBarHeight = 80;
  static const double minTouchTarget = 48;

  static const String fontSans = 'Inter';
  static const String fontMono = 'JetBrainsMono';

  static TextTheme textThemeFor(ColorScheme colors) {
    TextStyle sans(double size, FontWeight weight, {Color? color, double? height}) =>
        TextStyle(
          fontFamily: fontSans,
          fontSize: size,
          fontWeight: weight,
          color: color ?? colors.onSurface,
          height: height,
        );

    return TextTheme(
      displayLarge: sans(45, FontWeight.w700, height: 1.05),
      displayMedium: sans(40, FontWeight.w700, height: 1.05),
      displaySmall: sans(36, FontWeight.w700, height: 1.08),
      headlineLarge: sans(32, FontWeight.w700, height: 1.15),
      headlineMedium: sans(28, FontWeight.w700, height: 1.15),
      headlineSmall: sans(24, FontWeight.w600, height: 1.2),
      titleLarge: sans(22, FontWeight.w600, height: 1.25),
      titleMedium: sans(18, FontWeight.w600, height: 1.3),
      titleSmall: sans(16, FontWeight.w600, height: 1.3),
      bodyLarge: sans(16, FontWeight.w400, height: 1.45),
      bodyMedium: sans(14, FontWeight.w400, height: 1.45),
      bodySmall: sans(13, FontWeight.w400, color: colors.onSurfaceVariant, height: 1.4),
      labelLarge: sans(14, FontWeight.w600, height: 1.2),
      labelMedium: sans(12, FontWeight.w500, color: colors.onSurfaceVariant, height: 1.2),
      labelSmall: sans(11, FontWeight.w500, color: colors.onSurfaceVariant, height: 1.2),
    );
  }

  /// Numeric style for anything that must align in a column — set/rep/weight
  /// tables, the rest timer, log rows. Mono, so digits do not shift width
  /// between 1 and 8.
  static TextStyle numeric(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontMono,
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      letterSpacing: 0.2,
    );
  }

  static ThemeData build({
    required ColorScheme colors,
    required LockoutSemantics semantics,
  }) {
    final text = textThemeFor(colors);

    RoundedRectangleBorder rounded(double radius, {BorderSide? side}) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: side ?? BorderSide.none,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[semantics],
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      cardTheme: CardThemeData(
        color: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: rounded(
          radiusCard,
          side: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: rounded(radiusDialog),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surfaceContainerLow,
        elevation: 6,
        showDragHandle: true,
        dragHandleColor: colors.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: spaceLg),
          textStyle: text.labelLarge,
          shape: rounded(radiusButton),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: spaceLg),
          textStyle: text.labelLarge,
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.outline),
          shape: rounded(radiusButton),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, minTouchTarget),
          textStyle: text.labelLarge,
          shape: rounded(radiusButton),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceMd,
        ),
        labelStyle: text.labelMedium,
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: colors.error),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: navBarHeight,
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            color: selected ? colors.primary : colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          );
        }),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colors.secondaryContainer,
          selectedForegroundColor: colors.onSecondaryContainer,
          foregroundColor: colors.onSurfaceVariant,
          side: BorderSide(color: colors.outlineVariant),
          textStyle: text.labelLarge,
          minimumSize: const Size(0, minTouchTarget),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        selectedColor: colors.secondaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        labelStyle: text.labelMedium!,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: spaceSm, vertical: spaceXs),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        linearMinHeight: 8,
        circularTrackColor: colors.surfaceContainerHighest,
      ),

      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: spaceLg,
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        iconColor: colors.onSurfaceVariant,
        shape: rounded(radiusButton),
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceMd),
        minTileHeight: minTouchTarget,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: colors.onInverseSurface),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: rounded(radiusButton),
        insetPadding: const EdgeInsets.all(spaceMd),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 4,
        shape: rounded(radiusDialog),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: rounded(radiusButton),
        textStyle: text.bodyMedium,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colors.onPrimary : colors.outline),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.primary
                : colors.surfaceContainerHighest),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
```

**Correction applied during execution: do NOT set `pageTransitionsTheme` at all.** Flutter 3.47's default for Android is already `PredictiveBackPageTransitionsBuilder`, which runs the predictive-back preview only while a real back gesture is in progress and delegates every other navigation to `FadeForwardsPageTransitionsBuilder` — the Expressive motion this plan wanted. Pinning `FadeForwards` directly buys nothing and costs the back gesture. The test asserts the outcome (not Zoom, and the Expressive transition duration) rather than one specific class.

- [ ] **Step 4: Run the test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/lockout_theme_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/lockout_theme.dart test/lockout_theme_test.dart
git commit -m "feat(theme): Material 3 Expressive ThemeData builder

Shape scale, type scale, spacing grid and every component theme in one
place, so a widget never needs to restate them. No static colour accessor:
the dynamic scheme only exists below the widget that resolves it."
```

---

### Task 4: Theme controller (persistence, dynamic colour, legacy keys)

**Files:**
- Create: `lib/theme/theme_controller.dart`
- Test: `test/theme_controller_test.dart`

**Interfaces:**
- Consumes: `LockoutScheme`, `LockoutTheme` (Tasks 2–3), `DatabaseService.getSetting` / `saveSetting`.
- Produces:
  - `ThemeController.instance` (singleton, `ChangeNotifier`)
  - `Future<void> load()` — reads `theme_key`, maps legacy keys, resolves availability
  - `Future<void> select(String key)` — persists and notifies
  - `void setDynamicSchemes({ColorScheme? light, ColorScheme? dark})` — called by `DynamicColorBuilder`
  - `String get selectedKey`, `bool get dynamicAvailable`
  - `ThemeData get lightTheme`, `ThemeData? get darkTheme`, `ThemeMode get themeMode`
  - `List<String> get pickerKeys` — the six scheme keys, plus `LockoutScheme.dynamicKey` only when available

- [ ] **Step 1: Write the failing test**

```dart
// test/theme_controller_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/theme/theme_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
    ThemeController.instance.resetForTest();
  });

  test('defaults to graphite when nothing is saved', () async {
    await ThemeController.instance.load();
    expect(ThemeController.instance.selectedKey, 'graphite');
    expect(ThemeController.instance.themeMode, ThemeMode.light);
    expect(ThemeController.instance.lightTheme.brightness, Brightness.dark);
    expect(ThemeController.instance.darkTheme, isNull);
  });

  test('a saved legacy Jinatra key resolves to its nearest scheme', () async {
    await DatabaseService.instance.saveSetting('theme_key', 'midnight_cyan');
    await ThemeController.instance.load();
    expect(ThemeController.instance.selectedKey, 'indigo');
  });

  test('select persists and notifies', () async {
    await ThemeController.instance.load();
    var notifications = 0;
    ThemeController.instance.addListener(() => notifications++);

    await ThemeController.instance.select('paper');

    expect(notifications, 1);
    expect(ThemeController.instance.selectedKey, 'paper');
    expect(ThemeController.instance.lightTheme.brightness, Brightness.light);
    expect(
      await DatabaseService.instance.getSetting('theme_key', defaultValue: ''),
      'paper',
    );
  });

  test('dynamic is absent from the picker until schemes arrive', () async {
    await ThemeController.instance.load();
    expect(ThemeController.instance.dynamicAvailable, isFalse);
    expect(
      ThemeController.instance.pickerKeys.contains(LockoutScheme.dynamicKey),
      isFalse,
    );

    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );

    expect(ThemeController.instance.dynamicAvailable, isTrue);
    expect(ThemeController.instance.pickerKeys.last, LockoutScheme.dynamicKey);
  });

  test('dynamic selection follows the system brightness', () async {
    await ThemeController.instance.load();
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );
    await ThemeController.instance.select(LockoutScheme.dynamicKey);

    expect(ThemeController.instance.themeMode, ThemeMode.system);
    expect(ThemeController.instance.darkTheme, isNotNull);
    expect(ThemeController.instance.lightTheme.brightness, Brightness.light);
    expect(ThemeController.instance.darkTheme!.brightness, Brightness.dark);
  });

  test('a saved dynamic key falls back to graphite when unavailable', () async {
    await DatabaseService.instance.saveSetting('theme_key', LockoutScheme.dynamicKey);
    await ThemeController.instance.load();
    expect(ThemeController.instance.dynamicAvailable, isFalse);
    expect(ThemeController.instance.lightTheme.brightness, Brightness.dark);
    expect(ThemeController.instance.themeMode, ThemeMode.light);
  });

  test('dynamic keeps our authored warning, error and ramp', () async {
    await ThemeController.instance.load();
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );
    await ThemeController.instance.select(LockoutScheme.dynamicKey);

    final theme = ThemeController.instance.darkTheme!;
    expect(theme.colorScheme.error, LockoutScheme.graphite.colors.error);
    expect(theme.colorScheme.tertiary, LockoutScheme.graphite.colors.tertiary);
    expect(
      theme.extension<LockoutSemantics>()!.categoryRamp,
      LockoutScheme.graphite.semantics.categoryRamp,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/theme_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/theme/theme_controller.dart'`.

- [ ] **Step 3: Write `lib/theme/theme_controller.dart`**

```dart
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'lockout_semantics.dart';
import 'lockout_theme.dart';
import 'schemes.dart';

/// Owns which appearance is active and turns it into `ThemeData`.
///
/// A `ChangeNotifier` rather than an `InheritedWidget` of its own: the app
/// root listens once and rebuilds `MaterialApp`, which is all the framework
/// needs to repaint every `Theme.of(context)` reader beneath it.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _settingKey = 'theme_key';

  String _selectedKey = LockoutScheme.fallback.key;
  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;

  String get selectedKey => _selectedKey;

  /// True once the platform has handed us a wallpaper-derived scheme.
  /// False on Android 11 and below, and on every non-Android target.
  bool get dynamicAvailable => _dynamicLight != null && _dynamicDark != null;

  /// The keys the picker should offer, in order. Dynamic is appended only
  /// when the platform actually supplied schemes — an option that silently
  /// falls back is worse than an option that is not there.
  List<String> get pickerKeys => [
        for (final scheme in LockoutScheme.all) scheme.key,
        if (dynamicAvailable) LockoutScheme.dynamicKey,
      ];

  bool get _usingDynamic =>
      _selectedKey == LockoutScheme.dynamicKey && dynamicAvailable;

  /// The authored scheme in force. For a dynamic selection this is still
  /// graphite, because dynamic borrows its semantic colours from it.
  LockoutScheme get _base => _selectedKey == LockoutScheme.dynamicKey
      ? LockoutScheme.fallback
      : LockoutScheme.byKey(_selectedKey);

  ThemeData get lightTheme {
    if (_usingDynamic) {
      return LockoutTheme.build(
        colors: _harmonised(_dynamicLight!),
        semantics: LockoutScheme.fallback.semantics,
      );
    }
    final scheme = _base;
    return LockoutTheme.build(colors: scheme.colors, semantics: scheme.semantics);
  }

  /// Null unless a dynamic scheme is in force. An authored scheme already
  /// carries its own brightness, so offering a second one would let the
  /// system override an explicit choice.
  ThemeData? get darkTheme {
    if (!_usingDynamic) return null;
    return LockoutTheme.build(
      colors: _harmonised(_dynamicDark!),
      semantics: LockoutScheme.fallback.semantics,
    );
  }

  ThemeMode get themeMode => _usingDynamic ? ThemeMode.system : ThemeMode.light;

  /// Wallpaper colours decide hue, we decide meaning.
  ///
  /// A wallpaper can easily produce a green-ish `error` or an `error`-ish
  /// `tertiary`, at which point a destructive confirmation and a completed
  /// set are the same colour. Overwriting those two roles (and leaving the
  /// [LockoutSemantics] ramp authored) keeps the one thing that must never
  /// be ambiguous unambiguous.
  ColorScheme _harmonised(ColorScheme platform) {
    final authored = LockoutScheme.fallback.colors;
    return platform.copyWith(
      error: authored.error,
      onError: authored.onError,
      errorContainer: authored.errorContainer,
      onErrorContainer: authored.onErrorContainer,
      tertiary: authored.tertiary,
      onTertiary: authored.onTertiary,
      tertiaryContainer: authored.tertiaryContainer,
      onTertiaryContainer: authored.onTertiaryContainer,
    );
  }

  Future<void> load() async {
    final saved = await DatabaseService.instance
        .getSetting(_settingKey, defaultValue: LockoutScheme.fallback.key);
    _selectedKey = saved == LockoutScheme.dynamicKey
        ? LockoutScheme.dynamicKey
        : LockoutScheme.byKey(saved).key;
    notifyListeners();
  }

  Future<void> select(String key) async {
    final resolved = key == LockoutScheme.dynamicKey
        ? LockoutScheme.dynamicKey
        : LockoutScheme.byKey(key).key;
    if (resolved == _selectedKey) return;
    _selectedKey = resolved;
    await DatabaseService.instance.saveSetting(_settingKey, resolved);
    notifyListeners();
  }

  /// Called by `DynamicColorBuilder` at the app root on every platform
  /// palette change. A no-op when nothing actually changed, so it cannot
  /// loop through `notifyListeners` on every frame.
  void setDynamicSchemes({ColorScheme? light, ColorScheme? dark}) {
    if (light == _dynamicLight && dark == _dynamicDark) return;
    _dynamicLight = light;
    _dynamicDark = dark;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _selectedKey = LockoutScheme.fallback.key;
    _dynamicLight = null;
    _dynamicDark = null;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/theme_controller_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/theme_controller.dart test/theme_controller_test.dart
git commit -m "feat(theme): persisted theme selection with Material You support

Dynamic colour is offered only when the platform actually supplies it; a
saved dynamic key on a device that cannot provide one resolves to graphite
rather than silently rendering a default scheme. Error and tertiary stay
authored under dynamic so a wallpaper can never make 'destructive' and
'complete' the same colour."
```

---

### Task 5: Progress tab host (Body + Log)

**Files:**
- Create: `lib/screens/progress_tab.dart`
- Test: `test/progress_tab_test.dart`

**Interfaces:**
- Consumes: `BodyTab`/`BodyTabState`, `LogTab`/`LogTabState` (unchanged).
- Produces:
  - `enum ProgressSegment { weight, history }`
  - `class ProgressTab extends StatefulWidget` with `ProgressTab({Key? key, ProgressSegment initialSegment = ProgressSegment.weight})`
  - `class ProgressTabState extends State<ProgressTab>` with `Future<void> reload()` and `void showSegment(ProgressSegment segment)`

This task only *hosts* the two existing screens. Their internals are restyled in Task 12.

- [ ] **Step 1: Write the failing test**

```dart
// test/progress_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/screens/body_tab.dart';
import 'package:lockout/screens/log_tab.dart';
import 'package:lockout/screens/progress_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

Widget _host(GlobalKey<ProgressTabState> key) => MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: ProgressTab(key: key),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() => wipeDatabaseAndReseed(DatabaseService.instance));

  testWidgets('opens on Weight and shows both segments', (tester) async {
    final key = GlobalKey<ProgressTabState>();
    await tester.pumpWidget(_host(key));
    await settle(tester);

    expect(find.byType(SegmentedButton<ProgressSegment>), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byType(BodyTab), findsOneWidget);
    expect(find.byType(LogTab), findsNothing);
  });

  testWidgets('tapping History swaps the body', (tester) async {
    final key = GlobalKey<ProgressTabState>();
    await tester.pumpWidget(_host(key));
    await settle(tester);

    await tester.tap(find.text('History'));
    await settle(tester);

    expect(find.byType(LogTab), findsOneWidget);
    expect(find.byType(BodyTab), findsNothing);
  });

  testWidgets('showSegment drives the control from outside', (tester) async {
    final key = GlobalKey<ProgressTabState>();
    await tester.pumpWidget(_host(key));
    await settle(tester);

    key.currentState!.showSegment(ProgressSegment.history);
    await settle(tester);
    expect(find.byType(LogTab), findsOneWidget);

    key.currentState!.showSegment(ProgressSegment.weight);
    await settle(tester);
    expect(find.byType(BodyTab), findsOneWidget);
  });

  testWidgets('initialSegment opens straight on History', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: ProgressTab(initialSegment: ProgressSegment.history),
    ));
    await settle(tester);
    expect(find.byType(LogTab), findsOneWidget);
  });

  testWidgets('reload does not throw on either segment', (tester) async {
    final key = GlobalKey<ProgressTabState>();
    await tester.pumpWidget(_host(key));
    await settle(tester);

    await key.currentState!.reload();
    await settle(tester);

    key.currentState!.showSegment(ProgressSegment.history);
    await settle(tester);
    await key.currentState!.reload();
    await settle(tester);

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/progress_tab_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/screens/progress_tab.dart'`.

- [ ] **Step 3: Write `lib/screens/progress_tab.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'body_tab.dart';
import 'log_tab.dart';

/// Which half of Progress is on screen.
enum ProgressSegment { weight, history }

/// Hosts the two progress views behind one segmented control.
///
/// The segments are built lazily and only the visible one is mounted: both
/// children load from sqflite in `initState`, so keeping the hidden one
/// alive would double every read on a tab the user may never open. The cost
/// is that switching re-reads — which is correct here, since the other
/// segment's data may have changed while it was hidden.
class ProgressTab extends StatefulWidget {
  final ProgressSegment initialSegment;

  // NOT const — this screen's children read colour from the theme, and a
  // canonicalised instance is skipped on rebuild, stranding them in the
  // previous theme after a switch.
  // ignore: prefer_const_constructors_in_immutables
  ProgressTab({super.key, this.initialSegment = ProgressSegment.weight});

  @override
  State<ProgressTab> createState() => ProgressTabState();
}

class ProgressTabState extends State<ProgressTab> {
  late ProgressSegment _segment = widget.initialSegment;

  final _bodyKey = GlobalKey<BodyTabState>();
  final _logKey = GlobalKey<LogTabState>();

  /// Refreshes whichever segment is visible. The hidden one is not mounted,
  /// so there is nothing to refresh there — it reads fresh on the way in.
  Future<void> reload() async {
    switch (_segment) {
      case ProgressSegment.weight:
        await _bodyKey.currentState?.reload();
      case ProgressSegment.history:
        await _logKey.currentState?.reload();
    }
  }

  void showSegment(ProgressSegment segment) {
    if (!mounted || segment == _segment) return;
    setState(() => _segment = segment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LockoutTheme.screenPadding,
                LockoutTheme.spaceMd,
                LockoutTheme.screenPadding,
                LockoutTheme.spaceSm,
              ),
              child: Text(
                'Progress',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LockoutTheme.screenPadding,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ProgressSegment>(
                  segments: const [
                    ButtonSegment(
                      value: ProgressSegment.weight,
                      label: Text('Weight'),
                      icon: Icon(Icons.monitor_weight_outlined),
                    ),
                    ButtonSegment(
                      value: ProgressSegment.history,
                      label: Text('History'),
                      icon: Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                  selected: {_segment},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      showSegment(selection.first),
                ),
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),
            Expanded(
              child: switch (_segment) {
                ProgressSegment.weight => BodyTab(key: _bodyKey),
                ProgressSegment.history => LogTab(key: _logKey),
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/progress_tab_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/progress_tab.dart test/progress_tab_test.dart
git commit -m "feat(progress): host Body and Log behind one segmented control

Only the visible segment is mounted. Both children read sqflite in
initState, so keeping the hidden one alive would double every read on a
view the user may never open."
```

---

### Task 6: Profile tab host (Settings as a tab)

**Files:**
- Modify: `lib/screens/settings_screen.dart` — extract the body into a reusable widget
- Create: `lib/screens/profile_tab.dart`
- Test: `test/profile_tab_test.dart`

**Interfaces:**
- Consumes: the existing settings state and `onSettingsUpdated` contract.
- Produces:
  - `class SettingsBody extends StatefulWidget` — `SettingsBody({Key? key, required VoidCallback onSettingsUpdated, required bool showAppBar})` — the current `SettingsScreen` content with its `Scaffold`/`AppBar` made optional.
  - `class SettingsBodyState extends State<SettingsBody>` with `Future<void> reload()`.
  - `class ProfileTab extends StatefulWidget` — `ProfileTab({Key? key, required VoidCallback onSettingsUpdated})`
  - `class ProfileTabState extends State<ProfileTab>` with `Future<void> reload()`.
  - `SettingsScreen` is kept as a thin pushed-route wrapper around `SettingsBody(showAppBar: true)` so any existing deep link still works.

- [ ] **Step 1: Write the failing test**

```dart
// test/profile_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/screens/profile_tab.dart';
import 'package:lockout/screens/settings_screen.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() => wipeDatabaseAndReseed(DatabaseService.instance));

  testWidgets('renders the settings body with no back button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: ProfileTab(onSettingsUpdated: () {}),
    ));
    await settle(tester);

    expect(find.byType(SettingsBody), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('the pushed SettingsScreen still has a back button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(onSettingsUpdated: () {}),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.byType(SettingsBody), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('reload does not throw', (tester) async {
    final key = GlobalKey<ProfileTabState>();
    await tester.pumpWidget(MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: ProfileTab(key: key, onSettingsUpdated: () {}),
    ));
    await settle(tester);

    await key.currentState!.reload();
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/profile_tab_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/screens/profile_tab.dart'`.

- [ ] **Step 3: Extract `SettingsBody` from `SettingsScreen`**

In `lib/screens/settings_screen.dart`, rename the existing `SettingsScreen`/`_SettingsScreenState` pair to `SettingsBody`/`SettingsBodyState`, add a `final bool showAppBar;` field, expose the existing private reload as a public `Future<void> reload()`, and make the `Scaffold`'s `appBar:` conditional:

```dart
class SettingsBody extends StatefulWidget {
  final VoidCallback onSettingsUpdated;

  /// False when hosted as the Profile tab, where `MainScreen` owns the
  /// chrome and there is no route to pop back to.
  final bool showAppBar;

  // ignore: prefer_const_constructors_in_immutables
  SettingsBody({
    super.key,
    required this.onSettingsUpdated,
    this.showAppBar = true,
  });

  @override
  State<SettingsBody> createState() => SettingsBodyState();
}
```

and in its `build`:

```dart
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Settings'))
          : null,
      body: /* the existing body, unchanged in this task */,
    );
```

Then add the thin wrapper back, so the pushed route keeps working:

```dart
/// The pushed-route form of settings. Kept so anything that still navigates
/// to a settings page (a notification tap, a deep link) lands somewhere with
/// a back button, even though the primary entry point is now the Profile tab.
class SettingsScreen extends StatelessWidget {
  final VoidCallback onSettingsUpdated;

  // ignore: prefer_const_constructors_in_immutables
  SettingsScreen({super.key, required this.onSettingsUpdated});

  @override
  Widget build(BuildContext context) =>
      SettingsBody(onSettingsUpdated: onSettingsUpdated, showAppBar: true);
}
```

- [ ] **Step 4: Write `lib/screens/profile_tab.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'settings_screen.dart';

/// Settings hosted as a first-class tab.
///
/// Its own header rather than an `AppBar`, so it matches the other tabs:
/// `MainScreen` no longer carries a global app bar, and a tab that grew one
/// back would sit a bar taller than its neighbours.
class ProfileTab extends StatefulWidget {
  final VoidCallback onSettingsUpdated;

  // ignore: prefer_const_constructors_in_immutables
  ProfileTab({super.key, required this.onSettingsUpdated});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  final _bodyKey = GlobalKey<SettingsBodyState>();

  Future<void> reload() async => _bodyKey.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LockoutTheme.screenPadding,
                LockoutTheme.spaceMd,
                LockoutTheme.screenPadding,
                LockoutTheme.spaceSm,
              ),
              child: Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Expanded(
              child: SettingsBody(
                key: _bodyKey,
                onSettingsUpdated: widget.onSettingsUpdated,
                showAppBar: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/profile_tab_test.dart test/settings_restyle_test.dart`
Expected: the 3 new tests PASS. `settings_restyle_test.dart` may fail on the renamed class — update its references to `SettingsBody` in this task, since that is the same change.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart lib/screens/profile_tab.dart test/profile_tab_test.dart test/settings_restyle_test.dart
git commit -m "refactor(settings): split SettingsBody from its route so it can host a tab

SettingsScreen stays as a thin pushed-route wrapper, so anything that still
navigates to a settings page lands somewhere with a back button."
```

---

### Task 7: Navigation restructure

**Files:**
- Rewrite: `lib/widgets/bottom_nav.dart`
- Modify: `lib/screens/main_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/screens/today_tab.dart` — the `onNavigate` id strings only
- Test: `test/main_screen_test.dart` (update), `test/bottom_nav_test.dart` (create)

**Interfaces:**
- Consumes: `ProgressTab`/`ProgressSegment` (Task 5), `ProfileTab` (Task 6), `ThemeController` (Task 4).
- Produces:
  - `enum NavTab { home, workout, progress, food, profile }`
  - Ids: `'home'`, `'workout'`, `'progress'`, `'food'`, `'profile'`
  - `NavTabDef` gains `final IconData selectedIcon;`
  - `BottomNav.visibleTabs({bool foodTabEnabled = true})` — unchanged signature
  - `BottomNav.lastRenderedHeight` — unchanged, `undo_banner` still depends on it
  - `MainScreen._goToTab(String tabId, {ProgressSegment? segment})`

Legacy id remapping for `TodayTab.onNavigate` call sites: `'routines'` becomes `'workout'`; `'body'` becomes `'progress'` with `segment: ProgressSegment.weight`; `'log'` becomes `'progress'` with `segment: ProgressSegment.history`.

- [ ] **Step 1: Write the failing test**

```dart
// test/bottom_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/bottom_nav.dart';

Widget _host({bool foodTabEnabled = true, int index = 0}) => MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: Scaffold(
        bottomNavigationBar: BottomNav(
          currentIndex: index,
          foodTabEnabled: foodTabEnabled,
          onTap: (_) {},
        ),
      ),
    );

void main() {
  test('five tabs in the designed order', () {
    final tabs = BottomNav.visibleTabs();
    expect(tabs.map((t) => t.id).toList(),
        ['home', 'workout', 'progress', 'food', 'profile']);
    expect(tabs.map((t) => t.tab).toList(), NavTab.values);
  });

  test('hiding food leaves four tabs and keeps the order', () {
    final tabs = BottomNav.visibleTabs(foodTabEnabled: false);
    expect(tabs.map((t) => t.id).toList(),
        ['home', 'workout', 'progress', 'profile']);
  });

  test('every tab has a distinct selected and unselected icon', () {
    for (final tab in BottomNav.visibleTabs()) {
      expect(tab.icon, isNot(tab.selectedIcon), reason: tab.id);
    }
  });

  testWidgets('renders a Material NavigationBar, not a custom row',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('bar is at least 80dp and reports its height', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump();

    final size = tester.getSize(find.byType(NavigationBar));
    expect(size.height, greaterThanOrEqualTo(LockoutTheme.navBarHeight));
    expect(BottomNav.lastRenderedHeight.value, greaterThanOrEqualTo(80.0));
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: Scaffold(
        bottomNavigationBar: BottomNav(
          currentIndex: 0,
          onTap: (i) => tapped = i,
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Progress'));
    await tester.pump();
    expect(tapped, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/bottom_nav_test.dart`
Expected: FAIL — `NavTab` has no member `workout`.

- [ ] **Step 3: Rewrite `lib/widgets/bottom_nav.dart`**

Keep the enum-keyed `NavTabDef` contract and the `lastRenderedHeight` notifier verbatim — `undo_banner.dart` reads the latter to clear the bar during its 5s window, and the `dispose` reset exists because that static would otherwise stay stale across a test process. Replace only the hand-rolled `Row` with a framework `NavigationBar`.

```dart
import 'package:flutter/material.dart';

/// One nav destination, enum-keyed. `MainScreen._screenFor` switches on this
/// with a Dart switch *expression*, which the compiler rejects if a case is
/// missing — so a tab added here without a matching branch there is a
/// compile error, not a runtime `StateError`.
enum NavTab { home, workout, progress, food, profile }

class NavTabDef {
  final NavTab tab;

  /// The id `TodayTab.onNavigate(String tabId)` and `MainScreen._goToTab`
  /// use — a public string contract, kept alongside [tab] rather than
  /// derived from its `.name`, so renaming an enum member can never silently
  /// change that contract.
  final String id;
  final String label;

  /// Outlined when inactive, filled when active — the M3 convention that
  /// carries selection state without relying on colour alone.
  final IconData icon;
  final IconData selectedIcon;

  const NavTabDef({
    required this.tab,
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool foodTabEnabled;

  // ignore: prefer_const_constructors_in_immutables
  BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.foodTabEnabled = true,
  });

  static const List<NavTabDef> _allTabs = [
    NavTabDef(
      tab: NavTab.home,
      id: 'home',
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    NavTabDef(
      tab: NavTab.workout,
      id: 'workout',
      label: 'Workout',
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center,
    ),
    NavTabDef(
      tab: NavTab.progress,
      id: 'progress',
      label: 'Progress',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
    ),
    NavTabDef(
      tab: NavTab.food,
      id: 'food',
      label: 'Food',
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
    ),
    NavTabDef(
      tab: NavTab.profile,
      id: 'profile',
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  static List<NavTabDef> visibleTabs({bool foodTabEnabled = true}) =>
      _allTabs.where((t) => t.id != 'food' || foodTabEnabled).toList();

  /// The most recently *measured* rendered height of a live `BottomNav`,
  /// including its own bottom safe-area inset — `0.0` until one has laid out
  /// at least once. `showUndoBanner` (`lib/widgets/undo_banner.dart`) reads
  /// this so its `Positioned(bottom: ...)` clears the bar instead of sitting
  /// on top of it for the whole 5s undo window. Measured rather than a
  /// guessed constant so it cannot fall short on an unusual font-scale or
  /// device inset, and cannot overshoot where no bar exists at all.
  static final ValueNotifier<double> lastRenderedHeight =
      ValueNotifier<double>(0.0);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  final _barKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_reportHeight);
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_reportHeight);
  }

  void _reportHeight(Duration _) {
    final height = _barKey.currentContext?.size?.height;
    if (height != null && height != BottomNav.lastRenderedHeight.value) {
      BottomNav.lastRenderedHeight.value = height;
    }
  }

  // Resets so a tab pumped standalone after a bar has come and gone in the
  // same test process sees the documented 0.0 rather than a stale inset.
  @override
  void dispose() {
    BottomNav.lastRenderedHeight.value = 0.0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = BottomNav.visibleTabs(foodTabEnabled: widget.foodTabEnabled);
    final index = widget.currentIndex.clamp(0, tabs.length - 1);

    return NavigationBar(
      key: _barKey,
      selectedIndex: index,
      onDestinationSelected: widget.onTap,
      destinations: [
        for (final tab in tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
            tooltip: tab.label,
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Rewire `lib/screens/main_screen.dart`**

Replace the `_screenFor` switch, drop the global `AppBar`, and teach `_goToTab` about the Progress segment:

```dart
  Widget _screenFor(NavTab tab) => switch (tab) {
        NavTab.home => TodayTab(
            key: _todayKey,
            onNavigate: _goToTab,
            foodTabEnabled: _foodTabEnabled,
          ),
        NavTab.workout => RoutinesTab(key: _routinesKey),
        NavTab.progress => ProgressTab(key: _progressKey),
        NavTab.food => FoodTab(key: _foodKey),
        NavTab.profile => ProfileTab(
            key: _profileKey,
            onSettingsUpdated: _loadSettings,
          ),
      };

  void _refreshVisibleTab() {
    if (_currentIndex >= _tabIds.length) return;
    switch (_tabIds[_currentIndex]) {
      case 'home':
        _todayKey.currentState?.reload();
      case 'workout':
        _routinesKey.currentState?.reload();
      case 'progress':
        _progressKey.currentState?.reload();
      case 'food':
        _foodKey.currentState?.reload();
      case 'profile':
        _profileKey.currentState?.reload();
    }
  }

  /// Switches tabs by id. Ids rather than indices, because hiding the Food
  /// tab shifts every index after it.
  ///
  /// [segment] is honoured only for `'progress'`, which is the one tab with
  /// two destinations behind a single id — Home's WEIGH IN and HISTORY
  /// actions both land here and must not open the same half.
  void _goToTab(String tabId, {ProgressSegment? segment}) {
    final index = _tabIds.indexOf(tabId);
    if (index < 0) return;
    _onTabTapped(index);
    if (tabId == 'progress' && segment != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _progressKey.currentState?.showSegment(segment),
      );
    }
  }
```

and the `build` loses its `appBar:` entirely:

```dart
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        foodTabEnabled: _foodTabEnabled,
        onTap: _onTabTapped,
      ),
    );
```

Add `_progressKey` and `_profileKey` alongside the existing keys, and delete `_bodyKey` and `_logKey` (Progress owns those now). Widen `TodayTab.onNavigate` to `void Function(String, {ProgressSegment? segment})`.

- [ ] **Step 5: Update `lib/screens/today_tab.dart` navigation ids**

In `_quickActions()` and the `HomeHub` callbacks, change every `go?.call('routines')` to `go?.call('workout')`, every `go?.call('body')` to `go?.call('progress', segment: ProgressSegment.weight)`, and every `go?.call('log')` to `go?.call('progress', segment: ProgressSegment.history)`. `onOpenBody` and `onOpenLog` on `HomeHub` route the same way.

- [ ] **Step 6: Rewire `lib/main.dart` to the new theme**

```dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'screens/main_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve the saved appearance before the first frame so the app never
  // flashes the default theme on top of the chosen one.
  await ThemeController.instance.load();
  await NotificationService.instance.init();

  runApp(const LockoutApp());
}

class LockoutApp extends StatelessWidget {
  const LockoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Publishing outside build would need a frame callback; the
        // controller no-ops when nothing changed, so this cannot loop.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ThemeController.instance
              .setDynamicSchemes(light: lightDynamic, dark: darkDynamic);
        });

        return ListenableBuilder(
          listenable: ThemeController.instance,
          // MainScreen must NOT be const: a const widget is canonicalised to
          // a single instance, so Flutter sees an identical child and skips
          // rebuilding the subtree. Its constructor is non-const so this
          // cannot be written. No key either — a changing key would remount
          // the tabs and discard an in-progress live session.
          builder: (_, _) => MaterialApp(
            title: 'LOCKOUT',
            debugShowCheckedModeBanner: false,
            theme: ThemeController.instance.lightTheme,
            darkTheme: ThemeController.instance.darkTheme,
            themeMode: ThemeController.instance.themeMode,
            home: MainScreen(),
          ),
        );
      },
    );
  }
}
```

Note: `DatabaseService` is still imported transitively through the controller; drop the now-unused direct import from `main.dart` if the analyzer flags it.

- [ ] **Step 7: Update `test/main_screen_test.dart`**

Every assertion that names `'routines'`, `'body'` or `'log'` as a tab id, or expects five specific labels, moves to the new ids and labels. Add a case proving the food-off path yields four destinations and that `'progress'` with `ProgressSegment.history` lands on the History segment.

- [ ] **Step 8: Run the full suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: all pass. `today_tab_test.dart` and `home_tab_test.dart` may need their navigation-id expectations updated in this task — that is the same change, not scope creep.

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/bottom_nav.dart lib/screens/main_screen.dart lib/screens/today_tab.dart lib/main.dart test/bottom_nav_test.dart test/main_screen_test.dart test/today_tab_test.dart test/home_tab_test.dart
git commit -m "feat(nav): five-tab Material NavigationBar with Progress and Profile

Body and Log merge into Progress; Settings becomes Profile. The global
AppBar goes so each tab can own its own large title. NavTabDef stays
enum-keyed, so a tab without a screen is still a compile error."
```

---

### Task 8: Shared widget kit

**Files:**
- Rewrite: `lib/widgets/jinatra_card.dart` to `lib/widgets/lockout_card.dart`
- Rewrite: `lib/widgets/jinatra_button.dart` to `lib/widgets/lockout_button.dart`
- Rewrite: `lib/widgets/jinatra_input.dart` to `lib/widgets/lockout_field.dart`
- Modify: `lib/widgets/sheet_scaffold.dart`
- Modify: `lib/widgets/undo_banner.dart`
- Test: `test/widget_kit_test.dart`

**Interfaces:**
- Consumes: `LockoutTheme`, `LockoutSemantics`.
- Produces:
  - `LockoutCard({Key? key, required Widget child, EdgeInsets? padding, Color? color, VoidCallback? onTap, bool elevated = false})`
  - `LockoutButton` is **not** created — call sites use framework `FilledButton` / `FilledButton.tonal` / `OutlinedButton` / `TextButton` directly, since Task 3 already themed them. The old file is deleted.
  - `LockoutField({Key? key, required TextEditingController controller, required String label, String? hint, TextInputType? keyboardType, String? suffix, int? maxLines})`
  - `showLockoutSheet<T>({required BuildContext context, required String title, required Widget child})` replacing `showJinatraSheet`, and a matching `showLockoutRawSheet` so `isScrollControlled` / `useSafeArea` / shape can never be forgotten at a call site — this closes the follow-up logged at `b42586d` in `.spine/progress.md`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget_kit_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/lockout_card.dart';
import 'package:lockout/widgets/lockout_field.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';

Widget _host(Widget child) => MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('card takes colour and radius from the theme, never a constant',
      (tester) async {
    await tester.pumpWidget(_host(LockoutCard(child: const Text('x'))));
    await tester.pump();

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, isNull, reason: 'colour must come from CardThemeData');
    expect(card.shape, isNull, reason: 'shape must come from CardThemeData');
  });

  testWidgets('a tappable card has a 48dp minimum target', (tester) async {
    await tester.pumpWidget(
      _host(LockoutCard(onTap: () {}, child: const Text('x'))),
    );
    await tester.pump();

    expect(find.byType(InkWell), findsOneWidget);
    final size = tester.getSize(find.byType(LockoutCard));
    expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
  });

  testWidgets('field renders a themed TextField with its label', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(LockoutField(controller: controller, label: 'Weight', suffix: 'kg')),
    );
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
  });

  testWidgets('sheet opens with a drag handle and 28dp top corners',
      (tester) async {
    await tester.pumpWidget(_host(Builder(
      builder: (context) => TextButton(
        onPressed: () => showLockoutSheet<void>(
          context: context,
          title: 'Add day',
          child: const SizedBox(height: 120),
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Add day'), findsOneWidget);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    final shape = (sheet.shape ??
        Theme.of(tester.element(find.byType(BottomSheet)))
            .bottomSheetTheme
            .shape) as RoundedRectangleBorder;
    expect(
      shape.borderRadius.resolve(TextDirection.ltr).topLeft.x,
      LockoutTheme.radiusSheet,
    );
  });

  testWidgets('a sheet keeps clear of the system navigation bar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(Builder(
      builder: (context) => TextButton(
        onPressed: () => showLockoutSheet<void>(
          context: context,
          title: 'Add day',
          child: const SizedBox(height: 120),
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final bottom = tester.getBottomLeft(find.text('Add day')).dy;
    expect(bottom, lessThanOrEqualTo(800.0 - 48.0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/widget_kit_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/widgets/lockout_card.dart'`.

- [ ] **Step 3: Write `lib/widgets/lockout_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';

/// The app's one card shape.
///
/// It deliberately sets neither colour nor shape: both come from
/// `CardThemeData`, so a theme switch repaints every card without touching a
/// call site. A card that passes its own `color:` is a bug, not a variant.
class LockoutCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Only for a card that must sit on top of another surface — a sheet over
  /// a card, say. Everything else takes the theme's surface tone.
  final Color? color;

  final VoidCallback? onTap;

  /// Lifts to elevation 3 for the one card per screen that leads.
  final bool elevated;

  const LockoutCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding ?? const EdgeInsets.all(LockoutTheme.cardPadding),
      child: child,
    );

    return Card(
      color: color,
      elevation: elevated ? 3 : null,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(LockoutTheme.radiusCard),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: LockoutTheme.minTouchTarget,
                ),
                child: body,
              ),
            ),
    );
  }
}
```

- [ ] **Step 4: Write `lib/widgets/lockout_field.dart`**

```dart
import 'package:flutter/material.dart';

/// A text field with the app's decoration already applied.
///
/// Every property it does not name comes from `InputDecorationTheme`, so a
/// field cannot drift from the rest of the app by forgetting one.
class LockoutField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;

  /// Unit shown inside the field — `kg`, `cm`, `reps`.
  final String? suffix;

  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const LockoutField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.suffix,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
      ),
    );
  }
}
```

- [ ] **Step 5: Rework `lib/widgets/sheet_scaffold.dart`**

Rename `showJinatraSheet` to `showLockoutSheet` and add the raw variant that owns the easily-forgotten properties:

```dart
/// Opens a modal sheet with every property this app's sheets must have.
///
/// The three picker call sites used to repeat `isScrollControlled`,
/// `backgroundColor`, `shape` and `useSafeArea` by hand, and only one of them
/// was covered by a test — deleting `useSafeArea` from either picker left the
/// suite green while the sheet slid under the system navigation bar. Owning
/// them here makes that unforgettable.
Future<T?> showLockoutRawSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}

/// The titled form of [showLockoutRawSheet].
Future<T?> showLockoutSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showLockoutRawSheet<T>(
    context: context,
    builder: (ctx) => SheetScaffold(title: title, child: child),
  );
}
```

`SheetScaffold` itself keeps its existing inner `SafeArea` and keyboard-inset handling — that behaviour was hard-won at `b42586d` and must not be simplified away. Only its colours, radii and type change to theme reads.

- [ ] **Step 6: Restyle `lib/widgets/undo_banner.dart`**

Keep every timing and lifecycle detail. Replace only the neubrutalist decoration with `Theme.of(context)` reads and the shape with `LockoutTheme.radiusButton`. Do not convert it to a bare `SnackBar` in this task — it positions itself against `BottomNav.lastRenderedHeight`, and that interaction has its own tests.

- [ ] **Step 7: Delete the old widget files and update call sites**

```bash
git rm lib/widgets/jinatra_card.dart lib/widgets/jinatra_button.dart lib/widgets/jinatra_input.dart
```

Replace every `JinatraCard(` with `LockoutCard(`, every `JinatraButton(label: X, onPressed: Y)` with `FilledButton(onPressed: Y, child: Text(X))`, every `JinatraButton(..., isSignal: true)` with `FilledButton.tonal(...)`, and every `JinatraInput(` with `LockoutField(`. Run the analyzer to find them all:

Run: `C:\src\flutter\bin\flutter.bat analyze`
Expected: zero errors before moving on.

- [ ] **Step 8: Run the full suite**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: all pass, including the 5 new widget-kit tests. `widgets_v2_test.dart` asserts neubrutalist borders and shadows — rewrite its assertions here to the theme equivalents rather than deleting the file.

- [ ] **Step 9: Commit**

```bash
git add -A lib/widgets test/widget_kit_test.dart test/widgets_v2_test.dart
git commit -m "feat(widgets): Material 3 card, field and sheet kit

Buttons are now the framework's own, already themed in Task 3, so there is
no bespoke button class to drift. showLockoutRawSheet owns isScrollControlled
and useSafeArea, closing the follow-up logged at b42586d where deleting
useSafeArea from a picker left every test green."
```

---

### Task 9: Home screen

**Files:**
- Modify: `lib/screens/today_tab.dart:463-570` (`_buildPreSession`, `_quickActions`)
- Modify: `lib/widgets/home_hub.dart`, `lib/widgets/hero_card.dart`, `lib/widgets/action_grid.dart`, `lib/widgets/stat_tile.dart`, `lib/widgets/calm_row.dart`, `lib/widgets/progress_hero.dart`
- Test: `test/home_tab_test.dart` (extend)

**Interfaces:**
- Consumes: `LockoutCard`, `LockoutTheme`, `LockoutSemantics`, the `ProgressSegment` navigation from Task 7.
- Produces: no new public API. `HomeHub`'s constructor keeps its current parameter names so `today_tab.dart` needs no signature change.

- [ ] **Step 1: Write the failing test**

Append to `test/home_tab_test.dart`:

```dart
  testWidgets('home leads with a greeting, today card and start action',
      (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);

    expect(find.byType(FilledButton), findsWidgets);
    expect(find.text('START SESSION'), findsNothing,
        reason: 'all-caps is retired outside metadata labels');
    expect(find.text('Start session'), findsOneWidget);

    final title = tester.widget<Text>(find.text('Today'));
    final context = tester.element(find.text('Today'));
    expect(
      title.style?.fontSize ?? Theme.of(context).textTheme.headlineMedium!.fontSize,
      28,
    );
  });

  testWidgets('no widget on home paints a hardcoded colour', (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);

    final scheme = LockoutScheme.graphite.colors;
    for (final container in tester.widgetList<Container>(find.byType(Container))) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration || decoration.color == null) continue;
      final colour = decoration.color!;
      if (colour.a == 0) continue;
      expect(
        [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
          scheme.primary,
          scheme.primaryContainer,
          scheme.secondary,
          scheme.secondaryContainer,
          scheme.tertiaryContainer,
          ...LockoutScheme.graphite.semantics.categoryRamp,
        ].contains(colour),
        isTrue,
        reason: 'unthemed colour ${colour.toARGB32().toRadixString(16)}',
      );
    }
  });
```

Add `seedActiveWeekdayRoutineForToday()` and `hostedTodayTab()` to `test/test_helpers.dart` if they do not already exist there — `today_tab_test.dart` already builds this fixture inline, so move that code rather than writing a second copy.

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/home_tab_test.dart`
Expected: FAIL — "Start session" not found (the current label is `START SESSION`).

- [ ] **Step 3: Rebuild the Home composition**

`_buildPreSession` becomes a `CustomScrollView` with these slivers, in order:

1. Header: `Text('Today', style: textTheme.headlineMedium)` with the date beneath in `labelMedium`.
2. **Today card** — `LockoutCard(elevated: true)` carrying the eyebrow (`TODAY · MON` in `labelSmall`, the one place all-caps survives), the day name in `titleLarge`, `N exercises · N sets` in `bodyMedium`, and a full-width `FilledButton` labelled `Start session`. Rest day renders the same card with no button and the rest copy. Empty day renders the guidance text and a `TextButton` to the Workout tab.
3. **Weight card** — current weight in `displaySmall` using `LockoutTheme.numeric`, goal and remaining in `bodySmall`, the sparkline beneath tinted with `LockoutSemantics.of(context).chartLine`.
4. **Nutrition row** — three `LinearProgressIndicator`s (protein, calories, water) with `labelMedium` captions. Water uses `colorScheme.secondary`; the other two use `colorScheme.primary`. Hidden entirely when `foodTabEnabled` is false.
5. **Quick actions** — the existing `ActionGrid`, retinted from `LockoutSemantics.categoryAt(i)` instead of `JinatraTokens.accentAt(i)`, with sentence-case labels.

Every label in `_quickActions()` moves from `'LOG FOOD'` to `'Log food'`, `'WEIGH IN'` to `'Weigh in'`, `'ROUTINES'` to `'Workout'`, `'HISTORY'` to `'History'`, `'CUSTOM'` to `'Custom'`, `'STREAK'` to `'Streak'`, `'PLAN'` to `'Plan'`, `'EXERCISES'` to `'Exercises'`.

- [ ] **Step 4: Run the tests**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/home_tab_test.dart test/today_tab_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/today_tab.dart lib/widgets test/home_tab_test.dart test/test_helpers.dart
git commit -m "feat(home): Material 3 dashboard with a leading today card"
```

---

### Task 10: Live session screen

**Files:**
- Modify: `lib/screens/today_tab.dart:573-898` (`_buildActiveSession`, `_buildExerciseCard`, `_buildSetRow`, `_buildRestBar`)
- Test: `test/today_tab_test.dart` (extend)

**Interfaces:**
- Consumes: `LockoutCard`, `LockoutTheme.numeric`, `LockoutSemantics`.
- Produces: no new public API. `_LiveSet` / `_LiveExercise` keep their current fields.

- [ ] **Step 1: Write the failing test**

Append to `test/today_tab_test.dart`:

```dart
  testWidgets('session header shows elapsed time and exercise progress',
      (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);

    await tester.tap(find.text('Start session'));
    await settle(tester);

    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.byIcon(Icons.check), findsWidgets);
  });

  testWidgets('weight and rep steppers meet the 48dp touch target',
      (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    for (final icon in [Icons.remove, Icons.add]) {
      for (final element in find.byIcon(icon).evaluate()) {
        final size = tester.getSize(find.byWidget(
          element.findAncestorWidgetOfExactType<IconButton>()!,
        ));
        expect(size.width, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
        expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
      }
    }
  });

  testWidgets('the leg-safety notice renders in the warning role',
      (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    expect(find.textContaining('Pain-free movement only'), findsOneWidget);
  });

  testWidgets('numeric columns use the mono family so digits align',
      (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    final setNumber = tester.widget<Text>(find.text('1').first);
    expect(setNumber.style?.fontFamily, 'JetBrainsMono');
  });

  testWidgets('the header states duration, volume and sets', (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Sets'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('completing a set tints the whole row, not just the tick',
      (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    Color? rowColour() {
      final box = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('set-row-0-0')),
      );
      return (box.decoration as BoxDecoration).color;
    }

    final before = rowColour();
    await tester.tap(find.byKey(const ValueKey('set-complete-0-0')));
    await tester.pumpAndSettle();

    expect(rowColour(), isNot(before));
  });

  testWidgets('the rest bar adjusts in both directions', (tester) async {
    await seedActiveWeekdayRoutineForToday();
    await tester.pumpWidget(hostedTodayTab());
    await settle(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('set-complete-0-0')));
    await tester.pump();

    expect(find.text('-15s'), findsOneWidget);
    expect(find.text('+15s'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/today_tab_test.dart`
Expected: FAIL — "Pain-free movement only" not found.

- [ ] **Step 3: Rebuild the session UI**

Reference: [Hevy — logging a workout](https://mobbin.com/flows/7b6374ff-8ff6-4d7b-babe-077e72b6ee1f). Match its structure, not its colours.

- Header: a three-figure `Row` — `Duration`, `Volume`, `Sets` — each a `labelSmall` caption over a `LockoutTheme.numeric(context, size: 20)` value, with a `FilledButton.tonal('Finish')` at the trailing edge and a `LinearProgressIndicator` of completed exercises over total beneath.
- `_buildExerciseCard`: `LockoutCard` with the exercise name in `titleMedium`, muscle group and `sets x reps` in `bodySmall`, previous performance in `labelSmall`, then the set table.
- `_buildSetRow`: a `Row` of `SET | PREVIOUS | KG | REPS | check`. Weight and reps each get `IconButton(icon: Icon(Icons.remove))` / `Icons.add` with `constraints: BoxConstraints(minWidth: 48, minHeight: 48)`. The complete control is an `IconButton.filled`. **A completed row tints its whole background** to `LockoutSemantics.of(context).success.withValues(alpha: 0.12)`, not just the tick — progress down a card of eight sets has to be readable without counting ticks.
- Leg-safety notice: one `LockoutCard(color: colorScheme.tertiaryContainer)` at the top of the exercise list with the warning icon and the copy `Pain-free movement only. Use moderate load, avoid forcing painful reps.`
- `_buildRestBar`: a bottom bar on `surfaceContainerHigh` — a full-width `LinearProgressIndicator` of remaining time along its top edge, the countdown in `LockoutTheme.numeric(context, size: 28)`, then `-15s`, `+15s` and `Skip` as text buttons. Symmetric adjust rather than add-only: overshooting a rest by 30s with no way back is the common case.
- Finish: a `showLockoutSheet` summary carrying the same Duration / Volume / Sets triple plus `Save` and `Discard`, so the numbers the log will show are confirmed before the write rather than discovered after it. The existing save path is called unchanged from `Save`.

Test anchors: give each set row a `ValueKey('set-row-$exerciseIndex-$setIndex')` on its `DecoratedBox`, and each complete control a `ValueKey('set-complete-$exerciseIndex-$setIndex')`. The tests above address those keys rather than hunting by icon, so a second `Icons.check` elsewhere on screen cannot make them pass or fail by accident.

Do not touch any of the set/rest/persistence logic — this task changes only what is painted. The rest bar's `-15s` / `+15s` adjust the existing countdown value through whatever setter `_restRunning` already uses; they do not introduce a second timer.

- [ ] **Step 4: Run the tests**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/today_tab_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/today_tab.dart test/today_tab_test.dart
git commit -m "feat(session): Material 3 live session with aligned numeric columns"
```

---

### Task 11: Workout tab — feature today, collapse the week

This is the behaviour change the redesign was asked for.

**Files:**
- Modify: `lib/services/schedule_service.dart` — rename `_matchByWeekday` to `matchByWeekday` and `_matchByRotation` to `matchByRotation` (pure rename, two call sites)
- Create: `lib/services/routine_focus.dart`
- Create: `lib/widgets/today_day_card.dart`
- Create: `lib/widgets/week_day_row.dart`
- Modify: `lib/screens/routines_tab.dart:636-750` (`_buildRoutineCard`)
- Delete: `lib/widgets/day_row.dart`
- Test: `test/routine_focus_test.dart` (create), `test/routines_tab_test.dart` (extend)

**Interfaces:**
- Consumes: `Routine`, `TrainingDay`, `SchedulingMode`, `ScheduleService.matchByWeekday`, `ScheduleService.matchByRotation`.
- Produces:
  - `enum FeaturedDayKind { today, next }`
  - `class RoutineFocusResult { final TrainingDay? day; final FeaturedDayKind kind; }`
  - `RoutineFocus.resolve({required Routine routine, required List<TrainingDay> days, required DateTime now, required bool isActive}) -> RoutineFocusResult?` — null when nothing should be featured
  - `TodayDayCard({Key? key, required TrainingDay day, required Color accent, required String summary, required FeaturedDayKind kind, required VoidCallback onTap, VoidCallback? onStart})`
  - `WeekDayRow({Key? key, required TrainingDay day, required Color accent, required String summary, required bool isToday, required VoidCallback onTap})`
  - `String dayRowSummary(TrainingDay day)` moves from `day_row.dart` to `week_day_row.dart` unchanged.

- [ ] **Step 1: Write the failing test**

```dart
// test/routine_focus_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/services/routine_focus.dart';
import 'package:lockout/services/schedule_service.dart';

Routine _routine({
  SchedulingMode mode = SchedulingMode.weekday,
  String createdAt = '2026-01-01T00:00:00.000',
}) {
  return Routine(
    id: 'r1',
    name: 'Push Pull Legs',
    schedulingMode: mode,
    createdAt: createdAt,
  );
}

TrainingDay _day(String id, String tag, {int order = 0, bool rest = false}) {
  return TrainingDay(
    id: id,
    routineId: 'r1',
    name: 'Day $tag',
    tag: tag,
    orderIndex: order,
    isRestDay: rest,
  );
}

void main() {
  // 2026-09-28 is a Monday.
  final monday = DateTime(2026, 9, 28);

  test('an active weekday routine features today, labelled today', () {
    final days = [_day('d1', 'MON'), _day('d2', 'WED', order: 1)];
    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result, isNotNull);
    expect(result!.day!.id, 'd1');
    expect(result.kind, FeaturedDayKind.today);
  });

  test('a rest day scheduled today is still featured', () {
    final days = [_day('d1', 'MON', rest: true)];
    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result!.day!.isRestDay, isTrue);
    expect(result.kind, FeaturedDayKind.today);
  });

  test('a gap in the week features nothing but still resolves', () {
    final days = [_day('d1', 'WED'), _day('d2', 'FRI', order: 1)];
    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result, isNotNull);
    expect(result!.day, isNull, reason: 'nothing scheduled today');
    expect(result.kind, FeaturedDayKind.today);
  });

  test('a rotating routine features the next slot, labelled next', () {
    final days = [
      _day('d1', 'A', order: 0),
      _day('d2', 'B', order: 1),
      _day('d3', 'C', order: 2),
    ];
    final result = RoutineFocus.resolve(
      routine: _routine(mode: SchedulingMode.rotating),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result!.kind, FeaturedDayKind.next);
    expect(
      result.day!.id,
      ScheduleService.matchByRotation(
        days,
        _routine(mode: SchedulingMode.rotating),
        monday,
      )!.id,
      reason: 'must agree with the scheduler the session actually uses',
    );
  });

  test('an inactive routine features nothing at all', () {
    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: [_day('d1', 'MON')],
      now: monday,
      isActive: false,
    );
    expect(result, isNull);
  });

  test('a routine with no days features nothing at all', () {
    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: const [],
      now: monday,
      isActive: true,
    );
    expect(result, isNull);
  });
}
```

Adjust the `Routine` and `TrainingDay` constructor arguments to match the real definitions in `lib/models/models.dart` — read them before writing, do not guess field names.

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/routine_focus_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lockout/services/routine_focus.dart'`.

- [ ] **Step 3: Make the schedule matchers public**

In `lib/services/schedule_service.dart`, rename `_matchByWeekday` to `matchByWeekday` and `_matchByRotation` to `matchByRotation`, updating the two call sites inside `resolveFor`. Nothing else changes — same bodies, same behaviour. This exists so `RoutineFocus` cannot drift from what the session scheduler actually does, which is the whole point of featuring a day.

- [ ] **Step 4: Write `lib/services/routine_focus.dart`**

```dart
import '../models/models.dart';
import 'schedule_service.dart';

/// Why a day is being featured.
enum FeaturedDayKind {
  /// A weekday routine, and this is the day pinned to today's weekday.
  today,

  /// A rotating routine, where "today" is a position in a cycle rather than
  /// a weekday, so the card reads NEXT.
  next,
}

/// What a routine card should lead with. [day] is null when the routine is
/// worth featuring but has nothing scheduled right now.
class RoutineFocusResult {
  final TrainingDay? day;
  final FeaturedDayKind kind;

  const RoutineFocusResult({required this.day, required this.kind});
}

/// Decides which single day a routine card leads with.
///
/// Pure and synchronous: `RoutinesTab` already holds every day in memory, so
/// going back to sqflite per card would be a read per routine per rebuild.
/// It reuses `ScheduleService`'s own matchers rather than reimplementing
/// them, because a card that features a different day than the one
/// `START SESSION` would open is worse than no card at all.
class RoutineFocus {
  RoutineFocus._();

  static RoutineFocusResult? resolve({
    required Routine routine,
    required List<TrainingDay> days,
    required DateTime now,
    required bool isActive,
  }) {
    // "Today" is only meaningful for the routine actually being followed.
    // An inactive routine opens straight to its collapsed week.
    if (!isActive) return null;
    if (days.isEmpty) return null;

    if (routine.schedulingMode == SchedulingMode.weekday) {
      return RoutineFocusResult(
        day: ScheduleService.matchByWeekday(days, now),
        kind: FeaturedDayKind.today,
      );
    }

    return RoutineFocusResult(
      day: ScheduleService.matchByRotation(days, routine, now),
      kind: FeaturedDayKind.next,
    );
  }
}
```

- [ ] **Step 5: Run the focus test**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/routine_focus_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Write the two widgets**

`lib/widgets/today_day_card.dart` — a `LockoutCard(elevated: true)` with:
- eyebrow `Row`: a 4dp-wide `accent` bar, then `TODAY` or `NEXT` plus the day tag in `labelSmall`
- day name in `titleLarge`
- `summary` in `bodyMedium`
- a full-width `FilledButton('Start session')` when `onStart != null`
- for `day.isRestDay`: the copy `Recovery is part of the plan.` and no button

`lib/widgets/week_day_row.dart` — a `ListTile`-shaped row: a 40dp rounded leading box tinted `accent` carrying the weekday tag in `labelSmall`, `day.name` as the title, `summary` as the subtitle, `Icons.chevron_right` trailing, and a 2dp `accent` left edge when `isToday`. Move `dayRowSummary` here verbatim.

- [ ] **Step 7: Rebuild `_buildRoutineCard` in `lib/screens/routines_tab.dart`**

Replace the `else ...(() { ... })()` block that maps every day to a `DayRow` with:

```dart
          if (days.isEmpty)
            Text(
              'No training days yet. Open the week and tap "Add day" to pin a '
              'workout to a weekday.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            if (focus != null)
              focus.day == null
                  ? _buildNothingScheduledCard()
                  : TodayDayCard(
                      day: _hydrated(focus.day!),
                      accent: colours[focus.day!.id] ?? semantics.restDay,
                      summary: dayRowSummary(_hydrated(focus.day!)),
                      kind: focus.kind,
                      onTap: () => _openDaySheet(routine, focus.day!),
                      onStart: focus.day!.isRestDay ||
                              _hydrated(focus.day!).exercises.isEmpty
                          ? null
                          : () => _startSessionFor(routine, focus.day!),
                    ),
            const SizedBox(height: LockoutTheme.spaceMd),
            _buildWeekExpander(routine, days, colours),
          ],
```

`_buildWeekExpander` is an `ExpansionTile` with `title: Text('Full week (${days.length})')`, `initiallyExpanded: false`, `shape`/`collapsedShape` taking `LockoutTheme.radiusButton`, whose children are the `WeekDayRow`s plus a trailing `TextButton.icon(icon: Icon(Icons.add), label: Text('Add day'))` wired to the existing `_openDayFormSheet`. Expansion state is deliberately not persisted: reopening the tab returns to the focused view, which is the point of the change.

The `+ ADD DAY` pill in the `TRAINING WEEK` header row is removed; its handler moves into the expander. Rename the header text to sentence case.

- [ ] **Step 8: Extend `test/routines_tab_test.dart`**

```dart
  testWidgets('an active routine leads with one day and a collapsed week',
      (tester) async {
    await seedActiveWeekdayRoutine();
    await tester.pumpWidget(hostedRoutinesTab());
    await settle(tester);

    expect(find.byType(TodayDayCard), findsOneWidget);
    expect(find.byType(WeekDayRow), findsNothing,
        reason: 'the week must start collapsed');
    expect(find.textContaining('Full week'), findsOneWidget);
  });

  testWidgets('expanding reveals every day and the add-day action',
      (tester) async {
    await seedActiveWeekdayRoutine();
    await tester.pumpWidget(hostedRoutinesTab());
    await settle(tester);

    await tester.tap(find.textContaining('Full week'));
    await tester.pumpAndSettle();

    expect(find.byType(WeekDayRow), findsWidgets);
    expect(find.text('Add day'), findsOneWidget);
  });

  testWidgets('an inactive routine features no day', (tester) async {
    await seedInactiveRoutine();
    await tester.pumpWidget(hostedRoutinesTab());
    await settle(tester);

    expect(find.byType(TodayDayCard), findsNothing);
    expect(find.textContaining('Full week'), findsOneWidget);
  });

  testWidgets('a gap in the week says so and offers a custom session',
      (tester) async {
    await seedActiveRoutineWithNoDayToday();
    await tester.pumpWidget(hostedRoutinesTab());
    await settle(tester);

    expect(find.textContaining('Nothing scheduled today'), findsOneWidget);
    expect(find.byType(TodayDayCard), findsNothing);
  });

  testWidgets('a rest day today is featured without a start button',
      (tester) async {
    await seedActiveRoutineWithRestDayToday();
    await tester.pumpWidget(hostedRoutinesTab());
    await settle(tester);

    expect(find.byType(TodayDayCard), findsOneWidget);
    expect(find.text('Start session'), findsNothing);
    expect(find.textContaining('Recovery is part of the plan'), findsOneWidget);
  });
```

Write the five seed helpers in `test/test_helpers.dart`, each inserting a routine and its days through `DatabaseService` exactly as the existing routines tests already do. Seed weekday tags relative to `ScheduleService.weekdayCode(DateTime.now())` so the suite does not start failing on a Tuesday.

- [ ] **Step 9: Delete the old row and run everything**

```bash
git rm lib/widgets/day_row.dart
```

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: all pass. `day_row_test.dart` is replaced by the new `WeekDayRow` cases — move its assertions rather than deleting them.

- [ ] **Step 10: Commit**

```bash
git add -A lib/services lib/widgets lib/screens/routines_tab.dart test
git commit -m "feat(routines): lead with today, collapse the rest of the week

The routine card rendered all seven days as near-identical rows, so the one
day that matters had no more weight than the other six. RoutineFocus reuses
ScheduleService's own matchers rather than reimplementing them: a card that
featured a different day than START SESSION would open is worse than no card.
The week stays one tap away so the builder is still usable on any day."
```

---

### Task 12: Progress content

**Files:**
- Modify: `lib/screens/body_tab.dart`, `lib/screens/log_tab.dart`
- Modify: `lib/widgets/sparkline.dart`
- Test: `test/body_tab_test.dart`, `test/log_tab_test.dart` (extend)

**Interfaces:**
- Consumes: `LockoutCard`, `LockoutSemantics.chartLine` / `chartFill`, `LockoutTheme.numeric`.
- Produces: `Sparkline` gains `Sparkline({..., required Color line, required Color fill, bool smooth = true})` — colours are passed in rather than read statically, because a painter has no theme of its own.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('sparkline draws a smooth curve in the themed chart colour',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: LockoutTheme.build(
        colors: LockoutScheme.graphite.colors,
        semantics: LockoutScheme.graphite.semantics,
      ),
      home: Builder(
        builder: (context) {
          final semantics = LockoutSemantics.of(context);
          return Scaffold(
            body: Sparkline(
              values: const [80, 79.4, 79.1, 78.2, 77.9],
              line: semantics.chartLine,
              fill: semantics.chartFill,
            ),
          );
        },
      ),
    ));
    await tester.pump();

    final sparkline = tester.widget<Sparkline>(find.byType(Sparkline));
    expect(sparkline.smooth, isTrue);
    expect(sparkline.line, LockoutScheme.graphite.semantics.chartLine);
  });

  testWidgets('current weight is the one large number on the screen',
      (tester) async {
    await seedWeightHistory();
    await tester.pumpWidget(hostedBodyTab());
    await settle(tester);

    final context = tester.element(find.byType(Sparkline));
    final display = Theme.of(context).textTheme.displaySmall!.fontSize;
    final big = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.style?.fontSize ?? 0) >= display)
        .toList();
    expect(big.length, 1, reason: 'exactly one display-scale number');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/body_tab_test.dart`
Expected: FAIL — `Sparkline` has no named parameter `line`.

- [ ] **Step 3: Upgrade `Sparkline`**

Add `line`, `fill` and `smooth` parameters. In the painter, replace the `lineTo` chain with a Catmull-Rom-to-cubic conversion when `smooth` is true:

```dart
    // A monotone cubic through the points rather than straight segments.
    // Weight is a slow trend, not a set of discrete events, and a polyline
    // reads every daily fluctuation as a corner.
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
```

Keep the existing straight-segment path behind `smooth: false` so a two-point series (where a curve has nothing to interpolate) still renders correctly.

- [ ] **Step 4: Restyle both screens**

Body tab: weight in `displaySmall` + `LockoutTheme.numeric`, goal and remaining beneath, the sparkline in a `LockoutCard`, a range `SegmentedButton` (`1M` / `3M` / `1Y` / `All`), then BMI and plan as separate cards. Log tab: entries as quiet `ListTile` rows grouped under month headers in `labelMedium`, volume and duration in the mono family.

- [ ] **Step 5: Run the tests**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/body_tab_test.dart test/log_tab_test.dart test/progress_tab_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/body_tab.dart lib/screens/log_tab.dart lib/widgets/sparkline.dart test
git commit -m "feat(progress): themed weight chart and quiet history rows

Sparkline takes its colours as parameters: a CustomPainter has no theme of
its own, and reading one statically is what this branch is removing."
```

---

### Task 13: Food content

**Files:**
- Modify: `lib/screens/food_tab.dart`, `lib/widgets/meal_section.dart`, `lib/widgets/food_picker.dart`
- Test: `test/food_tab_test.dart` (extend)

**Interfaces:**
- Consumes: `LockoutCard`, `showLockoutRawSheet`, `LockoutTheme`.
- Produces: no new public API.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('daily totals render as three themed progress bars',
      (tester) async {
    await seedFoodDay();
    await tester.pumpWidget(hostedFoodTab());
    await settle(tester);

    final bars = tester
        .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .toList();
    expect(bars.length, greaterThanOrEqualTo(3));
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
  });

  testWidgets('water uses the secondary role, not primary', (tester) async {
    await seedFoodDay();
    await tester.pumpWidget(hostedFoodTab());
    await settle(tester);

    final context = tester.element(find.text('Water'));
    final scheme = Theme.of(context).colorScheme;
    final waterBar = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Water'),
          matching: find.byType(Column),
        ).first,
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(waterBar.color, scheme.secondary);
  });

  testWidgets('the food picker opens as a safe-area sheet', (tester) async {
    await seedFoodDay();
    await tester.pumpWidget(hostedFoodTab());
    await settle(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(SearchBar), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_tab_test.dart`
Expected: FAIL — 'Water' not found / no `SearchBar`.

- [ ] **Step 3: Restyle the food screens**

Reference: [MyFitnessPal daily totals](https://mobbin.com/screens/32b82d20-deb0-493f-a643-c170d9e46b8b), [Yazio meal list](https://mobbin.com/screens/7157507b-da8e-40f7-85b3-37017cc7002f), [Life Reset dark macro bars](https://mobbin.com/screens/4ec121e3-6681-4954-bae5-6313bebff8d7).

Totals card with three labelled `LinearProgressIndicator`s (water tinted `colorScheme.secondary`, protein and calories `colorScheme.primary`). Each bar's caption row is `Label` on the leading edge, `963 / 2,930` in the mono family in the middle, and **`1,967 left`** on the trailing edge in `labelMedium` — the remaining figure is the one a person decides on, so it is stated rather than left to be subtracted. Meal sections as `LockoutCard`s with a `titleMedium` heading, quiet rows, and a trailing `IconButton(Icons.add)` per meal so logging does not require opening the section first. The picker moves to `showLockoutRawSheet` with a Material `SearchBar` and `FilterChip`s for category, replacing the hand-rolled search field. No new analytics.

- [ ] **Step 4: Run the tests**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/food_tab_test.dart test/food_search_test.dart test/food_library_test.dart`
Expected: PASS. `food_search_test` and `food_library_test` cover pure logic and must pass unchanged — if either needs editing, the change has leaked out of the UI.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/food_tab.dart lib/widgets/meal_section.dart lib/widgets/food_picker.dart test/food_tab_test.dart
git commit -m "feat(food): themed totals and a Material search sheet"
```

---

### Task 14: Profile content and the seven-swatch theme picker

**Files:**
- Modify: `lib/screens/settings_screen.dart` (`SettingsBody`)
- Test: `test/settings_restyle_test.dart` (rewrite), `test/theme_picker_test.dart` (create)

**Interfaces:**
- Consumes: `ThemeController` (Task 4), `LockoutScheme`, `LockoutCard`.
- Produces: no new public API. The old `_applyTheme(AppPalette)` becomes `_applyTheme(String key)` delegating to `ThemeController.instance.select`.

- [ ] **Step 1: Write the failing test**

```dart
// test/theme_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/screens/profile_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/theme/theme_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
    ThemeController.instance.resetForTest();
    await ThemeController.instance.load();
  });

  testWidgets('offers six swatches and no dynamic option when unavailable',
      (tester) async {
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);

    for (final scheme in LockoutScheme.all) {
      expect(find.text(scheme.name), findsOneWidget, reason: scheme.key);
    }
    expect(find.text('Match my phone'), findsNothing);
  });

  testWidgets('offers the dynamic option once the platform supplies one',
      (tester) async {
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);

    expect(find.text('Match my phone'), findsOneWidget);
  });

  testWidgets('choosing a swatch persists it and repaints', (tester) async {
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);

    await tester.tap(find.text('Paper'));
    await settle(tester);

    expect(ThemeController.instance.selectedKey, 'paper');
    expect(
      await DatabaseService.instance.getSetting('theme_key', defaultValue: ''),
      'paper',
    );
  });

  testWidgets('no string in settings says LIAD', (tester) async {
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);
    expect(find.textContaining('LIAD'), findsNothing);
  });
}
```

`hostedProfileTab()` wraps `ProfileTab` in a `ListenableBuilder` on `ThemeController.instance` so a selection actually repaints, mirroring `main.dart`. Put it in `test/test_helpers.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/theme_picker_test.dart`
Expected: FAIL — 'Graphite' not found (the picker still lists Jinatra palettes).

- [ ] **Step 3: Rebuild the settings body**

Reference: [theScore account groups](https://mobbin.com/screens/0ca2cf67-c941-428a-8d03-6bcf28175c32), [Crypto.com account rows](https://mobbin.com/screens/036aab09-919c-438e-9208-4789bf516113), [Base display settings](https://mobbin.com/screens/3f573b95-4bbb-4978-957e-56178543e8e7).

- Grouped `LockoutCard` sections: Appearance, Units, Training, Food, Notifications, Data, About. Each group sits under a `labelSmall` caption outside the card, and every row states its current value on the trailing edge (`Weight  kg >`, `Rest timer  60s >`) rather than only a chevron — the screen should read without opening anything.
- The theme picker is a `Wrap` of swatches. Each swatch is a 2-column mini preview: a rounded rectangle filled with `scheme.colors.surface`, a `primary` pill and a `secondary` pill inside it, the scheme `name` in `labelMedium` beneath, and a `check_circle` overlay when selected. The dynamic entry uses `Icons.palette` with the label `Match my phone`, and is present only when `ThemeController.instance.dynamicAvailable`.
- Tapping a swatch calls `await ThemeController.instance.select(key)`.
- Destructive actions (wipe data) move to the bottom in `colorScheme.error`, behind the existing confirmation dialog.
- Replace the `JINATRA v1.1` string in About with the app version from `pubspec.yaml`. No `LIAD` string anywhere.

- [ ] **Step 4: Rewrite `test/settings_restyle_test.dart`**

Its neubrutalist assertions (border widths, hard shadows, mono all-caps labels) become the M3 equivalents: every section is a `Card`, every tappable row clears 48dp, and the destructive action resolves to `colorScheme.error`.

- [ ] **Step 5: Run the tests**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/theme_picker_test.dart test/settings_restyle_test.dart test/profile_tab_test.dart test/backup_roundtrip_test.dart`
Expected: PASS. `backup_roundtrip_test` must pass **unchanged** — restore writes `theme_key`, and that path must keep working.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart test
git commit -m "feat(profile): grouped settings and a seven-swatch theme picker

Dynamic appears only when the platform actually supplies a scheme, so the
option can never be chosen and silently do nothing."
```

---

### Task 15: Delete the old theme layer and verify the migration

**Files:**
- Delete: `lib/theme/jinatra_tokens.dart`, `lib/theme/app_palette.dart`
- Delete: `test/theme_tokens_test.dart` (its invariants now live in `schemes_test.dart`)
- Delete: `lib/widgets/day_block.dart`'s neubrutalist shell; keep `DayColours`, `SectionHeading`, `SubItemRow`, `AddLink` restyled
- Create: `test/no_legacy_theme_test.dart`
- Modify: `README.md`, `docs/` as needed

**Interfaces:**
- Consumes: everything from Tasks 1–14.
- Produces: a guarantee, enforced by test, that no Jinatra symbol survives in `lib/`.

- [ ] **Step 1: Write the failing test**

```dart
// test/no_legacy_theme_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  test('no Jinatra symbol survives anywhere in lib/', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Comments are blanked so a doc comment explaining the migration does
      // not read as a live reference.
      final code = blankComments(entity.readAsStringSync());
      if (code.contains('Jinatra') ||
          code.contains('jinatra') ||
          code.contains('AppPalette')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'the old theme layer is still referenced');
  });

  test('the old theme files are gone', () {
    expect(File('lib/theme/jinatra_tokens.dart').existsSync(), isFalse);
    expect(File('lib/theme/app_palette.dart').existsSync(), isFalse);
  });

  test('no widget hardcodes a Color constant outside lib/theme', () {
    final pattern = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.replaceAll(r'\', '/').contains('lib/theme/')) continue;
      final code = blankComments(entity.readAsStringSync());
      if (pattern.hasMatch(code)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty,
        reason: 'colour belongs in a ColorScheme, not a widget');
  });

  test('the shipped app is called LOCKOUT, never LIAD', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('LIAD')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1 test/no_legacy_theme_test.dart`
Expected: FAIL — offenders list is non-empty.

- [ ] **Step 3: Remove the remaining references**

```bash
grep -rn "Jinatra\|jinatra\|AppPalette" lib/
```

Fix each hit, then:

```bash
git rm lib/theme/jinatra_tokens.dart lib/theme/app_palette.dart test/theme_tokens_test.dart
```

Move `DayColours` onto `LockoutSemantics.categoryRamp` inside `day_block.dart` and restyle `SectionHeading`, `SubItemRow` and `AddLink` to theme reads. `day_colours_test.dart` keeps its uniqueness assertions, retargeted at the ramp.

- [ ] **Step 4: Analyze and run everything**

Run: `C:\src\flutter\bin\flutter.bat analyze`
Expected: zero errors, zero warnings.

Run: `C:\src\flutter\bin\flutter.bat test --concurrency=1`
Expected: every test passes. Record the final count; it must be at least the 91 baseline plus the new suites.

- [ ] **Step 5: Build the APK and report its size**

Run: `C:\src\flutter\bin\flutter.bat build apk --release`
Expected: build succeeds. Record the output `.apk` size and compare it to `lockout-c0e0509-release.apk` in the repo root, so the font-bundling cost is a number rather than a guess.

- [ ] **Step 6: Device QA**

Follow the pattern in `.spine/progress.md`: install on the `lockout_qa` emulator (Android 16 / API 36, 1080x2400, density 420) and drive every changed flow — nav between all five tabs, Workout featured day plus expanding the week, starting and finishing a session, the Progress segmented control, the food picker sheet with the keyboard up, and the theme picker including the dynamic option. Check specifically that no pushed route or sheet runs under the system navigation bar, which is the regression `b42586d` fixed.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(theme): delete the Jinatra layer

A test now fails if any Jinatra symbol, AppPalette reference, or hardcoded
Color constant reappears outside lib/theme, so the migration cannot rot back
one widget at a time."
```

---

## Coverage check against the spec

| Spec section | Task |
|---|---|
| 5.1 Colour, authored schemes, semantics extension | 2 |
| 5.2 Dynamic / Material You | 4, 14 |
| 5.3 Typography, bundled fonts | 1, 3 |
| 5.4 Shape, elevation, spacing, motion | 3 |
| 5.5 Expressive within SDK limits | 3, 5, 13 |
| 6 Navigation restructure | 5, 6, 7 |
| 7.1 Home | 9 |
| 7.2 Live session, leg-safety notice | 10 |
| 7.3 Workout featured day + collapsible week | 11 |
| 7.4 Progress | 5, 12 |
| 7.5 Food | 13 |
| 7.6 Profile | 6, 14 |
| 8 Component migration map | 8, 11, 15 |
| 10 Testing, device QA | every task; 15 for the sweep |
