import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/calm_row.dart';
import 'package:lockout/widgets/day_block.dart';
import 'package:lockout/widgets/hero_card.dart';
import 'package:lockout/widgets/sheet_scaffold.dart';
import 'package:lockout/widgets/stat_tile.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  setUpAll(() {
    // A widget test must never reach the network for a font file.
    GoogleFonts.config.allowRuntimeFetching = false;
    AppPalette.apply(AppPalette.paperPress);
  });

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

    await pumpWithInset(240);
    var container = tester.widget<Container>(find.byType(Container).first);
    expect(container.padding, const EdgeInsets.only(bottom: 240));

    await pumpWithInset(0);
    container = tester.widget<Container>(find.byType(Container).first);
    expect(container.padding, EdgeInsets.zero);
  });

  testWidgets('HeroCard renders eyebrow, title, subtitle and actions',
      (tester) async {
    await tester.pumpWidget(_host(HeroCard(
      eyebrow: 'TODAY - MON',
      title: 'LEGS',
      subtitle: '4 EX - 12 SETS',
      background: JinatraTokens.accentAt(0),
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
        color: JinatraTokens.accentAt(i),
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

  // The day sheet's Add affordance was the one place this repo's own 40dp
  // tap-target bar (log_tab.dart:325, meal_section.dart:110,
  // undo_banner.dart:217) was never applied: `AddLink` padded to roughly
  // 23dp tall around 10px mono text, and `HitTestBehavior.opaque` does not
  // enlarge the box it is applied to. `tester.tap` hits a widget's centre
  // regardless of size, so the flow tests in routines_tab_test.dart cannot
  // catch a shrunk hit target — this measures the tappable box instead.
  testWidgets('AddLink has at least a 40dp tall tappable bar', (tester) async {
    await tester.pumpWidget(_host(AddLink(label: '+ ADD WARM-UP', onTap: () {})));

    final detector = find.ancestor(
      of: find.text('+ ADD WARM-UP'),
      matching: find.byType(GestureDetector),
    );
    expect(detector, findsOneWidget);
    expect(tester.getSize(detector).height, greaterThanOrEqualTo(40));

    // The label is centred in that box, not parked at its top. Height alone
    // cannot see the difference: drop the centring and a 10px line paints at
    // the top of a 40dp box, still 40dp tall and now visibly misaligned.
    expect(tester.getCenter(detector).dy,
        moreOrLessEquals(tester.getCenter(find.text('+ ADD WARM-UP')).dy,
            epsilon: 0.5));
  });

  // The width leg needs its own case: every real label is ~135dp wide, so a
  // long one satisfies `>= 40` whatever the constraint says and would pass
  // against `minWidth: 0`.
  testWidgets('AddLink holds the 40dp floor on both axes for a short label',
      (tester) async {
    await tester.pumpWidget(_host(AddLink(label: '+', onTap: () {})));

    final detector = find.ancestor(
      of: find.text('+'),
      matching: find.byType(GestureDetector),
    );
    final size = tester.getSize(detector);
    expect(size.width, greaterThanOrEqualTo(40));
    expect(size.height, greaterThanOrEqualTo(40));
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
            onTap: () => showJinatraSheet<void>(
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

  testWidgets('showJinatraSheet presents a titled sheet and returns a value',
      (tester) async {
    String? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showJinatraSheet<String>(
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
}
