import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/screens/profile_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/theme/theme_controller.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Drives a bounded number of timed frames rather than `pumpAndSettle`.
///
/// `CircularProgressIndicator`'s indeterminate animation repeats forever, so
/// `pumpAndSettle` never terminates while one is on screen. This pumps
/// enough (fast, real) sqflite reads' worth of frames to resolve instead.
/// Shared by `today_tab_test.dart` and `routines_tab_test.dart` — both drive
/// the same in-memory-DB seam and previously duplicated this verbatim.
Future<void> settle(WidgetTester tester, {int maxPumps = 20}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Wipes every backup table and restores the same seed rows
/// `DatabaseService._createDB` writes on a fresh install.
///
/// The serial test runner shares one sqflite file across every suite, so a
/// `setUp` that only deletes rows leaves `user_settings` empty for whatever
/// suite runs next — or, worse, lets a value one test saved (e.g. a
/// `calorie_target` override) leak into a suite that never touched it.
/// Reseeding after every wipe keeps each test's starting state identical to
/// a fresh install.
Future<void> wipeDatabaseAndReseed(DatabaseService db) async {
  final database = await db.database;
  // `database_service_test.dart` installs an aborting trigger on `set_logs`
  // to make a half-written session write observable. It drops it in a
  // teardown and now runs against an in-memory database, so it can no longer
  // leave that DDL in the shared database file — but a checkout from before
  // the in-memory move, killed between `CREATE TRIGGER` and its teardown
  // (Ctrl-C, a harness timeout), can still be carrying one. There it aborts
  // the `set_logs` delete below and takes ~30 tests across several suites
  // down with a signature that points nowhere near the cause, and nothing
  // else ever removes it. Dropping it here clears it from the shared file
  // the first time any suite that both routes through this helper and uses
  // that file runs — `goal_service_test.dart` does, on every run — so a
  // poisoned checkout needs no manual SQL to recover. A no-op otherwise.
  await database.execute('DROP TRIGGER IF EXISTS test_fail_set_logs');
  for (final table in DatabaseService.backupTables) {
    await database.delete(table);
  }
  await db.saveSetting('unit_weight', 'kg');
  await db.saveSetting('unit_length', 'cm');
  await db.saveSetting('height_cm', '175.0');
  await db.saveSetting(
    'calorie_target',
    '${DatabaseService.defaultCalorieTarget}',
  );
  await db.saveSetting('food_tab_enabled', 'true');
  await db.saveSetting('rest_timer_default', '60');
  await db.saveSetting('height_unit', 'cm');
  await db.saveSetting('active_routine_id', '');
}

/// [source] with every comment blanked out, character for character, so an
/// offset into the result still maps to the same line of the original.
///
/// A line-by-line filter cannot do this job: it misses the `double\n
/// .tryParse(` shape `dart format` produces from a long enough expression,
/// and it flags `/* prose */` it has no way to recognise as a comment.
///
/// String literals are skipped rather than blanked, so text *about* the
/// hazard in a message still reads as text; interpolation holding its own
/// quotes (`'${map['k']}'`) would end the skip early, which errs toward
/// scanning more of the file as code rather than less.
String blankComments(String source) {
  final out = source.split('');
  var i = 0;

  void blank(int at) {
    if (source[at] != '\n') out[at] = ' ';
  }

  while (i < source.length) {
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        blank(i++);
      }
    } else if (source.startsWith('/*', i)) {
      // Dart's block comments nest.
      var depth = 0;
      while (i < source.length) {
        if (source.startsWith('/*', i)) {
          depth++;
          blank(i++);
          blank(i++);
        } else if (source.startsWith('*/', i)) {
          depth--;
          blank(i++);
          blank(i++);
          if (depth == 0) break;
        } else {
          blank(i++);
        }
      }
    } else if (source[i] == "'" || source[i] == '"') {
      i = _endOfStringLiteral(source, i);
    } else {
      i++;
    }
  }
  return out.join();
}

