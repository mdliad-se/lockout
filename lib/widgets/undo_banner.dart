import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// Shows a dismissible "MESSAGE — UNDO" banner for [duration], above
/// *everything* currently on screen, including an open [showJinatraSheet]
/// modal.
///
/// Shared by BODY's body-log delete and FOOD's food-entry delete (Ruling F)
/// so the two destructive-delete flows behave identically instead of two
/// lookalike implementations drifting apart. BODY's delete happens from
/// inside a modal sheet (LOG HISTORY); a `ScaffoldMessenger` SnackBar is
/// attached to the *Scaffold* underneath that sheet, and a modal route's own
/// `OverlayEntry` paints above that Scaffold, so a SnackBar shown there
/// renders entirely behind the sheet and its barrier — this is exactly the
/// failure `body_tab.dart`'s `_createRecommendedRoutine` had for CREATE THIS
/// ROUTINE's confirmation. Inserting straight into the *root* `Overlay`
/// (`rootOverlay: true`) puts this banner above every route, sheet included,
/// and — because it does not live inside the sheet's own subtree — it keeps
/// working even after the sheet that triggered the delete has been closed.
///
/// Returns a callback that dismisses the banner immediately, without
/// running [onUndo]; callers do not need it today but it keeps the widget
/// testable without waiting out the full [duration].
VoidCallback showUndoBanner(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  var removed = false;

  void dismiss() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => _UndoBanner(
      message: message,
      duration: duration,
      onUndo: () {
        dismiss();
        onUndo();
      },
      onExpire: dismiss,
    ),
  );

  overlay.insert(entry);
  return dismiss;
}

class _UndoBanner extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onExpire;

  const _UndoBanner({
    required this.message,
    required this.duration,
    required this.onUndo,
    required this.onExpire,
  });

  @override
  State<_UndoBanner> createState() => _UndoBannerState();
}

class _UndoBannerState extends State<_UndoBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onExpire);
  }

  @override
  void dispose() {
    // The OverlayEntry can be torn down by something other than expiry or an
    // UNDO tap (e.g. the whole app being popped in a test) — cancelling here
    // too means this never leaves a Timer pending past the widget's own life.
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = JinatraTokens.deepTeal;
    final on = JinatraTokens.onAccentColor(bg);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: JinatraTokens.cardDecoration(
                background: bg,
                shadowOffset: JinatraTokens.shadowSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      style: JinatraTokens.monoData(color: on, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: widget.onUndo,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'UNDO',
                        style: JinatraTokens.monoData(
                          color: on,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
