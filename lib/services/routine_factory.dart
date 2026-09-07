import '../data/exercise_library.dart';
import '../data/routine_templates.dart';
import '../models/models.dart';
import 'database_service.dart';

/// Builds a full routine — days and exercises — from a template.
///
/// Shared so the Routines tab's "New Routine" flow and the Body tab's
/// recommended-plan button create identical data.
class RoutineFactory {
  RoutineFactory._();

  /// Creates the routine and returns its id. When [makeActive] is true (or the
  /// user has no routines yet) it also becomes the routine Today schedules from.
  static Future<String> createFromTemplate({
    required String name,
    required SchedulingMode mode,
    required RoutineTemplate template,
    bool makeActive = false,
  }) async {
    final db = DatabaseService.instance;
    final routineId = DateTime.now().microsecondsSinceEpoch.toString();

    final existing = await db.getRoutines();

    await db.insertRoutine(Routine(
      id: routineId,
      name: name,
      schedulingMode: mode,
      createdAt: DateTime.now().toIso8601String(),
    ).toMap());

    for (var i = 0; i < template.days.length; i++) {
      final td = template.days[i];
      final dayId = '$routineId-d$i';

      await db.insertDay(TrainingDay(
        id: dayId,
        routineId: routineId,
        name: td.name,
        tag: td.tag,
        orderIndex: i,
        focus: td.focus,
      ).toMap());

      for (var j = 0; j < td.warmups.length; j++) {
        await db.insertWarmup(WarmupItem(
          id: '$dayId-w$j',
          dayId: dayId,
          name: td.warmups[j].name,
          amt: td.warmups[j].amt,
          orderIndex: j,
        ).toMap());
      }

      for (var j = 0; j < td.exercises.length; j++) {
        final lib = ExerciseLibrary.findByName(td.exercises[j]);
        if (lib == null) continue;
        await db.insertExercise(ExerciseDef(
          id: '$dayId-e$j',
          dayId: dayId,
          name: lib.name,
          targetSets: lib.defaultSets,
          targetRepsMin: lib.defaultRepsMin,
          targetRepsMax: lib.defaultRepsMax,
          muscleGroup: lib.muscleGroup,
          orderIndex: j,
        ).toMap());
      }

      for (var j = 0; j < td.finishers.length; j++) {
        await db.insertFinisher(FinisherItem(
          id: '$dayId-f$j',
          dayId: dayId,
          name: td.finishers[j].name,
          amt: td.finishers[j].amt,
          orderIndex: j,
        ).toMap());
      }
    }

    if (makeActive || existing.isEmpty) {
      await db.setActiveRoutine(routineId);
    }
    return routineId;
  }
}
