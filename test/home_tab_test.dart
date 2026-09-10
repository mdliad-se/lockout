import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/bottom_nav.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/home_hub.dart';

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
