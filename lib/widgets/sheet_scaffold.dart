import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';

/// Standard chrome for every form in the app.
///
/// v1 put creation forms inline at the top of a screen, so a screen showed a
/// form the user was not filling in above the content they came to read.
/// Forms live in sheets now; the content is the page.
///
/// Colour, radius and type all come from `BottomSheetThemeData` — the outer
/// shape is the sheet route's, not this widget's. What stays here is the
/// keyboard/safe-area handling, which is load-bearing (see [showLockoutRawSheet]).
class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;

  // Non-const constructor: see "Why some constructors in this app are
  // not const" at the top of lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    // `?? 0.0` guards an inline embed outside a sheet route with no
    // MediaQuery ancestor; pumpWidget always supplies one, so widget tests
    // cannot reach that branch.
    final inset = MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LockoutTheme.spaceLg,
                LockoutTheme.spaceXs,
                LockoutTheme.spaceSm,
                LockoutTheme.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    // `semanticLabel` rather than IconButton's `tooltip`:
                    // a Tooltip requires an Overlay ancestor, and this widget
                    // is embedded directly (no route) in its own tests. The
                    // screen-reader announcement is the same either way.
                    icon: const Icon(Icons.close, semanticLabel: 'Close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  LockoutTheme.spaceLg,
                  0,
                  LockoutTheme.spaceLg,
                  LockoutTheme.spaceLg,
                ),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LockoutTheme.spaceLg,
                  0,
                  LockoutTheme.spaceLg,
                  LockoutTheme.spaceLg,
                ),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens a modal sheet with every property this app's sheets must have.
///
/// The picker call sites used to repeat `isScrollControlled`, `shape` and
/// `useSafeArea` by hand, and only one of them was covered by a test —
/// deleting `useSafeArea` from either picker left the whole suite green while
/// the sheet slid under the system navigation bar. Owning those properties
/// here is what makes them unforgettable; that was logged as a follow-up at
/// `b42586d` and this closes it.
///
/// `isScrollControlled` lets a sheet take the full screen height, and a tall
/// one drew its title under the status bar; `useSafeArea` keeps it off the
/// top, left and right intrusions while leaving the bottom alone, so
/// [SheetScaffold]'s own keyboard inset still applies.
Future<T?> showLockoutRawSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// The titled form of [showLockoutRawSheet]: wraps [builder] in a
/// [SheetScaffold]. Returns whatever the sheet pops.
Future<T?> showLockoutSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? footer,
}) {
  return showLockoutRawSheet<T>(
    context: context,
    builder: (ctx) => SheetScaffold(
      title: title,
      footer: footer,
      child: builder(ctx),
    ),
  );
}
