import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../services/numeric_guard.dart';
import '../services/nutrition_planner.dart';
import '../services/routine_factory.dart';
import '../services/units.dart';
import '../theme/lockout_theme.dart';
import '../widgets/calm_row.dart';
import '../widgets/lockout_card.dart';
import '../widgets/lockout_field.dart';
import '../widgets/weight_card.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/stat_tile.dart';
import '../widgets/undo_banner.dart';

class BodyTab extends StatefulWidget {
  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart. This tab
  // lives in `MainScreen`'s `IndexedStack` and never unmounts, so a skipped
  // rebuild would strand it in the old palette for the process lifetime.
  // ignore: prefer_const_constructors_in_immutables
  BodyTab({super.key});

  @override
  State<BodyTab> createState() => BodyTabState();
}

class BodyTabState extends State<BodyTab> {
  List<BodyEntry> _bodyLogs = [];
  // `_HistoryList` inside an already-open LOG HISTORY sheet reads this
  // directly rather than the plain `_bodyLogs` field above (Finding 1):
  // `showLockoutSheet`'s modal route lives in the root `Overlay`, a sibling
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
    await showLockoutSheet<void>(
      context: context,
      title: 'Log body metrics',
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
        content: Text(
          '${rec.template.name} created and set active. '
          'Open the Workout tab.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // The same card Home leads with, rather than a second presentation
          // of the same three facts. Two screens disagreeing about how to
          // show a bodyweight is how the old UI ended up with a hero here and
          // a one-line row there.
          WeightCard(
            weightKg: latest,
            targetWeightKg:
                (targetWeightKg != null && targetWeightKg > 0)
                    ? targetWeightKg
                    : null,
            deltaKg: delta,
            series: weights,
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openMeasurementSheet,
              icon: const Icon(Icons.add),
              label: const Text('Log measurement'),
            ),
          ),
          const SizedBox(height: LockoutTheme.spaceLg),
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
                label: 'Target',
                value: (targetWeightKg == null || targetWeightKg <= 0)
                    ? '--'
                    : '${targetWeightKg.toStringAsFixed(1)} kg',
              ),
              StatTile(
                label: 'Daily intake',
                value: targetKcal == null ? '--' : '$targetKcal kcal',
              ),
              StatTile(
                label: 'Entries',
                value: '${_bodyLogs.length}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          CalmRow(
            icon: Icons.flag,
            title: 'Goal progress',
            onTap: () => showLockoutSheet<void>(
              context: context,
              title: 'Goal progress',
              builder: (ctx) => _buildGoalCard(),
            ),
          ),
          CalmRow(
            icon: Icons.insights,
            title: 'Recommended plan',
            onTap: () => showLockoutSheet<void>(
              context: context,
              title: 'Recommended training plan',
              builder: (ctx) => _buildPlanCard(ctx),
            ),
          ),
          CalmRow(
            icon: Icons.straighten,
            title: 'How this BMI is calculated',
            onTap: () => showLockoutSheet<void>(
              context: context,
              title: 'BMI',
              builder: (ctx) => _buildBmiCard(),
            ),
          ),
          CalmRow(
            icon: Icons.history,
            title: 'Weight history',
            value: '${_bodyLogs.length}',
            onTap: () => showLockoutSheet<void>(
              context: context,
              title: 'Weight history',
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final heightCm = _goal?.profile.heightCm ?? 175.0;
    final weight = _bodyLogs.isNotEmpty ? _bodyLogs.first.weightKg : null;
    final bmi = _goal?.bmi;
    final metres = heightCm / 100.0;

    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LATEST WEIGHT', style: theme.textTheme.labelSmall),
                  Text(
                    weight != null ? '${weight.toStringAsFixed(1)} kg' : '--',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('BMI', style: theme.textTheme.labelSmall),
                  Text(
                    bmi != null ? bmi.toStringAsFixed(1) : '--',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: colors.primary),
                  ),
                  if (bmi != null) ...[
                    const SizedBox(height: LockoutTheme.spaceXs),
                    Chip(
                      label: Text(Units.bmiCategory(bmi)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceMd),

          // The calculation, spelled out. Waist is deliberately absent.
          LockoutCard(
            color: colors.tertiaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How this BMI is calculated',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.onTertiaryContainer)),
                const SizedBox(height: LockoutTheme.spaceXs),
                Text(
                  weight == null
                      ? 'weight / height²  —  log a weight to calculate'
                      : '${weight.toStringAsFixed(1)} kg / '
                          '(${metres.toStringAsFixed(2)} m)² = '
                          '${bmi!.toStringAsFixed(1)}',
                  style: LockoutTheme.numeric(context,
                      size: 13, color: colors.onTertiaryContainer),
                ),
                const SizedBox(height: LockoutTheme.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('HEIGHT FROM SETTINGS',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: colors.onTertiaryContainer)),
                    Text(Units.formatHeight(heightCm, _heightUnit),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: colors.onTertiaryContainer)),
                  ],
                ),
                const SizedBox(height: LockoutTheme.spaceXs),
                Text(
                  'Waist is stored as a separate measurement and plays no part '
                  'in BMI. BMI also cannot tell muscle from fat — for a lifter '
                  'it is a rough reference, not a verdict.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onTertiaryContainer),
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

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (snap == null || plan == null || snap.currentWeightKg == null) {
      return LockoutCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NO GOAL SET', style: theme.textTheme.titleMedium),
            const SizedBox(height: LockoutTheme.spaceSm),
            Text(
              'Add your age and target weight in Settings, and log one body '
              'weight here. Then the app can work out your calorie target and '
              'recommend a training split instead of guessing.',
              style: theme.textTheme.bodyMedium,
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

    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No heading here: the sheet is already titled 'Goal progress'
          // directly above this card (`showLockoutSheet`'s own title bar),
          // so repeating it in all-caps just under that title would shout
          // the same three words back rather than add anything (Finding 3).
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Chip(
                label: Text(plan.directionLabel),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('START', '${start.toStringAsFixed(1)} kg'),
              _stat('NOW', '${current.toStringAsFixed(1)} kg'),
              _stat('TARGET', '${target.toStringAsFixed(1)} kg'),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
            child: LinearProgressIndicator(value: progress),
          ),
          const SizedBox(height: LockoutTheme.spaceSm),
          // This is the sheet's headline figure — `bodyMedium` (14/w400,
          // `onSurface`) rather than the aside's dimmed `bodySmall` below it,
          // so the two are differentiated again instead of reading as two
          // equally-weighted footnotes 4dp apart (Finding 4).
          Text(
            '${(progress * 100).round()}% of the way. Planned pace '
            '${plan.weeklyRatePct.toStringAsFixed(2)}% bodyweight/week over '
            '${plan.weeks} weeks.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: LockoutTheme.spaceXs),
          Text(
            'Healthy BMI weight for your height is '
            '${range.$1.toStringAsFixed(1)}-${range.$2.toStringAsFixed(1)} kg.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          // `SizedBox(width: double.infinity)`: `LockoutCard` renders a
          // `Card`, which sizes to its child, and this Column's
          // `crossAxisAlignment: .start` gives it loose constraints — so
          // without the wrapper this shrink-wraps to the width of its
          // shortest line ('P 180g - C 250g - F 70g') instead of staying
          // full-bleed like the rest of the sheet (Finding 1).
          SizedBox(
            width: double.infinity,
            child: LockoutCard(
              color: colors.tertiaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DAILY INTAKE TARGET',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colors.onTertiaryContainer)),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text('${plan.targetKcal} kcal',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: colors.onTertiaryContainer)),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text(
                    'P ${plan.proteinG}g  -  C ${plan.carbG}g  -  F ${plan.fatG}g',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.onTertiaryContainer),
                  ),
                ],
              ),
            ),
          ),
          if (plan.warning != null) ...[
            const SizedBox(height: LockoutTheme.spaceSm),
            // Same `tertiaryContainer` fill as the intake box above it, so
            // this still reads as a rate-cap/floor *notice* rather than a
            // second info panel identical to it: the leading warning glyph
            // (matching `today_tab.dart`'s leg-safety notice) is what
            // differentiates them, not the fill (Finding 2 — `warning` is a
            // content colour with no `onWarning` pair, so it belongs on the
            // glyph, never repainting the card). `Row`'s default
            // `mainAxisSize.max` also spans this full width without needing
            // its own `SizedBox` wrapper.
            LockoutCard(
              color: colors.tertiaryContainer,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: colors.onTertiaryContainer),
                  const SizedBox(width: LockoutTheme.spaceSm),
                  Expanded(
                    child: Text(plan.warning!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colors.onTertiaryContainer)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext sheetContext) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rec = _goal?.training;
    if (rec == null) {
      return LockoutCard(
        child: Text(
          'Add your age and target weight in Settings, and log one body '
          'weight, to get a recommended training split.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No heading here: the sheet is already titled 'Recommended
          // training plan' directly above this card, so an all-caps repeat
          // of it would shout the same words back rather than add anything
          // (Finding 3).
          //
          // `SizedBox(width: double.infinity)`: without it this hero
          // shrink-wraps to the width of '4 days/week - 4 sessions', the
          // same `Card`-sizes-to-its-child / loose-Column cause as the
          // intake box above (Finding 1).
          SizedBox(
            width: double.infinity,
            child: LockoutCard(
              color: colors.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.template.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: colors.onPrimaryContainer)),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text(
                    '${rec.daysPerWeek} days/week  -  ${rec.template.days.length} sessions',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          _advice('WHY THIS SPLIT', rec.rationale),
          _advice('HOW TO LOAD IT', rec.loadingAdvice),
          _advice('CARDIO', rec.cardioAdvice),
          const SizedBox(height: LockoutTheme.spaceXs),
          // Full-width, matching the tab-level primary action at :225-232
          // and `food_picker.dart`'s footer button — a bare `FilledButton`
          // here would render left-aligned at intrinsic width instead
          // (Finding 5).
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _createRecommendedRoutine(sheetContext),
              child: const Text('Create this routine'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _advice(String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelSmall),
          const SizedBox(height: LockoutTheme.spaceXs),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: LockoutTheme.spaceXs),
        Text(value, style: LockoutTheme.numeric(context, size: 14)),
      ],
    );
  }
}

// --- FORM WIDGET ---
//
// Owns its own controllers as a `StatefulWidget` rather than a builder
// closure fed hoisted `TextEditingController`s — see the doc block at
// routines_tab.dart:807-827 for why: `showLockoutSheet`'s `builder` is
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
  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart.
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
  /// silently fall back to a bogus `0`. The rule itself lives in
  /// `NumericGuard`, shared with Settings and the routine builder's weight
  /// field so all four write sites cannot drift apart.
  double? _parseWeight(String raw) =>
      NumericGuard.parse(raw, min: 0.0, minExclusive: true);

  /// Parses an optional waist measurement. Blank text and a literal "0"
  /// both mean "not measured" and store `0.0` — before this fix, blank
  /// silently stored `0.0` but typing the more explicit "0" was rejected as
  /// invalid, two different answers to the same question. `null` means
  /// "reject": `Infinity`/`-Infinity` and a negative value are not a real
  /// waist measurement either way. Shares `NumericGuard` with the weight
  /// parse above; only the empty-means-zero rule is local to waist.
  double? _parseWaist(String raw) {
    if (raw.trim().isEmpty) return 0.0;
    return NumericGuard.parse(raw, min: 0.0);
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
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LockoutField(
          label: 'Weight (kg)',
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        LockoutField(
          label: 'Waist (cm) - optional',
          controller: _waistCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (_error != null) ...[
          const SizedBox(height: LockoutTheme.spaceSm),
          Text(
            _error!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: LockoutTheme.spaceXs),
        Text(
          'Waist is tracked on its own. It is not used in the BMI figure — '
          'BMI is weight and height only.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        // The `_saving` re-entrancy guard used to be invisible — SAVE
        // MEASUREMENT looked identically pressable mid-save. `IgnorePointer`
        // stops a second tap from reaching `_save` at all (belt-and-braces
        // with the guard inside it), and the dimmed opacity plus relabel
        // make that state visible instead of just structurally prevented.
        // Full-width for the same reason as `_buildPlanCard`'s primary
        // action (Finding 5): a bare `FilledButton` here renders left-aligned
        // at intrinsic width instead of matching the tab-level primary
        // action's `SizedBox(width: double.infinity)`.
        SizedBox(
          width: double.infinity,
          child: Opacity(
            opacity: _saving ? 0.6 : 1.0,
            child: IgnorePointer(
              ignoring: _saving,
              child: FilledButton(
                onPressed: _save,
                child: Text(_saving ? 'Saving…' : 'Save measurement'),
              ),
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
// `showLockoutSheet`'s modal route lives in the root `Overlay`, a sibling of
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
        }

        return Column(
          children: [for (final log in logs) _row(context, log)],
        );
      },
    );
  }

  Widget _row(BuildContext context, BodyEntry log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
      child: LockoutCard(
        padding: const EdgeInsets.only(
          left: LockoutTheme.spaceMd,
          top: LockoutTheme.spaceXs,
          bottom: LockoutTheme.spaceXs,
        ),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(log.dateStr, style: LockoutTheme.numeric(context, size: 13)),
          Row(
            children: [
              Text('${log.weightKg} kg',
                  style: Theme.of(context).textTheme.titleMedium),
              if (log.waistCm > 0) ...[
                const SizedBox(width: 10),
                Text('waist ${log.waistCm} cm',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
              // `delete_outline`, not `close`: SheetScaffold already uses
              // `Icons.close` for "dismiss this sheet" and this row lives
              // inside one, so reusing it here would put the same glyph on
              // two different actions at once. The 48dp target comes from
              // IconButton's theme rather than padding wrapped by hand.
              IconButton(
                onPressed: () => onDelete(log),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  semanticLabel: 'Delete entry',
                ),
              ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
