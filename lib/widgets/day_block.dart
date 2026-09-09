import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';

/// Colour coding per training day, so a week reads at a glance.
///
/// Two rules, in this order:
///  1. A day proposes the accent for its category, so Push/Pull/Legs keep a
///     recognisable colour across routines and across themes.
///  2. Within one routine, no two training days may share a colour. v1 broke
///     here: "Upper Body + Core" and "Upper Body" are both category 5, so
///     both rendered the same magenta and the week stopped being scannable.
///     A day whose category accent is already taken walks forward to the
///     first free one.
///
/// Colours come from the palette's authored ramp rather than HSL rotation of
/// the primary — rotation produced muddy mid-tones in several themes and
/// could not guarantee distinctness in the first place.
class DayColours {
  DayColours._();

  /// Rest days recede rather than compete, and never consume an accent.
  static Color get restColour => JinatraTokens.mistTeal;

  /// Day categories in a fixed order, so the same kind of session keeps the
  /// same colour everywhere in the app.
  static int categoryOf(TrainingDay day) {
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
    // Anything unrecognised still gets a stable category rather than a
    // default, so the same custom day name always looks the same.
    return day.name.isEmpty ? 0 : day.name.codeUnitAt(0) % 6;
  }

  /// Colour per day for one routine, keyed by [TrainingDay.id].
  ///
  /// Pass the routine's days in display order; the order decides who keeps
  /// their category colour when two days want the same one.
  static Map<String, Color> assign(List<TrainingDay> days) {
    final ramp = JinatraTokens.accents;
    final result = <String, Color>{};
    final taken = <int>{};

    // Some themes' authored ramp happens to reuse the same colour as the
    // muted rest surface (e.g. Paper Press's yellow accent equals its
    // surfaceAlt). Reserve those slots up front so a training day can never
    // be handed the rest colour by coincidence.
    for (var i = 0; i < ramp.length; i++) {
      if (ramp[i] == restColour) taken.add(i);
    }

    for (final day in days) {
      if (day.isRestDay) {
        result[day.id] = restColour;
        continue;
      }

      final seed = categoryOf(day) % ramp.length;
      var slot = seed;
      // Walk forward to the first free slot. Once every slot is taken — more
      // than eight training days in one routine, possible with a rotating
      // schedule — fall back to the category colour and allow the reuse.
      if (taken.length < ramp.length) {
        var steps = 0;
        while (taken.contains(slot) && steps < ramp.length) {
          slot = (slot + 1) % ramp.length;
          steps++;
        }
      }

      taken.add(slot);
      result[day.id] = ramp[slot];
    }

    return result;
  }

  /// Text and icons drawn on a day colour.
  static Color onColorFor(Color background) =>
      JinatraTokens.onAccentColor(background);
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
