import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/data/exercise_library.dart';
import 'package:lockout/data/food_library.dart';
import 'package:lockout/data/routine_templates.dart';
import 'package:lockout/services/nutrition_planner.dart';
import 'package:lockout/services/training_planner.dart';
import 'package:lockout/theme/app_palette.dart';
import 'package:lockout/widgets/food_picker.dart';

void main() {
  group('AppPalette', () {
    test('ships four light and four dark palettes', () {
      expect(AppPalette.light.length, 4);
      expect(AppPalette.dark.length, 4);
      expect(AppPalette.all.length, 8);
    });

    test('light palettes are light and dark palettes are dark', () {
      for (final p in AppPalette.light) {
        expect(p.isDark, isFalse, reason: p.key);
      }
      for (final p in AppPalette.dark) {
        expect(p.isDark, isTrue, reason: p.key);
      }
    });

    test('palette keys and names are unique', () {
      final keys = AppPalette.all.map((p) => p.key).toList();
      final names = AppPalette.all.map((p) => p.name).toList();
      expect(keys.toSet().length, keys.length);
      expect(names.toSet().length, names.length);
    });

    test('an unknown key falls back rather than throwing', () {
      expect(AppPalette.byKey('does_not_exist').key, AppPalette.fallback.key);
      expect(AppPalette.byKey('carbon_lime').name, 'Carbon Lime');
    });

    test('applying a palette bumps the revision exactly once', () {
      AppPalette.applyKey(AppPalette.fallback.key);
      final before = AppPalette.revision.value;

      AppPalette.apply(AppPalette.voidMagenta);
      expect(AppPalette.revision.value, before + 1);
      expect(AppPalette.current.key, 'void_magenta');

      // Re-applying the same palette must not trigger a needless rebuild.
      AppPalette.apply(AppPalette.voidMagenta);
      expect(AppPalette.revision.value, before + 1);

      AppPalette.apply(AppPalette.fallback);
    });

    test('ink contrasts with canvas in every palette', () {
      for (final p in AppPalette.all) {
        final inkLum = p.ink.computeLuminance();
        final canvasLum = p.canvas.computeLuminance();
        expect((inkLum - canvasLum).abs(), greaterThan(0.4), reason: p.key);
      }
    });

    test('text on primary and accent stays readable', () {
      // Neubrutalism puts label text directly on saturated fills; if onPrimary
      // does not contrast with primary the button becomes unreadable.
      for (final p in AppPalette.all) {
        final primaryGap =
            (p.onPrimary.computeLuminance() - p.primary.computeLuminance())
                .abs();
        final accentGap =
            (p.onAccent.computeLuminance() - p.accent.computeLuminance()).abs();
        expect(primaryGap, greaterThan(0.25), reason: '${p.key} primary');
        expect(accentGap, greaterThan(0.25), reason: '${p.key} accent');
      }
    });
  });

  group('FoodLibrary', () {
    test('catalog is large and spans many cuisines', () {
      expect(FoodLibrary.all.length, greaterThan(300));
      expect(FoodLibrary.categories.length, greaterThanOrEqualTo(20));
    });

    test('every food is well formed and names a category that exists', () {
      for (final f in FoodLibrary.all) {
        expect(f.name.trim(), isNotEmpty, reason: f.name);
        expect(f.serving.trim(), isNotEmpty, reason: f.name);
        expect(f.ingredients.trim(), isNotEmpty, reason: f.name);
        expect(FoodLibrary.categories, contains(f.category), reason: f.name);
        expect(f.kcal, greaterThanOrEqualTo(0), reason: f.name);
        expect(f.proteinG, greaterThanOrEqualTo(0), reason: f.name);
        expect(f.carbG, greaterThanOrEqualTo(0), reason: f.name);
        expect(f.fatG, greaterThanOrEqualTo(0), reason: f.name);
      }
    });

    test('stated calories reconcile with the macro breakdown', () {
      // 4/4/9/7 kcal per gram of protein/carb/fat/alcohol. Alcohol matters:
      // without it a beer's calories cannot be explained by P/C/F at all.
      for (final f in FoodLibrary.all) {
        if (f.kcal == 0) continue;
        expect(
          f.kcalFromMacros,
          closeTo(f.kcal, f.kcal * 0.35 + 25),
          reason: '${f.name}: stated ${f.kcal}, macros ${f.kcalFromMacros}',
        );
      }
    });

    test('alcoholic drinks declare their ethanol', () {
      for (final name in ['Beer', 'Red Wine', 'Spirits (40%)']) {
        final drink = FoodLibrary.findByName(name);
        expect(drink, isNotNull, reason: name);
        expect(drink!.alcoholG, greaterThan(0), reason: name);
      }
    });

    test('food names are unique', () {
      final names = FoodLibrary.all.map((f) => f.name.toLowerCase()).toList();
      expect(names.toSet().length, names.length);
    });

    test('no cuisine dominates the catalog', () {
      // The complaint that prompted this: a catalog that is mostly one cuisine
      // is not a food database, it is a regional list.
      for (final c in FoodLibrary.categories) {
        final share =
            FoodLibrary.byCategory(c).length / FoodLibrary.all.length;
        expect(share, lessThan(0.25), reason: '$c is $share of the catalog');
      }
    });

    test('every major cuisine is represented', () {
      for (final c in [
        'Western',
        'Italian',
        'Chinese',
        'Japanese',
        'Korean',
        'Thai & SE Asian',
        'Mexican',
        'Middle Eastern',
        'Mediterranean',
        'South Asian',
        'Bengali',
      ]) {
        expect(FoodLibrary.byCategory(c).length, greaterThanOrEqualTo(7),
            reason: c);
      }
    });

    test('search matches name, category and ingredients', () {
      expect(FoodLibrary.search('curry'), isNotEmpty);
      expect(FoodLibrary.search('Japanese'), isNotEmpty);
      // Ingredient-only match: no food is named "mascarpone".
      expect(FoodLibrary.search('mascarpone'), isNotEmpty);
      expect(FoodLibrary.findByName('Tiramisu'), isNotNull);
    });
  });

  group('PickedFood scaling', () {
    final roti = FoodLibrary.findByName('Roti / Chapati')!;

    test('a single serving keeps the plain name and figures', () {
      final p = PickedFood.fromLibrary(roti, 1);
      expect(p.name, 'Roti / Chapati');
      expect(p.kcal, roti.kcal);
      expect(p.proteinG, roti.proteinG);
    });

    test('multiple servings scale macros and annotate the name', () {
      final p = PickedFood.fromLibrary(roti, 2);
      expect(p.kcal, roti.kcal * 2);
      expect(p.proteinG, roti.proteinG * 2);
      expect(p.name, contains('2x'));
    });

    test('fractional servings round to one decimal', () {
      final p = PickedFood.fromLibrary(roti, 0.5);
      expect(p.kcal, (roti.kcal * 0.5).round());
      expect(p.proteinG.toString().split('.').last.length, lessThanOrEqualTo(1));
    });

    test('a custom entry starts zeroed for the user to fill in', () {
      final p = PickedFood.custom('Nani Home Cooking');
      expect(p.name, 'Nani Home Cooking');
      expect(p.kcal, 0);
    });
  });

  group('NutritionPlanner', () {
    test('BMR follows Mifflin-St Jeor for both sexes', () {
      // 80kg, 180cm, 30y male -> 10*80 + 6.25*180 - 5*30 + 5 = 1780
      expect(
        NutritionPlanner.bmr(
            weightKg: 80, heightCm: 180, age: 30, sex: Sex.male),
        closeTo(1780, 0.5),
      );
      // Same body, female -> ...- 161 = 1614
      expect(
        NutritionPlanner.bmr(
            weightKg: 80, heightCm: 180, age: 30, sex: Sex.female),
        closeTo(1614, 0.5),
      );
    });

    test('a cut produces a deficit below TDEE', () {
      final plan = NutritionPlanner.build(
        currentWeightKg: 85,
        targetWeightKg: 78,
        heightCm: 178,
        age: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        weeks: 16,
      );
      expect(plan.direction, GoalDirection.cut);
      expect(plan.dailyDeltaKcal, lessThan(0));
      expect(plan.targetKcal, lessThan(plan.tdee));
    });

    test('a gain produces a surplus above TDEE', () {
      final plan = NutritionPlanner.build(
        currentWeightKg: 65,
        targetWeightKg: 70,
        heightCm: 178,
        age: 25,
        sex: Sex.male,
        activity: ActivityLevel.high,
        weeks: 20,
      );
      expect(plan.direction, GoalDirection.gain);
      expect(plan.dailyDeltaKcal, greaterThan(0));
      expect(plan.targetKcal, greaterThan(plan.tdee));
    });

    test('an equal target is treated as maintenance', () {
      final plan = NutritionPlanner.build(
        currentWeightKg: 75,
        targetWeightKg: 75,
        heightCm: 175,
        age: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        weeks: 12,
      );
      expect(plan.direction, GoalDirection.maintain);
      expect(plan.targetKcal, closeTo(plan.tdee, 5));
    });

    test('an unsafe crash-diet pace is clamped and explained', () {
      // 20kg in 4 weeks is 5kg/week — far beyond any safe rate.
      final plan = NutritionPlanner.build(
        currentWeightKg: 95,
        targetWeightKg: 75,
        heightCm: 175,
        age: 30,
        sex: Sex.male,
        activity: ActivityLevel.sedentary,
        weeks: 4,
      );
      expect(plan.wasClamped, isTrue);
      expect(plan.warning, isNotNull);
      expect(plan.weeklyRatePct,
          lessThanOrEqualTo(NutritionPlanner.maxLossRatePct + 0.001));
    });

    test('the target never drops below the safe intake floor', () {
      final plan = NutritionPlanner.build(
        currentWeightKg: 55,
        targetWeightKg: 45,
        heightCm: 160,
        age: 40,
        sex: Sex.female,
        activity: ActivityLevel.sedentary,
        weeks: 6,
      );
      expect(plan.targetKcal,
          greaterThanOrEqualTo(NutritionPlanner.minFemaleKcal));
    });

    test('gain is capped tighter than loss', () {
      expect(NutritionPlanner.maxGainRatePct,
          lessThan(NutritionPlanner.maxLossRatePct));
    });

    test('protein is prioritised in a cut', () {
      final cut = NutritionPlanner.build(
        currentWeightKg: 80,
        targetWeightKg: 74,
        heightCm: 178,
        age: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        weeks: 14,
      );
      // 2.2 g/kg in a deficit.
      expect(cut.proteinG, closeTo(80 * 2.2, 1));
      expect(cut.carbG, greaterThanOrEqualTo(0));
    });

    test('macros roughly reconstruct the calorie target', () {
      final plan = NutritionPlanner.build(
        currentWeightKg: 80,
        targetWeightKg: 74,
        heightCm: 178,
        age: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        weeks: 14,
      );
      final fromMacros = plan.proteinG * 4 + plan.carbG * 4 + plan.fatG * 9;
      expect(fromMacros, closeTo(plan.targetKcal, 30));
    });

    test('BMI uses weight and height only', () {
      final bmi = NutritionPlanner.bmiFor(weightKg: 78.8, heightCm: 175.26);
      expect(bmi, isNotNull);
      expect(bmi!, closeTo(25.65, 0.05));
    });

    test('healthy weight range brackets a normal BMI', () {
      final (low, high) = NutritionPlanner.healthyWeightRangeKg(178);
      expect(low, closeTo(58.6, 0.5));
      expect(high, closeTo(78.9, 0.5));
    });

    test('activity multipliers increase monotonically', () {
      final values = ActivityLevel.values.map((a) => a.multiplier).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });
  });

  group('TrainingPlanner', () {
    test('low frequency gets full body, high frequency gets a split', () {
      expect(
        TrainingPlanner.recommend(
                direction: GoalDirection.cut, daysPerWeek: 3)
            .template
            .key,
        'full_body',
      );
      expect(
        TrainingPlanner.recommend(
                direction: GoalDirection.gain, daysPerWeek: 4)
            .template
            .key,
        'upper_lower',
      );
      expect(
        TrainingPlanner.recommend(
                direction: GoalDirection.gain, daysPerWeek: 6)
            .template
            .key,
        'ppl',
      );
    });

    test('out-of-range day counts are clamped, not rejected', () {
      expect(
          TrainingPlanner.recommend(
                  direction: GoalDirection.maintain, daysPerWeek: 0)
              .daysPerWeek,
          2);
      expect(
          TrainingPlanner.recommend(
                  direction: GoalDirection.maintain, daysPerWeek: 99)
              .daysPerWeek,
          6);
    });

    test('advice differs by goal direction', () {
      final cut = TrainingPlanner.recommend(
          direction: GoalDirection.cut, daysPerWeek: 4);
      final gain = TrainingPlanner.recommend(
          direction: GoalDirection.gain, daysPerWeek: 4);
      expect(cut.cardioAdvice, isNot(equals(gain.cardioAdvice)));
      expect(cut.loadingAdvice, isNot(equals(gain.loadingAdvice)));
    });

    test('every recommendation carries a rationale', () {
      for (var d = 2; d <= 6; d++) {
        final rec = TrainingPlanner.recommend(
            direction: GoalDirection.maintain, daysPerWeek: d);
        expect(rec.rationale.trim(), isNotEmpty, reason: '$d days');
      }
    });
  });

  group('RoutineTemplate', () {
    test('every template day references real catalog exercises', () {
      for (final t in RoutineTemplate.all) {
        for (final d in t.days) {
          expect(d.exercises, isNotEmpty, reason: '${t.key}/${d.name}');
          for (final name in d.exercises) {
            expect(
              ExerciseLibrary.findByName(name),
              isNotNull,
              reason: '${t.key}/${d.name}: "$name" is not in the catalog',
            );
          }
        }
      }
    });

    test('non-blank templates ship warm-ups, focus and finishers', () {
      for (final t in RoutineTemplate.all.where((t) => t.key != 'blank')) {
        for (final d in t.days) {
          expect(d.focus.trim(), isNotEmpty, reason: '${t.key}/${d.name}');
          expect(d.warmups, isNotEmpty, reason: '${t.key}/${d.name}');
          expect(d.finishers, isNotEmpty, reason: '${t.key}/${d.name}');
        }
      }
    });

    test('weekday tags are valid and unique inside a template', () {
      const valid = ['SAT', 'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI'];
      for (final t in RoutineTemplate.all) {
        final tags = t.days.map((d) => d.tag).toList();
        for (final tag in tags) {
          expect(valid, contains(tag), reason: t.key);
        }
        expect(tags.toSet().length, tags.length,
            reason: '${t.key} schedules two days on one weekday');
      }
    });

    test('a blank template is offered first', () {
      expect(RoutineTemplate.all.first.key, 'blank');
      expect(RoutineTemplate.all.first.days, isEmpty);
    });

    test('templates recommended by the planner all exist', () {
      for (var d = 2; d <= 6; d++) {
        final rec = TrainingPlanner.recommend(
            direction: GoalDirection.maintain, daysPerWeek: d);
        expect(RoutineTemplate.all.map((t) => t.key), contains(rec.template.key));
        expect(rec.template.days, isNotEmpty);
      }
    });
  });

  group('Backup document shape', () {
    Map<String, dynamic> validDoc() => {
          'app': 'lockout',
          'schemaVersion': 2,
          'exportedAt': DateTime.now().toIso8601String(),
          'appVersion': '1.1.0',
          'data': {
            'routines': [
              {'id': 'r1', 'name': 'PPL', 'scheduling_mode': 'WEEKDAY'},
            ],
          },
        };

    test('a well formed document round-trips through JSON', () {
      final decoded = jsonDecode(jsonEncode(validDoc()));
      expect(decoded['app'], 'lockout');
      expect(decoded['data']['routines'], isA<List>());
    });

    test('a newer schema version is detectable before any write', () {
      final doc = validDoc()..['schemaVersion'] = 99;
      expect((doc['schemaVersion'] as int) > 2, isTrue);
    });
  });
}
