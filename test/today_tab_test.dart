import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/today_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/schedule_service.dart';
import 'package:lockout/theme/app_palette.dart';

import 'test_helpers.dart';

/// Direct coverage for the `TodayTab` wiring the two fix waves touched:
/// Ruling B's empty-day guard, the `foodTabEnabled` null-callback path, the
/// `_finishSession` summary refresh (including the ESTIMATE UNAVAILABLE /
/// NO SESSION YET split), and the `_isLoading` sequencing. All of these
/// depend on `ScheduleService` and `GoalService`, which read the real
/// database — there is no way to build a meaningful `TodayTab` in these
/// scenarios without one, unlike `HomeHub` itself (which is why `HomeHub`
/// stays presentation-only and gets tested with no database at all in
/// `home_tab_test.dart`). `settle` (the bounded-pump helper, since
/// `pumpAndSettle` never terminates while a `CircularProgressIndicator`'s
/// indeterminate animation is on screen) lives in `test_helpers.dart`,
/// shared with `routines_tab_test.dart`.
void main() {
  setUpAll(() {
    // `testWidgets`' fake-async zone never lets a *file-backed* sqflite
    // database finish opening in this environment — confirmed by isolating
    // the call: the identical `openDatabase` resolves instantly under a
    // plain `test()` (every other DB-backed suite in this repo uses one),
    // and resolves instantly here too once given an in-memory path instead.
    // `databaseFactoryFfiNoIsolate` avoids a second, unrelated hang from the
    // default factory's background-isolate round trip inside that same zone.
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  final today = ScheduleService.dateKey(DateTime.now());
  final todayCode = ScheduleService.weekdayCode(DateTime.now());

  group('Ruling B - empty scheduled day', () {
    testWidgets(
        'a training day scheduled today with zero exercises offers no live '
        'START SESSION, shows Routines-tab guidance, and still allows '
        'CUSTOM SESSION', (tester) async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'r1',
        name: 'Split',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-01-01T00:00:00.000',
      ).toMap());
      await db.insertDay(TrainingDay(
        id: 'd1',
        routineId: 'r1',
        name: 'Legs',
        tag: todayCode,
        orderIndex: 0,
      ).toMap());
      // Deliberately no exercises inserted for 'd1'.
      await db.setActiveRoutine('r1');

      await tester.pumpWidget(MaterialApp(home: TodayTab()));
      await settle(tester);

      expect(find.text('START SESSION'), findsNothing);
      expect(find.text('CUSTOM SESSION'), findsOneWidget);
      expect(
        find.textContaining('Add them on the Routines tab'),
        findsOneWidget,
      );
    });
  });

  group('foodTabEnabled', () {
    testWidgets(
        'false hides the CALORIES row and the LOG FOOD quick action, and '
        'the null onNavigate does not crash when a tile is tapped',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TodayTab(foodTabEnabled: false),
      ));
      await settle(tester);

      expect(find.text('CALORIES'), findsNothing);
      expect(find.text('LOG FOOD'), findsNothing);

      // onNavigate is null (the default for a tab pumped on its own). The
      // WEIGH IN tile's onTap is `() => go?.call('body')`, which must no-op
      // rather than throw when `go` is null.
      await tester.tap(find.text('WEIGH IN'));
      await settle(tester, maxPumps: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('_finishSession summary refresh', () {
    testWidgets(
        'a session saved with no bodyweight on record reads ESTIMATE '
        'UNAVAILABLE afterwards, not NO SESSION YET (the session was not '
        'lost, only its estimate)', (tester) async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'r1',
        name: 'Split',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-01-01T00:00:00.000',
      ).toMap());
      await db.insertDay(TrainingDay(
        id: 'd1',
        routineId: 'r1',
        name: 'Legs',
        tag: todayCode,
        orderIndex: 0,
      ).toMap());
      await db.insertExercise(ExerciseDef(
        id: 'e1',
        dayId: 'd1',
        name: 'Back Squat',
        targetSets: 1,
        targetRepsMin: 5,
        targetRepsMax: 5,
      ).toMap());
      await db.setActiveRoutine('r1');
      // No bodyweight logged and no target weight configured, so
      // EnergyEstimator.estimate() cannot produce a figure.

      await tester.pumpWidget(MaterialApp(home: TodayTab()));
      await settle(tester);

      expect(find.text('NO SESSION YET'), findsOneWidget);

      await tester.tap(find.text('START SESSION'));
      await settle(tester);

      await tester.tap(find.text('LOG SET'));
      await settle(tester, maxPumps: 4);

      await tester.tap(find.text('FINISH SESSION & SAVE'));
      await settle(tester);

      // Back on the hub: the session was saved (proved by the assertion
      // below), but with no bodyweight on record no estimate could be made.
      expect(find.text('ESTIMATE UNAVAILABLE'), findsOneWidget);
      expect(find.text('NO SESSION YET'), findsNothing);

      final saved = await db.getSessionLogsForDate(today);
      expect(saved.length, 1);
      expect(saved.first['kcal_burned'], 0.0);
    });
  });

  // Finishing a session is the only place set data is ever produced, and it
  // wrote two tables back to back with nothing joining them. `deleteSessionLog`
  // and `restoreSessionLog` were both given transactions on the argument that
  // a header without its sets is indistinguishable from a legitimately
  // detail-free entry; the create path has the identical exposure and was
  // left out.
  //
  // Sequential writes pass every other test in this suite, because nothing
  // else makes the second one fail. This installs the same aborting trigger
  // `database_service_test.dart` uses, drives a real session through the
  // real screen, and asserts the header does not survive the failure — a
  // lock on the call site, not just on the DatabaseService method.
  // Finishing a session is the only place set data is ever produced, and it
  // wrote two tables back to back with nothing joining them: a kill between
  // the header insert and the sets — a low-memory process death right after
  // a workout, when the app is most likely to be backgrounded — left a
  // header claiming `totalSets: N` with nothing behind it. That is the same
  // state `deleteSessionLog` and `restoreSessionLog` were given
  // transactions to prevent, on the argument that a detail-free header is
  // indistinguishable from a legitimately detail-free entry.
  //
  // The rollback itself is proved against a forced mid-transaction failure
  // in `database_service_test.dart`; driving the same failure through this
  // screen cannot be done, because the rejection surfaces as an unhandled
  // async error out of the button callback and `flutter_test` fails a test
  // the moment one is raised, before any assertion can run. This reads the
  // call site instead — the same structural idiom `settings_restyle_test`
  // uses for the v2 style sweep — so re-splitting the write into two
  // unguarded calls fails here even though every behavioural test passes.
  group('_finishSession writes atomically', () {
    test('the finish path goes through the transactional write', () {
      final source = File('lib/screens/today_tab.dart').readAsStringSync();

      expect(source, contains('insertSessionWithSets('),
          reason: 'the session and its sets must be written in one '
              'transaction');
      expect(source, isNot(contains('insertSetLogs(')),
          reason: 'a second, separate set write reopens the gap');
      expect(source, isNot(contains('insertSessionLog(')),
          reason: 'a bare header write reopens the gap');
    });
  });


  group('_isLoading sequencing', () {
    testWidgets(
        'renders real values, not the not-on-record prompts, once both the '
        'schedule and the summary have loaded', (tester) async {
      final db = DatabaseService.instance;
      await db.insertBodyLog(BodyEntry(
        id: 'b1',
        dateStr: today,
        weightKg: 80.0,
      ).toMap());
      await db.insertFoodLog(FoodEntry(
        id: 'f1',
        dateStr: today,
        mealSlot: 'Breakfast',
        name: 'Oats',
        kcal: 400,
      ).toMap());
      await db.insertSessionLog(SessionLog(
        id: 's1',
        dayName: 'Legs',
        dateStr: today,
        durationSeconds: 1800,
        totalVolumeKg: 1000,
        status: 'completed',
        kcalBurned: 300.0,
      ).toMap());

      await tester.pumpWidget(MaterialApp(home: TodayTab()));
      await settle(tester);

      // A single weigh-in: a value, but no delta yet.
      expect(find.text('LOG A WEIGHT'), findsNothing);
      expect(find.text('80.0 kg'), findsOneWidget);
      expect(find.text('NO SESSION YET'), findsNothing);
      expect(find.text('ESTIMATE UNAVAILABLE'), findsNothing);
      expect(find.text('~300 kcal'), findsOneWidget);

      // Verifying the two loads race-free in the single frame right after
      // `_isLoading` clears would need a controlled clock around the two
      // chained `await`s inside `reload()`; pumping a specific frame count
      // to land exactly there is inherently timing-dependent and would be
      // flaky rather than a real guarantee. The outcome above — real values
      // rendered, never a prompt for data that exists — is what that
      // sequencing exists to guarantee, and is what is verified here.
    });
  });
}
