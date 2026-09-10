import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/models/models.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/day_row.dart';

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
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  group('dayRowSummary', () {
    test('a rest day says REST', () {
      expect(dayRowSummary(_day(name: 'Off', rest: true)), 'REST');
    });

    test('a training day with no exercises says EMPTY', () {
      expect(dayRowSummary(_day()), 'EMPTY');
    });

    test('a populated day counts exercises and sets', () {
      final day = _day(exercises: [
        _ex('Leg Press', 4),
        _ex('Leg Curl', 3),
      ]);
      expect(dayRowSummary(day), '2 EX - 7 SETS');
    });
  });

  group('DayRow', () {
    testWidgets('shows the weekday tag, name and summary', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayRow(
            day: _day(exercises: [_ex('Leg Press', 4)]),
            accent: Colors.green,
            summary: '1 EX - 4 SETS',
            isToday: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('MON'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('1 EX - 4 SETS'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('marks today and reports a tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayRow(
            day: _day(),
            accent: Colors.green,
            summary: 'EMPTY',
            isToday: true,
            onTap: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('TODAY'), findsOneWidget);
      await tester.tap(find.byType(DayRow));
      expect(tapped, isTrue);
    });
  });
}
