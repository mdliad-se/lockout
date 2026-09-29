import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/today_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/schedule_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/lockout_theme.dart';

import 'test_helpers.dart';

/// Hosts `TodayTab` under the app's real theme — every test below opens a
/// live session, which reads `LockoutSemantics`/`LockoutTheme`, so a bare
/// `MaterialApp` is not enough.
Widget hostedTodayTab() =>
    MaterialApp(theme: lockoutTestTheme(), home: TodayTab());

/// Seeds one active weekday routine with a training day scheduled for today
/// and a single exercise, so `_startScheduledSession` has something to start.
/// Shared by every live-session test below rather than repeated per test.
Future<void> seedActiveWeekdayRoutineForToday({double targetWeightKg = 0}) async {
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
    tag: ScheduleService.weekdayCode(DateTime.now()),
    orderIndex: 0,
  ).toMap());
  await db.insertExercise(ExerciseDef(
    id: 'e1',
    dayId: 'd1',
    name: 'Back Squat',
    targetSets: 2,
    targetRepsMin: 8,
    targetRepsMax: 8,
    targetWeightKg: targetWeightKg,
  ).toMap());
  await db.setActiveRoutine('r1');
}

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

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: TodayTab()));
      await settle(tester);

      expect(find.text('Start session'), findsNothing);
      expect(find.text('Custom session'), findsOneWidget);
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
        theme: lockoutTestTheme(),
        home: TodayTab(foodTabEnabled: false),
      ));
      await settle(tester);

      expect(find.text('Calories'), findsNothing);
      expect(find.text('Log food'), findsNothing);

      // onNavigate is null (the default for a tab pumped on its own). The
      // Weigh in tile's onTap is `() => go?.call('progress', ...)`, which must
      // no-op rather than throw when `go` is null.
      await tester.tap(find.text('Weigh in'));
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

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: TodayTab()));
      await settle(tester);

      // Burn now rides on the day card's own subtitle rather than a
      // standalone row, so "no session today" is the absence of any burn
      // figure, not a sentence of its own.
      expect(find.textContaining('kcal'), findsNothing);

      await tester.tap(find.text('Start session'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('set-complete-0-0')));
      await settle(tester, maxPumps: 4);

      await tester.tap(find.text('Finish'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      // Back on the hub: the session was saved (proved by the assertion
      // below), but with no bodyweight on record no estimate could be made.
      expect(find.textContaining('Estimate unavailable'), findsOneWidget);

      final saved = await db.getSessionLogsForDate(today);
      expect(saved.length, 1);
      expect(saved.first['kcal_burned'], 0.0);
    });
  });

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

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: TodayTab()));
      await settle(tester);

      // A single weigh-in: a value, but no delta yet.
      expect(find.text('Log a weight'), findsNothing);
      // The weight card states the figure and its unit separately, so the
      // number can carry the display type scale.
      expect(find.text('80.0'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.textContaining('Estimate unavailable'), findsNothing);
      expect(find.textContaining('~300 kcal'), findsOneWidget);

      // Verifying the two loads race-free in the single frame right after
      // `_isLoading` clears would need a controlled clock around the two
      // chained `await`s inside `reload()`; pumping a specific frame count
      // to land exactly there is inherently timing-dependent and would be
      // flaky rather than a real guarantee. The outcome above — real values
      // rendered, never a prompt for data that exists — is what that
      // sequencing exists to guarantee, and is what is verified here.
    });
  });

  // TODAY does not hydrate these two rows through a model factory — it folds
  // the raw maps itself — so the tolerant reads added to `SessionLog.fromMap`
  // and `FoodEntry.fromMap` do not cover it. Same restore vector, same
  // `_loadSummary()` shape: the cast threw before `setState`, and the hub sat
  // on its spinner with no route off it.
  group('a poisoned row does not strand the hub', () {
    testWidgets('text in kcal and kcal_burned counts as zero, not a throw',
        (tester) async {
      final db = DatabaseService.instance;
      final database = await db.database;
      // Raw inserts: every typed path coerces on the way in.
      await database.insert('food_logs', {
        'id': 'f1',
        'date_str': today,
        'meal_slot': 'Breakfast',
        'name': 'Oats',
        'kcal': 'loads',
        'protein_g': 0.0,
        'carb_g': 0.0,
        'fat_g': 0.0,
      });
      await database.insert('session_logs', {
        'id': 's1',
        'day_name': 'Legs',
        'date_str': today,
        'duration_seconds': 1800,
        'total_volume_kg': 1000.0,
        'status': 'completed',
        'routine_id': '',
        'day_id': '',
        'total_sets': 4,
        'kcal_burned': 'loads',
      });

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: TodayTab()));
      await settle(tester);

      expect(tester.takeException(), isNull);
      // The session still happened, so the row must not claim otherwise —
      // only its unreadable estimate is lost.
      expect(find.text('No session yet'), findsNothing);
    });
  });

  group('the live session screen', () {
    testWidgets('session header shows elapsed time and exercise progress',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);

      await tester.tap(find.text('Start session'));
      await settle(tester);

      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('weight and rep steppers meet the 48dp touch target',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      for (final icon in [Icons.remove, Icons.add]) {
        for (final element in find.byIcon(icon).evaluate()) {
          final size = tester.getSize(find.byWidget(
            element.findAncestorWidgetOfExactType<IconButton>()!,
          ));
          expect(size.width, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
          expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
        }
      }
    });

    testWidgets('the leg-safety notice renders in the warning role',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      expect(find.textContaining('Pain-free movement only'), findsOneWidget);
    });

    testWidgets('numeric columns use the mono family so digits align',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      final setNumber = tester.widget<Text>(find.text('1').first);
      expect(setNumber.style?.fontFamily, 'JetBrainsMono');
    });

    testWidgets('the header states duration, volume and sets', (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      expect(find.text('Duration'), findsOneWidget);
      // The unit lives in the label, not the value, so a four-digit volume
      // has room to stay on-scale next to `Finish` at 360dp — see
      // `_buildSessionHeader`.
      expect(find.text('Volume (kg)'), findsOneWidget);
      expect(find.text('Sets'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('completing a set tints the whole row, not just the tick',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      Color? rowColour() {
        final box = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('set-row-0-0')),
        );
        return (box.decoration as BoxDecoration).color;
      }

      final before = rowColour();
      await tester.tap(find.byKey(const ValueKey('set-complete-0-0')));
      await tester.pumpAndSettle();

      expect(rowColour(), isNot(before));
    });

    // The default test viewport is 800x600 — wide enough that a set row's
    // fixed-width children never come close to overflowing, which is why the
    // suite stayed green while the row genuinely overflowed on a real phone.
    // 360dp is the narrowest common Android width. Seeded with a multi-digit
    // weight (102.5kg, not the default 0) — a single-character value never
    // exercises `FittedBox`'s scale-down path, which is exactly how this test
    // missed the previous round's column-shimmer regression.
    testWidgets(
        'the set row does not overflow at a 360dp phone width, and a '
        'multi-digit weight renders at the same scale as the reps column',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await seedActiveWeekdayRoutineForToday(targetWeightKg: 102.5);
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      expect(tester.takeException(), isNull);

      // `tester.getSize` on the `Text` itself is not a usable regression
      // check here: `FittedBox` applies its scale as a paint transform, so
      // `RenderFittedBox.performLayout` lays the child out unbounded and
      // `getSize` returns that unscaled layout size — identical for '102.5'
      // and '8' by construction, whatever `FittedBox` actually does.
      // Assert on the layout budget the value is given instead: it is
      // font-independent, and it is exactly what regresses if the complete
      // tick ever moves back onto the steppers' line (see
      // `_buildSetRow`'s comment) — the value's slot narrows from its
      // capped 40dp down to whatever the tick's neighbour leaves it.
      final slot = tester.getSize(find.ancestor(
        of: find.text('102.5'),
        matching: find.byType(FittedBox),
      ).first);
      expect(slot.width, greaterThanOrEqualTo(40));
    });

    testWidgets('the rest bar adjusts in both directions', (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('set-complete-0-0')));
      await tester.pump();

      expect(find.text('-15s'), findsOneWidget);
      expect(find.text('+15s'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    // Restores the v1 per-set delete affordance: `Add set` gained a way
    // back once a user could add sets they did not mean to.
    testWidgets('a set can be removed, but never down to zero',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      expect(find.byKey(const ValueKey('set-row-0-1')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).first);
      await settle(tester);

      expect(find.byKey(const ValueKey('set-row-0-1')), findsNothing);
      expect(find.byKey(const ValueKey('set-row-0-0')), findsOneWidget);

      // One set left: the guard disables the control rather than removing
      // the last row a session needs to log anything at all.
      final lastDelete = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.close),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(lastDelete.onPressed, isNull);
    });

    // Round-4 finding A: keying the completion tint's `TweenAnimationBuilder`
    // by loop position (`set-tween-$exerciseIndex-$setIndex`) is a no-op —
    // deleting a set renumbers the survivors, so `Element.updateChildren`
    // hands the surviving row the *old* completed row's animated element and
    // it flashes the success tint down to transparent over
    // `Durations.medium1` before settling on the colour it already held.
    // `ObjectKey(set)` fixes it by keying on the set's own identity instead
    // of its position.
    testWidgets('deleting a completed set does not tint the surviving row',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('set-complete-0-0')));
      // Let the completion tint finish animating in (Durations.medium1 is
      // 250ms) before deleting it. `settle`'s bounded pumps are safe here
      // even though marking a set complete also starts the rest countdown.
      await settle(tester, maxPumps: 6);

      // Deletes the now-completed set 0, leaving the never-logged set 1 as
      // the sole, surviving row (renumbered to position 0).
      await tester.tap(find.byIcon(Icons.close).first);
      // A single, zero-duration frame — not `settle`/`pumpAndSettle` — so a
      // 250ms false-"completed" flash on the surviving row is caught rather
      // than left to finish and hide.
      await tester.pump();

      final decoration = tester
          .widget<DecoratedBox>(find.byKey(const ValueKey('set-row-0-0')))
          .decoration as BoxDecoration;
      expect(decoration.color, Colors.transparent);
    });

    // The finish sheet's Discard used to end a session with logged sets on
    // a single tap. It must now route through the same "DISCARD SESSION?"
    // gate a zero-set session already gets from `_finishSession`.
    testWidgets(
        'Discard asks for confirmation once a set has been logged',
        (tester) async {
      await seedActiveWeekdayRoutineForToday();
      await tester.pumpWidget(hostedTodayTab());
      await settle(tester);
      await tester.tap(find.text('Start session'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('set-complete-0-0')));
      await settle(tester, maxPumps: 4);

      await tester.tap(find.text('Finish'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);

      expect(find.text('DISCARD SESSION?'), findsOneWidget);
      // The copy must name what is actually lost — a session with a logged
      // set is real data, not the empty-draft case the dialog also serves.
      expect(
        find.text('1 logged set will be lost. Discard it?'),
        findsOneWidget,
      );

      await tester.tap(find.text('KEEP GOING'));
      await settle(tester);

      // Declining the confirmation must leave the session running, not end
      // it anyway.
      expect(find.text('Finish'), findsOneWidget);
    });
  });
}
