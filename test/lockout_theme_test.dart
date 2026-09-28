import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_semantics.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';

ThemeData _themeFor(LockoutScheme scheme) =>
    LockoutTheme.build(colors: scheme.colors, semantics: scheme.semantics);

double _radiusOf(ShapeBorder? shape) {
  final rounded = shape as RoundedRectangleBorder;
  return rounded.borderRadius.resolve(TextDirection.ltr).topLeft.x;
}

void main() {
  test('build registers the semantics extension', () {
    final theme = _themeFor(LockoutScheme.graphite);
    final semantics = theme.extension<LockoutSemantics>();

    expect(semantics, isNotNull);
    expect(semantics!.categoryRamp.length, 8);
    expect(semantics.success, LockoutScheme.graphite.semantics.success);
  });

  test('build uses Material 3 and carries the scheme through', () {
    final theme = _themeFor(LockoutScheme.graphite);

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, LockoutScheme.graphite.colors.primary);
    expect(theme.scaffoldBackgroundColor, LockoutScheme.graphite.colors.surface);
    expect(theme.brightness, Brightness.dark);
  });

  test('a light scheme builds a light theme', () {
    final theme = _themeFor(LockoutScheme.paper);

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, LockoutScheme.paper.colors.surface);
  });

  test('the shape scale reaches the component themes', () {
    final theme = _themeFor(LockoutScheme.graphite);

    expect(_radiusOf(theme.cardTheme.shape), LockoutTheme.radiusCard);
    expect(_radiusOf(theme.dialogTheme.shape), LockoutTheme.radiusDialog);
    expect(
      _radiusOf(theme.filledButtonTheme.style!.shape!.resolve({})),
      LockoutTheme.radiusButton,
    );
    expect(
      _radiusOf(theme.outlinedButtonTheme.style!.shape!.resolve({})),
      LockoutTheme.radiusButton,
    );
  });

  test('the bottom sheet rounds its top corners only', () {
    final theme = _themeFor(LockoutScheme.graphite);
    final radius = (theme.bottomSheetTheme.shape as RoundedRectangleBorder)
        .borderRadius
        .resolve(TextDirection.ltr);

    expect(radius.topLeft.x, LockoutTheme.radiusSheet);
    expect(radius.topRight.x, LockoutTheme.radiusSheet);
    expect(radius.bottomLeft.x, 0);
    expect(radius.bottomRight.x, 0);
  });

  test('every text style resolves to a bundled family', () {
    final text = _themeFor(LockoutScheme.graphite).textTheme;

    for (final style in <TextStyle?>[
      text.displayLarge,
      text.displayMedium,
      text.displaySmall,
      text.headlineLarge,
      text.headlineMedium,
      text.headlineSmall,
      text.titleLarge,
      text.titleMedium,
      text.titleSmall,
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ]) {
      expect(style, isNotNull);
      expect(
        style!.fontFamily,
        anyOf('Inter', 'JetBrainsMono'),
        reason: 'unbundled family ${style.fontFamily}',
      );
    }
  });

  test('the type scale matches the design brief', () {
    final text = _themeFor(LockoutScheme.graphite).textTheme;

    expect(text.displaySmall!.fontSize, 36);
    expect(text.displaySmall!.fontWeight, FontWeight.w700);
    expect(text.headlineMedium!.fontSize, 28);
    expect(text.headlineMedium!.fontWeight, FontWeight.w700);
    expect(text.titleMedium!.fontSize, 18);
    expect(text.titleMedium!.fontWeight, FontWeight.w600);
    expect(text.bodyMedium!.fontSize, 14);
    expect(text.labelMedium!.fontSize, 12);
    expect(text.labelSmall!.fontSize, 11);
  });

  testWidgets('numeric() is mono so digits keep their column', (tester) async {
    late TextStyle style;
    await tester.pumpWidget(MaterialApp(
      theme: _themeFor(LockoutScheme.graphite),
      home: Builder(
        builder: (context) {
          style = LockoutTheme.numeric(context);
          return const SizedBox();
        },
      ),
    ));

    expect(style.fontFamily, 'JetBrainsMono');
    expect(style.color, LockoutScheme.graphite.colors.onSurface);
  });

  test('the navigation bar is 80dp with a pill indicator', () {
    final theme = _themeFor(LockoutScheme.graphite);

    expect(theme.navigationBarTheme.height, LockoutTheme.navBarHeight);
    expect(theme.navigationBarTheme.indicatorShape, isA<StadiumBorder>());
    expect(
      theme.navigationBarTheme.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );
  });

  test('a filled button clears the 52dp control height', () {
    final theme = _themeFor(LockoutScheme.graphite);
    final size = theme.filledButtonTheme.style!.minimumSize!.resolve({})!;

    expect(size.height, greaterThanOrEqualTo(52));
  });

  test('no theme paints a hard border or a heavy shadow', () {
    for (final scheme in LockoutScheme.all) {
      final theme = _themeFor(scheme);

      expect(theme.cardTheme.elevation, lessThanOrEqualTo(3.0), reason: scheme.key);
      final side = (theme.cardTheme.shape as RoundedRectangleBorder).side;
      expect(
        side.width,
        lessThanOrEqualTo(1.0),
        reason: '${scheme.key}: the 3px ink border is retired',
      );
    }
  });

  test('the progress track is a rounded 8dp bar in the primary role', () {
    final theme = _themeFor(LockoutScheme.graphite);

    expect(theme.progressIndicatorTheme.linearMinHeight, 8);
    expect(
      theme.progressIndicatorTheme.color,
      LockoutScheme.graphite.colors.primary,
    );
  });

  test('builds for every scheme without throwing', () {
    for (final scheme in LockoutScheme.all) {
      expect(() => _themeFor(scheme), returnsNormally, reason: scheme.key);
    }
  });

  test('pushed routes fade forwards rather than zooming', () {
    final theme = _themeFor(LockoutScheme.graphite);
    final builder = theme.pageTransitionsTheme.builders[TargetPlatform.android];

    // PredictiveBackPageTransitionsBuilder is the SDK default and is the
    // right answer: it runs the predictive-back preview only while a real
    // back gesture is in progress and delegates every other navigation to
    // FadeForwardsPageTransitionsBuilder, which is the Expressive motion the
    // brief asks for. Pinning FadeForwards directly would buy nothing and
    // cost the back gesture, so this asserts the outcome (not Zoom, and the
    // Expressive duration) rather than one specific class.
    expect(builder, isNot(isA<ZoomPageTransitionsBuilder>()));
    expect(
      builder!.transitionDuration.inMilliseconds,
      FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
    );
  });

  test('the spacing grid is in multiples of four', () {
    for (final space in const [
      LockoutTheme.spaceXs,
      LockoutTheme.spaceSm,
      LockoutTheme.spaceMd,
      LockoutTheme.spaceLg,
      LockoutTheme.spaceXl,
      LockoutTheme.screenPadding,
      LockoutTheme.cardPadding,
      LockoutTheme.sectionGap,
    ]) {
      expect(space % 4, 0, reason: '$space is off the grid');
    }
  });
}
