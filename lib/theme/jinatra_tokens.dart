import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';

/// Design tokens for the Jinatra neubrutalist system.
///
/// Colours resolve through [AppPalette.current] rather than being compile-time
/// constants, so switching theme repaints the whole app without touching call
/// sites. That is why none of the colour members are `const`.
class JinatraTokens {
  // Palette-backed colours. Names are historical (sweetCream, deepTeal...) and
  // map onto the semantic roles defined in AppPalette.
  static Color get sweetCream => AppPalette.current.canvas;
  static Color get paper => AppPalette.current.surface;
  static Color get mistTeal => AppPalette.current.surfaceAlt;
  static Color get deepTeal => AppPalette.current.primary;
  static Color get tealDeep => AppPalette.current.primaryPressed;
  static Color get ink => AppPalette.current.ink;
  static Color get signal => AppPalette.current.accent;

  /// Text/icon colour for content sitting on [deepTeal].
  static Color get onPrimary => AppPalette.current.onPrimary;

  /// Text/icon colour for content sitting on [signal].
  static Color get onAccent => AppPalette.current.onAccent;

  static bool get isDark => AppPalette.current.isDark;

  // Border & Shadow Dimensions
  static const double borderControl = 3.0;
  static const double borderHero = 4.0;
  static const double borderDivider = 2.0;

  static const double shadowSm = 3.0; // Controls
  static const double shadowMd = 6.0; // Cards
  static const double shadowLg = 10.0; // Hero elements

  // Typography Styles
  static TextStyle displayHeader({Color? color, double fontSize = 28.0}) {
    return GoogleFonts.archivo(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: color ?? ink,
      height: 1.02,
      letterSpacing: -0.5,
    );
  }

  static TextStyle sectionHeader({Color? color, double fontSize = 20.0}) {
    return GoogleFonts.archivo(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color ?? ink,
      height: 1.05,
    );
  }

  static TextStyle bodyText({
    Color? color,
    double fontSize = 15.0,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      height: 1.3,
    );
  }

  static TextStyle monoData({
    Color? color,
    double fontSize = 13.0,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: 0.2,
    );
  }

  // Hard Zero-Blur Shadow Helper
  static BoxShadow hardShadow({double offset = shadowSm, Color? shadowColor}) {
    return BoxShadow(
      color: shadowColor ?? ink,
      offset: Offset(offset, offset),
      blurRadius: 0,
      spreadRadius: 0,
    );
  }

  // Standard Neubrutalist Box Decoration
  static BoxDecoration cardDecoration({
    Color? background,
    Color? borderColor,
    double borderWidth = borderControl,
    double shadowOffset = shadowMd,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      color: background ?? paper,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: borderColor ?? ink, width: borderWidth),
      boxShadow: hasShadow ? [hardShadow(offset: shadowOffset)] : null,
    );
  }

  /// Material theme derived from the active palette, so framework-owned
  /// surfaces (dialogs, snackbars, text selection) match the neubrutalist set.
  static ThemeData materialTheme() {
    final p = AppPalette.current;
    return ThemeData(
      scaffoldBackgroundColor: p.canvas,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        primary: p.primary,
        onPrimary: p.onPrimary,
        secondary: p.accent,
        onSecondary: p.onAccent,
        surface: p.surface,
        onSurface: p.ink,
      ),
      useMaterial3: true,
    );
  }
}
