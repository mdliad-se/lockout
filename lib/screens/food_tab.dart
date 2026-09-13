import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../widgets/food_picker.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_input.dart';
import '../widgets/meal_section.dart';
import '../widgets/progress_hero.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/stat_tile.dart';
import '../widgets/undo_banner.dart';

class FoodTab extends StatefulWidget {
  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart. This tab
  // lives in `MainScreen`'s `IndexedStack` and never unmounts, so a skipped
  // rebuild would strand it in the old palette for the process lifetime.
  // ignore: prefer_const_constructors_in_immutables
  FoodTab({super.key});

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
  int _targetKcal = DatabaseService.defaultCalorieTarget;
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
    // Resolved through GoalService — the single place Ruling A's "plan
    // value first, then the manual override, then the default" order lives
    // — so this can never disagree with what HOME shows for the same day.
    final snapshot = await GoalService.instance.snapshot();

    if (!mounted) return;
    setState(() {
      _foodLogs = rows.map(FoodEntry.fromMap).toList();
      _targetKcal = snapshot.calorieTarget;
      _isLoading = false;
    });
  }

  int get _totalKcal => _foodLogs.fold(0, (sum, item) => sum + item.kcal);
  double get _totalProtein => _foodLogs.fold(0.0, (s, i) => s + i.proteinG);
  double get _totalCarb => _foodLogs.fold(0.0, (s, i) => s + i.carbG);
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

    final saved = await showJinatraSheet<bool>(
      context: context,
      title: 'LOG MEAL ITEM',
      builder: (ctx) => _LogMealForm(picked: picked, defaultSlot: _defaultSlot),
    );
    if (saved == true && mounted) await reload();
  }

  /// Same gap Task 9 left BODY's body-log delete with (Finding 3 / Ruling
  /// F): a single tap on a ~36dp target destroys a logged entry with no
  /// confirmation. Deletes immediately, then offers a few seconds to
  /// reverse it through the same `showUndoBanner` BODY uses, rather than a
  /// second, lookalike implementation of the same idea.
  Future<void> _deleteEntry(FoodEntry entry) async {
    await DatabaseService.instance.deleteFoodLog(entry.id);
    if (!mounted) return;
    await reload();
    if (!mounted) return;

    showUndoBanner(
      context,
      message: 'DELETED ${entry.name.toUpperCase()}',
      onUndo: () => _restoreEntry(entry),
    );
  }

  /// Re-inserts [entry] with its original id and every field intact —
  /// `insertFoodLog` uses `ConflictAlgorithm.replace`, so this is a true
  /// restore, not a near-copy with a freshly minted id.
  Future<void> _restoreEntry(FoodEntry entry) async {
    await DatabaseService.instance.insertFoodLog(entry.toMap());
    if (!mounted) return;
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: JinatraTokens.deepTeal));
    }

    final eaten = _totalKcal;
    final target = _targetKcal;
    final left = target - eaten;

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProgressHero(
            eyebrow: 'TODAY',
            title: '$eaten / $target KCAL',
            subtitle: left >= 0 ? '$left LEFT' : '${left.abs()} OVER',
            progress: target <= 0 ? 0.0 : eaten / target,
            // v1 painted both the number and the bar in the signal colour
            // once the day went over budget; an over-budget day otherwise
            // reads identically to an on-track one except for the 11px
            // subtitle. `ProgressHero` resolves its own foreground from
            // whatever background it is given (`onAccentColor`), so this
            // stays legible across every palette without hardcoding.
            background:
                left < 0 ? JinatraTokens.signal : JinatraTokens.accentAt(0),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'PROTEIN',
                  value: '${_num(_totalProtein)} g',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'CARBS',
                  value: '${_num(_totalCarb)} g',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'FAT',
                  value: '${_num(_totalFat)} g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          JinatraButton(
            label: 'LOG FOOD',
            icon: Icons.add,
            onPressed: _addFood,
          ),
          const SizedBox(height: 20),
          if (_foodLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'NO FOOD LOGGED TODAY\nTap "LOG FOOD" and pick from the catalog.',
                  textAlign: TextAlign.center,
                  style: JinatraTokens.monoData(
                    color: JinatraTokens.ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ...mealSlots.map(
            (slot) => MealSection(
              title: slot,
              entries: _foodLogs.where((f) => f.mealSlot == slot).toList(),
              onDelete: _deleteEntry,
            ),
          ),
          MealSection(
            title: 'Other',
            entries: _foodLogs
                .where((f) => !mealSlots.contains(f.mealSlot))
                .toList(),
            onDelete: _deleteEntry,
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

/// One decimal place, trimmed to a whole number when exact. Library-level
/// rather than a method on [FoodTabState] — [_LogMealFormState] is an
/// unrelated widget's `State` and had no business reaching into that one.
String _num(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// --- FORM WIDGET ---
//
// Owns its own controllers/state as a `StatefulWidget` rather than a builder
// closure fed hoisted `TextEditingController`s — see the doc block at
// routines_tab.dart:807-827 for why: `showJinatraSheet`'s `builder` is
// re-invoked on every drag-driven rebuild of the sheet's own state, so a
// controller created inside the builder gets silently recreated (losing
// typed input), and a controller hoisted into the calling method and
// disposed in a `finally` around the awaited sheet Future gets disposed
// ~200ms before the sheet's exit animation finishes removing it from the
// tree, producing a use-after-dispose. Tying the controllers' lifecycle to
// `State.dispose()` avoids both.
class _LogMealForm extends StatefulWidget {
  final PickedFood picked;
  final String defaultSlot;

  const _LogMealForm({required this.picked, required this.defaultSlot});

  @override
  State<_LogMealForm> createState() => _LogMealFormState();
}

class _LogMealFormState extends State<_LogMealForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _fatCtrl;
  late String _slot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.picked.name);
    _kcalCtrl = TextEditingController(text: widget.picked.kcal.toString());
    _proteinCtrl = TextEditingController(text: _num(widget.picked.proteinG));
    _carbCtrl = TextEditingController(text: _num(widget.picked.carbG));
    _fatCtrl = TextEditingController(text: _num(widget.picked.fatG));
    _slot = widget.defaultSlot;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Guards against two fast taps inserting two rows: `_save` awaits the
    // insert before popping, so nothing else stopped a second `onTapUp`
    // landing before the sheet closes.
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) return;
    _saving = true;
    try {
      final dateToday = DateTime.now().toIso8601String().split('T').first;
      final entry = FoodEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dateStr: dateToday,
        mealSlot: _slot,
        name: _nameCtrl.text.trim(),
        kcal: int.tryParse(_kcalCtrl.text) ?? 0,
        proteinG: double.tryParse(_proteinCtrl.text) ?? 0.0,
        carbG: double.tryParse(_carbCtrl.text) ?? 0.0,
        fatG: double.tryParse(_fatCtrl.text) ?? 0.0,
      );
      await DatabaseService.instance.insertFoodLog(entry.toMap());
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MEAL', style: JinatraTokens.monoData(fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FoodTabState.mealSlots.map((s) {
            final active = s == _slot;
            return GestureDetector(
              onTap: () => setState(() => _slot = s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: JinatraTokens.cardDecoration(
                  background:
                      active ? JinatraTokens.deepTeal : JinatraTokens.paper,
                  borderWidth: JinatraTokens.borderDivider,
                  hasShadow: !active,
                  shadowOffset: JinatraTokens.shadowSm,
                  radius: JinatraTokens.radiusPill,
                ),
                child: Text(
                  s.toUpperCase(),
                  style: JinatraTokens.monoData(
                    fontSize: 11,
                    color:
                        active ? JinatraTokens.onPrimary : JinatraTokens.ink,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        JinatraInput(label: 'Food Name', controller: _nameCtrl),
        JinatraInput(
          label: 'Calories (kcal)',
          controller: _kcalCtrl,
          keyboardType: TextInputType.number,
        ),
        Row(
          children: [
            Expanded(
              child: JinatraInput(
                label: 'Protein (g)',
                controller: _proteinCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: JinatraInput(
                label: 'Carbs (g)',
                controller: _carbCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: JinatraInput(
                label: 'Fat (g)',
                controller: _fatCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        JinatraButton(label: 'SAVE ENTRY', onPressed: _save),
      ],
    );
  }
}
