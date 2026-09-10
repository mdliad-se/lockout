import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';
import 'day_block.dart';

/// One line of summary for a day, so the week reads without expanding
/// anything.
String dayRowSummary(TrainingDay day) {
  if (day.isRestDay) return 'REST';
  if (day.exercises.isEmpty) return 'EMPTY';
  final sets = day.exercises.fold<int>(0, (s, e) => s + e.targetSets);
  return '${day.exercises.length} EX - $sets SETS';
}

/// A compact day in the training week: a coloured rail carrying the weekday,
/// then the day name and its one-line summary.
///
/// v1 filled the whole card with the day colour and expanded detail inline.
/// Seven saturated cards stacked meant the week had no visual hierarchy at
/// all, and the inline expansion nested a third level of bordered boxes. The
/// colour now identifies from a rail; the detail lives in a sheet.
class DayRow extends StatelessWidget {
  final TrainingDay day;
  final Color accent;
  final String summary;
  final bool isToday;
  final VoidCallback onTap;

  const DayRow({
    super.key,
    required this.day,
    required this.accent,
    required this.summary,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onAccent = DayColours.onColorFor(accent);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: JinatraTokens.cardDecoration(
          shadowOffset: JinatraTokens.shadowSm,
          borderColor: isToday ? JinatraTokens.signal : JinatraTokens.ink,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(JinatraTokens.radiusCard - 3),
                  bottomLeft: Radius.circular(JinatraTokens.radiusCard - 3),
                ),
              ),
              child: Text(
                day.tag.toUpperCase(),
                style: JinatraTokens.monoData(fontSize: 11, color: onAccent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          day.name,
                          overflow: TextOverflow.ellipsis,
                          style: JinatraTokens.sectionHeader(fontSize: 15),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: JinatraTokens.cardDecoration(
                            background: JinatraTokens.signal,
                            borderWidth: JinatraTokens.borderDivider,
                            hasShadow: false,
                            radius: JinatraTokens.radiusPill,
                          ),
                          child: Text(
                            'TODAY',
                            style: JinatraTokens.monoData(
                              fontSize: 8,
                              color: JinatraTokens.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    style: JinatraTokens.monoData(
                      fontSize: 10,
                      color: JinatraTokens.ink.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: JinatraTokens.ink.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
