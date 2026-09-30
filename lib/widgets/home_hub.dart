import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/lockout_theme.dart';
import 'action_grid.dart';
import 'hero_card.dart';
import 'nutrition_bars.dart';
import 'weight_card.dart';

/// Everything the hub needs to render, resolved by the caller.
///
/// Nulls are meaningful: they mean "not on record", and the hub renders a
/// prompt instead of a number. A zero would be a lie.
class HomeHubSummary {
  final int kcalEaten;

  /// The daily calorie target. Nullable so a widget test can exercise the
  /// "set a goal" prompt with no database, but that branch is not reachable
  /// on a real device: `GoalService.snapshot().calorieTarget` always resolves
  /// to something — the calculated plan, the user's manual override, or the
  /// seeded `calorie_target` default.
  final int? kcalTarget;

  final double? weightKg;
  final double? weightDeltaKg;

  /// Total estimated kcal burned today. Null means no session was logged
  /// today at all. A non-null value of zero or less means a session *was*
  /// logged but no estimate could be made for it (no bodyweight on record),
  /// which reads as "estimate unavailable" rather than denying the session
  /// happened.
  final double? burnedTodayKcal;

  /// The goal weight. Null when no goal is configured, in which case the
  /// weight card states the weight without inventing a gap.
  final double? targetWeightKg;

  final double proteinEatenG;

  /// Null until a nutrition plan exists to derive one from.
  final int? proteinTargetG;

  /// Recent weights, oldest first, for the trend line. Fewer than two points
  /// cannot make a line and the card says so instead of drawing one.
  final List<double> weightSeries;

  const HomeHubSummary({
    required this.kcalEaten,
    required this.kcalTarget,
    required this.weightKg,
    required this.weightDeltaKg,
    required this.burnedTodayKcal,
    this.targetWeightKg,
    this.proteinEatenG = 0,
    this.proteinTargetG,
    this.weightSeries = const [],
  });
}

/// The HOME landing screen.
///
/// v2 was one hero plus three identical navigable rows plus a colour grid.
/// Three rows of equal weight said less than one card each could: the weight
/// row could state a number but not the gap or the trend, and the calories row
/// could state intake but not how much was left. Each is now a card that
/// answers the question it is actually asked.
///
/// Presentation only — every value and every tap handler is passed in, so this
/// file has no dependency on the database or on the session state machine that
/// lives in `today_tab.dart`.
class HomeHub extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  /// The day's identifying colour, from the semantics ramp.
  final Color heroColor;

  final List<Widget> heroActions;
  final HomeHubSummary summary;
  final List<ActionItem> actions;
  final VoidCallback? onOpenFood;
  final VoidCallback? onOpenBody;
  final VoidCallback? onOpenLog;

  /// Whether the Food tab is reachable at all. When false the whole nutrition
  /// block is dropped rather than shown with values the user cannot act on.
  final bool foodTabEnabled;

  // Non-const constructor: see "Why some constructors in this app are
  // not const" at the top of lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  HomeHub({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.heroColor,
    required this.heroActions,
    required this.summary,
    required this.actions,
    this.onOpenFood,
    this.onOpenBody,
    this.onOpenLog,
    this.foodTabEnabled = true,
  });

  /// The day card's supporting line: what is scheduled, and what today has
  /// already burned when there is a session to report.
  String? get _daySubtitle {
    final burn = _burnLabel;
    if (subtitle == null) return burn;
    if (burn == null) return subtitle;
    return '$subtitle · $burn';
  }

  String? get _burnLabel {
    final burned = summary.burnedTodayKcal;
    if (burned == null) return null;
    // Reuses SessionLog's formatter rather than re-deriving "~123 kcal" here;
    // it returns '' for a non-positive value. That is a *different* state from
    // null: a session was logged but no estimate could be made for it, so this
    // must not read as "no session yet" — that would deny a session the user
    // just saved.
    final label = SessionLog.formatKcal(burned);
    return label.isEmpty ? 'Estimate unavailable' : label;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroCard(
          eyebrow: eyebrow,
          title: title,
          subtitle: _daySubtitle,
          accent: heroColor,
          actions: heroActions,
        ),
        WeightCard(
          weightKg: summary.weightKg,
          targetWeightKg: summary.targetWeightKg,
          deltaKg: summary.weightDeltaKg,
          series: summary.weightSeries,
          onTap: onOpenBody,
        ),
        if (foodTabEnabled) ...[
          const SizedBox(height: LockoutTheme.spaceSm),
          NutritionBars(
            kcalEaten: summary.kcalEaten,
            kcalTarget: summary.kcalTarget,
            proteinEatenG: summary.proteinEatenG,
            proteinTargetG: summary.proteinTargetG,
            onTap: onOpenFood,
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: LockoutTheme.spaceLg),
          Text('QUICK ACTIONS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: LockoutTheme.spaceSm),
          ActionGrid(items: actions),
        ],
        const SizedBox(height: LockoutTheme.spaceXl),
      ],
    );
  }
}
