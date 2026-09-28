import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'lockout_card.dart';

/// A leading card whose subject is a proportion — calories against a target.
///
/// The bar is clamped rather than allowed to overflow: going 300 kcal over
/// should read as "full and then some", not break the layout.
class ProgressHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  /// 0.0 to 1.0. Values outside that range are clamped.
  final double progress;

  /// The bar's fill. Defaults to the primary role.
  final Color? accent;

  const ProgressHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    return LockoutCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: theme.textTheme.labelSmall),
          const SizedBox(height: LockoutTheme.spaceXs),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: LockoutTheme.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
            child: LinearProgressIndicator(
              value: value,
              color: accent ?? theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: LockoutTheme.spaceSm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
