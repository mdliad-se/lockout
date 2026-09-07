import 'dart:math';

import 'units.dart';

enum Sex { male, female }

/// How much the user moves outside of deliberate training.
enum ActivityLevel {
  sedentary('Sedentary', 'Desk job, little walking', 1.2),
  light('Lightly Active', 'Light exercise 1-3 days/week', 1.375),
  moderate('Moderately Active', 'Training 3-5 days/week', 1.55),
  high('Very Active', 'Hard training 6-7 days/week', 1.725),
  athlete('Athlete', 'Physical job plus daily training', 1.9);

  final String label;
  final String blurb;
  final double multiplier;

  const ActivityLevel(this.label, this.blurb, this.multiplier);

  static ActivityLevel fromKey(String key) => ActivityLevel.values.firstWhere(
        (a) => a.name == key,
        orElse: () => ActivityLevel.moderate,
      );
}

enum GoalDirection { cut, maintain, gain }

/// A complete, explainable calorie and macro prescription.
class NutritionPlan {
  final double bmr;
  final double tdee;
  final int targetKcal;

  /// Daily surplus/deficit implied by the goal. Negative means a deficit.
  final int dailyDeltaKcal;

  final GoalDirection direction;

  /// kg to move, signed. Negative means weight to lose.
  final double weightDeltaKg;
  final int weeks;

  /// Rate as a share of bodyweight per week — the number that decides whether
  /// a plan is sane. Above ~1%/week of loss risks muscle.
  final double weeklyRatePct;

  /// True when the requested rate is outside a safe band and was clamped.
  final bool wasClamped;
  final String? warning;

  final int proteinG;
  final int carbG;
  final int fatG;

  const NutritionPlan({
    required this.bmr,
    required this.tdee,
    required this.targetKcal,
    required this.dailyDeltaKcal,
    required this.direction,
    required this.weightDeltaKg,
    required this.weeks,
    required this.weeklyRatePct,
    required this.wasClamped,
    required this.warning,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
  });

  String get directionLabel => switch (direction) {
        GoalDirection.cut => 'CUT',
        GoalDirection.maintain => 'MAINTAIN',
        GoalDirection.gain => 'GAIN',
      };
}

/// Turns body data plus a goal into a calorie target, instead of asking the
/// user to guess a number.
///
/// Uses Mifflin-St Jeor for BMR — the equation with the best track record for
/// non-athlete populations — then an activity multiplier for TDEE, then a
/// deficit or surplus sized by how much weight is to move and over how long.
class NutritionPlanner {
  NutritionPlanner._();

  /// Energy in 1 kg of body mass. The classic 7700 kcal/kg figure.
  static const double kcalPerKg = 7700.0;

  /// Safety rails, as a share of bodyweight per week.
  static const double maxLossRatePct = 1.0;
  static const double maxGainRatePct = 0.5;

  /// Never prescribe below this, whatever the maths says.
  static const int minMaleKcal = 1500;
  static const int minFemaleKcal = 1200;

  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required Sex sex,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return sex == Sex.male ? base + 5 : base - 161;
  }

  static double tdee({
    required double bmrValue,
    required ActivityLevel activity,
  }) =>
      bmrValue * activity.multiplier;

  static NutritionPlan build({
    required double currentWeightKg,
    required double targetWeightKg,
    required double heightCm,
    required int age,
    required Sex sex,
    required ActivityLevel activity,
    required int weeks,
  }) {
    final safeWeeks = weeks < 1 ? 1 : weeks;
    final bmrValue = bmr(
      weightKg: currentWeightKg,
      heightCm: heightCm,
      age: age,
      sex: sex,
    );
    final tdeeValue = tdee(bmrValue: bmrValue, activity: activity);

    final deltaKg = targetWeightKg - currentWeightKg;
    final direction = deltaKg.abs() < 0.5
        ? GoalDirection.maintain
        : (deltaKg < 0 ? GoalDirection.cut : GoalDirection.gain);

    // Requested pace, before any safety clamp.
    var weeklyKg = deltaKg / safeWeeks;
    var ratePct = currentWeightKg <= 0
        ? 0.0
        : (weeklyKg.abs() / currentWeightKg) * 100;

    var clamped = false;
    String? warning;

    final cap = direction == GoalDirection.gain ? maxGainRatePct : maxLossRatePct;
    if (direction != GoalDirection.maintain && ratePct > cap) {
      clamped = true;
      final cappedWeekly = currentWeightKg * (cap / 100);
      weeklyKg = deltaKg < 0 ? -cappedWeekly : cappedWeekly;
      final realisticWeeks = (deltaKg.abs() / cappedWeekly).ceil();
      warning = direction == GoalDirection.cut
          ? 'That pace is faster than ${cap.toStringAsFixed(1)}% of bodyweight per week, '
              'which tends to cost muscle. Target eased to a safe rate — expect '
              'roughly $realisticWeeks weeks instead of $safeWeeks.'
          : 'Gaining faster than ${cap.toStringAsFixed(1)}% of bodyweight per week is '
              'mostly fat. Target eased to a safe rate — expect roughly '
              '$realisticWeeks weeks instead of $safeWeeks.';
      ratePct = cap;
    }

    var dailyDelta = (weeklyKg * kcalPerKg / 7).round();
    var target = (tdeeValue + dailyDelta).round();

    // Absolute floor beats every other consideration.
    final floor = sex == Sex.male ? minMaleKcal : minFemaleKcal;
    if (target < floor) {
      target = floor;
      dailyDelta = target - tdeeValue.round();
      clamped = true;
      warning =
          'The maths landed below a safe intake floor, so the target is held at '
          '$floor kcal. Losing weight more slowly, or moving more, is the safer lever.';
    }

    final macros = _macros(
      targetKcal: target,
      weightKg: currentWeightKg,
      direction: direction,
    );

    return NutritionPlan(
      bmr: bmrValue,
      tdee: tdeeValue,
      targetKcal: target,
      dailyDeltaKcal: dailyDelta,
      direction: direction,
      weightDeltaKg: deltaKg,
      weeks: safeWeeks,
      weeklyRatePct: ratePct,
      wasClamped: clamped,
      warning: warning,
      proteinG: macros.$1,
      carbG: macros.$2,
      fatG: macros.$3,
    );
  }

  /// Protein first (it protects lean mass in a deficit), then fat as a share of
  /// calories, then carbs take whatever is left.
  static (int, int, int) _macros({
    required int targetKcal,
    required double weightKg,
    required GoalDirection direction,
  }) {
    final proteinPerKg = switch (direction) {
      GoalDirection.cut => 2.2,
      GoalDirection.maintain => 1.8,
      GoalDirection.gain => 1.8,
    };
    final protein = (weightKg * proteinPerKg).round();

    final fatKcal = targetKcal * 0.25;
    final fat = (fatKcal / 9).round();

    final remaining = targetKcal - (protein * 4) - (fat * 9);
    final carbs = max(0, (remaining / 4).round());

    return (protein, carbs, fat);
  }

  /// BMI straight from stored height and the latest logged weight. Waist is a
  /// separate measurement and plays no part in it.
  static double? bmiFor({
    required double weightKg,
    required double heightCm,
  }) =>
      Units.bmi(weightKg: weightKg, heightCm: heightCm);

  /// Healthy-BMI weight band for a height, so the goal screen can say what a
  /// sensible target actually is.
  static (double, double) healthyWeightRangeKg(double heightCm) {
    final m = heightCm / 100.0;
    return (18.5 * m * m, 24.9 * m * m);
  }
}
