import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/data/exercise_library.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/services/schedule_service.dart';
import 'package:lockout/services/units.dart';

void main() {
  group('Units - height and BMI', () {
    test('feet/inches convert to centimetres', () {
      expect(Units.feetInchesToCm(5, 9), closeTo(175.26, 0.01));
      expect(Units.feetInchesToCm(6, 0), closeTo(182.88, 0.01));
    });

    test('centimetres split back into feet and inches', () {
      final h = Units.cmToFeetInches(175.26);
      expect(h.feet, 5);
      expect(h.inches, closeTo(9.0, 0.05));
    });

    test('inches rounding up a full foot carries into feet', () {
      // 6ft exactly must never render as "5 ft 12 in".
      final h = Units.cmToFeetInches(182.88);
      expect(h.feet, 6);
      expect(h.inches, lessThan(12));
    });

    test('BMI matches the kg/m2 formula', () {
      final bmi = Units.bmi(weightKg: 78.8, heightCm: 175.26);
      expect(bmi, isNotNull);
      expect(bmi!, closeTo(25.65, 0.05));
      expect(Units.bmiCategory(bmi), 'OVERWEIGHT');
    });

    test('BMI returns null rather than infinity for unusable input', () {
      expect(Units.bmi(weightKg: 0, heightCm: 175), isNull);
      expect(Units.bmi(weightKg: 78, heightCm: 0), isNull);
    });

    test('height formats in the requested unit', () {
      expect(Units.formatHeight(175.26, 'ft'), '5 ft 9 in');
      expect(Units.formatHeight(175.0, 'cm'), '175 cm');
    });
  });

  group('ScheduleService - weekday resolution', () {
    test('weekday codes align with DateTime.weekday', () {
      // 2026-09-07 is a Monday.
      expect(ScheduleService.weekdayCode(DateTime(2026, 9, 7)), 'MON');
      expect(ScheduleService.weekdayCode(DateTime(2026, 9, 12)), 'SAT');
      expect(ScheduleService.weekdayCode(DateTime(2026, 9, 13)), 'SUN');
    });

    test('date key is the ISO calendar date', () {
      expect(ScheduleService.dateKey(DateTime(2026, 9, 7, 14, 30)), '2026-09-07');
    });
  });

  group('ScheduleService - streak', () {
    // Fixtures are built with calendar arithmetic — `DateTime(y, m, d - n)`,
    // which the constructor normalises across month and year boundaries —
    // rather than `now.subtract(Duration(days: n))`. Subtracting a fixed 24h
    // is the exact idiom these tests exist to guard against: on a
    // DST-observing host at 00:30 the morning after a spring-forward,
    // `now.subtract(const Duration(days: 1))` lands on the day *before*
    // yesterday, quietly turning "a streak ending yesterday" into a
    // gap-of-two case and failing in CI for a reason that has nothing to do
    // with the streak rule.
    String daysAgo(int n) {
      final now = DateTime.now();
      return ScheduleService.dateKey(
        DateTime(now.year, now.month, now.day - n),
      );
    }

    test('consecutive days ending today count', () {
      expect(
        ScheduleService.currentStreakDays([daysAgo(0), daysAgo(1), daysAgo(2)]),
        3,
      );
    });

    test('a streak ending yesterday is still live', () {
      expect(ScheduleService.currentStreakDays([daysAgo(1), daysAgo(2)]), 2);
    });

    test('a gap of two days breaks the streak', () {
      expect(ScheduleService.currentStreakDays([daysAgo(3)]), 0);
    });

    // A gap of 3 (above) also trips a mutated `> 2` bound, so it does not
    // discriminate the boundary. A gap of exactly 2 (the day-before-
    // yesterday case) only breaks the streak under the real `> 1` bound.
    test('a gap of exactly two days (day before yesterday) also breaks '
        'the streak', () {
      expect(ScheduleService.currentStreakDays([daysAgo(2)]), 0);
    });

    test('no history means no streak', () {
      expect(ScheduleService.currentStreakDays([]), 0);
    });

    // A date ahead of today is not a workout that happened: it comes from
    // clock skew, or from a backup restored from a device in a later
    // timezone. Left in, it makes the newest-date gap negative, which sails
    // past the `> 1` break test and reports a live streak off a session
    // nobody has done.
    test('a future-dated session cannot prop up a dead streak', () {
      expect(ScheduleService.currentStreakDays([daysAgo(-1)]), 0);
    });

    test('a future-dated session neither extends nor breaks a live run', () {
      expect(
        ScheduleService.currentStreakDays([daysAgo(-1), daysAgo(0), daysAgo(1)]),
        2,
      );
    });
  });

  // `dayNumber` derives a day ordinal from calendar fields alone (Howard
  // Hinnant's days_from_civil) and never from wall-clock subtraction,
  // because two local midnights are not reliably 24h apart: across a
  // spring-forward they are 23h apart, which `Duration.inDays` floors to 0,
  // and across a fall-back a genuine two-day gap is 47h, which floors to 1.
  group('ScheduleService - dayNumber', () {
    test('adjacent calendar dates are one ordinal apart whatever the time '
        'of day', () {
      expect(
        ScheduleService.dayNumber(DateTime(2026, 3, 9, 0, 0)) -
            ScheduleService.dayNumber(DateTime(2026, 3, 8, 23, 59)),
        1,
      );
    });

    test('ordinals run continuously across a month boundary', () {
      expect(
        ScheduleService.dayNumber(DateTime(2027, 3, 1)) -
            ScheduleService.dayNumber(DateTime(2027, 2, 28)),
        1,
      );
    });

    test('a leap day is a day like any other', () {
      // 2028 is a leap year, so 02-28 -> 03-01 spans two days.
      expect(
        ScheduleService.dayNumber(DateTime(2028, 3, 1)) -
            ScheduleService.dayNumber(DateTime(2028, 2, 28)),
        2,
      );
    });
  });

  // The DST hazard above cannot be reproduced here: this host runs at UTC+6
  // and observes no transition, so every real `DateTime` pair available to a
  // test makes calendar arithmetic and `Duration.inDays` agree. A test
  // written from real dates can only assert what both already do, and passes
  // just as happily against the broken arithmetic — there is no coverage to
  // be had that way.
  //
  // So these swap the calendar itself for a deliberately skewed one through
  // `ScheduleService.calendarDay`. A skew changes an answer only if the
  // production code actually consults the calendar, so reverting either
  // call site in `currentStreakDays` to `Duration.inDays` fails them.
  group('ScheduleService - streak reads the calendar, not the clock', () {
    tearDown(() => ScheduleService.calendarDay = ScheduleService.dayNumber);

    String key(DateTime d) => ScheduleService.dateKey(d);

    DateTime daysAgo(int n) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - n);
    }

    /// Installs a calendar that agrees with the real one everywhere except
    /// [date], which it places [by] extra days into the past — the stand-in
    /// for a transition this machine's timezone cannot produce.
    void skew(DateTime date, int by) {
      final target = ScheduleService.dayNumber(date);
      ScheduleService.calendarDay = (d) {
        final n = ScheduleService.dayNumber(d);
        return n == target ? n - by : n;
      };
    }

    test('the run between two logged days is a calendar difference', () {
      // The clock says these two dates are adjacent; the calendar says they
      // are four days apart, so the run is one day, not two.
      skew(daysAgo(1), 3);
      expect(
        ScheduleService.currentStreakDays([key(daysAgo(0)), key(daysAgo(1))]),
        1,
      );
    });

    test('the "today or yesterday" bound is measured the same way', () {
      // One logged day, adjacent to today by the clock but four calendar
      // days back: too old to keep the streak alive.
      skew(daysAgo(1), 3);
      expect(ScheduleService.currentStreakDays([key(daysAgo(1))]), 0);
    });

    test('a calendar that pulls two dates together keeps the run alive', () {
      // The mirror case, and the one a spring-forward actually produces: a
      // gap measured in hours over-counts what is really one calendar day.
      skew(daysAgo(3), -2);
      expect(
        ScheduleService.currentStreakDays([key(daysAgo(0)), key(daysAgo(3))]),
        2,
      );
    });
  });

  group('ExerciseLibrary', () {
    test('catalog is populated and every entry is well formed', () {
      expect(ExerciseLibrary.all.length, greaterThan(150));
      for (final e in ExerciseLibrary.all) {
        expect(e.name.trim(), isNotEmpty);
        expect(ExerciseLibrary.muscleGroups, contains(e.muscleGroup));
        expect(e.defaultSets, greaterThan(0));
        expect(e.defaultRepsMax, greaterThanOrEqualTo(e.defaultRepsMin));
      }
    });

    test('exercise names are unique so lookups are unambiguous', () {
      final names = ExerciseLibrary.all.map((e) => e.name.toLowerCase()).toList();
      expect(names.toSet().length, names.length);
    });

    test('lookup by name is case insensitive', () {
      expect(ExerciseLibrary.findByName('barbell bench press')?.muscleGroup, 'Chest');
      expect(ExerciseLibrary.findByName('Not A Real Lift'), isNull);
    });

    test('every exercise resolves a non-empty video query', () {
      for (final e in ExerciseLibrary.all) {
        expect(e.videoQuery, contains(e.name));
        expect(e.videoQuery, contains('3d animation'));
      }
    });

    test('search matches on name, group and equipment', () {
      expect(ExerciseLibrary.search('bench'), isNotEmpty);
      expect(ExerciseLibrary.search('Cable'), isNotEmpty);
      expect(ExerciseLibrary.search('Mobility'), isNotEmpty);
    });
  });

  group('Models', () {
    test('exercise target label collapses an equal rep range', () {
      final fixed = ExerciseDef(
        id: '1',
        dayId: 'd',
        name: 'Plank',
        targetSets: 3,
        targetRepsMin: 30,
        targetRepsMax: 30,
      );
      expect(fixed.targetLabel, '3x30');

      final ranged = fixed.copyWith(targetRepsMax: 45);
      expect(ranged.targetLabel, '3x30-45');
    });

    test('exercise round-trips through its map form', () {
      final ex = ExerciseDef(
        id: 'e1',
        dayId: 'd1',
        name: 'Lat Pulldown',
        targetSets: 4,
        targetRepsMin: 10,
        targetRepsMax: 12,
        targetWeightKg: 40,
        muscleGroup: 'Back',
        orderIndex: 2,
        note: 'slow eccentric',
      );
      final back = ExerciseDef.fromMap(ex.toMap());

      expect(back.name, ex.name);
      expect(back.targetWeightKg, ex.targetWeightKg);
      expect(back.muscleGroup, 'Back');
      expect(back.orderIndex, 2);
      expect(back.note, 'slow eccentric');
    });

    test('set log carries session grouping and computes volume', () {
      final set = SetLog(
        id: 's1',
        sessionExerciseId: 'e1',
        sessionId: 'sess1',
        exerciseName: 'Back Squat',
        setIndex: 1,
        weightKg: 60,
        reps: 10,
        isCompleted: true,
      );

      expect(set.volumeKg, 600);
      final back = SetLog.fromMap(set.toMap());
      expect(back.sessionId, 'sess1');
      expect(back.exerciseName, 'Back Squat');
      expect(back.isCompleted, isTrue);
    });

    test('day copyWith keeps identity, overrides given fields, and carries '
        'warmups/finishers along with exercises', () {
      final day = TrainingDay(
        id: 'd1',
        routineId: 'r1',
        name: 'Push',
        tag: 'MON',
        orderIndex: 0,
        focus: 'Chest',
        note: 'Go slow',
        isRestDay: false,
      );

      final exercises = [
        ExerciseDef(
          id: 'e1',
          dayId: 'd1',
          name: 'Bench Press',
          targetSets: 4,
          targetRepsMin: 8,
          targetRepsMax: 12,
        ),
      ];
      final warmups = [
        WarmupItem(id: 'w1', dayId: 'd1', name: 'Arm circles', amt: '3 min', orderIndex: 0),
      ];
      final finishers = [
        FinisherItem(id: 'f1', dayId: 'd1', name: 'Burpees', amt: '30s', orderIndex: 0),
      ];

      final hydrated = day.copyWith(
        exercises: exercises,
        warmups: warmups,
        finishers: finishers,
      );

      // id and routineId are identity — never copied over, even though
      // copyWith takes no id/routineId parameters to override them with.
      expect(hydrated.id, 'd1');
      expect(hydrated.routineId, 'r1');
      // Fields not passed to copyWith fall back to the original.
      expect(hydrated.name, 'Push');
      expect(hydrated.tag, 'MON');
      expect(hydrated.focus, 'Chest');
      expect(hydrated.note, 'Go slow');
      expect(hydrated.isRestDay, isFalse);
      // The fields that were passed are the ones that change.
      expect(hydrated.exercises, exercises);
      expect(hydrated.warmups, warmups);
      expect(hydrated.finishers, finishers);

      final renamedRestDay = day.copyWith(name: 'Off', isRestDay: true);
      expect(renamedRestDay.name, 'Off');
      expect(renamedRestDay.isRestDay, isTrue);
      // Untouched fields, including the lists, still fall back — copyWith
      // does not silently drop what it wasn't asked to change.
      expect(renamedRestDay.tag, 'MON');
      expect(renamedRestDay.exercises, isEmpty);
    });

    test('session duration label switches to hours past 60 minutes', () {
      SessionLog withDuration(int seconds) => SessionLog(
            id: 'x',
            dayName: 'Push',
            dateStr: '2026-09-07',
            durationSeconds: seconds,
            totalVolumeKg: 100,
            status: 'completed',
          );

      expect(withDuration(45 * 60).durationLabel, '45 min');
      expect(withDuration(95 * 60).durationLabel, '1h 35m');
    });
  });
}
