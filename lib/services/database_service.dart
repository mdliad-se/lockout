import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lockout.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
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
        status TEXT NOT NULL
      )
    ''');

    // Set Logs Table
    await db.execute('''
      CREATE TABLE set_logs (
        id TEXT PRIMARY KEY,
        session_exercise_id TEXT NOT NULL,
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
    await db.insert('user_settings', {'key': 'calorie_target', 'value': '2200'});
    await db.insert('user_settings', {'key': 'food_tab_enabled', 'value': 'true'});
    await db.insert('user_settings', {'key': 'rest_timer_default', 'value': '60'});
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
    return await db.query('exercises', where: 'day_id = ?', whereArgs: [dayId]);
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
    return await db.query('warmups', where: 'day_id = ?', whereArgs: [dayId]);
  }

  Future<void> insertWarmup(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('warmups', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getFinishersForDay(String dayId) async {
    final db = await instance.database;
    return await db.query('finishers', where: 'day_id = ?', whereArgs: [dayId]);
  }

  Future<void> insertFinisher(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('finishers', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- WORKOUT LOGS ---
  Future<List<Map<String, dynamic>>> getSessionLogs() async {
    final db = await instance.database;
    return await db.query('session_logs', orderBy: 'date_str DESC');
  }

  Future<void> insertSessionLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('session_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- FOOD LOGS ---
  Future<List<Map<String, dynamic>>> getFoodLogsForDate(String dateStr) async {
    final db = await instance.database;
    return await db.query('food_logs', where: 'date_str = ?', whereArgs: [dateStr]);
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
  Future<List<Map<String, dynamic>>> getBodyLogs() async {
    final db = await instance.database;
    return await db.query('body_logs', orderBy: 'date_str DESC');
  }

  Future<void> insertBodyLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('body_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
