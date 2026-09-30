import 'package:flutter/material.dart';

import 'lockout_semantics.dart';

/// One selectable appearance: a complete Material colour scheme plus the
/// semantic colours the framework has no role for.
///
/// Every role is stated. `ColorScheme.fromSeed` is used while authoring to
/// get a starting ramp and then thrown away, because at runtime it silently
/// re-derives every role the caller did not name — which is exactly how the
/// palette system this replaces ended up with colliding accents and muddy
/// mid-tones. `schemes_test.dart` is the acceptance check: contrast is a
/// number there, not a judgement here.
@immutable
class LockoutScheme {
  /// Persisted in the `theme_key` setting.
  final String key;

  /// Shown in the picker.
  final String name;

  final Brightness brightness;
  final ColorScheme colors;
  final LockoutSemantics semantics;

  const LockoutScheme({
    required this.key,
    required this.name,
    required this.brightness,
    required this.colors,
    required this.semantics,
  });

  /// The key the picker uses for "follow my phone's colours". Not a
  /// [LockoutScheme] of its own, because its colours come from the platform
  /// at runtime and only exist below the widget that resolves them.
  static const String dynamicKey = 'dynamic';

  // --- DARK ---

  /// The palette from the design brief. Default for a fresh install.
  static const graphite = LockoutScheme(
    key: 'graphite',
    name: 'Graphite',
    brightness: Brightness.dark,
    colors: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFA3E86D),
      onPrimary: Color(0xFF101419),
      primaryContainer: Color(0xFF2B4A1B),
      onPrimaryContainer: Color(0xFFC9F5A4),
      secondary: Color(0xFF75D9FF),
      onSecondary: Color(0xFF101419),
      secondaryContainer: Color(0xFF12394B),
      onSecondaryContainer: Color(0xFFB6EBFF),
      tertiary: Color(0xFFFFC857),
      onTertiary: Color(0xFF241A00),
      tertiaryContainer: Color(0xFF4A3708),
      onTertiaryContainer: Color(0xFFFFE0A3),
      error: Color(0xFFFF7777),
      onError: Color(0xFF2B0505),
      errorContainer: Color(0xFF5C1A1A),
      onErrorContainer: Color(0xFFFFCFCF),
      surface: Color(0xFF080A0D),
      onSurface: Color(0xFFF5F7FA),
      onSurfaceVariant: Color(0xFF9BA5B1),
      surfaceContainerLowest: Color(0xFF05070A),
      surfaceContainerLow: Color(0xFF101419),
      surfaceContainer: Color(0xFF151A20),
      surfaceContainerHigh: Color(0xFF1B2128),
      surfaceContainerHighest: Color(0xFF222931),
      inverseSurface: Color(0xFFF5F7FA),
      onInverseSurface: Color(0xFF101419),
      // The action tone for an inverse-surface background — in this app
      // that is the undo banner's only control, and the tone
      // `snackBarTheme.actionTextColor` names. Every scheme states it, for
      // two reasons. `primary` is built to read on `surface` and measures
      // 1.37:1 here; and the fallback for an unstated `inversePrimary` is
      // `onPrimary`, which on this scheme is `onInverseSurface` to the
      // byte, so the action painted the banner message's own tone and was
      // left to weight alone to read as an action. Each scheme takes its
      // own `primary` hue to the tone that reads on its inverse surface —
      // darker in the dark schemes, whose inverse surface is near-white,
      // lighter in the light ones. `schemes_test.dart` holds both bars
      // (>= 4.5:1 on `inverseSurface`, >= 1.5:1 against
      // `onInverseSurface`) across all six.
      inversePrimary: Color(0xFF3D6B1F),
      outline: Color(0xFF272E36),
      outlineVariant: Color(0xFF222931),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    semantics: LockoutSemantics(
      success: Color(0xFFA3E86D),
      // Matches this scheme's `onPrimary`: `success` sits at `primary`'s
      // luminance here, same as every other authored scheme today.
      onSuccess: Color(0xFF101419),
      warning: Color(0xFFFFC857),
      danger: Color(0xFFFF7777),
      restDay: Color(0xFF9BA5B1),
      chartLine: Color(0xFFA3E86D),
      chartFill: Color(0x1FA3E86D),
      categoryRamp: [
        Color(0xFFA3E86D),
        Color(0xFF75D9FF),
        Color(0xFFFFC857),
        Color(0xFFFF9E7A),
        Color(0xFFB3A8FF),
        Color(0xFF6FE0C0),
        Color(0xFFFF9EC4),
        Color(0xFFD8DE7A),
      ],
    ),
  );

  /// Warm neutral ground, amber primary.
  static const ember = LockoutScheme(
    key: 'ember',
    name: 'Ember',
    brightness: Brightness.dark,
    colors: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFF0A868),
      onPrimary: Color(0xFF2B1703),
      primaryContainer: Color(0xFF4A3117),
      onPrimaryContainer: Color(0xFFFFD9B0),
      secondary: Color(0xFF8FD3C7),
      onSecondary: Color(0xFF06211C),
      secondaryContainer: Color(0xFF143B34),
      onSecondaryContainer: Color(0xFFB9EDE4),
      tertiary: Color(0xFFFFC857),
      onTertiary: Color(0xFF241A00),
      tertiaryContainer: Color(0xFF4A3708),
      onTertiaryContainer: Color(0xFFFFE0A3),
      error: Color(0xFFFF7777),
      onError: Color(0xFF2B0505),
      errorContainer: Color(0xFF5C1A1A),
      onErrorContainer: Color(0xFFFFCFCF),
      surface: Color(0xFF12100E),
      onSurface: Color(0xFFF7F3EE),
      onSurfaceVariant: Color(0xFFB0A79C),
      surfaceContainerLowest: Color(0xFF0D0B09),
      surfaceContainerLow: Color(0xFF171412),
      surfaceContainer: Color(0xFF1C1916),
      surfaceContainerHigh: Color(0xFF232019),
      surfaceContainerHighest: Color(0xFF2B2721),
      inverseSurface: Color(0xFFF7F3EE),
      onInverseSurface: Color(0xFF1C1916),
      inversePrimary: Color(0xFF804C14),
      outline: Color(0xFF38322C),
      outlineVariant: Color(0xFF2B2721),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    semantics: LockoutSemantics(
      success: Color(0xFF9FD980),
      onSuccess: Color(0xFF2B1703),
      warning: Color(0xFFFFC857),
      danger: Color(0xFFFF7777),
      restDay: Color(0xFFB0A79C),
      chartLine: Color(0xFFF0A868),
      chartFill: Color(0x1FF0A868),
      categoryRamp: [
        Color(0xFFF0A868),
        Color(0xFF8FD3C7),
        Color(0xFFFFC857),
        Color(0xFFFFA0A0),
        Color(0xFFC4B0F0),
        Color(0xFF9FD980),
        Color(0xFF8FC2E8),
        Color(0xFFE0C98A),
      ],
    ),
  );

  /// Cool ground, periwinkle primary.
  static const indigo = LockoutScheme(
    key: 'indigo',
    name: 'Indigo',
    brightness: Brightness.dark,
    colors: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFA8C0FF),
      onPrimary: Color(0xFF0B142B),
      primaryContainer: Color(0xFF1F3260),
      onPrimaryContainer: Color(0xFFD2DEFF),
      secondary: Color(0xFF8FE0D2),
      onSecondary: Color(0xFF032420),
      secondaryContainer: Color(0xFF0F3F38),
      onSecondaryContainer: Color(0xFFB7F0E6),
      tertiary: Color(0xFFFFC857),
      onTertiary: Color(0xFF241A00),
      tertiaryContainer: Color(0xFF4A3708),
      onTertiaryContainer: Color(0xFFFFE0A3),
      error: Color(0xFFFF7777),
      onError: Color(0xFF2B0505),
      errorContainer: Color(0xFF5C1A1A),
      onErrorContainer: Color(0xFFFFCFCF),
      surface: Color(0xFF0A0C14),
      onSurface: Color(0xFFEEF1F8),
      onSurfaceVariant: Color(0xFFA3ACBF),
      surfaceContainerLowest: Color(0xFF07090F),
      surfaceContainerLow: Color(0xFF10141C),
      surfaceContainer: Color(0xFF151A24),
      surfaceContainerHigh: Color(0xFF1B2230),
      surfaceContainerHighest: Color(0xFF232B3A),
      inverseSurface: Color(0xFFEEF1F8),
      onInverseSurface: Color(0xFF151A24),
      inversePrimary: Color(0xFF345596),
      outline: Color(0xFF2A3242),
      outlineVariant: Color(0xFF232B3A),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    semantics: LockoutSemantics(
      success: Color(0xFF8FD98F),
      onSuccess: Color(0xFF0B142B),
      warning: Color(0xFFFFC857),
      danger: Color(0xFFFF7777),
      restDay: Color(0xFFA3ACBF),
      chartLine: Color(0xFFA8C0FF),
      chartFill: Color(0x1FA8C0FF),
      categoryRamp: [
        Color(0xFFA8C0FF),
        Color(0xFF8FE0D2),
        Color(0xFFFFC857),
        Color(0xFFFF9EC4),
        Color(0xFFC2A8FF),
        Color(0xFF8FD98F),
        Color(0xFFFFAE86),
        Color(0xFFD9DB7A),
      ],
    ),
  );

  // --- LIGHT ---
  //
  // Light schemes invert the surface ladder: `surfaceContainerLowest` is the
  // brightest tone and each step darkens, so elevation still reads as a tonal
  // change rather than a shadow.

  /// Neutral off-white ground, deep olive primary.
  static const paper = LockoutScheme(
    key: 'paper',
    name: 'Paper',
    brightness: Brightness.light,
    colors: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF3F6212),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFC3EFA0),
      onPrimaryContainer: Color(0xFF1B3A00),
      secondary: Color(0xFF00629E),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFCDE5FF),
      onSecondaryContainer: Color(0xFF001D32),
      tertiary: Color(0xFF7A5900),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFE08C),
      onTertiaryContainer: Color(0xFF261A00),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFFAFAF7),
      onSurface: Color(0xFF16181A),
      onSurfaceVariant: Color(0xFF4A4F55),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF5F5F1),
      surfaceContainer: Color(0xFFF0F0EB),
      surfaceContainerHigh: Color(0xFFEAEAE4),
      surfaceContainerHighest: Color(0xFFE3E3DC),
      inverseSurface: Color(0xFF2F3033),
      onInverseSurface: Color(0xFFF2F2ED),
      inversePrimary: Color(0xFF8AC257),
      outline: Color(0xFFB4B6AF),
      outlineVariant: Color(0xFFD9DAD4),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    semantics: LockoutSemantics(
      success: Color(0xFF2E7D32),
      onSuccess: Color(0xFFFFFFFF),
      warning: Color(0xFF8A6100),
      danger: Color(0xFFB3261E),
      restDay: Color(0xFF5E6368),
      chartLine: Color(0xFF3F6212),
      chartFill: Color(0x1F3F6212),
      categoryRamp: [
        Color(0xFF3F6212),
        Color(0xFF00629E),
        Color(0xFF7A5900),
        Color(0xFF9A3B2E),
        Color(0xFF5B4B9E),
        Color(0xFF0F6B5C),
        Color(0xFFA33071),
        Color(0xFF5E6B00),
      ],
    ),
  );

  /// Warm paper ground, burnt-amber primary.
  static const linen = LockoutScheme(
    key: 'linen',
    name: 'Linen',
    brightness: Brightness.light,
    colors: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF8A5A12),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFDDB0),
      onPrimaryContainer: Color(0xFF2C1A00),
      secondary: Color(0xFF1F6A5E),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFB8EFE2),
      onSecondaryContainer: Color(0xFF00201A),
      tertiary: Color(0xFF7A5900),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFE08C),
      onTertiaryContainer: Color(0xFF261A00),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFFBF7F0),
      onSurface: Color(0xFF1B1814),
      onSurfaceVariant: Color(0xFF514A41),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF6F1E8),
      surfaceContainer: Color(0xFFF1EBE1),
      surfaceContainerHigh: Color(0xFFEBE4D9),
      surfaceContainerHighest: Color(0xFFE4DCD0),
      inverseSurface: Color(0xFF34302A),
      onInverseSurface: Color(0xFFF7F2EA),
      inversePrimary: Color(0xFFE5A05C),
      outline: Color(0xFFB8B0A3),
      outlineVariant: Color(0xFFDCD5C9),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    semantics: LockoutSemantics(
      success: Color(0xFF2E7D32),
      onSuccess: Color(0xFFFFFFFF),
      warning: Color(0xFF8A6100),
      danger: Color(0xFFB3261E),
      restDay: Color(0xFF6E665B),
      chartLine: Color(0xFF8A5A12),
      chartFill: Color(0x1F8A5A12),
      categoryRamp: [
        Color(0xFF8A5A12),
        Color(0xFF1F6A5E),
        Color(0xFF9A3B2E),
        Color(0xFF4E5C8A),
        Color(0xFF7A3E8A),
        Color(0xFF3F6212),
        Color(0xFFA33071),
        Color(0xFF5E6B00),
      ],
    ),
  );

  /// Cool white ground, deep teal primary.
  static const frost = LockoutScheme(
    key: 'frost',
    name: 'Frost',
    brightness: Brightness.light,
    colors: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0F5F6B),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFB5ECF5),
      onPrimaryContainer: Color(0xFF001F25),
      secondary: Color(0xFF2E5A9E),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFD6E3FF),
      onSecondaryContainer: Color(0xFF001A41),
      tertiary: Color(0xFF7A5900),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFE08C),
      onTertiaryContainer: Color(0xFF261A00),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFF6F8FB),
      onSurface: Color(0xFF14181C),
      onSurfaceVariant: Color(0xFF454F59),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF1F4F8),
      surfaceContainer: Color(0xFFEBEFF5),
      surfaceContainerHigh: Color(0xFFE4EAF1),
      surfaceContainerHighest: Color(0xFFDCE3EC),
      inverseSurface: Color(0xFF2A3035),
      onInverseSurface: Color(0xFFEEF1F5),
      inversePrimary: Color(0xFF5ABDD1),
      outline: Color(0xFFAAB3BD),
      outlineVariant: Color(0xFFD5DCE4),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    semantics: LockoutSemantics(
      success: Color(0xFF2E7D32),
      onSuccess: Color(0xFFFFFFFF),
      warning: Color(0xFF8A6100),
      danger: Color(0xFFB3261E),
      restDay: Color(0xFF5A646E),
      chartLine: Color(0xFF0F5F6B),
      chartFill: Color(0x1F0F5F6B),
      categoryRamp: [
        Color(0xFF0F5F6B),
        Color(0xFF2E5A9E),
        Color(0xFF7A5900),
        Color(0xFF9A3B2E),
        Color(0xFF5B4B9E),
        Color(0xFF2E7D32),
        Color(0xFFA33071),
        Color(0xFF5E6B00),
      ],
    ),
  );

  static const List<LockoutScheme> dark = [graphite, ember, indigo];
  static const List<LockoutScheme> light = [paper, linen, frost];
  static const List<LockoutScheme> all = [...dark, ...light];

  static const LockoutScheme fallback = graphite;

  /// Keys written by the previous Jinatra palette system, mapped onto the
  /// closest new scheme.
  ///
  /// Kept so an existing install does not lose its choice on upgrade and does
  /// not error on a key that no longer exists. Brightness is preserved in
  /// every mapping — waking up to a white app because a palette was retired
  /// is the one outcome worse than losing the exact hue.
  static const Map<String, String> _legacyKeys = {
    'carbon_lime': 'graphite',
    'midnight_cyan': 'indigo',
    'ash_amber': 'ember',
    'void_magenta': 'graphite',
    'jinatra_cream': 'paper',
    'paper_press': 'paper',
    'mint_lab': 'frost',
    'sunblock': 'linen',
  };

  static LockoutScheme byKey(String key) {
    final resolved = _legacyKeys[key] ?? key;
    for (final scheme in all) {
      if (scheme.key == resolved) return scheme;
    }
    return fallback;
  }
}
