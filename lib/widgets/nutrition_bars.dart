import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'lockout_card.dart';

/// Today's intake as progress against target.
///
/// Calories and protein only. The design brief also lists water, but this app
/// has never tracked it and adding a water log would be a new feature rather
/// than a restyle — a bar with nothing behind it would be worse than no bar.
class NutritionBars extends StatelessWidget {
  final int kcalEaten;

  /// Null when no goal is configured; the bar then states intake alone.
  final int? kcalTarget;

  final double proteinEatenG;
  final int? proteinTargetG;

  final VoidCallback? onTap;

  const NutritionBars({
    super.key,
    required this.kcalEaten,
    required this.kcalTarget,
    required this.proteinEatenG,
    required this.proteinTargetG,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LockoutCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bar(
            label: 'Calories',
            eaten: kcalEaten.toDouble(),
            target: kcalTarget?.toDouble(),
            unit: '',
            colour: colors.primary,
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          _Bar(
            label: 'Protein',
            eaten: proteinEatenG,
            target: proteinTargetG?.toDouble(),
            unit: 'g',
            colour: colors.secondary,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double eaten;
  final double? target;

  /// Appended to every figure, e.g. `g`. Empty for calories, which are
  /// already named by the label.
  final String unit;

  final Color colour;

  const _Bar({
    required this.label,
    required this.eaten,
    required this.target,
    required this.unit,
    required this.colour,
  });

  String get _suffix => unit.isEmpty ? '' : ' $unit';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = target;
    final eatenWhole = eaten.round();

    // Clamped: a day at 250% of target would otherwise paint past the end of
    // its own track. The number beside it still tells the truth.
    final progress = goal == null || goal <= 0
        ? 0.0
        : (eaten / goal).clamp(0.0, 1.0).toDouble();

    final String remaining;
    if (goal == null) {
      remaining = '';
    } else {
      // Derived from the figures actually on screen, not from the raw values:
      // 96.5 of 150 displays as "97 / 150", and a remainder computed from the
      // raw 96.5 would read "54 left" beside it. The arithmetic a reader can
      // do in their head has to come out right.
      final left = goal.round() - eatenWhole;
      // Never a negative "left": past the target it reads as over, which is
      // the same fact stated the way a person would say it.
      remaining = left >= 0
          ? '$left$_suffix left'
          : '${left.abs()}$_suffix over';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              goal == null
                  ? '$eatenWhole$_suffix'
                  : '$eatenWhole / ${goal.round()}$_suffix',
              style: LockoutTheme.numeric(
                context,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: LockoutTheme.spaceSm),
        ClipRRect(
          borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
          child: LinearProgressIndicator(value: progress, color: colour),
        ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: LockoutTheme.spaceXs),
          Text(remaining, style: theme.textTheme.labelSmall),
        ],
      ],
    );
  }
}
