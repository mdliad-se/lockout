import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/services/backup_service.dart';
import 'package:lockout/services/database_service.dart';

/// Exercises the real export/import code against a real SQLite database.
///
/// The device test could only show that a file with the right name reached the
/// share sheet; app-private storage is unreadable on a production image. This
/// runs the same `BackupService` code on the host, so the *contents* of the
/// backup — and the fidelity of the restore — are actually verified.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Each test starts from an empty database.
    final db = await DatabaseService.instance.database;
    for (final table in DatabaseService.backupTables) {
      await db.delete(table);
    }
  });

  Future<void> seed() async {
    final db = DatabaseService.instance;

    await db.insertRoutine(Routine(
      id: 'r1',
      name: 'Push / Pull / Legs',
      schedulingMode: SchedulingMode.weekday,
      createdAt: '2026-09-01T08:00:00.000',
    ).toMap());

    await db.insertDay(TrainingDay(
      id: 'd1',
      routineId: 'r1',
      name: 'Push',
      tag: 'SAT',
      orderIndex: 0,
      focus: 'Chest - Shoulders - Triceps',
      note: 'shoulder cue: no flare',
    ).toMap());

    await db.insertWarmup(WarmupItem(
      id: 'w1',
      dayId: 'd1',
      name: 'Band pull-aparts',
      amt: '15 reps',
      orderIndex: 0,
    ).toMap());

    await db.insertExercise(ExerciseDef(
      id: 'e1',
      dayId: 'd1',
      name: 'Barbell Bench Press',
      targetSets: 4,
      targetRepsMin: 6,
      targetRepsMax: 10,
      targetWeightKg: 82.5,
      restDefaultS: 180,
      note: 'pause on chest',
      muscleGroup: 'Chest',
      orderIndex: 0,
    ).toMap());

    await db.insertFinisher(FinisherItem(
      id: 'f1',
      dayId: 'd1',
      name: 'Push-ups',
      amt: '12-15 reps',
      orderIndex: 0,
    ).toMap());

    await db.insertSessionLog(SessionLog(
      id: 's1',
      dayName: 'SAT - Push',
      dateStr: '2026-09-06',
      durationSeconds: 3300,
      totalVolumeKg: 3280.5,
      status: 'completed',
      routineId: 'r1',
      dayId: 'd1',
      totalSets: 4,
    ).toMap());

    await db.insertSetLogs([
      SetLog(
        id: 'sl1',
        sessionExerciseId: 'e1',
        sessionId: 's1',
        exerciseName: 'Barbell Bench Press',
        setIndex: 1,
        weightKg: 82.5,
        reps: 8,
        isCompleted: true,
      ).toMap(),
    ]);

    await db.insertFoodLog(FoodEntry(
      id: 'fl1',
      dateStr: '2026-09-07',
      mealSlot: 'Lunch',
      name: 'Chicken Curry (Bengali)',
      kcal: 290,
      proteinG: 26,
      carbG: 8,
      fatG: 17,
    ).toMap());

    await db.insertBodyLog(BodyEntry(
      id: 'b1',
      dateStr: '2026-09-07',
      weightKg: 88.0,
      waistCm: 92.0,
    ).toMap());

    await db.saveSetting('theme_key', 'carbon_lime');
    await db.saveSetting('height_cm', '178.00');
    await db.saveSetting('age', '30');
  }

  group('Export content', () {
    test('backup document carries the expected envelope', () async {
      await seed();
      final json = jsonDecode(await BackupService.instance.buildBackupJson())
          as Map<String, dynamic>;

      expect(json['app'], 'lockout');
      expect(json['schemaVersion'], BackupService.schemaVersion);
      expect(json['appVersion'], isNotEmpty);
      expect(DateTime.tryParse(json['exportedAt'] as String), isNotNull);
      expect(json['data'], isA<Map<String, dynamic>>());
    });

    test('every backup table is present in the export', () async {
      await seed();
      final json = jsonDecode(await BackupService.instance.buildBackupJson())
          as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;

      for (final table in DatabaseService.backupTables) {
        expect(data.containsKey(table), isTrue, reason: 'missing $table');
        expect(data[table], isA<List>(), reason: '$table is not a list');
      }
    });

    test('exported rows carry real field values, not just ids', () async {
      await seed();
      final json = jsonDecode(await BackupService.instance.buildBackupJson())
          as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;

      final routine = (data['routines'] as List).single as Map;
      expect(routine['name'], 'Push / Pull / Legs');
      expect(routine['scheduling_mode'], 'WEEKDAY');

      final day = (data['training_days'] as List).single as Map;
      expect(day['focus'], 'Chest - Shoulders - Triceps');
      expect(day['note'], 'shoulder cue: no flare');
      expect(day['tag'], 'SAT');

      final ex = (data['exercises'] as List).single as Map;
      expect(ex['name'], 'Barbell Bench Press');
      expect(ex['target_weight_kg'], 82.5);
      expect(ex['rest_default_s'], 180);
      expect(ex['muscle_group'], 'Chest');

      final warmup = (data['warmups'] as List).single as Map;
      expect(warmup['name'], 'Band pull-aparts');

      final finisher = (data['finishers'] as List).single as Map;
      expect(finisher['amt'], '12-15 reps');

      final session = (data['session_logs'] as List).single as Map;
      expect(session['total_volume_kg'], 3280.5);
      expect(session['total_sets'], 4);

      final set = (data['set_logs'] as List).single as Map;
      expect(set['exercise_name'], 'Barbell Bench Press');
      expect(set['reps'], 8);

      final food = (data['food_logs'] as List).single as Map;
      expect(food['name'], 'Chicken Curry (Bengali)');
      expect(food['kcal'], 290);

      final body = (data['body_logs'] as List).single as Map;
      expect(body['weight_kg'], 88.0);
      expect(body['waist_cm'], 92.0);

      // Settings are key/value rows; the theme must survive a restore.
      final settings = (data['user_settings'] as List).cast<Map>();
      final themeRow = settings.firstWhere((r) => r['key'] == 'theme_key');
      expect(themeRow['value'], 'carbon_lime');
    });

    test('food logs from every date are exported, not just today', () async {
      await seed();
      // The pre-phase-2 export silently shipped only the current day.
      await DatabaseService.instance.insertFoodLog(FoodEntry(
        id: 'fl-old',
        dateStr: '2020-01-01',
        mealSlot: 'Dinner',
        name: 'Ancient Meal',
        kcal: 500,
      ).toMap());

      final json = jsonDecode(await BackupService.instance.buildBackupJson())
          as Map<String, dynamic>;
      final foods = (json['data'] as Map)['food_logs'] as List;

      expect(foods.length, 2);
      expect(
        foods.any((f) => (f as Map)['name'] == 'Ancient Meal'),
        isTrue,
        reason: 'export dropped food logs outside today',
      );
    });
  });

  group('Import restores what export wrote', () {
    test('a full round trip preserves every table', () async {
      await seed();
      final exported = await BackupService.instance.buildBackupJson();

      // Wipe, then restore from the exported document.
      final db = await DatabaseService.instance.database;
      for (final table in DatabaseService.backupTables) {
        await db.delete(table);
      }
      expect((await DatabaseService.instance.getRoutines()), isEmpty);

      final result = await BackupService.instance.importFromJson(exported);
      expect(result.ok, isTrue, reason: result.message);

      final routines = await DatabaseService.instance.getRoutines();
      expect(routines.single['name'], 'Push / Pull / Legs');

      final days = await DatabaseService.instance.getDaysForRoutine('r1');
      expect(days.single['focus'], 'Chest - Shoulders - Triceps');

      final exercises = await DatabaseService.instance.getExercisesForDay('d1');
      expect(exercises.single['target_weight_kg'], 82.5);

      final warmups = await DatabaseService.instance.getWarmupsForDay('d1');
      expect(warmups.single['name'], 'Band pull-aparts');

      final finishers = await DatabaseService.instance.getFinishersForDay('d1');
      expect(finishers.single['name'], 'Push-ups');

      final sessions = await DatabaseService.instance.getSessionLogs();
      expect(sessions.single['total_volume_kg'], 3280.5);

      final sets = await DatabaseService.instance.getSetLogsForSession('s1');
      expect(sets.single['exercise_name'], 'Barbell Bench Press');

      final foods =
          await DatabaseService.instance.getFoodLogsForDate('2026-09-07');
      expect(foods.single['kcal'], 290);

      final bodies = await DatabaseService.instance.getBodyLogs();
      expect(bodies.single['weight_kg'], 88.0);

      expect(
        await DatabaseService.instance.getSetting('theme_key'),
        'carbon_lime',
      );
    });

    test('restore replaces rather than merges', () async {
      await seed();
      final exported = await BackupService.instance.buildBackupJson();

      // A routine that exists now but is absent from the backup must be gone
      // after the restore — otherwise "replace all data" is a lie.
      await DatabaseService.instance.insertRoutine(Routine(
        id: 'stale',
        name: 'Should Not Survive',
        schedulingMode: SchedulingMode.rotating,
        createdAt: '2026-09-02T08:00:00.000',
      ).toMap());
      expect((await DatabaseService.instance.getRoutines()).length, 2);

      await BackupService.instance.importFromJson(exported);

      final routines = await DatabaseService.instance.getRoutines();
      expect(routines.length, 1);
      expect(routines.single['id'], 'r1');
    });

    test('row count reported matches what was written', () async {
      await seed();
      final exported = await BackupService.instance.buildBackupJson();
      final data = jsonDecode(exported)['data'] as Map<String, dynamic>;
      final expected = data.values
          .fold<int>(0, (sum, rows) => sum + (rows as List).length);

      final result = await BackupService.instance.importFromJson(exported);
      expect(result.rowsRestored, expected);
    });

    test('estimated burn survives an export and import', () async {
      final db = await DatabaseService.instance.database;
      await db.insert('session_logs', {
        'id': 'burn-1',
        'day_name': 'MON - Legs',
        'date_str': '2026-09-07',
        'duration_seconds': 3060,
        'total_volume_kg': 2295.0,
        'status': 'completed',
        'routine_id': '',
        'day_id': '',
        'total_sets': 22,
        'kcal_burned': 388.7,
      });

      final doc = await BackupService.instance.buildBackupJson();
      for (final table in DatabaseService.backupTables) {
        await db.delete(table);
      }
      final result = await BackupService.instance.importFromJson(doc);
      expect(result.ok, isTrue, reason: result.message);

      final rows = await db.query('session_logs', where: 'id = ?',
          whereArgs: ['burn-1']);
      expect(rows.single['kcal_burned'], closeTo(388.7, 0.001));
    });
  });

  group('Import rejects bad input without touching data', () {
    Future<void> expectRejected(String raw, Matcher messageMatcher) async {
      await seed();
      final before = await DatabaseService.instance.getRoutines();

      final result = await BackupService.instance.importFromJson(raw);

      expect(result.ok, isFalse);
      expect(result.message, messageMatcher);
      // The existing database must be untouched by a failed import.
      final after = await DatabaseService.instance.getRoutines();
      expect(after.length, before.length);
      expect(after.single['name'], 'Push / Pull / Legs');
    }

    test('malformed JSON', () async {
      await expectRejected('{not json at all', contains('valid JSON'));
    });

    test('wrong app tag', () async {
      await expectRejected(
        jsonEncode({'app': 'someotherapp', 'schemaVersion': 1, 'data': {}}),
        contains('not a LOCKOUT backup'),
      );
    });

    test('newer schema version', () async {
      await expectRejected(
        jsonEncode({'app': 'lockout', 'schemaVersion': 99, 'data': {}}),
        contains('newer version'),
      );
    });

    test('missing data section', () async {
      await expectRejected(
        jsonEncode({'app': 'lockout', 'schemaVersion': 2}),
        contains('no data section'),
      );
    });

    test('malformed table', () async {
      await expectRejected(
        jsonEncode({
          'app': 'lockout',
          'schemaVersion': 2,
          'data': {'routines': 'not-a-list'},
        }),
        contains('malformed'),
      );
    });

    test('malformed row inside a table', () async {
      await expectRejected(
        jsonEncode({
          'app': 'lockout',
          'schemaVersion': 2,
          'data': {
            'routines': ['just-a-string'],
          },
        }),
        contains('malformed row'),
      );
    });

    test('an older schema version is accepted', () async {
      await seed();
      final result = await BackupService.instance.importFromJson(jsonEncode({
        'app': 'lockout',
        'schemaVersion': 1,
        'data': {
          'routines': [
            {
              'id': 'old1',
              'name': 'Legacy Routine',
              'scheduling_mode': 'WEEKDAY',
              'is_active': 1,
              'created_at': '2020-01-01T00:00:00.000',
            }
          ],
        },
      }));

      expect(result.ok, isTrue, reason: result.message);
      final routines = await DatabaseService.instance.getRoutines();
      expect(routines.single['name'], 'Legacy Routine');
    });
  });
}
