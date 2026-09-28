import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/home_hub.dart';
import 'package:lockout/widgets/nutrition_bars.dart';
import 'package:lockout/widgets/sparkline.dart';
import 'package:lockout/widgets/weight_card.dart';

import 'test_helpers.dart';

Widget _host(Widget child) => MaterialApp(
      theme: lockoutTestTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

HomeHub _hub({
  HomeHubSummary? summary,
  List<ActionItem> actions = const [],
  bool foodTabEnabled = true,
}) {
  return HomeHub(
    eyebrow: 'TODAY · MON',
    title: 'Legs',
    subtitle: '4 exercises · 12 sets',
    heroColor: LockoutScheme.graphite.semantics.categoryAt(0),
    heroActions: const [],
    foodTabEnabled: foodTabEnabled,
    summary: summary ??
        const HomeHubSummary(
          kcalEaten: 1240,
          kcalTarget: 1850,
          weightKg: 78.4,
          weightDeltaKg: -0.4,
          burnedTodayKcal: 388.0,
          targetWeightKg: 72.0,
          proteinEatenG: 96.5,
          proteinTargetG: 150,
          weightSeries: [80.0, 79.6, 79.1, 78.8, 78.4],
        ),
    actions: actions,
  );
}

void main() {
  group('weight card', () {
    testWidgets('leads with the current weight and states what is left',
        (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      expect(find.byType(WeightCard), findsOneWidget);
      expect(find.text('78.4'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      // The figure the user acts on is the gap, not the target.
      expect(find.textContaining('6.4 kg to go'), findsOneWidget);
      expect(find.textContaining('72.0'), findsOneWidget);
    });

    testWidgets('the current weight is the one display-scale number',
        (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      final context = tester.element(find.byType(WeightCard));
      final display = Theme.of(context).textTheme.displaySmall!.fontSize!;
      final big = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.style?.fontSize ?? 0) >= display)
          .toList();

      expect(big.length, 1);
      expect(big.single.data, '78.4');
    });

    testWidgets('draws the trend when there is a series', (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('one weigh-in draws no trend and says so', (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 0,
          kcalTarget: 1850,
          weightKg: 78.4,
          weightDeltaKg: null,
          burnedTodayKcal: null,
          targetWeightKg: 72.0,
          proteinEatenG: 0,
          proteinTargetG: 150,
          weightSeries: [78.4],
        ),
      )));
      await tester.pump();

      expect(find.byType(Sparkline), findsNothing);
      expect(find.textContaining('Log another weight'), findsOneWidget);
    });

    testWidgets('no weight on record prompts instead of showing a number',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 0,
          kcalTarget: 1850,
          weightKg: null,
          weightDeltaKg: null,
          burnedTodayKcal: null,
          targetWeightKg: null,
          proteinEatenG: 0,
          proteinTargetG: null,
          weightSeries: [],
        ),
      )));
      await tester.pump();

      expect(find.text('Log a weight'), findsOneWidget);
      expect(find.byType(Sparkline), findsNothing);
    });

    testWidgets('no goal set states the weight without inventing a gap',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 0,
          kcalTarget: 1850,
          weightKg: 78.4,
          weightDeltaKg: -0.2,
          burnedTodayKcal: null,
          targetWeightKg: null,
          proteinEatenG: 0,
          proteinTargetG: null,
          weightSeries: [79.0, 78.4],
        ),
      )));
      await tester.pump();

      expect(find.text('78.4'), findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
      expect(find.textContaining('Set a goal'), findsOneWidget);
    });
  });

  group('nutrition bars', () {
    testWidgets('calories and protein each read eaten, target and left',
        (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      expect(find.byType(NutritionBars), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('1240 / 1850'), findsOneWidget);
      expect(find.text('610 left'), findsOneWidget);
      expect(find.text('97 / 150 g'), findsOneWidget);
      expect(find.text('53 g left'), findsOneWidget);
    });

    testWidgets('going over target says over, never a negative left',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 2000,
          kcalTarget: 1850,
          weightKg: 78.4,
          weightDeltaKg: null,
          burnedTodayKcal: null,
          targetWeightKg: 72.0,
          proteinEatenG: 160,
          proteinTargetG: 150,
          weightSeries: [78.4, 78.2],
        ),
      )));
      await tester.pump();

      expect(find.text('150 over'), findsOneWidget);
      expect(find.text('10 g over'), findsOneWidget);
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('a bar never overfills its track', (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 5000,
          kcalTarget: 1850,
          weightKg: null,
          weightDeltaKg: null,
          burnedTodayKcal: null,
          targetWeightKg: null,
          proteinEatenG: 400,
          proteinTargetG: 150,
          weightSeries: [],
        ),
      )));
      await tester.pump();

      for (final bar in tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))) {
        expect(bar.value, lessThanOrEqualTo(1.0));
        expect(bar.value, greaterThanOrEqualTo(0.0));
      }
    });

    testWidgets('the whole nutrition block goes when Food is disabled',
        (tester) async {
      await tester.pumpWidget(_host(_hub(foodTabEnabled: false)));
      await tester.pump();

      expect(find.byType(NutritionBars), findsNothing);
    });

    testWidgets('no protein target shows the intake without a fake goal',
        (tester) async {
      await tester.pumpWidget(_host(_hub(
        summary: const HomeHubSummary(
          kcalEaten: 100,
          kcalTarget: 1850,
          weightKg: null,
          weightDeltaKg: null,
          burnedTodayKcal: null,
          targetWeightKg: null,
          proteinEatenG: 42,
          proteinTargetG: null,
          weightSeries: [],
        ),
      )));
      await tester.pump();

      expect(find.text('42 g'), findsOneWidget);
      expect(find.textContaining('/ 0'), findsNothing);
    });
  });

  group('composition', () {
    testWidgets('home leads with the day, then weight, then nutrition',
        (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      final dayY = tester.getTopLeft(find.text('Legs')).dy;
      final weightY = tester.getTopLeft(find.byType(WeightCard)).dy;
      final foodY = tester.getTopLeft(find.byType(NutritionBars)).dy;

      expect(dayY, lessThan(weightY));
      expect(weightY, lessThan(foodY));
    });

    testWidgets('the retired calm rows are gone', (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      // Their content moved into the weight card and the nutrition bars;
      // three identical navigable rows said less than either. "Bodyweight"
      // still appears — as the weight card's own label, which is the point.
      expect(find.byType(CalmRow), findsNothing);
      expect(find.text('Burned today'), findsNothing);
      expect(find.text('Log a weight'), findsNothing);
    });

    testWidgets('burn is stated on the day card, not as its own row',
        (tester) async {
      await tester.pumpWidget(_host(_hub()));
      await tester.pump();

      expect(find.textContaining('~388 kcal'), findsOneWidget);
    });
  });
}
