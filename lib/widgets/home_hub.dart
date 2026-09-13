import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/jinatra_tokens.dart';
import 'action_grid.dart';
import 'calm_row.dart';
import 'hero_card.dart';

/// Everything the hub needs to render, resolved by the caller.
///
/// Nulls are meaningful: they mean "not on record", and the hub renders a
/// prompt instead of a number. A zero would be a lie.
class HomeHubSummary {
  final int kcalEaten;

  /// The daily calorie target. Nullable so a widget test can exercise the
  /// "SET A GOAL" prompt with no database, but that branch is not reachable
  /// on a real device: `GoalService.snapshot().calorieTarget` always
  /// resolves to something — the calculated plan, the user's manual
  /// override, or the seeded `calorie_target` default (Ruling A) — so
  /// `TodayTab` can never actually pass null here.
  final int? kcalTarget;
  final double? weightKg;
  final double? weightDeltaKg;

  /// Total estimated kcal burned today. Null means no session was logged
  /// today at all — the honest "NO SESSION YET" case. A non-null value of
  /// zero or less means a session *was* logged but no estimate could be
  /// made for it (no bodyweight on record); the hub renders that as
  /// "ESTIMATE UNAVAILABLE" rather than denying the session happened.
  final double? burnedTodayKcal;

  const HomeHubSummary({
    required this.kcalEaten,
    required this.kcalTarget,
    required this.weightKg,
    required this.weightDeltaKg,
    required this.burnedTodayKcal,
  });
}

/// The HOME landing screen: one hero, three calm rows, a colour action grid.
///
/// Presentation only — every value and every tap handler is passed in, so
/// this file has no dependency on the database or on the session state
/// machine that lives in `today_tab.dart`.
class HomeHub extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Color heroColor;
  final List<Widget> heroActions;
  final HomeHubSummary summary;
  final List<ActionItem> actions;
  final VoidCallback? onOpenFood;
  final VoidCallback? onOpenBody;
  final VoidCallback? onOpenLog;

  /// Whether the Food tab is reachable at all. When false the CALORIES row
  /// is dropped entirely rather than shown with a value the user has no way
  /// to act on or change.
  final bool foodTabEnabled;

  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart.
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

  String get _intakeValue {
    final target = summary.kcalTarget;
    if (target == null) return 'SET A GOAL';
    return '${summary.kcalEaten} / $target kcal';
  }

  String get _weightValue {
    final w = summary.weightKg;
    if (w == null) return 'LOG A WEIGHT';
    final delta = summary.weightDeltaKg;
    if (delta == null) return '${w.toStringAsFixed(1)} kg';
    final sign = delta > 0 ? '+' : '';
    return '${w.toStringAsFixed(1)} kg  $sign${delta.toStringAsFixed(1)}';
  }

  String get _burnValue {
    final b = summary.burnedTodayKcal;
    if (b == null) return 'NO SESSION YET';
    // Reuses SessionLog's formatter rather than re-deriving the "~123 kcal"
    // format here; it returns '' for a non-positive value. That is a
    // *different* state from null: a session was logged (b is non-null) but
    // no estimate could be made for it, so this must not say "NO SESSION
    // YET" — that would deny a session the user just saved.
    final label = SessionLog.formatKcal(b);
    return label.isEmpty ? 'ESTIMATE UNAVAILABLE' : label;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroCard(
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          background: heroColor,
          actions: heroActions,
        ),
        if (foodTabEnabled)
          CalmRow(
            icon: Icons.restaurant,
            title: 'CALORIES',
            value: _intakeValue,
            onTap: onOpenFood,
          ),
        CalmRow(
          icon: Icons.monitor_weight,
          title: 'BODYWEIGHT',
          value: _weightValue,
          onTap: onOpenBody,
        ),
        CalmRow(
          icon: Icons.local_fire_department,
          title: 'BURNED TODAY',
          value: _burnValue,
          onTap: onOpenLog,
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'QUICK ACTIONS',
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: JinatraTokens.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          ActionGrid(items: actions),
        ],
        const SizedBox(height: 28),
      ],
    );
  }
}
