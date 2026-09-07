import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/schedule_service.dart';

/// Schedule resolution and streak counting against a real database.
///
/// These paths depend on the calendar, and the emulator's Google Play image
/// refuses `date` without root — so driving them by moving a device clock is
/// not possible. Running them here exercises the same queries and the same
/// resolution logic across arbitrary dates instead.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseService.instance.database;
    for (final table in DatabaseService.backupTables) {
      await db.delete(table);
    }
  });

  /// A routine whose days cycle in order, anchored at [createdAt].
  Future<void> seedRotating({
    required String createdAt,
    required List<String> dayNames,
  }) async {
    final db = DatabaseService.instance;
    await db.insertRoutine(Routine(
      id: 'rot',
      name: 'Rotating Split',
      schedulingMode: SchedulingMode.rotating,
      createdAt: createdAt,
    ).toMap());

    for (var i = 0; i < dayNames.length; i++) {
      final dayId = 'rot-d$i';
      await db.insertDay(TrainingDay(
        id: dayId,
        routineId: 'rot',
        name: dayNames[i],
        tag: 'D${i + 1}',
        orderIndex: i,
      ).toMap());
      await db.insertExercise(ExerciseDef(
        id: 'rot-e$i',
        dayId: dayId,
        name: 'Back Squat',
        targetSets: 3,
        targetRepsMin: 5,
        targetRepsMax: 5,
        orderIndex: 0,
      ).toMap());
    }
    await db.setActiveRoutine('rot');
  }

  group('Rotating schedule', () {
    test('cycles one day forward per calendar day and wraps', () async {
      await seedRotating(
        createdAt: '2026-09-01T08:00:00.000',
        dayNames: ['Push', 'Pull', 'Legs'],
      );

      Future<String?> dayOn(int y, int m, int d) async =>
          (await ScheduleService.resolveFor(DateTime(y, m, d)))?.day.name;

      expect(await dayOn(2026, 9, 1), 'Push'); // anchor day
      expect(await dayOn(2026, 9, 2), 'Pull');
      expect(await dayOn(2026, 9, 3), 'Legs');
      expect(await dayOn(2026, 9, 4), 'Push'); // wraps
      expect(await dayOn(2026, 9, 5), 'Pull');
      expect(await dayOn(2026, 9, 6), 'Legs');
    });

    test('ignores weekday entirely', () async {
      await seedRotating(
        createdAt: '2026-09-01T08:00:00.000',
        dayNames: ['A', 'B'],
      );

      // 2026-09-07 and 2026-09-14 are both Mondays, but sit at different
      // points in a 2-day cycle: 6 and 13 days after the anchor.
      expect(
        (await ScheduleService.resolveFor(DateTime(2026, 9, 7)))?.day.name,
        'A',
      );
      expect(
        (await ScheduleService.resolveFor(DateTime(2026, 9, 14)))?.day.name,
        'B',
      );
    });

    test('the cycle holds over a long span', () async {
      await seedRotating(
        createdAt: '2026-09-01T08:00:00.000',
        dayNames: ['A', 'B', 'C', 'D'],
      );
      // 100 days after the anchor: 100 % 4 == 0, so back to the first day.
      final resolved =
          await ScheduleService.resolveFor(DateTime(2026, 9, 1).add(const Duration(days: 100)));
      expect(resolved?.day.name, 'A');
    });

    test('a date before the routine existed resolves to nothing', () async {
      await seedRotating(
        createdAt: '2026-09-10T08:00:00.000',
        dayNames: ['A', 'B'],
      );
      expect(await ScheduleService.resolveFor(DateTime(2026, 9, 5)), isNull);
    });

    test('resolved day carries its exercises', () async {
      await seedRotating(
        createdAt: '2026-09-01T08:00:00.000',
        dayNames: ['Push', 'Pull'],
      );
      final resolved = await ScheduleService.resolveFor(DateTime(2026, 9, 1));
      expect(resolved!.exercises.single.name, 'Back Squat');
      expect(resolved.routine.schedulingMode, SchedulingMode.rotating);
    });
  });

  group('Weekday schedule', () {
    Future<void> seedWeekday() async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'wk',
        name: 'Weekday Split',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-09-01T08:00:00.000',
      ).toMap());

      for (final entry in {'MON': 'Legs', 'SAT': 'Push'}.entries) {
        final dayId = 'wk-${entry.key}';
        await db.insertDay(TrainingDay(
          id: dayId,
          routineId: 'wk',
          name: entry.value,
          tag: entry.key,
          orderIndex: 0,
        ).toMap());
      }
      await db.setActiveRoutine('wk');
    }

    test('matches the day pinned to that weekday', () async {
      await seedWeekday();
      // 2026-09-07 is a Monday, 2026-09-12 a Saturday.
      expect(
        (await ScheduleService.resolveFor(DateTime(2026, 9, 7)))?.day.name,
        'Legs',
      );
      expect(
        (await ScheduleService.resolveFor(DateTime(2026, 9, 12)))?.day.name,
        'Push',
      );
    });

    test('an unscheduled weekday is a rest day', () async {
      await seedWeekday();
      // Wednesday — no day pinned to it.
      expect(await ScheduleService.resolveFor(DateTime(2026, 9, 9)), isNull);
    });
  });

  group('Streak from real sessions', () {
    Future<void> logSessionOn(String dateStr) async {
      await DatabaseService.instance.insertSessionLog(SessionLog(
        id: 'sess-$dateStr',
        dayName: 'Session',
        dateStr: dateStr,
        durationSeconds: 1800,
        totalVolumeKg: 1000,
        status: 'completed',
      ).toMap());
    }

    String key(DateTime d) => ScheduleService.dateKey(d);

    test('consecutive sessions build a streak', () async {
      final now = DateTime.now();
      await logSessionOn(key(now));
      await logSessionOn(key(now.subtract(const Duration(days: 1))));
      await logSessionOn(key(now.subtract(const Duration(days: 2))));

      final dates = await DatabaseService.instance.getWorkoutDates();
      expect(ScheduleService.currentStreakDays(dates), 3);
    });

    test('two sessions on one day count once', () async {
      final now = DateTime.now();
      // getWorkoutDates() is DISTINCT; a double session must not inflate it.
      await DatabaseService.instance.insertSessionLog(SessionLog(
        id: 'a',
        dayName: 'AM',
        dateStr: key(now),
        durationSeconds: 900,
        totalVolumeKg: 500,
        status: 'completed',
      ).toMap());
      await DatabaseService.instance.insertSessionLog(SessionLog(
        id: 'b',
        dayName: 'PM',
        dateStr: key(now),
        durationSeconds: 900,
        totalVolumeKg: 500,
        status: 'completed',
      ).toMap());

      final dates = await DatabaseService.instance.getWorkoutDates();
      expect(dates.length, 1);
      expect(ScheduleService.currentStreakDays(dates), 1);
    });

    test('a missed day breaks the streak', () async {
      final now = DateTime.now();
      await logSessionOn(key(now));
      await logSessionOn(key(now.subtract(const Duration(days: 1))));
      // gap at day 2
      await logSessionOn(key(now.subtract(const Duration(days: 3))));
      await logSessionOn(key(now.subtract(const Duration(days: 4))));

      final dates = await DatabaseService.instance.getWorkoutDates();
      expect(ScheduleService.currentStreakDays(dates), 2);
    });

    test('only completed sessions count toward a streak', () async {
      final now = DateTime.now();
      await logSessionOn(key(now.subtract(const Duration(days: 1))));
      await DatabaseService.instance.insertSessionLog(SessionLog(
        id: 'skipped',
        dayName: 'Bailed',
        dateStr: key(now),
        durationSeconds: 0,
        totalVolumeKg: 0,
        status: 'skipped',
      ).toMap());

      final dates = await DatabaseService.instance.getWorkoutDates();
      expect(dates, [key(now.subtract(const Duration(days: 1)))]);
      expect(ScheduleService.currentStreakDays(dates), 1);
    });

    test('a long unbroken run counts fully', () async {
      final now = DateTime.now();
      for (var i = 0; i < 30; i++) {
        await logSessionOn(key(now.subtract(Duration(days: i))));
      }
      final dates = await DatabaseService.instance.getWorkoutDates();
      expect(ScheduleService.currentStreakDays(dates), 30);
    });
  });

  group('Active routine fallback', () {
    test('falls back to the newest routine when none is marked active',
        () async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'old',
        name: 'Older',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-01-01T08:00:00.000',
      ).toMap());
      await db.insertRoutine(Routine(
        id: 'new',
        name: 'Newer',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-09-01T08:00:00.000',
      ).toMap());
      await db.saveSetting('active_routine_id', '');

      expect((await db.getActiveRoutine())?['name'], 'Newer');
    });

    test('falls back when the stored active id points at a deleted routine',
        () async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'alive',
        name: 'Still Here',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-09-01T08:00:00.000',
      ).toMap());
      await db.setActiveRoutine('deleted-long-ago');

      expect((await db.getActiveRoutine())?['name'], 'Still Here');
    });
  });
}
