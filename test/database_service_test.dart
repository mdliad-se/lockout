import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/services/database_service.dart';

import 'test_helpers.dart';

/// Ordering and date-scoping guarantees `DatabaseService`'s query methods
/// make, exercised against a real sqflite database rather than asserted by
/// reading the SQL.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  group('DatabaseService.getBodyLogs', () {
    test('same-day entries come back newest-inserted-first, not undefined',
        () async {
      final db = DatabaseService.instance;
      // Two weigh-ins on the same calendar day: a loss, logged twice.
      await db.insertBodyLog(BodyEntry(
        id: 'b1',
        dateStr: '2026-09-10',
        weightKg: 80.0,
      ).toMap());
      await db.insertBodyLog(BodyEntry(
        id: 'b2',
        dateStr: '2026-09-10',
        weightKg: 79.0,
      ).toMap());

      final rows = await db.getBodyLogs();
      expect(rows.length, 2);
      // The later insert (the second weigh-in that day) must sort first —
      // date_str DESC alone cannot distinguish these, so the rowid DESC
      // tiebreaker is what makes this deterministic.
      expect(rows[0]['id'], 'b2');
      expect(rows[1]['id'], 'b1');
    });

    test('a later date still outranks an earlier one', () async {
      final db = DatabaseService.instance;
      await db.insertBodyLog(BodyEntry(
        id: 'early',
        dateStr: '2026-09-01',
        weightKg: 81.0,
      ).toMap());
      await db.insertBodyLog(BodyEntry(
        id: 'late',
        dateStr: '2026-09-10',
        weightKg: 80.0,
      ).toMap());

      final rows = await db.getBodyLogs();
      expect(rows.first['id'], 'late');
    });
  });

  group('DatabaseService.getSessionLogsForDate', () {
    test('scopes to the given date instead of scanning all history',
        () async {
      final db = DatabaseService.instance;
      await db.insertSessionLog(SessionLog(
        id: 's-today',
        dayName: 'Legs',
        dateStr: '2026-09-10',
        durationSeconds: 1800,
        totalVolumeKg: 1000,
        status: 'completed',
        kcalBurned: 300,
      ).toMap());
      await db.insertSessionLog(SessionLog(
        id: 's-yesterday',
        dayName: 'Push',
        dateStr: '2026-09-09',
        durationSeconds: 1800,
        totalVolumeKg: 900,
        status: 'completed',
        kcalBurned: 250,
      ).toMap());

      final rows = await db.getSessionLogsForDate('2026-09-10');
      expect(rows.length, 1);
      expect(rows.first['id'], 's-today');
    });

    test('returns nothing for a date with no sessions', () async {
      final rows =
          await DatabaseService.instance.getSessionLogsForDate('2026-01-01');
      expect(rows, isEmpty);
    });
  });
}
