import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';

int mealSubtotalKcal(List<FoodEntry> entries) =>
    entries.fold<int>(0, (sum, e) => sum + e.kcal);

/// One decimal place, trimmed to a whole number when exact — enough
/// precision that a logged 0.4g doesn't silently round down to a measured
/// zero, without manufacturing false precision on values that are exact.
String _formatMacro(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// One meal's entries under a labelled rule with a subtotal.
///
/// v1 showed the day as one flat list, so "how much was lunch" could not be
/// answered without adding rows up by eye. An empty meal renders nothing
/// rather than an empty heading.
class MealSection extends StatelessWidget {
  final String title;
  final List<FoodEntry> entries;
  final void Function(FoodEntry) onDelete;

  // NOT const: `build` resolves a palette colour, so a const call site
  // would canonicalise this widget and `Element.updateChild` would skip
  // its rebuild on a theme switch, stranding it in the old palette. A
  // non-const constructor makes that unrepresentable rather than asking
  // every call site to remember.
  // ignore: prefer_const_constructors_in_immutables
  MealSection({
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
                  color: JinatraTokens.ink,
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
                  'P ${_formatMacro(e.proteinG)}  '
                  'C ${_formatMacro(e.carbG)}  '
                  'F ${_formatMacro(e.fatG)}',
                  style: JinatraTokens.monoData(
                    fontSize: 9,
                    color: JinatraTokens.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${e.kcal} kcal',
            style: JinatraTokens.monoData(fontSize: 13),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onDelete(e),
            behavior: HitTestBehavior.opaque,
            // Padding lives *inside* the detector so the tappable area grows
            // to a 40dp square without enlarging the visible glyph —
            // `HitTestBehavior.opaque` alone only makes the existing 16x16
            // box register taps everywhere within it, it does not resize
            // that box. Matches BODY's delete affordance
            // (`body_tab.dart`, `EdgeInsets.all(12)` around the same 16dp
            // glyph) so the two delete flows feel identical (third-round
            // review, Finding 8) — this used to be `EdgeInsets.all(10)`,
            // ~36dp. This is the screen's only delete path with no upfront
            // confirmation, but (Ruling F) `showUndoBanner` gives a few
            // seconds to reverse it, same as BODY.
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.close,
                size: 16,
                color: JinatraTokens.ink.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