/// The offset just past the literal opening at [start].
int _endOfStringLiteral(String source, int start) {
  final quote = source[start];
  final isRaw = start > 0 && (source[start - 1] == 'r' || source[start - 1] == 'R');
  final tripled = quote + quote + quote;
  final delimiter = source.startsWith(tripled, start) ? tripled : quote;
  var i = start + delimiter.length;
  while (i < source.length) {
    if (!isRaw && source[i] == r'\') {
      i += 2;
      continue;
    }
    if (source.startsWith(delimiter, i)) return i + delimiter.length;
    // An unterminated single-quoted literal ends at the newline; bail there
    // rather than swallowing the rest of the file.
    if (delimiter.length == 1 && source[i] == '\n') return i;
    i++;
  }
  return source.length;
}

/// The app's real `ThemeData`, for any test that pumps a widget which reads
/// `LockoutSemantics`.
///
/// `LockoutSemantics.of` asserts rather than falling back, so a bare
/// `MaterialApp()` fails loudly instead of silently painting framework
/// defaults. This is the one-liner that satisfies it.
ThemeData lockoutTestTheme([LockoutScheme scheme = LockoutScheme.graphite]) =>
    LockoutTheme.build(colors: scheme.colors, semantics: scheme.semantics);

/// Hosts `ProfileTab` the way `main.dart` hosts `MainScreen`: rebuilt
/// whenever `ThemeController` notifies, so a swatch selection actually
/// repaints instead of leaving the previous theme on screen. A bare
/// `MaterialApp(home: ProfileTab(...))` would build the theme once and never
/// again, which is exactly the hazard `main.dart`'s own `ListenableBuilder`
/// exists to avoid.
Widget hostedProfileTab({VoidCallback? onSettingsUpdated}) {
  return ListenableBuilder(
    listenable: ThemeController.instance,
    builder: (_, _) => MaterialApp(
      theme: ThemeController.instance.lightTheme,
      darkTheme: ThemeController.instance.darkTheme,
      themeMode: ThemeController.instance.themeMode,
      home: ProfileTab(onSettingsUpdated: onSettingsUpdated ?? () {}),
    ),
  );
}

/// A `WebViewPlatform` for `exercise_video_screen_test.dart`.
///
/// `flutter test` registers no real webview platform, so a bare
/// `WebViewController()` throws — `PlatformWebViewController`'s factory
/// asserts `WebViewPlatform.instance != null`. That gap is why
/// `ExerciseVideoScreen` shipped with zero widget-level coverage, and why
/// its `initState`-reads-`Theme.of(context)` regression went uncaught: with
/// no way to pump the screen, there was no way to run it at all. Setting
/// `WebViewPlatform.instance = FakeWebViewPlatform()` (once, e.g. in
/// `setUp`) closes that gap without touching the real controller/webview
/// wiring `ExerciseVideoScreen` owns.
///
/// [controllers] records every `FakeWebViewController` created, in creation
/// order, so a test can reach the one backing the screen it pumped and
/// drive its navigation delegate directly — `onProgress`, `onPageFinished`,
/// `onWebResourceError` — the same events a real platform would deliver.
class FakeWebViewPlatform extends WebViewPlatform {
  final List<FakeWebViewController> controllers = [];

  /// The controller for the most recently constructed `WebViewController`.
  /// Every test in this suite pumps exactly one webview at a time.
  FakeWebViewController get lastController => controllers.last;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      FakeWebViewWidget(params);
}

/// Records what `ExerciseVideoScreen` tells its `WebViewController` instead
/// of forwarding any of it to a real browser engine.
class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  FakeNavigationDelegate? navigationDelegate;
  final List<Uri> loadedUris = [];

  /// Every colour handed to [setBackgroundColor], in call order — mirrors
  /// [loadedUris] so a test can pin that the call still happens at all, not
  /// just that it is absent from `initState`.
  final List<Color> backgroundColors = [];

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {
    backgroundColors.add(color);
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigationDelegate = handler as FakeNavigationDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedUris.add(params.uri);
  }
}

/// Captures the callbacks `NavigationDelegate` registers so a test can
/// invoke them directly, simulating the progress/finished/error events
/// that drive `ExerciseVideoScreen`'s `_progress`/`_failed` state machine.
class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  ProgressCallback? onProgress;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {
    this.onProgress = onProgress;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    this.onWebResourceError = onWebResourceError;
  }
}

/// Stands in for the platform's real webview surface: `flutter test` has no
/// browser engine to paint, so this just needs to exist as a
/// `WebViewWidget` in the tree.
class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
