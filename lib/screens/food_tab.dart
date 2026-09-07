import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/food_picker.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_input.dart';

class FoodTab extends StatefulWidget {
  const FoodTab({super.key});

  @override
  State<FoodTab> createState() => FoodTabState();
}

class FoodTabState extends State<FoodTab> {
  static const List<String> mealSlots = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
  ];

  List<FoodEntry> _foodLogs = [];
  int _targetKcal = 2200;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Called by MainScreen when this tab becomes visible again.
  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final db = DatabaseService.instance;
    final dateToday = DateTime.now().toIso8601String().split('T').first;
    final rows = await db.getFoodLogsForDate(dateToday);
    final targetStr = await db.getSetting('calorie_target', defaultValue: '2200');

    if (!mounted) return;
    setState(() {
      _foodLogs = rows.map(FoodEntry.fromMap).toList();
      _targetKcal = int.tryParse(targetStr) ?? 2200;
      _isLoading = false;
    });
  }

  int get _totalKcal => _foodLogs.fold(0, (sum, item) => sum + item.kcal);
  double get _totalProtein => _foodLogs.fold(0.0, (s, i) => s + i.proteinG);
  double get _totalCarbs => _foodLogs.fold(0.0, (s, i) => s + i.carbG);
  double get _totalFat => _foodLogs.fold(0.0, (s, i) => s + i.fatG);

  /// Meal slot suggested from the clock, so the common case needs no tap.
  String get _defaultSlot {
    final h = DateTime.now().hour;
    if (h < 11) return 'Breakfast';
    if (h < 16) return 'Lunch';
    if (h < 21) return 'Dinner';
    return 'Snacks';
  }

  /// Catalog picker first, then a confirm sheet with everything prefilled and
  /// still editable — a catalog figure is a starting point, not a fact.
  Future<void> _addFood() async {
    final picked = await showFoodPicker(context);
    if (picked == null || !mounted) return;

    final nameCtrl = TextEditingController(text: picked.name);
    final kcalCtrl = TextEditingController(text: picked.kcal.toString());
    final proteinCtrl = TextEditingController(text: _num(picked.proteinG));
    final carbCtrl = TextEditingController(text: _num(picked.carbG));
    final fatCtrl = TextEditingController(text: _num(picked.fatG));
    var slot = _defaultSlot;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JinatraTokens.sweetCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOG MEAL ITEM', style: JinatraTokens.sectionHeader()),
                const SizedBox(height: 14),

                Text('MEAL', style: JinatraTokens.monoData(fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mealSlots.map((s) {
                    final active = s == slot;
                    return GestureDetector(
                      onTap: () => setSheet(() => slot = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? JinatraTokens.deepTeal
                              : JinatraTokens.paper,
                          border:
                              Border.all(color: JinatraTokens.ink, width: 2),
                          boxShadow: active
                              ? null
                              : [JinatraTokens.hardShadow(offset: 2)],
                        ),
                        child: Text(
                          s.toUpperCase(),
                          style: JinatraTokens.monoData(
                            fontSize: 11,
                            color: active
                                ? JinatraTokens.onPrimary
                                : JinatraTokens.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                JinatraInput(label: 'Food Name', controller: nameCtrl),
                JinatraInput(
                  label: 'Calories (kcal)',
                  controller: kcalCtrl,
                  keyboardType: TextInputType.number,
                ),
                Row(
                  children: [
                    Expanded(
                      child: JinatraInput(
                        label: 'Protein (g)',
                        controller: proteinCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: JinatraInput(
                        label: 'Carbs (g)',
                        controller: carbCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: JinatraInput(
                        label: 'Fat (g)',
                        controller: fatCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                JinatraButton(
                  label: 'SAVE ENTRY',
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final dateToday =
                        DateTime.now().toIso8601String().split('T').first;
                    final entry = FoodEntry(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      dateStr: dateToday,
                      mealSlot: slot,
                      name: nameCtrl.text.trim(),
                      kcal: int.tryParse(kcalCtrl.text) ?? 0,
                      proteinG: double.tryParse(proteinCtrl.text) ?? 0.0,
                      carbG: double.tryParse(carbCtrl.text) ?? 0.0,
                      fatG: double.tryParse(fatCtrl.text) ?? 0.0,
                    );
                    await DatabaseService.instance.insertFoodLog(entry.toMap());
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _num(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: JinatraTokens.deepTeal));
    }

    final ratio = _targetKcal <= 0
        ? 0.0
        : (_totalKcal / _targetKcal).clamp(0.0, 1.0).toDouble();
    final over = _totalKcal > _targetKcal;

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text('NUTRITION LOG',
                        style: JinatraTokens.sectionHeader())),
                JinatraButton(label: '+ LOG FOOD', onPressed: _addFood),
              ],
            ),
            const SizedBox(height: 16),

            JinatraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CALORIES CONSUMED',
                          style: JinatraTokens.monoData(fontSize: 12)),
                      Text(
                        '$_totalKcal / $_targetKcal kcal',
                        style: JinatraTokens.monoData(
                          fontSize: 14,
                          color:
                              over ? JinatraTokens.signal : JinatraTokens.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: JinatraTokens.mistTeal,
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio,
                      child: Container(
                        color: over
                            ? JinatraTokens.signal
                            : JinatraTokens.deepTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('P: ${_totalProtein.toStringAsFixed(1)}g',
                          style: JinatraTokens.monoData()),
                      Text('C: ${_totalCarbs.toStringAsFixed(1)}g',
                          style: JinatraTokens.monoData()),
                      Text('F: ${_totalFat.toStringAsFixed(1)}g',
                          style: JinatraTokens.monoData()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _foodLogs.isEmpty
                  ? Center(
                      child: Text(
                        'NO FOOD LOGGED TODAY\nTap "+ LOG FOOD" and pick from the catalog.',
                        textAlign: TextAlign.center,
                        style: JinatraTokens.monoData(
                          color: JinatraTokens.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView(children: _buildSlotSections()),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups the day's entries under meal headers, skipping empty slots.
  List<Widget> _buildSlotSections() {
    final widgets = <Widget>[];

    for (final slot in mealSlots) {
      final items = _foodLogs.where((f) => f.mealSlot == slot).toList();
      if (items.isEmpty) continue;

      final slotKcal = items.fold(0, (sum, f) => sum + f.kcal);

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(slot.toUpperCase(),
                style: JinatraTokens.monoData(fontSize: 12)),
            Text('$slotKcal kcal',
                style: JinatraTokens.monoData(
                  fontSize: 11,
                  color: JinatraTokens.ink.withValues(alpha: 0.6),
                )),
          ],
        ),
      ));

      widgets.addAll(items.map(_buildFoodRow));
    }

    // Entries saved before meal slots existed, or with an unknown slot.
    final orphans =
        _foodLogs.where((f) => !mealSlots.contains(f.mealSlot)).toList();
    if (orphans.isNotEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text('OTHER', style: JinatraTokens.monoData(fontSize: 12)),
      ));
      widgets.addAll(orphans.map(_buildFoodRow));
    }

    return widgets;
  }

  Widget _buildFoodRow(FoodEntry food) {
    return JinatraCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name,
                    style: JinatraTokens.bodyText(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  'P ${food.proteinG}g - C ${food.carbG}g - F ${food.fatG}g',
                  style: JinatraTokens.monoData(fontSize: 10),
                ),
              ],
            ),
          ),
          Text('${food.kcal} kcal',
              style: JinatraTokens.monoData(fontSize: 13)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: JinatraTokens.ink),
            onPressed: () async {
              await DatabaseService.instance.deleteFoodLog(food.id);
              _loadData();
            },
          ),
        ],
      ),
    );
  }
}
