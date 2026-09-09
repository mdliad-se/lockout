import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

class JinatraInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const JinatraInput({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label.toUpperCase(),
            style: JinatraTokens.monoData(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: JinatraTokens.paper,
            borderRadius: BorderRadius.circular(JinatraTokens.radiusTile),
            border: Border.all(color: JinatraTokens.ink, width: JinatraTokens.borderControl),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: JinatraTokens.bodyText(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: JinatraTokens.bodyText(color: JinatraTokens.ink.withValues(alpha: 0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(JinatraTokens.radiusTile),
                borderSide: BorderSide(color: JinatraTokens.signal, width: 3.0),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
