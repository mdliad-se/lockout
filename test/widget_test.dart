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
    String key(DateTime d) => ScheduleService.dateKey(d);

    test('consecutive days ending today count', () {
      final now = DateTime.now();
      final dates = [
        key(now),
        key(now.subtract(const Duration(days: 1))),
        key(now.subtract(const Duration(days: 2))),
      ];
      expect(ScheduleService.currentStreakDays(dates), 3);
    });

    test('a streak ending yesterday is still live', () {
      final now = DateTime.now();
      final dates = [
        key(now.subtract(const Duration(days: 1))),
        key(now.subtract(const Duration(days: 2))),
      ];
      expect(ScheduleService.currentStreakDays(dates), 2);
    });

    test('a gap of two days breaks the streak', () {
      final now = DateTime.now();
      final dates = [key(now.subtract(const Duration(days: 3)))];
      expect(ScheduleService.currentStreakDays(dates), 0);
    });

    test('no history means no streak', () {
      expect(ScheduleService.currentStreakDays([]), 0);
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
