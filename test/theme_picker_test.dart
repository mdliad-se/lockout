import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/theme/theme_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() {
    // Not sqfliteFfiInit()/databaseFactoryFfi: the isolate factory arms a
    // 10s sqflite timeout inside fake_async that a bounded `settle` never
    // cancels, and this suite previously hung for ten minutes on exactly
    // that. Every other suite in the repo uses the no-isolate factory
    // against an in-memory database for the same reason.
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
    ThemeController.instance.resetForTest();
    await ThemeController.instance.load();
  });

  // The serial runner reuses one process across every suite (see
  // `lockout_app_test.dart:44`), so whatever this suite last selected would
  // otherwise leak into the next one to run.
  tearDown(() => ThemeController.instance.resetForTest());

  testWidgets('offers six swatches and no dynamic option when unavailable',
      (tester) async {
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);

    for (final scheme in LockoutScheme.all) {
      expect(find.text(scheme.name), findsOneWidget, reason: scheme.key);
    }
    expect(find.text('Match my phone'), findsNothing);
  });

  testWidgets('offers the dynamic option once the platform supplies one',
      (tester) async {
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);

    expect(find.text('Match my phone'), findsOneWidget);
  });

  testWidgets('choosing a swatch persists it and repaints', (tester) async {
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);

    await tester.tap(find.text('Paper'));
    await settle(tester);

    expect(ThemeController.instance.selectedKey, 'paper');
    expect(
      await DatabaseService.instance.getSetting('theme_key', defaultValue: ''),
      'paper',
    );
  });

  testWidgets('no string in settings says LIAD', (tester) async {
    await tester.pumpWidget(hostedProfileTab());
    await settle(tester);
    expect(find.textContaining('LIAD'), findsNothing);
  });
}
