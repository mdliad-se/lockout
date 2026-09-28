import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Source-level proof that the migration is complete rather than partial.
///
/// A visual redesign rots back one widget at a time: someone reaches for the
/// old token class because it is still there, and six months later half the
/// app is neubrutalist again. These tests make each of those a build failure.
///
/// They are deliberately source scans rather than widget tests. A widget test
/// can only prove the screens it pumps; this covers every file, including the
/// ones nobody remembered to write a test for.
List<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll(r'\', '/');

void main() {
  test('no widget outside lib/theme hardcodes a Color constant', () {
    final pattern = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
    final offenders = <String>[];

    for (final file in _dartFiles('lib')) {
      final path = _rel(file);
      // The theme layer is where colour is allowed to be a literal; that is
      // the whole point of it.
      if (path.contains('lib/theme/')) continue;
      // Comments are blanked so a doc comment quoting a hex value does not
      // read as a painted colour.
      if (pattern.hasMatch(blankComments(file.readAsStringSync()))) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'colour belongs in a ColorScheme or LockoutSemantics, not in a '
          'widget',
    );
  });

  test('the shipped app is called LOCKOUT, never LIAD', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      if (file.readAsStringSync().contains('LIAD')) offenders.add(_rel(file));
    }

    expect(
      offenders,
      isEmpty,
      reason: 'LIAD is the design brief\'s reference name, not the product',
    );
  });
}
