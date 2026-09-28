import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/main.dart';
import 'package:lockout/screens/main_screen.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/theme/theme_controller.dart';
import 'package:lockout/widgets/bottom_nav.dart';

import 'test_helpers.dart';

/// The only coverage `lib/main.dart` has.
///
/// `ThemeController` -> `ListenableBuilder` -> `MaterialApp` ->
/// `home: MainScreen()` is the single mechanism that makes the whole non-const
/// sweep worth anything: the
/// `// ignore: prefer_const_constructors_in_immutables` suppressions across
/// this codebase exist so that this chain can actually repaint the tree, and
/// nothing else pins the chain itself. Every other repaint test in the repo
/// pumps a screen directly under a bare `MaterialApp`, which bypasses
/// `LockoutApp` entirely — so deleting the `ListenableBuilder`, or putting
/// `const` back on `MainScreen` and its call site, would break nothing that
/// any other test could see.
///
/// `LockoutApp` itself stays a const-constructor exception: it builds no
/// theme-derived colour of its own, it only rebuilds what does.
void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
    ThemeController.instance.resetForTest();
    await ThemeController.instance.load();
  });

  // The shared serial runner reuses one process, so a selection left applied
  // here would follow every later suite into its own setUpAll.
  tearDown(() => ThemeController.instance.resetForTest());

  /// The surface `MainScreen` actually painted. Built by `MainScreen.build`,
  /// which is precisely the build that a canonicalised `const MainScreen()`
  /// would let Flutter skip.
  Color scaffoldFill(WidgetTester tester) {
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: find.byType(MainScreen), matching: find.byType(Scaffold)).first,
    );
    return scaffold.backgroundColor!;
  }

  /// The nav bar's resolved background — the other half of the chrome that
  /// `main.dart`'s comment says a skipped rebuild strands.
  Color navFill(WidgetTester tester) {
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final context = tester.element(find.byType(NavigationBar));
    return bar.backgroundColor ??
        Theme.of(context).navigationBarTheme.backgroundColor!;
  }

  testWidgets('the app boots on the saved theme', (tester) async {
    await tester.pumpWidget(const LockoutApp());
    await settle(tester);

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(scaffoldFill(tester), LockoutScheme.graphite.colors.surface);
  });

  testWidgets('the semantics extension reaches the widgets below MaterialApp',
      (tester) async {
    await tester.pumpWidget(const LockoutApp());
    await settle(tester);

    final context = tester.element(find.byType(BottomNav));
    expect(
      LockoutSemantics.of(context).categoryRamp,
      LockoutScheme.graphite.semantics.categoryRamp,
    );
  });

  testWidgets('selecting a theme repaints the tree LockoutApp builds',
      (tester) async {
    await tester.pumpWidget(const LockoutApp());
    await settle(tester);

    final before = scaffoldFill(tester);
    expect(before, LockoutScheme.graphite.colors.surface);
    final navBefore = navFill(tester);

    await ThemeController.instance.select('paper');
    // pumpAndSettle, not a single pump: MaterialApp wraps its theme in an
    // AnimatedTheme, so frame zero still samples the previous colours and a
    // one-frame pump would assert against the tween's starting value.
    await tester.pumpAndSettle();

    expect(
      scaffoldFill(tester),
      isNot(before),
      reason: 'MainScreen kept the previous theme after a change',
    );
    expect(scaffoldFill(tester), LockoutScheme.paper.colors.surface);
    expect(
      navFill(tester),
      isNot(navBefore),
      reason: 'the nav bar repaints along with the rest of the chrome',
    );
  });

  testWidgets('a theme chosen while another route is on top has repainted '
      'HOME by the time the user is back on it', (tester) async {
    // The harder case: a pushed route sits on top of MainScreen, so MainScreen
    // is still mounted but not on screen when the theme changes. Its rebuild
    // has to happen anyway, because popping back does not rebuild a route
    // Flutter thinks is unchanged.
    await tester.pumpWidget(const LockoutApp());
    await settle(tester);

    final navBefore = navFill(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('on top'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('on top'), findsOneWidget);

    await ThemeController.instance.select('indigo');
    await tester.pumpAndSettle();

    navigator.pop();
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.byType(MainScreen), findsOneWidget);
    expect(
      navFill(tester),
      isNot(navBefore),
      reason: 'BottomNav still carries the theme it was built with before the '
          'user changed it',
    );
    expect(scaffoldFill(tester), LockoutScheme.indigo.colors.surface);
  });

  testWidgets('a legacy palette key saved by the previous build still boots',
      (tester) async {
    await DatabaseService.instance.saveSetting('theme_key', 'carbon_lime');
    ThemeController.instance.resetForTest();
    await ThemeController.instance.load();

    await tester.pumpWidget(const LockoutApp());
    await settle(tester);

    expect(scaffoldFill(tester), LockoutScheme.graphite.colors.surface);
  });
}
