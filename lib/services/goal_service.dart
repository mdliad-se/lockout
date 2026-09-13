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
  /// caller that also needs the delta since the previous weigh-in (the HOME
  /// hub) can derive it from this list instead of issuing its own
  /// `getBodyLogs()` call.
  final List<Map<String, dynamic>> bodyLogs;

  /// The one calorie number every screen must display — resolved here so
  /// FOOD and HOME can never disagree (Ruling A). The calculated [nutrition]
  /// plan wins when one exists; otherwise the user's editable
  /// `calorie_target` override from Settings; `DatabaseService
  /// .defaultCalorieTarget` only when neither has ever been set. That seed
  /// row means this is effectively never null on a real device — see the
  /// doc on `HomeHubSummary.kcalTarget` for the consequence.
  final int calorieTarget;

  const GoalSnapshot({
    required this.profile,
    required this.currentWeightKg,
    required this.nutrition,
    required this.training,
    required this.bmi,
    required this.bodyLogs,
    required this.calorieTarget,
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

    // Clamped on read, not only on write. Settings' write-side guard cannot
    // see either realistic vector for a poisoned row:
    // `BackupService.importFromJson` validates the app tag and schema version
    // and then writes `user_settings` rows verbatim, so a hand-edited or
    // older-build backup restores `target_weight_kg = 'Infinity'` straight
    // past it — as does any row a build predating that guard already wrote.
    // `double.tryParse` accepts 'Infinity' and 'NaN', and a non-finite value
    // reaching `NutritionPlanner.build` throws `Unsupported operation:
    // Infinity or NaN toInt`. Every caller of `snapshot()` — BODY, FOOD,
    // TODAY and Settings — then fails to load rather than merely showing a
    // silly number. Clamping here closes the UI, import and legacy-row paths
    // at once, including the value Settings echoes back into its own field.
    final height = _finiteOr(
      double.tryParse(await db.getSetting('height_cm', defaultValue: '175.0')),
      fallback: 175.0,
      floor: 0.0,
      floorExclusive: true,
    );
    final targetWeight = _finiteOr(
      double.tryParse(
        await db.getSetting('target_weight_kg', defaultValue: '0'),
      ),
      fallback: 0.0,
      floor: 0.0,
    );
    // `int.tryParse` cannot produce a non-finite value, but it happily parses
    // a negative one, and a negative age drags the BMR equation with it.
    final rawAge =
        int.tryParse(await db.getSetting('age', defaultValue: '0')) ?? 0;
    final age = rawAge > 0 ? rawAge : 0;
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

  /// [value] when it is a usable number, [fallback] otherwise.
  ///
  /// "Usable" is non-null, finite, and at or above [floor] — strictly above it
  /// when [floorExclusive], which is how height rejects a stored `0` that
  /// would divide BMI by zero while target weight keeps `0` as its legitimate
  /// "not set yet" value.
  static double _finiteOr(
    double? value, {
    required double fallback,
    required double floor,
    bool floorExclusive = false,
  }) {
    if (value == null || !value.isFinite) return fallback;
    if (floorExclusive ? value <= floor : value < floor) return fallback;
    return value;
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

    NutritionPlan? nutrition;
    TrainingRecommendation? training;
    if (profile.isConfigured && currentWeight != null) {
      nutrition = NutritionPlanner.build(
        currentWeightKg: currentWeight,
        targetWeightKg: profile.targetWeightKg,
        heightCm: profile.heightCm,
        age: profile.age,
        sex: profile.sex,
        activity: profile.activity,
        weeks: profile.weeks,
      );

      training = TrainingPlanner.recommend(
        direction: nutrition.direction,
        daysPerWeek: profile.daysPerWeek,
      );
    }

    final calorieTarget = await _resolveCalorieTarget(nutrition);

    return GoalSnapshot(
      profile: profile,
      currentWeightKg: currentWeight,
      nutrition: nutrition,
      training: training,
      bmi: bmi,
      bodyLogs: bodyRows,
      calorieTarget: calorieTarget,
    );
  }

  /// Ruling A's resolution order, on its own so it can be reused wherever a
  /// snapshot is not already in hand.
  Future<int> _resolveCalorieTarget(NutritionPlan? plan) async {
    if (plan != null) return plan.targetKcal;
    final db = DatabaseService.instance;
    final stored = await db.getSetting(
      'calorie_target',
      defaultValue: '${DatabaseService.defaultCalorieTarget}',
    );
    return int.tryParse(stored) ?? DatabaseService.defaultCalorieTarget;
  }

  /// Bodyweight delta since the previous weigh-in, from [bodyLogs] rows
  /// ordered newest first (the shape `getBodyLogs()` returns) — not
  /// necessarily "yesterday": `getBodyLogs()` orders same-day entries
  /// deterministically (see its doc), so two weigh-ins logged hours apart on
  /// the same calendar day compare against each other too. Null when there
  /// are fewer than two entries to compare.
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
