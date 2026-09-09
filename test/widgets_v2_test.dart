import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/theme/jinatra_tokens.dart';
import 'package:lockout/widgets/action_grid.dart';
import 'package:lockout/widgets/calm_row.dart';
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
      const StatTile(label: 'BMI', value: '23.4'),
    ));
    expect(find.text('BMI'), findsOneWidget);
    expect(find.text('23.4'), findsOneWidget);
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
