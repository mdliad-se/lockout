import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';
import 'numeric_guard.dart';

/// Outcome of an import attempt, so the UI can report precisely rather than
/// showing a generic failure.
class ImportResult {
  final bool ok;
  final String message;
  final int rowsRestored;

  const ImportResult._(this.ok, this.message, this.rowsRestored);

  const ImportResult.success(int rows)
      : this._(true, 'Restored $rows rows.', rows);

  const ImportResult.cancelled() : this._(false, 'Import cancelled.', 0);

  const ImportResult.failure(String message) : this._(false, message, 0);
}

/// Whole-database JSON backup and restore. Everything stays on-device unless
/// the user explicitly shares the exported file.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const int schemaVersion = 2;
  static const String appTag = 'lockout';

  /// Serialises every backup table plus settings into a single JSON document.
  Future<String> buildBackupJson() async {
    final db = DatabaseService.instance;
    final data = <String, dynamic>{};

    for (final table in DatabaseService.backupTables) {
      data[table] = await db.dumpTable(table);
    }

    return const JsonEncoder.withIndent('  ').convert({
      'app': appTag,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': '1.1.0',
      'data': data,
    });
  }

  /// Writes the backup to a temp file and hands it to the OS share sheet.
  Future<void> exportAndShare() async {
    final json = await buildBackupJson();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/lockout-backup-$stamp.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'LOCKOUT backup - $stamp',
      ),
    );
  }

  /// Prompts for a file and replaces the database with its contents.
  ///
  /// The whole file is validated before a single row is written, so a bad pick
  /// leaves existing data untouched.
  Future<ImportResult> pickAndImport() async {
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Choose a LOCKOUT backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (e) {
      return ImportResult.failure('Could not open the file picker: $e');
    }

    if (picked == null) return const ImportResult.cancelled();

    String raw;
    try {
      raw = utf8.decode(await picked.readAsBytes());
    } catch (e) {
      return ImportResult.failure('Could not read the file: $e');
    }

    return importFromJson(raw);
  }

  /// Forces every value destined for a REAL or INTEGER column to be a
  /// number, so the rest of the app can keep reading those columns as one.
  ///
  /// A backup is a plain JSON file the user can hand-edit, and SQLite's
  /// column affinity is advisory: `"weight_kg": "heavy"` is stored as the
  /// literal text `heavy` in a REAL column, after which
  /// `bodyRows.first['weight_kg'] as num` throws a `TypeError` — inside
  /// `_loadData()`, before its `setState(_isLoading = false)`, which leaves
  /// BODY, FOOD and HOME on a spinner forever with no error and no retry.
  /// Guarding here rather than in each of the five reading screens means one
  /// audit point instead of five try/catches that each hide the symptom.
  ///
  /// Text that spells a number keeps its value (`"72.5"` -> `72.5`), because
  /// that is plainly what the file meant. Anything else — a word, a list, a
  /// null, a non-finite number — becomes `0`, the same "not recorded" value
  /// unparseable input already lands on everywhere else in the app. Dropping
  /// the key instead is not an option: every numeric column in this schema
  /// is `NOT NULL`, and several carry no default, so a dropped key would
  /// abort the whole restore over one bad cell. Columns the schema declares
  /// as TEXT are left exactly as they are.
  static Map<String, dynamic> _coerceRow(
    Map<String, dynamic> row,
    Map<String, String> columnTypes,
  ) {
    final out = <String, dynamic>{};
    row.forEach((key, value) {
      final type = columnTypes[key];
      if (type == 'REAL') {
        out[key] = NumericGuard.read(value) ?? 0.0;
      } else if (type == 'INTEGER') {
        out[key] = (NumericGuard.read(value) ?? 0.0).round();
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  /// Validates and applies a backup document. Exposed separately from the file
  /// picker so it can be unit tested without touching the filesystem.
  Future<ImportResult> importFromJson(String raw) async {
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        return const ImportResult.failure('File is not a LOCKOUT backup.');
      }
      decoded = parsed;
    } catch (_) {
      return const ImportResult.failure('File is not valid JSON.');
    }

    if (decoded['app'] != appTag) {
      return const ImportResult.failure(
        'File is not a LOCKOUT backup (wrong app tag).',
      );
    }

    final fileVersion = decoded['schemaVersion'];
    if (fileVersion is! int || fileVersion > schemaVersion) {
      return ImportResult.failure(
        'Backup was made by a newer version of LOCKOUT (schema $fileVersion). '
        'Update the app first.',
      );
    }

    final rawData = decoded['data'];
    if (rawData is! Map<String, dynamic>) {
      return const ImportResult.failure('Backup has no data section.');
    }

    // Coerce and count before writing anything.
    final tables = <String, List<Map<String, dynamic>>>{};
    var total = 0;
    for (final table in DatabaseService.backupTables) {
      final rows = rawData[table];
      if (rows == null) continue;
      if (rows is! List) {
        return ImportResult.failure('Table "$table" is malformed.');
      }
      final types = await DatabaseService.instance.columnTypes(table);
      final typed = <Map<String, dynamic>>[];
      for (final row in rows) {
        if (row is! Map) {
          return ImportResult.failure('Table "$table" has a malformed row.');
        }
        typed.add(_coerceRow(Map<String, dynamic>.from(row), types));
      }
      tables[table] = typed;
      total += typed.length;
    }

    if (tables.isEmpty) {
      return const ImportResult.failure('Backup contains no known tables.');
    }

    try {
      await DatabaseService.instance.restoreTables(tables);
    } catch (e) {
      return ImportResult.failure('Restore failed, database unchanged: $e');
    }

    return ImportResult.success(total);
  }
}
