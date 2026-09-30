import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/widgets/day_block.dart';

TrainingDay _day(
  String id,
  String name, {
  String focus = '',
  bool rest = false,
  int order = 0,
}) =>
    TrainingDay(
      id: id,
      routineId: 'r1',
      name: name,
      tag: id,
      orderIndex: order,
      focus: focus,
      isRestDay: rest,
    );

/// A fixture ramp rather than a real [LockoutScheme]: none of the six
/// authored schemes happens to collide an accent with `restDay` (that
/// collision was specific to the retired Paper Press palette), so a synthetic
/// scheme is what keeps the "never hand a training day the rest colour, even
/// once the ramp saturates" guarantee under test regardless of what the
/// authored schemes look like.
const _semantics = LockoutSemantics(
  success: Color(0xFF2E7D32),
  onSuccess: Color(0xFFFFFFFF),
  warning: Color(0xFF8A6100),
  danger: Color(0xFFB3261E),
  restDay: Color(0xFFFFE24A),
  chartLine: Color(0xFF2E7D32),
  chartFill: Color(0x1F2E7D32),
  categoryRamp: [
    Color(0xFFFF6B35),
    // Deliberately bit-identical to restDay, so a saturated ramp still
    // cannot hand a training day the rest colour by coincidence.
    Color(0xFFFFE24A),
    Color(0xFF00A99D),
    Color(0xFF7B61FF),
    Color(0xFFFF3D71),
    Color(0xFF2ECC71),
    Color(0xFF3498DB),
    Color(0xFFE67E22),
  ],
);

/// The exact week from the bug report.
List<TrainingDay> _reportedWeek() => [
      _day('sat', 'Push', focus: 'Chest, Shoulders, Triceps', order: 0),
      _day('sun', 'Pull', focus: 'Back, Biceps', order: 1),
      _day('mon', 'Legs', focus: 'Legs', order: 2),
      _day('tue', 'Rest', rest: true, order: 3),
      _day('wed', 'Upper Body + Core', focus: 'Upper Body', order: 4),
      _day('thu', 'Upper Body', focus: 'Upper-focused, light hip-hinge', order: 5),
      _day('fri', 'Off', rest: true, order: 6),
    ];

