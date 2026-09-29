import 'package:flutter/material.dart';
import '../data/food_library.dart';
import '../data/food_search.dart';
import '../theme/lockout_theme.dart';
import 'lockout_card.dart';
import 'sheet_scaffold.dart';

/// Result of the food picker. [servings] scales the catalog entry's macros;
/// a custom entry comes back with zeroed macros for the user to fill in.
class PickedFood {
  final String name;
  final int kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  const PickedFood({
    required this.name,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
  });

  factory PickedFood.fromLibrary(LibraryFood f, double servings) => PickedFood(
        name: servings == 1
            ? f.name
            : '${f.name} (${_trim(servings)}x ${f.serving})',
        kcal: (f.kcal * servings).round(),
        proteinG: _round1(f.proteinG * servings),
        carbG: _round1(f.carbG * servings),
        fatG: _round1(f.fatG * servings),
      );

  factory PickedFood.custom(String name) =>
      PickedFood(name: name, kcal: 0, proteinG: 0, carbG: 0, fatG: 0);

  static double _round1(double v) => double.parse(v.toStringAsFixed(1));

  static String _trim(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

Future<PickedFood?> showFoodPicker(BuildContext context) {
  return showLockoutRawSheet<PickedFood>(
    context: context,
    builder: (_) => _FoodPickerSheet(),
  );
}

class _FoodPickerSheet extends StatefulWidget {
  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  _FoodPickerSheet();

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Ranked, alias-aware search. The match notes (why a surprising row is in
  /// the list) are returned alongside the list rather than stashed on a
  /// field, so this stays a pure read with no build-time side effect.
  ({List<LibraryFood> items, Map<String, String> matchNotes}) get _results {
    var list = _category == 'All'
        ? FoodLibrary.all
        : FoodLibrary.byCategory(_category);
    if (_query.trim().isEmpty) {
      return (items: list, matchNotes: const {});
    }
    final hits = searchFoods(_query, source: list);
    final notes = <String, String>{};
    for (final h in hits) {
      if (h.matchedVia != null) notes[h.item.name] = h.matchedVia!;
    }
    return (items: hits.map((h) => h.item).toList(), matchNotes: notes);
  }

  bool get _canAddCustom =>
      _query.trim().isNotEmpty && FoodLibrary.findByName(_query) == null;

  /// Serving-size step before the item is logged, so "2 rotis" is one entry.
  Future<void> _pickServings(LibraryFood food) async {
    final result = await showLockoutRawSheet<PickedFood>(
      context: context,
      builder: (_) => _ServingsSheet(food: food),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:items, :matchNotes) = _results;
    final results = items;
    final cats = ['All', ...FoodLibrary.categories];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LockoutTheme.screenPadding,
                LockoutTheme.spaceSm,
                LockoutTheme.screenPadding,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pick food', style: theme.textTheme.titleLarge),
                  Text('${results.length} found',
                      style: theme.textTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: LockoutTheme.screenPadding),
              child: TextField(
                controller: _searchCtrl,
                style: theme.textTheme.bodyLarge,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search dish, cuisine or ingredient...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close,
                              semanticLabel: 'Clear search'),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),

            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: LockoutTheme.screenPadding),
                itemCount: cats.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: LockoutTheme.spaceSm),
                itemBuilder: (_, i) {
                  final c = cats[i];
                  return ChoiceChip(
                    label: Text(c),
                    selected: c == _category,
                    onSelected: (_) => setState(() => _category = c),
                  );
                },
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),

            if (_canAddCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LockoutTheme.screenPadding,
                  0,
                  LockoutTheme.screenPadding,
                  LockoutTheme.spaceMd,
                ),
                child: LockoutCard(
                  color: theme.colorScheme.tertiaryContainer,
                  onTap: () => Navigator.pop(
                    context,
                    PickedFood.custom(_searchCtrl.text.trim()),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: theme.colorScheme.onTertiaryContainer),
                      const SizedBox(width: LockoutTheme.spaceSm),
                      Expanded(
                        child: Text(
                          'Add custom: "${_searchCtrl.text.trim()}"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No match in catalog.\nType a name to add it as custom.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        LockoutTheme.screenPadding,
                        0,
                        LockoutTheme.screenPadding,
                        LockoutTheme.screenPadding,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: LockoutTheme.spaceSm),
                      itemBuilder: (_, i) {
                        final f = results[i];
                        return _FoodRow(
                          food: f,
                          matchNote: matchNotes[f.name],
                          onTap: () => _pickServings(f),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final LibraryFood food;
  final String? matchNote;
  final VoidCallback onTap;

  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  _FoodRow({required this.food, required this.matchNote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(LockoutTheme.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (matchNote != null)
                      Text('~ matched "$matchNote"',
                          style: theme.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${food.serving} – P${food.proteinG} '
                      'C${food.carbG} F${food.fatG}',
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      food.ingredients,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LockoutTheme.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
                ),
                child: Text(
                  '${food.kcal} kcal',
                  style: LockoutTheme.numeric(
                    context,
                    size: 11,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The serving-size confirmation step between picking a catalog entry and
/// logging it. Its own sheet (rather than inline in [_FoodPickerSheet]) so
/// the servings stepper can own its state independently of the search list
/// underneath it.
class _ServingsSheet extends StatefulWidget {
  final LibraryFood food;

  const _ServingsSheet({required this.food});

  @override
  State<_ServingsSheet> createState() => _ServingsSheetState();
}

class _ServingsSheetState extends State<_ServingsSheet> {
  double _servings = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final food = widget.food;
    final scaled = PickedFood.fromLibrary(food, _servings);

    return SheetScaffold(
      title: food.name,
      footer: FilledButton(
        onPressed: () => Navigator.pop(context, scaled),
        child: const Text('Add to log'),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Per serving: ${food.serving}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: LockoutTheme.spaceMd),
          LockoutCard(
            color: theme.colorScheme.surfaceContainerHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Made with', style: theme.textTheme.labelMedium),
                const SizedBox(height: LockoutTheme.spaceXs),
                Text(food.ingredients, style: theme.textTheme.bodyMedium),
                const SizedBox(height: LockoutTheme.spaceSm),
                Text(
                  'Figures assume this. Swap the oil or the cut and they '
                  'move — every field stays editable on the next screen.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: LockoutTheme.spaceLg),

          Text('Servings', style: theme.textTheme.labelMedium),
          const SizedBox(height: LockoutTheme.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _servings > 0.25
                    ? () => setState(() => _servings -= 0.25)
                    : null,
                icon: const Icon(Icons.remove, semanticLabel: 'Fewer servings'),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    PickedFood._trim(_servings),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _servings += 0.25),
                icon: const Icon(Icons.add, semanticLabel: 'More servings'),
              ),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceLg),

          LockoutCard(
            color: theme.colorScheme.secondaryContainer,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Calories', style: theme.textTheme.labelMedium),
                    Text(
                      '${scaled.kcal} kcal',
                      style: LockoutTheme.numeric(context, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: LockoutTheme.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('P ${scaled.proteinG}g',
                        style: LockoutTheme.numeric(context, size: 13)),
                    Text('C ${scaled.carbG}g',
                        style: LockoutTheme.numeric(context, size: 13)),
                    Text('F ${scaled.fatG}g',
                        style: LockoutTheme.numeric(context, size: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
