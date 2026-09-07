import 'package:flutter/material.dart';
import '../data/food_library.dart';
import '../theme/jinatra_tokens.dart';

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
  return showModalBottomSheet<PickedFood>(
    context: context,
    isScrollControlled: true,
    backgroundColor: JinatraTokens.sweetCream,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => const _FoodPickerSheet(),
  );
}

class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet();

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

  List<LibraryFood> get _results {
    var list = _category == 'All'
        ? FoodLibrary.all
        : FoodLibrary.byCategory(_category);
    if (_query.isNotEmpty) {
      list = list.where((f) => f.matches(_query)).toList();
    }
    return list;
  }

  bool get _canAddCustom =>
      _query.trim().isNotEmpty && FoodLibrary.findByName(_query) == null;

  /// Serving-size step before the item is logged, so "2 rotis" is one entry.
  Future<void> _pickServings(LibraryFood food) async {
    var servings = 1.0;

    final result = await showModalBottomSheet<PickedFood>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JinatraTokens.sweetCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) {
          final scaled = PickedFood.fromLibrary(food, servings);
          return Padding(
            padding: EdgeInsets.only(
              top: 24,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name.toUpperCase(),
                    style: JinatraTokens.sectionHeader(fontSize: 17)),
                const SizedBox(height: 4),
                Text(
                  'PER SERVING: ${food.serving}',
                  style: JinatraTokens.monoData(
                    fontSize: 10,
                    color: JinatraTokens.ink.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: JinatraTokens.paper,
                    border: Border.all(color: JinatraTokens.ink, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MADE WITH',
                          style: JinatraTokens.monoData(fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(food.ingredients,
                          style: JinatraTokens.bodyText(fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        'Figures assume this. Swap the oil or the cut and they move — every field stays editable on the next screen.',
                        style: JinatraTokens.bodyText(
                          fontSize: 10,
                          color: JinatraTokens.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('SERVINGS', style: JinatraTokens.monoData(fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stepBtn('-', () {
                      if (servings > 0.25) {
                        setSheet(() => servings -= 0.25);
                      }
                    }),
                    Expanded(
                      child: Center(
                        child: Text(
                          PickedFood._trim(servings),
                          style: JinatraTokens.displayHeader(fontSize: 26),
                        ),
                      ),
                    ),
                    _stepBtn('+', () => setSheet(() => servings += 0.25)),
                  ],
                ),
                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: JinatraTokens.mistTeal,
                    border: Border.all(color: JinatraTokens.ink, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CALORIES',
                              style: JinatraTokens.monoData(fontSize: 12)),
                          Text('${scaled.kcal} kcal',
                              style: JinatraTokens.monoData(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('P ${scaled.proteinG}g',
                              style: JinatraTokens.monoData(fontSize: 12)),
                          Text('C ${scaled.carbG}g',
                              style: JinatraTokens.monoData(fontSize: 12)),
                          Text('F ${scaled.fatG}g',
                              style: JinatraTokens.monoData(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                GestureDetector(
                  onTap: () => Navigator.pop(ctx, scaled),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: JinatraTokens.deepTeal,
                      border: Border.all(
                          color: JinatraTokens.ink,
                          width: JinatraTokens.borderControl),
                      boxShadow: [JinatraTokens.hardShadow(offset: 3)],
                    ),
                    child: Center(
                      child: Text(
                        'ADD TO LOG',
                        style: JinatraTokens.monoData(
                            color: JinatraTokens.onPrimary, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Widget _stepBtn(String glyph, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: JinatraTokens.paper,
          border: Border.all(color: JinatraTokens.ink, width: 2),
          boxShadow: [JinatraTokens.hardShadow(offset: 2)],
        ),
        child: Text(glyph, style: JinatraTokens.monoData(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final cats = ['All', ...FoodLibrary.categories];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PICK FOOD', style: JinatraTokens.sectionHeader()),
                  Text(
                    '${results.length} FOUND',
                    style: JinatraTokens.monoData(
                      fontSize: 11,
                      color: JinatraTokens.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: JinatraTokens.paper,
                  border: Border.all(
                      color: JinatraTokens.ink,
                      width: JinatraTokens.borderControl),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: JinatraTokens.bodyText(fontWeight: FontWeight.w600),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search dish, cuisine or ingredient...',
                    hintStyle: JinatraTokens.bodyText(
                      color: JinatraTokens.ink.withValues(alpha: 0.45),
                    ),
                    prefixIcon:
                        Icon(Icons.search, color: JinatraTokens.ink, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close,
                                size: 18, color: JinatraTokens.ink),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: cats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final active = c == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? JinatraTokens.deepTeal
                            : JinatraTokens.paper,
                        border: Border.all(color: JinatraTokens.ink, width: 2),
                        boxShadow:
                            active ? null : [JinatraTokens.hardShadow(offset: 2)],
                      ),
                      child: Text(
                        c.toUpperCase(),
                        style: JinatraTokens.monoData(
                          fontSize: 11,
                          color: active
                              ? JinatraTokens.onPrimary
                              : JinatraTokens.ink,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            if (_canAddCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap: () => Navigator.pop(
                    context,
                    PickedFood.custom(_searchCtrl.text.trim()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JinatraTokens.signal,
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                      boxShadow: [JinatraTokens.hardShadow(offset: 3)],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18, color: JinatraTokens.onAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ADD CUSTOM: "${_searchCtrl.text.trim()}"',
                            style: JinatraTokens.monoData(
                                fontSize: 11, color: JinatraTokens.onAccent),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'NO MATCH IN CATALOG\nType a name to add it as custom.',
                        textAlign: TextAlign.center,
                        style: JinatraTokens.monoData(
                          color: JinatraTokens.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final f = results[i];
                        return GestureDetector(
                          onTap: () => _pickServings(f),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: JinatraTokens.paper,
                              border: Border.all(
                                  color: JinatraTokens.ink, width: 2),
                              boxShadow: [JinatraTokens.hardShadow(offset: 3)],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f.name,
                                        style: JinatraTokens.bodyText(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${f.serving}  -  P${f.proteinG} C${f.carbG} F${f.fatG}',
                                        style: JinatraTokens.monoData(
                                          fontSize: 9,
                                          color: JinatraTokens.ink
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        f.ingredients,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: JinatraTokens.bodyText(
                                          fontSize: 10,
                                          color: JinatraTokens.ink
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: JinatraTokens.mistTeal,
                                    border: Border.all(
                                        color: JinatraTokens.ink, width: 1),
                                  ),
                                  child: Text('${f.kcal} kcal',
                                      style: JinatraTokens.monoData(
                                          fontSize: 10)),
                                ),
                              ],
                            ),
                          ),
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
