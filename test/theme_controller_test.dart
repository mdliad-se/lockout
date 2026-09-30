import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/theme/theme_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

void main() {
  // The no-isolate factory against an in-memory path, matching every other
  // suite here. The isolate-backed factory arms a 10s transaction timeout
  // inside fake_async that a bounded pump never lives long enough to cancel.
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
  });

  setUp(() async {
    await wipeDatabaseAndReseed(DatabaseService.instance);
    ThemeController.instance.resetForTest();
  });

  test('defaults to graphite when nothing is saved', () async {
    await ThemeController.instance.load();

    expect(ThemeController.instance.selectedKey, 'graphite');
    expect(ThemeController.instance.themeMode, ThemeMode.light);
    expect(ThemeController.instance.lightTheme.brightness, Brightness.dark);
    expect(ThemeController.instance.darkTheme, isNull);
  });

  test('an authored dark scheme is served through `theme`, not `darkTheme`',
      () async {
    await ThemeController.instance.load();
    await ThemeController.instance.select('ember');

    // themeMode.light means MaterialApp reads `theme`. The scheme carries its
    // own brightness, so an explicit choice is never overridden by the
    // system's light/dark setting.
    expect(ThemeController.instance.themeMode, ThemeMode.light);
    expect(ThemeController.instance.lightTheme.brightness, Brightness.dark);
    expect(ThemeController.instance.darkTheme, isNull);
  });

  test('a saved legacy Jinatra key resolves to its nearest scheme', () async {
    await DatabaseService.instance.saveSetting('theme_key', 'midnight_cyan');
    await ThemeController.instance.load();

    expect(ThemeController.instance.selectedKey, 'indigo');
    expect(ThemeController.instance.lightTheme.brightness, Brightness.dark);
  });

  test('select persists and notifies exactly once', () async {
    await ThemeController.instance.load();
    var notifications = 0;
    void listener() => notifications++;
    ThemeController.instance.addListener(listener);
    addTearDown(() => ThemeController.instance.removeListener(listener));

    await ThemeController.instance.select('paper');

    expect(notifications, 1);
    expect(ThemeController.instance.selectedKey, 'paper');
    expect(ThemeController.instance.lightTheme.brightness, Brightness.light);
    expect(
      await DatabaseService.instance.getSetting('theme_key', defaultValue: ''),
      'paper',
    );
  });

  test('selecting the current scheme is a no-op', () async {
    await ThemeController.instance.load();
    var notifications = 0;
    void listener() => notifications++;
    ThemeController.instance.addListener(listener);
    addTearDown(() => ThemeController.instance.removeListener(listener));

    await ThemeController.instance.select('graphite');

    expect(notifications, 0);
  });

  test('selecting junk falls back rather than throwing', () async {
    await ThemeController.instance.load();
    await ThemeController.instance.select('not_a_scheme');

    expect(ThemeController.instance.selectedKey, LockoutScheme.fallback.key);
  });

  test('dynamic is absent from the picker until schemes arrive', () async {
    await ThemeController.instance.load();

    expect(ThemeController.instance.dynamicAvailable, isFalse);
    expect(
      ThemeController.instance.pickerKeys.contains(LockoutScheme.dynamicKey),
      isFalse,
    );
    expect(ThemeController.instance.pickerKeys.length, 6);

    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );

    expect(ThemeController.instance.dynamicAvailable, isTrue);
    expect(ThemeController.instance.pickerKeys.last, LockoutScheme.dynamicKey);
    expect(ThemeController.instance.pickerKeys.length, 7);
  });

  test('setDynamicSchemes does not notify when nothing changed', () async {
    await ThemeController.instance.load();
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );

    var notifications = 0;
    void listener() => notifications++;
    ThemeController.instance.addListener(listener);
    addTearDown(() => ThemeController.instance.removeListener(listener));

    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );

    expect(
      notifications,
      0,
      reason: 'DynamicColorBuilder rebuilds often; notifying every time would '
          'loop the app root',
    );
  });

  test('dynamic selection follows the system brightness', () async {
    await ThemeController.instance.load();
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );
    await ThemeController.instance.select(LockoutScheme.dynamicKey);

    expect(ThemeController.instance.themeMode, ThemeMode.system);
    expect(ThemeController.instance.darkTheme, isNotNull);
    expect(ThemeController.instance.lightTheme.brightness, Brightness.light);
    expect(ThemeController.instance.darkTheme!.brightness, Brightness.dark);
  });

  test('a saved dynamic key falls back to graphite when unavailable', () async {
    await DatabaseService.instance
        .saveSetting('theme_key', LockoutScheme.dynamicKey);
    await ThemeController.instance.load();

    expect(ThemeController.instance.dynamicAvailable, isFalse);
    expect(ThemeController.instance.lightTheme.brightness, Brightness.dark);
    expect(ThemeController.instance.darkTheme, isNull);
    expect(ThemeController.instance.themeMode, ThemeMode.light);
  });

  test('a saved dynamic key comes back once the platform supplies schemes',
      () async {
    await DatabaseService.instance
        .saveSetting('theme_key', LockoutScheme.dynamicKey);
    await ThemeController.instance.load();
    expect(ThemeController.instance.themeMode, ThemeMode.light);

    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );

    expect(
      ThemeController.instance.themeMode,
      ThemeMode.system,
      reason: 'the choice was never discarded, only unservable',
    );
  });

  test('dynamic keeps our authored warning, error and ramp', () async {
    await ThemeController.instance.load();
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );
    await ThemeController.instance.select(LockoutScheme.dynamicKey);

    for (final theme in [
      ThemeController.instance.lightTheme,
      ThemeController.instance.darkTheme!,
    ]) {
      expect(theme.colorScheme.error, LockoutScheme.graphite.colors.error);
      expect(theme.colorScheme.tertiary, LockoutScheme.graphite.colors.tertiary);
      expect(
        theme.extension<LockoutSemantics>()!.categoryRamp,
        LockoutScheme.graphite.semantics.categoryRamp,
      );
    }
  });

  test('dynamic still takes its primary from the platform', () async {
    await ThemeController.instance.load();
    const platformLight = ColorScheme.light(primary: Color(0xFF7722AA));
    ThemeController.instance.setDynamicSchemes(
      light: platformLight,
      dark: const ColorScheme.dark(),
    );
    await ThemeController.instance.select(LockoutScheme.dynamicKey);

    expect(
      ThemeController.instance.lightTheme.colorScheme.primary,
      const Color(0xFF7722AA),
      reason: 'wallpaper decides hue; we only pin what must carry meaning',
    );
  });

  test('every picker key resolves to something buildable', () async {
    await ThemeController.instance.load();
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );

    for (final key in ThemeController.instance.pickerKeys) {
      await ThemeController.instance.select(key);
      expect(
        ThemeController.instance.lightTheme.extension<LockoutSemantics>(),
        isNotNull,
        reason: key,
      );
    }
  });

  test('storing platform schemes does not notify while an authored theme is '
      'selected', () async {
    await ThemeController.instance.load();
    expect(ThemeController.instance.selectedKey, 'graphite');

    var notifications = 0;
    void listener() => notifications++;
    ThemeController.instance.addListener(listener);
    addTearDown(() => ThemeController.instance.removeListener(listener));

    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );

    // The app root publishes these from a post-frame callback inside the
    // DynamicColorBuilder that also rebuilds on notify. Notifying for schemes
    // that cannot change what is on screen rebuilds the whole tree for
    // nothing, and on a device that supplies a palette it feeds straight back
    // into the callback that published them.
    expect(
      notifications,
      0,
      reason: 'graphite is selected; platform schemes change nothing on screen',
    );
    expect(ThemeController.instance.dynamicAvailable, isTrue);
  });

  test('the picker still gains dynamic once schemes arrive, without a '
      'notification storm', () async {
    await ThemeController.instance.load();

    var notifications = 0;
    void listener() => notifications++;
    ThemeController.instance.addListener(listener);
    addTearDown(() => ThemeController.instance.removeListener(listener));

    for (var i = 0; i < 5; i++) {
      ThemeController.instance.setDynamicSchemes(
        light: const ColorScheme.light(),
        dark: const ColorScheme.dark(),
      );
    }

    expect(notifications, 0);
    expect(
      ThemeController.instance.pickerKeys.contains(LockoutScheme.dynamicKey),
      isTrue,
    );
  });

  test('a dynamic selection does notify, because the screen changes',
      () async {
    await ThemeController.instance.load();
    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(),
      dark: const ColorScheme.dark(),
    );
    await ThemeController.instance.select(LockoutScheme.dynamicKey);

    var notifications = 0;
    void listener() => notifications++;
    ThemeController.instance.addListener(listener);
    addTearDown(() => ThemeController.instance.removeListener(listener));

    ThemeController.instance.setDynamicSchemes(
      light: const ColorScheme.light(primary: Color(0xFF00FF00)),
      dark: const ColorScheme.dark(),
    );

    expect(
      notifications,
      1,
      reason: 'the wallpaper changed and dynamic is what is on screen',
    );
  });

}
