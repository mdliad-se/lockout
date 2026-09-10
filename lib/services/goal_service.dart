import 'database_service.dart';
import 'nutrition_planner.dart';
import 'training_planner.dart';

/// The user's stored profile and goal, read back as typed values.
class GoalProfile {
  final double heightCm;
  final double targetWeightKg;
  final int age;
  final Sex sex;
  final ActivityLevel activity;
  final int weeks;
  final int daysPerWeek;

  /// False until the user has actually filled the goal section in, so screens
  /// can prompt instead of showing a plan built from placeholder defaults.
  final bool isConfigured;

  const GoalProfile({
    required this.heightCm,
    required this.targetWeightKg,
    required this.age,
    required this.sex,
    required this.activity,
    required this.weeks,
    required this.daysPerWeek,
    required this.isConfigured,
  });
}

/// Bundles everything the Body tab needs in one read.
class GoalSnapshot {
  final GoalProfile profile;

  /// Latest logged bodyweight; null when nothing has been logged yet.
  final double? currentWeightKg;

  final NutritionPlan? nutrition;
  final TrainingRecommendation? training;
  final double? bmi;

  /// The raw rows behind [currentWeightKg], newest first. Exposed so a
  /// caller that also needs the day-over-day delta (the HOME hub) can derive
  /// it from this list instead of issuing its own `getBodyLogs()` call.
  final List<Map<String, dynamic>> bodyLogs;

  const GoalSnapshot({
    required this.profile,
    required this.currentWeightKg,
    required this.nutrition,
    required this.training,
    required this.bmi,
    required this.bodyLogs,
  });

  bool get isReady => nutrition != null && currentWeightKg != null;
}

/// Reads goal settings and turns them into a calorie target and a training
/// recommendation. One place so Settings and Body can never disagree.
class GoalService {
  GoalService._();
  static final GoalService instance = GoalService._();

  Future<GoalProfile> loadProfile() async {
    final db = DatabaseService.instance;

    final height = double.tryParse(
          await db.getSetting('height_cm', defaultValue: '175.0'),
        ) ??
        175.0;
    final targetWeight = double.tryParse(
          await db.getSetting('target_weight_kg', defaultValue: '0'),
        ) ??
        0.0;
    final age =
        int.tryParse(await db.getSetting('age', defaultValue: '0')) ?? 0;
    final sexKey = await db.getSetting('sex', defaultValue: 'male');
    final activityKey =
        await db.getSetting('activity_level', defaultValue: 'moderate');
    final weeks =
        int.tryParse(await db.getSetting('goal_weeks', defaultValue: '12')) ?? 12;
    final days = int.tryParse(
          await db.getSetting('training_days_per_week', defaultValue: '4'),
        ) ??
        4;

    return GoalProfile(
      heightCm: height,
      targetWeightKg: targetWeight,
      age: age,
      sex: sexKey == 'female' ? Sex.female : Sex.male,
      activity: ActivityLevel.fromKey(activityKey),
      weeks: weeks,
      daysPerWeek: days,
      // Age and target weight are the two the user must supply; without them
      // any calorie number would be invented rather than calculated.
      isConfigured: age > 0 && targetWeight > 0,
    );
  }

  Future<GoalSnapshot> snapshot() async {
    final db = DatabaseService.instance;
    final profile = await loadProfile();

    final bodyRows = await db.getBodyLogs();
    final currentWeight = bodyRows.isEmpty
        ? null
        : (bodyRows.first['weight_kg'] as num).toDouble();

    final bmi = currentWeight == null
        ? null
        : NutritionPlanner.bmiFor(
            weightKg: currentWeight,
            heightCm: profile.heightCm,
          );

    if (!profile.isConfigured || currentWeight == null) {
      return GoalSnapshot(
        profile: profile,
        currentWeightKg: currentWeight,
        nutrition: null,
        training: null,
        bmi: bmi,
        bodyLogs: bodyRows,
      );
    }

    final nutrition = NutritionPlanner.build(
      currentWeightKg: currentWeight,
      targetWeightKg: profile.targetWeightKg,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
      activity: profile.activity,
      weeks: profile.weeks,
    );

    final training = TrainingPlanner.recommend(
      direction: nutrition.direction,
      daysPerWeek: profile.daysPerWeek,
    );

    return GoalSnapshot(
      profile: profile,
      currentWeightKg: currentWeight,
      nutrition: nutrition,
      training: training,
      bmi: bmi,
      bodyLogs: bodyRows,
    );
  }

  /// Day-over-day bodyweight delta from [bodyLogs] rows ordered newest first
  /// (the shape `getBodyLogs()` returns). Null when there is fewer than two
  /// entries to compare.
  ///
  /// A pure function so the sign can be covered by a test with no database:
  /// feed it two rows and check `latest - previous` comes out the right way
  /// round, rather than inverted by an accidental same-day tie.
  static double? weightDeltaKg(List<Map<String, dynamic>> bodyLogs) {
    if (bodyLogs.length < 2) return null;
    final latest = (bodyLogs[0]['weight_kg'] as num).toDouble();
    final previous = (bodyLogs[1]['weight_kg'] as num).toDouble();
    return latest - previous;
  }

  /// Recomputes the plan and writes the calorie target the Food tab reads.
  /// Returns the plan so the caller can report what changed.
  Future<NutritionPlan?> recalculateAndSaveTarget() async {
    final snap = await snapshot();
    final plan = snap.nutrition;
    if (plan == null) return null;

    final db = DatabaseService.instance;
    await db.saveSetting('calorie_target', plan.targetKcal.toString());
    await db.saveSetting('protein_target_g', plan.proteinG.toString());
    await db.saveSetting('carb_target_g', plan.carbG.toString());
    await db.saveSetting('fat_target_g', plan.fatG.toString());
    return plan;
  }
}
