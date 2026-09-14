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
  // the value of one shared guard is that nothing re-derives it. A new
  // `double.tryParse` is how this whole family of defects got in, one field
  // at a time — and the first version of this check scanned `lib/screens`
  // only, which is exactly how `GoalService` kept its own private copy of
  // the finite/floor rule for a whole branch after the consolidation was
  // declared done. Services read the same poisoned rows screens do.
  group('nothing in lib re-derives the parse', () {
    test('the scanner reads code, not prose, and follows a split call', () {
      const sample = '''
/* double.tryParse inside a block comment is prose, not a call */
// and so is double.tryParse in a line comment
/// as is `double.tryParse` in a doc comment
final label = 'double.tryParse';
final value = double
    .tryParse(raw);
''';
      final matches =
          RegExp(r'double\s*\.\s*tryParse').allMatches(blankComments(sample));
      // Only the real call and the string literal survive — and the split
      // call is found, which the old line-by-line check could not see.
      expect(matches, hasLength(2));
    });

    test('lib contains no bare double.tryParse outside NumericGuard', () {
      final offenders = <String>[];
      var scanned = 0;
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll(r'\', '/');
        // The one call the whole rule exists to concentrate in one place.
        if (path.endsWith('lib/services/numeric_guard.dart')) continue;
        scanned++;
        // `int.tryParse` is fine either way: ints have no Infinity or NaN
        // to let through.
        final code = blankComments(file.readAsStringSync());
        for (final match in RegExp(r'double\s*\.\s*tryParse').allMatches(code)) {
          final line = '\n'.allMatches(code.substring(0, match.start)).length;
          offenders.add('$path:${line + 1}');
        }
      }
      // Without this, a mistyped directory makes the loop iterate zero
      // times and the offender list come back empty — the shape in which
      // this test passes loudly while checking nothing at all.
      expect(scanned, greaterThan(0),
          reason: 'scanned no Dart files: the path is wrong');
      expect(offenders, isEmpty,
          reason: 'route the value through NumericGuard instead, so the '
              'finite/floor rule stays in one place');
    });
  });
}

/// [source] with every comment blanked out, character for character, so an
/// offset into the result still maps to the same line of the original.
///
/// A line-by-line filter cannot do this job: it misses the `double\n
/// .tryParse(` shape `dart format` produces from a long enough expression,
/// and it flags `/* prose */` it has no way to recognise as a comment.
///
/// String literals are skipped rather than blanked, so text *about* the
/// hazard in a message still reads as text; interpolation holding its own
/// quotes (`'${map['k']}'`) would end the skip early, which errs toward
/// scanning more of the file as code rather than less.
String blankComments(String source) {
  final out = source.split('');
  var i = 0;

  void blank(int at) {
    if (source[at] != '\n') out[at] = ' ';
  }

  while (i < source.length) {
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        blank(i++);
      }
    } else if (source.startsWith('/*', i)) {
      // Dart's block comments nest.
      var depth = 0;
      while (i < source.length) {
        if (source.startsWith('/*', i)) {
          depth++;
          blank(i++);
          blank(i++);
        } else if (source.startsWith('*/', i)) {
          depth--;
          blank(i++);
          blank(i++);
          if (depth == 0) break;
        } else {
          blank(i++);
        }
      }
    } else if (source[i] == "'" || source[i] == '"') {
      i = _endOfStringLiteral(source, i);
    } else {
      i++;
    }
  }
  return out.join();
}

/// The offset just past the literal opening at [start].
int _endOfStringLiteral(String source, int start) {
  final quote = source[start];
  final isRaw = start > 0 && (source[start - 1] == 'r' || source[start - 1] == 'R');
  final tripled = quote + quote + quote;
  final delimiter = source.startsWith(tripled, start) ? tripled : quote;
  var i = start + delimiter.length;
  while (i < source.length) {
    if (!isRaw && source[i] == r'\') {
      i += 2;
      continue;
    }
    if (source.startsWith(delimiter, i)) return i + delimiter.length;
    // An unterminated single-quoted literal ends at the newline; bail there
    // rather than swallowing the rest of the file.
    if (delimiter.length == 1 && source[i] == '\n') return i;
    i++;
  }
  return source.length;
}
