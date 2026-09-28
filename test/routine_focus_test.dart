import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/services/routine_focus.dart';
import 'package:lockout/services/schedule_service.dart';

Routine _routine({
  SchedulingMode mode = SchedulingMode.weekday,
  String createdAt = '2026-01-01T00:00:00.000',
}) {
  return Routine(
    id: 'r1',
    name: 'Push Pull Legs',
    schedulingMode: mode,
    createdAt: createdAt,
  );
}

TrainingDay _day(
  String id,
  String tag, {
  int order = 0,
  bool rest = false,
}) {
  return TrainingDay(
    id: id,
    routineId: 'r1',
    name: 'Day $tag',
    tag: tag,
    orderIndex: order,
    isRestDay: rest,
  );
}

void main() {
  // A fixed Monday, so the suite does not start failing on a Tuesday.
  final monday = DateTime(2026, 9, 28);

  test('an active weekday routine features today, labelled today', () {
    final days = [_day('d1', 'MON'), _day('d2', 'WED', order: 1)];

    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result, isNotNull);
    expect(result!.day!.id, 'd1');
    expect(result.kind, FeaturedDayKind.today);
  });

  test('the weekday match is case- and whitespace-insensitive, like the '
      'scheduler', () {
    final days = [_day('d1', ' mon ')];

    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result!.day!.id, 'd1');
  });

  test('a rest day scheduled today is still featured', () {
    final days = [_day('d1', 'MON', rest: true)];

    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result!.day, isNotNull);
    expect(result.day!.isRestDay, isTrue);
    expect(result.kind, FeaturedDayKind.today);
  });

  test('a gap in the week features nothing but still resolves', () {
    final days = [_day('d1', 'WED'), _day('d2', 'FRI', order: 1)];

    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result, isNotNull, reason: 'the card still leads with something');
    expect(result!.day, isNull, reason: 'nothing scheduled today');
    expect(result.kind, FeaturedDayKind.today);
  });

  test('a rotating routine features the next slot, labelled next', () {
    final routine = _routine(mode: SchedulingMode.rotating);
    final days = [
      _day('d1', 'A', order: 0),
      _day('d2', 'B', order: 1),
      _day('d3', 'C', order: 2),
    ];

    final result = RoutineFocus.resolve(
      routine: routine,
      days: days,
      now: monday,
      isActive: true,
    );

    expect(result!.kind, FeaturedDayKind.next);
    expect(
      result.day!.id,
      ScheduleService.matchByRotation(days, routine, monday)!.id,
      reason: 'the card must feature the day START SESSION would actually '
          'open, not a second opinion about it',
    );
  });

  test('an inactive routine features nothing at all', () {
    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: [_day('d1', 'MON')],
      now: monday,
      isActive: false,
    );

    expect(
      result,
      isNull,
      reason: '"today" is only meaningful for the routine being followed',
    );
  });

  test('a routine with no days features nothing at all', () {
    final result = RoutineFocus.resolve(
      routine: _routine(),
      days: const [],
      now: monday,
      isActive: true,
    );

    expect(result, isNull);
  });

  test('a rotating routine created in the future features nothing', () {
    final routine = _routine(
      mode: SchedulingMode.rotating,
      createdAt: '2027-01-01T00:00:00.000',
    );

    final result = RoutineFocus.resolve(
      routine: routine,
      days: [_day('d1', 'A')],
      now: monday,
      isActive: true,
    );

    expect(result!.day, isNull, reason: 'the cycle has not started yet');
    expect(result.kind, FeaturedDayKind.next);
  });
}
