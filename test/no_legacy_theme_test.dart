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
///
/// Every test here asserts that something is *absent*, which is exactly the
/// shape of assertion that an empty scan satisfies. If the extension filter
/// or the enumeration itself stopped matching any file, the scan would find
/// nothing and turn the whole file green without reading a line of source.
/// The non-empty assertion below is what stops that, and it lives in the
/// helper so every present and future caller inherits it.
List<File> _dartFiles(String root) {
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  expect(
    files,
    isNotEmpty,
    reason: 'no .dart file was found under $root/, so this scan saw nothing '
        'and would pass having proved nothing',
  );

  return files;
}

String _rel(File f) => f.path.replaceAll(r'\', '/');

/// The two deliberate survivors of the Jinatra deletion, as exact source text.
///
/// Allowing the *text* rather than the whole file is the point. An allowlist
/// of file paths would let a genuine new Jinatra reference reappear inside
/// `schemes.dart` or `settings_screen.dart` unnoticed — exactly the rot this
/// suite exists to prevent. Each entry below is removed from the source
/// before the scan, so anything else in the same file still fails.
///
/// Do not "clean up" either entry:
///   * `schemes.dart` carries the migration map that moves an existing
///     install's persisted `theme_key` off the retired palette keys.
///     `jinatra_cream` maps to `paper`. Delete it and every user who chose
///     that palette silently loses their setting on upgrade.
///   * `settings_screen.dart` carries the legal publisher attribution shown
///     in the About card. It names the company, not a theme.
const _allowedJinatraText = <String, List<String>>{
  'lib/theme/schemes.dart': ["'jinatra_cream': 'paper',"],
  'lib/screens/settings_screen.dart': ['Published by Jinatra Ltd.'],
};

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

  test('no file under lib references the deleted Jinatra theme layer', () {
    final pattern = RegExp('Jinatra|jinatra|AppPalette');
    final offenders = <String>[];
    // An allowlist entry only does anything on a path the scan actually
    // visits. If a survivor file is renamed or moved, its entry stops
    // applying *and* stops being checked, both silently. Tracking what the
    // scan consumed turns that into a failure.
    final unvisited = _allowedJinatraText.keys.toSet();

    for (final file in _dartFiles('lib')) {
      final path = _rel(file);
      unvisited.remove(path);
      // Comments are blanked so a doc comment explaining the migration does
      // not read as a live reference.
      var source = blankComments(file.readAsStringSync());

      for (final allowed in _allowedJinatraText[path] ?? const <String>[]) {
        // If a survivor is ever removed for real, the allowlist must shrink
        // with it rather than quietly permitting something new.
        expect(
          source,
          contains(allowed),
          reason: '$path no longer contains "$allowed"; drop it from '
              '_allowedJinatraText',
        );
        source = source.replaceAll(allowed, '');
      }

      if (pattern.hasMatch(source)) offenders.add(path);
    }

    expect(
      unvisited,
      isEmpty,
      reason: 'the scan never reached these allowlisted paths, so their '
          'entries no longer guard anything; move or drop them in '
          '_allowedJinatraText',
    );

    expect(
      offenders,
      isEmpty,
      reason: 'the Jinatra theme layer is deleted; colour, type and shape '
          'resolve through Theme.of(context), ColorScheme and '
          'LockoutSemantics',
    );
  });

  test('no file under lib is named after the Jinatra theme layer', () {
    // The content grep reads source, never file names. A resurrected
    // `jinatra_tokens.dart` whose symbols had been renamed would sail past
    // it, and the disk check below pins two exact paths and nothing else.
    // This scans the names of every file the enumeration found.
    final pattern = RegExp('jinatra|app_?palette', caseSensitive: false);
    final offenders = <String>[];

    for (final file in _dartFiles('lib')) {
      final path = _rel(file);
      if (pattern.hasMatch(path)) offenders.add(path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'a file named for the deleted theme layer is back under lib/; '
          'renaming its symbols does not make it a new layer',
    );
  });

  test('the Jinatra theme files are gone from disk', () {
    // These paths are relative, so a runner with the wrong working directory
    // would find none of them and pass. Pin a file that must exist first, so
    // "absent" means absent rather than "looked in the wrong place".
    expect(
      File('lib/theme/lockout_theme.dart').existsSync(),
      isTrue,
      reason: 'lib/theme/lockout_theme.dart was not found, so the absence '
          'checks below prove nothing about where the theme layer lives',
    );

    for (final path in const [
      'lib/theme/jinatra_tokens.dart',
      'lib/theme/app_palette.dart',
    ]) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path is dead; reaching for it is how the redesign rots back',
      );
    }
  });
}
