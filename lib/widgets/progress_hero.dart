import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// A hero card whose subject is a proportion — calories against a target.
///
/// The bar is clamped rather than allowed to overflow: going 300 kcal over
/// should read as "full and then some", not break the layout.
class ProgressHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  /// 0.0 to 1.0. Values outside that range are clamped.
  final double progress;

  final Color background;

  const ProgressHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final on = JinatraTokens.onAccentColor(background);
    final value = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
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
              color: on,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: JinatraTokens.displayHeader(fontSize: 26, color: on),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: on, width: JinatraTokens.borderDivider),
              borderRadius: BorderRadius.circular(JinatraTokens.radiusPill),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(JinatraTokens.radiusPill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: JinatraTokens.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(on),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: on,
            ),
          ),
        ],
      ),
    );
  }
}
