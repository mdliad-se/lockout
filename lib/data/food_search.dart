import 'dart:math' as math;

import 'exercise_library.dart';
import 'food_library.dart';

/// One result, with why it matched.
///
/// [rank] is a small integer where lower is better, so callers sort rather
/// than score. [matchedVia] is set only when the match was not literal — an
/// alias or a corrected typo — so the UI can explain a surprising hit
/// instead of leaving the user to wonder.
class SearchHit<T> {
  final T item;
  final int rank;
  final String? matchedVia;

  const SearchHit({required this.item, required this.rank, this.matchedVia});
}

/// Normalising, alias-aware, typo-tolerant text matching.
///
/// The substring test this replaces could not find items the library already
/// held: a user typing `ruti` or `omlet` got an empty list and reasonably
/// concluded the food was missing.
class TextSearch {
  TextSearch._();

  /// Transliteration and synonym pairs, mapping what a user types to the
  /// token the library actually uses. Bengali/Hindi romanisation varies by
  /// person, so both the common spellings and the English word are accepted.
  static const Map<String, String> aliases = {
    // breads
    'ruti': 'roti',
    'rooti': 'roti',
    'rooty': 'roti',
    'porota': 'paratha',
    'parotha': 'paratha',
    'porata': 'paratha',
    'luchee': 'luchi',
    'nan': 'naan',
    // eggs
    'omlet': 'omelette',
    'omlette': 'omelette',
    'omelet': 'omelette',
    'omelete': 'omelette',
    'dim': 'egg',
    'deem': 'egg',
    // meat
    'murgi': 'chicken',
    'murgir': 'chicken',
    'murog': 'chicken',
    'morog': 'chicken',
    'murgh': 'chicken',
    'gorur': 'beef',
    'goru': 'beef',
    'khashi': 'mutton',
    'khasi': 'mutton',
    'hasher': 'duck',
    'mangsho': 'meat',
    'mangso': 'meat',
    // fish and seafood
    'mach': 'fish',
    'machh': 'fish',
    'maach': 'fish',
    'macher': 'fish',
    'machher': 'fish',
    'machh er': 'fish',
    'chingri': 'prawn',
    'shrimp': 'prawn',
    'ilish': 'hilsa',
    'rui': 'rohu',
    'shutki': 'dried fish',
    // staples
    'bhat': 'rice',
    'polao': 'pulao',
    'pulao': 'pulao',
    'khichdi': 'khichuri',
    'khichri': 'khichuri',
    'daal': 'dal',
    'dhal': 'dal',
    'chola': 'chickpeas',
    'chhola': 'chickpeas',
    // dishes and preparations
    'jhol': 'curry',
    'jhal': 'curry',
    'torkari': 'vegetable',
    'tarkari': 'vegetable',
    'bhorta': 'bhorta',
    'vorta': 'bhorta',
    'bhaji': 'bhaji',
    'vaji': 'bhaji',
    'misti': 'sweet',
    'mishti': 'sweet',
    'doi': 'yogurt',
    // British / US spelling pairs
    'yoghurt': 'yogurt',
    'aubergine': 'aubergine',
    'eggplant': 'aubergine',
    'courgette': 'courgette',
    'zucchini': 'courgette',
    'chips': 'chips',
    'fries': 'chips',
    'coriander': 'coriander',
    'cilantro': 'coriander',
    'chickpea': 'chickpeas',
    'garbanzo': 'chickpeas',
  };

  /// Lowercase, fold diacritics, punctuation to spaces, collapse whitespace.
  static String normalise(String input) {
    final lower = input.toLowerCase();
    final folded = StringBuffer();
    for (final ch in lower.split('')) {
      folded.write(_diacritics[ch] ?? ch);
    }
    final cleaned = folded
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  static const Map<String, String> _diacritics = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  static List<String> tokenise(String input) {
    final n = normalise(input);
    if (n.isEmpty) return const [];
    return n.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Replaces every token that has an alias with its canonical form.
  static List<String> canonicalise(List<String> tokens) =>
      tokens.map((t) => aliases[t] ?? t).toList();

  /// Alias targets generic enough to be redundant once a more specific query
  /// token is present — e.g. Bengali "mangsho" ("meat") tacked onto a named
  /// protein like "murgir" ("chicken"). See `_score`'s alias/fuzzy bands.
  static const Set<String> _genericAliasTargets = {'meat'};

  /// Damerau–Levenshtein distance. A transposition counts as one edit, which
  /// matters because most real misspellings are transpositions.
  static int editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final rows = a.length + 1;
    final cols = b.length + 1;
    final d = List.generate(rows, (_) => List<int>.filled(cols, 0));

    for (var i = 0; i < rows; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j < cols; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var best = math.min(
          d[i - 1][j] + 1,
          math.min(d[i][j - 1] + 1, d[i - 1][j - 1] + cost),
        );
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1]) {
          best = math.min(best, d[i - 2][j - 2] + 1);
        }
        d[i][j] = best;
      }
    }

    return d[a.length][b.length];
  }

  /// Tolerance scales with length: a three-letter word has no room for a typo
  /// without becoming a different word, a long one has plenty.
  static bool fuzzyTokenMatch(String queryToken, String candidateToken) {
    if (queryToken == candidateToken) return true;
    if (candidateToken.startsWith(queryToken) && queryToken.length >= 4) {
      return true;
    }

    final len = math.max(queryToken.length, candidateToken.length);
    final allowed = len <= 3
        ? 0
        : len <= 6
            ? 1
            : 2;
    if (allowed == 0) return false;
    return editDistance(queryToken, candidateToken) <= allowed;
  }
}

