import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/lockout_theme.dart';

int mealSubtotalKcal(List<FoodEntry> entries) =>
    entries.fold<int>(0, (sum, e) => sum + e.kcal);

/// One decimal place, trimmed to a whole number when exact — enough precision
/// that a logged 0.4g doesn't silently round down to a measured zero, without
/// manufacturing false precision on values that are exact.
String _formatMacro(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// One meal's entries under a labelled heading with a subtotal.
///
/// v1 showed the day as one flat list, so "how much was lunch" could not be
/// answered without adding rows up by eye. An empty meal renders nothing
/// rather than an empty heading.
class MealSection extends StatelessWidget {
  final String title;
  final List<FoodEntry> entries;
  final void Function(FoodEntry) onDelete;

  const MealSection({
    super.key,
    required this.title,
    required this.entries,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LockoutTheme.spaceXs,
            LockoutTheme.spaceMd,
            LockoutTheme.spaceXs,
            LockoutTheme.spaceSm,
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              Text(
                '${mealSubtotalKcal(entries)} kcal',
                style: LockoutTheme.numeric(
                  context,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final entry in entries) _MealRow(entry: entry, onDelete: onDelete),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  final FoodEntry entry;
  final void Function(FoodEntry) onDelete;

  const _MealRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
        child: Padding(
          padding: const EdgeInsets.only(left: LockoutTheme.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      'P ${_formatMacro(entry.proteinG)}  '
                      'C ${_formatMacro(entry.carbG)}  '
                      'F ${_formatMacro(entry.fatG)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.kcal} kcal',
                style: LockoutTheme.numeric(context, size: 13),
              ),
              // The 48dp target comes from IconButton's own theme now, rather
              // than padding hand-wrapped around a 16dp glyph. This is the
              // screen's only delete path with no upfront confirmation, but
              // `showUndoBanner` gives a few seconds to reverse it, same as
              // Progress.
              IconButton(
                onPressed: () => onDelete(entry),
                icon: const Icon(Icons.close, size: 18, semanticLabel: 'Delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
