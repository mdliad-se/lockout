import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/main.dart';
import 'package:lockout/screens/main_screen.dart';
import 'package:lockout/screens/settings_screen.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/bottom_nav.dart';

import 'test_helpers.dart';

/// The only coverage `lib/main.dart` has.
///
/// `AppPalette.revision` -> `ValueListenableBuilder` -> `MaterialApp` ->
/// `home: MainScreen()` is the single mechanism that makes the whole
/// non-const sweep worth anything: thirty-one
/// `// ignore: prefer_const_constructors_in_immutables` suppressions across
/// three fix waves exist so that this chain can actually repaint the tree,
/// and nothing pinned the chain itself. Every other repaint test in the repo
/// pumps a screen directly under a bare `MaterialApp`, which bypasses
/// `LockoutApp` entirely — so deleting the `ValueListenableBuilder`, or
/// putting `const` back on `MainScreen` and its call site, broke nothing
/// that any test could see.
///
/// `LockoutApp` is one of the two documented const-constructor exceptions
/// (`Sparkline` is the other): it builds no palette-derived colour itself,
/// it only rebuilds what does.
void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
    AppPalette.apply(AppPalette.jinatraCream);
  });

  // The shared serial runner reuses one process, so a palette left applied
  // here would follow every later suite into its own setUpAll.
  tearDown(() => AppPalette.apply(AppPalette.paperPress));

  /// The fill `MainScreen`'s AppBar actually painted. Built by
  /// `MainScreen.build`, which is precisely the build that a canonicalised
  /// `const MainScreen()` would let Flutter skip.
  Color appBarFill(WidgetTester tester) {
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    return bar.backgroundColor!;
  }

  /// The fill of the nav bar's outer `Container` — the other half of the
  /// chrome `main.dart`'s comment says a skipped rebuild strands.
  Color navFill(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(BottomNav),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration as BoxDecoration).color!;
  }

  testWidgets('applying a palette repaints the tree LockoutApp builds',
      (tester) async {
    await tester.pumpWidget(const LockoutApp());
    await settle(tester);

    final before = appBarFill(tester);
    expect(before, AppPalette.jinatraCream.canvas);

    AppPalette.apply(AppPalette.carbonLime);
    await tester.pump();

    final after = appBarFill(tester);
    expect(after, isNot(before),
        reason: 'the AppBar kept the previous palette after a theme change');
    expect(after, AppPalette.carbonLime.canvas);
    expect(navFill(tester), AppPalette.carbonLime.canvas,
        reason: 'the nav bar repaints along with the rest of the chrome');
  });

  testWidgets('a theme chosen in Settings has repainted HOME by the time the '
      'user is back on it', (tester) async {
    // The harder route case: Settings is pushed on top of MainScreen, so
    // MainScreen is still mounted but not on screen when the palette
    // changes. Its rebuild has to happen anyway, because popping back does
    // not rebuild a route that Flutter thinks is unchanged.
    await tester.pumpWidget(const LockoutApp());
    await settle(tester);

    final navBefore = navFill(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.ensureVisible(find.text('CARBON LIME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CARBON LIME'));
    await settle(tester);
    expect(AppPalette.current.key, 'carbon_lime');

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(MainScreen), findsOneWidget);

    expect(navFill(tester), isNot(navBefore),
        reason: 'BottomNav still carries the palette it was built with '
            'before the user changed the theme');
    expect(navFill(tester), AppPalette.carbonLime.canvas);
    expect(appBarFill(tester), AppPalette.carbonLime.canvas);

    // Flush the toast timer Settings started, so no timer is pending when
    // the tree is torn down.
    await tester.pump(const Duration(seconds: 6));
  });
}
