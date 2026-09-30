import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// [yaml] with every comment line removed.
///
/// The pubspec explains *why* google_fonts was dropped, and a scan that
/// cannot tell a comment from a dependency would force that explanation out
/// of the file that most needs it.
String _yamlWithoutComments(String yaml) => yaml
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

/// The app is zero-network on device. `google_fonts` fetches typefaces over
/// HTTP at first paint, so every face it resolved silently fell back to
/// Roboto in the shipped APK — the chosen type had never actually rendered
/// on a phone. These tests are the guard that it now ships in the bundle.
void main() {
  test('Inter and JetBrains Mono ship as bundled assets', () {
    for (final name in const [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Bold.ttf',
    ]) {
      final file = File('assets/fonts/$name');
      expect(file.existsSync(), isTrue, reason: 'missing assets/fonts/$name');
      expect(
        file.lengthSync(),
        greaterThan(10000),
        reason: '$name looks truncated',
      );
    }
  });

  test('both font licences travel with the files', () {
    expect(File('assets/fonts/OFL-Inter.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-JetBrainsMono.txt').existsSync(), isTrue);
  });

  test('pubspec declares both families and no longer depends on google_fonts', () {
    final pubspec = _yamlWithoutComments(File('pubspec.yaml').readAsStringSync());
    expect(pubspec.contains('family: Inter'), isTrue);
    expect(pubspec.contains('family: JetBrainsMono'), isTrue);
    expect(pubspec.contains('dynamic_color:'), isTrue);
    expect(
      pubspec.contains('google_fonts:'),
      isFalse,
      reason: 'google_fonts fetches typefaces over HTTP; this app is offline',
    );
  });

  test('the lockfile no longer resolves google_fonts', () {
    final lock = File('pubspec.lock').readAsStringSync();
    expect(
      lock.contains('google_fonts'),
      isFalse,
      reason: 'a transitive dependency would put it back in the APK',
    );
  });

  test('no Dart source imports google_fonts', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Comments are blanked so the note explaining the removal does not
      // read as a live import.
      if (blankComments(entity.readAsStringSync()).contains('google_fonts')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
