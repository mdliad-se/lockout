import 'package:flutter_test/flutter_test.dart';
import 'package:lockout/data/exercise_library.dart';
import 'package:lockout/data/food_library.dart';
import 'package:lockout/data/food_search.dart';

List<String> _names(String query) =>
    searchFoods(query).map((h) => h.item.name).toList();

void main() {
  group('normalise and tokenise', () {
    test('folds case, punctuation and repeated whitespace', () {
      expect(TextSearch.normalise('  Roti / Chapati  '), 'roti chapati');
      expect(TextSearch.normalise('Chicken Curry (Bengali)'),
          'chicken curry bengali');
      expect(TextSearch.normalise("Shepherd's Pie"), 'shepherd s pie');
    });

    test('tokenise drops empties', () {
      expect(TextSearch.tokenise('Beef  Curry '), ['beef', 'curry']);
      expect(TextSearch.tokenise('   '), isEmpty);
    });
  });

  group('editDistance', () {
    test('counts substitutions, insertions and deletions', () {
      expect(TextSearch.editDistance('roti', 'roti'), 0);
      expect(TextSearch.editDistance('ruti', 'roti'), 1);
      expect(TextSearch.editDistance('chiken', 'chicken'), 1);
      expect(TextSearch.editDistance('cury', 'curry'), 1);
      expect(TextSearch.editDistance('parata', 'paratha'), 1);
    });

    test('counts a transposition as one edit', () {
      expect(TextSearch.editDistance('omlette', 'omelette'), 1);
      expect(TextSearch.editDistance('beff', 'beef'), 1);
    });
  });

  group('fuzzyTokenMatch', () {
    test('short tokens must be exact', () {
      expect(TextSearch.fuzzyTokenMatch('egg', 'egg'), isTrue);
      expect(TextSearch.fuzzyTokenMatch('egg', 'ego'), isFalse);
    });

    test('medium tokens tolerate one edit', () {
      expect(TextSearch.fuzzyTokenMatch('ruti', 'roti'), isTrue);
      expect(TextSearch.fuzzyTokenMatch('rice', 'ruti'), isFalse);
    });

    test('long tokens tolerate two edits', () {
      expect(TextSearch.fuzzyTokenMatch('omlete', 'omelette'), isTrue);
      expect(TextSearch.fuzzyTokenMatch('chikn', 'chicken'), isTrue);
    });
  });

  group('the reported queries now find their dishes', () {
    test('omlet finds the omelettes', () {
      final names = _names('omlet');
      expect(names, contains('Plain Omelette'));
      expect(names, contains('Dim Bhaji (Bengali Omelette)'));
    });

    test('ruti finds roti', () {
      expect(_names('ruti'), contains('Roti / Chapati'));
    });

    test('porota finds paratha', () {
      expect(_names('porota'), contains('Paratha'));
    });

    test('murgir finds the chicken dishes', () {
      final names = _names('murgir mangsho');
      expect(names, contains('Chicken Curry (Bengali)'));
    });

    test('beef cury finds beef curry despite the typo', () {
      expect(_names('beef cury'), contains('Beef Curry (Bengali)'));
    });

    test('macher jhol finds the fish curries', () {
      final names = _names('macher jhol');
      expect(names, contains('Rui Macher Jhol (Rohu Curry)'));
    });

    test('parata finds paratha despite the typo', () {
      expect(_names('parata'), contains('Paratha'));
    });

    test('yoghurt and yogurt are the same query', () {
      expect(_names('yoghurt'), isNotEmpty);
      expect(_names('yoghurt').first, _names('yogurt').first);
    });
  });

  group('the generic "meat" alias does not excuse other tokens', () {
    test('mangsho salad returns no vegetarian salad', () {
      final names = _names('mangsho salad');
      expect(names, isNot(contains('Green Salad (undressed)')));
      expect(names, isNot(contains('Som Tam (Papaya Salad)')));
      expect(names, isNot(contains('Greek Salad')));
    });

    test('mangsho curry returns no bean, fish, prawn or egg dish', () {
      final names = _names('mangsho curry');
      expect(names, isNot(contains('Rajma (Kidney Bean Curry)')));
      expect(names, isNot(contains('Rui Macher Jhol (Rohu Curry)')));
      expect(names, isNot(contains('Chingri Malai Curry')));
      expect(names, isNot(contains('Dim Bhuna (Egg Curry)')));
    });

    test('murgir mangsho still finds Chicken Curry (Bengali)', () {
      expect(_names('murgir mangsho'), contains('Chicken Curry (Bengali)'));
    });

    test('beef mangsho finds beef dishes', () {
      expect(_names('beef mangsho'), contains('Beef Curry (Bengali)'));
    });

    test('mangsho alone returns meat and no vegetarian dishes', () {
      final names = _names('mangsho');
      expect(names, isNot(contains('Green Salad (undressed)')));
      expect(names, isNotEmpty);
    });
  });

  group('ranking', () {
    test('an exact name wins', () {
      expect(_names('Paratha').first, 'Paratha');
    });

    test('a name prefix beats an ingredient mention', () {
      final hits = searchFoods('chicken curry');
      expect(hits.first.item.name.toLowerCase(), startsWith('chicken curry'));
    });

    test('a name match outranks a category match', () {
      final hits = searchFoods('bengali');
      expect(hits, isNotEmpty);
      // Every Bengali-category item is reachable, and nothing outranks a
      // literal name hit.
      expect(hits.first.rank, lessThanOrEqualTo(hits.last.rank));
    });

    test('hits come back sorted by rank', () {
      final ranks = searchFoods('curry').map((h) => h.rank).toList();
      final sorted = [...ranks]..sort();
      expect(ranks, sorted);
    });

    test('an alias or fuzzy hit says how it matched', () {
      final hit = searchFoods('ruti').first;
      expect(hit.matchedVia, isNotNull);
      expect(hit.matchedVia, contains('ruti'));
    });

    test('an exact hit needs no explanation', () {
      expect(searchFoods('Paratha').first.matchedVia, isNull);
    });
  });

  group('degenerate queries', () {
    test('an empty query returns the whole library in order', () {
      expect(searchFoods('').length, FoodLibrary.all.length);
      expect(searchFoods('   ').first.item.name, FoodLibrary.all.first.name);
    });

    test('a query matching nothing returns nothing', () {
      expect(searchFoods('zzzzqqqq'), isEmpty);
    });
  });

  group('FoodLibrary.search delegates', () {
    test('it returns the ranked items', () {
      expect(FoodLibrary.search('ruti').map((f) => f.name),
          contains('Roti / Chapati'));
    });
  });

  group('exercise search shares the pipeline', () {
    test('a misspelling still finds the exercise', () {
      final names =
          searchExercises('bench pres').map((h) => h.item.name).toList();
      expect(names.any((n) => n.contains('Bench Press')), isTrue);
    });

    test('ExerciseLibrary.search delegates', () {
      expect(ExerciseLibrary.search('deadlift'), isNotEmpty);
    });
  });
}
