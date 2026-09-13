import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/services/database_service.dart';

import 'test_helpers.dart';

/// Ordering and date-scoping guarantees `DatabaseService`'s query methods
/// make, exercised against a real sqflite database rather than asserted by
/// reading the SQL.
void main() {
  // This suite installs an aborting trigger on `set_logs` (see the atomicity
  // group below). `CREATE TRIGGER` is DDL: on the shared on-disk test
  // database it would survive process exit and poison every later run — the
  // `addTearDown` that drops it covers a failing assertion but not a Ctrl-C,
  // a harness timeout kill or a crash in between. Pointing this suite at an
  // in-memory database means a leaked trigger dies with the process. The
  // second belt, for a checkout already poisoned by a pre-in-memory run that
  // never reached its teardown, is the `DROP TRIGGER IF EXISTS` in
  // `wipeDatabaseAndReseed` — which this file's `setUp` calls, and which
  // clears the shared file for the suites still using it.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
  });

  // Leaving a global seam set at end-of-suite is the same class of defect as
  // leaving the trigger behind.
  tearDownAll(() {
    DatabaseService.testDatabasePath = null;
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  group('DatabaseService.getBodyLogs', () {
    // Third-round review, Finding 7: this test's name and comment used to
    // say "rowid DESC tiebreaker" and "newest-inserted-first" — stale since
    // the fix moved the tiebreak to `id DESC`. 'b2' > 'b1' lexicographically
    // (`id` is `TEXT`, so this is a textual, not numeric, comparison — see
    // `getBodyLogs()`'s doc), which also happens to be insertion order here,
    // but it's the id comparison, not "the second weigh-in that day", that
    // this query actually guarantees.
    test('same-day entries come back highest-id-first, not undefined',
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
      // 'b2' sorts before 'b1' textually — date_str DESC alone cannot
      // distinguish these, so the id DESC tiebreaker is what makes this
      // deterministic.
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

    // Second-round review, Finding 2: `insertBodyLog`'s undo restore
    // (`ConflictAlgorithm.replace` on the same `id`) keeps every column,
    // but SQLite assigns the reinserted row a brand new `rowid`. Ordering on
    // `rowid DESC` therefore made a restored same-day entry look like the
    // latest weigh-in regardless of when it was actually logged that day.
    // `id` is a `microsecondsSinceEpoch` value untouched by that same
    // REPLACE, so ordering on it instead keeps a restored row in its
    // original chronological slot.
    test(
        'a delete then restore of the same id keeps its original position, '
        'not the newest', () async {
      final db = DatabaseService.instance;
      await db.insertBodyLog(BodyEntry(
        id: 'm1',
        dateStr: '2026-09-05',
        weightKg: 80.0,
      ).toMap());
      await db.insertBodyLog(BodyEntry(
        id: 'm2',
        dateStr: '2026-09-05',
        weightKg: 79.0,
      ).toMap());

      await db.deleteBodyLog('m2');
      // The restore: same id, same every column, but a fresh SQLite rowid.
      await db.insertBodyLog(BodyEntry(
        id: 'm2',
        dateStr: '2026-09-05',
        weightKg: 79.0,
      ).toMap());

      final rows = await db.getBodyLogs();
      expect(rows.map((r) => r['id']).toList(), ['m2', 'm1'],
          reason: 'm2 was logged later that day and must still sort first '
              'after being restored');
    });

    // Third-round review, Finding 1: the test above deletes and restores the
    // *newest* same-day row, which — because a fresh restore also lands on
    // the newest `rowid` — comes back on top under the old, broken
    // `rowid DESC` ordering too. It cannot tell the fix apart from the bug.
    // Deleting and restoring the OLDER of a same-day pair does discriminate:
    // under `rowid DESC` the restore's fresh rowid is still the highest in
    // the table, so it wrongly jumps to newest; under `id DESC` its
    // untouched, smaller id keeps it in its original, older slot.
    // Mutation-verified: fails (order becomes ['o1', 'o2']) with
    // `getBodyLogs()`'s `orderBy` reverted to `'date_str DESC, rowid DESC'`,
    // passes at HEAD.
    test(
        'restoring the OLDER of a same-day pair does not jump it to '
        'newest', () async {
      final db = DatabaseService.instance;
      await db.insertBodyLog(BodyEntry(
        id: 'o1',
        dateStr: '2026-09-05',
        weightKg: 80.0,
      ).toMap());
      await db.insertBodyLog(BodyEntry(
        id: 'o2',
        dateStr: '2026-09-05',
        weightKg: 79.0,
      ).toMap());

      // Delete and restore o1 — the OLDER entry that day — not o2.
      await db.deleteBodyLog('o1');
      await db.insertBodyLog(BodyEntry(
        id: 'o1',
        dateStr: '2026-09-05',
        weightKg: 80.0,
      ).toMap());

      final rows = await db.getBodyLogs();
      expect(rows.map((r) => r['id']).toList(), ['o2', 'o1'],
          reason: 'o1 was logged first that day; restoring it must not '
              'make it outrank o2, which was never touched');
    });

    // Third-round review, Finding 1, second discriminating shape: delete a
    // row, insert a newer one in the interim, then restore the deleted row.
    // Under `rowid DESC` the restore always gets the highest rowid in the
    // table regardless of how many newer rows were inserted meanwhile, so
    // it wrongly outranks even a row logged after it was deleted; under
    // `id DESC` its untouched, smaller id keeps it behind that newer row.
    // Mutation-verified: fails (order becomes ['p1', 'p3', 'p2']) with
    // `getBodyLogs()`'s `orderBy` reverted to `'date_str DESC, rowid DESC'`,
    // passes at HEAD.
    test(
        'restoring a deleted row after a newer same-day row was inserted '
        'keeps it behind that newer row', () async {
      final db = DatabaseService.instance;
      await db.insertBodyLog(BodyEntry(
        id: 'p1',
        dateStr: '2026-09-05',
        weightKg: 80.0,
      ).toMap());
      await db.insertBodyLog(BodyEntry(
        id: 'p2',
        dateStr: '2026-09-05',
        weightKg: 79.0,
      ).toMap());

      await db.deleteBodyLog('p1');
      // A newer same-day entry logged while p1 was deleted.
      await db.insertBodyLog(BodyEntry(
        id: 'p3',
        dateStr: '2026-09-05',
        weightKg: 78.0,
      ).toMap());
      // Restore p1 last.
      await db.insertBodyLog(BodyEntry(
        id: 'p1',
        dateStr: '2026-09-05',
        weightKg: 80.0,
      ).toMap());

      final rows = await db.getBodyLogs();
      expect(rows.map((r) => r['id']).toList(), ['p3', 'p2', 'p1'],
          reason: 'p1 was logged before p2 and p3 that day; restoring it '
              'last must not make it outrank either');
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

  // `deleteSessionLog` and `restoreSessionLog` each write two tables, and
  // `set_logs.session_id` carries no FK/`ON DELETE CASCADE` — so only a
  // transaction stops a failure on the second statement from leaving a
  // header without its sets, or sets without their header (invisible to
  // every query, yet faithfully exported into every future backup).
  //
  // Sequential `db.delete`/`db.insert` calls pass every other test in this
  // repo, because nothing else ever makes the child half fail. These
  // install a trigger that makes it fail on demand, which is the only way
  // to observe the difference.
  group('DatabaseService session writes are atomic', () {
    /// Makes every [event] on `set_logs` abort, and removes the trigger
    /// again afterwards. The drop is belt one of three; see the note on
    /// `setUpAll` for why one is not enough.
    Future<void> failSetLogsOn(String event) async {
      final database = await DatabaseService.instance.database;
      addTearDown(() async {
        final db = await DatabaseService.instance.database;
        await db.execute('DROP TRIGGER IF EXISTS test_fail_set_logs');
      });
      await database.execute('DROP TRIGGER IF EXISTS test_fail_set_logs');
      await database.execute(
        'CREATE TRIGGER test_fail_set_logs BEFORE $event ON set_logs '
        "BEGIN SELECT RAISE(ABORT, 'rejected by test trigger'); END;",
      );
    }

    Map<String, dynamic> sessionRow() => SessionLog(
          id: 'tx-1',
          dayName: 'MON - Legs',
          dateStr: '2026-09-10',
          durationSeconds: 1800,
          totalVolumeKg: 1000,
          status: 'completed',
          totalSets: 2,
        ).toMap();

    List<Map<String, dynamic>> setRows() => [
          SetLog(
            id: 'tx-1-a',
            sessionExerciseId: '',
            sessionId: 'tx-1',
            exerciseName: 'Squat',
            setIndex: 0,
            weightKg: 100,
            reps: 5,
            isCompleted: true,
          ).toMap(),
          SetLog(
            id: 'tx-1-b',
            sessionExerciseId: '',
            sessionId: 'tx-1',
            exerciseName: 'Squat',
            setIndex: 1,
            weightKg: 100,
            reps: 4,
            isCompleted: true,
          ).toMap(),
        ];

    test('a failed set delete rolls the session header back in', () async {
      final db = DatabaseService.instance;
      await db.insertSessionLog(sessionRow());
      await db.insertSetLogs(setRows());

      await failSetLogsOn('DELETE');

      await expectLater(db.deleteSessionLog('tx-1'), throwsA(anything));

      expect(await db.getSessionLogs(), hasLength(1),
          reason: 'the header must not be gone while its sets survive');
      expect(await db.getSetLogsForSession('tx-1'), hasLength(2),
          reason: 'both set rows are untouched');
    });

    test('a failed set insert rolls the restored header back out', () async {
      final db = DatabaseService.instance;
      await failSetLogsOn('INSERT');

      await expectLater(
        db.restoreSessionLog(sessionRow(), setRows()),
        throwsA(anything),
      );

      expect(await db.getSessionLogs(), isEmpty,
          reason: 'a header with no sets is indistinguishable from a '
              'legitimately detail-free entry, so it must not be left behind');
      expect(await db.getSetLogsForSession('tx-1'), isEmpty);
    });
  });
}
