import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/lockout_semantics.dart';
import '../theme/lockout_theme.dart';

// --------------------------------------------------------------------------
// Why some constructors in this app are not const
//
// A number of widgets across `lib/` declare a non-const constructor with
// `// ignore: prefer_const_constructors_in_immutables` and point at this
// note. It is one note rather than twenty copies because the copies stated
// a rule that is wrong.
//
// The claim was that a const instance is canonicalised, skipped on rebuild,
// and therefore "stranded in the previous theme after a switch". The first
// half is real — `Element.updateChild` returns the existing child untouched
// when the new widget is identical to the old one — but the conclusion does
// not follow: anything reading `Theme.of(context)` registers an
// `InheritedWidget` dependency, and a theme change rebuilds every dependent
// directly rather than through its parent. A const constructor cannot strand
// a widget in the old theme, and nothing here depends on avoiding one.
//
// What is left is narrower and has nothing to do with colour: most of these
// constructors are invoked with runtime values — a `GlobalKey` held by a
// `State`, a callback, a model loaded from the database — so the call site
// could not be a const expression anyway and a const declaration would buy
// nothing. Five of the twenty could be const today, all of them
// zero-argument: `main.dart`'s `MainScreen()`, `exercise_picker.dart`'s
// `_ExercisePickerSheet()`, `food_picker.dart`'s `_FoodPickerSheet()`,
// `body_tab.dart`'s `_MeasurementForm()` and `routines_tab.dart`'s
// `_CreateRoutineForm()`. The saving there is a handful of canonicalised
// widgets, which is not worth churning files on a UI-only branch for.
// Anything new should prefer const.
// --------------------------------------------------------------------------

/// Colour coding per training day, so a week reads at a glance.
///
/// Two rules, in this order:
///  1. A day proposes the accent for its category, so Push/Pull/Legs keep a
///     recognisable colour across routines and across themes.
///  2. Within one routine, no two training days may share a colour while a
///     free slot remains. v1 broke here: "Upper Body + Core" and "Upper
///     Body" are both category 5, so both rendered the same magenta and the
///     week stopped being scannable. A day whose category accent is already
///     taken walks forward to the first free slot; once every slot is in
///     use, colours repeat deterministically. Either way, a training day
///     never receives the colour reserved for rest days.
///
/// Colours come from the scheme's authored ramp (`LockoutSemantics
/// .categoryRamp`) rather than HSL rotation of the primary — rotation
/// produced muddy mid-tones in several themes and could not guarantee
/// distinctness in the first place.
class DayColours {
  DayColours._();

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
  /// their category colour when two days want the same one. [semantics]
  /// supplies both the ramp and the rest-day colour, so the assignment
  /// follows the active scheme exactly.
  static Map<String, Color> assign(
    List<TrainingDay> days,
    LockoutSemantics semantics,
  ) {
    final ramp = semantics.categoryRamp;
    final restColour = semantics.restDay;
    final result = <String, Color>{};
    final taken = <int>{};

    // Some schemes' authored ramp could in principle reuse the same colour
    // as restDay. Reserve those slots up front so a training day can never
    // be handed the rest colour by coincidence — this holds no matter how
    // many training days are in the list.
    final reserved = <int>{};
    for (var i = 0; i < ramp.length; i++) {
      if (ramp[i] == restColour) reserved.add(i);
    }
    taken.addAll(reserved);

    for (final day in days) {
      if (day.isRestDay) {
        result[day.id] = restColour;
        continue;
      }

      final seed = categoryOf(day) % ramp.length;

      // Walk forward from the category seed to the first slot not yet in
      // use (reserved slots count as in-use from the start). Bounded by
      // ramp.length so a fully saturated ramp can't spin forever.
      var slot = seed;
      var steps = 0;
      while (taken.contains(slot) && steps < ramp.length) {
        slot = (slot + 1) % ramp.length;
        steps++;
      }

      if (!taken.contains(slot)) {
        taken.add(slot);
        result[day.id] = ramp[slot];
        continue;
      }

      // Saturated: every slot — reserved or not — is already in use.
      // Colours may now repeat, but never the reserved one. Walk again from
      // the same seed, this time stepping only around reserved slots; the
      // outcome depends solely on the seed and the palette, so repeated
      // calls with the same days stay identical. If a palette had every
      // accent equal to restColour, this bottoms out back at the seed
      // instead of looping forever.
      var reuse = seed;
      var reuseSteps = 0;
      while (reserved.contains(reuse) && reuseSteps < ramp.length) {
        reuse = (reuse + 1) % ramp.length;
        reuseSteps++;
      }
      result[day.id] = ramp[reuse];
    }

    return result;
  }

