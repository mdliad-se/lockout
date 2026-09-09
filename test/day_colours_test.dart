import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';
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
  setUp(() => AppPalette.apply(AppPalette.paperPress));

  group('DayColours.assign', () {
    test('every day in the list gets a colour', () {
      final colours = DayColours.assign(_reportedWeek());
      expect(colours.length, 7);
      for (final d in _reportedWeek()) {
        expect(colours.containsKey(d.id), isTrue, reason: d.id);
      }
    });

    test('the reported WED/THU collision is gone', () {
      final colours = DayColours.assign(_reportedWeek());
      expect(colours['wed'], isNot(colours['thu']));
    });

    test('all training days in a week are distinct', () {
      final colours = DayColours.assign(_reportedWeek());
      final training = _reportedWeek().where((d) => !d.isRestDay);
      final used = training.map((d) => colours[d.id]).toList();
      expect(used.toSet().length, used.length);
    });

    test('rest days take the muted surface and consume no accent', () {
      final week = _reportedWeek();
      final colours = DayColours.assign(week);
      expect(colours['tue'], DayColours.restColour);
      expect(colours['fri'], DayColours.restColour);

      // Five accents remain available to five training days, so a week of
      // five training days never has to reuse one.
      final training = week.where((d) => !d.isRestDay);
      final used = training.map((d) => colours[d.id]).toSet();
      expect(used.contains(DayColours.restColour), isFalse);
    });

    test('a day keeps its category colour when nothing else claims it', () {
      final colours = DayColours.assign(_reportedWeek());
      expect(colours['sat'], JinatraTokens.accentAt(DayColours.categoryOf(
        _day('sat', 'Push', focus: 'Chest, Shoulders, Triceps'),
      )));
    });

    test('assignment is deterministic across calls', () {
      final a = DayColours.assign(_reportedWeek());
      final b = DayColours.assign(_reportedWeek());
      expect(a, b);
    });

    test('more than eight training days wraps instead of throwing', () {
      final days = List.generate(
        11,
        (i) => _day('d$i', 'Session $i', focus: 'Full Body', order: i),
      );
      final colours = DayColours.assign(days);
      expect(colours.length, 11);
    });

    test('two routines each start from their own category colour', () {
      final routineA = [_day('a1', 'Legs', focus: 'Legs')];
      final routineB = [_day('b1', 'Legs', focus: 'Legs')];
      expect(
        DayColours.assign(routineA)['a1'],
        DayColours.assign(routineB)['b1'],
      );
    });

    // Paper Press's accents[1] (#FFE24A) is bit-identical to restColour. Once
    // the ramp saturates, an overflow day must still never land on it.
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
      AppPalette.apply(AppPalette.paperPress);
      final colours = DayColours.assign(_nineDayOverflowWeek());
      for (final day in _nineDayOverflowWeek()) {
        expect(colours[day.id], isNot(DayColours.restColour), reason: day.id);
      }
    });

    test('the same 9-day week assigns identically on repeat calls', () {
      AppPalette.apply(AppPalette.paperPress);
      final a = DayColours.assign(_nineDayOverflowWeek());
      final b = DayColours.assign(_nineDayOverflowWeek());
      expect(a, b);
    });

    test('a 7-training-day week fills every non-reserved slot distinctly', () {
      AppPalette.apply(AppPalette.paperPress);
      final week = [
        _day('e0', 'Push', focus: 'Chest', order: 0),
        _day('e1', 'Pull', focus: 'Back', order: 1),
        _day('e2', 'Legs', focus: 'Legs', order: 2),
        _day('e3', 'Shoulders', focus: 'Delts', order: 3),
        _day('e4', 'Arms', focus: 'Triceps', order: 4),
        _day('e5', 'Upper Body', focus: 'Upper', order: 5),
        _day('e6', 'Push', focus: 'Chest', order: 6),
      ];
      final colours = DayColours.assign(week);
      final used = week.map((d) => colours[d.id]).toList();
      expect(used.toSet().length, 7);
      expect(used.contains(DayColours.restColour), isFalse);
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
    test('delegates to the token contrast rule', () {
      const yellow = Color(0xFFFFE24A);
      expect(DayColours.onColorFor(yellow),
          JinatraTokens.onAccentColor(yellow));
    });
  });
}
