import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import 'bottom_nav.dart';

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
/// `body_tab.dart` and `food_tab.dart` point back at this doc rather than
/// repeating the rationale.
void showUndoBanner(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final slot = _claimBannerSlot();
  late final OverlayEntry entry;
  var removed = false;

  void dismiss() {
    if (removed) return;
    removed = true;
    _releaseBannerSlot(slot);
    entry.remove();
    // `OverlayEntry.dispose()` tears down an internal `ValueNotifier`
    // `remove()` alone does not touch — without this, every delete leaves
    // one undisposed behind (Finding 3).
    entry.dispose();
  }

  entry = OverlayEntry(
    builder: (ctx) => _UndoBanner(
      message: message,
      duration: duration,
      stackSlot: slot,
      onUndo: () {
        dismiss();
        onUndo();
      },
      onExpire: dismiss,
    ),
  );

  overlay.insert(entry);
}

/// Slots currently in use by an on-screen banner, so a second delete fired
/// before the first banner's window closes stacks above it instead of
/// painting in the exact same rect and hiding it (Finding 5). Module-level
/// because BODY and FOOD share this one root-Overlay mechanism and must
/// stack against each other too, not just against their own prior banner.
/// A `Set` rather than a plain counter: releasing a slot out of order (the
/// first of two banners dismissed while the second is still showing) must
/// not let a third banner reuse the still-occupied slot the second one
/// holds, which a simple increment/decrement counter would allow.
final Set<int> _occupiedBannerSlots = <int>{};

int _claimBannerSlot() {
  var slot = 0;
  while (_occupiedBannerSlots.contains(slot)) {
    slot++;
  }
  _occupiedBannerSlots.add(slot);
  return slot;
}

void _releaseBannerSlot(int slot) => _occupiedBannerSlots.remove(slot);

/// Extra vertical space one stacked banner needs above another — a single
/// banner's own rendered height (measured at 75.0dp with the default
/// single-line message and this file's padding/border/shadow — see the
/// probe in this file's git history for third-round review, Finding 3, and
/// re-measure if the message text, padding, border or shadow ever change)
/// plus 9dp of visible gap. Was `64.0`, *below* that measured height, so two
/// stacked banner cards overlapped by 11dp and the upper one painted over
/// the lower's ink border and hard shadow — the opposite of what this
/// constant's old doc claimed ("a little extra clearance"). Not measured
/// live the way `BottomNav.lastRenderedHeight` is (a second banner's own
/// height isn't known until the first frame it's already stacked in, and
/// unlike the nav bar there's no single shared instance to read a height
/// off of before the second banner itself needs to lay out), so this stays
/// a constant tied to the current design instead — pick the Column-based
/// layout this file's doc mentions as the alternative if the message ever
/// needs to wrap to more than one line, since a fixed constant cannot track
/// a variable-height card.
const double _stackSpacing = 84.0;

class _UndoBanner extends StatefulWidget {
  final String message;
  final Duration duration;
  final int stackSlot;
  final VoidCallback onUndo;
  final VoidCallback onExpire;

  // NOT const: `build` resolves a palette colour, so a const call site
  // would canonicalise this widget and `Element.updateChild` would skip
  // its rebuild on a theme switch, stranding it in the old palette. A
  // non-const constructor makes that unrepresentable rather than asking
  // every call site to remember.
  // ignore: prefer_const_constructors_in_immutables
  _UndoBanner({
    required this.message,
    required this.duration,
    required this.stackSlot,
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
    // Third-round review, Finding 5: the same non-`dismiss()` teardown that
    // could leave `_timer` pending also leaked `widget.stackSlot` out of
    // `_occupiedBannerSlots` forever, since only `dismiss()` (the UNDO-tap /
    // expiry path) released it. `Set.remove` on an already-released slot
    // (the normal path, where `dismiss()` released it first) is a no-op, so
    // this is safe to call unconditionally rather than tracked with an
    // extra "did dismiss() already run" flag.
    _releaseBannerSlot(widget.stackSlot);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = JinatraTokens.deepTeal;
    final on = JinatraTokens.onAccentColor(bg);

    return ValueListenableBuilder<double>(
      valueListenable: BottomNav.lastRenderedHeight,
      builder: (context, navHeight, _) {
        return Positioned(
          left: 16,
          right: 16,
          // `24` clears the screen edge; `navHeight` clears the app's own
          // bottom navigation bar (measured, `0.0` where none is mounted —
          // e.g. a widget test that pumps a tab on its own), which this
          // banner would otherwise sit directly on top of for its whole 5s
          // window (Finding 4). `stackSlot * _stackSpacing` clears any
          // other banner still showing (Finding 5).
          bottom: 24 + navHeight + (widget.stackSlot * _stackSpacing),
          child: SafeArea(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                // Keyed per stack slot so a test can measure this card's
                // own rect (border, shadow and all) directly instead of a
                // proxy like the "UNDO" text inside it — third-round
                // review, Finding 3: the prior stacking test compared two
                // "UNDO" `Text` rects, which sit `_stackSpacing` apart *by
                // construction* (that's the offset applied to the whole
                // card), so it could never see the cards themselves
                // overlapping.
                key: ValueKey('undo_banner_card_${widget.stackSlot}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: JinatraTokens.cardDecoration(
                  background: bg,
                  shadowOffset: JinatraTokens.shadowSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      // A separate `Semantics` node (forced by `container:
                      // true`) from the UNDO button below — without this,
                      // Flutter merges both into a single node with the
                      // message and "UNDO" concatenated into one label and
                      // a bare `tap` action, so a screen-reader tap
                      // anywhere on the banner fires undo instead of just
                      // on the button (Finding 6).
                      child: Semantics(
                        container: true,
                        liveRegion: true,
                        child: Text(
                          widget.message,
                          style:
                              JinatraTokens.monoData(color: on, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      container: true,
                      button: true,
                      label: 'Undo',
                      child: GestureDetector(
                        onTap: widget.onUndo,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          // Padding lives inside the detector so the
                          // tappable area grows past 40dp without
                          // enlarging the visible glyph — the previous
                          // `vertical: 8` measured 64.8x33.0dp, short of
                          // the 40dp bar this same task's test holds the
                          // delete glyph to (Finding 6).
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          // Excluded so the raw text doesn't also
                          // contribute its own label — the `Semantics`
                          // above already names this node "Undo".
                          child: ExcludeSemantics(
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
