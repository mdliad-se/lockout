import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/meal_section.dart';
import 'package:lockout/widgets/progress_hero.dart';

FoodEntry _entry(String name, int kcal, String slot) => FoodEntry(
      id: name,
      dateStr: '2026-09-09',
      mealSlot: slot,
      name: name,
      kcal: kcal,
      proteinG: 10.0,
      carbG: 20.0,
      fatG: 5.0,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  group('mealSubtotalKcal', () {
    test('sums the entries', () {
      expect(
        mealSubtotalKcal([
          _entry('Paratha', 354, 'Breakfast'),
          _entry('Cheese Omelette', 225, 'Breakfast'),
        ]),
        579,
      );
    });

    test('an empty meal is zero', () {
      expect(mealSubtotalKcal(const []), 0);
    });
  });

  group('ProgressHero', () {
    testWidgets('renders its text and clamps an over-target progress',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProgressHero(
            eyebrow: 'TODAY',
            title: '1240 / 1850 KCAL',
            subtitle: '610 LEFT',
            progress: 1.8,
            background: Colors.orange,
          ),
        ),
      ));

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('1240 / 1850 KCAL'), findsOneWidget);
      expect(find.text('610 LEFT'), findsOneWidget);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 1.0);
    });

    testWidgets('a negative progress clamps to zero', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProgressHero(
            eyebrow: 'TODAY',
            title: '0 / 1850 KCAL',
            subtitle: '1850 LEFT',
            progress: -3.0,
            background: Colors.orange,
          ),
        ),
      ));

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.0);
    });
  });

  group('MealSection', () {
    testWidgets('shows the title, subtotal and every entry', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Breakfast',
            entries: [
              _entry('Paratha', 354, 'Breakfast'),
              _entry('Cheese Omelette', 225, 'Breakfast'),
            ],
            onDelete: (_) {},
          ),
        ),
      ));

      expect(find.text('BREAKFAST'), findsOneWidget);
      expect(find.text('579 kcal'), findsOneWidget);
      expect(find.text('Paratha'), findsOneWidget);
      expect(find.text('Cheese Omelette'), findsOneWidget);
    });

    testWidgets('an empty meal renders nothing at all', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Snacks',
            entries: const [],
            onDelete: (_) {},
          ),
        ),
      ));

      expect(find.text('SNACKS'), findsNothing);
    });

    testWidgets('deleting an entry reports it', (tester) async {
      FoodEntry? deleted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Lunch',
            entries: [_entry('Dal Bhat', 374, 'Lunch')],
            onDelete: (e) => deleted = e,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.close));
      expect(deleted?.name, 'Dal Bhat');
    });
  });
}
