import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../services/nutrition_planner.dart';
import '../services/routine_factory.dart';
import '../services/units.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/calm_row.dart';
import '../widgets/hero_card.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_input.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/sparkline.dart';
import '../widgets/stat_tile.dart';

class BodyTab extends StatefulWidget {
  const BodyTab({super.key});

  @override
  State<BodyTab> createState() => BodyTabState();
}

class BodyTabState extends State<BodyTab> {
  List<BodyEntry> _bodyLogs = [];
  GoalSnapshot? _goal;
  String _heightUnit = 'cm';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Called by MainScreen so a height or goal changed in Settings shows here.
  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final db = DatabaseService.instance;
    final rows = await db.getBodyLogs();
    final unit = await db.getSetting('height_unit', defaultValue: 'cm');
    final goal = await GoalService.instance.snapshot();

    if (!mounted) return;
    setState(() {
      _bodyLogs = rows.map(BodyEntry.fromMap).toList();
      _heightUnit = unit == 'ft' ? 'ft' : 'cm';
      _goal = goal;
      _isLoading = false;
    });
  }

  Future<void> _openMeasurementSheet() async {
    await showJinatraSheet<void>(
      context: context,
      title: 'LOG BODY METRICS',
      builder: (ctx) => const _MeasurementForm(),
    );
    if (!mounted) return;
    await reload();
  }

  Future<void> _deleteLog(BodyEntry log) async {
    await DatabaseService.instance.deleteBodyLog(log.id);
    // A removed weight changes TDEE, so the calorie target moves too.
    await GoalService.instance.recalculateAndSaveTarget();
    if (!mounted) return;
    await reload();
  }

  Future<void> _createRecommendedRoutine() async {
    final rec = _goal?.training;
    if (rec == null) return;

    await RoutineFactory.createFromTemplate(
      name: rec.template.name,
      mode: SchedulingMode.weekday,
      template: rec.template,
      makeActive: true,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: JinatraTokens.deepTeal,
        content: Text(
          '${rec.template.name} created and set active. Open the Routines tab.',
          style: JinatraTokens.monoData(
              color: JinatraTokens.onPrimary, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: JinatraTokens.deepTeal));
    }

    // `_bodyLogs` is ordered newest-first (`getBodyLogs`'s
    // `date_str DESC, rowid DESC`), so the first entry is the latest weight
    // and the chronological (oldest-first) order the sparkline needs is the
    // reverse of that.
    final latest = _bodyLogs.isEmpty ? null : _bodyLogs.first.weightKg;
    final weights =
        _bodyLogs.map((l) => l.weightKg).toList().reversed.toList();
    // Delta goes through `GoalService.weightDeltaKg` rather than being
    // recomputed here so BODY and HOME can never disagree, and so a
    // same-day pair (a morning-vs-evening swing, not a day-over-day change)
    // is compared in the same insertion order everywhere.
    final delta = GoalService.weightDeltaKg(_goal?.bodyLogs ?? const []);

    final bmi = _goal?.bmi;
    final isGoalConfigured = _goal?.profile.isConfigured ?? false;
    final targetWeightKg =
        isGoalConfigured ? _goal?.profile.targetWeightKg : null;
    final targetKcal = _goal?.calorieTarget;

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeroCard(
            eyebrow: 'BODYWEIGHT',
            title: latest == null
                ? 'NO DATA YET'
                : '${latest.toStringAsFixed(1)} KG',
            subtitle: delta == null
                ? 'LOG A SECOND WEIGHT TO SEE A TREND'
                : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} KG '
                    'SINCE LAST ENTRY',
            background: JinatraTokens.accentAt(2),
            actions: [
              JinatraButton(
                label: '+ LOG MEASUREMENT',
                onPressed: _openMeasurementSheet,
              ),
            ],
          ),
          if (weights.length >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: JinatraTokens.cardDecoration(
                  shadowOffset: JinatraTokens.shadowSm,
                ),
                child: Sparkline(
                  values: weights,
                  lineColor: JinatraTokens.deepTeal,
                ),
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              StatTile(
                label: 'BMI',
                value: bmi == null ? '--' : bmi.toStringAsFixed(1),
              ),
              StatTile(
                label: 'TARGET',
                value: targetWeightKg == null
                    ? '--'
                    : '${targetWeightKg.toStringAsFixed(1)} kg',
              ),
              StatTile(
                label: 'DAILY INTAKE',
                value: targetKcal == null ? '--' : '$targetKcal kcal',
              ),
              StatTile(
                label: 'ENTRIES',
                value: '${_bodyLogs.length}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          CalmRow(
            icon: Icons.flag,
            title: 'GOAL PROGRESS',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'GOAL PROGRESS',
              builder: (ctx) => _buildGoalCard(),
            ),
          ),
          CalmRow(
            icon: Icons.insights,
            title: 'RECOMMENDED PLAN',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'RECOMMENDED TRAINING PLAN',
              builder: (ctx) => _buildPlanCard(),
            ),
          ),
          CalmRow(
            icon: Icons.straighten,
            title: 'HOW THIS BMI IS CALCULATED',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'BMI',
              builder: (ctx) => _buildBmiCard(),
            ),
          ),
          CalmRow(
            icon: Icons.history,
            title: 'LOG HISTORY',
            value: '${_bodyLogs.length}',
            onTap: () => showJinatraSheet<void>(
              context: context,
              title: 'LOG HISTORY',
              builder: (ctx) =>
                  _HistoryList(logs: _bodyLogs, onDelete: _deleteLog),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildBmiCard() {
    final heightCm = _goal?.profile.heightCm ?? 175.0;
    final weight = _bodyLogs.isNotEmpty ? _bodyLogs.first.weightKg : null;
    final bmi = _goal?.bmi;
    final metres = heightCm / 100.0;

    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LATEST WEIGHT',
                      style: JinatraTokens.monoData(fontSize: 11)),
                  Text(
                    weight != null ? '${weight.toStringAsFixed(1)} kg' : '--',
                    style: JinatraTokens.displayHeader(fontSize: 26),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('BMI', style: JinatraTokens.monoData(fontSize: 11)),
                  Text(
                    bmi != null ? bmi.toStringAsFixed(1) : '--',
                    style: JinatraTokens.displayHeader(
                        fontSize: 26, color: JinatraTokens.deepTeal),
                  ),
                  if (bmi != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: JinatraTokens.signal,
                        border: Border.all(color: JinatraTokens.ink, width: 2),
                      ),
                      child: Text(Units.bmiCategory(bmi),
                          style: JinatraTokens.monoData(
                              fontSize: 9, color: JinatraTokens.onAccent)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // The calculation, spelled out. Waist is deliberately absent.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: JinatraTokens.mistTeal,
              border: Border.all(color: JinatraTokens.ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOW THIS BMI IS CALCULATED',
                    style: JinatraTokens.monoData(fontSize: 10)),
                const SizedBox(height: 5),
                Text(
                  weight == null
                      ? 'weight / height²  —  log a weight to calculate'
                      : '${weight.toStringAsFixed(1)} kg / '
                          '(${metres.toStringAsFixed(2)} m)² = '
                          '${bmi!.toStringAsFixed(1)}',
                  style: JinatraTokens.monoData(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('HEIGHT FROM SETTINGS',
                        style: JinatraTokens.monoData(fontSize: 9)),
                    Text(Units.formatHeight(heightCm, _heightUnit),
                        style: JinatraTokens.monoData(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Waist is stored as a separate measurement and plays no part '
                  'in BMI. BMI also cannot tell muscle from fat — for a lifter '
                  'it is a rough reference, not a verdict.',
                  style: JinatraTokens.bodyText(
                    fontSize: 11,
                    color: JinatraTokens.ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard() {
    final snap = _goal;
    final plan = snap?.nutrition;

    if (snap == null || plan == null || snap.currentWeightKg == null) {
      return JinatraCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NO GOAL SET',
                style: JinatraTokens.sectionHeader(fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Add your age and target weight in Settings, and log one body '
              'weight here. Then the app can work out your calorie target and '
              'recommend a training split instead of guessing.',
              style: JinatraTokens.bodyText(fontSize: 13),
            ),
          ],
        ),
      );
    }

    final current = snap.currentWeightKg!;
    final target = snap.profile.targetWeightKg;
    final start = _bodyLogs.last.weightKg;
    final totalDelta = (target - start).abs();
    final doneDelta = (current - start).abs();
    final progress =
        totalDelta <= 0 ? 1.0 : (doneDelta / totalDelta).clamp(0.0, 1.0);
    final range = NutritionPlanner.healthyWeightRangeKg(snap.profile.heightCm);

    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('GOAL PROGRESS',
                    style: JinatraTokens.monoData(fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: JinatraTokens.signal,
                  border: Border.all(color: JinatraTokens.ink, width: 2),
                ),
                child: Text(plan.directionLabel,
                    style: JinatraTokens.monoData(
                        fontSize: 9, color: JinatraTokens.onAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('START', '${start.toStringAsFixed(1)} kg'),
              _stat('NOW', '${current.toStringAsFixed(1)} kg'),
              _stat('TARGET', '${target.toStringAsFixed(1)} kg'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: JinatraTokens.mistTeal,
              border: Border.all(color: JinatraTokens.ink, width: 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: JinatraTokens.deepTeal),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(progress * 100).round()}% of the way. Planned pace '
            '${plan.weeklyRatePct.toStringAsFixed(2)}% bodyweight/week over '
            '${plan.weeks} weeks.',
            style: JinatraTokens.bodyText(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Healthy BMI weight for your height is '
            '${range.$1.toStringAsFixed(1)}-${range.$2.toStringAsFixed(1)} kg.',
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
              color: JinatraTokens.mistTeal,
              border: Border.all(color: JinatraTokens.ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY INTAKE TARGET',
                    style: JinatraTokens.monoData(fontSize: 10)),
                const SizedBox(height: 3),
                Text('${plan.targetKcal} kcal',
                    style: JinatraTokens.displayHeader(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  'P ${plan.proteinG}g  -  C ${plan.carbG}g  -  F ${plan.fatG}g',
                  style: JinatraTokens.monoData(fontSize: 11),
                ),
              ],
            ),
          ),
          if (plan.warning != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JinatraTokens.signal,
                border: Border.all(color: JinatraTokens.ink, width: 2),
              ),
              child: Text(plan.warning!,
                  style: JinatraTokens.bodyText(
                      fontSize: 12, color: JinatraTokens.onAccent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    final rec = _goal?.training;
    if (rec == null) {
      return JinatraCard(
        margin: EdgeInsets.zero,
        child: Text(
          'Add your age and target weight in Settings, and log one body '
          'weight, to get a recommended training split.',
          style: JinatraTokens.bodyText(fontSize: 13),
        ),
      );
    }

    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECOMMENDED TRAINING PLAN',
              style: JinatraTokens.monoData(fontSize: 14)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JinatraTokens.deepTeal,
              border: Border.all(
                  color: JinatraTokens.ink, width: JinatraTokens.borderControl),
              boxShadow: [JinatraTokens.hardShadow(offset: 3)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.template.name.toUpperCase(),
                    style: JinatraTokens.displayHeader(
                        color: JinatraTokens.onPrimary, fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  '${rec.daysPerWeek} days/week  -  ${rec.template.days.length} sessions',
                  style: JinatraTokens.monoData(
                      color: JinatraTokens.sweetCream, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _advice('WHY THIS SPLIT', rec.rationale),
          _advice('HOW TO LOAD IT', rec.loadingAdvice),
          _advice('CARDIO', rec.cardioAdvice),
          const SizedBox(height: 6),
          JinatraButton(
            label: 'CREATE THIS ROUTINE',
            onPressed: _createRecommendedRoutine,
          ),
        ],
      ),
    );
  }

  Widget _advice(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: JinatraTokens.monoData(fontSize: 10)),
          const SizedBox(height: 3),
          Text(body, style: JinatraTokens.bodyText(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: JinatraTokens.monoData(fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: JinatraTokens.monoData(fontSize: 14)),
      ],
    );
  }
}

// --- FORM WIDGET ---
//
// Owns its own controllers as a `StatefulWidget` rather than a builder
// closure fed hoisted `TextEditingController`s — see the doc block at
// routines_tab.dart:807-827 for why: `showJinatraSheet`'s `builder` is
// re-invoked on every drag-driven rebuild of the sheet's own state, so a
// controller created inside the builder gets silently recreated (losing
// typed input), and a controller hoisted into the calling method and
// disposed in a `finally` around the awaited sheet Future gets disposed
// ~200ms before the sheet's exit animation finishes removing it from the
// tree, producing a use-after-dispose. Tying the controllers' lifecycle to
// `State.dispose()` avoids both. The pre-Task-10 version of this form built
// its controllers inline in `_showAddEntryModal` outside the builder, which
// avoided the reset bug but never disposed them at all (a leak); this fixes
// that too.
class _MeasurementForm extends StatefulWidget {
  const _MeasurementForm();

  @override
  State<_MeasurementForm> createState() => _MeasurementFormState();
}

class _MeasurementFormState extends State<_MeasurementForm> {
  final _weightCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waistCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Guards against two fast taps inserting two rows.
    if (_saving) return;
    if (_weightCtrl.text.trim().isEmpty) return;
    _saving = true;
    try {
      final entry = BodyEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dateStr: DateTime.now().toIso8601String().split('T').first,
        weightKg: double.tryParse(_weightCtrl.text) ?? 0,
        waistCm: double.tryParse(_waistCtrl.text) ?? 0.0,
      );
      await DatabaseService.instance.insertBodyLog(entry.toMap());
      // A new weight changes TDEE, so the calorie target moves too.
      await GoalService.instance.recalculateAndSaveTarget();
      if (!mounted) return;
      Navigator.pop(context);
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
        JinatraInput(
          label: 'Weight (kg)',
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        JinatraInput(
          label: 'Waist (cm) - optional',
          controller: _waistCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        Text(
          'Waist is tracked on its own. It is not used in the BMI figure — '
          'BMI is weight and height only.',
          style: JinatraTokens.bodyText(
            fontSize: 11,
            color: JinatraTokens.ink.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 14),
        JinatraButton(
          label: 'SAVE MEASUREMENT',
          onPressed: _save,
        ),
      ],
    );
  }
}

// --- HISTORY LIST WIDGET ---
//
// Also a `StatefulWidget` rather than a plain builder for the same reason as
// `_MeasurementForm`: `showJinatraSheet`'s builder can be re-invoked while
// the sheet is open, and a local list rebuilt from `widget.logs` on every
// invocation would silently undo an in-sheet delete. Owning the working copy
// in `State` lets a delete remove the row from the still-open sheet
// immediately, instead of only being visible the next time the sheet opens.
class _HistoryList extends StatefulWidget {
  final List<BodyEntry> logs;
  final Future<void> Function(BodyEntry) onDelete;

  const _HistoryList({required this.logs, required this.onDelete});

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  late List<BodyEntry> _logs;

  @override
  void initState() {
    super.initState();
    _logs = List.of(widget.logs);
  }

  Future<void> _handleDelete(BodyEntry log) async {
    await widget.onDelete(log);
    if (!mounted) return;
    setState(() => _logs.removeWhere((l) => l.id == log.id));
  }

  @override
  Widget build(BuildContext context) {
    if (_logs.isEmpty) {
      return Text(
        'No weight entries yet.',
        style: JinatraTokens.monoData(
          color: JinatraTokens.ink.withValues(alpha: 0.6),
        ),
      );
    }

    return Column(children: _logs.map(_row).toList());
  }

  Widget _row(BodyEntry log) {
    return JinatraCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(log.dateStr, style: JinatraTokens.monoData(fontSize: 13)),
          Row(
            children: [
              Text('${log.weightKg} kg',
                  style: JinatraTokens.sectionHeader(fontSize: 16)),
              if (log.waistCm > 0) ...[
                const SizedBox(width: 10),
                Text('waist ${log.waistCm} cm',
                    style: JinatraTokens.monoData(fontSize: 10)),
              ],
              // Padding lives *inside* the detector so the tappable area
              // grows to a ~40dp square without enlarging the visible
              // glyph — `HitTestBehavior.opaque` alone only makes the
              // existing 16x16 box register taps everywhere within it, it
              // does not resize that box. This is a different glyph
              // (`delete_outline`, not `close`) from the pre-Task-10 row's
              // `IconButton`, deliberately: `SheetScaffold` already uses
              // `Icons.close` for "dismiss this sheet", and this row now
              // lives inside a sheet, so reusing `close` here for "delete
              // this row" would put the same glyph on two different
              // actions on screen at once.
              GestureDetector(
                onTap: () => _handleDelete(log),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: JinatraTokens.ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
