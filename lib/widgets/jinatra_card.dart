import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

class JinatraCard extends StatelessWidget {
  final Widget child;
  /// Null resolves to the palette surface colour at build time.
  final Color? background;
  final double shadowOffset;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  const JinatraCard({
    super.key,
    required this.child,
    this.background,
    this.shadowOffset = JinatraTokens.shadowMd,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.radius = JinatraTokens.radiusCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: JinatraTokens.cardDecoration(
        background: background,
        shadowOffset: shadowOffset,
        radius: radius,
      ),
      child: child,
    );
  }
}
