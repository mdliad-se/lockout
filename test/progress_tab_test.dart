import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/screens/body_tab.dart';
import 'package:lockout/screens/log_tab.dart';
import 'package:lockout/screens/progress_tab.dart';
import 'package:lockout/services/database_service.dart';
import 'package:lockout/theme/lockout_theme.dart';
import 'package:lockout/theme/schemes.dart';
import 'package:lockout/widgets/weight_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

ThemeData _theme() => LockoutTheme.build(
      colors: LockoutScheme.graphite.colors,
      semantics: LockoutScheme.graphite.semantics,
    );

Widget _host({
  GlobalKey<ProgressTabState>? key,
  ProgressSegment initial = ProgressSegment.weight,
}) {
  return MaterialApp(
    theme: _theme(),
    home: ProgressTab(key: key, initialSegment: initial),
  );
}

void main() {
  // The no-isolate factory against an in-memory path, matching every other
  // widget suite here. The isolate-backed factory arms a 10s transaction
  // timeout inside fake_async that a bounded `settle` never lives long enough
  // to cancel, so the widget tree is disposed with a timer still pending.
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
  });

  setUp(() => wipeDatabaseAndReseed(DatabaseService.instance));

  testWidgets('opens on Weight and offers both segments', (tester) async {
    await tester.pumpWidget(_host());
    await settle(tester);

    expect(find.byType(SegmentedButton<ProgressSegment>), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byType(BodyTab), findsOneWidget);
    expect(find.byType(LogTab), findsNothing);
  });

  testWidgets('the screen carries its own title', (tester) async {
    await tester.pumpWidget(_host());
    await settle(tester);

    expect(find.text('Progress'), findsOneWidget);
    expect(
      find.byType(AppBar),
      findsNothing,
      reason: 'tabs own their header; MainScreen no longer has a global bar',
    );
  });

  testWidgets('tapping History swaps the body', (tester) async {
    await tester.pumpWidget(_host());
    await settle(tester);

    await tester.tap(find.text('History'));
    await settle(tester);

    expect(find.byType(LogTab), findsOneWidget);
    expect(
      find.byType(BodyTab),
      findsNothing,
      reason: 'the hidden segment is unmounted, not merely offstage: both '
          'children read sqflite in initState',
    );
  });

  testWidgets('showSegment drives the control from outside', (tester) async {
    final key = GlobalKey<ProgressTabState>();
    await tester.pumpWidget(_host(key: key));
    await settle(tester);

    key.currentState!.showSegment(ProgressSegment.history);
    await settle(tester);
    expect(find.byType(LogTab), findsOneWidget);

    key.currentState!.showSegment(ProgressSegment.weight);
    await settle(tester);
    expect(find.byType(BodyTab), findsOneWidget);
  });

  testWidgets('initialSegment opens straight on History', (tester) async {
    await tester.pumpWidget(_host(initial: ProgressSegment.history));
    await settle(tester);

    expect(find.byType(LogTab), findsOneWidget);
    expect(find.byType(BodyTab), findsNothing);
  });

  testWidgets('reload works on either segment', (tester) async {
    final key = GlobalKey<ProgressTabState>();
    await tester.pumpWidget(_host(key: key));
    await settle(tester);

    await key.currentState!.reload();
    await settle(tester);

    key.currentState!.showSegment(ProgressSegment.history);
    await settle(tester);
    await key.currentState!.reload();
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('showSegment with the current segment does not rebuild',
      (tester) async {
    final key = GlobalKey<ProgressTabState>();
    await tester.pumpWidget(_host(key: key));
    await settle(tester);

    final bodyBefore = tester.element(find.byType(BodyTab));
    key.currentState!.showSegment(ProgressSegment.weight);
    await settle(tester);

    expect(
      tester.element(find.byType(BodyTab)),
      same(bodyBefore),
      reason: 'a no-op selection must not remount the child and re-read the DB',
    );
  });

  testWidgets('the segmented control clears the 48dp touch target',
      (tester) async {
    await tester.pumpWidget(_host());
    await settle(tester);

    final size = tester.getSize(find.byType(SegmentedButton<ProgressSegment>));
    expect(size.height, greaterThanOrEqualTo(LockoutTheme.minTouchTarget));
  });

  // Progress is the seam: this screen pads its own heading with
  // `screenPadding`, and then hosts BodyTab, which pads itself again. The two
  // disagreed by 4dp for the whole branch — the heading sat at 20 and the card
  // beneath it at a literal 16 — and no test could see it, because every
  // geometry assertion in this suite is a ratio, a lower bound, a non-overlap
  // or an ordering. Not one pinned an absolute horizontal position, which is
  // exactly the class of defect absolute positions catch.
  //
  // The source scan in no_legacy_theme_test.dart catches the literal
  // `EdgeInsets.all(16)` spelling; only this catches the misalignment itself,
  // whatever spelling reintroduces it.
  testWidgets('the heading and the card below it share a left edge',
      (tester) async {
    await tester.pumpWidget(_host());
    await settle(tester);

    final headingLeft = tester.getTopLeft(find.text('Progress')).dx;
    final cardLeft = tester.getTopLeft(find.byType(WeightCard).first).dx;

    expect(
      cardLeft,
      headingLeft,
      reason: 'ProgressTab pads its heading with screenPadding (20) and '
          'BodyTab pads its list; both must use the same token or the card '
          'steps out from under the title',
    );
  });
}
