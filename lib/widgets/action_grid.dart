import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';

/// One destination in the quick-action grid.
class ActionItem {
  final String label;
  final IconData icon;

  /// The identifying colour, normally from `LockoutSemantics.categoryAt(n)`.
  final Color color;
  final VoidCallback onTap;

  const ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// A grid of quick destinations.
///
/// This is a menu, not content, so colour here identifies rather than competes
/// for attention. v1 flooded each tile with its accent; the accent now tints
/// only the icon and its container, which keeps eight of them on screen at
/// once from reading as a paint chart.
class ActionGrid extends StatelessWidget {
  final List<ActionItem> items;
  final int columns;

  const ActionGrid({super.key, required this.items, this.columns = 4});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: LockoutTheme.spaceSm,
      mainAxisSpacing: LockoutTheme.spaceSm,
      childAspectRatio: 0.85,
      children: [for (final item in items) ActionTile(item: item)],
    );
  }
}

/// A single quick-action tile.
class ActionTile extends StatelessWidget {
  final ActionItem item;

  const ActionTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: LockoutTheme.minTouchTarget,
            minHeight: LockoutTheme.minTouchTarget,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // A low-alpha wash of the identifying colour rather than a
                  // full fill: legible against every scheme's surface without
                  // needing a per-colour foreground calculation.
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
                ),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(height: LockoutTheme.spaceSm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LockoutTheme.spaceXs,
                ),
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
