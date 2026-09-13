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
import '../widgets/undo_banner.dart';

class BodyTab extends StatefulWidget {
  const BodyTab({super.key});

  @override
  State<BodyTab> createState() => BodyTabState();
}

class BodyTabState extends State<BodyTab> {
  List<BodyEntry> _bodyLogs = [];
  // `_HistoryList` inside an already-open LOG HISTORY sheet reads this
  // directly rather than the plain `_bodyLogs` field above (Finding 1):
  // `showJinatraSheet`'s modal route lives in the root `Overlay`, a sibling
  // of this State's own Element subtree rather than a descendant of it, so
  // `setState` here cannot reach back into an already-built sheet. A
  // `ValueNotifier` does, because `ValueListenableBuilder` subscribes to
  // the object itself, not to an ancestor rebuild — so an UNDO tapped from
  // the banner while the sheet is still open (the banner is deliberately
  // reachable without closing it) updates that list live instead of only
  // the next time the sheet opens.
  final ValueNotifier<List<BodyEntry>> _bodyLogsNotifier =
      ValueNotifier<List<BodyEntry>>(const []);
  GoalSnapshot? _goal;
  String _heightUnit = 'cm';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _bodyLogsNotifier.dispose();
    super.dispose();
  }

  /// Called by MainScreen so a height or goal changed in Settings shows here.
  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final db = DatabaseService.instance;
    final unit = await db.getSetting('height_unit', defaultValue: 'cm');
    final goal = await GoalService.instance.snapshot();

    if (!mounted) return;
    // Derived from `goal.bodyLogs` rather than a second `getBodyLogs()`
    // call: the sparkline/latest-weight series and the delta `build()`
    // computes from `_goal.bodyLogs` used to come from two separate
    // queries that happened to agree in practice but had no structural
    // reason to — one list, one query, so they cannot drift apart.
    final logs = goal.bodyLogs.map(BodyEntry.fromMap).toList();
    setState(() {
      _bodyLogs = logs;
      _heightUnit = unit == 'ft' ? 'ft' : 'cm';
      _goal = goal;
      _isLoading = false;
    });
    _bodyLogsNotifier.value = logs;
  }

  Future<void> _openMeasurementSheet() async {
    await showJinatraSheet<void>(
      context: context,
      title: 'LOG BODY METRICS',
      builder: (ctx) => _MeasurementForm(),
    );
    if (!mounted) return;
    await reload();
  }

  /// Deletes [log] immediately, then offers a few seconds to reverse it —
  /// this destroys logged history that cannot be reconstructed, and nothing
  /// short of a real undo window is an acceptable guard on a single 40dp
  /// tap (Finding 3 / Ruling F). See the doc on `showUndoBanner` for why it
  /// uses the root `Overlay` rather than a `ScaffoldMessenger` SnackBar, and
  /// why undo keeps working after the LOG HISTORY sheet that triggered the
  /// delete has been closed.
  Future<void> _deleteLog(BodyEntry log) async {
    await DatabaseService.instance.deleteBodyLog(log.id);
    // A removed weight changes TDEE, so the calorie target moves too.
    await GoalService.instance.recalculateAndSaveTarget();
    if (!mounted) return;
    await reload();
    if (!mounted) return;

    showUndoBanner(
      context,
      message: 'DELETED ${log.weightKg.toStringAsFixed(1)} KG ENTRY',
      onUndo: () => _restoreLog(log),
    );
  }

  /// Re-inserts [log] with its original id and every field intact —
  /// `insertBodyLog` uses `ConflictAlgorithm.replace`, so this is a true
  /// restore, not a near-copy with a freshly minted id.
  Future<void> _restoreLog(BodyEntry log) async {
    await DatabaseService.instance.insertBodyLog(log.toMap());
    await GoalService.instance.recalculateAndSaveTarget();
    if (!mounted) return;
    await reload();
  }

  /// [sheetContext] is the RECOMMENDED PLAN sheet's own `BuildContext`
  /// (`builder: (ctx) => ...` in `_buildPlanCard`'s caller), captured here
  /// rather than reached for after the `await` below (Finding 7): if the
  /// sheet is dragged away while `createFromTemplate` is in flight, its
  /// route pops itself, and `Navigator.of(context).maybePop()` — `context`
  /// being this State's own, long-lived one — would then pop whatever is
  /// *next* topmost on that same Navigator instead, which in the app is
  /// `MainScreen`'s own route. `ModalRoute.of`/`Navigator.of` are read
  /// synchronously, before the `await`, while `sheetContext` is definitely
  /// still valid; `route.isCurrent` afterwards is a plain property read on
  /// the `Route` object itself, safe even if the underlying widget is long
  /// gone, and answers "is this specific sheet still the one on top" rather
  /// than "is *something* poppable".
  Future<void> _createRecommendedRoutine(BuildContext sheetContext) async {
    final rec = _goal?.training;
    if (rec == null) return;

    final route = ModalRoute.of(sheetContext);
    final navigator = Navigator.of(sheetContext);

    await RoutineFactory.createFromTemplate(
      name: rec.template.name,
      mode: SchedulingMode.weekday,
      template: rec.template,
      makeActive: true,
    );
    if (!mounted) return;

    // This button lives inside the RECOMMENDED PLAN sheet. A SnackBar shown
    // from here attaches to this tab's Scaffold, which sits *below* the
    // sheet's own modal-route OverlayEntry — measured at 390x844, the sheet
    // occupies y=158..844 and the SnackBar would render at y=765..844,
    // entirely behind the sheet and its barrier, so the routine was created
    // but nothing visibly happened (Finding 1). Popping the sheet first
    // puts this tab's Scaffold back on top before the SnackBar is queued —
    // but only if that sheet is still the thing on top to pop.
    if (route != null && route.isCurrent) {
      navigator.pop();
    }

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
    // `date_str DESC, id DESC`), so the first entry is the latest weight
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
    // Gated on the target weight actually being set, not on
    // `profile.isConfigured` (age > 0 && targetWeight > 0) — a user who
    // entered a target weight but no age has genuinely set a target, and a
    // tile labelled TARGET showing `--` for them is wrong. `isConfigured`
    // still gates the *derived* plan values below (`targetKcal`, via
    // `GoalSnapshot.calorieTarget`'s own resolution order), where it
    // belongs: those numbers cannot be calculated from a target weight
    // alone.
    final targetWeightKg = _goal?.profile.targetWeightKg;
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
                value: (targetWeightKg == null || targetWeightKg <= 0)
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
              builder: (ctx) => _buildPlanCard(ctx),
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
              builder: (ctx) => _HistoryList(
                  logsNotifier: _bodyLogsNotifier, onDelete: _deleteLog),
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

  Widget _buildPlanCard(BuildContext sheetContext) {
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
            onPressed: () => _createRecommendedRoutine(sheetContext),
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
  // NOT const: `build` resolves a palette colour, so a const call site
  // would canonicalise this widget and `Element.updateChild` would skip
  // its rebuild on a theme switch, stranding it in the old palette. A
  // non-const constructor makes that unrepresentable rather than asking
  // every call site to remember.
  // ignore: prefer_const_constructors_in_immutables
  _MeasurementForm();

  @override
  State<_MeasurementForm> createState() => _MeasurementFormState();
}

class _MeasurementFormState extends State<_MeasurementForm> {
  final _weightCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waistCtrl.dispose();
    super.dispose();
  }

  /// Parses a required, strictly-positive, finite weight. `null` means
  /// "reject": `double.tryParse` happily accepts `Infinity`/`-Infinity`
  /// (which then renders as `INFINITY KG` in the hero and breaks the
  /// sparkline's normalisation into NaN) and a non-numeric string used to
  /// silently fall back to a bogus `0`.
  double? _parseWeight(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  /// Parses an optional waist measurement. Blank text and a literal "0"
  /// both mean "not measured" and store `0.0` — before this fix, blank
  /// silently stored `0.0` but typing the more explicit "0" was rejected as
  /// invalid, two different answers to the same question. `null` means
  /// "reject": `Infinity`/`-Infinity` and a negative value are not a real
  /// waist measurement either way.
  double? _parseWaist(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 0.0;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }

  Future<void> _save() async {
    // Guards against two fast taps inserting two rows.
    if (_saving) return;

    final weight = _parseWeight(_weightCtrl.text);
    if (weight == null) {
      setState(() => _error = 'Enter a valid weight in kg, e.g. 72.5.');
      return;
    }
    final waist = _parseWaist(_waistCtrl.text);
    if (waist == null) {
      setState(() => _error = 'Waist must be a valid measurement in cm.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = BodyEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dateStr: DateTime.now().toIso8601String().split('T').first,
        weightKg: weight,
        waistCm: waist,
      );
      await DatabaseService.instance.insertBodyLog(entry.toMap());
      // A new weight changes TDEE, so the calorie target moves too.
      await GoalService.instance.recalculateAndSaveTarget();
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
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
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: JinatraTokens.signal,
              border: Border.all(color: JinatraTokens.ink, width: 2),
            ),
            child: Text(
              _error!,
              style: JinatraTokens.bodyText(
                  fontSize: 12, color: JinatraTokens.onAccent),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          'Waist is tracked on its own. It is not used in the BMI figure — '
          'BMI is weight and height only.',
          style: JinatraTokens.bodyText(
            fontSize: 11,
            color: JinatraTokens.ink.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 14),
        // The `_saving` re-entrancy guard used to be invisible — SAVE
        // MEASUREMENT looked identically pressable mid-save. `IgnorePointer`
        // stops a second tap from reaching `_save` at all (belt-and-braces
        // with the guard inside it), and the dimmed opacity plus relabel
        // make that state visible instead of just structurally prevented.
        Opacity(
          opacity: _saving ? 0.6 : 1.0,
          child: IgnorePointer(
            ignoring: _saving,
            child: JinatraButton(
              label: _saving ? 'SAVING…' : 'SAVE MEASUREMENT',
              onPressed: _save,
            ),
          ),
        ),
      ],
    );
  }
}

