import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_input.dart';

class FoodTab extends StatefulWidget {
  const FoodTab({super.key});

  @override
  State<FoodTab> createState() => _FoodTabState();
}

class _FoodTabState extends State<FoodTab> {
  List<FoodEntry> _foodLogs = [];
  int _targetKcal = 2200;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dateToday = DateTime.now().toIso8601String().split('T').first;
    final rows = await DatabaseService.instance.getFoodLogsForDate(dateToday);
    final targetStr = await DatabaseService.instance.getSetting('calorie_target', defaultValue: '2200');
    
    setState(() {
      _foodLogs = rows.map((r) => FoodEntry.fromMap(r)).toList();
      _targetKcal = int.tryParse(targetStr) ?? 2200;
      _isLoading = false;
    });
  }

  int get _totalKcal => _foodLogs.fold(0, (sum, item) => sum + item.kcal);
  double get _totalProtein => _foodLogs.fold(0.0, (sum, item) => sum + item.proteinG);
  double get _totalCarbs => _foodLogs.fold(0.0, (sum, item) => sum + item.carbG);
  double get _totalFat => _foodLogs.fold(0.0, (sum, item) => sum + item.fatG);

  void _showAddFoodModal() {
    final nameCtrl = TextEditingController();
    final kcalCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    String selectedSlot = 'Lunch';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JinatraTokens.sweetCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Padding(
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
              JinatraInput(label: 'Food Name', controller: nameCtrl, hint: 'e.g. Chicken & Rice'),
              JinatraInput(label: 'Calories (kcal)', controller: kcalCtrl, keyboardType: TextInputType.number),
              Row(
                children: [
                  Expanded(child: JinatraInput(label: 'Protein (g)', controller: proteinCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: JinatraInput(label: 'Carbs (g)', controller: carbCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: JinatraInput(label: 'Fat (g)', controller: fatCtrl, keyboardType: TextInputType.number)),
                ],
              ),
              JinatraButton(
                label: 'SAVE ENTRY',
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || kcalCtrl.text.isEmpty) return;
                  final dateToday = DateTime.now().toIso8601String().split('T').first;
                  final entry = FoodEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    dateStr: dateToday,
                    mealSlot: selectedSlot,
                    name: nameCtrl.text.trim(),
                    kcal: int.parse(kcalCtrl.text),
                    proteinG: double.tryParse(proteinCtrl.text) ?? 0.0,
                    carbG: double.tryParse(carbCtrl.text) ?? 0.0,
                    fatG: double.tryParse(fatCtrl.text) ?? 0.0,
                  );
                  await DatabaseService.instance.insertFoodLog(entry.toMap());
                  Navigator.pop(ctx);
                  _loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: JinatraTokens.deepTeal));
    }

    final ratio = (_totalKcal / _targetKcal).clamp(0.0, 1.0);

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
                Text('NUTRITION LOG', style: JinatraTokens.sectionHeader()),
                JinatraButton(label: '+ LOG FOOD', onPressed: _showAddFoodModal),
              ],
            ),
            const SizedBox(height: 16),
            // Calorie Budget Neubrutalist Bar
            JinatraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CALORIES CONSUMED', style: JinatraTokens.monoData(fontSize: 12)),
                      Text('$_totalKcal / $_targetKcal kcal', style: JinatraTokens.monoData(fontSize: 14)),
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
                      child: Container(color: JinatraTokens.deepTeal),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('P: ${_totalProtein.toStringAsFixed(1)}g', style: JinatraTokens.monoData()),
                      Text('C: ${_totalCarbs.toStringAsFixed(1)}g', style: JinatraTokens.monoData()),
                      Text('F: ${_totalFat.toStringAsFixed(1)}g', style: JinatraTokens.monoData()),
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
                        'NO FOOD LOGGED TODAY\nTap "+ LOG FOOD" to record a meal.',
                        textAlign: TextAlign.center,
                        style: JinatraTokens.monoData(color: JinatraTokens.ink.withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _foodLogs.length,
                      itemBuilder: (ctx, idx) {
                        final food = _foodLogs[idx];
                        return JinatraCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(food.name, style: JinatraTokens.sectionHeader(fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'P: ${food.proteinG}g · C: ${food.carbG}g · F: ${food.fatG}g',
                                    style: JinatraTokens.monoData(fontSize: 11),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('${food.kcal} kcal', style: JinatraTokens.monoData(fontSize: 14)),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () async {
                                      await DatabaseService.instance.deleteFoodLog(food.id);
                                      _loadData();
                                    },
                                  ),
                                ],
                              ),
                            ],
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
