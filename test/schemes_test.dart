import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/schemes.dart';

/// WCAG relative-contrast ratio, so "is this label readable" is a number
/// rather than an opinion. Carried over from the palette suite this replaces.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('three dark and three light schemes, all keys unique', () {
    expect(LockoutScheme.dark.length, 3);
    expect(LockoutScheme.light.length, 3);
    expect(LockoutScheme.all.length, 6);
    final keys = LockoutScheme.all.map((s) => s.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('brightness matches the list the scheme lives in', () {
    for (final s in LockoutScheme.dark) {
      expect(s.brightness, Brightness.dark, reason: s.key);
      expect(s.colors.brightness, Brightness.dark, reason: s.key);
    }
    for (final s in LockoutScheme.light) {
      expect(s.brightness, Brightness.light, reason: s.key);
      expect(s.colors.brightness, Brightness.light, reason: s.key);
    }
  });

  test('graphite carries the design brief values exactly', () {
    final c = LockoutScheme.graphite.colors;
    expect(c.surface, const Color(0xFF080A0D));
    expect(c.surfaceContainer, const Color(0xFF151A20));
    expect(c.onSurface, const Color(0xFFF5F7FA));
    expect(c.onSurfaceVariant, const Color(0xFF9BA5B1));
    expect(c.primary, const Color(0xFFA3E86D));
    expect(c.onPrimary, const Color(0xFF101419));
    expect(c.secondary, const Color(0xFF75D9FF));
    expect(c.outline, const Color(0xFF272E36));
    expect(c.error, const Color(0xFFFF7777));
  });

  test('graphite is the fallback, and it is dark', () {
    expect(LockoutScheme.fallback.key, 'graphite');
    expect(LockoutScheme.fallback.brightness, Brightness.dark);
  });

  test('every foreground role is readable on its own background', () {
    for (final s in LockoutScheme.all) {
      final c = s.colors;
      final pairs = <String, List<Color>>{
        'onSurface': [c.onSurface, c.surface],
        'onSurfaceVariant': [c.onSurfaceVariant, c.surface],
        'onPrimary': [c.onPrimary, c.primary],
        'onSecondary': [c.onSecondary, c.secondary],
        'onTertiary': [c.onTertiary, c.tertiary],
        'onError': [c.onError, c.error],
        'onPrimaryContainer': [c.onPrimaryContainer, c.primaryContainer],
        'onSecondaryContainer': [c.onSecondaryContainer, c.secondaryContainer],
        'onTertiaryContainer': [c.onTertiaryContainer, c.tertiaryContainer],
        'onErrorContainer': [c.onErrorContainer, c.errorContainer],
        'onInverseSurface': [c.onInverseSurface, c.inverseSurface],
        'onSuccess': [s.semantics.onSuccess, s.semantics.success],
      };
      pairs.forEach((name, pair) {
        expect(
          _contrast(pair[0], pair[1]),
          greaterThanOrEqualTo(4.5),
          reason: '${s.key} $name',
        );
      });
    }
  });

  test('body text is readable on every surface container tone', () {
    for (final s in LockoutScheme.all) {
      final c = s.colors;
      final surfaces = <String, Color>{
        'surfaceContainerLowest': c.surfaceContainerLowest,
        'surfaceContainerLow': c.surfaceContainerLow,
        'surfaceContainer': c.surfaceContainer,
        'surfaceContainerHigh': c.surfaceContainerHigh,
        'surfaceContainerHighest': c.surfaceContainerHighest,
      };
      surfaces.forEach((name, background) {
        expect(
          _contrast(c.onSurface, background),
          greaterThanOrEqualTo(4.5),
          reason: '${s.key} onSurface on $name',
        );
      });
    }
  });

  test('surface container tones step in one direction, never flat', () {
    for (final s in LockoutScheme.all) {
      final c = s.colors;
      final tones = [
        c.surfaceContainerLowest,
        c.surfaceContainerLow,
        c.surfaceContainer,
        c.surfaceContainerHigh,
        c.surfaceContainerHighest,
      ].map((colour) => colour.computeLuminance()).toList();

      for (var i = 0; i < tones.length - 1; i++) {
        // Dark schemes lift by getting lighter, light schemes by getting
        // darker. Either is fine; a flat pair is not, because elevation in
        // this design is carried by tone rather than by shadow.
        expect(
          tones[i],
          isNot(closeTo(tones[i + 1], 0.0005)),
          reason: '${s.key} container tones $i and ${i + 1} are the same',
        );
      }
    }
  });

  test('every scheme authors exactly eight distinct, labellable ramp colours',
      () {
    for (final s in LockoutScheme.all) {
      final ramp = s.semantics.categoryRamp;
      expect(ramp.length, 8, reason: s.key);
      expect(ramp.map((c) => c.toARGB32()).toSet().length, 8, reason: s.key);
      for (final colour in ramp) {
        expect(
          _contrast(colour, s.colors.surface),
          greaterThanOrEqualTo(3.0),
          reason: '${s.key} ${colour.toARGB32().toRadixString(16)}',
        );
      }
    }
  });

  test('semantic roles stay distinguishable from each other', () {
    for (final s in LockoutScheme.all) {
      final semantics = s.semantics;
      final roles = [
        semantics.success,
        semantics.warning,
        semantics.danger,
        semantics.restDay,
      ].map((c) => c.toARGB32()).toList();
      expect(
        roles.toSet().length,
        roles.length,
        reason: '${s.key}: success, warning, danger and restDay must differ',
      );
    }
  });

  test('categoryAt wraps instead of throwing', () {
    final semantics = LockoutScheme.graphite.semantics;
    expect(semantics.categoryAt(8), semantics.categoryAt(0));
    expect(semantics.categoryAt(11), semantics.categoryAt(3));
    expect(semantics.categoryAt(0), semantics.categoryRamp.first);
  });

  test('byKey resolves new keys, legacy Jinatra keys, and junk', () {
    expect(LockoutScheme.byKey('graphite').key, 'graphite');
    expect(LockoutScheme.byKey('paper').key, 'paper');

    // Every key the previous palette system could have written.
    expect(LockoutScheme.byKey('carbon_lime').key, 'graphite');
    expect(LockoutScheme.byKey('midnight_cyan').key, 'indigo');
    expect(LockoutScheme.byKey('ash_amber').key, 'ember');
    expect(LockoutScheme.byKey('void_magenta').key, 'graphite');
    expect(LockoutScheme.byKey('jinatra_cream').key, 'paper');
    expect(LockoutScheme.byKey('paper_press').key, 'paper');
    expect(LockoutScheme.byKey('mint_lab').key, 'frost');
    expect(LockoutScheme.byKey('sunblock').key, 'linen');

    expect(LockoutScheme.byKey('nonsense').key, LockoutScheme.fallback.key);
    expect(LockoutScheme.byKey('').key, LockoutScheme.fallback.key);
  });

  test('a legacy dark key never resolves to a light scheme', () {
    for (final legacy in const [
      'carbon_lime',
      'midnight_cyan',
      'ash_amber',
      'void_magenta',
    ]) {
      expect(
        LockoutScheme.byKey(legacy).brightness,
        Brightness.dark,
        reason: '$legacy was a dark palette',
      );
    }
    for (final legacy in const [
      'jinatra_cream',
      'paper_press',
      'mint_lab',
      'sunblock',
    ]) {
      expect(
        LockoutScheme.byKey(legacy).brightness,
        Brightness.light,
        reason: '$legacy was a light palette',
      );
    }
  });

  test('lerp moves every semantic field and keeps the ramp intact', () {
    final a = LockoutScheme.graphite.semantics;
    final b = LockoutScheme.paper.semantics;
    final mid = a.lerp(b, 0.5);

    expect(mid.success, isNot(a.success));
    expect(mid.warning, isNot(a.warning));
    expect(mid.restDay, isNot(a.restDay));
    expect(mid.categoryRamp.length, 8);
    expect(a.lerp(null, 0.5), same(a));
  });

  test('copyWith replaces only what it is given', () {
    final base = LockoutScheme.graphite.semantics;
    final changed = base.copyWith(warning: const Color(0xFF123456));

    expect(changed.warning, const Color(0xFF123456));
    expect(changed.success, base.success);
    expect(changed.categoryRamp, base.categoryRamp);
  });
}
