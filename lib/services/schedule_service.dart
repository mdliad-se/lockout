import 'package:flutter/foundation.dart' show visibleForTesting;

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

    // A calendar difference, never `_midnight(date).difference(...).inDays`:
    // across a spring-forward 191 wall-clock hours is 8 calendar days but
    // floors to 7, which would advance the cycle to the wrong day and leave
    // it a slot behind for the rest of the routine's life.
    final elapsed = calendarDay(date) - calendarDay(start);
    if (elapsed < 0) return null;

    final sorted = [...days]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted[elapsed % sorted.length];
  }

  /// Calendar-day ordinal for [d], derived from its year/month/day fields
  /// alone (Howard Hinnant's `days_from_civil`) rather than from wall-clock
  /// subtraction.
  ///
  /// Two local midnights are not reliably 24h apart: across a spring-
  /// forward transition they are 23h apart, so `Duration.inDays` floors
  /// that to 0; across a fall-back they are 47h apart, so a genuine 2-day
  /// gap floors to 1. Differencing this ordinal instead is exact on every
  /// host regardless of DST.
  @visibleForTesting
  static int dayNumber(DateTime d) {
    final m = d.month;
    final y = m <= 2 ? d.year - 1 : d.year;
    final era = (y >= 0 ? y : y - 399) ~/ 400;
    final yoe = y - era * 400; // [0, 399]
    final doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) ~/ 5 + d.day - 1; // [0, 365]
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy; // [0, 146096]
    return era * 146097 + doe - 719468;
  }

  /// How a `DateTime` is reduced to a calendar-day ordinal.
  ///
  /// Always [dayNumber] in production, and the only reason it is a mutable
  /// field rather than a direct call is that the hazard [dayNumber] exists
  /// to defeat cannot be reproduced on a host whose timezone has no DST
  /// transition: there, every pair of local midnights makes a calendar
  /// difference and `Duration.inDays` agree, so no real `DateTime` can
  /// demonstrate which of the two a day-difference below was computed
  /// with. Substituting a deliberately skewed calendar can. Tests that
  /// replace it must restore it in a `tearDown`.
  @visibleForTesting
  static int Function(DateTime) calendarDay = dayNumber;

  /// Consecutive-day training streak ending today or yesterday.
  ///
  /// Rule: the newest logged date must be *today or yesterday* — a gap of
  /// two or more days (i.e. the newest session is two-plus days old) breaks
  /// the streak to 0. Yesterday still counts as live so the streak is not
  /// reported broken during the hours before today's session; today not
  /// having a session yet does not itself break anything. Multiple
  /// sessions on the same calendar day collapse to a single day via the
  /// `toSet()` below, so training twice in one day does not advance the
  /// count by two. Dates *ahead* of today — clock skew, or a backup
  /// restored from a device in a later timezone — are dropped before
  /// anything is counted: a session that has not happened cannot hold a
  /// dead streak open, nor sit inside a live one and inflate it.
  ///
  /// Every comparison is between [calendarDay] ordinals rather than
  /// `Duration`s, because two local midnights are not reliably 24h apart
  /// across a DST transition — see [dayNumber].
  static int currentStreakDays(List<String> workoutDates) {
    if (workoutDates.isEmpty) return 0;

    final todayNumber = calendarDay(DateTime.now());
    final days = workoutDates
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map(calendarDay)
        .where((n) => n <= todayNumber)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (days.isEmpty) return 0;
    if (todayNumber - days.first > 1) return 0;

    var streak = 1;
    for (var i = 0; i < days.length - 1; i++) {
      if (days[i] - days[i + 1] == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
