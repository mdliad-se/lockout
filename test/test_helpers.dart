import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/services/database_service.dart';

/// Drives a bounded number of timed frames rather than `pumpAndSettle`.
///
/// `CircularProgressIndicator`'s indeterminate animation repeats forever, so
/// `pumpAndSettle` never terminates while one is on screen. This pumps
/// enough (fast, real) sqflite reads' worth of frames to resolve instead.
/// Shared by `today_tab_test.dart` and `routines_tab_test.dart` — both drive
/// the same in-memory-DB seam and previously duplicated this verbatim.
Future<void> settle(WidgetTester tester, {int maxPumps = 20}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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
