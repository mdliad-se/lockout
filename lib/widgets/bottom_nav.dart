import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool foodTabEnabled;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.foodTabEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'label': 'HOME', 'icon': Icons.home},
      {'label': 'ROUTINES', 'icon': Icons.fitness_center},
      if (foodTabEnabled) {'label': 'FOOD', 'icon': Icons.restaurant},
      {'label': 'BODY', 'icon': Icons.monitor_weight},
      {'label': 'LOG', 'icon': Icons.calendar_month},
    ];

    return Container(
      decoration: BoxDecoration(
        color: JinatraTokens.sweetCream,
        border: Border(
          top: BorderSide(color: JinatraTokens.ink, width: JinatraTokens.borderControl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isActive = currentIndex == index;
            final item = tabs[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: isActive
                        ? JinatraTokens.cardDecoration(
                            background: JinatraTokens.deepTeal,
                            shadowOffset: JinatraTokens.shadowSm,
                            radius: JinatraTokens.radiusPill,
                          )
                        : const BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: isActive
                              ? JinatraTokens.onPrimary
                              : JinatraTokens.ink.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['label'] as String,
                          style: JinatraTokens.monoData(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? JinatraTokens.onPrimary
                                : JinatraTokens.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
