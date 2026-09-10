import 'package:lockout/services/database_service.dart';

/// Wipes every backup table and restores the same seed rows
/// `DatabaseService._createDB` writes on a fresh install.
///
/// The serial test runner shares one sqflite file across every suite, so a
/// `setUp` that only deletes rows leaves `user_settings` empty for whatever
/// suite runs next — or, worse, lets a value one test saved (e.g. a
/// `calorie_target` override) leak into a suite that never touched it.
/// Reseeding after every wipe keeps each test's starting state identical to
/// a fresh install.
Future<void> wipeDatabaseAndReseed(DatabaseService db) async {
  final database = await db.database;
  for (final table in DatabaseService.backupTables) {
    await database.delete(table);
  }
  await db.saveSetting('unit_weight', 'kg');
  await db.saveSetting('unit_length', 'cm');
  await db.saveSetting('height_cm', '175.0');
  await db.saveSetting(
    'calorie_target',
    '${DatabaseService.defaultCalorieTarget}',
  );
  await db.saveSetting('food_tab_enabled', 'true');
  await db.saveSetting('rest_timer_default', '60');
  await db.saveSetting('height_unit', 'cm');
  await db.saveSetting('active_routine_id', '');
}
