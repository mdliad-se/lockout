import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/routines_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/jinatra_input.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';

import 'test_helpers.dart';

/// Direct coverage for `RoutinesTab`, which had zero widget coverage before
/// the first fix wave: the day-detail sheet's `refreshAfter` staleness
/// guard, the EDIT DAY sheet-pop, and the drag-does-not-reset-typed-state
/// regression from Task 8's review (every sheet form used to build its
/// `TextEditingController`s and local form state inside the builder passed
/// to `showJinatraSheet`, so a drag that only rebuilt the sheet's own
/// drag-handling state — without dismissing it — silently reset them).
///
/// A second review wave found that fix's disposal half was backwards: it
/// disposed every controller in a `finally` around the `showJinatraSheet`
/// await, which resolves when the sheet's pop *starts*, not when its exit
/// animation finishes — so any sheet that had been typed into threw a
/// use-after-dispose the moment it closed. The four
/// `type into a field, then close the sheet` tests below are the regression
/// coverage for that: each would fail (`tester.takeException()` non-null)
/// against the disposed-in-`finally` version and pass against the
/// StatefulWidget-owns-its-controllers fix.
///
/// `settle` (in-memory-DB seam, bounded-pump helper) is shared with
/// `today_tab_test.dart` via `test_helpers.dart`.
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

    await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
    await settle(tester);

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

    await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
    await settle(tester);

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

    await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
    await settle(tester);

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

  // Second review wave: the first fix wave hoisted controllers out of the
  // rebuilt builder (fixing the drag-state-loss bug above) but disposed them
  // in a `finally` around `showJinatraSheet`'s await, which resolves when
  // the sheet's pop *starts* — not when its exit animation finishes and the
  // sheet is actually removed from the tree. Any field that had been
  // focused/edited was still wired to `EditableText` via
  // `Listenable.merge([controller, ...])` for the ~200ms the sheet spent
  // sliding away, so closing a typed-into sheet threw a use-after-dispose.
  // Each of these four tests types into one of the four sheet forms and
  // then closes it, matching the reviewer's reproduction; none of the three
  // tests above would have caught it, since none of them types into a field
  // and then lets the sheet actually close.
  group('typing into a form then closing the sheet does not throw', () {
    testWidgets('create-routine form: type, then SAVE ROUTINE', (tester) async {
      await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('+ NEW'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Push / Pull / Legs'),
          'My Custom Split');
      await tester.pump();

      await tester.ensureVisible(find.text('SAVE ROUTINE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE ROUTINE'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('day form: + ADD DAY, type a day name, then ADD DAY',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('+ ADD DAY'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Push'), 'Pull Day');
      await tester.pump();

      await tester.tap(find.text('ADD DAY'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'sub-item form: + ADD WARM-UP, type a movement, then ADD',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ ADD WARM-UP'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Arm circles'),
          'Band pull-aparts');
      await tester.pump();

      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('exercise form: edit an exercise, type a note, then SAVE CHANGES',
        (tester) async {
      final day = await seedRoutineWithDay();
      await DatabaseService.instance.insertExercise(ExerciseDef(
        id: 'e1',
        dayId: day.id,
        name: 'Bench Press',
        targetSets: 4,
        targetRepsMin: 8,
        targetRepsMax: 12,
      ).toMap());

      await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Cues, injury notes, tempo...'),
          'slow eccentric');
      await tester.pump();

      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // `double.tryParse` accepts the literal text 'Infinity', '-Infinity' and
    // 'NaN', and this field carries no `inputFormatters`, so the raw string
    // reached `target_weight_kg`. From there it is copied into every live
    // set the exercise starts, multiplied into `total_volume_kg`, and
    // persisted — after which `LogTab`'s `toInt()` throws on every launch
    // and the archive row that would let the user delete it is the thing
    // that crashes. Three sibling forms already reject this; this one is
    // the hole they were fixed around.
    testWidgets(
        'exercise form: a non-finite weight cannot reach the database',
        (tester) async {
      final day = await seedRoutineWithDay();
      await DatabaseService.instance.insertExercise(ExerciseDef(
        id: 'e1',
        dayId: day.id,
        name: 'Bench Press',
        targetSets: 4,
        targetRepsMin: 8,
        targetRepsMax: 12,
        targetWeightKg: 60,
      ).toMap());

      await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();

      final weightField = find.descendant(
        of: find.widgetWithText(JinatraInput, 'WEIGHT (KG)'),
        matching: find.byType(TextField),
      );
      await tester.enterText(weightField, 'Infinity');
      await tester.pump();

      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();

      final rows =
          await DatabaseService.instance.getExercisesForDay(day.id);
      final stored = (rows.single['target_weight_kg'] as num).toDouble();
      expect(stored.isFinite, isTrue,
          reason: 'Infinity was persisted into target_weight_kg');
      expect(stored, 0.0);
    });

    // There was a NaN twin of the test above here. It was vacuous: SQLite
    // stores a NaN REAL as NULL, so the assertion it made held with the
    // guard removed as well as with it in place — it proved a property of
    // the database, not of the field. NaN's rejection is a property of the
    // parse, and it is asserted where the parse lives, in
    // `numeric_guard_test.dart`. Infinity, which SQLite does store in a
    // REAL column, is what makes the test above worth driving through the
    // screen.
    // The guard must not become a blanket "everything is zero".
    testWidgets('exercise form: an ordinary weight still round-trips',
        (tester) async {
      final day = await seedRoutineWithDay();
      await DatabaseService.instance.insertExercise(ExerciseDef(
        id: 'e1',
        dayId: day.id,
        name: 'Bench Press',
        targetSets: 4,
        targetRepsMin: 8,
        targetRepsMax: 12,
      ).toMap());

      await tester.pumpWidget(MaterialApp(home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(JinatraInput, 'WEIGHT (KG)'),
          matching: find.byType(TextField),
        ),
        '62.5',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();

      final rows = await DatabaseService.instance.getExercisesForDay(day.id);
      expect((rows.single['target_weight_kg'] as num).toDouble(), 62.5);
    });
  });
}
