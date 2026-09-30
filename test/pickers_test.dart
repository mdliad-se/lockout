import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/data/food_library.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/widgets/exercise_picker.dart';
import 'package:lockout/widgets/food_picker.dart';

import 'test_helpers.dart';

/// The only thing that used to exercise either picker was
/// `food_tab_test.dart`'s `openLogForm` helper, and its own docstring says
/// it deliberately avoids the catalog path — the servings stepper, the
/// category chips and the touch-target rule on the chip strip had no
/// dedicated coverage at all. This suite drives both pickers directly from a
/// stub button, the way the real screens do.
void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  /// Pumps a single button whose `onPressed` awaits [showFoodPicker] and
  /// stashes the result, so a test can assert on the value that actually
  /// comes back through the future — the save path — not just what the
  /// stepper painted along the way.
  Future<_Holder<PickedFood>> pumpFoodPicker(WidgetTester tester) async {
    final holder = _Holder<PickedFood>();
    await tester.pumpWidget(MaterialApp(
      theme: lockoutTestTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              holder.value = await showFoodPicker(context);
              holder.completed = true;
            },
            child: const Text('open food picker'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open food picker'));
    await tester.pumpAndSettle();
    return holder;
  }

  Future<_Holder<PickedExercise>> pumpExercisePicker(
      WidgetTester tester) async {
    final holder = _Holder<PickedExercise>();
    await tester.pumpWidget(MaterialApp(
      theme: lockoutTestTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              holder.value = await showExercisePicker(context);
              holder.completed = true;
            },
            child: const Text('open exercise picker'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open exercise picker'));
    await tester.pumpAndSettle();
    return holder;
  }

  group('showFoodPicker', () {
    testWidgets('tapping a catalog row opens the servings sheet at 1 serving',
        (tester) async {
      await pumpFoodPicker(tester);

      await tester.tap(find.text('Full English Breakfast'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Add to log'), findsOneWidget);
    });

    testWidgets(
        'two + taps scale kcal by 1.5x and the future carries the '
        'multiplied PickedFood', (tester) async {
      final holder = await pumpFoodPicker(tester);

      await tester.tap(find.text('Full English Breakfast'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // 810 kcal base x 1.5 = 1215.
      expect(find.text('1215 kcal'), findsOneWidget);

      await tester.tap(find.text('Add to log'));
      await tester.pumpAndSettle();

      expect(holder.completed, isTrue,
          reason: 'showFoodPicker\'s future must resolve, not just pop the '
              'inner sheet');
      expect(holder.value, isNotNull);
      expect(holder.value!.kcal, 1215,
          reason: 'the multiplier must reach the value returned through the '
              'future, not just the painted text');
      expect(holder.value!.name, contains('1.50x'));
    });

    testWidgets('the minus stepper floors at 0.25 servings and then disables',
        (tester) async {
      await pumpFoodPicker(tester);

      await tester.tap(find.text('Full English Breakfast'));
      await tester.pumpAndSettle();

      // 1.0 -> 0.75 -> 0.5 -> 0.25.
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(find.text('0.25'), findsOneWidget);

      final minusButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.remove),
          matching: find.byType(IconButton),
        ),
      );
      expect(minusButton.onPressed, isNull,
          reason: 'the 0.25 floor must disable further decrements');
    });

    testWidgets(
        'choosing a category chip narrows the result count and keeps an '
        'in-category item', (tester) async {
      await pumpFoodPicker(tester);

      final totalCount = FoodLibrary.all.length;
      expect(find.text('$totalCount found'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Breakfast'));
      await tester.pumpAndSettle();

      final breakfastCount = FoodLibrary.byCategory('Breakfast').length;
      expect(breakfastCount, lessThan(totalCount));
      expect(find.text('$breakfastCount found'), findsOneWidget);
      expect(find.text('Full English Breakfast'), findsOneWidget,
          reason: 'a Breakfast item stays after filtering to Breakfast');
      // No "an off-category row is absent" assertion here. The list is a
      // lazy ListView on an 800x600 surface, so an off-category row far down
      // the catalog is never built either way and `findsNothing` would hold
      // with the filter removed. The count assertion above is the real guard.
    });

    testWidgets(
        'the category chip and a catalog row both meet the 48dp touch '
        'target', (tester) async {
      await pumpFoodPicker(tester);

      final chipSize = tester.getSize(find.byType(ChoiceChip).first);
      expect(
        chipSize.height,
        greaterThanOrEqualTo(LockoutTheme.minTouchTarget),
        reason: 'the chip strip is a bare SizedBox(height: 40) pre-fix, '
            'clamping the ChoiceChip below LockoutTheme.minTouchTarget (48)',
      );

      final rowSize = tester.getSize(
        find.ancestor(
          of: find.text('Full English Breakfast'),
          matching: find.byType(InkWell),
        ),
      );
      expect(rowSize.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
    });
  });

  group('showExercisePicker', () {
    testWidgets('the muscle group chip also meets the 48dp touch target',
        (tester) async {
      await pumpExercisePicker(tester);

      final chipSize = tester.getSize(find.byType(ChoiceChip).first);
      expect(
        chipSize.height,
        greaterThanOrEqualTo(LockoutTheme.minTouchTarget),
        reason: 'exercise_picker.dart shares the same 40dp SizedBox bug',
      );
    });
  });
}

class _Holder<T> {
  T? value;
  bool completed = false;
}
