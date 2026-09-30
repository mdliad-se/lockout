import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/routine_focus.dart';
import '../theme/lockout_theme.dart';
import 'lockout_card.dart';

/// The one day a routine card leads with.
///
/// The routine card used to render all seven days as near-identical rows, so
/// the day that actually matters today carried no more weight than the other
/// six. This is the card that fixes that; the rest of the week lives behind an
/// expander so the routine is still editable on any day.
class TodayDayCard extends StatelessWidget {
  final TrainingDay day;

  /// The day's identifying colour. Used for the rail and the eyebrow, never as
  /// a fill.
  final Color accent;

  /// One-line summary, e.g. `5 exercises · 18 sets`.
  final String summary;

  /// Whether this is today (weekday routines) or the next slot in a rotation.
  final FeaturedDayKind kind;

  /// Opens the full day sheet.
  final VoidCallback onTap;

  /// Starts the session. Null for a rest day, or a day with no exercises yet —
  /// both cases have nothing to start.
  final VoidCallback? onStart;

  const TodayDayCard({
    super.key,
    required this.day,
    required this.accent,
    required this.summary,
    required this.kind,
    required this.onTap,
    this.onStart,
  });

  String get _eyebrow {
    final label = kind == FeaturedDayKind.today ? 'TODAY' : 'NEXT';
    final tag = day.tag.trim().toUpperCase();
    return tag.isEmpty ? label : '$label · $tag';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LockoutCard(
      elevated: true,
      onTap: onTap,
      // IntrinsicHeight: the rail stretches to the row's height and has none
      // of its own, which inside a scroll view is an infinite constraint.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              margin: const EdgeInsets.only(right: LockoutTheme.spaceMd),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _eyebrow,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: accent, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text(
                    // The user's own name for the day, even when it is a rest
                    // day — they named it, and the subtitle already says what
                    // a rest day means. Only an unnamed day falls back.
                    day.name.trim().isEmpty ? 'Rest day' : day.name,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text(
                    day.isRestDay ? 'Recovery is part of the plan.' : summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onStart != null) ...[
                    const SizedBox(height: LockoutTheme.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onStart,
                        child: const Text('Start session'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
