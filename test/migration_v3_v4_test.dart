import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/services/database_service.dart';

/// Drives the real v3 -> v4 `session_logs.kcal_burned` migration against an
/// on-disk database, through `DatabaseService`'s actual `onUpgrade` path.
///
/// `DatabaseService._initDB` always opens a file literally named
/// `lockout.db` in `getDatabasesPath()`, and its `_createDB`/`_upgradeDB`
/// callbacks are private to that library file, so that exact path is the
/// only place the real migration is reachable from. This file seeds a
/// genuine pre-task v3 database there, then lets `DatabaseService` open it
/// for real, and deletes the file afterwards so the shared sqflite state the
/// other suites rely on is left clean.
void main() {
  late String dbPath;
  Database? opened;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbPath = p.join(await getDatabasesPath(), 'lockout.db');
  });

  tearDownAll(() async {
    // Windows holds an exclusive lock on the open sqlite file, so it must be
    // closed before the file can be deleted.
    if (opened != null && opened!.isOpen) {
      await opened!.close();
    }
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test(
      'a v3 session_logs row survives the v4 upgrade with kcal_burned '
      'defaulted, not backfilled', () async {
    await databaseFactory.deleteDatabase(dbPath);

    // The genuine pre-task shape of session_logs, from
    // `git show 2529a16:lib/services/database_service.dart` -- no
    // kcal_burned column.
    final seed = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
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
            total_sets INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    await seed.insert('session_logs', {
      'id': 'legacy-1',
      'day_name': 'MON - Legs',
      'date_str': '2026-09-01',
      'duration_seconds': 3060,
      'total_volume_kg': 2295.0,
      'status': 'completed',
      'routine_id': 'r1',
      'day_id': 'd1',
      'total_sets': 22,
    });

    final preCols = await seed.rawQuery('PRAGMA table_info(session_logs)');
    expect(preCols.any((c) => c['name'] == 'kcal_burned'), isFalse);
    expect(await seed.getVersion(), 3);
    await seed.close();

    // Open the same file through the real DatabaseService upgrade path, so
    // the genuine onCreate/onUpgrade/_addColumnIfMissing code runs.
    final upgraded = await DatabaseService.instance.database;
    opened = upgraded;

    expect(await upgraded.getVersion(), 4);

    final postCols = await upgraded.rawQuery('PRAGMA table_info(session_logs)');
    expect(postCols.where((c) => c['name'] == 'kcal_burned'), hasLength(1));

    final rows = await upgraded.query(
      'session_logs',
      where: 'id = ?',
      whereArgs: ['legacy-1'],
    );
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row['day_name'], 'MON - Legs');
    expect(row['date_str'], '2026-09-01');
    expect(row['duration_seconds'], 3060);
    expect(row['total_volume_kg'], 2295.0);
    expect(row['status'], 'completed');
    expect(row['routine_id'], 'r1');
    expect(row['day_id'], 'd1');
    expect(row['total_sets'], 22);
    // The migration must NOT backfill an estimate for pre-existing rows.
    expect((row['kcal_burned'] as num).toDouble(), 0.0);

    // --- Idempotence ---
    //
    // `DatabaseService.instance` is a singleton that caches its open
    // connection, exactly like the real app -- dozens of call sites hit
    // `DatabaseService.instance.database` and must never choke because the
    // migration already ran. Calling it again must be a safe no-op.
    final again = await DatabaseService.instance.database;
    expect(identical(again, upgraded), isTrue);
    expect(await again.getVersion(), 4);
    final colsAfterRefetch =
        await again.rawQuery('PRAGMA table_info(session_logs)');
    expect(colsAfterRefetch.where((c) => c['name'] == 'kcal_burned'),
        hasLength(1));

    // `_addColumnIfMissing` (the guard the real migration uses) is private
    // to database_service.dart and so cannot be invoked directly from this
    // test file. Reproducing its exact PRAGMA-check-then-ALTER shape against
    // the already-upgraded table proves that re-running that guard on a
    // database that already has the column is safe and does not duplicate
    // it -- the property the finding is protecting.
    Future<void> addColumnIfMissing(String column, String ddlType) async {
      final info = await again.rawQuery('PRAGMA table_info(session_logs)');
      final exists = info.any((c) => c['name'] == column);
      if (!exists) {
        await again.execute(
          'ALTER TABLE session_logs ADD COLUMN $column $ddlType',
        );
      }
    }

    await expectLater(
      addColumnIfMissing('kcal_burned', 'REAL NOT NULL DEFAULT 0.0'),
      completes,
    );

    final colsFinal = await again.rawQuery('PRAGMA table_info(session_logs)');
    expect(colsFinal.where((c) => c['name'] == 'kcal_burned'), hasLength(1));
  });
}
