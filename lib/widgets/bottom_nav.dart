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
      {'label': 'ROUTINES', 'icon': Icons.fitness_center},
      {'label': 'TODAY', 'icon': Icons.play_arrow},
      if (foodTabEnabled) {'label': 'FOOD', 'icon': Icons.restaurant},
      {'label': 'BODY', 'icon': Icons.monitor_weight},
      {'label': 'LOG', 'icon': Icons.calendar_month},
    ];

    return Container(
      decoration: const BoxDecoration(
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? JinatraTokens.deepTeal : JinatraTokens.sweetCream,
                    border: isActive
                        ? Border.all(color: JinatraTokens.ink, width: JinatraTokens.borderControl)
                        : const Border(right: BorderSide(color: JinatraTokens.ink, width: 1.0)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isActive ? JinatraTokens.sweetCream : JinatraTokens.ink,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'] as String,
                        style: JinatraTokens.monoData(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isActive ? JinatraTokens.sweetCream : JinatraTokens.ink,
                        ),
                      ),
                    ],
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
