import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';

/// Colour coding per day type, so a training week reads at a glance.
///
/// The printed plan fills each day's whole header bar with a distinct hue —
/// Push yellow, Pull blue, Legs green — rather than tinting a small chip.
/// Hardcoding those would fight eight themes, so the hues are derived by
/// rotating the active palette's primary: distinct from each other, still
/// recognisably part of the current theme.
class DayPalette {
  /// Day categories in a fixed order, so the same kind of session keeps the
  /// same colour everywhere in the app.
  static int _categoryOf(TrainingDay day) {
    final key = '${day.name} ${day.focus}'.toLowerCase();
    if (key.contains('push') || key.contains('chest')) return 0;
    if (key.contains('pull') ||
        key.contains('back') ||
        key.contains('bicep')) {
      return 1;
    }
    if (key.contains('leg') || key.contains('lower') || key.contains('quad')) {
      return 2;
    }
    if (key.contains('shoulder') || key.contains('delt')) return 3;
    if (key.contains('arm') || key.contains('tricep')) return 4;
    if (key.contains('upper') || key.contains('full')) return 5;
    // Anything unrecognised still gets a stable colour rather than a default.
    return day.name.isEmpty ? 0 : day.name.codeUnitAt(0) % 6;
  }

  static Color forDay(TrainingDay day) {
    // Rest keeps the muted secondary surface — it should recede, not compete.
    if (day.isRestDay) return JinatraTokens.mistTeal;

    final base = HSLColor.fromColor(JinatraTokens.deepTeal);
    final hue = (base.hue + _categoryOf(day) * 58) % 360;

    // Clamp saturation and lightness so every rotation lands somewhere the
    // ink border and the label can both survive.
    final saturation = base.saturation.clamp(0.55, 0.95);
    final lightness = JinatraTokens.isDark
        ? base.lightness.clamp(0.45, 0.62)
        : base.lightness.clamp(0.38, 0.58);

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  /// Text and icons drawn on [forDay]. Decided by luminance rather than by a
  /// lookup, so it stays correct for every derived hue in every theme.
  static Color onColorFor(TrainingDay day) {
    final bg = forDay(day);
    return bg.computeLuminance() > 0.45
        ? const Color(0xFF111111)
        : const Color(0xFFFFFFFF);
  }
}

/// A section heading inside an expanded day — "WARM-UP", "FINISHER".
///
/// Deliberately a rule with a label rather than a bordered box: the day card
/// already draws a frame, and nesting another one made the routine list read
/// as a wall of rectangles.
class SectionHeading extends StatelessWidget {
  final String title;
  final String amount;
  final VoidCallback? onAdd;

  const SectionHeading({
    super.key,
    required this.title,
    this.amount = '',
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: JinatraTokens.monoData(
              fontSize: 10,
              color: JinatraTokens.ink.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              color: JinatraTokens.ink.withValues(alpha: 0.18),
            ),
          ),
          if (amount.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              amount,
              style: JinatraTokens.monoData(
                fontSize: 9,
                color: JinatraTokens.ink.withValues(alpha: 0.55),
              ),
            ),
          ],
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Icon(Icons.add, size: 16, color: JinatraTokens.ink),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One warm-up or finisher line. Plain text rows — the amount carries the
/// detail, so a border around each would add weight without adding meaning.
class SubItemRow extends StatelessWidget {
  final String name;
  final String amt;
  final VoidCallback? onRemove;

  const SubItemRow({
    super.key,
    required this.name,
    required this.amt,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: JinatraTokens.bodyText(fontSize: 13)),
          ),
          Text(
            amt,
            style: JinatraTokens.monoData(
              fontSize: 10,
              color: JinatraTokens.ink.withValues(alpha: 0.65),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                Icons.close,
                size: 14,
                color: JinatraTokens.ink.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Low-emphasis "add the first one" affordance, used where a whole empty
/// bordered block used to sit.
class AddLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AddLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2, top: 2),
        child: Text(
          label,
          style: JinatraTokens.monoData(
            fontSize: 10,
            color: JinatraTokens.deepTeal,
          ),
        ),
      ),
    );
  }
}
