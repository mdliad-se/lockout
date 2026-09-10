import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  /// Overrides the path `database` opens, for tests only. A `testWidgets`
  /// test that pumps a widget backed by a real file database hangs
  /// indefinitely in this environment — opening a `dart:io` file inside
  /// `TestWidgetsFlutterBinding`'s zone never completes, even though the
  /// identical `openDatabase` call resolves instantly under a plain `test()`
  /// (every non-widget DB test in this repo relies on that). An in-memory
  /// database (`sqflite_common_ffi`'s `inMemoryDatabasePath`) opens
  /// instantly regardless of which binding is active, so widget tests that
  /// need a real database set this before pumping. Production code never
  /// sets it, so this has no effect outside tests.
  @visibleForTesting
  static String? testDatabasePath;

  /// The single `calorie_target` fallback used everywhere one is needed: the
  /// seed row a fresh install writes, the value Settings shows before a plan
  /// has ever been calculated, and `GoalService`'s final fallback when
  /// neither a calculated plan nor a saved override exists. One constant so
  /// the three call sites cannot drift to different numbers.
  static const int defaultCalorieTarget = 2200;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lockout.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final override = testDatabasePath;
    final path =
        override ?? join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Adds a column only when it is missing, so the migration is safe to re-run
  /// and safe on databases created at any earlier version.
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String ddlType,
  ) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $ddlType');
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: exercise ordering + muscle grouping; set logs linked to a session
      // so the Log tab can rebuild a workout; session provenance for streaks.
      await _addColumnIfMissing(db, 'exercises', 'muscle_group', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'exercises', 'order_index', 'INTEGER NOT NULL DEFAULT 0');

      await _addColumnIfMissing(db, 'set_logs', 'session_id', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'set_logs', 'exercise_name', "TEXT NOT NULL DEFAULT ''");

      await _addColumnIfMissing(db, 'session_logs', 'routine_id', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'session_logs', 'day_id', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'session_logs', 'total_sets', 'INTEGER NOT NULL DEFAULT 0');

      await db.insert(
        'user_settings',
        {'key': 'height_unit', 'value': 'cm'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.insert(
        'user_settings',
        {'key': 'active_routine_id', 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    if (oldVersion < 3) {
      // v3: training days carry a focus subtitle, a day-level note and an
      // explicit rest-day flag, so the routine view can render the same
      // structure as the printed plan rather than a bare exercise list.
      await _addColumnIfMissing(db, 'training_days', 'focus', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'training_days', 'note', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'training_days', 'is_rest_day', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'warmups', 'order_index', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'finishers', 'order_index', 'INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 4) {
      // v4: estimated energy cost per session. Additive and idempotent, so a
      // database created at any earlier version lands in the same shape.
      await _addColumnIfMissing(
        db,
        'session_logs',
        'kcal_burned',
        'REAL NOT NULL DEFAULT 0.0',
      );
    }
  }

  Future _createDB(Database db, int version) async {
    // Routines Table
    await db.execute('''
      CREATE TABLE routines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        scheduling_mode TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // Training Days Table
    await db.execute('''
      CREATE TABLE training_days (
        id TEXT PRIMARY KEY,
        routine_id TEXT NOT NULL,
        name TEXT NOT NULL,
        tag TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        focus TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        is_rest_day INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE
      )
    ''');

    // Warmups Table
    await db.execute('''
      CREATE TABLE warmups (
        id TEXT PRIMARY KEY,
        day_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amt TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (day_id) REFERENCES training_days (id) ON DELETE CASCADE
      )
    ''');

    // Exercises Table
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        day_id TEXT NOT NULL,
        name TEXT NOT NULL,
        target_sets INTEGER NOT NULL,
        target_reps_min INTEGER NOT NULL,
        target_reps_max INTEGER NOT NULL,
        target_weight_kg REAL NOT NULL DEFAULT 0.0,
        rest_default_s INTEGER NOT NULL DEFAULT 60,
        note TEXT,
        video_url TEXT,
        muscle_group TEXT NOT NULL DEFAULT '',
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (day_id) REFERENCES training_days (id) ON DELETE CASCADE
      )
    ''');

    // Finishers Table
    await db.execute('''
      CREATE TABLE finishers (
        id TEXT PRIMARY KEY,
        day_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amt TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (day_id) REFERENCES training_days (id) ON DELETE CASCADE
      )
    ''');

    // Session Logs Table
    await db.execute('''
      CREATE TABLE session_logs (
        id TEXT PRIMARY KEY,
        day_name TEXT NOT NULL,
        date_str TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        total_volume_kg REAL NOT NULL,
        status TEXT NOT NULL,
        routine_id TEXT NOT NULL DEFAULT '',
        day_id TEXT NOT NULL DEFAULT '',
        total_sets INTEGER NOT NULL DEFAULT 0,
        kcal_burned REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Set Logs Table
    await db.execute('''
      CREATE TABLE set_logs (
        id TEXT PRIMARY KEY,
        session_exercise_id TEXT NOT NULL,
        session_id TEXT NOT NULL DEFAULT '',
        exercise_name TEXT NOT NULL DEFAULT '',
        set_index INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        reps INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Food Logs Table
    await db.execute('''
      CREATE TABLE food_logs (
        id TEXT PRIMARY KEY,
        date_str TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        name TEXT NOT NULL,
        kcal INTEGER NOT NULL,
        protein_g REAL NOT NULL DEFAULT 0.0,
        carb_g REAL NOT NULL DEFAULT 0.0,
        fat_g REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Body Logs Table
    await db.execute('''
      CREATE TABLE body_logs (
        id TEXT PRIMARY KEY,
        date_str TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        waist_cm REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // User Settings Table
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Insert Default Settings
    await db.insert('user_settings', {'key': 'unit_weight', 'value': 'kg'});
    await db.insert('user_settings', {'key': 'unit_length', 'value': 'cm'});
    await db.insert('user_settings', {'key': 'height_cm', 'value': '175.0'});
    await db.insert('user_settings',
        {'key': 'calorie_target', 'value': '$defaultCalorieTarget'});
    await db.insert('user_settings', {'key': 'food_tab_enabled', 'value': 'true'});
    await db.insert('user_settings', {'key': 'rest_timer_default', 'value': '60'});
    await db.insert('user_settings', {'key': 'height_unit', 'value': 'cm'});
    await db.insert('user_settings', {'key': 'active_routine_id', 'value': ''});
  }

  // --- SETTINGS STORAGE ---
  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await instance.database;
    final res = await db.query('user_settings', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return defaultValue;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- ROUTINES CRUD ---
  Future<List<Map<String, dynamic>>> getRoutines() async {
    final db = await instance.database;
    return await db.query('routines', orderBy: 'created_at DESC');
  }

  Future<void> insertRoutine(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('routines', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRoutine(String id) async {
    final db = await instance.database;
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  // --- DAYS CRUD ---
  Future<List<Map<String, dynamic>>> getDaysForRoutine(String routineId) async {
    final db = await instance.database;
    return await db.query('training_days', where: 'routine_id = ?', whereArgs: [routineId], orderBy: 'order_index ASC');
  }

  Future<void> insertDay(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('training_days', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteDay(String id) async {
    final db = await instance.database;
    await db.delete('training_days', where: 'id = ?', whereArgs: [id]);
  }

  // --- EXERCISES CRUD ---
  Future<List<Map<String, dynamic>>> getExercisesForDay(String dayId) async {
    final db = await instance.database;
    return await db.query(
      'exercises',
      where: 'day_id = ?',
      whereArgs: [dayId],
      orderBy: 'order_index ASC, rowid ASC',
    );
  }

  Future<void> insertExercise(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('exercises', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExercise(String id) async {
    final db = await instance.database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // --- WARMUPS & FINISHERS ---
  Future<List<Map<String, dynamic>>> getWarmupsForDay(String dayId) async {
    final db = await instance.database;
    return await db.query('warmups', where: 'day_id = ?', whereArgs: [dayId], orderBy: 'order_index ASC, rowid ASC');
  }

  Future<void> insertWarmup(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('warmups', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteWarmup(String id) async {
    final db = await instance.database;
    await db.delete('warmups', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteFinisher(String id) async {
    final db = await instance.database;
    await db.delete('finishers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getFinishersForDay(String dayId) async {
    final db = await instance.database;
    return await db.query('finishers', where: 'day_id = ?', whereArgs: [dayId], orderBy: 'order_index ASC, rowid ASC');
  }

  Future<void> insertFinisher(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('finishers', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- WORKOUT LOGS ---
  /// Newest day first, newest-within-a-day first (`date_str DESC, id
  /// DESC`), scoped to `status = 'completed'` so this list, its aggregates
  /// (LOG's hero/tiles) and `currentStreakDays` — which is fed by
  /// `getWorkoutDates()`, filtered the same way — never disagree on what
  /// counts as a logged workout.
  ///
  /// The id tiebreak matters: `session_logs.id` is minted the same way
  /// `body_logs.id` is (`DateTime.now().millisecondsSinceEpoch.toString()`,
  /// see `today_tab.dart`), so it sorts the same way — textually, correct
  /// for same-width ids. Without it, two sessions sharing a `date_str` fall
  /// back to SQLite's rowid order, which a delete-then-undo (LOG's Ruling F
  /// delete, Task 11) reassigns on restore — the exact defect
  /// `getBodyLogs()`/`getFoodLogsForDate()` were fixed for.
  Future<List<Map<String, dynamic>>> getSessionLogs() async {
    final db = await instance.database;
    return await db.query(
      'session_logs',
      where: "status = 'completed'",
      orderBy: 'date_str DESC, id DESC',
    );
  }

  /// Sessions logged on exactly [dateStr], scoped in the same style as
  /// `getFoodLogsForDate` rather than fetching every session ever logged and
  /// filtering in Dart.
  Future<List<Map<String, dynamic>>> getSessionLogsForDate(String dateStr) async {
    final db = await instance.database;
    return await db.query('session_logs', where: 'date_str = ?', whereArgs: [dateStr]);
  }

  Future<void> insertSessionLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('session_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- FOOD LOGS ---
  /// `id ASC` (oldest-logged-first, matching the order a meal's items were
  /// actually added) so a delete-then-undo (Ruling F, shared with
  /// `getBodyLogs()` above) restores a row into its original slot instead
  /// of letting SQLite's rowid fall-back order jump it to the end. Third-
  /// round review, Finding 4: with no `orderBy` at all, `food_logs` fell
  /// back to `rowid`, which `insertFoodLog`'s `ConflictAlgorithm.replace`
  /// restore reassigns on every insert including a restore of a row that
  /// already has an `id` — the exact defect `getBodyLogs()` was fixed for.
  /// `food_logs.id` is minted the same way BODY's is
  /// (`DateTime.now().microsecondsSinceEpoch.toString()`, see
  /// `food_tab.dart`), so it sorts the same way: textually, not
  /// numerically, correct for same-width ids.
  Future<List<Map<String, dynamic>>> getFoodLogsForDate(String dateStr) async {
    final db = await instance.database;
    return await db.query('food_logs',
        where: 'date_str = ?', whereArgs: [dateStr], orderBy: 'id ASC');
  }

  Future<void> insertFoodLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('food_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteFoodLog(String id) async {
    final db = await instance.database;
    await db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- BODY LOGS ---
  /// Newest first. `id DESC` is a required tiebreaker, not decoration:
  /// `body_tab.dart` mints one row per save, so multiple weigh-ins on the
  /// same `date_str` are normal, and `date_str DESC` alone leaves same-day
  /// rows in SQLite-undefined order (see `getLastPerformance` above for the
  /// same pattern applied to sessions).
  ///
  /// Tiebreaks on `id`, not `rowid`. `id` is a `microsecondsSinceEpoch`
  /// value minted once per row and never reused; `rowid` is SQLite's own
  /// internal row number, which `INSERT ... ON CONFLICT REPLACE` (what
  /// `insertBodyLog`'s undo restore uses) reassigns to a *new* value on
  /// every insert, including a restore of a row that already has an `id`.
  /// Ordering on `rowid DESC` therefore made an undone-then-restored
  /// same-day entry jump to "latest" even when it wasn't the one most
  /// recently weighed in, silently rewriting the headline weight
  /// `GoalService.snapshot()` reads from `bodyLogs.first` and flipping
  /// `GoalService.weightDeltaKg`'s sign. `id` is preserved by that same
  /// REPLACE (it's the column being conflicted on), so ordering on it
  /// instead keeps a restored row in its original chronological slot.
  /// Every consumer of this method (`GoalService.snapshot()`,
  /// `GoalService.weightDeltaKg`, `body_tab.dart`'s hero/sparkline/BMI) only
  /// ever reads relative order (`bodyLogs.first`, `bodyLogs[0]`/`[1]`), not
  /// `rowid` itself, so this is a same-shape substitution, not a behaviour
  /// change for any row that was never deleted and restored.
  ///
  /// Third-round review, Finding 6: `id DESC` is a *textual* (lexicographic)
  /// comparison — `body_logs.id` is `TEXT PRIMARY KEY`, not a numeric
  /// column, so SQLite sorts it byte-for-byte, not by value. That happens to
  /// agree with the numeric ordering of every id this app currently mints
  /// (`DateTime.now().microsecondsSinceEpoch.toString()`) because they are
  /// all the same digit width (16 digits, true for the entire range of
  /// plausible install dates), so a lexicographically-larger id is always
  /// the numerically-larger, later one. It would *not* agree for ids of
  /// different digit widths sharing one `date_str` — the initial commit
  /// minted `millisecondsSinceEpoch` ids (13 digits), and a 13-digit id
  /// would sort as textually *greater* than (i.e. "newer" than) any
  /// 16-digit `microsecondsSinceEpoch` id, since `'9' > '1'` is compared
  /// before either string's length matters. No currently-installed schema
  /// mixes the two, so this is a latent risk, not a live bug, but it's why
  /// this tiebreak is not simply "insertion order": it is *clock* order —
  /// same as insertion order for a clock that only ever moves forward, but
  /// the two diverge the moment the device clock is set backwards between
  /// two saves, which insertion order alone would still get right.
  Future<List<Map<String, dynamic>>> getBodyLogs() async {
    final db = await instance.database;
    return await db.query('body_logs', orderBy: 'date_str DESC, id DESC');
  }

  Future<void> insertBodyLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('body_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBodyLog(String id) async {
    final db = await instance.database;
    await db.delete('body_logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- ACTIVE ROUTINE ---
  /// The routine the Today tab schedules from. Falls back to the most recently
  /// created routine when the stored id is empty or points at a deleted row,
  /// so a fresh install still resolves a workout without extra setup.
  Future<Map<String, dynamic>?> getActiveRoutine() async {
    final db = await instance.database;
    final storedId = await getSetting('active_routine_id');

    if (storedId.isNotEmpty) {
      final hit = await db.query('routines', where: 'id = ?', whereArgs: [storedId]);
      if (hit.isNotEmpty) return hit.first;
    }

    final all = await db.query('routines', orderBy: 'created_at DESC', limit: 1);
    return all.isEmpty ? null : all.first;
  }

  Future<void> setActiveRoutine(String routineId) =>
      saveSetting('active_routine_id', routineId);

  // --- SET LOGS ---
  /// Persists every set of a finished session in one transaction.
  Future<void> insertSetLogs(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('set_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getSetLogsForSession(String sessionId) async {
    final db = await instance.database;
    return await db.query(
      'set_logs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'rowid ASC',
    );
  }

  /// Completed sets from the most recent session that included [exerciseName].
  /// Drives the "LAST: 60kg x 10,10,8" strip in the live session header.
  Future<List<Map<String, dynamic>>> getLastPerformance(String exerciseName) async {
    final db = await instance.database;
    final recent = await db.rawQuery('''
      SELECT sl.session_id
      FROM set_logs sl
      JOIN session_logs s ON s.id = sl.session_id
      WHERE sl.exercise_name = ? AND sl.is_completed = 1
      ORDER BY s.date_str DESC, s.rowid DESC
      LIMIT 1
    ''', [exerciseName]);

    if (recent.isEmpty) return const [];

    return await db.query(
      'set_logs',
      where: 'session_id = ? AND exercise_name = ? AND is_completed = 1',
      whereArgs: [recent.first['session_id'], exerciseName],
      orderBy: 'set_index ASC',
    );
  }

  /// Deletes a session and its sets atomically. `set_logs.session_id` has
  /// no FK/`ON DELETE CASCADE`, so without a transaction a crash between
  /// the two statements below orphans `set_logs` rows: invisible to every
  /// query (`getLastPerformance` JOINs `session_logs`) yet still faithfully
  /// exported by `dumpTable` into every future backup.
  Future<void> deleteSessionLog(String id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('session_logs', where: 'id = ?', whereArgs: [id]);
      await txn.delete('set_logs', where: 'session_id = ?', whereArgs: [id]);
    });
  }

  /// Re-inserts a session header and its sets atomically — the LOG undo
  /// path's counterpart to `deleteSessionLog`'s transaction above. Without
  /// it, an interruption between the two inserts leaves a header with no
  /// sets, which the UI cannot distinguish from a legitimately
  /// detail-free entry.
  Future<void> restoreSessionLog(
    Map<String, dynamic> sessionRow,
    List<Map<String, dynamic>> setRows,
  ) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('session_logs', sessionRow,
          conflictAlgorithm: ConflictAlgorithm.replace);
      if (setRows.isNotEmpty) {
        final batch = txn.batch();
        for (final row in setRows) {
          batch.insert('set_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  // --- BACKUP SUPPORT ---

  /// Tables carried by a backup file, in dependency order. Restore replays
  /// them in this order so parents exist before children.
  static const List<String> backupTables = [
    'routines',
    'training_days',
    'exercises',
    'warmups',
    'finishers',
    'session_logs',
    'set_logs',
    'food_logs',
    'body_logs',
    'user_settings',
  ];

  Future<List<Map<String, dynamic>>> dumpTable(String table) async {
    final db = await instance.database;
    return await db.query(table);
  }

  /// Replaces the entire contents of every backup table in one transaction, so
  /// a malformed file cannot leave the database half-restored.
  Future<void> restoreTables(Map<String, List<Map<String, dynamic>>> data) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      for (final table in backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in backupTables) {
        final rows = data[table];
        if (rows == null) continue;
        for (final row in rows) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Distinct workout dates, newest first — the raw input for streak maths.
  Future<List<String>> getWorkoutDates() async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT date_str FROM session_logs
      WHERE status = 'completed'
      ORDER BY date_str DESC
    ''');
    return rows.map((r) => r['date_str'] as String).toList();
  }
}
