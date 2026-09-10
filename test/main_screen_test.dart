import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/screens/main_screen.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/bottom_nav.dart';

import 'test_helpers.dart';

/// Every tab shows a `CircularProgressIndicator` (indeterminate: its
/// `AnimationController` repeats forever) while its own data loads.
/// `pumpAndSettle` never terminates against an indeterminate animation — it
/// keeps pumping as long as a frame is scheduled, which a repeating
/// controller always does — so this drives frames with a bounded loop of
/// timed `pump()` calls instead, long enough for the real (fast) sqflite
/// reads behind each tab's loading state to resolve.
Future<void> _settle(WidgetTester tester, {int maxPumps = 20}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// `MainScreen._screens` now maps every `NavTab` to a screen through a Dart
/// 3 switch *expression*, which the compiler rejects if a case is missing —
/// the enum-keyed alternative to the runtime `StateError` default this
/// replaced. This test is the belt to that compile-time brace: it drives the
/// real widget end to end, tapping through every currently-visible tab in
/// both the food-enabled and food-disabled configurations, so a regression
/// (e.g. someone reintroducing a stringly-typed fallback) would still fail
/// here instead of only on a device.
void main() {
  setUpAll(() {
    // `testWidgets`' fake-async zone never lets a *file-backed* sqflite
    // database finish opening in this environment — confirmed by isolating
    // the call: the identical `openDatabase` resolves instantly under a
    // plain `test()` (every other DB-backed suite in this repo uses one),
    // and resolves instantly here too once given an in-memory path instead.
    // `databaseFactoryFfiNoIsolate` avoids a second, unrelated hang from the
    // default factory's background-isolate round trip inside that same zone.
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  testWidgets(
      'every visible tab (food enabled) resolves to a screen instead of '
      'throwing StateError', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await _settle(tester);

    for (final tab in BottomNav.visibleTabs(foodTabEnabled: true)) {
      // Scoped to BottomNav: the destination screen's own body can contain
      // the same label text (e.g. a "ROUTINES" section header), and
      // IndexedStack keeps every tab's widgets in the tree even when
      // Offstage, so an unscoped `find.text` becomes ambiguous once more
      // than one tab has been visited.
      await tester.tap(_navLabel(tab.label));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'every visible tab (food disabled) resolves to a screen instead of '
      'throwing StateError', (tester) async {
    await DatabaseService.instance
        .saveSetting('food_tab_enabled', 'false');

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await _settle(tester);

    final tabs = BottomNav.visibleTabs(foodTabEnabled: false);
    expect(tabs.map((t) => t.id), isNot(contains('food')));

    for (final tab in tabs) {
      await tester.tap(_navLabel(tab.label));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }
  });
}

/// The nav bar's copy of [label], not any other widget's — see the note
/// above the loop that uses this.
Finder _navLabel(String label) => find.descendant(
      of: find.byType(BottomNav),
      matching: find.text(label),
    );
