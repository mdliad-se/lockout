import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

class JinatraCard extends StatelessWidget {
  final Widget child;
  final Color background;
  final double shadowOffset;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const JinatraCard({
    super.key,
    required this.child,
    this.background = JinatraTokens.paper,
    this.shadowOffset = JinatraTokens.shadowMd,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: JinatraTokens.cardDecoration(
        background: background,
        shadowOffset: shadowOffset,
      ),
      child: child,
    );
  }
}
