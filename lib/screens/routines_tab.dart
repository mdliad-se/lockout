import 'package:flutter/material.dart';
import '../data/exercise_library.dart';
import '../data/routine_templates.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/routine_factory.dart';
import '../services/schedule_service.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/day_block.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_input.dart';
import 'exercise_video_screen.dart';

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

  /// Days currently expanded. Every day rendered open at once turned a 4-day
  /// plan into an unreadable scroll, so days collapse to a summary row and
  /// today's day is opened automatically.
  final Set<String> _expandedDays = {};

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

      // Open today's day so the screen lands on what matters now.
      final todayCode = ScheduleService.weekdayCode(DateTime.now());
      for (final dayList in days.values) {
        for (final d in dayList) {
          if (d.tag.toUpperCase() == todayCode && !d.isRestDay) {
            _expandedDays.add(d.id);
          }
        }
      }
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

  // --- CREATE ROUTINE ---

  void _showCreateRoutineModal() {
    final nameCtrl = TextEditingController();
    var mode = SchedulingMode.weekday;
    var template = RoutineTemplate.all.first;

    showModalBottomSheet(
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
                Text('CREATE NEW ROUTINE',
                    style: JinatraTokens.sectionHeader()),
                const SizedBox(height: 16),
                JinatraInput(
                  label: 'Routine Name',
                  controller: nameCtrl,
                  hint: 'e.g. Push / Pull / Legs',
                ),
                Text('SCHEDULING MODE',
                    style: JinatraTokens.monoData(fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _choice(
                        label: 'WEEKDAY',
                        selected: mode == SchedulingMode.weekday,
                        onTap: () =>
                            setSheet(() => mode = SchedulingMode.weekday),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _choice(
                        label: 'ROTATING',
                        selected: mode == SchedulingMode.rotating,
                        onTap: () =>
                            setSheet(() => mode = SchedulingMode.rotating),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  mode == SchedulingMode.weekday
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
                  final selected = t.key == template.key;
                  return GestureDetector(
                    onTap: () => setSheet(() => template = t),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? JinatraTokens.mistTeal
                            : JinatraTokens.paper,
                        border: Border.all(
                          color: selected
                              ? JinatraTokens.deepTeal
                              : JinatraTokens.ink,
                          width: selected ? 3 : 2,
                        ),
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
                        : (template.key == 'blank' ? '' : template.name);
                    if (name.isEmpty) return;

                    await RoutineFactory.createFromTemplate(
                      name: name,
                      mode: mode,
                      template: template,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadAllRoutinesData();
                  },
                ),
              ],
            ),
          ),
        ),
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
        decoration: BoxDecoration(
          color: selected ? JinatraTokens.deepTeal : JinatraTokens.paper,
          border: Border.all(color: JinatraTokens.ink, width: 3),
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

  void _showDayModal(String routineId, {TrainingDay? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final focusCtrl = TextEditingController(text: existing?.focus ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var tag = existing?.tag ?? ScheduleService.weekdayPickerOrder.first;
    var isRest = existing?.isRestDay ?? false;

    showModalBottomSheet(
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
                Text(existing == null ? 'ADD TRAINING DAY' : 'EDIT DAY',
                    style: JinatraTokens.sectionHeader()),
                const SizedBox(height: 14),
                Text('DAY OF WEEK', style: JinatraTokens.monoData(fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ScheduleService.weekdayPickerOrder.map((d) {
                    final selected = tag == d;
                    return GestureDetector(
                      onTap: () => setSheet(() => tag = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? JinatraTokens.signal
                              : JinatraTokens.paper,
                          border:
                              Border.all(color: JinatraTokens.ink, width: 2),
                          boxShadow: selected
                              ? null
                              : [JinatraTokens.hardShadow(offset: 2)],
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
                      value: isRest,
                      activeThumbColor: JinatraTokens.deepTeal,
                      onChanged: (v) => setSheet(() => isRest = v),
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
                      tag: tag,
                      orderIndex: existing?.orderIndex ?? dayCount,
                      focus: focusCtrl.text.trim(),
                      note: noteCtrl.text.trim(),
                      isRestDay: isRest,
                    ).toMap());
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadAllRoutinesData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WARMUP / FINISHER ROWS ---

  Future<void> _addSubItem({
    required String dayId,
    required bool isWarmup,
    required int index,
  }) async {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    await showModalBottomSheet(
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
            Text(isWarmup ? 'ADD WARM-UP ITEM' : 'ADD FINISHER ITEM',
                style: JinatraTokens.sectionHeader(fontSize: 17)),
            const SizedBox(height: 14),
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
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAllRoutinesData();
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- ADD EXERCISE ---

  Future<void> _addExerciseToDay(String dayId) async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;

    final existing = _dayExercises[dayId] ?? [];
    await _showExerciseSheet(
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

  Future<void> _showExerciseSheet(ExerciseDef ex, {bool isNew = false}) async {
    final setsCtrl = TextEditingController(text: ex.targetSets.toString());
    final repsMinCtrl = TextEditingController(text: ex.targetRepsMin.toString());
    final repsMaxCtrl = TextEditingController(text: ex.targetRepsMax.toString());
    final weightCtrl = TextEditingController(
      text: ex.targetWeightKg == 0 ? '' : ex.targetWeightKg.toString(),
    );
    final restCtrl = TextEditingController(text: ex.restDefaultS.toString());
    final noteCtrl = TextEditingController(text: ex.note);
    final videoCtrl = TextEditingController(text: ex.videoUrl);

    final group = ex.muscleGroup.isNotEmpty
        ? ex.muscleGroup
        : ExerciseLibrary.groupFor(ex.name);

    await showModalBottomSheet(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.name.toUpperCase(),
                            style: JinatraTokens.sectionHeader(fontSize: 18)),
                        if (group.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: JinatraTokens.mistTeal,
                              border: Border.all(
                                  color: JinatraTokens.ink, width: 2),
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
                      Navigator.pop(ctx);
                      _openVideo(ex.name, videoCtrl.text.trim());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: JinatraTokens.signal,
                        border: Border.all(color: JinatraTokens.ink, width: 2),
                        boxShadow: [JinatraTokens.hardShadow(offset: 3)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow,
                              size: 15, color: JinatraTokens.onAccent),
                          const SizedBox(width: 4),
                          Text('WATCH',
                              style: JinatraTokens.monoData(
                                  fontSize: 11,
                                  color: JinatraTokens.onAccent)),
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
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadAllRoutinesData();
                },
              ),
              if (!isNew) ...[
                const SizedBox(height: 10),
                JinatraButton(
                  label: 'REMOVE EXERCISE',
                  isSignal: true,
                  onPressed: () async {
                    await DatabaseService.instance.deleteExercise(ex.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadAllRoutinesData();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRoutine(Routine routine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JinatraTokens.sweetCream,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JinatraTokens.ink, width: 3),
          borderRadius: BorderRadius.zero,
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
      await _loadAllRoutinesData();
    }
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
                    label: '+ NEW', onPressed: _showCreateRoutineModal),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine.name,
                        style: JinatraTokens.sectionHeader(fontSize: 18)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _tag(routine.schedulingMode.name.toUpperCase(),
                            JinatraTokens.mistTeal, JinatraTokens.ink),
                        _tag('${days.length} DAYS', JinatraTokens.mistTeal,
                            JinatraTokens.ink),
                        if (isActive)
                          _tag('ACTIVE', JinatraTokens.signal,
                              JinatraTokens.onAccent),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: JinatraTokens.ink),
                onPressed: () => _confirmDeleteRoutine(routine),
              ),
            ],
          ),
          if (!isActive) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                await DatabaseService.instance.setActiveRoutine(routine.id);
                await _loadAllRoutinesData();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: JinatraTokens.paper,
                  border: Border.all(color: JinatraTokens.ink, width: 2),
                  boxShadow: [JinatraTokens.hardShadow(offset: 2)],
                ),
                child: Text('SET AS ACTIVE',
                    style: JinatraTokens.monoData(fontSize: 10)),
              ),
            ),
          ],
          const Divider(height: 22, thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TRAINING WEEK', style: JinatraTokens.monoData(fontSize: 12)),
              GestureDetector(
                onTap: () => _showDayModal(routine.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: JinatraTokens.deepTeal,
                    border: Border.all(color: JinatraTokens.ink, width: 2),
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
              return days
                  .map((d) => _buildDayCard(
                        routine,
                        d,
                        colours[d.id] ?? DayColours.restColour,
                        isToday: isActive &&
                            routine.schedulingMode ==
                                SchedulingMode.weekday &&
                            d.tag.toUpperCase() == todayCode,
                      ))
                  .toList();
            })(),
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: JinatraTokens.ink, width: 2),
      ),
      child: Text(label, style: JinatraTokens.monoData(fontSize: 10, color: fg)),
    );
  }

  Widget _buildDayCard(Routine routine, TrainingDay day, Color accent,
      {required bool isToday}) {
    final exercises = _dayExercises[day.id] ?? [];
    final warmups = _dayWarmups[day.id] ?? [];
    final finishers = _dayFinishers[day.id] ?? [];
    final onAccent = DayColours.onColorFor(accent);
    final isOpen = _expandedDays.contains(day.id);

    final setCount = exercises.fold<int>(0, (sum, e) => sum + e.targetSets);
    // Kept terse: the count must survive on one line next to a long focus.
    final summary = day.isRestDay
        ? 'REST'
        : exercises.isEmpty
            ? 'EMPTY'
            : '${exercises.length} EX - $setCount SETS';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: JinatraTokens.paper,
        border: Border.all(
          color: isToday ? JinatraTokens.deepTeal : JinatraTokens.ink,
          width: isToday ? 3 : 2,
        ),
        boxShadow: [JinatraTokens.hardShadow(offset: isOpen ? 4 : 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Summary row: the whole thing is the expand target ---
          GestureDetector(
            onTap: () => setState(() {
              if (isOpen) {
                _expandedDays.remove(day.id);
              } else {
                _expandedDays.add(day.id);
              }
            }),
            behavior: HitTestBehavior.opaque,
            child: Container(
              // The whole bar carries the day's colour, as in the printed
              // plan — a small tinted chip did not separate days enough.
              color: accent,
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: onAccent,
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                    ),
                    child: Text(day.tag,
                        style: JinatraTokens.monoData(
                            fontSize: 11, color: accent)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                day.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: JinatraTokens.sectionHeader(
                                    fontSize: 16, color: onAccent),
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: onAccent,
                                  border: Border.all(
                                      color: JinatraTokens.ink, width: 1),
                                ),
                                child: Text('TODAY',
                                    style: JinatraTokens.monoData(
                                        fontSize: 7, color: accent)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Only the focus may truncate; the exercise and
                            // set count always stays readable.
                            if (day.focus.isNotEmpty)
                              Flexible(
                                child: Text(
                                  day.focus,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: JinatraTokens.monoData(
                                    fontSize: 9,
                                    color: onAccent.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            if (day.focus.isNotEmpty)
                              Text('  -  ',
                                  style: JinatraTokens.monoData(
                                    fontSize: 9,
                                    color: onAccent.withValues(alpha: 0.8),
                                  )),
                            Text(
                              summary,
                              style: JinatraTokens.monoData(
                                fontSize: 9,
                                color: onAccent.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: onAccent,
                  ),
                ],
              ),
            ),
          ),

          if (isOpen) _buildDayDetail(routine, day, exercises, warmups,
              finishers, accent, onAccent),
        ],
      ),
    );
  }

  Widget _buildDayDetail(
    Routine routine,
    TrainingDay day,
    List<ExerciseDef> exercises,
    List<WarmupItem> warmups,
    List<FinisherItem> finishers,
    Color accent,
    Color onAccent,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 4, 11, 11),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: JinatraTokens.ink, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day.note.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: JinatraTokens.signal,
                border: Border.all(color: JinatraTokens.ink, width: 2),
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
                onTap: () => _addSubItem(
                    dayId: day.id, isWarmup: true, index: 0),
              )
            else ...[
              SectionHeading(
                title: 'Warm-Up',
                amount: '~6-8 min',
                onAdd: () => _addSubItem(
                    dayId: day.id, isWarmup: true, index: warmups.length),
              ),
              ...warmups.asMap().entries.map((e) => SubItemRow(
                    name: e.value.name,
                    amt: e.value.amt,
                    onRemove: () async {
                      await DatabaseService.instance
                          .deleteWarmup(e.value.id);
                      await _loadAllRoutinesData();
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
                onTap: () => _addExerciseToDay(day.id),
              )
            else ...[
              ...exercises.asMap().entries.map(
                    (e) => _buildExerciseRow(
                        e.key + 1, e.value, accent, onAccent),
                  ),
              AddLink(
                label: '+ ADD EXERCISE',
                onTap: () => _addExerciseToDay(day.id),
              ),
            ],

            // --- Finisher ---
            if (finishers.isEmpty)
              AddLink(
                label: '+ ADD FINISHER',
                onTap: () => _addSubItem(
                    dayId: day.id, isWarmup: false, index: 0),
              )
            else ...[
              SectionHeading(
                title: 'Conditioning Finisher',
                amount: 'x3 rounds',
                onAdd: () => _addSubItem(
                    dayId: day.id, isWarmup: false, index: finishers.length),
              ),
              ...finishers.asMap().entries.map((e) => SubItemRow(
                    name: e.value.name,
                    amt: e.value.amt,
                    onRemove: () async {
                      await DatabaseService.instance
                          .deleteFinisher(e.value.id);
                      await _loadAllRoutinesData();
                    },
                  )),
            ],
          ],

          // --- Day actions, only while open ---
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showDayModal(routine.id, existing: day),
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
                    await _loadAllRoutinesData();
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
      ),
    );
  }

  /// Number, name, then target and WATCH on a second line — a long name and a
  /// target chip competing for one row forced three-line wraps.
  Widget _buildExerciseRow(
      int number, ExerciseDef ex, Color accent, Color onAccent) {
    return GestureDetector(
      onTap: () => _showExerciseSheet(ex),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: JinatraTokens.sweetCream,
          border: Border.all(color: JinatraTokens.ink, width: 2),
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
                decoration: BoxDecoration(
                  color: JinatraTokens.paper,
                  border: Border.all(color: JinatraTokens.ink, width: 2),
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
}
