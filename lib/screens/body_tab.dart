import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../services/nutrition_planner.dart';
import '../services/routine_factory.dart';
import '../services/units.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_input.dart';

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

  double? get _latestWeight =>
      _bodyLogs.isNotEmpty ? _bodyLogs.first.weightKg : null;

  void _showAddEntryModal() {
    final weightCtrl = TextEditingController();
    final waistCtrl = TextEditingController();

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LOG BODY METRICS', style: JinatraTokens.sectionHeader()),
            const SizedBox(height: 14),
            JinatraInput(
              label: 'Weight (kg)',
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            JinatraInput(
              label: 'Waist (cm) - optional',
              controller: waistCtrl,
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
              onPressed: () async {
                if (weightCtrl.text.trim().isEmpty) return;
                final entry = BodyEntry(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  dateStr: DateTime.now().toIso8601String().split('T').first,
                  weightKg: double.tryParse(weightCtrl.text) ?? 0,
                  waistCm: double.tryParse(waistCtrl.text) ?? 0.0,
                );
                await DatabaseService.instance.insertBodyLog(entry.toMap());
                // A new weight changes TDEE, so the calorie target moves too.
                await GoalService.instance.recalculateAndSaveTarget();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
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
                    child: Text('BODY METRICS',
                        style: JinatraTokens.sectionHeader())),
                JinatraButton(label: '+ LOG', onPressed: _showAddEntryModal),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildBmiCard(),
                  const SizedBox(height: 12),
                  _buildGoalCard(),
                  const SizedBox(height: 12),
                  _buildPlanCard(),
                  const SizedBox(height: 12),
                  Text('LOG HISTORY',
                      style: JinatraTokens.monoData(fontSize: 14)),
                  const SizedBox(height: 8),
                  if (_bodyLogs.isEmpty)
                    Text(
                      'No weight entries yet. Tap "+ LOG" to add one.',
                      style: JinatraTokens.monoData(
                        color: JinatraTokens.ink.withValues(alpha: 0.6),
                      ),
                    )
                  else
                    ..._bodyLogs.map(_buildHistoryRow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBmiCard() {
    final heightCm = _goal?.profile.heightCm ?? 175.0;
    final weight = _latestWeight;
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
    if (rec == null) return const SizedBox.shrink();

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

  Widget _buildHistoryRow(BodyEntry log) {
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
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 16, color: JinatraTokens.ink),
                onPressed: () async {
                  await DatabaseService.instance.deleteBodyLog(log.id);
                  await GoalService.instance.recalculateAndSaveTarget();
                  await _loadData();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
