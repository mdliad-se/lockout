import 'package:flutter/material.dart';

/// The colours Material 3 has no role for.
///
/// A `ThemeExtension` rather than a static list, because these must follow a
/// theme switch and a dynamic (Material You) scheme exactly the way the
/// framework roles do. Reading them through `context` is what makes that
/// automatic instead of something every call site has to remember — the
/// previous system exposed the equivalents statically, and that is precisely
/// what made wallpaper-derived colour impossible to support.
@immutable
class LockoutSemantics extends ThemeExtension<LockoutSemantics> {
  /// A completed set, a hit target, a finished session.
  final Color success;

  /// The foreground painted on top of [success] — e.g. the check glyph on a
  /// filled "set complete" button. Stated explicitly rather than reusing
  /// `ColorScheme.onPrimary`: `success` is not `primary` in every scheme, and
  /// borrowing `onPrimary` for it only worked by coincidence (every current
  /// scheme happens to put `success` at the same luminance as `primary`).
  final Color onSuccess;

  /// The leg-safety notice and anything else advisory.
  final Color warning;

  /// Destructive confirmation only. Deliberately distinct from
  /// `ColorScheme.error`, which the framework also paints on an invalid form
  /// field — "you typed something wrong" and "this will delete your data"
  /// should not be the same colour.
  final Color danger;

  /// A scheduled rest day, which is neither success nor absence.
  final Color restDay;

  /// The weight/progress chart stroke and the area beneath it.
  final Color chartLine;
  final Color chartFill;

  /// Eight authored colours for telling many categories apart at a glance:
  /// training-day rails, the home action grid, category chips.
  ///
  /// Authored per scheme rather than derived. Rotating one hue through HSL
  /// collided two same-category days onto a single colour and produced muddy
  /// mid-tones; that finding predates this redesign and still holds, which is
  /// why the ramp is a literal in every scheme rather than a function of
  /// `primary`.
  final List<Color> categoryRamp;

  const LockoutSemantics({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.danger,
    required this.restDay,
    required this.chartLine,
    required this.chartFill,
    required this.categoryRamp,
  });

  /// The ramp colour at [index], wrapping, so a caller with more than eight
  /// categories degrades to reuse instead of throwing.
  Color categoryAt(int index) => categoryRamp[index % categoryRamp.length];

  /// Resolves the extension for [context].
  ///
  /// Asserts rather than falling back: every `ThemeData` this app builds
  /// registers the extension, so a null here means a widget is sitting under
  /// a bare `MaterialApp` in a test. A silent default would hide that and
  /// paint the wrong colours in a passing test.
  static LockoutSemantics of(BuildContext context) {
    final extension = Theme.of(context).extension<LockoutSemantics>();
    assert(
      extension != null,
      'No LockoutSemantics in the theme. Build the ThemeData with '
      'LockoutTheme.build(), or wrap the widget under test in one.',
    );
    return extension!;
  }

  @override
  LockoutSemantics copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? danger,
    Color? restDay,
    Color? chartLine,
    Color? chartFill,
    List<Color>? categoryRamp,
  }) {
    return LockoutSemantics(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      restDay: restDay ?? this.restDay,
      chartLine: chartLine ?? this.chartLine,
      chartFill: chartFill ?? this.chartFill,
      categoryRamp: categoryRamp ?? this.categoryRamp,
    );
  }

  @override
  LockoutSemantics lerp(covariant LockoutSemantics? other, double t) {
    if (other == null) return this;
    return LockoutSemantics(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      restDay: Color.lerp(restDay, other.restDay, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
      chartFill: Color.lerp(chartFill, other.chartFill, t)!,
      // Both ramps are always eight long — `schemes_test.dart` enforces it —
      // so this pairs by index rather than guarding a length mismatch that
      // cannot occur without that test already failing.
      categoryRamp: [
        for (var i = 0; i < categoryRamp.length; i++)
          Color.lerp(categoryRamp[i], other.categoryRamp[i], t)!,
      ],
    );
  }
}
