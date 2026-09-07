import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';

/// Colour coding per day type, mirroring the printed plan's legend so a week
/// can be read at a glance rather than word by word.
class DayPalette {
  static Color forDay(TrainingDay day) {
    if (day.isRestDay) return JinatraTokens.mistTeal;
    final key = '${day.name} ${day.focus}'.toLowerCase();
    if (key.contains('push') || key.contains('chest')) return JinatraTokens.signal;
    if (key.contains('pull') || key.contains('back')) return JinatraTokens.deepTeal;
    if (key.contains('leg') || key.contains('lower')) return JinatraTokens.mistTeal;
    if (key.contains('shoulder') || key.contains('arm')) return JinatraTokens.signal;
    return JinatraTokens.deepTeal;
  }

  static Color onColorFor(TrainingDay day) {
    final c = forDay(day);
    return c == JinatraTokens.deepTeal
        ? JinatraTokens.onPrimary
        : (c == JinatraTokens.signal
            ? JinatraTokens.onAccent
            : JinatraTokens.ink);
  }
}

/// A bordered sub-section inside a day card — the "Warm-Up" and "Conditioning
/// Finisher" blocks from the plan.
class DaySubBlock extends StatelessWidget {
  final String title;
  final String amount;
  final List<({String name, String amt})> rows;
  final Color headerColor;
  final Color headerTextColor;
  final VoidCallback? onAdd;
  final void Function(int index)? onRemove;

  const DaySubBlock({
    super.key,
    required this.title,
    required this.amount,
    required this.rows,
    required this.headerColor,
    required this.headerTextColor,
    this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: JinatraTokens.paper,
        border: Border.all(color: JinatraTokens.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(
                bottom: BorderSide(color: JinatraTokens.ink, width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: JinatraTokens.monoData(
                        fontSize: 10, color: headerTextColor),
                  ),
                ),
                if (amount.isNotEmpty)
                  Text(
                    amount,
                    style: JinatraTokens.monoData(
                        fontSize: 10, color: headerTextColor),
                  ),
                if (onAdd != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onAdd,
                    child: Icon(Icons.add, size: 15, color: headerTextColor),
                  ),
                ],
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Nothing added yet.',
                style: JinatraTokens.bodyText(
                  fontSize: 11,
                  color: JinatraTokens.ink.withValues(alpha: 0.55),
                ),
              ),
            )
          else
            ...rows.asMap().entries.map((e) {
              final isLast = e.key == rows.length - 1;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: JinatraTokens.ink.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.value.name,
                        style: JinatraTokens.bodyText(fontSize: 13),
                      ),
                    ),
                    Text(
                      e.value.amt,
                      style: JinatraTokens.monoData(
                        fontSize: 10,
                        color: JinatraTokens.ink.withValues(alpha: 0.7),
                      ),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => onRemove!(e.key),
                        child: Icon(Icons.close,
                            size: 14,
                            color: JinatraTokens.ink.withValues(alpha: 0.6)),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
