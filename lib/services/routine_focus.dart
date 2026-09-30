import '../models/models.dart';
import 'schedule_service.dart';

/// Why a day is being featured.
enum FeaturedDayKind {
  /// A weekday routine, and this is the day pinned to today's weekday.
  today,

  /// A rotating routine, where "today" is a position in a cycle rather than a
  /// weekday, so the card reads NEXT.
  next,
}

/// What a routine card should lead with.
///
/// [day] is null when the routine is worth featuring but has nothing scheduled
/// right now — a gap in the week, or a rotation that has not started. That is
/// a different answer from "do not feature anything", which `resolve` signals
/// by returning null outright.
class RoutineFocusResult {
  final TrainingDay? day;
  final FeaturedDayKind kind;

  const RoutineFocusResult({required this.day, required this.kind});
}

/// Decides which single day a routine card leads with.
///
/// Pure and synchronous: `RoutinesTab` already holds every day in memory, so
/// going back to sqflite per card would be a read per routine per rebuild.
///
/// It reuses `ScheduleService`'s own matchers rather than reimplementing them.
/// A card that featured a different day than the one START SESSION would open
/// is worse than no card at all, and two copies of the weekday/rotation rules
/// would drift the first time either changed.
class RoutineFocus {
  RoutineFocus._();

  static RoutineFocusResult? resolve({
    required Routine routine,
    required List<TrainingDay> days,
    required DateTime now,
    required bool isActive,
  }) {
    // "Today" is only meaningful for the routine actually being followed. An
    // inactive routine opens straight to its collapsed week.
    if (!isActive) return null;
    if (days.isEmpty) return null;

    if (routine.schedulingMode == SchedulingMode.weekday) {
      return RoutineFocusResult(
        day: ScheduleService.matchByWeekday(days, now),
        kind: FeaturedDayKind.today,
      );
    }

    return RoutineFocusResult(
      day: ScheduleService.matchByRotation(days, routine, now),
      kind: FeaturedDayKind.next,
    );
  }
}
