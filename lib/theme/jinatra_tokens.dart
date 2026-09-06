import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JinatraTokens {
  // Brand Colors (Jinatra Product System v1.1)
  static const Color sweetCream = Color(0xFFFFEACF); // 60% App Canvas
  static const Color paper = Color(0xFFFFFFFF);      // Card & Input interiors
  static const Color mistTeal = Color(0xFFE0F0EE);   // Secondary surfaces, stripes
  static const Color deepTeal = Color(0xFF0A756C);   // Primary actions, active nav
  static const Color tealDeep = Color(0xFF06554F);   // Pressed Teal state
  static const Color ink = Color(0xFF1A1A1A);        // Borders, shadows, body text
  static const Color signal = Color(0xFFFF6B35);     // Warm orange single highlight

  // Border & Shadow Dimensions
  static const double borderControl = 3.0;
  static const double borderHero = 4.0;
  static const double borderDivider = 2.0;
  
  static const double shadowSm = 3.0; // Controls
  static const double shadowMd = 6.0; // Cards
  static const double shadowLg = 10.0; // Hero elements

  // Typography Styles
  static TextStyle displayHeader({Color color = ink, double fontSize = 28.0}) {
    return GoogleFonts.archivo(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: color,
      height: 1.02,
      letterSpacing: -0.5,
    );
  }

  static TextStyle sectionHeader({Color color = ink, double fontSize = 20.0}) {
    return GoogleFonts.archivo(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
      height: 1.05,
    );
  }

  static TextStyle bodyText({Color color = ink, double fontSize = 15.0, FontWeight fontWeight = FontWeight.w400}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle monoData({Color color = ink, double fontSize = 13.0, FontWeight fontWeight = FontWeight.w700}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.2,
    );
  }

  // Hard Zero-Blur Shadow Helper
  static BoxShadow hardShadow({double offset = shadowSm, Color shadowColor = ink}) {
    return BoxShadow(
      color: shadowColor,
      offset: Offset(offset, offset),
      blurRadius: 0,
      spreadRadius: 0,
    );
  }

  // Standard Neubrutalist Box Decoration
  static BoxDecoration cardDecoration({
    Color background = paper,
    Color borderColor = ink,
    double borderWidth = borderControl,
    double shadowOffset = shadowMd,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: hasShadow ? [hardShadow(offset: shadowOffset)] : null,
    );
  }
}
