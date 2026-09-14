import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/screens/exercise_video_screen.dart';

/// `ExerciseVideoScreen` used to hand the user's raw `videoUrl` straight to
/// `WebViewController.loadRequest` from inside `initState`.
/// `webview_flutter_android` validates that request synchronously and throws
/// `ArgumentError: WebViewRequest#uri is required to have a scheme.`, and
/// `initState` is not async, so the error propagates out of it and the route
/// is a red error screen. Pasting a link without `https://` is the obvious
/// thing to do, and the screen is reachable from WATCH inside the routine
/// editor before anything has even been saved.
///
/// `flutter test` provides no WebView platform implementation, so there is
/// no way to drive a real controller here. These cover the normalisation
/// itself — the part that decides what, if anything, is handed to the
/// platform — which is why it is a top-level function rather than a private
/// method on the state.
void main() {
  group('pinnedVideoUri', () {
    test('the hazard it exists for: a pasted host has no scheme', () {
      // Not an assertion about our code — a statement of the Dart behaviour
      // the plugin then rejects. If this ever changes, the guard below is
      // merely redundant rather than wrong.
      expect(Uri.parse('youtube.com/watch?v=abc').hasScheme, isFalse);
    });

    test('a schemeless host is promoted to https with its path and query '
        'intact', () {
      final uri = pinnedVideoUri('youtube.com/watch?v=abc');
      expect(uri, isNotNull);
      expect(uri!.hasScheme, isTrue);
      expect(uri.scheme, 'https');
      expect(uri.host, 'youtube.com');
      expect(uri.path, '/watch');
      expect(uri.queryParameters['v'], 'abc');
    });

    test('www and m subdomains survive the promotion', () {
      expect(pinnedVideoUri('m.youtube.com/watch?v=abc')?.toString(),
          'https://m.youtube.com/watch?v=abc');
      expect(pinnedVideoUri('www.youtube.com/watch?v=abc')?.host,
          'www.youtube.com');
    });

    test('a fragment (the timestamp form of a share link) is kept', () {
      expect(pinnedVideoUri('youtu.be/abc#t=30')?.toString(),
          'https://youtu.be/abc#t=30');
    });

    test('a url that already has a scheme is left exactly as it is', () {
      expect(pinnedVideoUri('https://m.youtube.com/watch?v=abc')?.toString(),
          'https://m.youtube.com/watch?v=abc');
      expect(pinnedVideoUri('http://example.com/clip')?.toString(),
          'http://example.com/clip');
    });

    test('surrounding whitespace from a paste is trimmed', () {
      expect(pinnedVideoUri('  youtube.com/watch?v=abc  ')?.scheme, 'https');
    });

    test('nothing usable means null, never a throw', () {
      expect(pinnedVideoUri(''), isNull);
      expect(pinnedVideoUri('   '), isNull);
      // No host to promote: 'https://' + 'watch a video' is not parseable.
      expect(pinnedVideoUri('watch a video'), isNull);
      expect(pinnedVideoUri('///'), isNull);
    });

    test('a scheme the webview cannot load is refused rather than promoted',
        () {
      // `javascript:` and `file:` both parse and both have a scheme, so a
      // bare `hasScheme` check would hand them to the platform.
      expect(pinnedVideoUri('javascript:alert(1)'), isNull);
      expect(pinnedVideoUri('file:///etc/passwd'), isNull);
      expect(pinnedVideoUri('ftp://files.example.com/clip.mp4'), isNull);
    });

    test('every non-null result is loadable: it has a scheme and a host', () {
      const inputs = [
        'youtube.com/watch?v=abc',
        'https://m.youtube.com/watch?v=abc',
        'http://example.com',
        'youtu.be/abc',
        '  www.youtube.com/results?search_query=squat  ',
      ];
      for (final input in inputs) {
        final uri = pinnedVideoUri(input);
        expect(uri, isNotNull, reason: input);
        expect(uri!.hasScheme, isTrue, reason: input);
        expect(uri.host, isNotEmpty, reason: input);
      }
    });
  });

  group('searchVideoUri', () {
    test('the unpinned fallback always has a scheme', () {
      final uri = searchVideoUri('Barbell Bench Press');
      expect(uri.hasScheme, isTrue);
      expect(uri.scheme, 'https');
      expect(uri.host, 'm.youtube.com');
      expect(uri.queryParameters['search_query'],
          contains('Barbell Bench Press'));
    });

    test('an exercise name with characters that need encoding still parses',
        () {
      final uri = searchVideoUri('Face Pull (rope) & hold');
      expect(uri.hasScheme, isTrue);
      expect(uri.queryParameters['search_query'], contains('&'));
    });
  });
}
