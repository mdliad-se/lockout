import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/lockout_card.dart';
import 'package:lockout/widgets/lockout_field.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';

ThemeData _theme([LockoutScheme scheme = LockoutScheme.graphite]) =>
    LockoutTheme.build(colors: scheme.colors, semantics: scheme.semantics);

Widget _host(Widget child, {LockoutScheme scheme = LockoutScheme.graphite}) =>
    MaterialApp(theme: _theme(scheme), home: Scaffold(body: child));

Widget _sheetOpener({String title = 'Add day'}) => Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showLockoutSheet<void>(
            context: context,
            title: title,
            builder: (_) => const SizedBox(height: 120, child: Text('inside')),
          ),
          child: const Text('open'),
        ),
      ),
    );

void main() {
  group('LockoutCard', () {
    testWidgets('takes colour and shape from the theme, never a constant',
        (tester) async {
      await tester.pumpWidget(_host(LockoutCard(child: const Text('x'))));
      await tester.pump();

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, isNull, reason: 'colour must come from CardThemeData');
      expect(card.shape, isNull, reason: 'shape must come from CardThemeData');
    });

    testWidgets('a tappable card is inkable and clears 48dp', (tester) async {
      await tester.pumpWidget(
        _host(LockoutCard(onTap: () {}, child: const Text('x'))),
      );
      await tester.pump();

      expect(find.byType(InkWell), findsOneWidget);
      expect(
        tester.getSize(find.byType(LockoutCard)).height,
        greaterThanOrEqualTo(LockoutTheme.minTouchTarget),
      );
    });

    testWidgets('a plain card adds no tap affordance', (tester) async {
      await tester.pumpWidget(_host(LockoutCard(child: const Text('x'))));
      await tester.pump();

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('onTap actually fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(LockoutCard(onTap: () => tapped = true, child: const Text('x'))),
      );
      await tester.pump();

      await tester.tap(find.byType(LockoutCard));
      expect(tapped, isTrue);
    });

    testWidgets('elevated lifts, default does not', (tester) async {
      await tester.pumpWidget(_host(Column(children: [
        LockoutCard(elevated: true, child: const Text('lead')),
        LockoutCard(child: const Text('rest')),
      ])));
      await tester.pump();

      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards[0].elevation, 3);
      expect(cards[1].elevation, isNull, reason: 'inherits CardThemeData');
    });
  });

  group('LockoutField', () {
    testWidgets('renders a themed field with its label and unit',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        LockoutField(controller: controller, label: 'Weight', suffix: 'kg'),
      ));
      await tester.pump();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('typing reaches the controller and onChanged', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var seen = '';

      await tester.pumpWidget(_host(LockoutField(
        controller: controller,
        label: 'Reps',
        onChanged: (v) => seen = v,
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '12');

      expect(controller.text, '12');
      expect(seen, '12');
    });

    testWidgets('its fill tracks the theme rather than a constant',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      // TextFormField merges InputDecorationTheme into the decoration before
      // the inner TextField sees it, so asserting `fillColor == null` would
      // only prove where the merge happens. Asserting the resolved value
      // against two different schemes proves it actually came from the theme.
      Future<Color?> fillUnder(LockoutScheme scheme) async {
        await tester.pumpWidget(
          _host(
            LockoutField(controller: controller, label: 'Weight'),
            scheme: scheme,
          ),
        );
        // pumpAndSettle: MaterialApp animates a theme change, so a single
        // pump would still sample the previous scheme's fill.
        await tester.pumpAndSettle();
        return tester
            .widget<TextField>(find.byType(TextField))
            .decoration!
            .fillColor;
      }

      expect(
        await fillUnder(LockoutScheme.graphite),
        LockoutScheme.graphite.colors.surfaceContainerHigh,
      );
      expect(
        await fillUnder(LockoutScheme.paper),
        LockoutScheme.paper.colors.surfaceContainerHigh,
      );
    });
  });

  group('sheets', () {
    testWidgets('open with the title, a drag handle and 28dp top corners',
        (tester) async {
      await tester.pumpWidget(_host(_sheetOpener()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Add day'), findsOneWidget);
      expect(find.text('inside'), findsOneWidget);

      final context = tester.element(find.text('Add day'));
      final sheetTheme = Theme.of(context).bottomSheetTheme;
      expect(sheetTheme.showDragHandle, isTrue);
      expect(
        (sheetTheme.shape as RoundedRectangleBorder)
            .borderRadius
            .resolve(TextDirection.ltr)
            .topLeft
            .x,
        LockoutTheme.radiusSheet,
      );
    });

    testWidgets('a sheet keeps clear of the system navigation bar',
        (tester) async {
      // The regression fixed at b42586d: an isScrollControlled sheet without
      // useSafeArea runs under the system bars. showLockoutRawSheet owns that
      // property so a call site cannot forget it.
      tester.view.physicalSize = const Size(640, 1000);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 48);
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 48);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_sheetOpener()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final bottom = tester.getBottomLeft(find.text('inside')).dy;
      expect(
        bottom,
        lessThanOrEqualTo(1000.0 - 48.0),
        reason: 'the sheet ran under the navigation bar',
      );
    });

    testWidgets('the raw sheet carries the same properties', (tester) async {
      await tester.pumpWidget(_host(Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showLockoutRawSheet<void>(
              context: context,
              builder: (_) => const SizedBox(height: 80, child: Text('raw')),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('raw'), findsOneWidget);
    });

    testWidgets('a sheet returns what it pops', (tester) async {
      String? result;
      await tester.pumpWidget(_host(Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              result = await showLockoutSheet<String>(
                context: context,
                title: 'Pick',
                builder: (ctx) => TextButton(
                  onPressed: () => Navigator.of(ctx).pop('chosen'),
                  child: const Text('choose'),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('choose'));
      await tester.pumpAndSettle();

      expect(result, 'chosen');
    });
  });

  testWidgets('the kit repaints across every scheme without a hard border',
      (tester) async {
    for (final scheme in LockoutScheme.all) {
      await tester.pumpWidget(_host(
        LockoutCard(child: const Text('x')),
        scheme: scheme,
      ));
      await tester.pump();

      final context = tester.element(find.byType(LockoutCard));
      final shape = Theme.of(context).cardTheme.shape as RoundedRectangleBorder;
      expect(shape.side.width, lessThanOrEqualTo(1.0), reason: scheme.key);
    }
  });
}
