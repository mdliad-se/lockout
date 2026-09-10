import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/food_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';
import 'package:lockout/widgets/meal_section.dart';
import 'package:lockout/widgets/progress_hero.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';

import 'test_helpers.dart';

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
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
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
      // Q4: an entry row carries its own unit, same as v1's
      // "'${food.kcal} kcal'" — a bare integer next to "P 10 C 20 F 5" is
      // ambiguous about what it is measuring.
      expect(find.text('354 kcal'), findsOneWidget);
      expect(find.text('225 kcal'), findsOneWidget);
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

    // C1: the old row used a ~40x40 `IconButton`; the rewrite shrank the
    // affordance to a bare 16x16 `Icon` and only made it register taps
    // everywhere within that 16x16 box (`HitTestBehavior.opaque` does not
    // enlarge the box it is applied to). `tester.tap` hits the widget's
    // centre regardless of its size, so the test above cannot catch a
    // shrunk hit target — this test measures the actual tappable area
    // instead, against a 36dp floor (16dp icon + 10dp padding each side).
    testWidgets('the delete affordance has at least a 36dp tappable area',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Lunch',
            entries: [_entry('Dal Bhat', 374, 'Lunch')],
            onDelete: (_) {},
          ),
        ),
      ));

      final detector = find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(GestureDetector),
      );
      expect(detector, findsOneWidget);
      final size = tester.getSize(detector);
      expect(size.width, greaterThanOrEqualTo(36));
      expect(size.height, greaterThanOrEqualTo(36));
    });

    // Q1: macro rounding must not manufacture precision in either
    // direction — 0.4g logged protein must not render as a measured zero,
    // and an exact whole number must not sprout a fake ".0".
    testWidgets('macros keep one decimal place instead of rounding to a '
        'false zero', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: 'Snacks',
            entries: [
              FoodEntry(
                id: 'partial',
                dateStr: '2026-09-09',
                mealSlot: 'Snacks',
                name: 'Half a Banana',
                kcal: 45,
                proteinG: 0.4,
                carbG: 12.6,
                fatG: 0.0,
              ),
            ],
            onDelete: (_) {},
          ),
        ),
      ));

      expect(find.text('P 0.4  C 12.6  F 0'), findsOneWidget);
    });
  });

  group('FoodTab', () {
    testWidgets('empty state: shows guidance when nothing is logged today',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FoodTab()));
      await settle(tester);

      expect(find.textContaining('NO FOOD LOGGED TODAY'), findsOneWidget);
      // Every meal slot still gets a `MealSection` instance (the empty-list
      // shrink is internal to each one), so the guidance text plus the
      // absence of any delete affordance is what proves nothing rendered.
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets(
        'hero wiring: under target uses the accent background and the '
        'LEFT subtitle', (tester) async {
      final db = DatabaseService.instance;
      final today = DateTime.now().toIso8601String().split('T').first;
      await db.insertFoodLog(FoodEntry(
        id: 'f1',
        dateStr: today,
        mealSlot: 'Breakfast',
        name: 'Oats',
        kcal: 800,
      ).toMap());

      await tester.pumpWidget(const MaterialApp(home: FoodTab()));
      await settle(tester);

      final hero = tester.widget<ProgressHero>(find.byType(ProgressHero));
      // Default seeded calorie_target is DatabaseService.defaultCalorieTarget
      // (2200), resolved through GoalService.snapshot() — no profile is
      // configured in a freshly-wiped/reseeded DB, so no nutrition plan
      // exists to override it.
      expect(hero.progress, closeTo(800 / 2200, 0.0001));
      expect(hero.background, equals(JinatraTokens.accentAt(0)));
      expect(find.textContaining('LEFT'), findsOneWidget);
    });

    testWidgets(
        'Ruling E: an over-budget day paints the hero with the signal '
        'colour and shows OVER, not just the accent every day gets',
        (tester) async {
      final db = DatabaseService.instance;
      final today = DateTime.now().toIso8601String().split('T').first;
      await db.insertFoodLog(FoodEntry(
        id: 'f1',
        dateStr: today,
        mealSlot: 'Dinner',
        name: 'Feast',
        kcal: 2500,
      ).toMap());

      await tester.pumpWidget(const MaterialApp(home: FoodTab()));
      await settle(tester);

      final hero = tester.widget<ProgressHero>(find.byType(ProgressHero));
      expect(hero.background, equals(JinatraTokens.signal));
      expect(find.textContaining('OVER'), findsOneWidget);
    });

    testWidgets(
        'an entry whose meal_slot is not one of the four named slots lands '
        'in the Other section, not silently dropped', (tester) async {
      final db = DatabaseService.instance;
      final today = DateTime.now().toIso8601String().split('T').first;
      await db.insertFoodLog(FoodEntry(
        id: 'f1',
        dateStr: today,
        mealSlot: 'Midnight',
        name: 'Cold Pizza',
        kcal: 300,
      ).toMap());

      await tester.pumpWidget(const MaterialApp(home: FoodTab()));
      await settle(tester);

      expect(find.text('OTHER'), findsOneWidget);
      expect(find.text('Cold Pizza'), findsOneWidget);
    });

    testWidgets(
        'the macro StatTiles keep one decimal place instead of rounding a '
        'small logged amount to zero', (tester) async {
      final db = DatabaseService.instance;
      final today = DateTime.now().toIso8601String().split('T').first;
      await db.insertFoodLog(FoodEntry(
        id: 'f1',
        dateStr: today,
        mealSlot: 'Breakfast',
        name: 'Sliver of cheese',
        kcal: 10,
        proteinG: 0.4,
        carbG: 0.0,
        fatG: 0.0,
      ).toMap());

      await tester.pumpWidget(const MaterialApp(home: FoodTab()));
      await settle(tester);

      expect(find.text('0.4 g'), findsOneWidget);
    });

    testWidgets('the LOG FOOD button label has no doubled plus', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FoodTab()));
      await settle(tester);

      expect(find.text('LOG FOOD'), findsOneWidget);
      expect(find.text('+ LOG FOOD'), findsNothing);
    });
  });

  // These model the shape of `routines_tab_test.dart`'s sheet regression
  // tests — Task 8 shipped a Critical twice in exactly this area (a form's
  // controllers built inside `showJinatraSheet`'s re-invoked builder, then
  // a second wave disposed them in a `finally` before the sheet's exit
  // animation finished). Task 9 converted FOOD's confirm sheet the same
  // way `routines_tab.dart` was already fixed, but shipped with no
  // regression lock of its own — nothing here stops a future refactor from
  // reintroducing either failure mode and still going green.
  group('_LogMealForm sheet regressions', () {
    /// Drives the real path to the form under test: the LOG FOOD button
    /// opens the catalog picker first (Task 5), and only a *custom* entry
    /// (typed name not in the catalog) skips the intermediate
    /// serving-size sheet and lands directly on `_LogMealForm` — the
    /// screen's only other path (an existing dish) goes through one more
    /// sheet this suite has no reason to also drive.
    Future<void> openLogForm(WidgetTester tester, String customName) async {
      await tester.pumpWidget(const MaterialApp(home: FoodTab()));
      await settle(tester);

      await tester.tap(find.text('LOG FOOD'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
            TextField, 'Search dish, cuisine or ingredient...'),
        customName,
      );
      await tester.pump();

      await tester.tap(find.textContaining('ADD CUSTOM'));
      await tester.pumpAndSettle();

      expect(find.text('LOG MEAL ITEM'), findsOneWidget);
    }

    testWidgets(
        'a sheet drag that does not dismiss does not clear a typed field',
        (tester) async {
      await openLogForm(tester, 'Zzz Custom Test Dish');

      const typed = '555';
      await tester.enterText(find.byType(TextField).at(1), typed);
      await tester.pump();
      expect(find.text(typed), findsOneWidget);

      // Drag from the sheet's title bar, same as routines_tab_test.dart —
      // the body sits inside SheetScaffold's own SingleChildScrollView,
      // which wins the vertical-drag gesture arena and just scrolls. A
      // modest drag from the title bar is a genuine candidate for the
      // modal's own dismiss-drag detector without actually dismissing it.
      await tester.drag(find.text('LOG MEAL ITEM'), const Offset(0, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('LOG MEAL ITEM'), findsOneWidget,
          reason: 'the small drag must not have dismissed the sheet');
      expect(find.text(typed), findsOneWidget,
          reason: 'the typed kcal value must survive a non-dismissing drag');
    });

    testWidgets('typing into a field then closing via the SheetScaffold X '
        'does not throw', (tester) async {
      await openLogForm(tester, 'Zzz Another Custom Dish');

      await tester.enterText(find.byType(TextField).at(1), '250');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      // Past the ~200ms exit animation the bottom-sheet route runs before
      // actually removing the sheet (and its controllers) from the tree.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(find.byType(SheetScaffold), findsNothing);
    });

    testWidgets('SAVE ENTRY inserts the entry and pops the sheet',
        (tester) async {
      await openLogForm(tester, 'Zzz Saved Custom Dish');

      await tester.enterText(find.byType(TextField).at(1), '250');
      await tester.pump();

      await tester.tap(find.text('SAVE ENTRY'));
      await tester.pumpAndSettle();

      expect(find.byType(SheetScaffold), findsNothing);
      expect(find.text('Zzz Saved Custom Dish'), findsOneWidget);
      // The section's subtotal and this lone entry's own row both read
      // "250 kcal" — proof the kcal field's typed text was parsed and
      // actually persisted, not just that some row exists.
      expect(find.text('250 kcal'), findsNWidgets(2));
    });
  });
}
