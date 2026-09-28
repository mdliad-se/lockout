import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'lockout_card.dart';

/// A low-emphasis navigable row: icon, title, value, chevron.
///
/// This is what secondary information looks like. It replaces the filled
/// cards v1 used for everything, which is what made the hierarchy unreadable.
class CalmRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  /// Tints the leading icon only. Pass one when the row genuinely needs
  /// identifying, which is rare — the default takes the secondary role.
  final Color? accent;

  const CalmRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
      child: LockoutCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: LockoutTheme.spaceMd,
          vertical: LockoutTheme.spaceSm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
              ),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: LockoutTheme.spaceMd),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            if (value != null)
              Text(
                value!,
                style: LockoutTheme.numeric(
                  context,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: LockoutTheme.spaceXs),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
