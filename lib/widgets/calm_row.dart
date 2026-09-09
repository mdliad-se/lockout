import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// A low-emphasis navigable row: icon box, title, optional value, chevron.
///
/// This is what secondary information looks like in v2. It replaces the
/// filled cards v1 used for everything, which is what made the hierarchy
/// unreadable.
class CalmRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  /// Defaults to the palette's secondary surface. Pass an accent only when
  /// the row genuinely needs identifying, which is rare.
  final Color? iconBackground;

  const CalmRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = iconBackground ?? JinatraTokens.mistTeal;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: JinatraTokens.cardDecoration(
          shadowOffset: JinatraTokens.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: JinatraTokens.cardDecoration(
                background: iconBg,
                borderWidth: JinatraTokens.borderDivider,
                hasShadow: false,
                radius: JinatraTokens.radiusTile,
              ),
              child: Icon(
                icon,
                size: 20,
                color: JinatraTokens.onAccentColor(iconBg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: JinatraTokens.monoData(fontSize: 12),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: JinatraTokens.monoData(
                  fontSize: 13,
                  color: JinatraTokens.deepTeal,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: JinatraTokens.ink.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
