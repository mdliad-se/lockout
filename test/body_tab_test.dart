import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/body_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/goal_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';
import 'package:lockout/widgets/sparkline.dart';
import 'package:lockout/widgets/stat_tile.dart';

import 'test_helpers.dart';

Future<void> _insertLog(
  DatabaseService db, {
  required String id,
  required String dateStr,
  required double weightKg,
  double waistCm = 0.0,
}) async {
  await db.insertBodyLog(BodyEntry(
    id: id,
    dateStr: dateStr,
    weightKg: weightKg,
    waistCm: waistCm,
  ).toMap());
}

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

  group('sparklineNormalise', () {
    test('maps the range onto 0..1', () {
      expect(sparklineNormalise([70.0, 72.0, 74.0]), [0.0, 0.5, 1.0]);
    });

    test('a flat series sits in the middle rather than dividing by zero', () {
      expect(sparklineNormalise([72.0, 72.0, 72.0]), [0.5, 0.5, 0.5]);
    });

    test('a series too short to draw returns nothing', () {
      expect(sparklineNormalise([72.0]), isEmpty);
      expect(sparklineNormalise(const []), isEmpty);
    });

    test('a descending series normalises without reordering', () {
      expect(sparklineNormalise([74.0, 72.0, 70.0]), [1.0, 0.5, 0.0]);
    });

    test('a single outlier still normalises the rest against the full range',
        () {
      // Q3: an outlier must not be silently clipped out of the range — every
      // other point still lands correctly relative to a range the outlier
      // itself defines.
      expect(
        sparklineNormalise([72.0, 72.5, 73.0, 100.0]),
        [0.0, 0.017857142857142856, 0.03571428571428571, 1.0],
      );
    });
  });

  group('Sparkline', () {
    testWidgets('draws when it has data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Sparkline(
            values: const [70.0, 71.5, 71.0, 72.4],
            lineColor: Colors.black,
          ),
        ),
      ));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders an empty box rather than failing on one point',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Sparkline(values: const [70.0], lineColor: Colors.black),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  // BODY's ListView is long enough (hero, sparkline, stat grid, four
  // reference rows) that the default 800x600 test surface only realises the
  // rows near the top — `ListView`'s sliver children beyond the viewport +
  // cache extent are never built, so `find.text` on a row like GOAL
  // PROGRESS returns zero widgets even though scrolling to it on a real
  // device works fine. A tall surface keeps the whole screen realised
  // without every test having to scroll first.
  Future<void> pumpBody(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BodyTab()));
  }

  group('BodyTab', () {
    testWidgets('empty state: no data yet, no sparkline, zero entries',
        (tester) async {
      await pumpBody(tester);
      await settle(tester);

      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(hero.title, 'NO DATA YET');
      expect(hero.subtitle, 'LOG A SECOND WEIGHT TO SEE A TREND');
      expect(find.byType(Sparkline), findsNothing);

      final tiles = tester.widgetList<StatTile>(find.byType(StatTile));
      final byLabel = {for (final t in tiles) t.label: t.value};
      expect(byLabel['BMI'], '--');
      expect(byLabel['TARGET'], '--');
      expect(byLabel['ENTRIES'], '0');
    });

    testWidgets(
        'one entry: shows the weight but no delta and no sparkline yet',
        (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);

      await pumpBody(tester);
      await settle(tester);

      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(hero.title, '80.0 KG');
      expect(hero.subtitle, 'LOG A SECOND WEIGHT TO SEE A TREND');
      expect(find.byType(Sparkline), findsNothing);
    });

    testWidgets('a rising trend across two days shows a signed delta and '
        'a sparkline', (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);
      await _insertLog(db, id: 'b', dateStr: '2026-09-02', weightKg: 82.0);

      await pumpBody(tester);
      await settle(tester);

      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(hero.title, '82.0 KG');
      expect(hero.subtitle, '+2.0 KG SINCE LAST ENTRY');
      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('a falling trend does not get a plus sign', (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 82.0);
      await _insertLog(db, id: 'b', dateStr: '2026-09-02', weightKg: 80.0);

      await pumpBody(tester);
      await settle(tester);

      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(hero.subtitle, '-2.0 KG SINCE LAST ENTRY');
    });

    // Ambiguity resolution 2: two weigh-ins on the same calendar day are a
    // morning-vs-evening swing, not a day-over-day change, and must compare
    // against each other in insertion order (`getBodyLogs`'s
    // `rowid DESC` tiebreak) rather than an order that could invert the
    // sign.
    testWidgets(
        'two same-day entries compare in insertion order, not an '
        'accidentally inverted one', (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-05', weightKg: 80.0);
      await _insertLog(db, id: 'b', dateStr: '2026-09-05', weightKg: 79.0);

      await pumpBody(tester);
      await settle(tester);

      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      // The second insert (79.0) is the latest by rowid; the delta must be
      // 79.0 - 80.0, not the other way round.
      expect(hero.title, '79.0 KG');
      expect(hero.subtitle, '-1.0 KG SINCE LAST ENTRY');
    });

    testWidgets('the stat grid reflects a configured goal snapshot exactly',
        (tester) async {
      final db = DatabaseService.instance;
      await db.saveSetting('age', '30');
      await db.saveSetting('target_weight_kg', '75.0');
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);

      final snap = await GoalService.instance.snapshot();

      await pumpBody(tester);
      await settle(tester);

      final tiles = tester.widgetList<StatTile>(find.byType(StatTile));
      final byLabel = {for (final t in tiles) t.label: t.value};
      expect(byLabel['BMI'], snap.bmi!.toStringAsFixed(1));
      expect(byLabel['TARGET'], '75.0 kg');
      expect(byLabel['DAILY INTAKE'], '${snap.calorieTarget} kcal');
      expect(byLabel['ENTRIES'], '1');
    });

    testWidgets('every reference row is present, LOG HISTORY carries the '
        'entry count', (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);
      await _insertLog(db, id: 'b', dateStr: '2026-09-02', weightKg: 81.0);

      await pumpBody(tester);
      await settle(tester);

      expect(find.text('GOAL PROGRESS'), findsOneWidget);
      expect(find.text('RECOMMENDED PLAN'), findsOneWidget);
      expect(find.text('HOW THIS BMI IS CALCULATED'), findsOneWidget);
      final historyRow =
          tester.widget<CalmRow>(find.widgetWithText(CalmRow, 'LOG HISTORY'));
      expect(historyRow.value, '2');
    });

    testWidgets('tapping the BMI row opens a sheet that spells the '
        'calculation out', (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);

      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('HOW THIS BMI IS CALCULATED'));
      await tester.pumpAndSettle();

      expect(find.text('BMI'), findsWidgets);
      expect(find.textContaining('80.0 kg /'), findsOneWidget);
    });

    testWidgets(
        'tapping GOAL PROGRESS with no goal configured shows the prompt '
        'instead of crashing', (tester) async {
      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('GOAL PROGRESS'));
      await tester.pumpAndSettle();

      expect(find.text('NO GOAL SET'), findsOneWidget);
    });

    testWidgets(
        'logging a measurement through the hero sheet inserts it and the '
        'grid picks it up', (tester) async {
      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('+ LOG MEASUREMENT'));
      await tester.pumpAndSettle();
      expect(find.text('LOG BODY METRICS'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '77.5');
      await tester.pump();
      await tester.tap(find.text('SAVE MEASUREMENT'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.byType(SheetScaffold), findsNothing);
      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(hero.title, '77.5 KG');
      final tiles = tester.widgetList<StatTile>(find.byType(StatTile));
      final byLabel = {for (final t in tiles) t.label: t.value};
      expect(byLabel['ENTRIES'], '1');
    });

    // Regression lock for the disposable-controller lesson this branch paid
    // for twice already (see routines_tab.dart:807-827 / food_tab_test.dart).
    testWidgets(
        'a sheet drag that does not dismiss does not clear a typed weight',
        (tester) async {
      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('+ LOG MEASUREMENT'));
      await tester.pumpAndSettle();

      const typed = '68.2';
      await tester.enterText(find.byType(TextField).first, typed);
      await tester.pump();
      expect(find.text(typed), findsOneWidget);

      await tester.drag(find.text('LOG BODY METRICS'), const Offset(0, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('LOG BODY METRICS'), findsOneWidget,
          reason: 'the small drag must not have dismissed the sheet');
      expect(find.text(typed), findsOneWidget,
          reason: 'the typed weight must survive a non-dismissing drag');
    });

    testWidgets(
        'typing into the measurement sheet then closing via the X does not '
        'throw', (tester) async {
      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('+ LOG MEASUREMENT'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '68.2');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(find.byType(SheetScaffold), findsNothing);
    });

    testWidgets(
        'the LOG HISTORY delete affordance has at least a 40dp tappable '
        'area and removes the row live', (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);
      await _insertLog(db, id: 'b', dateStr: '2026-09-02', weightKg: 81.0);

      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('LOG HISTORY'));
      await tester.pumpAndSettle();

      // The delete glyph is deliberately not `Icons.close` in this sheet —
      // `SheetScaffold` already uses `Icons.close` for its own dismiss
      // button, and reusing it for "delete this row" inside the very sheet
      // that also uses it for "close this sheet" is exactly the kind of
      // ambiguity a hit-target test like this one is meant to catch.
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

      final detector = find
          .ancestor(
            of: find.byIcon(Icons.delete_outline).first,
            matching: find.byType(GestureDetector),
          )
          .first;
      final size = tester.getSize(detector);
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await settle(tester);

      // The row disappeared from the still-open sheet without needing to
      // close and reopen it.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close)); // SheetScaffold's dismiss
      await tester.pumpAndSettle();
      await settle(tester);

      final historyRow =
          tester.widget<CalmRow>(find.widgetWithText(CalmRow, 'LOG HISTORY'));
      expect(historyRow.value, '1');
    });
  });
}
