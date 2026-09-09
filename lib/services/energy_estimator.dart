import '../data/exercise_library.dart';
import '../models/models.dart';

/// Estimated energy cost of a training session.
///
/// Uses the standard MET relation
///
///     kcal = MET * 3.5 * bodyweightKg / 200 * minutes
///
/// with the MET taken from the session's dominant muscle group, because a leg
/// day and an arms day of equal length do not cost the same. Values are
/// estimates and every caller renders them with a `~` prefix.
class EnergyEstimator {
  EnergyEstimator._();

  /// MET per muscle group, from the Compendium of Physical Activities'
  /// resistance-training entries.
  static const Map<String, double> metByGroup = {
    'Cardio': 8.0,
    'Legs': 6.0,
    'Glutes': 6.0,
    'Full Body': 6.0,
    'Chest': 5.0,
    'Back': 5.0,
    'Shoulders': 5.0,
    'Core': 4.5,
    'Biceps': 3.5,
    'Triceps': 3.5,
    'Calves': 3.5,
    'Forearms': 3.5,
    'Mobility': 2.5,
  };

  /// General resistance training, used when the group is unknown. Deliberately
  /// mid-range: an unknown session should not be flattered or penalised.
  static const double defaultMet = 5.0;

  static double metForGroup(String muscleGroup) =>
      metByGroup[muscleGroup] ?? defaultMet;

  /// The muscle group that accounts for the most sets in [sets].
  ///
  /// Falls back to keyword matching on [dayName] when no exercise resolves —
  /// ad-hoc sessions and sessions logged before the exercise library covered
  /// an exercise both land here. Returns `''` when neither source says
  /// anything, which [metForGroup] turns into [defaultMet].
  static String dominantGroup({
    required List<SetLog> sets,
    required String dayName,
  }) {
    final counts = <String, int>{};
    for (final s in sets) {
      final def = ExerciseLibrary.findByName(s.exerciseName);
      if (def == null || def.muscleGroup.isEmpty) continue;
      counts[def.muscleGroup] = (counts[def.muscleGroup] ?? 0) + 1;
    }

    if (counts.isNotEmpty) {
      // Ties break on the library's group order, so the result is stable.
      var best = '';
      var bestCount = -1;
      for (final group in ExerciseLibrary.muscleGroups) {
        final c = counts[group] ?? 0;
        if (c > bestCount) {
          best = group;
          bestCount = c;
        }
      }
      if (bestCount > 0) return best;
    }

    return _groupFromDayName(dayName);
  }

  static String _groupFromDayName(String dayName) {
    final key = dayName.toLowerCase();
    if (key.contains('cardio') || key.contains('run') || key.contains('hiit')) {
      return 'Cardio';
    }
    if (key.contains('leg') || key.contains('lower') || key.contains('quad')) {
      return 'Legs';
    }
    if (key.contains('glute') || key.contains('hip')) return 'Glutes';
    if (key.contains('full') || key.contains('upper')) return 'Full Body';
    if (key.contains('push') || key.contains('chest')) return 'Chest';
    if (key.contains('pull') || key.contains('back')) return 'Back';
    if (key.contains('shoulder') || key.contains('delt')) return 'Shoulders';
    if (key.contains('core') || key.contains('abs')) return 'Core';
    if (key.contains('arm') || key.contains('bicep') || key.contains('tricep')) {
      return 'Biceps';
    }
    return '';
  }

  static double kcal({
    required double met,
    required double bodyweightKg,
    required int durationSeconds,
  }) {
    final minutes = durationSeconds / 60.0;
    return met * 3.5 * bodyweightKg / 200.0 * minutes;
  }

  /// Null when no honest estimate is possible: no bodyweight on record, or a
  /// session with no measured duration. A missing number is better than a
  /// fabricated one.
  static double? estimate({
    required List<SetLog> sets,
    required String dayName,
    required double? bodyweightKg,
    required int durationSeconds,
  }) {
    if (bodyweightKg == null || bodyweightKg <= 0) return null;
    if (durationSeconds <= 0) return null;

    final group = dominantGroup(sets: sets, dayName: dayName);
    return kcal(
      met: metForGroup(group),
      bodyweightKg: bodyweightKg,
      durationSeconds: durationSeconds,
    );
  }
}
