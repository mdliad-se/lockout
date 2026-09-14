import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lockout/models/models.dart';
import 'package:lockout/screens/settings_screen.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/services/goal_service.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';
import 'package:lockout/widgets/day_block.dart';
import 'package:lockout/widgets/jinatra_input.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
  });

  /// Structural guards rather than behavioural tests: the v2 sweep is only
  /// finished when no widget draws a square corner or a raw hex colour.
  group('v2 style sweep', () {
    test('no widget or screen uses BorderRadius.zero', () {
      final offenders = <String>[];
      for (final dir in ['lib/widgets', 'lib/screens']) {
        for (final f in Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
          if (f.readAsStringSync().contains('BorderRadius.zero')) {
            offenders.add(f.path);
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('screens do not hardcode palette colours', () {
      final offenders = <String>[];
      final hex = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
      for (final f in Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (hex.hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
      expect(offenders, isEmpty);
    });
  });

  group('settings target weight', () {
    /// Types [typed] into the goal card's target-weight field, presses
    /// CALCULATE MY TARGET and returns whatever reached `user_settings`.
    Future<String> saveTargetWeight(WidgetTester tester, String typed) async {
      // Settings is one long scroll; a surface tall enough to hold the goal
      // card keeps the field and its button on screen, so the test drives the
      // save rather than the scroll physics.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(onSettingsUpdated: () {})),
      );
      await settle(tester);

      final field = find.descendant(
        of: find.widgetWithText(JinatraInput, 'TARGET WEIGHT (KG)'),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, typed);
      await tester.pump();

      await tester.tap(find.text('CALCULATE MY TARGET'));
      await settle(tester);

      final stored = await DatabaseService.instance
          .getSetting('target_weight_kg', defaultValue: '');

      // Flush the toast's auto-dismiss Timer so none is left pending when
      // the tree is torn down.
      await tester.pump(const Duration(seconds: 6));
      return stored;
    }

    testWidgets('a non-finite target weight never reaches the database',
        (tester) async {
      // `double.tryParse('Infinity')` succeeds, so an unguarded save let the
      // BODY screen's TARGET tile render "Infinity kg" and poisoned every
      // calculation downstream of the goal profile.
      final stored = await saveTargetWeight(tester, 'Infinity');

      final parsed = double.tryParse(stored);
      expect(parsed, isNotNull);
      expect(parsed!.isFinite, isTrue);

      final profile = await GoalService.instance.loadProfile();
      expect(profile.targetWeightKg.isFinite, isTrue);
    });

    testWidgets('a negative target weight never reaches the database',
        (tester) async {
      final stored = await saveTargetWeight(tester, '-72');

      final parsed = double.tryParse(stored);
      expect(parsed, isNotNull);
      expect(parsed, greaterThanOrEqualTo(0.0));

      final profile = await GoalService.instance.loadProfile();
      expect(profile.targetWeightKg, greaterThanOrEqualTo(0.0));
    });
  });

  /// Settings is one long scroll. A surface tall enough to hold every card
  /// keeps the field, swatch or button a test drives on screen, so the test
  /// exercises the screen rather than the scroll physics.
  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(onSettingsUpdated: () {})),
    );
    await settle(tester);
  }

  /// Seeds a profile complete enough for `GoalService.snapshot()` to return a
  /// plan, so Settings renders its calculated-plan block. The four-week
  /// timeframe against a 30kg cut is deliberate: it trips
  /// `NutritionPlanner`'s rate cap, so the warning container renders too.
  /// Both subtrees are invisible in the default state.
  Future<void> seedCalculablePlan({String heightCm = '175.0'}) async {
    final db = DatabaseService.instance;
    await db.saveSetting('height_cm', heightCm);
    await db.saveSetting('age', '30');
    await db.saveSetting('target_weight_kg', '70');
    await db.saveSetting('goal_weeks', '4');
    await db.insertBodyLog(BodyEntry(
      id: 'seed-plan',
      dateStr: '2026-09-10',
      weightKg: 100.0,
    ).toMap());
  }

  /// The text sitting in the field labelled [label].
  String fieldText(WidgetTester tester, String label) {
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(JinatraInput, label),
        matching: find.byType(TextField),
      ),
    );
    return field.controller!.text;
  }

  group('theme switch repaint', () {
    /// The colour a [SectionHeading] actually painted its title in.
    Color headingColour(WidgetTester tester, String title) {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(SectionHeading),
          matching: find.text(title),
        ),
      );
      return text.style!.color!;
    }

    testWidgets('a section heading repaints when the palette changes',
        (tester) async {
      // The plan's hard constraint: "a theme switch must repaint everything".
      // `SectionHeading.build` reads `JinatraTokens.ink` at build time, so
      // constructing one `const` canonicalises it to a single instance and
      // `Element.updateChild` skips the rebuild entirely — the heading keeps
      // the old palette's near-black ink on the new palette's near-black
      // canvas, for the process lifetime, because Settings lives in an
      // `IndexedStack` and never unmounts. Same hazard `main.dart` documents
      // for `MainScreen`. This is the only test that pins the constraint to
      // a real screen, so it guards the whole family.
      addTearDown(() => AppPalette.apply(AppPalette.paperPress));

      await pumpSettings(tester);
      final before = headingColour(tester, 'APPEARANCE');

      await tester.tap(find.text('CARBON LIME'));
      await settle(tester);

      expect(AppPalette.current.key, 'carbon_lime');
      expect(
        headingColour(tester, 'APPEARANCE'),
        isNot(before),
        reason: 'the APPEARANCE heading kept the previous palette\'s ink',
      );
      expect(
        headingColour(tester, 'APPEARANCE'),
        JinatraTokens.ink.withValues(alpha: 0.75),
      );
    });
  });

  group('settings height', () {
    /// Types [typed] into HEIGHT (CM), presses SAVE SETTINGS and returns
    /// whatever reached `user_settings`.
    Future<String> saveHeight(WidgetTester tester, String typed) async {
      await pumpSettings(tester);

      final field = find.descendant(
        of: find.widgetWithText(JinatraInput, 'HEIGHT (CM)'),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, typed);
      await tester.pump();

      await tester.tap(find.text('SAVE SETTINGS'));
      await settle(tester);

      final stored = await DatabaseService.instance
          .getSetting('height_cm', defaultValue: '');

      // Flush the toast's auto-dismiss Timer so none is left pending when
      // the tree is torn down.
      await tester.pump(const Duration(seconds: 6));
      return stored;
    }

    testWidgets('a non-finite height never reaches the database',
        (tester) async {
      // `double.tryParse('Infinity')` succeeds and `Infinity > 0` is true, so
      // an unguarded save stored the literal string 'Infinity'. Reading it
      // back threw `Unsupported operation: Infinity or NaN toInt` out of
      // `NutritionPlanner.build`, taking BODY, FOOD, TODAY and Settings down.
      final stored = await saveHeight(tester, 'Infinity');

      final parsed = double.tryParse(stored);
      expect(parsed, isNotNull);
      expect(parsed!.isFinite, isTrue);

      final profile = await GoalService.instance.loadProfile();
      expect(profile.heightCm.isFinite, isTrue);
      expect(profile.heightCm, greaterThan(0));
    });

    testWidgets('a NaN height never reaches the database', (tester) async {
      // Contract documentation rather than mutation coverage, and labelled
      // as such: NaN fails every comparison, so any guard that catches
      // Infinity catches NaN too — `_usableHeightCm` written as
      // `cm != double.infinity && cm > 0` leaves the whole suite green.
      // Kept because `double.tryParse('NaN')` succeeds and both values reach
      // this unformatted field by the same route (a paste, or a letters
      // keyboard), so the write side should name what it refuses.
      final stored = await saveHeight(tester, 'NaN');

      final parsed = double.tryParse(stored);
      expect(parsed, isNotNull);
      expect(parsed!.isFinite, isTrue);
      expect(parsed, greaterThan(0));

      final profile = await GoalService.instance.loadProfile();
      expect(profile.heightCm.isFinite, isTrue);
      expect(profile.heightCm, greaterThan(0));
    });
  });

  group('settings load survives a poisoned height row', () {
    /// `BackupService.importFromJson` writes `user_settings` rows verbatim,
    /// so a hand-edited or older-build backup restores `height_cm =
    /// 'Infinity'` untouched, as does any row a build predating the
    /// write-side guard already wrote. Settings used to parse that row itself
    /// rather than through `GoalService`'s clamp, and
    /// `Units.cmToFeetInches` throws `Unsupported operation: Infinity or NaN
    /// toInt` on it — inside `_loadSettings`, before its `setState`. The
    /// screen then rendered with every field empty and no plan, silently, and
    /// the same throw inside `_restoreBackup` swallowed the reschedule, the
    /// `onSettingsUpdated` callback and the "Import complete" toast.
    for (final poison in ['Infinity', 'NaN']) {
      testWidgets('a stored height of $poison loads as the default',
          (tester) async {
        await seedCalculablePlan(heightCm: poison);
        await pumpSettings(tester);

        expect(fieldText(tester, 'HEIGHT (CM)'), '175');
        // The rest of the load must have completed, not been abandoned
        // half way: these are the fields and the block that came up empty.
        expect(fieldText(tester, 'AGE'), '30');
        expect(fieldText(tester, 'TARGET WEIGHT (KG)'), '70.0');
        expect(find.text('DAILY TARGET'), findsOneWidget);
      });
    }
  });

  group('a restore of a hand-edited backup still finishes', () {
    /// The two channels `NotificationService.rescheduleAll` touches. Both
    /// must be mocked: an unmocked platform channel under `flutter test`
    /// never answers at all, so the `await` inside `init()` hangs forever
    /// and nothing after it in `_import` runs. Mocking them also makes the
    /// reschedule observable — nothing registers a
    /// `FlutterLocalNotificationsPlatform` in a test, so
    /// `registerWith()` here stands in for the plugin registrant.
    const notifications =
        MethodChannel('dexterous.com/flutter/local_notifications');
    const timezone = MethodChannel('flutter_timezone');

    /// Drives the whole import tail through the UI — picker, restore,
    /// reschedule, callback, toast — over [raw], and hands back the three
    /// things the tail is pinned on.
    Future<({List<String> notificationCalls, int callbacks, SnackBar toast})>
        runImport(WidgetTester tester, String raw) async {
      // The restore applies the backup's theme, and these backups carry
      // none, so `AppPalette` lands on the fallback. Put it back for
      // whatever runs next: `setUpAll` chose Paper Press once, for the
      // whole file.
      addTearDown(() => AppPalette.apply(AppPalette.paperPress));

      final realPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _StubFilePicker(raw);
      addTearDown(() => FilePickerPlatform.instance = realPicker);

      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final notificationCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        notifications,
        (call) async {
          notificationCalls.add(call.method);
          // The Android impl declares initialize as Future<bool>; returning
          // null there throws a TypeError before anything is scheduled.
          return call.method == 'initialize' ? true : null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(notifications, null));
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(timezone, (call) async => 'UTC');
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(timezone, null));

      var callbacks = 0;
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(onSettingsUpdated: () => callbacks++),
      ));
      await settle(tester);

      await tester.tap(find.text('IMPORT BACKUP JSON'));
      await settle(tester);
      await tester.tap(find.text('CHOOSE FILE'));
      await settle(tester);

      // Flush the toast's auto-dismiss Timer before teardown.
      addTearDown(() => tester.pump(const Duration(seconds: 6)));

      return (
        notificationCalls: notificationCalls,
        callbacks: callbacks,
        toast: tester.widget<SnackBar>(find.byType(SnackBar)),
      );
    }

    String backupJson(Object? weightKg) => jsonEncode({
          'app': 'lockout',
          'schemaVersion': 2,
          'data': {
            'body_logs': [
              {
                'id': '1',
                'date_str': '2026-01-01',
                'weight_kg': weightKg,
                'waist_cm': 0.0,
              },
            ],
            'user_settings': [
              {'key': 'reminders_enabled', 'value': 'true'},
              {'key': 'reminder_hour', 'value': '7'},
              {'key': 'reminder_minute', 'value': '30'},
            ],
          },
        });

    testWidgets(
        'a backup carrying a non-numeric weight_kg still reschedules, still '
        'calls back and still tells the user the import applied',
        (tester) async {
      // A hand-edited backup puts the string 'heavy' into
      // `body_logs.weight_kg` — a REAL-affinity column SQLite will happily
      // keep as TEXT. `_loadSettings` reads it back through
      // `GoalService.snapshot()`, whose `bodyRows.first['weight_kg'] as num`
      // threw a `TypeError` on the `await` that sits ahead of
      // `rescheduleAll()`, `onSettingsUpdated()` and the "Import complete"
      // toast: the import applied, the OS kept the pre-restore reminder
      // schedule forever and the user was told nothing.
      //
      // The try/catch that first covered this only protected Settings; the
      // other four `snapshot()` callers were still exposed. The coercion now
      // happens a layer down, inside `BackupService.importFromJson`, so the
      // bad value never reaches the column at all and every caller is
      // covered at once. This test still drives the whole import tail — the
      // reschedule, the callback and the toast are what it was written to
      // pin — but the expected outcome is now a clean read-back rather than
      // a reported failure. Settings' try/catch stays as a belt for any
      // future read-back failure; nothing arriving through an import can
      // trip it any more.
      final imported = await runImport(tester, backupJson('heavy'));

      // The rows did land — this is a completed import, not a rejected one
      // — and the poisoned cell is a number by the time it is stored.
      final rows = await DatabaseService.instance.getBodyLogs();
      expect(rows.single['weight_kg'], isA<num>());

      expect(tester.takeException(), isNull);
      expect(imported.notificationCalls, contains('zonedSchedule'),
          reason: 'the imported reminder settings must reach the OS');
      expect(imported.callbacks, 1,
          reason: 'onSettingsUpdated must still fire');
      expect(find.textContaining('Import complete'), findsOneWidget);
    });

    testWidgets(
        'the user is told how many cells the import had to rewrite, and told '
        'it in the warning styling', (tester) async {
      // Availability was the point of coercing a layer down, and that part
      // is right. What it cost is diagnosability: the import quietly
      // rewrote a cell the user had typed and then reported plain success.
      // The warning that was supposed to cover this hangs off the
      // try/catch around `_loadSettings()`, which the coercion means can no
      // longer fire — so the count has to come up with the result instead.
      final imported = await runImport(tester, backupJson('heavy'));

      expect(find.textContaining('Import complete'), findsOneWidget);
      expect(find.textContaining('could not be read'), findsOneWidget,
          reason: 'a rewritten cell must not be reported as a clean import');
      expect(find.textContaining('1 value'), findsOneWidget);
      expect(imported.toast.backgroundColor, JinatraTokens.signal,
          reason: 'it must look different from a clean import, not just '
              'read differently');
    });

    testWidgets('a clean backup gets no warning and no count', (tester) async {
      final imported = await runImport(tester, backupJson(81.25));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Import complete'), findsOneWidget);
      expect(find.textContaining('could not be read'), findsNothing,
          reason: 'nothing was rewritten, so there is nothing to warn about');
      expect(imported.toast.backgroundColor, JinatraTokens.deepTeal);
    });
  });

  group('theme swatch chrome', () {
    testWidgets('shadow offsets stay on the 3/6/10 token scale',
        (tester) async {
      // Two shadow-bearing subtrees never render in the default state: the
      // calculated-plan block and the reminder-time row. Seeding both is what
      // makes this sweep cover the whole screen. The warning container the
      // seed also trips is built `hasShadow: false`, so it adds nothing to
      // `offsets` — its assertion below is a render guard on the seed, not
      // part of the shadow sweep.
      await seedCalculablePlan();
      await DatabaseService.instance.saveSetting('reminders_enabled', 'true');
      await pumpSettings(tester);

      expect(find.text('DAILY TARGET'), findsOneWidget);
      expect(find.textContaining('Target eased to a safe rate'), findsOneWidget);
      expect(find.text('REMINDER TIME'), findsOneWidget);

      final offsets = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .expand((d) => d.boxShadow ?? const <BoxShadow>[])
          .map((s) => s.offset.dx)
          .toSet();

      // Without this the assertion below is vacuous the day a refactor moves
      // these boxes from `Container` to `DecoratedBox` or a painter: an empty
      // set is a subset of anything.
      expect(offsets, isNotEmpty);
      expect(
        offsets.difference({
          JinatraTokens.shadowSm,
          JinatraTokens.shadowMd,
          JinatraTokens.shadowLg,
        }),
        isEmpty,
      );
    });
  });
}

/// A picked file whose bytes the test supplies. `PlatformFile` is
/// `abstract base`, so a subclass outside its own library must be `final`.
final class _StubBackupFile extends PlatformFile {
  _StubBackupFile(String json) : _bytes = Uint8List.fromList(utf8.encode(json));

  final Uint8List _bytes;

  @override
  String get name => 'lockout-backup.json';

  @override
  Uri get uri => Uri.parse('file:///lockout-backup.json');

  // `Never` is a subtype of `XFile`, so this satisfies the override without
  // importing cross_file. `pickAndImport` reads bytes, never the XFile.
  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(_bytes);
}

/// Stands in for the OS file picker, which cannot open under `flutter test`.
/// Extending `FilePickerPlatform` passes its own token, so no mock mixin is
/// needed; the test restores the real instance in a tear-down.
class _StubFilePicker extends FilePickerPlatform {
  _StubFilePicker(this.json);

  final String json;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      _StubBackupFile(json);
}
