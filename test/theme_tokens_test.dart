import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';

/// WCAG relative-contrast ratio, so "is this label readable" is a number
/// rather than an opinion.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Accent ramp', () {
    test('every palette authors exactly eight accents', () {
      for (final p in AppPalette.all) {
        expect(p.accents.length, 8, reason: p.key);
      }
    });

    test('accents within a palette are distinct', () {
      for (final p in AppPalette.all) {
        final values = p.accents.map((c) => c.toARGB32()).toList();
        expect(values.toSet().length, values.length, reason: p.key);
      }
    });

    test('every accent can carry a readable label', () {
      for (final p in AppPalette.all) {
        for (final accent in p.accents) {
          final on = JinatraTokens.onAccentColor(accent);
          expect(
            _contrast(accent, on),
            greaterThanOrEqualTo(3.0),
            reason: '${p.key} ${accent.toARGB32().toRadixString(16)}',
          );
        }
      }
    });

    test('accents follow the active palette', () {
      AppPalette.apply(AppPalette.paperPress);
      expect(JinatraTokens.accents, AppPalette.paperPress.accents);
      AppPalette.apply(AppPalette.voidMagenta);
      expect(JinatraTokens.accents, AppPalette.voidMagenta.accents);
      AppPalette.apply(AppPalette.fallback);
    });

    test('accentAt wraps past the end of the ramp', () {
      AppPalette.apply(AppPalette.paperPress);
      expect(JinatraTokens.accentAt(8), JinatraTokens.accentAt(0));
      expect(JinatraTokens.accentAt(11), JinatraTokens.accentAt(3));
    });

    test('on-accent picks the higher-contrast of ink-black and white', () {
      expect(JinatraTokens.onAccentColor(const Color(0xFFFFE24A)),
          const Color(0xFF111111));
      expect(JinatraTokens.onAccentColor(const Color(0xFF1E44D6)),
          const Color(0xFFFFFFFF));
    });
  });

  group('Radius tokens', () {
    test('v2 radii are the pinned values', () {
      expect(JinatraTokens.radiusCard, 14.0);
      expect(JinatraTokens.radiusTile, 12.0);
      expect(JinatraTokens.radiusPill, 999.0);
    });

    test('cardDecoration rounds to the card radius by default', () {
      final d = JinatraTokens.cardDecoration();
      expect(d.borderRadius, BorderRadius.circular(JinatraTokens.radiusCard));
    });

    test('cardDecoration honours an explicit radius', () {
      final d = JinatraTokens.cardDecoration(radius: JinatraTokens.radiusTile);
      expect(d.borderRadius, BorderRadius.circular(JinatraTokens.radiusTile));
    });
  });
}
