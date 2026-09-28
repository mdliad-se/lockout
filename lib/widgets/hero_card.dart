import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'lockout_card.dart';

/// The one card a screen leads with.
///
/// v1 gave several blocks per screen a saturated fill, which is why the app
/// read as noisy: nothing was clearly the most important thing. Exactly one
/// HeroCard per screen is still the rule, but it now leads through elevation,
/// type scale and a single accent rail rather than by flooding a rectangle
/// with colour — a filled block that size fights the calm the design calls for
/// and forces every label inside it onto a contrast knife-edge.
class HeroCard extends StatelessWidget {
  /// Small label above the title — context, not content. One of the few
  /// places all-caps survives, because it is scanned rather than read.
  final String eyebrow;

  /// The one thing this screen is about.
  final String title;

  /// Optional detail line under the title.
  final String? subtitle;

  /// The identifying accent, normally from `LockoutSemantics.categoryAt(n)`.
  /// Used for the rail and the eyebrow, never as a fill.
  final Color accent;

  /// Actions laid out in a wrap under the text.
  final List<Widget> actions;

  const HeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.accent,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: LockoutTheme.spaceMd),
      child: LockoutCard(
        elevated: true,
        // IntrinsicHeight, because the rail below stretches to the row's
        // height and has no height of its own: inside a scroll view that
        // resolves to an infinite constraint and fails layout. The cost is one
        // extra measuring pass on a single card per screen.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // The accent identifies the day without colouring the card.
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
                      eyebrow,
                      style: text.labelSmall?.copyWith(
                        color: accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: LockoutTheme.spaceXs),
                    Text(title, style: text.headlineSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: LockoutTheme.spaceXs),
                      Text(subtitle!, style: text.bodyMedium),
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: LockoutTheme.spaceMd),
                      Wrap(
                        spacing: LockoutTheme.spaceSm,
                        runSpacing: LockoutTheme.spaceSm,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
