import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// One nav destination: a stable id plus how it renders.
///
/// `BottomNav.visibleTabs` is the single source of truth for tab order and
/// which tabs exist. `MainScreen` binds its `_screens` and `_tabIds` lists to
/// it directly, rather than hard-coding the same order a second and third
/// time, so a future reorder can't make the three lists disagree.
class NavTabDef {
  final String id;
  final String label;
  final IconData icon;

  const NavTabDef({required this.id, required this.label, required this.icon});
}

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool foodTabEnabled;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.foodTabEnabled = true,
  });

  static const List<NavTabDef> _allTabs = [
    NavTabDef(id: 'home', label: 'HOME', icon: Icons.home),
    NavTabDef(id: 'routines', label: 'ROUTINES', icon: Icons.fitness_center),
    NavTabDef(id: 'food', label: 'FOOD', icon: Icons.restaurant),
    NavTabDef(id: 'body', label: 'BODY', icon: Icons.monitor_weight),
    NavTabDef(id: 'log', label: 'LOG', icon: Icons.calendar_month),
  ];

  /// The ordered, currently-visible tabs. `MainScreen` derives both its
  /// screen list and its id list from this so they can't drift out of sync
  /// with what `BottomNav` actually renders.
  static List<NavTabDef> visibleTabs({bool foodTabEnabled = true}) =>
      _allTabs.where((t) => t.id != 'food' || foodTabEnabled).toList();

  @override
  Widget build(BuildContext context) {
    final tabs = visibleTabs(foodTabEnabled: foodTabEnabled);

    return Container(
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
            final isActive = currentIndex == index;
            final item = tabs[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
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
