import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';

/// One destination in the quick-action grid.
class ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// A grid of coloured tiles.
///
/// The one place many saturated colours are allowed at once: this is a menu,
/// not content, so colour identifies rather than competes for attention.
class ActionGrid extends StatelessWidget {
  final List<ActionItem> items;
  final int columns;

  const ActionGrid({super.key, required this.items, this.columns = 4});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: items.map((i) => ActionTile(item: i)).toList(),
    );
  }
}

/// A single tile. Stateful only to carry the press-in shadow collapse that
/// every neubrutalist control in this app shares.
class ActionTile extends StatefulWidget {
  final ActionItem item;

  const ActionTile({super.key, required this.item});

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final on = JinatraTokens.onAccentColor(widget.item.color);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.item.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(
          _pressed ? 3.0 : 0.0,
          _pressed ? 3.0 : 0.0,
          0.0,
        ),
        decoration: JinatraTokens.cardDecoration(
          background: widget.item.color,
          shadowOffset: _pressed ? 0.0 : JinatraTokens.shadowSm,
          radius: JinatraTokens.radiusTile,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.item.icon, size: 24, color: on),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                widget.item.label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: JinatraTokens.monoData(fontSize: 9, color: on),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
