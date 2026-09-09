import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// The single saturated block a screen is allowed.
///
/// v1 gave several blocks per screen a filled accent, which is why the app
/// read as noisy: nothing was clearly the most important thing. Exactly one
/// HeroCard per screen is the rule the rest of the layout hangs off.
class HeroCard extends StatelessWidget {
  /// Small mono label above the title — context, not content.
  final String eyebrow;

  /// The one thing this screen is about.
  final String title;

  /// Optional mono detail line under the title.
  final String? subtitle;

  /// Saturated fill, normally `JinatraTokens.accentAt(n)`.
  final Color background;

  /// Pill actions laid out in a wrap under the text.
  final List<Widget> actions;

  const HeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.background,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final on = JinatraTokens.onAccentColor(background);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: JinatraTokens.cardDecoration(
        background: background,
        shadowOffset: JinatraTokens.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: on.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: JinatraTokens.displayHeader(fontSize: 30, color: on),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: JinatraTokens.monoData(
                fontSize: 12,
                color: on.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}
