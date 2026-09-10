import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';

int mealSubtotalKcal(List<FoodEntry> entries) =>
    entries.fold<int>(0, (sum, e) => sum + e.kcal);

/// One meal's entries under a labelled rule with a subtotal.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: JinatraTokens.monoData(fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 2,
                  color: JinatraTokens.ink.withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${mealSubtotalKcal(entries)} kcal',
                style: JinatraTokens.monoData(
                  fontSize: 11,
                  color: JinatraTokens.deepTeal,
                ),
              ),
            ],
          ),
        ),
        ...entries.map((e) => _row(e)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _row(FoodEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: JinatraTokens.cardDecoration(
        borderWidth: JinatraTokens.borderDivider,
        shadowOffset: JinatraTokens.shadowSm,
        radius: JinatraTokens.radiusTile,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: JinatraTokens.bodyText(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'P ${e.proteinG.toStringAsFixed(0)}  '
                  'C ${e.carbG.toStringAsFixed(0)}  '
                  'F ${e.fatG.toStringAsFixed(0)}',
                  style: JinatraTokens.monoData(
                    fontSize: 9,
                    color: JinatraTokens.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${e.kcal}',
            style: JinatraTokens.monoData(fontSize: 13),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onDelete(e),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              size: 16,
              color: JinatraTokens.ink.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
