import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';

/// A small metric: quiet label above a numeric value.
///
/// The value is mono so a column of tiles keeps its digits aligned, and both
/// lines clip rather than overflow — these sit in grids whose height is set by
/// the shortest tile, and a long value used to push the column 4px past it.
class StatTile extends StatelessWidget {
  final String label;
  final String value;

  /// Tints the value only. Defaults to the plain on-surface colour.
  final Color? accent;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(LockoutTheme.spaceSm + 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: LockoutTheme.spaceXs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LockoutTheme.numeric(
              context,
              size: 16,
              color: accent ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
