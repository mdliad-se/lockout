import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  });

  group('theme swatch chrome', () {
    testWidgets('shadow offsets stay on the 3/6/10 token scale',
        (tester) async {
      await pumpSettings(tester);

      final offsets = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .expand((d) => d.boxShadow ?? const <BoxShadow>[])
          .map((s) => s.offset.dx)
          .toSet();

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
