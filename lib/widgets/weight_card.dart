import 'package:flutter/material.dart';

import '../theme/lockout_semantics.dart';
import '../theme/lockout_theme.dart';
import 'lockout_card.dart';
import 'sparkline.dart';

/// Bodyweight: one large number, the gap to the goal, and the trend.
///
/// This replaces the single navigable row that used to read
/// `72.5 kg  -0.4`. A row that size could state the weight but not the two
/// things a cut is actually run on — how far there is to go, and which way the
/// line is moving.
class WeightCard extends StatelessWidget {
  /// Null when nothing is on record: the card prompts instead of showing a
  /// number, because a zero would be a lie.
  final double? weightKg;

  /// Null when no goal is configured. The gap is then not stated at all
  /// rather than invented.
  final double? targetWeightKg;

  /// Day-over-day change. Null when there is only one weigh-in.
  final double? deltaKg;

  /// Recent weights, oldest first. Fewer than two cannot make a line.
  final List<double> series;

  final VoidCallback? onTap;

  const WeightCard({
    super.key,
    required this.weightKg,
    required this.targetWeightKg,
    required this.deltaKg,
    required this.series,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = LockoutSemantics.of(context);
    final weight = weightKg;

    if (weight == null) {
      return LockoutCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: LockoutTheme.spaceMd),
            Expanded(
              child: Text('Log a weight', style: theme.textTheme.titleSmall),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      );
    }

    final target = targetWeightKg;
    final gap = target == null ? null : weight - target;

    return LockoutCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Bodyweight', style: theme.textTheme.labelSmall),
              const Spacer(),
              if (deltaKg != null) _DeltaChip(deltaKg: deltaKg!),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                weight.toStringAsFixed(1),
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(width: LockoutTheme.spaceXs),
              Text('kg', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceXs),
          Text(
            // The gap is the figure a cut is run on, so it leads; the target
            // follows it as context rather than standing on its own.
            gap == null
                ? 'Set a goal to track the gap'
                : gap <= 0
                    ? 'Target reached · ${target!.toStringAsFixed(1)} kg'
                    : '${gap.toStringAsFixed(1)} kg to go '
                        '· target ${target!.toStringAsFixed(1)} kg',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (series.length >= 2) ...[
            const SizedBox(height: LockoutTheme.spaceMd),
            Sparkline(values: series, lineColor: semantics.chartLine),
          ] else ...[
            const SizedBox(height: LockoutTheme.spaceSm),
            Text(
              'Log another weight to see the trend',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// The day-over-day change, coloured by direction rather than by sign.
///
/// Down is not universally good — that depends on the goal — so this states
/// the movement and leaves the judgement to the gap line above.
class _DeltaChip extends StatelessWidget {
  final double deltaKg;

  const _DeltaChip({required this.deltaKg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rising = deltaKg > 0;
    final sign = rising ? '+' : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          rising ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
        Text(
          '$sign${deltaKg.toStringAsFixed(1)} kg',
          style: LockoutTheme.numeric(
            context,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