void main() {
  group('DayColours.assign', () {
    test('every day in the list gets a colour', () {
      final colours = DayColours.assign(_reportedWeek(), _semantics);
      expect(colours.length, 7);
      for (final d in _reportedWeek()) {
        expect(colours.containsKey(d.id), isTrue, reason: d.id);
      }
    });

    test('the reported WED/THU collision is gone', () {
      final colours = DayColours.assign(_reportedWeek(), _semantics);
      expect(colours['wed'], isNot(colours['thu']));
    });

    test('all training days in a week are distinct', () {
      final colours = DayColours.assign(_reportedWeek(), _semantics);
      final training = _reportedWeek().where((d) => !d.isRestDay);
      final used = training.map((d) => colours[d.id]).toList();
      expect(used.toSet().length, used.length);
    });

    test('rest days take the muted surface and consume no accent', () {
      final week = _reportedWeek();
      final colours = DayColours.assign(week, _semantics);
      expect(colours['tue'], _semantics.restDay);
      expect(colours['fri'], _semantics.restDay);

      // The fixture ramp has eight slots, one of them reserved because it
      // equals restDay — so seven stay available to the week's five
      // training days and none of them has to reuse a colour.
      final training = week.where((d) => !d.isRestDay);
      final used = training.map((d) => colours[d.id]).toSet();
      expect(used.contains(_semantics.restDay), isFalse);
    });

    test('a day keeps its category colour when nothing else claims it', () {
      final colours = DayColours.assign(_reportedWeek(), _semantics);
      expect(
        colours['sat'],
        _semantics.categoryAt(DayColours.categoryOf(
          _day('sat', 'Push', focus: 'Chest, Shoulders, Triceps'),
        )),
      );
    });

    test('assignment is deterministic across calls', () {
      final a = DayColours.assign(_reportedWeek(), _semantics);
      final b = DayColours.assign(_reportedWeek(), _semantics);
      expect(a, b);
    });

    test('more than eight training days wraps instead of throwing', () {
      final days = List.generate(
        11,
        (i) => _day('d$i', 'Session $i', focus: 'Full Body', order: i),
      );
      final colours = DayColours.assign(days, _semantics);
      expect(colours.length, 11);
    });

    test('two routines each start from their own category colour', () {
      final routineA = [_day('a1', 'Legs', focus: 'Legs')];
      final routineB = [_day('b1', 'Legs', focus: 'Legs')];
      expect(
        DayColours.assign(routineA, _semantics)['a1'],
        DayColours.assign(routineB, _semantics)['b1'],
      );
    });

    // categoryRamp[1] is bit-identical to restDay in this fixture. Once the
    // ramp saturates, an overflow day must still never land on it.
    List<TrainingDay> _nineDayOverflowWeek() => [
          _day('d0', 'Push', focus: 'Chest', order: 0),
          _day('d1', 'Pull', focus: 'Back', order: 1),
          _day('d2', 'Legs', focus: 'Legs', order: 2),
          _day('d3', 'Shoulders', focus: 'Delts', order: 3),
          _day('d4', 'Arms', focus: 'Triceps', order: 4),
          _day('d5', 'Upper Body', focus: 'Upper', order: 5),
          _day('d6', 'Push', focus: 'Chest', order: 6),
          _day('d7', 'Pull', focus: 'Back', order: 7),
          _day('d8', 'Legs', focus: 'Legs', order: 8),
        ];

    test('a 9-day week never hands a training day the rest colour, even '
        'once the ramp saturates', () {
      final colours = DayColours.assign(_nineDayOverflowWeek(), _semantics);
      for (final day in _nineDayOverflowWeek()) {
        expect(colours[day.id], isNot(_semantics.restDay), reason: day.id);
      }
    });

    test('the same 9-day week assigns identically on repeat calls', () {
      final a = DayColours.assign(_nineDayOverflowWeek(), _semantics);
      final b = DayColours.assign(_nineDayOverflowWeek(), _semantics);
      expect(a, b);
    });

    test('a 7-training-day week fills every non-reserved slot distinctly', () {
      final week = [
        _day('e0', 'Push', focus: 'Chest', order: 0),
        _day('e1', 'Pull', focus: 'Back', order: 1),
        _day('e2', 'Legs', focus: 'Legs', order: 2),
        _day('e3', 'Shoulders', focus: 'Delts', order: 3),
        _day('e4', 'Arms', focus: 'Triceps', order: 4),
        _day('e5', 'Upper Body', focus: 'Upper', order: 5),
        _day('e6', 'Push', focus: 'Chest', order: 6),
      ];
      final colours = DayColours.assign(week, _semantics);
      final used = week.map((d) => colours[d.id]).toList();
      expect(used.toSet().length, 7);
      expect(used.contains(_semantics.restDay), isFalse);
    });
  });

  group('DayColours.categoryOf', () {
    test('recognises the six session families', () {
      expect(DayColours.categoryOf(_day('1', 'Push', focus: 'Chest')), 0);
      expect(DayColours.categoryOf(_day('2', 'Pull', focus: 'Back')), 1);
      expect(DayColours.categoryOf(_day('3', 'Legs', focus: 'Quads')), 2);
      expect(DayColours.categoryOf(_day('4', 'Shoulders', focus: 'Delts')), 3);
      expect(DayColours.categoryOf(_day('5', 'Arms', focus: 'Triceps')), 4);
      expect(DayColours.categoryOf(_day('6', 'Upper Body', focus: 'Upper')), 5);
    });

    test('an unrecognised name still returns a stable category', () {
      final d = _day('7', 'Conditioning', focus: 'Mixed');
      expect(DayColours.categoryOf(d), DayColours.categoryOf(d));
      expect(DayColours.categoryOf(d), inInclusiveRange(0, 5));
    });
  });

  group('DayColours.onColorFor', () {
    test('a light background gets a darker foreground', () {
      const yellow = Color(0xFFFFE24A);
      final on = DayColours.onColorFor(yellow);
      expect(on.computeLuminance(), lessThan(yellow.computeLuminance()));
    });

    test('a dark background gets a lighter foreground', () {
      const navy = Color(0xFF101419);
      final on = DayColours.onColorFor(navy);
      expect(on.computeLuminance(), greaterThan(navy.computeLuminance()));
    });
  });
}
