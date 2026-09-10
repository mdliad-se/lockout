import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/goal_service.dart';

import 'test_helpers.dart';

/// `GoalService`'s pure bodyweight-delta maths, and the shared calorie
/// target resolution (Ruling A) both FOOD and HOME resolve through.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Reseeded, not just wiped: a bare `delete` from every backup table
    // (including `user_settings`) would leave whatever the previous test in
    // this file saved to `calorie_target` behind for the next suite on the
    // shared serial database.
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  group('GoalService.weightDeltaKg', () {
    test('null with fewer than two entries', () {
      expect(GoalService.weightDeltaKg([]), isNull);
      expect(
        GoalService.weightDeltaKg([
          {'weight_kg': 80.0},
        ]),
        isNull,
      );
    });

    test('a loss (latest lighter than previous) is negative', () {
      // Rows in the order getBodyLogs() returns them: newest first.
      final delta = GoalService.weightDeltaKg([
        {'weight_kg': 79.0}, // latest
        {'weight_kg': 80.0}, // previous
      ]);
      expect(delta, closeTo(-1.0, 1e-9));
    });

    test('a gain (latest heavier than previous) is positive, not inverted',
        () {
      // Regression for the bug: two same-day rows, order undefined without
      // the DB tiebreaker, could put the earlier (lighter) row first and
      // flip the sign. Given correctly-ordered input, the sign must track
      // the real direction of change.
      final delta = GoalService.weightDeltaKg([
        {'weight_kg': 80.3}, // latest, a gain
        {'weight_kg': 80.0}, // previous
      ]);
      expect(delta, greaterThan(0));
      expect(delta, closeTo(0.3, 1e-9));
    });
  });

  group('GoalService.instance.snapshot().calorieTarget', () {
    test('defaults to DatabaseService.defaultCalorieTarget when nothing is '
        'stored and no plan exists', () async {
      final snap = await GoalService.instance.snapshot();
      expect(snap.nutrition, isNull);
      expect(snap.calorieTarget, DatabaseService.defaultCalorieTarget);
    });

    test(
        'reads back whatever the Settings override last saved, when no plan '
        'exists (FOOD and HOME must resolve to the same number)', () async {
      final db = DatabaseService.instance;
      await db.saveSetting('calorie_target', '1950');

      final snap = await GoalService.instance.snapshot();
      expect(snap.nutrition, isNull);
      expect(snap.calorieTarget, 1950);
    });

    test(
        'a calculated plan wins over the manual override once both exist '
        '(Ruling A)', () async {
      final db = DatabaseService.instance;
      // A manual override left over from before the profile was configured.
      await db.saveSetting('calorie_target', '1800');

      // Configure a full profile and log a bodyweight, so snapshot() can
      // calculate a plan.
      await db.saveSetting('age', '30');
      await db.saveSetting('target_weight_kg', '70');
      await db.saveSetting('height_cm', '175.0');
      await db.saveSetting('sex', 'male');
      await db.saveSetting('activity_level', 'moderate');
      await db.saveSetting('goal_weeks', '12');
      await db.insertBodyLog(BodyEntry(
        id: 'b1',
        dateStr: '2026-09-10',
        weightKg: 80.0,
      ).toMap());

      final snap = await GoalService.instance.snapshot();
      expect(snap.nutrition, isNotNull);
      expect(snap.calorieTarget, snap.nutrition!.targetKcal);
      // The whole point of the finding: this must NOT be the stale manual
      // override once a plan can be calculated.
      expect(snap.calorieTarget, isNot(1800));
    });
  });
}
