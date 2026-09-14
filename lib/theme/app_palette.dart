import 'package:flutter/material.dart';

/// A complete neubrutalist colour set.
///
/// Neubrutalism needs high contrast between the border/shadow colour and every
/// surface behind it, so dark palettes invert the role of [ink]: it stays the
/// border, shadow and body-text colour, but becomes a light tone so hard edges
/// still read against a dark canvas.
class AppPalette {
  final String key;
  final String name;
  final bool isDark;

  /// Page background (60% of the screen).
  final Color canvas;

  /// Card and input interiors.
  final Color surface;

  /// Secondary surfaces, chips, stripes.
  final Color surfaceAlt;

  /// Primary actions, active nav.
  final Color primary;

  /// Pressed state of [primary].
  final Color primaryPressed;

  /// Text/icons drawn on top of [primary].
  final Color onPrimary;

  /// Borders, hard shadows, body text.
  final Color ink;

  /// The single warm highlight — one per screen, used sparingly.
  final Color accent;

  /// Text/icons drawn on top of [accent].
  final Color onAccent;

  /// Eight authored colours used wherever many categories must be told apart
  /// at a glance: training-day rails, the HOME action grid, category chips.
  ///
  /// Authored rather than derived. Rotating a single primary through HSL
  /// produced collisions — two same-category days landed on one hue — and
  /// muddy mid-tones in several themes, so each palette states its own ramp.
  final List<Color> accents;

  const AppPalette({
    required this.key,
    required this.name,
    required this.isDark,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.ink,
    required this.accent,
    required this.onAccent,
    required this.accents,
  });

  // --- LIGHT PALETTES ---

