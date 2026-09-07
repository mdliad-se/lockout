import '../data/routine_templates.dart';
import 'nutrition_planner.dart';

/// A recommended routine plus the reasoning behind it, so the suggestion can
/// be argued with rather than just obeyed.
class TrainingRecommendation {
  final RoutineTemplate template;
  final GoalDirection direction;
  final int daysPerWeek;

  /// Why this split, in one sentence.
  final String rationale;

  /// Conditioning guidance that sits alongside the lifting.
  final String cardioAdvice;

  /// Rep-range emphasis for the goal.
  final String loadingAdvice;

  const TrainingRecommendation({
    required this.template,
    required this.direction,
    required this.daysPerWeek,
    required this.rationale,
    required this.cardioAdvice,
    required this.loadingAdvice,
  });
}

/// Picks a starter split from the user's goal and how many days they can
/// realistically train.
///
/// The honest constraint here: training frequency is limited by the days a
/// person will actually show up, not by what is theoretically optimal. So
/// available days is the primary input and the goal only shapes emphasis.
class TrainingPlanner {
  TrainingPlanner._();

  static TrainingRecommendation recommend({
    required GoalDirection direction,
    required int daysPerWeek,
  }) {
    final days = daysPerWeek.clamp(2, 6);

    final template = switch (days) {
      <= 3 => RoutineTemplate.all.firstWhere((t) => t.key == 'full_body'),
      4 => RoutineTemplate.all.firstWhere((t) => t.key == 'upper_lower'),
      5 => RoutineTemplate.all.firstWhere((t) => t.key == 'bro_split'),
      _ => RoutineTemplate.all.firstWhere((t) => t.key == 'ppl'),
    };

    final rationale = switch (days) {
      <= 3 =>
        'At $days days a week, full-body sessions hit every muscle 3x weekly — '
            'more total stimulus than a split can give you at this frequency.',
      4 =>
        'Four days splits cleanly into upper/lower, so each muscle gets trained '
            'twice a week with enough recovery between sessions.',
      5 =>
        'Five days lets each muscle group get a dedicated session with high '
            'volume, without cramming two body parts into one workout.',
      _ =>
        'Six days suits push/pull/legs run twice through, giving high frequency '
            'and high volume for someone already used to training.',
    };

    final cardioAdvice = switch (direction) {
      GoalDirection.cut =>
        'Add 2-3 easy cardio sessions of 25-40 min, plus a daily step target. '
            'Keep it low intensity so it does not eat into lifting recovery.',
      GoalDirection.maintain =>
        'Two moderate cardio sessions a week is enough to hold conditioning '
            'without interfering with strength work.',
      GoalDirection.gain =>
        'Keep cardio light — one or two short sessions for heart health. More '
            'than that fights the surplus you are trying to hold.',
    };

    final loadingAdvice = switch (direction) {
      GoalDirection.cut =>
        'Keep the weight heavy and the reps in the 6-10 range. In a deficit, '
            'heavy loading is the signal that tells your body to keep the muscle.',
      GoalDirection.maintain =>
        'Work mostly in the 8-12 range and chase small weekly load increases.',
      GoalDirection.gain =>
        'Push progressive overload hard in the 6-12 range. A surplus is when '
            'adding weight to the bar works best — add load before adding reps.',
    };

    return TrainingRecommendation(
      template: template,
      direction: direction,
      daysPerWeek: days,
      rationale: rationale,
      cardioAdvice: cardioAdvice,
      loadingAdvice: loadingAdvice,
    );
  }
}
