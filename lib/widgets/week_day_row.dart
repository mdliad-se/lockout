import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/lockout_theme.dart';

/// One line of summary for a day, so the week reads without expanding
/// anything.
String dayRowSummary(TrainingDay day) {
  if (day.isRestDay) return 'Rest';
  if (day.exercises.isEmpty) return 'Empty';
  final sets = day.exercises.fold<int>(0, (s, e) => s + e.targetSets);
  final plural = day.exercises.length == 1 ? 'exercise' : 'exercises';
  return '${day.exercises.length} $plural · $sets sets';
}

/// A compact day inside the collapsed week.
///
/// Deliberately quieter than [TodayDayCard]: these are the days the user is
/// *not* training today, and the whole point of collapsing the week was that
/// seven equally-loud rows gave the day that matters no prominence at all.
class WeekDayRow extends StatelessWidget {
  final TrainingDay day;
  final Color accent;
  final String summary;

  /// True for the day the routine is actually on today — it is also featured
  /// above, so this is only a locator inside the expanded list.
  final bool isToday;

  final VoidCallback onTap;

  const WeekDayRow({
    super.key,
    required this.day,
    required this.accent,
    required this.summary,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LockoutTheme.spaceSm,
      ),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
        ),
        child: Text(
          day.tag.trim().toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: accent),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              day.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: LockoutTheme.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
              ),
              child: Text(
                'TODAY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(summary, style: theme.textTheme.bodySmall),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
