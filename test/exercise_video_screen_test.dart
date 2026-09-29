import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:lockout/screens/exercise_video_screen.dart';

import 'test_helpers.dart';

/// `ExerciseVideoScreen` had zero widget-level coverage before this suite —
/// the given reason was "no WebView platform under `flutter test`", which is
/// only half true: `WebViewController()` throws because
/// `WebViewPlatform.instance` is unset, and that is exactly what
/// `FakeWebViewPlatform` (`test_helpers.dart`) exists to inject. With it
/// registered, the screen pumps like any other, which is what would have
/// caught `initState` reading `Theme.of(context)` — forbidden by the
/// framework's own lifecycle assert — before it shipped.
void main() {
  late FakeWebViewPlatform fakePlatform;

  setUp(() {
    fakePlatform = FakeWebViewPlatform();
    WebViewPlatform.instance = fakePlatform;
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(theme: lockoutTestTheme(), home: home));
    await tester.pump();
  }

  group('ExerciseVideoScreen', () {
    // Finding 1. This is the test that turns the crash into evidence: run
    // it against the pre-fix `initState` (with `setBackgroundColor` back in
    // the cascade, ahead of `super.initState()` completing) and it fails
    // with the framework's own lifecycle assert. See the task report for
    // that red run's output.
    testWidgets('pumping the screen never throws', (tester) async {
      await pump(tester, ExerciseVideoScreen(exerciseName: 'Bench Press'));

      expect(tester.takeException(), isNull,
          reason: 'Theme.of(context) must not be read from initState');
    });

    testWidgets(
        'an unpinned exercise opens the search query and shows the webview',
        (tester) async {
      await pump(tester, ExerciseVideoScreen(exerciseName: 'Squat'));

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.text('Link not usable'), findsNothing);
      expect(find.text('Video unavailable'), findsNothing);
      expect(fakePlatform.lastController.loadedUris, isNotEmpty,
          reason: 'the search query should have been handed to loadRequest');
    });

    // Finding 2 (round 2). `FakeWebViewController.setBackgroundColor` was a
    // silent no-op, so nothing distinguished "the call happens once, after
    // `initState`" from "the call never happens at all" — deleting
    // `didChangeDependencies` outright still left every other test in this
    // suite green. This pins the call positively: see the task report for
    // that red run, captured by commenting `didChangeDependencies` out.
    testWidgets(
        "didChangeDependencies hands the theme's surface colour to the "
        'webview, exactly once', (tester) async {
      final theme = lockoutTestTheme();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: ExerciseVideoScreen(exerciseName: 'Squat'),
      ));
      await tester.pump();

      expect(fakePlatform.lastController.backgroundColors.single,
          theme.colorScheme.surface);
    });

    testWidgets(
        'a pinned link that cannot be made loadable shows the unusable '
        'notice instead of the webview, with no reload button',
        (tester) async {
      await pump(
        tester,
        ExerciseVideoScreen(
          exerciseName: 'Squat',
          videoUrl: 'javascript:alert(1)',
        ),
      );

      expect(find.text('Link not usable'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(find.byTooltip('Reload'), findsNothing,
          reason: 'there is no target to reload');
      expect(fakePlatform.lastController.loadedUris, isEmpty);
    });

    testWidgets(
        'a resource error flips to the offline notice and hides the webview',
        (tester) async {
      await pump(tester, ExerciseVideoScreen(exerciseName: 'Squat'));
      expect(find.byType(WebViewWidget), findsOneWidget);

      fakePlatform.lastController.navigationDelegate!.onWebResourceError!(
        const WebResourceError(errorCode: -2, description: 'no connection'),
      );
      await tester.pump();

      expect(find.text('Video unavailable'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });

    testWidgets(
        'progress reaching 100 hides the progress bar while the reload '
        'button, gated on the same target, stays available throughout',
        (tester) async {
      await pump(tester, ExerciseVideoScreen(exerciseName: 'Squat'));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Reload'), findsOneWidget);

      fakePlatform.lastController.navigationDelegate!.onPageFinished!('done');
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byTooltip('Reload'), findsOneWidget);
    });

    testWidgets('onProgress drives the progress bar value', (tester) async {
      await pump(tester, ExerciseVideoScreen(exerciseName: 'Squat'));

      fakePlatform.lastController.navigationDelegate!.onProgress!(42);
      await tester.pump();

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.42, 0.001));
    });

    testWidgets('retrying after a failure reloads the same target and '
        'clears the offline notice', (tester) async {
      await pump(tester, ExerciseVideoScreen(exerciseName: 'Squat'));

      fakePlatform.lastController.navigationDelegate!.onWebResourceError!(
        const WebResourceError(errorCode: -2, description: 'no connection'),
      );
      await tester.pump();
      expect(find.text('Video unavailable'), findsOneWidget);

      final loadsBefore = fakePlatform.lastController.loadedUris.length;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();

      expect(find.text('Video unavailable'), findsNothing);
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(fakePlatform.lastController.loadedUris.length, loadsBefore + 1);
    });
  });
}
