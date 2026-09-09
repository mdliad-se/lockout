import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/services/energy_estimator.dart';

SetLog _set(String exerciseName, {int index = 1}) => SetLog(
      id: '$exerciseName-$index',
      sessionExerciseId: 'ex',
      sessionId: 's1',
      exerciseName: exerciseName,
      setIndex: index,
      weightKg: 30.0,
      reps: 10,
      isCompleted: true,
    );

void main() {
  group('metForGroup', () {
    test('cardio is the most expensive family', () {
      expect(EnergyEstimator.metForGroup('Cardio'), 8.0);
    });

    test('multi-joint lower body outranks upper compound', () {
      expect(
        EnergyEstimator.metForGroup('Legs'),
        greaterThan(EnergyEstimator.metForGroup('Chest')),
      );
      expect(EnergyEstimator.metForGroup('Legs'), 6.0);
      expect(EnergyEstimator.metForGroup('Glutes'), 6.0);
      expect(EnergyEstimator.metForGroup('Full Body'), 6.0);
    });

    test('upper compound sits at 5.0', () {
      expect(EnergyEstimator.metForGroup('Chest'), 5.0);
      expect(EnergyEstimator.metForGroup('Back'), 5.0);
      expect(EnergyEstimator.metForGroup('Shoulders'), 5.0);
    });

    test('core is calisthenic', () {
      expect(EnergyEstimator.metForGroup('Core'), 4.5);
    });

    test('isolation work is the cheapest', () {
      expect(EnergyEstimator.metForGroup('Biceps'), 3.5);
      expect(EnergyEstimator.metForGroup('Triceps'), 3.5);
      expect(EnergyEstimator.metForGroup('Calves'), 3.5);
      expect(EnergyEstimator.metForGroup('Forearms'), 3.5);
    });

    test('an unknown group falls back to the resistance default', () {
      expect(EnergyEstimator.metForGroup('Interpretive Dance'), 5.0);
      expect(EnergyEstimator.metForGroup(''), 5.0);
    });
  });

  group('dominantGroup', () {
    test('picks the group with the most sets', () {
      final sets = [
        _set('Leg Press', index: 1),
        _set('Leg Press', index: 2),
        _set('Leg Press', index: 3),
        _set('Plank', index: 1),
      ];
      expect(
        EnergyEstimator.dominantGroup(sets: sets, dayName: 'MON - Legs'),
        'Legs',
      );
    });

    test('falls back to the day name when no set resolves', () {
      final sets = [_set('Freestyle Nonsense Lift')];
      expect(
        EnergyEstimator.dominantGroup(sets: sets, dayName: 'Leg Day'),
        'Legs',
      );
      expect(
        EnergyEstimator.dominantGroup(sets: sets, dayName: 'Push'),
        'Chest',
      );
      expect(
        EnergyEstimator.dominantGroup(sets: const [], dayName: 'Cardio Blast'),
        'Cardio',
      );
    });

    test('an unrecognisable day name yields the resistance default', () {
      expect(
        EnergyEstimator.dominantGroup(sets: const [], dayName: 'Session 4'),
        '',
      );
    });
  });

  group('kcal', () {
    test('matches the MET formula', () {
      // 6.0 MET, 72.5 kg, 51 min -> 6.0 * 3.5 * 72.5 / 200 * 51
      final v = EnergyEstimator.kcal(
        met: 6.0,
        bodyweightKg: 72.5,
        durationSeconds: 51 * 60,
      );
      expect(v, closeTo(388.7, 0.5));
    });

    test('scales linearly with duration and weight', () {
      final base = EnergyEstimator.kcal(
        met: 5.0,
        bodyweightKg: 80.0,
        durationSeconds: 1800,
      );
      final twiceTime = EnergyEstimator.kcal(
        met: 5.0,
        bodyweightKg: 80.0,
        durationSeconds: 3600,
      );
      final twiceWeight = EnergyEstimator.kcal(
        met: 5.0,
        bodyweightKg: 160.0,
        durationSeconds: 1800,
      );
      expect(twiceTime, closeTo(base * 2, 0.001));
      expect(twiceWeight, closeTo(base * 2, 0.001));
    });

    test('zero duration costs nothing', () {
      expect(
        EnergyEstimator.kcal(met: 6.0, bodyweightKg: 70, durationSeconds: 0),
        0.0,
      );
    });
  });

  group('estimate', () {
    test('produces a value from sets, weight and duration', () {
      final v = EnergyEstimator.estimate(
        sets: [_set('Leg Press'), _set('Leg Press', index: 2)],
        dayName: 'MON - Legs',
        bodyweightKg: 72.5,
        durationSeconds: 51 * 60,
      );
      expect(v, isNotNull);
      expect(v!, closeTo(388.7, 0.5));
    });

    test('returns null without a bodyweight', () {
      expect(
        EnergyEstimator.estimate(
          sets: [_set('Leg Press')],
          dayName: 'Legs',
          bodyweightKg: null,
          durationSeconds: 3060,
        ),
        isNull,
      );
    });

    test('returns null for a zero-length session', () {
      expect(
        EnergyEstimator.estimate(
          sets: [_set('Leg Press')],
          dayName: 'Legs',
          bodyweightKg: 72.5,
          durationSeconds: 0,
        ),
        isNull,
      );
    });

    test('a nonsense bodyweight is rejected rather than trusted', () {
      expect(
        EnergyEstimator.estimate(
          sets: [_set('Leg Press')],
          dayName: 'Legs',
          bodyweightKg: 0.0,
          durationSeconds: 3060,
        ),
        isNull,
      );
    });
  });

  group('SessionLog.kcalBurned', () {
    test('defaults to zero and round-trips through its map form', () {
      final log = SessionLog(
        id: 's1',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
        totalSets: 22,
      );
      expect(log.kcalBurned, 0.0);

      final withBurn = SessionLog(
        id: 's2',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
        totalSets: 22,
        kcalBurned: 388.7,
      );
      final back = SessionLog.fromMap(withBurn.toMap());
      expect(back.kcalBurned, closeTo(388.7, 0.001));
    });

    test('a row written before the migration reads as zero', () {
      final legacy = {
        'id': 's3',
        'day_name': 'MON - Legs',
        'date_str': '2026-09-07',
        'duration_seconds': 3060,
        'total_volume_kg': 2295.0,
        'status': 'completed',
        'routine_id': '',
        'day_id': '',
        'total_sets': 22,
      };
      expect(SessionLog.fromMap(legacy).kcalBurned, 0.0);
    });

    test('the label marks the value as an estimate', () {
      final log = SessionLog(
        id: 's4',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
        kcalBurned: 388.7,
      );
      expect(log.kcalLabel, '~389 kcal');
    });

    test('no burn means no label rather than a zero', () {
      final log = SessionLog(
        id: 's5',
        dayName: 'MON - Legs',
        dateStr: '2026-09-07',
        durationSeconds: 3060,
        totalVolumeKg: 2295.0,
        status: 'completed',
      );
      expect(log.kcalLabel, '');
    });
  });
}
