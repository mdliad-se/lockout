import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// Standard chrome for every form in the app.
///
/// v1 put creation forms inline at the top of a screen, so a screen showed a
/// form the user was not filling in above the content they came to read.
/// Forms live in sheets now; the content is the page.
class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;

  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    // `?? 0.0` guards an inline embed outside showJinatraSheet with no
    // MediaQuery ancestor; pumpWidget always supplies one, so widget tests can't reach this branch.
    final inset = MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0;

    return Container(
      padding: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: JinatraTokens.paper,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(JinatraTokens.radiusCard),
        ),
        border: Border(
          top: BorderSide(
            color: JinatraTokens.ink,
            width: JinatraTokens.borderControl,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: JinatraTokens.sectionHeader(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: JinatraTokens.ink),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens [builder] inside a [SheetScaffold]. Returns whatever the sheet pops.
Future<T?> showJinatraSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SheetScaffold(title: title, child: builder(ctx)),
  );
}
