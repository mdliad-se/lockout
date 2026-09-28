import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/widgets/week_day_row.dart';

import 'test_helpers.dart';

TrainingDay _day({
  String id = 'mon',
  String name = 'Legs',
  String tag = 'MON',
  bool rest = false,
  List<ExerciseDef> exercises = const [],
}) =>
    TrainingDay(
      id: id,
      routineId: 'r1',
      name: name,
      tag: tag,
      orderIndex: 0,
      isRestDay: rest,
      exercises: exercises,
    );

ExerciseDef _ex(String name, int sets) => ExerciseDef(
      id: name,
      dayId: 'mon',
      name: name,
      targetSets: sets,
      targetRepsMin: 8,
      targetRepsMax: 12,
    );

void main() {
  group('dayRowSummary', () {
    test('a rest day says Rest', () {
      expect(dayRowSummary(_day(name: 'Off', rest: true)), 'Rest');
    });

    test('a rest day says Rest even if exercise rows are still attached',
        () {
      // Rest is checked before Empty in dayRowSummary; a rest day built with
      // an empty exercise list (as above) can't tell Rest from Empty on its
      // own — only a rest day that also carries exercises proves Rest wins.
      expect(
        dayRowSummary(_day(
          name: 'Off',
          rest: true,
          exercises: [_ex('Leg Press', 4)],
        )),
        'Rest',
      );
    });

    test('a training day with no exercises says Empty', () {
      expect(dayRowSummary(_day()), 'Empty');
    });

    test('a populated day counts exercises and sets', () {
      final day = _day(exercises: [
        _ex('Leg Press', 4),
        _ex('Leg Curl', 3),
      ]);
      expect(dayRowSummary(day), '2 exercises · 7 sets');
    });
  });

  test('a single exercise is not pluralised', () {
    expect(
      dayRowSummary(_day(exercises: [_ex('Leg Press', 4)])),
      '1 exercise · 4 sets',
    );
  });

  group('WeekDayRow', () {
    testWidgets('shows the weekday tag, name and summary', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: lockoutTestTheme(),
        home: Scaffold(
          body: WeekDayRow(
            day: _day(exercises: [_ex('Leg Press', 4)]),
            accent: Colors.green,
            summary: '1 exercise · 4 sets',
            isToday: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('MON'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('1 exercise · 4 sets'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('marks today and reports a tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        theme: lockoutTestTheme(),
        home: Scaffold(
          body: WeekDayRow(
            day: _day(),
            accent: Colors.green,
            summary: 'Empty',
            isToday: true,
            onTap: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('TODAY'), findsOneWidget);
      await tester.tap(find.byType(WeekDayRow));
      expect(tapped, isTrue);
    });
  });
}
