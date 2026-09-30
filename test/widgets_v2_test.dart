import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/day_block.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';
import 'package:lockout/widgets/stat_tile.dart';
import 'package:lockout/widgets/undo_banner.dart';

import 'test_helpers.dart';

Widget _host(Widget child) => MaterialApp(
      theme: lockoutTestTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

/// The ramp the rebuilt widgets identify with, replacing the palette accents
/// the neubrutalist versions took.
Color _ramp(int i) => LockoutScheme.graphite.semantics.categoryAt(i);

/// Hosts a button that raises an undo banner into the root overlay, the way
/// BODY and FOOD raise it after a delete.
Widget _undoHost({ThemeData? theme}) => MaterialApp(
      theme: theme ?? lockoutTestTheme(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showUndoBanner(
              ctx,
              message: 'Entry deleted',
              onUndo: () {},
            ),
            child: const Text('delete'),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'SheetScaffold bottom padding tracks MediaQuery viewInsets',
      (tester) async {
    Future<void> pumpWithInset(double bottom) async {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          viewInsets: EdgeInsets.only(bottom: bottom),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SheetScaffold(
            title: 'TEST SHEET',
            child: Text('Content'),
          ),
        ),
      ));
    }

    // The outer wrapper is a Padding rather than a Container now that colour
    // and radius come from BottomSheetThemeData; the keyboard-inset
    // behaviour it guards is unchanged.
    await pumpWithInset(240);
    var padding = tester.widget<Padding>(find.byType(Padding).first);
    expect(padding.padding, const EdgeInsets.only(bottom: 240));

    await pumpWithInset(0);
    padding = tester.widget<Padding>(find.byType(Padding).first);
    expect(padding.padding, EdgeInsets.zero);
  });

  testWidgets('HeroCard renders eyebrow, title, subtitle and actions',
      (tester) async {
    await tester.pumpWidget(_host(HeroCard(
      eyebrow: 'TODAY - MON',
      title: 'LEGS',
      subtitle: '4 EX - 12 SETS',
      accent: _ramp(0),
      actions: [
        ElevatedButton(onPressed: () {}, child: const Text('START')),
      ],
    )));

    expect(find.text('TODAY - MON'), findsOneWidget);
    expect(find.text('LEGS'), findsOneWidget);
    expect(find.text('4 EX - 12 SETS'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('ActionGrid renders one tile per item and fires onTap',
      (tester) async {
    var tapped = '';
    final items = List.generate(
      8,
      (i) => ActionItem(
        label: 'ACT$i',
        icon: Icons.circle,
        color: _ramp(i),
        onTap: () => tapped = 'ACT$i',
      ),
    );

    await tester.pumpWidget(_host(ActionGrid(items: items)));

    expect(find.byType(ActionTile), findsNWidgets(8));
    await tester.tap(find.text('ACT5'));
    expect(tapped, 'ACT5');
  });

  testWidgets('CalmRow shows a value and is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(CalmRow(
      icon: Icons.restaurant,
      title: 'CALORIES',
      value: '1240 / 1850',
      onTap: () => tapped = true,
    )));

    expect(find.text('CALORIES'), findsOneWidget);
    expect(find.text('1240 / 1850'), findsOneWidget);
    await tester.tap(find.byType(CalmRow));
    expect(tapped, isTrue);
  });

  testWidgets('StatTile shows label and value', (tester) async {
    await tester.pumpWidget(_host(
      StatTile(label: 'BMI', value: '23.4'),
    ));
    expect(find.text('BMI'), findsOneWidget);
    expect(find.text('23.4'), findsOneWidget);
  });

  // The day sheet's Add affordance was the one place this repo's own
  // tap-target bar was never applied: `AddLink` padded to roughly 23dp tall
  // around 10px mono text, and `HitTestBehavior.opaque` does not enlarge the
  // box it is applied to. `tester.tap` hits a widget's centre regardless of
  // size, so the flow tests in routines_tab_test.dart cannot catch a shrunk
  // hit target — this measures the tappable box instead.
  //
  // The bar is `LockoutTheme.minTouchTarget` (48), not the 40 this widget
  // first shipped with: 40 was never a recorded decision, and 48 is the
  // branch-wide constraint every other restyled control already clears.
  testWidgets('AddLink has at least a minTouchTarget tall tappable bar',
      (tester) async {
    await tester.pumpWidget(_host(AddLink(label: '+ ADD WARM-UP', onTap: () {})));

    final detector = find.ancestor(
      of: find.text('+ ADD WARM-UP'),
      matching: find.byType(GestureDetector),
    );
    expect(detector, findsOneWidget);
    expect(tester.getSize(detector).height,
        greaterThanOrEqualTo(LockoutTheme.minTouchTarget));

    // The label is centred in that box, not parked at its top. Height alone
    // cannot see the difference: drop the centring and a 10px line paints at
    // the top of the 48dp box, still 48dp tall and now visibly misaligned.
    expect(tester.getCenter(detector).dy,
        moreOrLessEquals(tester.getCenter(find.text('+ ADD WARM-UP')).dy,
            epsilon: 0.5));
  });

  // The day sheet's rows carried a bare 14px `Icons.close` — the one delete
  // affordance in the app that was still under the app's tap-target floor.
  testWidgets('SubItemRow remove affordance clears minTouchTarget',
      (tester) async {
    await tester.pumpWidget(_host(
      SubItemRow(name: 'Band pull-aparts', amt: 'x15', onRemove: () {}),
    ));

    final detector = find.ancestor(
      of: find.byIcon(Icons.close),
      matching: find.byType(GestureDetector),
    );
    expect(detector, findsOneWidget);
    final size = tester.getSize(detector);
    expect(size.width, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
    expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
  });

  // The width leg needs its own case: every real label is ~135dp wide, so a
  // long one satisfies the floor whatever the constraint says and would pass
  // against `minWidth: 0`.
  testWidgets('AddLink holds the floor on both axes for a short label',
      (tester) async {
    await tester.pumpWidget(_host(AddLink(label: '+', onTap: () {})));

    final detector = find.ancestor(
      of: find.text('+'),
      matching: find.byType(GestureDetector),
    );
    final size = tester.getSize(detector);
    expect(size.width, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
    expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
  });

  // `SectionHeading`'s title and its amount are the same 11px `labelSmall`,
  // so the only thing separating them is colour. v1 separated them with a
  // smaller, more transparent type; the restyle has to carry that with two
  // roles, and both sides of the pair have to be pinned or the heading
  // silently re-flattens — which is exactly what happened when the amount
  // was given `copyWith(color: onSurfaceVariant)`, the colour `labelSmall`
  // already carried, leaving two byte-identical styles.
  //
  // Both roles are overridden to sentinels rather than compared against the
  // shipped graphite values, so this fails if either side drops its role or
  // if the two ever resolve to one.
  testWidgets('SectionHeading separates its title and amount by role',
      (tester) async {
    const titleTone = Color(0xFF00FF00);
    const amountTone = Color(0xFFFF00FF);
    final theme = LockoutTheme.build(
      colors: LockoutScheme.graphite.colors.copyWith(
        onSurface: titleTone,
        onSurfaceVariant: amountTone,
      ),
      semantics: LockoutScheme.graphite.semantics,
    );

    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: SectionHeading(title: 'Warm-up', amount: '3 items'),
      ),
    ));

    final title = tester.widget<Text>(find.text('WARM-UP'));
    final amount = tester.widget<Text>(find.text('3 items'));

    expect(title.style?.color, titleTone);
    expect(amount.style?.color, amountTone);
    expect(title.style?.color, isNot(amount.style?.color));
    // Same size on both sides: the hierarchy is carried by colour alone, so
    // a size difference would be a different design, not this one.
    expect(title.style?.fontSize, amount.style?.fontSize);
  });

  // Reported on an Android 16 device: a tall sheet drew its title UNDER the
  // status bar, so "CREATE NEW ROUTINE" overlapped the clock and the battery
  // icon. `showModalBottomSheet` with `isScrollControlled: true` is allowed
  // the full screen height, and `SheetScaffold`'s own `SafeArea` passes
  // `top: false` — correct for the scaffold, which must not pad a short
  // sheet, but it leaves nothing keeping a tall one off the system bars.
  testWidgets('a tall sheet stays clear of the status bar', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(640, 1000);
    tester.view.padding = const FakeViewPadding(top: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showLockoutSheet<void>(
              context: ctx,
              title: 'Create New Routine',
              builder: (_) => const SizedBox(height: 1200, child: Text('tall')),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.byType(SheetScaffold), findsOneWidget);
    expect(tester.getTopLeft(find.byType(SheetScaffold)).dy,
        greaterThanOrEqualTo(48.0));
  });

  testWidgets('showLockoutSheet presents a titled sheet and returns a value',
      (tester) async {
    String? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showLockoutSheet<String>(
                context: ctx,
                title: 'LOG FOOD',
                builder: (sheetCtx) => TextButton(
                  onPressed: () => Navigator.pop(sheetCtx, 'saved'),
                  child: const Text('SAVE'),
                ),
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(SheetScaffold), findsOneWidget);
    expect(find.text('LOG FOOD'), findsOneWidget);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(result, 'saved');
  });

  // The banner paints on `inverseSurface`, and its action used to take
  // `colors.primary` — 1.37:1 on graphite, unreadable, and the control is
  // the only one the banner has. `inversePrimary` is the readable tone for
  // that background in every scheme (`schemes_test.dart` measures it);
  // this pins the widget to the role rather than to a value, so a scheme
  // that authors its own `inversePrimary` still gets a legible label.
  //
  // The role is overridden to a sentinel rather than read off the shipped
  // scheme, the way `settings_restyle_test.dart` does for `danger`. Asserting
  // `colors.inversePrimary` against the shipped graphite palette would pass
  // just as well if the widget had painted `onInverseSurface` or a literal —
  // the banner's message is asserted against a neighbouring role three lines
  // down, and the two roles only differ by palette choice. A sentinel no
  // other role holds makes the assertion discriminating by construction.
  testWidgets('the undo banner draws its action in inversePrimary',
      (tester) async {
    const sentinel = Color(0xFF00FF00);
    final theme = LockoutTheme.build(
      colors:
          LockoutScheme.graphite.colors.copyWith(inversePrimary: sentinel),
      semantics: LockoutScheme.graphite.semantics,
    );
    await tester.pumpWidget(_undoHost(theme: theme));
    await tester.tap(find.text('delete'));
    await tester.pump();

    final colors = theme.colorScheme;
    final action = tester.widget<Text>(find.text('UNDO'));
    expect(action.style?.color, sentinel);
    expect(sentinel, isNot(colors.primary));
    expect(sentinel, isNot(colors.onInverseSurface));

    // The message keeps the background's own on-colour.
    final message = tester.widget<Text>(find.text('Entry deleted'));
    expect(message.style?.color, colors.onInverseSurface);

    // Let the 5s auto-dismiss Timer fire, or the test ends with it pending.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