  /// Text and icons drawn on a day colour.
  ///
  /// A one-line delegate to [LockoutSemantics.onCategoryColor] and nothing
  /// more — kept only as the seam the day-colour code reads through, so
  /// `routines_tab.dart` asks one class for both the accent and its label
  /// colour instead of having to know which of the two owns which half. It
  /// adds no behaviour; if that pairing ever stops holding, delete it and
  /// let the caller reach for the semantics directly.
  static Color onColorFor(Color background) =>
      LockoutSemantics.onCategoryColor(background);
}

/// A section heading inside an expanded day — "WARM-UP", "FINISHER".
///
/// Deliberately a rule with a label rather than a bordered box: the day card
/// already draws a frame, and nesting another one made the routine list read
/// as a wall of rectangles. Uppercase stays: this is the small-metadata-label
/// exception (`labelSmall`), same idiom as "WORKOUT ARCHIVE" and "QUICK
/// ACTIONS" elsewhere in the app.
class SectionHeading extends StatelessWidget {
  final String title;
  final String amount;

  const SectionHeading({
    super.key,
    required this.title,
    this.amount = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            // The title names the section, so it takes the full-strength
            // `onSurface`. The amount below only qualifies it and keeps
            // `labelSmall`'s own `onSurfaceVariant`. Both sides are the
            // same 11px type — v1 separated them with a smaller, more
            // transparent style and this carries it on colour roles alone,
            // so the pair has to be pinned in a test (it is, in
            // `widgets_v2_test.dart`) or it re-flattens unnoticed.
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colors.onSurface),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              color: colors.outlineVariant,
            ),
          ),
          if (amount.isNotEmpty) ...[
            const SizedBox(width: 8),
            // Bare `labelSmall`, which already carries `onSurfaceVariant`
            // — the receding half of the pair the title steps out of.
            Text(amount, style: theme.textTheme.labelSmall),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          Text(amt, style: theme.textTheme.labelSmall),
          // A bare 14px glyph was the last delete affordance in the app
          // below a tap-target floor. It sits on `LockoutTheme
          // .minTouchTarget` like every other control this branch restyled —
          // the 40 it first shipped with was inherited from the widgets this
          // replaced, never a decision. The box carries the row's height
          // too, so every row in the day sheet is one bar tall whether or
          // not it has a remove control.
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: LockoutTheme.minTouchTarget,
                  minHeight: LockoutTheme.minTouchTarget,
                ),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            const SizedBox(
              width: LockoutTheme.minTouchTarget,
              height: LockoutTheme.minTouchTarget,
            ),
        ],
      ),
    );
  }
}

/// The single add affordance for a day-sheet section, shown whether or not
/// the section already has rows. It used to be an empty-state-only control
/// that a heading `+` replaced on first use; all three sections now keep it
/// in both states so the button the user just pressed is still there.
class AddLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AddLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // A `ConstrainedBox` rather than padding, for `LockoutTheme
      // .minTouchTarget`: `HitTestBehavior.opaque` does not enlarge the box
      // it sits on, and padding a 10px mono line to the floor leaves the
      // result depending on the font's line height. A minimum states it
      // instead. log_tab.dart clears the same floor for the same 10px text
      // with `vertical: 14` padding and its own test holds it there, so both
      // idioms work — that one and meal_section.dart / undo_banner.dart are
      // candidates to migrate to this stated-minimum form later.
      // The `Row` does two jobs: `mainAxisSize.min` shrink-wraps the label
      // so the visible text is unchanged, and its default cross-axis
      // centring puts the glyphs in the middle of the box. Without it a bare
      // `Text` paints at the top and leaves the rest of the box empty
      // beneath it.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: LockoutTheme.minTouchTarget,
          minWidth: LockoutTheme.minTouchTarget,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