// --- HISTORY LIST WIDGET ---
//
// A `ValueListenableBuilder` over `BodyTabState._bodyLogsNotifier` rather
// than a plain builder fed a `List<BodyEntry>` snapshot (Finding 1):
// `showJinatraSheet`'s modal route lives in the root `Overlay`, a sibling of
// `BodyTabState`'s own Element subtree rather than a descendant of it, so
// that State's `setState` cannot reach back into an already-open sheet — a
// snapshot taken when the sheet opened would still read 1 row after an
// UNDO put a 2nd back, until the sheet was closed and reopened. Listening to
// the notifier directly sidesteps that: it updates whenever
// `BodyTabState.reload()` does, regardless of which Element subtree is
// currently listening, including this sheet's, while it's open.
class _HistoryList extends StatelessWidget {
  final ValueNotifier<List<BodyEntry>> logsNotifier;
  final Future<void> Function(BodyEntry) onDelete;

  const _HistoryList({required this.logsNotifier, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BodyEntry>>(
      valueListenable: logsNotifier,
      builder: (context, logs, _) {
        if (logs.isEmpty) {
          return Text(
            'No weight entries yet.',
            style: JinatraTokens.monoData(
              color: JinatraTokens.ink.withValues(alpha: 0.6),
            ),
          );
        }

        return Column(children: logs.map(_row).toList());
      },
    );
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
                onTap: () => onDelete(log),
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
