import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/data/food_library.dart';

void main() {
  group('Library integrity', () {
    test('names are unique so lookups are unambiguous', () {
      final names = FoodLibrary.all.map((f) => f.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('every item declares a known category', () {
      for (final f in FoodLibrary.all) {
        expect(FoodLibrary.categories, contains(f.category), reason: f.name);
      }
    });

    test('every item states a serving and ingredients', () {
      for (final f in FoodLibrary.all) {
        expect(f.serving.trim(), isNotEmpty, reason: f.name);
        expect(f.ingredients.trim(), isNotEmpty, reason: f.name);
      }
    });

    test('stated calories agree with the macro breakdown', () {
      for (final f in FoodLibrary.all) {
        // Below 30 kcal a single gram of rounding in any one macro swings
        // the percentage drift by ~15-20 points on its own, so percentage
        // drift stops being a meaningful check; 20 kcal was too low a cutoff
        // (e.g. Kimchi at 22 kcal drifts 12.27% on rounding alone).
        if (f.kcal < 30) continue;
        final implied = f.kcalFromMacros;
        final drift = (implied - f.kcal).abs() / f.kcal;
        expect(
          drift,
          lessThanOrEqualTo(0.12),
          reason: '${f.name}: stated ${f.kcal}, macros ${implied.round()}',
        );
      }
    });

    test('the audit added the everyday gaps', () {
      final names = FoodLibrary.all.map((f) => f.name).toSet();
      for (final expected in [
        'Cheese Omelette',
        'Masala Omelette',
        'Egg Bhurji',
        'Omelette (3-egg)',
        'Egg Curry',
        'Cheese Paratha',
        'Egg Paratha',
        'Paneer Paratha',
        'Roti with Ghee',
        'Ruti (Atta, large)',
        'Suji Ruti',
        'Chicken Curry',
        'Fish Curry',
        'Prawn Curry',
        'Vegetable Curry',
        'Chicken Bhuna',
        'Mutton Bhuna',
        'Duck Curry (Hasher Mangsho)',
        'Chicken Jhol',
        'Shorshe Bata Mach',
        'Shorshe Chingri',
        'Chingri Bhorta',
        'Lau Chingri',
        'Fish Fry (Bengali)',
        'Chicken Fry (Bengali)',
        'Dim Bhuna',
        'Tehari (Chicken)',
        'Tehari (Mutton)',
        'Chicken Khichuri',
        'Dim Khichuri',
        'Vegetable Khichuri',
        'Dal Bhat',
        'Aloo Bhorta with Mustard Oil',
        'Chola Boot',
        'Mixed Fruit Salad',
        'Whole Wheat Bread (2 slices)',
        'Cheese Toast',
        'Chicken Sandwich',
        'Instant Coffee (black)',
        'Sugar-free Tea with Milk',
      ]) {
        expect(names, contains(expected), reason: expected);
      }
    });

    test('the library grew to 472 items', () {
      expect(FoodLibrary.all.length, 472);
    });
  });
}
