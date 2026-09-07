import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

class JinatraButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  /// Null resolves to the palette primary / onPrimary at build time, so a
  /// theme switch repaints buttons that never named an explicit colour.
  final Color? background;
  final Color? textColor;
  final bool isSignal;
  final IconData? icon;

  const JinatraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.background,
    this.textColor,
    this.isSignal = false,
    this.icon,
  });

  @override
  State<JinatraButton> createState() => _JinatraButtonState();
}

class _JinatraButtonState extends State<JinatraButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = widget.isSignal
        ? JinatraTokens.signal
        : (widget.background ?? JinatraTokens.deepTeal);
    final effectiveText = widget.isSignal
        ? JinatraTokens.onAccent
        : (widget.textColor ?? JinatraTokens.onPrimary);
    final offset = _isPressed ? 0.0 : JinatraTokens.shadowSm;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(_isPressed ? 3.0 : 0.0, _isPressed ? 3.0 : 0.0, 0.0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: JinatraTokens.ink, width: JinatraTokens.borderControl),
          boxShadow: [JinatraTokens.hardShadow(offset: offset)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: effectiveText, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label.toUpperCase(),
              style: JinatraTokens.monoData(
                color: effectiveText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
