import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/home_hub.dart';

// The BottomNav groups that used to live here moved to bottom_nav_test.dart
// when the bar became a framework NavigationBar: that suite covers tab order,
// the food-hidden order, tap indices in both configurations, icon pairs,
// measured height and index clamping, which is a superset of what was here.

ThemeData _theme([LockoutScheme scheme = LockoutScheme.graphite]) =>
    LockoutTheme.build(colors: scheme.colors, semantics: scheme.semantics);

Widget _host(Widget child, {LockoutScheme scheme = LockoutScheme.graphite}) =>
    MaterialApp(
      theme: _theme(scheme),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

HomeHub _hub({
  HomeHubSummary? summary,
  List<ActionItem> actions = const [],
  List<Widget> heroActions = const [],
  bool foodTabEnabled = true,
  VoidCallback? onOpenFood,
  VoidCallback? onOpenBody,
  VoidCallback? onOpenLog,
  String title = 'Legs',
  String? subtitle = '4 exercises · 12 sets',
}) {
  return HomeHub(
    eyebrow: 'TODAY · MON',
    title: title,
    subtitle: subtitle,
    heroColor: LockoutScheme.graphite.semantics.categoryAt(0),
    heroActions: heroActions,
    foodTabEnabled: foodTabEnabled,
    summary: summary ??
        const HomeHubSummary(
          kcalEaten: 1240,
          kcalTarget: 1850,
          weightKg: 72.5,
          weightDeltaKg: -0.4,
          burnedTodayKcal: 388.0,
        ),
    actions: actions,
    onOpenFood: onOpenFood,
    onOpenBody: onOpenBody,
    onOpenLog: onOpenLog,
  );
}

void main() {
  group('HomeHub', () {
    testWidgets('renders one hero, the calm rows and the action tiles',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        actions: List.generate(
          8,
          (i) => ActionItem(
            label: 'A$i',
            icon: Icons.circle,
            color: LockoutScheme.graphite.semantics.categoryAt(i),
            onTap: () {},
          ),
        ),
      )));
      await tester.pump();

      expect(find.byType(HeroCard), findsOneWidget);
      expect(find.byType(CalmRow), findsNWidgets(3));
      expect(find.byType(ActionTile), findsNWidgets(8));
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('1240 / 1850 kcal'), findsOneWidget);
      expect(find.text('72.5 kg  -0.4'), findsOneWidget);
      expect(find.text('~388 kcal'), findsOneWidget);
    });

    testWidgets('missing data shows a prompt rather than a fake number',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        title: 'Rest day',
        subtitle: null,
        summary: const HomeHubSummary(
          kcalEaten: 0,
          kcalTarget: null,
          weightKg: null,
          weightDeltaKg: null,
          burnedTodayKcal: null,
        ),
      )));
      await tester.pump();

      expect(find.text('Set a goal'), findsOneWidget);
      expect(find.text('Log a weight'), findsOneWidget);
      expect(find.text('No session yet'), findsOneWidget);
    });

    testWidgets('a known weight with no delta on record shows plain, no sign',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 0,
          kcalTarget: null,
          weightKg: 72.5,
          weightDeltaKg: null,
          burnedTodayKcal: null,
        ),
      )));
      await tester.pump();

      expect(find.text('72.5 kg'), findsOneWidget);
    });

    testWidgets('a positive delta renders with an explicit + sign',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 0,
          kcalTarget: null,
          weightKg: 72.5,
          weightDeltaKg: 0.4,
          burnedTodayKcal: null,
        ),
      )));
      await tester.pump();

      expect(find.text('72.5 kg  +0.4'), findsOneWidget);
    });

    testWidgets('tapping a CalmRow fires its onTap', (tester) async {
      var opened = '';
      await tester.pumpWidget(_host(_hub(
        onOpenFood: () => opened = 'food',
        onOpenBody: () => opened = 'body',
        onOpenLog: () => opened = 'log',
      )));
      await tester.pump();

      await tester.tap(find.text('Calories'));
      expect(opened, 'food');

      await tester.tap(find.text('Bodyweight'));
      expect(opened, 'body');

      await tester.tap(find.text('Burned today'));
      expect(opened, 'log');
    });

    testWidgets(
        'a session logged today with no burn estimate reads Estimate '
        'unavailable, not No session yet', (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 0,
          kcalTarget: null,
          weightKg: null,
          weightDeltaKg: null,
          // Non-null zero: a session WAS logged today, but no estimate could
          // be produced for it (no bodyweight on record).
          burnedTodayKcal: 0.0,
        ),
      )));
      await tester.pump();

      expect(find.text('Estimate unavailable'), findsOneWidget);
      expect(find.text('No session yet'), findsNothing);
    });

    testWidgets(
        'the Calories row is dropped entirely when the Food tab is disabled',
        (tester) async {
      await tester.pumpWidget(_host(_hub(foodTabEnabled: false)));
      await tester.pump();

      expect(find.text('Calories'), findsNothing);
      expect(find.byType(CalmRow), findsNWidgets(2));
    });
  });

  group('Material 3 surface', () {
    testWidgets('the hub paints on themed cards, not bordered containers',
        (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      expect(find.byType(Card), findsWidgets);

      // The neubrutalist signature was a 3px border plus a zero-blur shadow.
      // Neither may survive anywhere in the hub.
      for (final container in tester.widgetList<Container>(
        find.descendant(of: find.byType(HomeHub), matching: find.byType(Container)),
      )) {
        final decoration = container.decoration;
        if (decoration is! BoxDecoration) continue;
        expect(
          decoration.border,
          isNull,
          reason: 'hard borders are retired',
        );
        for (final shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
          expect(
            shadow.blurRadius,
            greaterThan(0),
            reason: 'zero-blur hard shadows are retired',
          );
        }
      }
    });

    testWidgets('labels are sentence case outside metadata', (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      for (final label in const ['Calories', 'Bodyweight', 'Burned today']) {
        expect(find.text(label), findsOneWidget);
        expect(find.text(label.toUpperCase()), findsNothing);
      }
    });

    testWidgets('every colour the hub paints comes from the theme',
        (tester) async {
      for (final scheme in LockoutScheme.all) {
        await tester.pumpWidget(_host(_hub(), scheme: scheme));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(HomeHub));
        expect(
          LockoutSemantics.of(context).categoryRamp,
          scheme.semantics.categoryRamp,
          reason: scheme.key,
        );
      }
    });

    testWidgets('every action tile clears the 48dp touch target',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        actions: List.generate(
          8,
          (i) => ActionItem(
            label: 'A$i',
            icon: Icons.circle,
            color: LockoutScheme.graphite.semantics.categoryAt(i),
            onTap: () {},
          ),
        ),
      )));
      await tester.pump();

      for (final tile in find.byType(ActionTile).evaluate()) {
        final size = tester.getSize(find.byWidget(tile.widget));
        expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
      }
    });
  });
}
