import '../models/models.dart';
import 'database_service.dart';

/// What the Today tab should show for a given date.
class ScheduledDay {
  final Routine routine;
  final TrainingDay day;
  final List<ExerciseDef> exercises;

  const ScheduledDay({
    required this.routine,
    required this.day,
    required this.exercises,
  });
}

/// Resolves "what am I training today" from the active routine.
///
/// Two scheduling modes:
///  * [SchedulingMode.weekday]  — a day's `tag` is a weekday code (SAT..FRI);
///    today matches when the tag equals today's code. Days with no matching
///    tag are simply rest days.
///  * [SchedulingMode.rotating] — days cycle in `orderIndex` order regardless
///    of weekday, advancing one slot per calendar day since the routine was
///    created.
class ScheduleService {
  ScheduleService._();

  /// Index-aligned with `DateTime.weekday` (1 = Monday .. 7 = Sunday).
  static const List<String> _weekdayCodes = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  /// Display order used by the routine builder's day picker.
  static const List<String> weekdayPickerOrder = [
    'SAT',
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
  ];

  static String weekdayCode(DateTime date) => _weekdayCodes[date.weekday - 1];

  static String dateKey(DateTime date) =>
      date.toIso8601String().split('T').first;

  /// The scheduled workout for [date], or null on a rest day / empty setup.
  static Future<ScheduledDay?> resolveFor(DateTime date) async {
    final db = DatabaseService.instance;

    final routineRow = await db.getActiveRoutine();
    if (routineRow == null) return null;
    final routine = Routine.fromMap(routineRow);

    final dayRows = await db.getDaysForRoutine(routine.id);
    if (dayRows.isEmpty) return null;
    final days = dayRows.map(TrainingDay.fromMap).toList();

    final TrainingDay? match = routine.schedulingMode == SchedulingMode.weekday
        ? _matchByWeekday(days, date)
        : _matchByRotation(days, routine, date);

    if (match == null) return null;

    final exRows = await db.getExercisesForDay(match.id);
    return ScheduledDay(
      routine: routine,
      day: match,
      exercises: exRows.map(ExerciseDef.fromMap).toList(),
    );
  }

  static Future<ScheduledDay?> resolveToday() => resolveFor(DateTime.now());

  static TrainingDay? _matchByWeekday(List<TrainingDay> days, DateTime date) {
    final code = weekdayCode(date);
    for (final d in days) {
      if (d.tag.trim().toUpperCase() == code) return d;
    }
    return null;
  }

  static TrainingDay? _matchByRotation(
    List<TrainingDay> days,
    Routine routine,
    DateTime date,
  ) {
    final start = DateTime.tryParse(routine.createdAt);
    if (start == null) return days.first;

    final elapsed = _midnight(date).difference(_midnight(start)).inDays;
    if (elapsed < 0) return null;

    final sorted = [...days]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted[elapsed % sorted.length];
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Consecutive-day training streak ending today or yesterday.
  ///
  /// Yesterday still counts so a streak is not reported as broken during the
  /// hours before today's session.
  static int currentStreakDays(List<String> workoutDates) {
    if (workoutDates.isEmpty) return 0;

    final days = workoutDates
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map(_midnight)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = _midnight(DateTime.now());
    final gapToNewest = today.difference(days.first).inDays;
    if (gapToNewest > 1) return 0;

    var streak = 1;
    for (var i = 0; i < days.length - 1; i++) {
      if (days[i].difference(days[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