/// Rank bands. Lower is better; the gaps leave room to insert a band later
/// without renumbering the ones around it.
class _Rank {
  static const exactName = 0;
  static const namePrefix = 10;
  static const allTokensInName = 20;
  static const aliasName = 30;
  static const fuzzyName = 40;
  static const category = 50;
  static const ingredients = 60;
}

/// Scores one candidate against a query. Returns null when nothing matched.
///
/// Shared by foods and exercises so the two pickers cannot drift apart: the
/// exercise picker had the identical substring limitation.
SearchHit<T>? _score<T>({
  required T item,
  required String name,
  required List<String> secondary,
  required String rawQuery,
  required List<String> queryTokens,
  required List<String> canonicalQuery,
}) {
  final normName = TextSearch.normalise(name);
  final nameTokens = TextSearch.tokenise(name);
  final canonicalName = TextSearch.canonicalise(nameTokens);
  final normQuery = TextSearch.normalise(rawQuery);

  if (normName == normQuery) {
    return SearchHit(item: item, rank: _Rank.exactName);
  }
  if (normName.startsWith(normQuery)) {
    return SearchHit(item: item, rank: _Rank.namePrefix);
  }
  if (queryTokens.every((q) => normName.contains(q))) {
    return SearchHit(item: item, rank: _Rank.allTokensInName);
  }

  // Alias/fuzzy bands require every *significant* canonical query token to
  // have a home in the name. A generic alias target such as "meat" (from
  // Bengali "mangsho") is filler once a specific protein is already named —
  // "murgir mangsho" (chicken meat) should not fail to find "Chicken Curry"
  // just because no field literally says "meat". Dropping generic tokens
  // only kicks in when another, more specific token is present, so a query
  // of "meat" alone still needs to match something on its own.
  final significantQuery = canonicalQuery.length > 1
      ? canonicalQuery
          .where((q) => !TextSearch._genericAliasTargets.contains(q))
          .toList()
      : canonicalQuery;
  final tokensToMatch = significantQuery.isEmpty ? canonicalQuery : significantQuery;

  // Alias band: the query means the same thing as the name once both sides
  // are canonicalised. This is what makes "ruti" find "Roti / Chapati".
  final aliasMatched = tokensToMatch.every(
    (q) => canonicalName.any((n) => n == q) || normName.contains(q),
  );
  if (aliasMatched) {
    return SearchHit(
      item: item,
      rank: _Rank.aliasName,
      matchedVia: rawQuery.trim(),
    );
  }

  // Fuzzy band: every query token is within edit distance of some name token.
  final fuzzyMatched = tokensToMatch.every(
    (q) => canonicalName.any((n) => TextSearch.fuzzyTokenMatch(q, n)),
  );
  if (fuzzyMatched) {
    return SearchHit(
      item: item,
      rank: _Rank.fuzzyName,
      matchedVia: rawQuery.trim(),
    );
  }

  // Secondary fields, in the order they were passed: category before
  // ingredients, so "bengali" surfaces the cuisine rather than every dish
  // that happens to mention it.
  for (var i = 0; i < secondary.length; i++) {
    final normField = TextSearch.normalise(secondary[i]);
    if (queryTokens.every((q) => normField.contains(q))) {
      return SearchHit(
        item: item,
        rank: i == 0 ? _Rank.category : _Rank.ingredients,
      );
    }
  }

  return null;
}

List<SearchHit<T>> _rank<T>(List<SearchHit<T>> hits) {
  // A stable sort keeps the library's own order inside a band, so staples
  // stay above obscure items.
  final indexed = hits.asMap().entries.toList();
  indexed.sort((a, b) {
    final byRank = a.value.rank.compareTo(b.value.rank);
    return byRank != 0 ? byRank : a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

/// Ranked food search. An empty query returns the whole library in order.
List<SearchHit<LibraryFood>> searchFoods(
  String query, {
  List<LibraryFood>? source,
}) {
  final items = source ?? FoodLibrary.all;
  final tokens = TextSearch.tokenise(query);

  if (tokens.isEmpty) {
    return items
        .map((f) => SearchHit(item: f, rank: _Rank.exactName))
        .toList();
  }

  final canonical = TextSearch.canonicalise(tokens);
  final hits = <SearchHit<LibraryFood>>[];

  for (final food in items) {
    final hit = _score<LibraryFood>(
      item: food,
      name: food.name,
      secondary: [food.category, food.ingredients],
      rawQuery: query,
      queryTokens: tokens,
      canonicalQuery: canonical,
    );
    if (hit != null) hits.add(hit);
  }

  return _rank(hits);
}

/// Ranked exercise search, same pipeline as [searchFoods].
List<SearchHit<LibraryExercise>> searchExercises(
  String query, {
  List<LibraryExercise>? source,
}) {
  final items = source ?? ExerciseLibrary.all;
  final tokens = TextSearch.tokenise(query);

  if (tokens.isEmpty) {
    return items
        .map((e) => SearchHit(item: e, rank: _Rank.exactName))
        .toList();
  }

  final canonical = TextSearch.canonicalise(tokens);
  final hits = <SearchHit<LibraryExercise>>[];

  for (final ex in items) {
    final hit = _score<LibraryExercise>(
      item: ex,
      name: ex.name,
      secondary: [ex.muscleGroup, ex.equipment],
      rawQuery: query,
      queryTokens: tokens,
      canonicalQuery: canonical,
    );
    if (hit != null) hits.add(hit);
  }

  return _rank(hits);
}
