import 'package:flutter/material.dart';
import '../data/exercise_library.dart';
import '../data/routine_templates.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/routine_factory.dart';
import '../services/schedule_service.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/day_block.dart';
import '../widgets/day_row.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_input.dart';
import '../widgets/sheet_scaffold.dart';
import 'exercise_video_screen.dart';

/// Runs a nested sheet/pick action that resolves whether it changed
/// anything, so the caller knows whether to refresh.
typedef RefreshAfter = Future<void> Function(Future<bool?> Function() action);

class RoutinesTab extends StatefulWidget {
  const RoutinesTab({super.key});

  @override
  State<RoutinesTab> createState() => RoutinesTabState();
}

class RoutinesTabState extends State<RoutinesTab> {
  List<Routine> _routines = [];
  final Map<String, List<TrainingDay>> _routineDays = {};
  final Map<String, List<ExerciseDef>> _dayExercises = {};
  final Map<String, List<WarmupItem>> _dayWarmups = {};
  final Map<String, List<FinisherItem>> _dayFinishers = {};
  String _activeRoutineId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllRoutinesData();
  }

  /// Called by MainScreen when this tab becomes visible again.
  Future<void> reload() => _loadAllRoutinesData();

  Future<void> _loadAllRoutinesData() async {
    final db = DatabaseService.instance;
    final routines = (await db.getRoutines()).map(Routine.fromMap).toList();

    final days = <String, List<TrainingDay>>{};
    final exercises = <String, List<ExerciseDef>>{};
    final warmups = <String, List<WarmupItem>>{};
    final finishers = <String, List<FinisherItem>>{};

    for (final r in routines) {
      final dayList =
          (await db.getDaysForRoutine(r.id)).map(TrainingDay.fromMap).toList();
      days[r.id] = dayList;

      for (final d in dayList) {
        exercises[d.id] = (await db.getExercisesForDay(d.id))
            .map(ExerciseDef.fromMap)
            .toList();
        warmups[d.id] =
            (await db.getWarmupsForDay(d.id)).map(WarmupItem.fromMap).toList();
        finishers[d.id] = (await db.getFinishersForDay(d.id))
            .map(FinisherItem.fromMap)
            .toList();
      }
    }

    final active = await db.getActiveRoutine();

    if (!mounted) return;
    setState(() {
      _routines = routines;
      _routineDays
        ..clear()
        ..addAll(days);
      _dayExercises
        ..clear()
        ..addAll(exercises);
      _dayWarmups
        ..clear()
        ..addAll(warmups);
      _dayFinishers
        ..clear()
        ..addAll(finishers);
      _activeRoutineId = active == null ? '' : active['id'] as String;
      _isLoading = false;
    });
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _openVideo(String name, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseVideoScreen(exerciseName: name, videoUrl: url),
      ),
    );
  }

  /// A [TrainingDay] loaded from the DB never carries its exercises inline —
  /// they live in [_dayExercises], loaded separately. Hydrate a copy so
  /// [dayRowSummary] and [DayRow] see the real count.
  TrainingDay _hydrated(TrainingDay day) =>
      day.copyWith(exercises: _dayExercises[day.id] ?? []);

  // --- CREATE ROUTINE ---

  /// Controllers and selection state are created here, once per sheet open,
  /// rather than inside the builder passed to [showJinatraSheet] — that
  /// builder is re-invoked on every rebuild of the sheet's own drag-handling
  /// state (see `_BottomSheetState` in the framework), which would otherwise
  /// hand back fresh controllers/locals — and silently clear whatever the
  /// user had typed or picked — on a drag that does not dismiss the sheet.
  Future<void> _openCreateRoutineSheet() async {
    final nameCtrl = TextEditingController();
    var mode = SchedulingMode.weekday;
    var template = RoutineTemplate.all.first;
    try {
      final saved = await showJinatraSheet<bool>(
        context: context,
        title: 'CREATE NEW ROUTINE',
        builder: (ctx) => _buildCreateRoutineForm(
          ctx,
          nameCtrl: nameCtrl,
          mode: mode,
          template: template,
          onModeChanged: (m) => mode = m,
          onTemplateChanged: (t) => template = t,
        ),
      );
      if (saved == true && mounted) await reload();
    } finally {
      nameCtrl.dispose();
    }
  }

  Widget _buildCreateRoutineForm(
    BuildContext sheetCtx, {
    required TextEditingController nameCtrl,
    required SchedulingMode mode,
    required RoutineTemplate template,
    required ValueChanged<SchedulingMode> onModeChanged,
    required ValueChanged<RoutineTemplate> onTemplateChanged,
  }) {
    // Local copies drive this sheet instance's own rebuilds; the callbacks
    // above keep the hoisted state in `_openCreateRoutineSheet` current too,
    // so a re-invocation of this builder (a drag that doesn't dismiss) picks
    // up the last choice instead of resetting to the initial default.
    var localMode = mode;
    var localTemplate = template;

    return StatefulBuilder(
      builder: (context, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JinatraInput(
            label: 'Routine Name',
            controller: nameCtrl,
            hint: 'e.g. Push / Pull / Legs',
          ),
          Text('SCHEDULING MODE', style: JinatraTokens.monoData(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _choice(
                  label: 'WEEKDAY',
                  selected: localMode == SchedulingMode.weekday,
                  onTap: () => setSheet(() {
                    localMode = SchedulingMode.weekday;
                    onModeChanged(localMode);
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _choice(
                  label: 'ROTATING',
                  selected: localMode == SchedulingMode.rotating,
                  onTap: () => setSheet(() {
                    localMode = SchedulingMode.rotating;
                    onModeChanged(localMode);
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            localMode == SchedulingMode.weekday
                ? 'Each day is pinned to a weekday. Today\'s workout is whichever day matches today.'
                : 'Days cycle in order, one per calendar day, ignoring weekdays.',
            style: JinatraTokens.bodyText(
              fontSize: 12,
              color: JinatraTokens.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          Text('START FROM', style: JinatraTokens.monoData(fontSize: 12)),
          const SizedBox(height: 8),
          ...RoutineTemplate.all.map((t) {
            final selected = t.key == localTemplate.key;
            return GestureDetector(
              onTap: () => setSheet(() {
                localTemplate = t;
                onTemplateChanged(localTemplate);
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: JinatraTokens.cardDecoration(
                  background: selected
                      ? JinatraTokens.mistTeal
                      : JinatraTokens.paper,
                  borderColor: selected
                      ? JinatraTokens.deepTeal
                      : JinatraTokens.ink,
                  borderWidth: selected
                      ? JinatraTokens.borderControl
                      : JinatraTokens.borderDivider,
                  radius: JinatraTokens.radiusTile,
                  hasShadow: false,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: JinatraTokens.ink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              style: JinatraTokens.bodyText(
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            t.blurb,
                            style: JinatraTokens.monoData(
                              fontSize: 10,
                              color: JinatraTokens.ink
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          JinatraButton(
            label: 'SAVE ROUTINE',
            onPressed: () async {
              final typed = nameCtrl.text.trim();
              final name = typed.isNotEmpty
                  ? typed
                  : (localTemplate.key == 'blank' ? '' : localTemplate.name);
              if (name.isEmpty) return;

              await RoutineFactory.createFromTemplate(
                name: name,
                mode: localMode,
                template: localTemplate,
              );
              if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
            },
          ),
        ],
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: JinatraTokens.cardDecoration(
          background: selected ? JinatraTokens.deepTeal : JinatraTokens.paper,
          borderWidth: JinatraTokens.borderControl,
          radius: JinatraTokens.radiusTile,
          hasShadow: !selected,
          shadowOffset: JinatraTokens.shadowSm,
        ),
        child: Center(
          child: Text(
            label,
            style: JinatraTokens.monoData(
              color: selected ? JinatraTokens.onPrimary : JinatraTokens.ink,
            ),
          ),
        ),
      ),
    );
  }

  // --- ADD / EDIT TRAINING DAY ---

  /// Opens the training-day form. Resolves `true` only when the day was
  /// actually saved, so a caller that must close a parent sheet (the day
  /// detail sheet, on an edit) can tell a save apart from a dismiss.
  Future<bool?> _openDayFormSheet(String routineId, {TrainingDay? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final focusCtrl = TextEditingController(text: existing?.focus ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var tag = existing?.tag ?? ScheduleService.weekdayPickerOrder.first;
    var isRest = existing?.isRestDay ?? false;
    try {
      return await showJinatraSheet<bool>(
        context: context,
        title: existing == null ? 'ADD TRAINING DAY' : 'EDIT DAY',
        builder: (ctx) => _buildDayForm(
          ctx,
          routineId,
          existing: existing,
          nameCtrl: nameCtrl,
          focusCtrl: focusCtrl,
          noteCtrl: noteCtrl,
          tag: tag,
          isRest: isRest,
          onTagChanged: (v) => tag = v,
          onRestChanged: (v) => isRest = v,
        ),
      );
    } finally {
      nameCtrl.dispose();
      focusCtrl.dispose();
      noteCtrl.dispose();
    }
  }

  Widget _buildDayForm(
    BuildContext sheetCtx,
    String routineId, {
    TrainingDay? existing,
    required TextEditingController nameCtrl,
    required TextEditingController focusCtrl,
    required TextEditingController noteCtrl,
    required String tag,
    required bool isRest,
    required ValueChanged<String> onTagChanged,
    required ValueChanged<bool> onRestChanged,
  }) {
    var localTag = tag;
    var localIsRest = isRest;

    return StatefulBuilder(
      builder: (context, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DAY OF WEEK', style: JinatraTokens.monoData(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ScheduleService.weekdayPickerOrder.map((d) {
              final selected = localTag == d;
              return GestureDetector(
                onTap: () => setSheet(() {
                  localTag = d;
                  onTagChanged(localTag);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: JinatraTokens.cardDecoration(
                    background: selected
                        ? JinatraTokens.signal
                        : JinatraTokens.paper,
                    borderWidth: JinatraTokens.borderControl,
                    radius: JinatraTokens.radiusTile,
                    hasShadow: !selected,
                    shadowOffset: JinatraTokens.shadowSm,
                  ),
                  child: Text(d,
                      style: JinatraTokens.monoData(
                        fontSize: 12,
                        color: selected
                            ? JinatraTokens.onAccent
                            : JinatraTokens.ink,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          JinatraInput(
            label: 'Day Name',
            controller: nameCtrl,
            hint: 'e.g. Push',
          ),
          JinatraInput(
            label: 'Focus (muscle groups)',
            controller: focusCtrl,
            hint: 'e.g. Chest - Shoulders - Triceps',
          ),
          JinatraInput(
            label: 'Day Note (optional)',
            controller: noteCtrl,
            hint: 'Injury cautions, tempo rules...',
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('MARK AS REST DAY',
                    style: JinatraTokens.monoData(fontSize: 13)),
              ),
              Switch(
                value: localIsRest,
                activeThumbColor: JinatraTokens.deepTeal,
                onChanged: (v) => setSheet(() {
                  localIsRest = v;
                  onRestChanged(localIsRest);
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          JinatraButton(
            label: existing == null ? 'ADD DAY' : 'SAVE DAY',
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final dayCount = (_routineDays[routineId] ?? []).length;
              await DatabaseService.instance.insertDay(TrainingDay(
                id: existing?.id ?? _newId(),
                routineId: routineId,
                name: nameCtrl.text.trim(),
                tag: localTag,
                orderIndex: existing?.orderIndex ?? dayCount,
                focus: focusCtrl.text.trim(),
                note: noteCtrl.text.trim(),
                isRestDay: localIsRest,
              ).toMap());
              if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
            },
          ),
        ],
      ),
    );
  }

  // --- WARMUP / FINISHER ROWS ---

  /// Opens the warm-up/finisher item form. Resolves `true` only if an item
  /// was actually added.
  Future<bool?> _openSubItemSheet({
    required String dayId,
    required bool isWarmup,
    required int index,
  }) async {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    try {
      return await showJinatraSheet<bool>(
        context: context,
        title: isWarmup ? 'ADD WARM-UP ITEM' : 'ADD FINISHER ITEM',
        builder: (ctx) => _buildSubItemForm(
          ctx,
          dayId: dayId,
          isWarmup: isWarmup,
          index: index,
          nameCtrl: nameCtrl,
          amtCtrl: amtCtrl,
        ),
      );
    } finally {
      nameCtrl.dispose();
      amtCtrl.dispose();
    }
  }

  Widget _buildSubItemForm(
    BuildContext sheetCtx, {
    required String dayId,
    required bool isWarmup,
    required int index,
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JinatraInput(
          label: 'Movement',
          controller: nameCtrl,
          hint: isWarmup ? 'e.g. Arm circles' : 'e.g. Push-ups',
        ),
        JinatraInput(
          label: 'Amount',
          controller: amtCtrl,
          hint: isWarmup ? 'e.g. 3-4 min' : 'e.g. 12-15 reps',
        ),
        JinatraButton(
          label: 'ADD',
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final db = DatabaseService.instance;
            if (isWarmup) {
              await db.insertWarmup(WarmupItem(
                id: _newId(),
                dayId: dayId,
                name: nameCtrl.text.trim(),
                amt: amtCtrl.text.trim(),
                orderIndex: index,
              ).toMap());
            } else {
              await db.insertFinisher(FinisherItem(
                id: _newId(),
                dayId: dayId,
                name: nameCtrl.text.trim(),
                amt: amtCtrl.text.trim(),
                orderIndex: index,
              ).toMap());
            }
            if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
          },
        ),
      ],
    );
  }

  // --- ADD / EDIT EXERCISE ---

  /// Resolves `true` only if an exercise was added; `null`/`false` for a
  /// cancelled pick or a dismissed sheet.
  Future<bool?> _addExerciseToDay(String dayId) async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return null;

    final existing = _dayExercises[dayId] ?? [];
    return _openExerciseSheet(
      ExerciseDef(
        id: _newId(),
        dayId: dayId,
        name: picked.name,
        targetSets: picked.sets,
        targetRepsMin: picked.repsMin,
        targetRepsMax: picked.repsMax,
        muscleGroup: picked.muscleGroup,
        orderIndex: existing.length,
      ),
      isNew: true,
    );
  }

  /// Resolves `true` if the exercise was saved or removed — either way the
  /// caller's list is stale and must refresh.
  Future<bool?> _openExerciseSheet(ExerciseDef ex, {bool isNew = false}) async {
    final setsCtrl = TextEditingController(text: ex.targetSets.toString());
    final repsMinCtrl =
        TextEditingController(text: ex.targetRepsMin.toString());
    final repsMaxCtrl =
        TextEditingController(text: ex.targetRepsMax.toString());
    final weightCtrl = TextEditingController(
      text: ex.targetWeightKg == 0 ? '' : ex.targetWeightKg.toString(),
    );
    final restCtrl = TextEditingController(text: ex.restDefaultS.toString());
    final noteCtrl = TextEditingController(text: ex.note);
    final videoCtrl = TextEditingController(text: ex.videoUrl);
    try {
      return await showJinatraSheet<bool>(
        context: context,
        title: isNew ? 'ADD EXERCISE' : 'EDIT EXERCISE',
        builder: (ctx) => _buildExerciseForm(
          ctx,
          ex,
          isNew: isNew,
          setsCtrl: setsCtrl,
          repsMinCtrl: repsMinCtrl,
          repsMaxCtrl: repsMaxCtrl,
          weightCtrl: weightCtrl,
          restCtrl: restCtrl,
          noteCtrl: noteCtrl,
          videoCtrl: videoCtrl,
        ),
      );
    } finally {
      setsCtrl.dispose();
      repsMinCtrl.dispose();
      repsMaxCtrl.dispose();
      weightCtrl.dispose();
      restCtrl.dispose();
      noteCtrl.dispose();
      videoCtrl.dispose();
    }
  }

  Widget _buildExerciseForm(
    BuildContext sheetCtx,
    ExerciseDef ex, {
    bool isNew = false,
    required TextEditingController setsCtrl,
    required TextEditingController repsMinCtrl,
    required TextEditingController repsMaxCtrl,
    required TextEditingController weightCtrl,
    required TextEditingController restCtrl,
    required TextEditingController noteCtrl,
    required TextEditingController videoCtrl,
  }) {
    final group = ex.muscleGroup.isNotEmpty
        ? ex.muscleGroup
        : ExerciseLibrary.groupFor(ex.name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Not a sectionHeader: the SheetScaffold title above
                  // ("ADD EXERCISE" / "EDIT EXERCISE") already carries that
                  // weight, so this is a secondary line, not a second
                  // heading.
                  Text(ex.name.toUpperCase(),
                      style: JinatraTokens.bodyText(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  if (group.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: JinatraTokens.mistTeal,
                        border:
                            Border.all(color: JinatraTokens.ink, width: 2),
                      ),
                      child: Text(group.toUpperCase(),
                          style: JinatraTokens.monoData(fontSize: 10)),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(sheetCtx);
                _openVideo(ex.name, videoCtrl.text.trim());
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: JinatraTokens.cardDecoration(
                  background: JinatraTokens.signal,
                  borderWidth: JinatraTokens.borderControl,
                  radius: JinatraTokens.radiusPill,
                  shadowOffset: JinatraTokens.shadowSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow,
                        size: 15, color: JinatraTokens.onAccent),
                    const SizedBox(width: 4),
                    Text('WATCH',
                        style: JinatraTokens.monoData(
                            fontSize: 11, color: JinatraTokens.onAccent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: JinatraInput(
                label: 'Sets',
                controller: setsCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: JinatraInput(
                label: 'Min Reps',
                controller: repsMinCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: JinatraInput(
                label: 'Max Reps',
                controller: repsMaxCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: JinatraInput(
                label: 'Weight (kg)',
                controller: weightCtrl,
                hint: '0',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: JinatraInput(
                label: 'Rest (sec)',
                controller: restCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        JinatraInput(
          label: 'Note',
          controller: noteCtrl,
          hint: 'Cues, injury notes, tempo...',
        ),
        JinatraInput(
          label: 'Pinned Video URL (optional)',
          controller: videoCtrl,
          hint: 'Leave empty to auto-search YouTube',
        ),
        Text(
          'Empty video URL means WATCH opens a YouTube search for a 3D / '
          'animated form demo of this exercise. Paste a link to pin one.',
          style: JinatraTokens.bodyText(
            fontSize: 11,
            color: JinatraTokens.ink.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 16),
        JinatraButton(
          label: isNew ? 'ADD TO DAY' : 'SAVE CHANGES',
          onPressed: () async {
            final minReps =
                int.tryParse(repsMinCtrl.text) ?? ex.targetRepsMin;
            var maxReps =
                int.tryParse(repsMaxCtrl.text) ?? ex.targetRepsMax;
            if (maxReps < minReps) maxReps = minReps;

            await DatabaseService.instance.insertExercise(
              ex.copyWith(
                targetSets: int.tryParse(setsCtrl.text) ?? ex.targetSets,
                targetRepsMin: minReps,
                targetRepsMax: maxReps,
                targetWeightKg: double.tryParse(weightCtrl.text) ?? 0.0,
                restDefaultS:
                    int.tryParse(restCtrl.text) ?? ex.restDefaultS,
                note: noteCtrl.text.trim(),
                videoUrl: videoCtrl.text.trim(),
                muscleGroup: group,
              ).toMap(),
            );
            if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
          },
        ),
        if (!isNew) ...[
          const SizedBox(height: 10),
          JinatraButton(
            label: 'REMOVE EXERCISE',
            isSignal: true,
            onPressed: () async {
              await DatabaseService.instance.deleteExercise(ex.id);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
            },
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeleteRoutine(Routine routine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JinatraTokens.sweetCream,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: JinatraTokens.ink, width: JinatraTokens.borderControl),
          borderRadius: BorderRadius.circular(JinatraTokens.radiusCard),
        ),
        title: Text('DELETE ROUTINE?',
            style: JinatraTokens.sectionHeader(fontSize: 16)),
        content: Text(
          '"${routine.name}" and all of its training days and exercises will be '
          'removed. Past workout history is kept.',
          style: JinatraTokens.bodyText(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: JinatraTokens.monoData(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE',
                style: JinatraTokens.monoData(
                    fontSize: 12, color: JinatraTokens.signal)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await DatabaseService.instance.deleteRoutine(routine.id);
      if (!mounted) return;
      await _loadAllRoutinesData();
    }
  }

  Future<void> _setActive(Routine routine) async {
    await DatabaseService.instance.setActiveRoutine(routine.id);
    if (!mounted) return;
    await _loadAllRoutinesData();
  }

  // --- DAY DETAIL SHEET ---

  /// Opens a day's detail in a sheet rather than expanding it inline.
  ///
  /// The routine list was three levels of bordered box deep; a sheet gives
  /// the detail the whole screen and leaves the week scannable behind it.
  Future<void> _openDaySheet(Routine routine, TrainingDay day) async {
    await showJinatraSheet<void>(
      context: context,
      title: '${day.tag} - ${day.name}',
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) {
          final exercises = _dayExercises[day.id] ?? [];
          final warmups = _dayWarmups[day.id] ?? [];
          final finishers = _dayFinishers[day.id] ?? [];
          final colours = DayColours.assign(_routineDays[routine.id] ?? []);
          final accent = colours[day.id] ?? DayColours.restColour;
          final onAccent = DayColours.onColorFor(accent);
          return _buildDayDetail(
            ctx,
            setSheet,
            routine,
            day,
            exercises,
            warmups,
            finishers,
            accent,
            onAccent,
          );
        },
      ),
    );
    // No trailing `reload()` here: every mutation path reachable from
    // `_buildDayDetail` (`refreshAfter`, the warm-up/finisher remove
    // handlers, EDIT DAY, DELETE DAY) already calls `_loadAllRoutinesData()`
    // itself the moment it changes something, so `RoutinesTabState` is
    // already current by the time this sheet closes. Reloading again here
    // would re-run the N+1x3 query walk over every routine and day for
    // nothing — whether or not anything changed.
  }

  Widget _buildDayDetail(
    BuildContext sheetCtx,
    StateSetter setSheet,
    Routine routine,
    TrainingDay day,
    List<ExerciseDef> exercises,
    List<WarmupItem> warmups,
    List<FinisherItem> finishers,
    Color accent,
    Color onAccent,
  ) {
    // Runs a nested sheet/pick action, then refreshes the outer state and
    // this sheet's own content only if something actually changed — the
    // sheet route is a separate subtree from RoutinesTabState, so a reload
    // there does not repaint content already on screen here.
    Future<void> refreshAfter(Future<bool?> Function() action) async {
      final changed = await action();
      if (changed != true || !mounted) return;
      await _loadAllRoutinesData();
      if (sheetCtx.mounted) setSheet(() {});
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // v1 showed the day's focus (muscle groups) on the card's summary
        // row; `DayRow`'s signature is fixed and has no slot for it, so it
        // surfaces here instead — read-only, the edit form is where it's set.
        if (day.focus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              day.focus,
              style: JinatraTokens.monoData(
                fontSize: 11,
                color: JinatraTokens.ink.withValues(alpha: 0.65),
              ),
            ),
          ),
        if (day.note.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(9),
            decoration: JinatraTokens.cardDecoration(
              background: JinatraTokens.signal,
              borderWidth: JinatraTokens.borderControl,
              radius: JinatraTokens.radiusTile,
              hasShadow: false,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('READ FIRST',
                    style: JinatraTokens.monoData(
                        fontSize: 9, color: JinatraTokens.onAccent)),
                const SizedBox(height: 3),
                Text(day.note,
                    style: JinatraTokens.bodyText(
                        fontSize: 12, color: JinatraTokens.onAccent)),
              ],
            ),
          ),

        if (day.isRestDay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(Icons.bedtime_outlined,
                    size: 18, color: JinatraTokens.ink),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('Recovery is part of the plan.',
                      style: JinatraTokens.bodyText(
                        fontSize: 12,
                        color: JinatraTokens.ink.withValues(alpha: 0.7),
                      )),
                ),
              ],
            ),
          )
        else ...[
          // --- Warm-up ---
          if (warmups.isEmpty)
            AddLink(
              label: '+ ADD WARM-UP',
              onTap: () => refreshAfter(() => _openSubItemSheet(
                  dayId: day.id, isWarmup: true, index: 0)),
            )
          else ...[
            SectionHeading(
              title: 'Warm-Up',
              amount: '~6-8 min',
              onAdd: () => refreshAfter(() => _openSubItemSheet(
                  dayId: day.id, isWarmup: true, index: warmups.length)),
            ),
            ...warmups.asMap().entries.map((e) => SubItemRow(
                  name: e.value.name,
                  amt: e.value.amt,
                  onRemove: () async {
                    await DatabaseService.instance.deleteWarmup(e.value.id);
                    if (!mounted) return;
                    await _loadAllRoutinesData();
                    if (sheetCtx.mounted) setSheet(() {});
                  },
                )),
            const SizedBox(height: 6),
          ],

          // --- Exercises ---
          SectionHeading(
            title: 'Exercises',
            amount: exercises.isEmpty ? '' : '${exercises.length}',
          ),
          if (exercises.isEmpty)
            AddLink(
              label: '+ ADD EXERCISE',
              onTap: () => refreshAfter(() => _addExerciseToDay(day.id)),
            )
          else ...[
            ...exercises.asMap().entries.map(
                  (e) => _buildExerciseRow(
                      e.key + 1, e.value, accent, onAccent, refreshAfter),
                ),
            AddLink(
              label: '+ ADD EXERCISE',
              onTap: () => refreshAfter(() => _addExerciseToDay(day.id)),
            ),
          ],

          // --- Finisher ---
          if (finishers.isEmpty)
            AddLink(
              label: '+ ADD FINISHER',
              onTap: () => refreshAfter(() => _openSubItemSheet(
                  dayId: day.id, isWarmup: false, index: 0)),
            )
          else ...[
            SectionHeading(
              title: 'Conditioning Finisher',
              amount: 'x3 rounds',
              onAdd: () => refreshAfter(() => _openSubItemSheet(
                  dayId: day.id, isWarmup: false, index: finishers.length)),
            ),
            ...finishers.asMap().entries.map((e) => SubItemRow(
                  name: e.value.name,
                  amt: e.value.amt,
                  onRemove: () async {
                    await DatabaseService.instance.deleteFinisher(e.value.id);
                    if (!mounted) return;
                    await _loadAllRoutinesData();
                    if (sheetCtx.mounted) setSheet(() {});
                  },
                )),
          ],
        ],

        // --- Day actions ---
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final saved =
                      await _openDayFormSheet(routine.id, existing: day);
                  if (saved != true || !mounted) return;
                  await _loadAllRoutinesData();
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).maybePop();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 14, color: JinatraTokens.ink),
                    const SizedBox(width: 5),
                    Text('EDIT DAY',
                        style: JinatraTokens.monoData(fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () async {
                  await DatabaseService.instance.deleteDay(day.id);
                  if (!mounted) return;
                  await _loadAllRoutinesData();
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).maybePop();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(Icons.close, size: 14, color: JinatraTokens.signal),
                    const SizedBox(width: 5),
                    Text('DELETE DAY',
                        style: JinatraTokens.monoData(
                            fontSize: 9, color: JinatraTokens.signal)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Number, name, then target and WATCH on a second line — a long name and a
  /// target chip competing for one row forced three-line wraps.
  Widget _buildExerciseRow(
    int number,
    ExerciseDef ex,
    Color accent,
    Color onAccent,
    RefreshAfter refreshAfter,
  ) {
    return GestureDetector(
      onTap: () => refreshAfter(() => _openExerciseSheet(ex)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: JinatraTokens.cardDecoration(
          background: JinatraTokens.sweetCream,
          borderWidth: JinatraTokens.borderControl,
          radius: JinatraTokens.radiusTile,
          hasShadow: true,
          shadowOffset: JinatraTokens.shadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                border: Border.all(color: JinatraTokens.ink, width: 1),
              ),
              child: Text('$number',
                  style:
                      JinatraTokens.monoData(fontSize: 9, color: onAccent)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: JinatraTokens.bodyText(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ex.targetWeightKg > 0
                        ? '${ex.targetLabel} @ ${ex.targetWeightKg}kg'
                        : ex.targetLabel,
                    style: JinatraTokens.monoData(
                      fontSize: 10,
                      color: JinatraTokens.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openVideo(ex.name, ex.videoUrl),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: JinatraTokens.cardDecoration(
                  background: JinatraTokens.paper,
                  borderWidth: JinatraTokens.borderControl,
                  radius: JinatraTokens.radiusPill,
                  hasShadow: false,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 11, color: JinatraTokens.ink),
                    const SizedBox(width: 3),
                    Text('WATCH', style: JinatraTokens.monoData(fontSize: 8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILD ---

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
                    child: Text('WORKOUT ROUTINES',
                        style: JinatraTokens.sectionHeader())),
                JinatraButton(
                    label: '+ NEW', onPressed: _openCreateRoutineSheet),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _routines.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _routines.length,
                      itemBuilder: (ctx, i) => _buildRoutineCard(_routines[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: JinatraTokens.cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: JinatraTokens.ink),
            const SizedBox(height: 12),
            Text('NO ROUTINES YET',
                style: JinatraTokens.sectionHeader(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Tap "+ NEW" and pick a starter split. Every day arrives with a '
              'warm-up, numbered exercises and a conditioning finisher already '
              'filled in.',
              textAlign: TextAlign.center,
              style: JinatraTokens.bodyText(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard(Routine routine) {
    final days = _routineDays[routine.id] ?? [];
    final isActive = routine.id == _activeRoutineId;
    final todayCode = ScheduleService.weekdayCode(DateTime.now());

    return JinatraCard(
      shadowOffset: JinatraTokens.shadowLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routine.name,
                  style: JinatraTokens.sectionHeader(fontSize: 18),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: JinatraTokens.ink),
                color: JinatraTokens.paper,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(JinatraTokens.radiusTile),
                  side: BorderSide(
                      color: JinatraTokens.ink,
                      width: JinatraTokens.borderControl),
                ),
                onSelected: (v) {
                  if (v == 'active') _setActive(routine);
                  if (v == 'delete') _confirmDeleteRoutine(routine);
                },
                // v1 hid SET AS ACTIVE once the routine was already active;
                // a fixed two-item menu can't express that, so filter here.
                itemBuilder: (_) => [
                  if (!isActive)
                    PopupMenuItem(
                      value: 'active',
                      child: Text('SET AS ACTIVE',
                          style: JinatraTokens.monoData(fontSize: 12)),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('DELETE',
                        style: JinatraTokens.monoData(
                            fontSize: 12, color: JinatraTokens.signal)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(routine.schedulingMode.name.toUpperCase(),
                  JinatraTokens.mistTeal),
              _tag('${days.length} DAYS', JinatraTokens.mistTeal),
              if (isActive) _tag('ACTIVE', JinatraTokens.signal, filled: true),
            ],
          ),
          const Divider(height: 22, thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TRAINING WEEK', style: JinatraTokens.monoData(fontSize: 12)),
              GestureDetector(
                onTap: () async {
                  final saved = await _openDayFormSheet(routine.id);
                  if (saved == true && mounted) await reload();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: JinatraTokens.cardDecoration(
                    background: JinatraTokens.deepTeal,
                    borderWidth: JinatraTokens.borderControl,
                    radius: JinatraTokens.radiusPill,
                    shadowOffset: JinatraTokens.shadowSm,
                  ),
                  child: Text('+ ADD DAY',
                      style: JinatraTokens.monoData(
                          color: JinatraTokens.onPrimary, fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (days.isEmpty)
            Text(
              'No training days yet. Tap "+ ADD DAY" to pin a workout to a weekday.',
              style: JinatraTokens.bodyText(
                fontSize: 12,
                color: JinatraTokens.ink.withValues(alpha: 0.6),
              ),
            )
          else
            // One assignment per routine: the uniqueness rule is only
            // meaningful across the whole week.
            ...(() {
              final colours = DayColours.assign(days);
              return days.map((d) {
                final hydrated = _hydrated(d);
                return DayRow(
                  day: hydrated,
                  accent: colours[d.id] ?? DayColours.restColour,
                  summary: dayRowSummary(hydrated),
                  isToday: isActive &&
                      routine.schedulingMode == SchedulingMode.weekday &&
                      d.tag.toUpperCase() == todayCode,
                  onTap: () => _openDaySheet(routine, d),
                );
              }).toList();
            })(),
        ],
      ),
    );
  }

  /// A day tag/status chip. Outline by default; filled only for the
  /// currently-active routine's ACTIVE badge, so the header reads calmer.
  Widget _tag(String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: JinatraTokens.cardDecoration(
        background: filled ? color : Colors.transparent,
        borderColor: filled ? JinatraTokens.ink : color,
        borderWidth: JinatraTokens.borderDivider,
        hasShadow: false,
        radius: JinatraTokens.radiusPill,
      ),
      child: Text(
        label,
        style: JinatraTokens.monoData(
          fontSize: 9,
          color: filled ? JinatraTokens.onAccentColor(color) : color,
        ),
      ),
    );
  }
}
