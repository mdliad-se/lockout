import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/routines_tab.dart';
import 'package:lockout/widgets/today_day_card.dart';
import 'package:lockout/widgets/week_day_row.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/schedule_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/day_block.dart';
import 'package:lockout/widgets/lockout_field.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';

import 'test_helpers.dart';

/// Direct coverage for `RoutinesTab`, which had zero widget coverage before
/// the first fix wave: the day-detail sheet's `refreshAfter` staleness
/// guard, the EDIT DAY sheet-pop, and the drag-does-not-reset-typed-state
/// regression from Task 8's review (every sheet form used to build its
/// `TextEditingController`s and local form state inside the builder passed
/// to `showLockoutSheet`, so a drag that only rebuilt the sheet's own
/// drag-handling state — without dismissing it — silently reset them).
///
/// A second review wave found that fix's disposal half was backwards: it
/// disposed every controller in a `finally` around the `showLockoutSheet`
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
/// A weekday code guaranteed to differ from today's, for tests that need a
/// day the routine card will NOT feature.
String _aWeekdayThatIsNotToday() {
  final today = ScheduleService.weekdayCode(DateTime.now());
  return ScheduleService.weekdayPickerOrder.firstWhere((c) => c != today);
}

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
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
      // Today's own weekday, so the day is the featured one whatever day the
      // suite runs on. A hardcoded MON would make every assertion below pass
      // only on Mondays now that the card leads with today.
      tag: ScheduleService.weekdayCode(DateTime.now()),
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

    await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
    await settle(tester);

    // Open the day-detail sheet.
    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();

    // SheetScaffold no longer shouts its title.
    final sheetTitle = find.text('${day.tag} - ${day.name}');
    expect(sheetTitle, findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);

    // Open the exercise, then remove it — this pops only the nested
    // EDIT EXERCISE sheet, landing back on the still-open day sheet.
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('Remove exercise'), findsOneWidget);

    // REMOVE EXERCISE sits below the fold of the test's default viewport,
    // inside the sheet's own scroll view.
    await tester.ensureVisible(find.text('Remove exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove exercise'));
    await tester.pumpAndSettle();

    // The day sheet is still open (refreshAfter kept it open and repainted
    // its own content) and no longer lists the deleted exercise.
    expect(sheetTitle, findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    expect(find.byType(SheetScaffold), findsOneWidget);
  });

  testWidgets('EDIT DAY saves and pops the day-detail sheet', (tester) async {
    final day = await seedRoutineWithDay();

    await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
    await settle(tester);

    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();
    // SheetScaffold no longer shouts its title: all-caps is retired
    // outside small metadata labels and the weekday rail.
    expect(find.text('${day.tag} - ${day.name}'), findsOneWidget);

    await tester.tap(find.text('EDIT DAY'));
    await tester.pumpAndSettle();
    expect(find.text('Save day'), findsOneWidget);

    await tester.tap(find.text('Save day'));
    await tester.pumpAndSettle();

    // Both the edit-day form sheet and the day-detail sheet it was opened
    // from are gone — EDIT DAY pops the parent sheet on a real save.
    expect(find.byType(SheetScaffold), findsNothing);
  });

  testWidgets(
      'a sheet drag that does not dismiss does not clear a typed field',
      (tester) async {
    await seedRoutineWithDay();

    await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
    await settle(tester);

    await tester.tap(find.text('New'));
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
    // builder passed to `showLockoutSheet`. Before the fix, that
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
  // in a `finally` around `showLockoutSheet`'s await, which resolves when
  // the sheet's pop *starts* — not when its exit animation finishes and the
  // sheet is actually removed from the tree. Any field that had been
  // focused/edited was still wired to `EditableText` via
  // `Listenable.merge([controller, ...])` for the ~200ms the sheet spent
  // sliding away, so closing a typed-into sheet threw a use-after-dispose.
  // Each of these four tests types into one of the four sheet forms and
  // then closes it, matching the reviewer's reproduction; none of the three
  // tests above would have caught it, since none of them types into a field
  // and then lets the sheet actually close.
  // Post-PR finding: the day sheet gave the same action two presentations.
  // Warm-Up and Finisher showed a labelled `AddLink` while empty and swapped
  // it for a small heading `+` once populated — so the control the user had
  // just pressed vanished on first use — while Exercises kept its link in
  // both states. These three lock the one affordance the sections now share:
  // heading always, labelled link always, no heading `+` anywhere.
  group('the day sheet offers one add affordance per section', () {
    testWidgets('an empty day shows all three headings and all three links',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      expect(find.text('WARM-UP'), findsOneWidget);
      expect(find.text('EXERCISES'), findsOneWidget);
      expect(find.text('CONDITIONING FINISHER'), findsOneWidget);
      expect(find.text('+ ADD WARM-UP'), findsOneWidget);
      expect(find.text('+ ADD EXERCISE'), findsOneWidget);
      expect(find.text('+ ADD FINISHER'), findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(SectionHeading),
            matching: find.byIcon(Icons.add),
          ),
          findsNothing);
    });

    testWidgets('the warm-up link survives the first warm-up', (tester) async {
      final day = await seedRoutineWithDay();
      await DatabaseService.instance.insertWarmup(WarmupItem(
        id: 'w1',
        dayId: day.id,
        name: 'Band pull-aparts',
        amt: 'x15',
      ).toMap());

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      expect(find.text('Band pull-aparts'), findsOneWidget);
      expect(find.text('WARM-UP'), findsOneWidget);
      expect(find.text('+ ADD WARM-UP'), findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(SectionHeading),
            matching: find.byIcon(Icons.add),
          ),
          findsNothing);
    });

    testWidgets('the exercise link survives the first exercise',
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

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('EXERCISES'), findsOneWidget);
      expect(find.text('+ ADD EXERCISE'), findsOneWidget);
    });

    // All three sections now live in one `else` spread hanging off
    // `if (day.isRestDay)` (routines_tab.dart:362). A bad edit that hoists
    // that spread out of the branch would offer warm-ups and exercises on a
    // rest day, and nothing else in the suite reaches this path.
    testWidgets('a rest day offers no sections and no add links',
        (tester) async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'r1',
        name: 'Push Pull Legs',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-01-01T00:00:00.000',
      ).toMap());
      await db.insertDay(TrainingDay(
        id: 'd1',
        routineId: 'r1',
        name: 'Rest Day',
        // Deliberately NOT today: this test is about the day sheet, so the
        // day is reached through the collapsed week rather than the featured
        // card, and the assertions below cannot be satisfied by the card's
        // own rest-day copy.
        tag: _aWeekdayThatIsNotToday(),
        orderIndex: 0,
        isRestDay: true,
      ).toMap());
      await db.setActiveRoutine('r1');

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.textContaining('Full week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rest Day'));
      await tester.pumpAndSettle();

      expect(find.text('Recovery is part of the plan.'), findsOneWidget);
      expect(find.text('WARM-UP'), findsNothing);
      expect(find.text('EXERCISES'), findsNothing);
      expect(find.text('CONDITIONING FINISHER'), findsNothing);
      expect(find.text('+ ADD WARM-UP'), findsNothing);
      expect(find.text('+ ADD EXERCISE'), findsNothing);
      expect(find.text('+ ADD FINISHER'), findsNothing);
    });

    testWidgets('the finisher link survives the first finisher',
        (tester) async {
      final day = await seedRoutineWithDay();
      await DatabaseService.instance.insertFinisher(FinisherItem(
        id: 'f1',
        dayId: day.id,
        name: 'Farmer carry',
        amt: '3 rounds',
      ).toMap());

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      expect(find.text('Farmer carry'), findsOneWidget);
      expect(find.text('CONDITIONING FINISHER'), findsOneWidget);
      expect(find.text('+ ADD FINISHER'), findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(SectionHeading),
            matching: find.byIcon(Icons.add),
          ),
          findsNothing);
    });
  });

  // Reported from the device: a routine created through + NEW arrived with
  // every day EMPTY. Nothing was broken — `Blank Routine` was the
  // pre-selected default (`RoutineTemplate.all.first`), so typing a name and
  // hitting SAVE produced an empty routine, while the empty-state copy right
  // behind the sheet promises that "Every day arrives with a warm-up,
  // numbered exercises and a conditioning finisher already filled in".
  // START FROM now starts unticked and SAVE waits for a real choice.
  group('START FROM has no pre-selected default', () {
    Future<void> openCreateForm(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Push / Pull / Legs'),
          'My Custom Split');
      await tester.pump();
    }

    Future<void> saveRoutine(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Save routine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save routine'));
      await tester.pumpAndSettle();
    }

    testWidgets('saving without a choice creates nothing and says so',
        (tester) async {
      await openCreateForm(tester);
      await saveRoutine(tester);

      expect(await DatabaseService.instance.getRoutines(), isEmpty);
      expect(find.textContaining('Pick a starter split'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('picking a starter split fills every day it creates',
        (tester) async {
      await openCreateForm(tester);
      await tester.ensureVisible(find.text('Push / Pull / Legs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push / Pull / Legs'));
      await tester.pumpAndSettle();
      await saveRoutine(tester);

      final db = DatabaseService.instance;
      final routines = await db.getRoutines();
      expect(routines, hasLength(1));
      expect(routines.single['name'], 'My Custom Split');

      final days = await db.getDaysForRoutine(routines.single['id'] as String);
      expect(days, hasLength(3));
      for (final day in days) {
        final id = day['id'] as String;
        expect(await db.getExercisesForDay(id), isNotEmpty,
            reason: 'day ${day['name']} arrived with no exercises');
      }
    });

    testWidgets('picking Blank Routine still creates an empty routine',
        (tester) async {
      await openCreateForm(tester);
      await tester.ensureVisible(find.text('Blank Routine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blank Routine'));
      await tester.pumpAndSettle();
      await saveRoutine(tester);

      final db = DatabaseService.instance;
      final routines = await db.getRoutines();
      expect(routines, hasLength(1));
      expect(await db.getDaysForRoutine(routines.single['id'] as String),
          isEmpty);
    });
  });

  group('typing into a form then closing the sheet does not throw', () {
    testWidgets('create-routine form: type, then SAVE ROUTINE', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Push / Pull / Legs'),
          'My Custom Split');
      await tester.pump();

      await tester.ensureVisible(find.text('Save routine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save routine'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('day form: + ADD DAY, type a day name, then ADD DAY',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);

      // Add day lives inside the collapsed week now: building a routine
      // means opening the week, rather than the week staying permanently
      // expanded for the sake of one button.
      await tester.tap(find.textContaining('Full week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add day'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Push'), 'Pull Day');
      await tester.pump();

      await tester.tap(find.text('Add day'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'sub-item form: + ADD WARM-UP, type a movement, then ADD',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ ADD WARM-UP'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Arm circles'),
          'Band pull-aparts');
      await tester.pump();

      await tester.tap(find.text('Add'));
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

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Cues, injury notes, tempo...'),
          'slow eccentric');
      await tester.pump();

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
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

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();

      final weightField = find.descendant(
        of: find.widgetWithText(LockoutField, 'Weight (kg)'),
        matching: find.byType(TextField),
      );
      await tester.enterText(weightField, 'Infinity');
      await tester.pump();

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
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

      await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()));
      await settle(tester);
      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(LockoutField, 'Weight (kg)'),
          matching: find.byType(TextField),
        ),
        '62.5',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final rows = await DatabaseService.instance.getExercisesForDay(day.id);
      expect((rows.single['target_weight_kg'] as num).toDouble(), 62.5);
    });
  });

  group('the routine card leads with one day', () {
    testWidgets('an active routine features today and collapses the week',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(
        MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()),
      );
      await settle(tester);

      expect(find.byType(TodayDayCard), findsOneWidget);
      expect(
        find.byType(WeekDayRow),
        findsNothing,
        reason: 'the week must start collapsed; that is the whole change',
      );
      expect(find.textContaining('Full week'), findsOneWidget);
    });

    testWidgets('expanding reveals the days and the add-day action',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(
        MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()),
      );
      await settle(tester);

      await tester.tap(find.textContaining('Full week'));
      await tester.pumpAndSettle();

      expect(find.byType(WeekDayRow), findsWidgets);
      expect(find.text('Add day'), findsOneWidget);
    });

    testWidgets('the expander reports how many days the week holds',
        (tester) async {
      await seedRoutineWithDay();
      await DatabaseService.instance.insertDay(TrainingDay(
        id: 'd2',
        routineId: 'r1',
        name: 'Pull Day',
        tag: _aWeekdayThatIsNotToday(),
        orderIndex: 1,
      ).toMap());

      await tester.pumpWidget(
        MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()),
      );
      await settle(tester);

      expect(find.text('Full week (2)'), findsOneWidget);
    });

    testWidgets('an inactive routine features no day at all', (tester) async {
      await seedRoutineWithDay();
      // A second, newer routine takes over as the active one. Clearing
      // active_routine_id would not work: getActiveRoutine falls back to the
      // most recently created routine, so with a single routine nothing can
      // be inactive.
      await DatabaseService.instance.insertRoutine(Routine(
        id: 'r2',
        name: 'Other Routine',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-06-01T00:00:00.000',
      ).toMap());
      await DatabaseService.instance.setActiveRoutine('r2');

      await tester.pumpWidget(
        MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()),
      );
      await settle(tester);

      expect(
        find.byType(TodayDayCard),
        findsNothing,
        reason: 'the inactive routine must not feature a day',
      );
      expect(find.textContaining('Full week (1)'), findsOneWidget);
    });

    testWidgets('a gap in the week says so rather than featuring nothing',
        (tester) async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'r1',
        name: 'Push Pull Legs',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-01-01T00:00:00.000',
      ).toMap());
      await db.insertDay(TrainingDay(
        id: 'd1',
        routineId: 'r1',
        name: 'Push Day',
        tag: _aWeekdayThatIsNotToday(),
        orderIndex: 0,
      ).toMap());
      await db.setActiveRoutine('r1');

      await tester.pumpWidget(
        MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()),
      );
      await settle(tester);

      expect(find.text('Nothing scheduled today'), findsOneWidget);
      expect(find.byType(TodayDayCard), findsNothing);
      expect(find.textContaining('Full week'), findsOneWidget);
    });

    testWidgets('a rest day today is featured with no start button',
        (tester) async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'r1',
        name: 'Push Pull Legs',
        schedulingMode: SchedulingMode.weekday,
        createdAt: '2026-01-01T00:00:00.000',
      ).toMap());
      await db.insertDay(TrainingDay(
        id: 'd1',
        routineId: 'r1',
        name: 'Recovery',
        tag: ScheduleService.weekdayCode(DateTime.now()),
        orderIndex: 0,
        isRestDay: true,
      ).toMap());
      await db.setActiveRoutine('r1');

      await tester.pumpWidget(MaterialApp(
        theme: lockoutTestTheme(),
        home: RoutinesTab(onStartToday: () {}),
      ));
      await settle(tester);

      expect(find.byType(TodayDayCard), findsOneWidget);
      expect(find.text('Recovery'), findsOneWidget);
      expect(find.text('Start session'), findsNothing);
      expect(find.text('Recovery is part of the plan.'), findsOneWidget);
    });

    testWidgets('a scheduled day with no exercises yet offers no start',
        (tester) async {
      await seedRoutineWithDay();

      await tester.pumpWidget(MaterialApp(
        theme: lockoutTestTheme(),
        home: RoutinesTab(onStartToday: () {}),
      ));
      await settle(tester);

      expect(find.byType(TodayDayCard), findsOneWidget);
      expect(
        find.text('Start session'),
        findsNothing,
        reason: 'starting a day with zero exercises opens an empty session',
      );
    });

    testWidgets('a populated day today starts the session', (tester) async {
      final day = await seedRoutineWithDay();
      await DatabaseService.instance.insertExercise(ExerciseDef(
        id: 'e1',
        dayId: day.id,
        name: 'Bench Press',
        targetSets: 3,
        targetRepsMin: 8,
        targetRepsMax: 10,
        orderIndex: 0,
      ).toMap());

      var started = false;
      await tester.pumpWidget(MaterialApp(
        theme: lockoutTestTheme(),
        home: RoutinesTab(onStartToday: () => started = true),
      ));
      await settle(tester);

      expect(find.text('Start session'), findsOneWidget);
      await tester.tap(find.text('Start session'));
      await tester.pump();

      expect(started, isTrue);
    });

    testWidgets('a rotating routine labels its featured day NEXT, not TODAY',
        (tester) async {
      final db = DatabaseService.instance;
      await db.insertRoutine(Routine(
        id: 'r1',
        name: 'Rotation',
        schedulingMode: SchedulingMode.rotating,
        createdAt: '2026-01-01T00:00:00.000',
      ).toMap());
      await db.insertDay(TrainingDay(
        id: 'd1',
        routineId: 'r1',
        name: 'Day A',
        tag: 'A',
        orderIndex: 0,
      ).toMap());
      await db.setActiveRoutine('r1');

      await tester.pumpWidget(
        MaterialApp(theme: lockoutTestTheme(), home: RoutinesTab()),
      );
      await settle(tester);

      expect(find.byType(TodayDayCard), findsOneWidget);
      expect(find.textContaining('NEXT'), findsOneWidget);
      expect(find.textContaining('TODAY'), findsNothing);
    });
  });

}
