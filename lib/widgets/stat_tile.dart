import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// A small bordered metric: mono label above a mono value.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? background;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? JinatraTokens.paper;
    final on = JinatraTokens.onAccentColor(bg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: JinatraTokens.cardDecoration(
        background: bg,
        borderWidth: JinatraTokens.borderDivider,
        shadowOffset: JinatraTokens.shadowSm,
        radius: JinatraTokens.radiusTile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 9,
              color: on.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: JinatraTokens.monoData(fontSize: 16, color: on),
          ),
        ],
      ),
    );
  }
}
