import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'lockout_theme.dart';
import 'schemes.dart';

/// Owns which appearance is active and turns it into `ThemeData`.
///
/// A `ChangeNotifier` rather than an `InheritedWidget` of its own: the app
/// root listens once and rebuilds `MaterialApp`, which is all the framework
/// needs to repaint every `Theme.of(context)` reader beneath it.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _settingKey = 'theme_key';

  String _selectedKey = LockoutScheme.fallback.key;
  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;

  String get selectedKey => _selectedKey;

  /// True once the platform has handed us a wallpaper-derived scheme. False on
  /// Android 11 and below, and on every non-Android target.
  bool get dynamicAvailable => _dynamicLight != null && _dynamicDark != null;

  /// The keys the picker should offer, in order.
  ///
  /// Dynamic is appended only when the platform actually supplied schemes. An
  /// option that is present but silently does nothing is worse than an option
  /// that is not there.
  List<String> get pickerKeys => [
        for (final scheme in LockoutScheme.all) scheme.key,
        if (dynamicAvailable) LockoutScheme.dynamicKey,
      ];

  /// Whether dynamic is both chosen AND servable.
  ///
  /// The two are separate on purpose: a saved dynamic choice on a device that
  /// cannot provide one is *unservable*, not wrong, so [_selectedKey] keeps
  /// saying `dynamic` and starts working the moment schemes arrive.
  bool get _usingDynamic =>
      _selectedKey == LockoutScheme.dynamicKey && dynamicAvailable;

  /// The authored scheme in force. For a dynamic selection this is still the
  /// fallback, because dynamic borrows its semantic colours from it.
  LockoutScheme get _base => _selectedKey == LockoutScheme.dynamicKey
      ? LockoutScheme.fallback
      : LockoutScheme.byKey(_selectedKey);

  ThemeData get lightTheme {
    if (_usingDynamic) {
      return LockoutTheme.build(
        colors: _harmonised(_dynamicLight!),
        semantics: LockoutScheme.fallback.semantics,
      );
    }
    final scheme = _base;
    return LockoutTheme.build(
      colors: scheme.colors,
      semantics: scheme.semantics,
    );
  }

  /// Null unless a dynamic scheme is in force.
  ///
  /// An authored scheme already carries its own brightness, so offering a
  /// second one would let the system's light/dark setting override an explicit
  /// choice — picking "Graphite" and getting a white app at sunrise.
  ThemeData? get darkTheme {
    if (!_usingDynamic) return null;
    return LockoutTheme.build(
      colors: _harmonised(_dynamicDark!),
      semantics: LockoutScheme.fallback.semantics,
    );
  }

  ThemeMode get themeMode => _usingDynamic ? ThemeMode.system : ThemeMode.light;

  /// Wallpaper colours decide hue; we decide meaning.
  ///
  /// A wallpaper can easily yield a green-ish `error` or a red-ish `tertiary`,
  /// at which point a destructive confirmation and a completed set are the
  /// same colour. Overwriting those two role groups — and leaving the
  /// `LockoutSemantics` ramp authored — keeps the things that must never be
  /// ambiguous unambiguous, while `primary` and the surfaces still come from
  /// the phone.
  ColorScheme _harmonised(ColorScheme platform) {
    final authored = LockoutScheme.fallback.colors;
    return platform.copyWith(
      error: authored.error,
      onError: authored.onError,
      errorContainer: authored.errorContainer,
      onErrorContainer: authored.onErrorContainer,
      tertiary: authored.tertiary,
      onTertiary: authored.onTertiary,
      tertiaryContainer: authored.tertiaryContainer,
      onTertiaryContainer: authored.onTertiaryContainer,
    );
  }

  /// Reads the saved choice. Call before the first frame so the app never
  /// flashes the default theme on top of the chosen one.
  Future<void> load() async {
    final saved = await DatabaseService.instance
        .getSetting(_settingKey, defaultValue: LockoutScheme.fallback.key);
    _selectedKey = _resolveKey(saved);
    notifyListeners();
  }

  Future<void> select(String key) async {
    final resolved = _resolveKey(key);
    if (resolved == _selectedKey) return;
    _selectedKey = resolved;
    await DatabaseService.instance.saveSetting(_settingKey, resolved);
    notifyListeners();
  }

  /// `dynamic` passes through untouched; anything else goes through
  /// [LockoutScheme.byKey], which maps legacy palette keys and falls back on
  /// junk.
  String _resolveKey(String key) => key == LockoutScheme.dynamicKey
      ? LockoutScheme.dynamicKey
      : LockoutScheme.byKey(key).key;

  /// Called by `DynamicColorBuilder` at the app root whenever the platform
  /// palette changes.
  ///
  /// A no-op when nothing actually changed: that builder rebuilds far more
  /// often than the wallpaper changes, and notifying every time would rebuild
  /// `MaterialApp` on every frame.
  void setDynamicSchemes({ColorScheme? light, ColorScheme? dark}) {
    if (light == _dynamicLight && dark == _dynamicDark) return;
    _dynamicLight = light;
    _dynamicDark = dark;
    notifyListeners();
  }

  /// Returns the controller to its fresh-install state.
  ///
  /// The singleton outlives an individual test, so without this a suite that
  /// selected `paper` would leak that choice into the next one.
  @visibleForTesting
  void resetForTest() {
    _selectedKey = LockoutScheme.fallback.key;
    _dynamicLight = null;
    _dynamicDark = null;
  }
}