  static const jinatraCream = AppPalette(
    key: 'jinatra_cream',
    name: 'Jinatra Cream',
    isDark: false,
    canvas: Color(0xFFFFEACF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE0F0EE),
    primary: Color(0xFF0A756C),
    primaryPressed: Color(0xFF06554F),
    onPrimary: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1A1A),
    accent: Color(0xFFFF6B35),
    onAccent: Color(0xFF1A1A1A),
    accents: [
      Color(0xFF0A756C), // teal
      Color(0xFFFF6B35), // coral
      Color(0xFFF2B01E), // amber
      Color(0xFF3E7D3A), // green
      Color(0xFF2B59FF), // blue
      Color(0xFFA64BC4), // purple
      Color(0xFFE0447E), // pink
      Color(0xFF17A2B8), // cyan
    ],
  );

  static const paperPress = AppPalette(
    key: 'paper_press',
    name: 'Paper Press',
    isDark: false,
    canvas: Color(0xFFF6F3EA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFE24A),
    primary: Color(0xFFE23A2E),
    primaryPressed: Color(0xFFB52A20),
    onPrimary: Color(0xFFFFFFFF),
    ink: Color(0xFF111111),
    accent: Color(0xFF2B59FF),
    onAccent: Color(0xFFFFFFFF),
    accents: [
      Color(0xFFE23A2E), // red
      Color(0xFFFFE24A), // yellow
      Color(0xFFB6F53C), // lime
      Color(0xFF2CE0D4), // cyan
      Color(0xFF2B59FF), // blue
      Color(0xFFC77DFF), // purple
      Color(0xFFFF7AC4), // pink
      Color(0xFFFF8A3D), // orange
    ],
  );

  static const mintLab = AppPalette(
    key: 'mint_lab',
    name: 'Mint Lab',
    isDark: false,
    canvas: Color(0xFFDFF7EC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8DDFF),
    primary: Color(0xFF6C3FD4),
    primaryPressed: Color(0xFF512DA8),
    onPrimary: Color(0xFFFFFFFF),
    ink: Color(0xFF14211C),
    accent: Color(0xFFB6F53C),
    onAccent: Color(0xFF14211C),
    accents: [
      Color(0xFF6C3FD4), // purple
      Color(0xFFB6F53C), // lime
      Color(0xFF00A5A5), // teal
      Color(0xFFFF5C8A), // pink
      Color(0xFFFFB020), // amber
      Color(0xFF2B6CFF), // blue
      Color(0xFF38B000), // green
      Color(0xFFFF6B35), // orange
    ],
  );

  static const sunblock = AppPalette(
    key: 'sunblock',
    name: 'Sunblock',
    isDark: false,
    canvas: Color(0xFFFFF3C4),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFD6E4FF),
    primary: Color(0xFF1E44D6),
    primaryPressed: Color(0xFF15329E),
    onPrimary: Color(0xFFFFFFFF),
    ink: Color(0xFF141414),
    accent: Color(0xFFFF3D9A),
    onAccent: Color(0xFFFFFFFF),
    accents: [
      Color(0xFF1E44D6), // blue
      Color(0xFFFF3D9A), // pink
      Color(0xFF00A98F), // teal
      Color(0xFFFF8A00), // orange
      Color(0xFF7B2FF2), // purple
      Color(0xFFE23A2E), // red
      Color(0xFF2CB67D), // green
      Color(0xFF0FA3B1), // cyan
    ],
  );

  // --- DARK PALETTES ---

  static const carbonLime = AppPalette(
    key: 'carbon_lime',
    name: 'Carbon Lime',
    isDark: true,
    canvas: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceAlt: Color(0xFF2C2C2C),
    primary: Color(0xFFB6F53C),
    primaryPressed: Color(0xFF93C92F),
    onPrimary: Color(0xFF101610),
    ink: Color(0xFFF2F2F2),
    accent: Color(0xFFFF6B35),
    onAccent: Color(0xFF101010),
    accents: [
      Color(0xFFB6F53C), // lime
      Color(0xFFFF6B35), // orange
      Color(0xFF2CE0D4), // cyan
      Color(0xFFFFD23F), // yellow
      Color(0xFFFF4D8D), // pink
      Color(0xFF9D7BFF), // violet
      Color(0xFF4CC9F0), // sky
      Color(0xFF7CD97C), // green
    ],
  );

  static const midnightCyan = AppPalette(
    key: 'midnight_cyan',
    name: 'Midnight Cyan',
    isDark: true,
    canvas: Color(0xFF0B1524),
    surface: Color(0xFF152232),
    surfaceAlt: Color(0xFF1F3145),
    primary: Color(0xFF2CE0D4),
    primaryPressed: Color(0xFF1FB3A9),
    onPrimary: Color(0xFF04161A),
    ink: Color(0xFFEAF4FF),
    accent: Color(0xFFFF4D8D),
    onAccent: Color(0xFF10040A),
    accents: [
      Color(0xFF2CE0D4), // cyan
      Color(0xFFFF4D8D), // pink
      Color(0xFFFFC53D), // amber
      Color(0xFF7BD3FF), // sky
      Color(0xFFA78BFA), // violet
      Color(0xFF4ADE80), // green
      Color(0xFFFB923C), // orange
      Color(0xFFD4D700), // citron
    ],
  );

  static const ashAmber = AppPalette(
    key: 'ash_amber',
    name: 'Ash Amber',
    isDark: true,
    canvas: Color(0xFF1B1917),
    surface: Color(0xFF272321),
    surfaceAlt: Color(0xFF37312D),
    primary: Color(0xFFFFB020),
    primaryPressed: Color(0xFFCC8B14),
    onPrimary: Color(0xFF1B1200),
    ink: Color(0xFFF5EFE6),
    accent: Color(0xFFFF4D4D),
    onAccent: Color(0xFF1B0505),
    accents: [
      Color(0xFFFFB020), // amber
      Color(0xFFFF4D4D), // red
      Color(0xFFA3E635), // lime
      Color(0xFF22D3EE), // cyan
      Color(0xFF93C5FD), // blue
      Color(0xFFC4B5FD), // violet
      Color(0xFFFDA4AF), // rose
      Color(0xFF6EE7B7), // mint
    ],
  );

  static const voidMagenta = AppPalette(
    key: 'void_magenta',
    name: 'Void Magenta',
    isDark: true,
    canvas: Color(0xFF000000),
    surface: Color(0xFF161616),
    surfaceAlt: Color(0xFF242424),
    primary: Color(0xFFFF2BD1),
    primaryPressed: Color(0xFFC81FA4),
    onPrimary: Color(0xFF14000F),
    ink: Color(0xFFFFFFFF),
    accent: Color(0xFF25F4EE),
    onAccent: Color(0xFF001312),
    accents: [
      Color(0xFFFF2BD1), // magenta
      Color(0xFF25F4EE), // cyan
      Color(0xFFFFE347), // yellow
      Color(0xFF7CFF6B), // green
      Color(0xFF6B8CFF), // blue
      Color(0xFFFF8A3D), // orange
      Color(0xFFC77DFF), // purple
      Color(0xFFFF5C7A), // rose
    ],
  );

  static const List<AppPalette> light = [
    jinatraCream,
    paperPress,
    mintLab,
    sunblock,
  ];

  static const List<AppPalette> dark = [
    carbonLime,
    midnightCyan,
    ashAmber,
    voidMagenta,
  ];

  static const List<AppPalette> all = [...light, ...dark];

  static const AppPalette fallback = jinatraCream;

  static AppPalette byKey(String key) {
    for (final p in all) {
      if (p.key == key) return p;
    }
    return fallback;
  }

  // --- ACTIVE PALETTE ---

  /// Bumped whenever the palette changes so the app root rebuilds. Kept as a
  /// notifier rather than an InheritedWidget because JinatraTokens is read
  /// statically from ~400 call sites that have no BuildContext.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static AppPalette _current = fallback;

  static AppPalette get current => _current;

  static void apply(AppPalette palette) {
    if (palette.key == _current.key) return;
    _current = palette;
    revision.value++;
  }

  static void applyKey(String key) => apply(byKey(key));
}
