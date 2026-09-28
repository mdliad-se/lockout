import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/home_hub.dart';

import 'test_helpers.dart';

// What this file covers, and what it does not:
//
//  * The BottomNav groups moved to bottom_nav_test.dart when the bar became a
//    framework NavigationBar.
//  * Every assertion about WHAT the hub says — the weight card, the nutrition
//    bars, the ordering, the null/prompt cases — moved to
//    home_composition_test.dart when Home was rebuilt around those cards.
//
// What is left here is the surface contract: the hub paints on themed cards,
// takes every colour from the theme, and keeps its touch targets.

ThemeData _theme([LockoutScheme scheme = LockoutScheme.graphite]) =>
    LockoutTheme.build(colors: scheme.colors, semantics: scheme.semantics);

Widget _host(Widget child, {LockoutScheme scheme = LockoutScheme.graphite}) =>
    MaterialApp(
      theme: _theme(scheme),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

HomeHub _hub({List<ActionItem> actions = const []}) => HomeHub(
      eyebrow: 'TODAY · MON',
      title: 'Legs',
      subtitle: '4 exercises · 12 sets',
      heroColor: LockoutScheme.graphite.semantics.categoryAt(0),
      heroActions: const [],
      summary: const HomeHubSummary(
        kcalEaten: 1240,
        kcalTarget: 1850,
        weightKg: 72.5,
        weightDeltaKg: -0.4,
        burnedTodayKcal: 388.0,
        targetWeightKg: 68.0,
        proteinEatenG: 96,
        proteinTargetG: 150,
        weightSeries: [74.0, 73.2, 72.5],
      ),
      actions: actions,
    );

List<ActionItem> _eightActions() => List.generate(
      8,
      (i) => ActionItem(
        label: 'A$i',
        icon: Icons.circle,
        color: LockoutScheme.graphite.semantics.categoryAt(i),
        onTap: () {},
      ),
    );

void main() {
  testWidgets('the hub leads with one hero and renders its action tiles',
      (tester) async {
    await tester.pumpWidget(_host(_hub(actions: _eightActions())));
    await tester.pump();

    expect(find.byType(HeroCard), findsOneWidget);
    expect(find.byType(ActionTile), findsNWidgets(8));
    expect(find.text('Legs'), findsOneWidget);
  });

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
      expect(decoration.border, isNull, reason: 'hard borders are retired');
      for (final shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
        expect(
          shadow.blurRadius,
          greaterThan(0),
          reason: 'zero-blur hard shadows are retired',
        );
      }
    }
  });

  testWidgets('every semantic colour follows the active scheme',
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
    await tester.pumpWidget(_host(_hub(actions: _eightActions())));
    await tester.pump();

    for (final tile in find.byType(ActionTile).evaluate()) {
      final size = tester.getSize(find.byWidget(tile.widget));
      expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
      expect(size.width, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
    }
  });

  testWidgets('labels are sentence case outside metadata', (tester) async {
    await tester.pumpWidget(_host(_hub()));
    await tester.pump();

    for (final label in const ['Calories', 'Protein', 'Bodyweight']) {
      expect(find.text(label), findsOneWidget);
      expect(find.text(label.toUpperCase()), findsNothing);
    }
  });
}
