import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/routines_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';

import 'test_helpers.dart';

/// Direct coverage for `RoutinesTab`, which had zero widget coverage before
/// this fix wave: the day-detail sheet's `refreshAfter` staleness guard, the
/// EDIT DAY sheet-pop, and the drag-does-not-reset-typed-state regression
/// from Task 8's review (every sheet form used to build its
/// `TextEditingController`s and local form state inside the builder passed
/// to `showJinatraSheet`, so a drag that only rebuilt the sheet's own
/// drag-handling state — without dismissing it — silently reset them).
///
/// Same in-memory-DB seam as `today_tab_test.dart`: a file-backed sqflite
/// database never finishes opening inside `testWidgets`' fake-async zone in
/// this environment, but an in-memory one resolves instantly.
Future<void> _settle(WidgetTester tester, {int maxPumps = 20}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  /// Seeds one active routine with a single non-rest training day, and
  /// returns the day so callers can add exercises to it.
  Future<TrainingDay> seedRoutineWithDay() async {
    final db = DatabaseService.instance;
    await db.insertRoutine(Routine(
      id: 'r1',
      name: 'Push Pull Legs',
      schedulingMode: SchedulingMode.weekday,
      createdAt: '2026-01-01T00:00:00.000',
    ).toMap());
    final day = TrainingDay(
      id: 'd1',
      routineId: 'r1',
      name: 'Push Day',
      tag: 'MON',
      orderIndex: 0,
    );
    await db.insertDay(day.toMap());
    await db.setActiveRoutine('r1');
    return day;
  }

  testWidgets(
      'deleting an exercise from the day sheet removes the row without '
      'closing the sheet', (tester) async {
    final day = await seedRoutineWithDay();
    await DatabaseService.instance.insertExercise(ExerciseDef(
      id: 'e1',
      dayId: day.id,
      name: 'Bench Press',
      targetSets: 4,
      targetRepsMin: 8,
      targetRepsMax: 12,
    ).toMap());

    await tester.pumpWidget(const MaterialApp(home: RoutinesTab()));
    await _settle(tester);

    // Open the day-detail sheet.
    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();

    final sheetTitle = find.text('${day.tag} - ${day.name}'.toUpperCase());
    expect(sheetTitle, findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);

    // Open the exercise, then remove it — this pops only the nested
    // EDIT EXERCISE sheet, landing back on the still-open day sheet.
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('REMOVE EXERCISE'), findsOneWidget);

    // REMOVE EXERCISE sits below the fold of the test's default viewport,
    // inside the sheet's own scroll view.
    await tester.ensureVisible(find.text('REMOVE EXERCISE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE EXERCISE'));
    await tester.pumpAndSettle();

    // The day sheet is still open (refreshAfter kept it open and repainted
    // its own content) and no longer lists the deleted exercise.
    expect(sheetTitle, findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    expect(find.byType(SheetScaffold), findsOneWidget);
  });

  testWidgets('EDIT DAY saves and pops the day-detail sheet', (tester) async {
    final day = await seedRoutineWithDay();

    await tester.pumpWidget(const MaterialApp(home: RoutinesTab()));
    await _settle(tester);

    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();
    expect(find.text('${day.tag} - ${day.name}'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('EDIT DAY'));
    await tester.pumpAndSettle();
    expect(find.text('SAVE DAY'), findsOneWidget);

    await tester.tap(find.text('SAVE DAY'));
    await tester.pumpAndSettle();

    // Both the edit-day form sheet and the day-detail sheet it was opened
    // from are gone — EDIT DAY pops the parent sheet on a real save.
    expect(find.byType(SheetScaffold), findsNothing);
  });

  testWidgets(
      'a sheet drag that does not dismiss does not clear a typed field',
      (tester) async {
    await seedRoutineWithDay();

    await tester.pumpWidget(const MaterialApp(home: RoutinesTab()));
    await _settle(tester);

    await tester.tap(find.text('+ NEW'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE NEW ROUTINE'), findsOneWidget);

    const typed = 'My Custom Split';
    await tester.enterText(find.widgetWithText(TextField, 'e.g. Push / Pull / Legs'), typed);
    await tester.pump();
    expect(find.text(typed), findsOneWidget);

    // Drag from the sheet's title bar rather than its body: the body sits
    // inside SheetScaffold's own SingleChildScrollView, which wins the
    // vertical-drag gesture arena and just scrolls (never reaching
    // `_BottomSheetState`). The title bar is outside that scroll view, so a
    // drag starting there is a genuine candidate for the modal's own
    // dismiss-drag `GestureDetector`. A modest drag — well short of the
    // distance needed to dismiss — still triggers `_BottomSheetState`'s
    // `setState` (`_handleDragStart`/`_handleDragEnd`), which re-invokes the
    // builder passed to `showJinatraSheet`. Before the fix, that
    // re-invocation created a fresh (empty) TextEditingController and the
    // typed name vanished while the sheet stayed open.
    await tester.drag(find.text('CREATE NEW ROUTINE'), const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CREATE NEW ROUTINE'), findsOneWidget,
        reason: 'the small drag must not have dismissed the sheet');
    expect(find.text(typed), findsOneWidget,
        reason: 'the typed routine name must survive a non-dismissing drag');
  });
}
