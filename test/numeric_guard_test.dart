import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/services/numeric_guard.dart';

/// The shared guard four write sites and three read sites now route through.
///
/// Settings' target weight, Settings' height, BODY's weight and BODY's waist
/// each carried their own copy of "reject non-finite, reject below the
/// floor" — and the routine builder's weight field, the one write site
/// nobody had got to, carried none of it, which is how `Infinity` reached
/// `target_weight_kg` and from there `total_volume_kg` and a LOG tab that
/// threw on every launch. One implementation means the next numeric field
/// inherits the rule instead of re-deriving three quarters of it.
void main() {
  group('finite', () {
    test('passes an ordinary number through untouched', () {
      expect(NumericGuard.finite(72.5), 72.5);
      expect(NumericGuard.finite(0), 0);
      expect(NumericGuard.finite(-5), -5);
    });

    test('rejects null and the three non-finite doubles', () {
      expect(NumericGuard.finite(null), isNull);
      expect(NumericGuard.finite(double.infinity), isNull);
      expect(NumericGuard.finite(double.negativeInfinity), isNull);
      expect(NumericGuard.finite(double.nan), isNull);
    });

    test('an inclusive floor keeps the boundary value', () {
      expect(NumericGuard.finite(0, min: 0), 0);
      expect(NumericGuard.finite(-0.1, min: 0), isNull);
    });

    // The distinction the two Settings fields need: a target weight of 0 is
    // the legitimate "not set yet", a height of 0 divides BMI by zero.
    test('an exclusive floor rejects the boundary value', () {
      expect(NumericGuard.finite(0, min: 0, minExclusive: true), isNull);
      expect(NumericGuard.finite(0.1, min: 0, minExclusive: true), 0.1);
    });
  });

  group('parse', () {
    test('reads a plain number', () {
      expect(NumericGuard.parse('72.5'), 72.5);
      expect(NumericGuard.parse('  72.5  '), 72.5);
    });

    // The whole reason this class exists: `double.tryParse` accepts all
    // three of these words, and no numeric field in the app carries
    // `inputFormatters`, so a paste or a letters keyboard reaches it.
    test('refuses the words double.tryParse would happily accept', () {
      expect(double.tryParse('Infinity'), double.infinity);
      expect(NumericGuard.parse('Infinity'), isNull);
      expect(NumericGuard.parse('-Infinity'), isNull);
      expect(NumericGuard.parse('NaN'), isNull);
    });

    test('blank and unparseable text are both null', () {
      expect(NumericGuard.parse(''), isNull);
      expect(NumericGuard.parse('   '), isNull);
      expect(NumericGuard.parse('heavy'), isNull);
    });

    test('the floor applies to parsed text as well', () {
      expect(NumericGuard.parse('-3', min: 0), isNull);
      expect(NumericGuard.parse('0', min: 0, minExclusive: true), isNull);
    });
  });

  group('sanitiseKg', () {
    test('keeps a real weight', () {
      expect(NumericGuard.sanitiseKg('62.5'), 62.5);
      expect(NumericGuard.sanitiseKg('0'), 0.0);
    });

    test('falls back rather than persisting something non-finite', () {
      expect(NumericGuard.sanitiseKg('Infinity'), 0.0);
      expect(NumericGuard.sanitiseKg('NaN'), 0.0);
      expect(NumericGuard.sanitiseKg('-10'), 0.0);
      expect(NumericGuard.sanitiseKg(''), 0.0);
    });

    test('the fallback is caller-chosen', () {
      expect(NumericGuard.sanitiseKg('Infinity', fallback: 175.0), 175.0);
    });
  });

  group('read', () {
    test('a num column reads back as itself', () {
      expect(NumericGuard.read(80), 80.0);
      expect(NumericGuard.read(80.5), 80.5);
    });

    // What a hand-edited backup, restored by a build older than the import
    // coercion, leaves in a REAL-affinity column.
    test('text in a numeric column is read, not cast', () {
      expect(NumericGuard.read('80.5'), 80.5);
      expect(NumericGuard.read('heavy'), isNull);
      expect(NumericGuard.read('Infinity'), isNull);
    });

    test('anything with no numeric meaning is null, never a throw', () {
      expect(NumericGuard.read(null), isNull);
      expect(NumericGuard.read(<int>[1]), isNull);
      expect(NumericGuard.read({'a': 1}), isNull);
      expect(NumericGuard.read(double.infinity), isNull);
    });

    test('JSON booleans land on 1 and 0, the way SQLite stores flags', () {
      expect(NumericGuard.read(true), 1.0);
      expect(NumericGuard.read(false), 0.0);
    });
  });

  // Structural, in the same spirit as the v2 style sweep's source checks:
  // the value of one shared guard is that no screen re-derives it. A new
  // `double.tryParse` in a screen is how this whole family of defects got
  // in, one field at a time.
  group('no screen re-derives the parse', () {
    test('lib/screens contains no bare double.tryParse', () {
      final offenders = <String>[];
      for (final file in Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final line in source.split('\n')) {
          final code = line.trim();
          // Prose about the hazard is not the hazard. `int.tryParse` is
          // fine either way: ints have no Infinity or NaN to let through.
          if (code.startsWith('//')) continue;
          if (code.contains('double.tryParse')) {
            offenders.add('${file.path}: $code');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'route the value through NumericGuard instead, so the '
              'finite/floor rule stays in one place');
    });
  });
}
