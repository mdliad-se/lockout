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
      // Finding 2: `_bodyLogs` is newest-first, so the production code
      // reverses it before handing it to `Sparkline` — deleting that
      // `.reversed` leaves every other assertion in this file green (they
      // only check `findsOneWidget`/`findsNothing`) while silently drawing
      // a weight GAIN as a downward line. Reading `.values` locks the
      // chronological (oldest-first) order the widget actually receives.
      final sparkline = tester.widget<Sparkline>(find.byType(Sparkline));
      expect(sparkline.values, [80.0, 82.0]);
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

      // The delete above queued an UNDO banner with a 5s auto-dismiss
      // Timer (see `showUndoBanner`). `flutter_test` runs inside a fake
      // clock, so that Timer is real and still pending at this point —
      // advancing past its duration lets it fire and cancel itself, rather
      // than leaving a Timer alive when the test ends.
      await tester.pump(const Duration(seconds: 6));
    });

    // Finding 3 / Ruling F: a single tap with no confirmation destroyed
    // logged history that cannot be reconstructed. This locks the undo
    // window: the delete happens immediately, but the exact row — same id,
    // same weight, same waist, same date — comes back on UNDO.
    testWidgets(
        'deleting a body log offers UNDO, which restores the exact row',
        (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(
          db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0, waistCm: 91.5);
      await _insertLog(db, id: 'b', dateStr: '2026-09-02', weightKg: 81.0);

      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('LOG HISTORY'));
      await tester.pumpAndSettle();

      // 'b' (2026-09-02) sorts first (newest-first), so 'a' is the second
      // delete affordance.
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pumpAndSettle();
      await settle(tester);

      final afterDelete = await db.getBodyLogs();
      expect(afterDelete.any((r) => r['id'] == 'a'), isFalse,
          reason: 'the row is deleted immediately, not just hidden');

      expect(find.text('UNDO'), findsOneWidget);
      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      await settle(tester);

      final restored = await db.getBodyLogs();
      final row = restored.firstWhere((r) => r['id'] == 'a');
      expect(row['weight_kg'], 80.0);
      expect(row['waist_cm'], 91.5);
      expect(row['date_str'], '2026-09-01');
      expect(restored.length, 2);
    });

    // The banner's whole reason to exist is Finding 1's failure mode: a
    // ScaffoldMessenger SnackBar shown from inside this sheet would render
    // behind it. This proves the undo affordance is not a descendant of the
    // sheet's own subtree by surviving the sheet closing entirely.
    testWidgets(
        'the UNDO banner survives the LOG HISTORY sheet closing, and undo '
        'still restores the row afterwards', (tester) async {
      final db = DatabaseService.instance;
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);
      await _insertLog(db, id: 'b', dateStr: '2026-09-02', weightKg: 81.0);

      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('LOG HISTORY'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close)); // SheetScaffold's dismiss
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.byType(SheetScaffold), findsNothing);
      expect(find.text('UNDO'), findsOneWidget,
          reason: 'undo must not have been a child of the closed sheet');

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      await settle(tester);

      final historyRow =
          tester.widget<CalmRow>(find.widgetWithText(CalmRow, 'LOG HISTORY'));
      expect(historyRow.value, '2');
    });

    // Finding 1: the button visibly did nothing — the routine WAS created,
    // but its SnackBar rendered behind the still-open sheet and barrier.
    // Also closes Finding 4's coverage gap: no prior test opened the
    // RECOMMENDED PLAN sheet or exercised CREATE THIS ROUTINE at all.
    testWidgets(
        'CREATE THIS ROUTINE creates the routine, closes the sheet and '
        'confirms', (tester) async {
      final db = DatabaseService.instance;
      await db.saveSetting('age', '30');
      await db.saveSetting('target_weight_kg', '75.0');
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);

      final snap = await GoalService.instance.snapshot();
      final expectedName = snap.training!.template.name;

      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('RECOMMENDED PLAN'));
      await tester.pumpAndSettle();
      expect(find.text('RECOMMENDED TRAINING PLAN'), findsWidgets);

      await tester.tap(find.text('CREATE THIS ROUTINE'));
      await tester.pumpAndSettle();
      await settle(tester);

      // The sheet is gone — the confirmation is no longer trapped behind
      // it — and the routine actually exists.
      expect(find.byType(SheetScaffold), findsNothing);
      expect(find.textContaining('created and set active'), findsOneWidget);

      final routines = await db.getRoutines();
      expect(routines.length, 1);
      expect(routines.first['name'], expectedName);

      // Flush the SnackBar's own auto-dismiss Timer so none is left
      // pending when the test ends.
      await tester.pump(const Duration(seconds: 5));
    });

    // Finding 4: the report claimed coverage it did not have — no test
    // exercised `_buildPlanCard`'s no-recommendation fallback either.
    testWidgets(
        'RECOMMENDED PLAN with no goal configured shows the fallback '
        'prompt instead of an empty sheet', (tester) async {
      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('RECOMMENDED PLAN'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            'log one body weight, to get a recommended training split'),
        findsOneWidget,
      );
      expect(find.text('CREATE THIS ROUTINE'), findsNothing);
    });

    // Finding 5: `targetWeightKg` used to be gated on `isConfigured`
    // (age > 0 && targetWeight > 0), so a user who set a target weight but
    // never entered an age saw `--` in a tile labelled TARGET even though
    // they plainly had set one.
    testWidgets(
        'the TARGET tile shows a set target weight even with no age on '
        'file', (tester) async {
      final db = DatabaseService.instance;
      await db.saveSetting('target_weight_kg', '70.0');
      // age deliberately left at the seeded default (0 / unset).

      await pumpBody(tester);
      await settle(tester);

      final tiles = tester.widgetList<StatTile>(find.byType(StatTile));
      final byLabel = {for (final t in tiles) t.label: t.value};
      expect(byLabel['TARGET'], '70.0 kg');
      // The plan-derived number still correctly has nothing to show,
      // because it genuinely cannot be calculated without an age.
      expect(byLabel['DAILY INTAKE'], '${DatabaseService.defaultCalorieTarget} kcal');
    });

    // Findings 6 & 9: `double.tryParse` accepts "Infinity"/"-Infinity" and
    // the old `?? 0` fallback silently stored a bogus zero for unparseable
    // text — both are reachable from the keyboard and both used to save
    // without complaint.
    testWidgets(
        'typing a non-finite weight is rejected at the form, not persisted',
        (tester) async {
      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('+ LOG MEASUREMENT'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Infinity');
      await tester.pump();
      await tester.tap(find.text('SAVE MEASUREMENT'));
      await tester.pump();

      expect(find.byType(SheetScaffold), findsOneWidget,
          reason: 'an invalid weight must not close the sheet');
      expect(find.textContaining('valid weight'), findsOneWidget);

      final rows = await DatabaseService.instance.getBodyLogs();
      expect(rows, isEmpty);
    });

    testWidgets(
        'an empty SAVE MEASUREMENT tap shows a message instead of doing '
        'nothing silently', (tester) async {
      await pumpBody(tester);
      await settle(tester);

      await tester.tap(find.text('+ LOG MEASUREMENT'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE MEASUREMENT'));
      await tester.pump();

      expect(find.byType(SheetScaffold), findsOneWidget);
      expect(find.textContaining('valid weight'), findsOneWidget);
    });

    // Finding 11: every other test in this file runs at the 800x2000
    // surface `pumpBody` fixes, so the `GridView.count(childAspectRatio:
    // 2.4)` stat tiles never get measured at anything close to a real
    // phone's width. This is a smoke test, not a pixel-exact one: the
    // reviewer already confirmed nothing overflows at 390x844 today, so
    // this just keeps that true going forward.
    testWidgets('nothing overflows at a 390x844 phone width', (tester) async {
      final db = DatabaseService.instance;
      await db.saveSetting('age', '30');
      await db.saveSetting('target_weight_kg', '75.0');
      await _insertLog(db, id: 'a', dateStr: '2026-09-01', weightKg: 80.0);
      await _insertLog(db, id: 'b', dateStr: '2026-09-02', weightKg: 79.0);

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: BodyTab()));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(HeroCard), findsOneWidget);
      expect(find.byType(Sparkline), findsOneWidget);
    });
  });
}
