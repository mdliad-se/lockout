import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/log_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/schedule_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/stat_tile.dart';

import 'test_helpers.dart';

SessionLog _log({
  String id = 's1',
  String dayName = 'MON - Legs',
  String dateStr = '2026-09-07',
  int durationSeconds = 3060,
  double totalVolumeKg = 2295.0,
  int totalSets = 22,
  double kcal = 0.0,
}) =>
    SessionLog(
      id: id,
      dayName: dayName,
      dateStr: dateStr,
      durationSeconds: durationSeconds,
      totalVolumeKg: totalVolumeKg,
      status: 'completed',
      totalSets: totalSets,
      kcalBurned: kcal,
    );

Future<void> _insertSession(
  DatabaseService db,
  SessionLog log, {
  List<SetLog> sets = const [],
}) async {
  await db.insertSessionLog(log.toMap());
  if (sets.isNotEmpty) {
    await db.insertSetLogs(sets.map((s) => s.toMap()).toList());
  }
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

  group('sessionArchiveLine', () {
    test('includes the burn estimate when there is one', () {
      expect(
        sessionArchiveLine(_log(kcal: 388.7)),
        '2026-09-07  -  51 min  -  22 sets  -  ~389 kcal',
      );
    });

    test('omits the burn entirely when there is none', () {
      expect(
        sessionArchiveLine(_log()),
        '2026-09-07  -  51 min  -  22 sets',
      );
    });
  });

  Future<void> pumpLog(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LogTab()));
    await settle(tester);
  }

  group('LogTab', () {
    testWidgets('empty state: no active streak, no logs', (tester) async {
      await pumpLog(tester);

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? '').contains('NO COMPLETED WORKOUTS YET')),
        findsOneWidget,
      );

      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(hero.eyebrow, 'CONSISTENCY');
      expect(hero.title, 'NO ACTIVE STREAK');
    });

    testWidgets(
        'streak hero and stat tiles report workouts and total burned',
        (tester) async {
      final db = DatabaseService.instance;
      final today = ScheduleService.dateKey(DateTime.now());
      final yesterday = ScheduleService.dateKey(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      await _insertSession(
        db,
        _log(id: 's1', dateStr: today, kcal: 300.0, totalVolumeKg: 1000),
      );
      await _insertSession(
        db,
        _log(id: 's2', dateStr: yesterday, kcal: 88.7, totalVolumeKg: 500),
      );

      await pumpLog(tester);

      final hero = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(hero.title, '2 DAY STREAK');
      expect(hero.subtitle, '2 WORKOUTS - 1500 KG TOTAL');

      final tiles = tester.widgetList<StatTile>(find.byType(StatTile)).toList();
      expect(tiles.length, 2);
      expect(tiles[0].label, 'WORKOUTS');
      expect(tiles[0].value, '2');
      expect(tiles[1].label, 'TOTAL BURNED');
      expect(tiles[1].value, '~389 kcal');
    });

    testWidgets('total burned shows -- when no session logged a burn',
        (tester) async {
      final db = DatabaseService.instance;
      await _insertSession(db, _log(id: 's1', kcal: 0.0));

      await pumpLog(tester);

      final tiles = tester.widgetList<StatTile>(find.byType(StatTile)).toList();
      expect(tiles[1].value, '--');
    });

    testWidgets(
        'an archive card is closed by default: header only, no set detail, '
        'no DELETE ENTRY', (tester) async {
      final db = DatabaseService.instance;
      await _insertSession(
        db,
        _log(id: 's1', dayName: 'MON - Legs', kcal: 200.0),
        sets: [
          SetLog(
            id: 's1-1',
            sessionExerciseId: '',
            sessionId: 's1',
            exerciseName: 'Squat',
            setIndex: 0,
            weightKg: 100,
            reps: 5,
            isCompleted: true,
          ),
        ],
      );

      await pumpLog(tester);

      expect(find.text('MON - Legs'), findsOneWidget);
      expect(find.text(sessionArchiveLine(_log(id: 's1', kcal: 200.0))),
          findsOneWidget);
      expect(find.text('Squat'), findsNothing);
      expect(find.text('DELETE ENTRY'), findsNothing);
    });

    testWidgets(
        'expanding a card reveals its sets and a DELETE ENTRY link with a '
        '40dp-class tap target', (tester) async {
      final db = DatabaseService.instance;
      await _insertSession(
        db,
        _log(id: 's1', dayName: 'MON - Legs', kcal: 200.0),
        sets: [
          SetLog(
            id: 's1-1',
            sessionExerciseId: '',
            sessionId: 's1',
            exerciseName: 'Squat',
            setIndex: 0,
            weightKg: 100,
            reps: 5,
            isCompleted: true,
          ),
        ],
      );

      await pumpLog(tester);

      await tester.tap(find.text('MON - Legs'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('DELETE ENTRY'), findsOneWidget);

      final detector = find.ancestor(
        of: find.text('DELETE ENTRY'),
        matching: find.byType(GestureDetector),
      );
      expect(detector, findsOneWidget);
      final size = tester.getSize(detector);
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    });

    testWidgets(
        'deleting a session offers UNDO, which restores the session and its '
        'sets', (tester) async {
      final db = DatabaseService.instance;
      await _insertSession(
        db,
        _log(id: 's1', dayName: 'MON - Legs', kcal: 200.0, totalSets: 1),
        sets: [
          SetLog(
            id: 's1-1',
            sessionExerciseId: '',
            sessionId: 's1',
            exerciseName: 'Squat',
            setIndex: 0,
            weightKg: 100,
            reps: 5,
            isCompleted: true,
          ),
        ],
      );

      await pumpLog(tester);
      await tester.tap(find.text('MON - Legs'));
      await tester.pumpAndSettle();
      await settle(tester);

      await tester.tap(find.text('DELETE ENTRY'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('MON - Legs'), findsNothing,
          reason: 'the row disappears immediately');
      expect(await db.getSessionLogs(), isEmpty,
          reason: 'the session is deleted immediately, not just hidden');
      expect(await db.getSetLogsForSession('s1'), isEmpty,
          reason: 'its sets are deleted immediately too');

      expect(find.text('UNDO'), findsOneWidget);
      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('MON - Legs'), findsOneWidget);
      final restored = await db.getSessionLogs();
      expect(restored.length, 1);
      expect(restored.first['id'], 's1');
      expect(restored.first['kcal_burned'], 200.0);

      final restoredSets = await db.getSetLogsForSession('s1');
      expect(restoredSets.length, 1);
      expect(restoredSets.first['exercise_name'], 'Squat');
      expect(restoredSets.first['weight_kg'], 100);
      expect(restoredSets.first['reps'], 5);
    });

    testWidgets(
        'the UNDO banner for a session delete auto-dismisses without '
        'leaving anything pending', (tester) async {
      final db = DatabaseService.instance;
      await _insertSession(db, _log(id: 's1', dayName: 'MON - Legs'));

      await pumpLog(tester);
      await tester.tap(find.text('MON - Legs'));
      await tester.pumpAndSettle();
      await settle(tester);

      await tester.tap(find.text('DELETE ENTRY'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('UNDO'), findsOneWidget);

      // Let the banner's own Timer expire instead of tapping UNDO.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('UNDO'), findsNothing);

      expect(await db.getSessionLogs(), isEmpty,
          reason: 'expiry must not undo the delete');
    });

    // Mirrors food_tab_test.dart's equivalent lock: `getSessionLogs()` has
    // no id-based tiebreak for two sessions sharing a `date_str`, so a
    // delete-then-undo of the middle one could fall back to SQLite's rowid
    // order and land the restored row at the end instead of back in the
    // middle. Deleting the newest of three same-day sessions (already last
    // under `id DESC`) would pass even with the bug, so this deletes the
    // middle one instead.
    testWidgets(
        'deleting the middle of three same-day sessions and undoing '
        'restores its original position', (tester) async {
      final db = DatabaseService.instance;
      const sameDate = '2026-09-07';
      await _insertSession(
          db, _log(id: '1000000000000001', dayName: 'Alpha', dateStr: sameDate));
      await _insertSession(
          db, _log(id: '1000000000000002', dayName: 'Beta', dateStr: sameDate));
      await _insertSession(
          db, _log(id: '1000000000000003', dayName: 'Gamma', dateStr: sameDate));

      await pumpLog(tester);

      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((d) => ['Alpha', 'Beta', 'Gamma'].contains(d))
            .toList(),
        ['Gamma', 'Beta', 'Alpha'],
        reason: 'newest id sorts first within a shared date',
      );

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      await settle(tester);
      await tester.tap(find.text('DELETE ENTRY'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('Beta'), findsNothing);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      await settle(tester);

      final restoredOrder = (await db.getSessionLogs())
          .map((r) => r['day_name'])
          .toList();
      expect(restoredOrder, ['Gamma', 'Beta', 'Alpha'],
          reason: 'Beta must come back into the middle, not get appended');

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => ['Alpha', 'Beta', 'Gamma'].contains(d))
          .toList();
      expect(texts, ['Gamma', 'Beta', 'Alpha'],
          reason: 'on-screen order must match the restored DB order');
    });
  });
}
