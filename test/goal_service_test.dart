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

  /// The write-side guard in Settings is only one of three ways a poisoned
  /// row reaches `loadProfile`. `BackupService.importFromJson` validates the
  /// app tag and schema version and then writes `user_settings` rows
  /// verbatim, so a hand-edited or older-build backup restores
  /// `target_weight_kg = 'Infinity'` straight past it — as does any row
  /// written by a build that predates the guard. Clamping on read closes all
  /// three at once; the write-side guard stays because keeping garbage out of
  /// the database is still worth doing.
  group('loadProfile clamps non-finite rows', () {
    test('a non-finite target weight reads back as an unset target', () async {
      final db = DatabaseService.instance;
      await db.saveSetting('target_weight_kg', 'Infinity');
      await db.saveSetting('age', '30');

      final profile = await GoalService.instance.loadProfile();
      expect(profile.targetWeightKg, 0.0);
      // An unset target must not read as configured, or the user is shown a
      // fabricated plan instead of being asked for a real number.
      expect(profile.isConfigured, isFalse);
    });

    test('a NaN target weight reads back as an unset target', () async {
      await DatabaseService.instance.saveSetting('target_weight_kg', 'NaN');

      final profile = await GoalService.instance.loadProfile();
      expect(profile.targetWeightKg, 0.0);
    });

    test('a negative target weight reads back as an unset target', () async {
      await DatabaseService.instance.saveSetting('target_weight_kg', '-72');

      final profile = await GoalService.instance.loadProfile();
      expect(profile.targetWeightKg, 0.0);
    });

    test('a non-finite height reads back as the default height', () async {
      await DatabaseService.instance.saveSetting('height_cm', 'Infinity');

      final profile = await GoalService.instance.loadProfile();
      expect(profile.heightCm, 175.0);
    });

    test('a zero or negative height reads back as the default height',
        () async {
      final db = DatabaseService.instance;
      await db.saveSetting('height_cm', '0');
      expect((await GoalService.instance.loadProfile()).heightCm, 175.0);

      await db.saveSetting('height_cm', '-175');
      expect((await GoalService.instance.loadProfile()).heightCm, 175.0);
    });

    test('a negative age reads back as unset', () async {
      await DatabaseService.instance.saveSetting('age', '-30');

      final profile = await GoalService.instance.loadProfile();
      expect(profile.age, 0);
      expect(profile.isConfigured, isFalse);
    });

    test('snapshot survives a poisoned row instead of throwing', () async {
      // Verbatim reproduction of the crash: `NutritionPlanner.build` calls
      // `.round()` on a target derived from Infinity, and Dart throws
      // `Unsupported operation: Infinity or NaN toInt`. That took BODY, FOOD,
      // TODAY and Settings itself down, because all four call snapshot().
      final db = DatabaseService.instance;
      await db.saveSetting('target_weight_kg', 'Infinity');
      await db.saveSetting('height_cm', 'Infinity');
      await db.saveSetting('age', '30');
      await db.insertBodyLog(BodyEntry(
        id: 'poisoned',
        dateStr: '2026-09-10',
        weightKg: 80.0,
      ).toMap());

      final snap = await GoalService.instance.snapshot();
      expect(snap.currentWeightKg, 80.0);
      expect(snap.bmi, isNotNull);
      expect(snap.bmi!.isFinite, isTrue);
      // Target is unset once clamped, so no plan is invented from it.
      expect(snap.nutrition, isNull);
    });
  });
}
