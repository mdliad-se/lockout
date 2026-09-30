import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/bottom_nav.dart';

ThemeData _theme() => LockoutTheme.build(
      colors: LockoutScheme.graphite.colors,
      semantics: LockoutScheme.graphite.semantics,
    );

Widget _host({
  bool foodTabEnabled = true,
  int index = 0,
  ValueChanged<int>? onTap,
}) {
  return MaterialApp(
    theme: _theme(),
    home: Scaffold(
      bottomNavigationBar: BottomNav(
        currentIndex: index,
        foodTabEnabled: foodTabEnabled,
        onTap: onTap ?? (_) {},
      ),
    ),
  );
}

void main() {
  test('five tabs in the designed order', () {
    final tabs = BottomNav.visibleTabs();

    expect(
      tabs.map((t) => t.id).toList(),
      ['home', 'workout', 'progress', 'food', 'profile'],
    );
    expect(tabs.map((t) => t.tab).toList(), NavTab.values);
  });

  test('hiding food leaves four tabs and keeps the order', () {
    final tabs = BottomNav.visibleTabs(foodTabEnabled: false);

    expect(
      tabs.map((t) => t.id).toList(),
      ['home', 'workout', 'progress', 'profile'],
    );
  });

  test('every tab has a distinct selected and unselected icon', () {
    for (final tab in BottomNav.visibleTabs()) {
      expect(
        tab.icon,
        isNot(tab.selectedIcon),
        reason: '${tab.id}: selection must read without relying on colour '
            'alone',
      );
    }
  });

  test('labels are sentence case, not the old shouting', () {
    for (final tab in BottomNav.visibleTabs()) {
      expect(tab.label, isNot(tab.label.toUpperCase()), reason: tab.id);
    }
  });

  testWidgets('renders a Material NavigationBar, not a hand-rolled row',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in const [
      'Home',
      'Workout',
      'Progress',
      'Food',
      'Profile',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('food off renders four destinations', (tester) async {
    await tester.pumpWidget(_host(foodTabEnabled: false));
    await tester.pump();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Food'), findsNothing);
  });

  testWidgets('the bar is at least 80dp and reports its measured height',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump();

    final size = tester.getSize(find.byType(NavigationBar));
    expect(size.height, greaterThanOrEqualTo(LockoutTheme.navBarHeight));
    expect(
      BottomNav.lastRenderedHeight.value,
      greaterThanOrEqualTo(LockoutTheme.navBarHeight),
      reason: 'showUndoBanner positions itself against this',
    );
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(_host(onTap: (i) => tapped = i));
    await tester.pump();

    await tester.tap(find.text('Progress'));
    await tester.pump();

    expect(tapped, 2);
  });

  testWidgets('with food off, the index still matches the visible order',
      (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      _host(foodTabEnabled: false, onTap: (i) => tapped = i),
    );
    await tester.pump();

    await tester.tap(find.text('Profile'));
    await tester.pump();

    expect(
      tapped,
      3,
      reason: 'Profile is the fourth visible tab once Food is hidden',
    );
  });

  testWidgets('an out-of-range index clamps rather than throwing',
      (tester) async {
    await tester.pumpWidget(_host(foodTabEnabled: false, index: 4));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
