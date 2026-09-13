import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// One nav destination, enum-keyed. `MainScreen._screenFor` switches on this
/// with a Dart switch *expression*, which the compiler rejects if a case is
/// missing — so a tab added here without a matching branch there is a
/// compile error, not the runtime `StateError` a `String`-keyed switch could
/// only catch by remembering to write a `default`.
enum NavTab { home, routines, food, body, log }

/// One nav destination: a stable id plus how it renders.
///
/// `BottomNav.visibleTabs` is the single source of truth for tab order and
/// which tabs exist. `MainScreen` binds its `_screens` and `_tabIds` lists to
/// it directly, rather than hard-coding the same order a second and third
/// time, so a future reorder can't make the three lists disagree.
class NavTabDef {
  final NavTab tab;

  /// The id `TodayTab.onNavigate(String tabId)` and `MainScreen._goToTab`
  /// use — a public string contract (see the Task 7 brief), kept alongside
  /// [tab] rather than derived from its `.name`, so renaming an enum member
  /// can never silently change that contract.
  final String id;
  final String label;
  final IconData icon;

  const NavTabDef({
    required this.tab,
    required this.id,
    required this.label,
    required this.icon,
  });
}

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool foodTabEnabled;

  // NOT const: `build` resolves a palette colour, so a const call site
  // would canonicalise this widget and `Element.updateChild` would skip
  // its rebuild on a theme switch, stranding it in the old palette. A
  // non-const constructor makes that unrepresentable rather than asking
  // every call site to remember.
  // ignore: prefer_const_constructors_in_immutables
  BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.foodTabEnabled = true,
  });

  static const List<NavTabDef> _allTabs = [
    NavTabDef(tab: NavTab.home, id: 'home', label: 'HOME', icon: Icons.home),
    NavTabDef(
      tab: NavTab.routines,
      id: 'routines',
      label: 'ROUTINES',
      icon: Icons.fitness_center,
    ),
    NavTabDef(
      tab: NavTab.food,
      id: 'food',
      label: 'FOOD',
      icon: Icons.restaurant,
    ),
    NavTabDef(
      tab: NavTab.body,
      id: 'body',
      label: 'BODY',
      icon: Icons.monitor_weight,
    ),
    NavTabDef(
      tab: NavTab.log,
      id: 'log',
      label: 'LOG',
      icon: Icons.calendar_month,
    ),
  ];

  /// The ordered, currently-visible tabs. `MainScreen` derives both its
  /// screen list and its id list from this so they can't drift out of sync
  /// with what `BottomNav` actually renders.
  static List<NavTabDef> visibleTabs({bool foodTabEnabled = true}) =>
      _allTabs.where((t) => t.id != 'food' || foodTabEnabled).toList();

  /// The most recently *measured* rendered height of a live `BottomNav`,
  /// including its own bottom safe-area inset — `0.0` until one has laid
  /// out at least once (there is no bar to clear yet, e.g. in a widget test
  /// that pumps a tab on its own with no `MainScreen`/`BottomNav` around it
  /// at all). `showUndoBanner` (`lib/widgets/undo_banner.dart`) reads this
  /// so its `Positioned(bottom: ...)` clears the bar instead of sitting on
  /// top of it for the whole 5s undo window. A measured value rather than a
  /// guessed constant so it can't fall short on an unusual font-scale or
  /// device inset, and can't overshoot (pushing the banner needlessly high)
  /// where no bar exists to clear at all.
  static final ValueNotifier<double> lastRenderedHeight =
      ValueNotifier<double>(0.0);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  final _barKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_reportHeight);
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_reportHeight);
  }

  void _reportHeight(Duration _) {
    final height = _barKey.currentContext?.size?.height;
    if (height != null && height != BottomNav.lastRenderedHeight.value) {
      BottomNav.lastRenderedHeight.value = height;
    }
  }

  // Third-round review, Finding 2: this static ValueNotifier had no
  // teardown at all — once any `BottomNav` had ever mounted in this
  // process, `lastRenderedHeight` stayed at its last measured value
  // forever, so a `BodyTab` pumped standalone (no `MainScreen` around it)
  // *after* a `MainScreen` had mounted and unmounted would still see a
  // stale non-zero inset instead of the `0.0` the doc on
  // `lastRenderedHeight` promises. Resetting to `0.0` here is the cheap
  // fix, not the preferred one: `MainScreen` is `home:` in this app and
  // never unmounts in production, so this line does not fire there, and it
  // does not solve the sibling problem that `lastRenderedHeight` is also
  // never re-measured on a MediaQuery-only relayout (keyboard, rotation,
  // font scale) with no new frame from `BottomNav` itself — it can still go
  // stale *high* while mounted. The doc-preferred fix (publish the inset
  // through an `InheritedWidget` `MainScreen` owns, read via the caller's
  // `context` in `showUndoBanner`) removes the static, and with it both
  // problems, but is a larger structural change than this finding's given
  // scope; this reset at least makes the one property this class currently
  // documents (0.0 for a tab pumped with no bar ever mounted) hold even
  // after a bar-bearing widget has come and gone in the same test process.
  @override
  void dispose() {
    BottomNav.lastRenderedHeight.value = 0.0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = BottomNav.visibleTabs(foodTabEnabled: widget.foodTabEnabled);

    return Container(
      key: _barKey,
      decoration: BoxDecoration(
        color: JinatraTokens.sweetCream,
        border: Border(
          top: BorderSide(color: JinatraTokens.ink, width: JinatraTokens.borderControl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isActive = widget.currentIndex == index;
            final item = tabs[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: isActive
                        ? JinatraTokens.cardDecoration(
                            background: JinatraTokens.deepTeal,
                            shadowOffset: JinatraTokens.shadowSm,
                            radius: JinatraTokens.radiusPill,
                          )
                        : const BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: isActive
                              ? JinatraTokens.onPrimary
                              : JinatraTokens.ink.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: JinatraTokens.monoData(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? JinatraTokens.onPrimary
                                : JinatraTokens.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
