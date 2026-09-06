import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_input.dart';

class RoutinesTab extends StatefulWidget {
  const RoutinesTab({super.key});

  @override
  State<RoutinesTab> createState() => _RoutinesTabState();
}

class _RoutinesTabState extends State<RoutinesTab> {
  List<Routine> _routines = [];
  Map<String, List<TrainingDay>> _routineDays = {};
  Map<String, List<ExerciseDef>> _dayExercises = {};
  bool _isLoading = true;

  final List<String> _weekDays = ['SAT', 'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI'];

  @override
  void initState() {
    super.initState();
    _loadAllRoutinesData();
  }

  Future<void> _loadAllRoutinesData() async {
    final rRows = await DatabaseService.instance.getRoutines();
    final routines = rRows.map((r) => Routine.fromMap(r)).toList();

    Map<String, List<TrainingDay>> daysMap = {};
    Map<String, List<ExerciseDef>> exMap = {};

    for (var r in routines) {
      final dRows = await DatabaseService.instance.getDaysForRoutine(r.id);
      final days = dRows.map((d) => TrainingDay.fromMap(d)).toList();
      daysMap[r.id] = days;

      for (var d in days) {
        final eRows = await DatabaseService.instance.getExercisesForDay(d.id);
        exMap[d.id] = eRows.map((e) => ExerciseDef.fromMap(e)).toList();
      }
    }

    setState(() {
      _routines = routines;
      _routineDays = daysMap;
      _dayExercises = exMap;
      _isLoading = false;
    });
  }

  // --- MODAL: CREATE ROUTINE ---
  void _showCreateRoutineModal() {
    final nameCtrl = TextEditingController();
    SchedulingMode selectedMode = SchedulingMode.weekday;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JinatraTokens.sweetCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
              Text('CREATE NEW ROUTINE', style: JinatraTokens.sectionHeader()),
              const SizedBox(height: 16),
              JinatraInput(
                label: 'Routine Name',
                controller: nameCtrl,
                hint: 'e.g. 5-Day Push/Pull/Legs Split',
              ),
              Text('SCHEDULING MODE', style: JinatraTokens.monoData(fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedMode = SchedulingMode.weekday),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedMode == SchedulingMode.weekday
                              ? JinatraTokens.deepTeal
                              : JinatraTokens.paper,
                          border: Border.all(color: JinatraTokens.ink, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            'WEEKDAY',
                            style: JinatraTokens.monoData(
                              color: selectedMode == SchedulingMode.weekday
                                  ? Colors.white
                                  : JinatraTokens.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedMode = SchedulingMode.rotating),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedMode == SchedulingMode.rotating
                              ? JinatraTokens.deepTeal
                              : JinatraTokens.paper,
                          border: Border.all(color: JinatraTokens.ink, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            'ROTATING',
                            style: JinatraTokens.monoData(
                              color: selectedMode == SchedulingMode.rotating
                                  ? Colors.white
                                  : JinatraTokens.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              JinatraButton(
                label: 'SAVE ROUTINE',
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final routine = Routine(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    schedulingMode: selectedMode,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  await DatabaseService.instance.insertRoutine(routine.toMap());
                  Navigator.pop(ctx);
                  _loadAllRoutinesData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODAL: ADD TRAINING DAY WITH DAY PICKER ---
  void _showAddDayModal(String routineId) {
    final dayNameCtrl = TextEditingController();
    String selectedTag = 'SAT';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JinatraTokens.sweetCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
              Text('ADD TRAINING DAY', style: JinatraTokens.sectionHeader()),
              const SizedBox(height: 14),
              Text('SELECT DAY OF WEEK / TAG', style: JinatraTokens.monoData(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekDays.map((dayTag) {
                  final isSelected = selectedTag == dayTag;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedTag = dayTag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? JinatraTokens.deepTeal : JinatraTokens.paper,
                        border: Border.all(color: JinatraTokens.ink, width: 2),
                      ),
                      child: Text(
                        dayTag,
                        style: JinatraTokens.monoData(
                          color: isSelected ? Colors.white : JinatraTokens.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              JinatraInput(
                label: 'Day Name / Focus',
                controller: dayNameCtrl,
                hint: 'e.g. Push (Chest & Shoulders)',
              ),
              const SizedBox(height: 16),
              JinatraButton(
                label: 'ADD DAY TO ROUTINE',
                onPressed: () async {
                  if (dayNameCtrl.text.trim().isEmpty) return;
                  final currentDays = _routineDays[routineId] ?? [];
                  final newDay = TrainingDay(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    routineId: routineId,
                    name: dayNameCtrl.text.trim(),
                    tag: selectedTag,
                    orderIndex: currentDays.length,
                  );
                  await DatabaseService.instance.insertDay(newDay.toMap());
                  Navigator.pop(ctx);
                  _loadAllRoutinesData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODAL: ADD EXERCISE TO DAY ---
  void _showAddExerciseModal(String dayId) {
    final exNameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsMinCtrl = TextEditingController(text: '10');
    final repsMaxCtrl = TextEditingController(text: '12');
    final weightCtrl = TextEditingController(text: '0');
    final videoCtrl = TextEditingController();

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
              Text('ADD EXERCISE', style: JinatraTokens.sectionHeader()),
              const SizedBox(height: 14),
              JinatraInput(label: 'Exercise Name', controller: exNameCtrl, hint: 'e.g. Bench Press'),
              Row(
                children: [
                  Expanded(child: JinatraInput(label: 'Target Sets', controller: setsCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: JinatraInput(label: 'Min Reps', controller: repsMinCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: JinatraInput(label: 'Max Reps', controller: repsMaxCtrl, keyboardType: TextInputType.number)),
                ],
              ),
              JinatraInput(label: 'Target Weight (kg)', controller: weightCtrl, keyboardType: TextInputType.number),
              JinatraInput(label: 'YouTube Form Guide URL (Optional)', controller: videoCtrl, hint: 'https://youtube.com/...'),
              const SizedBox(height: 12),
              JinatraButton(
                label: 'SAVE EXERCISE',
                onPressed: () async {
                  if (exNameCtrl.text.trim().isEmpty) return;
                  final ex = ExerciseDef(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    dayId: dayId,
                    name: exNameCtrl.text.trim(),
                    targetSets: int.tryParse(setsCtrl.text) ?? 3,
                    targetRepsMin: int.tryParse(repsMinCtrl.text) ?? 10,
                    targetRepsMax: int.tryParse(repsMaxCtrl.text) ?? 12,
                    targetWeightKg: double.tryParse(weightCtrl.text) ?? 0.0,
                    videoUrl: videoCtrl.text.trim(),
                  );
                  await DatabaseService.instance.insertExercise(ex.toMap());
                  Navigator.pop(ctx);
                  _loadAllRoutinesData();
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
                Text('WORKOUT ROUTINES', style: JinatraTokens.sectionHeader()),
                JinatraButton(
                  label: '+ NEW ROUTINE',
                  onPressed: _showCreateRoutineModal,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_routines.isEmpty)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: JinatraTokens.paper,
                      border: Border.all(color: JinatraTokens.ink, width: 3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fitness_center, size: 48, color: JinatraTokens.ink),
                        const SizedBox(height: 12),
                        Text(
                          'NO ROUTINES CREATED YET',
                          style: JinatraTokens.sectionHeader(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'LOCKOUT starts empty. Tap "+ NEW ROUTINE" to build your custom split, then add training days (Sat, Sun, Mon, etc.).',
                          textAlign: TextAlign.center,
                          style: JinatraTokens.bodyText(),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _routines.length,
                  itemBuilder: (ctx, rIdx) {
                    final routine = _routines[rIdx];
                    final days = _routineDays[routine.id] ?? [];

                    return JinatraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Routine Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(routine.name, style: JinatraTokens.sectionHeader(fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: JinatraTokens.mistTeal,
                                      border: Border.all(color: JinatraTokens.ink, width: 2),
                                    ),
                                    child: Text(
                                      routine.schedulingMode.name.toUpperCase(),
                                      style: JinatraTokens.monoData(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: JinatraTokens.ink),
                                    onPressed: () async {
                                      await DatabaseService.instance.deleteRoutine(routine.id);
                                      _loadAllRoutinesData();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: JinatraTokens.ink, height: 20, thickness: 2),

                          // Training Days Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TRAINING DAYS (${days.length})', style: JinatraTokens.monoData(fontSize: 12)),
                              GestureDetector(
                                onTap: () => _showAddDayModal(routine.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: JinatraTokens.deepTeal,
                                    border: Border.all(color: JinatraTokens.ink, width: 2),
                                  ),
                                  child: Text('+ ADD DAY', style: JinatraTokens.monoData(color: Colors.white, fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (days.isEmpty)
                            Text(
                              'No training days added. Tap "+ ADD DAY" to set up Saturday Push, Sunday Pull, etc.',
                              style: JinatraTokens.bodyText(fontSize: 12, color: JinatraTokens.ink.withOpacity(0.6)),
                            )
                          else
                            Column(
                              children: days.map((day) {
                                final exercises = _dayExercises[day.id] ?? [];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: JinatraTokens.sweetCream,
                                    border: Border.all(color: JinatraTokens.ink, width: 2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: JinatraTokens.signal,
                                                  border: Border.all(color: JinatraTokens.ink, width: 2),
                                                ),
                                                child: Text(
                                                  day.tag,
                                                  style: JinatraTokens.monoData(fontSize: 12, color: JinatraTokens.ink),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(day.name, style: JinatraTokens.sectionHeader(fontSize: 15)),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _showAddExerciseModal(day.id),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: JinatraTokens.paper,
                                                    border: Border.all(color: JinatraTokens.ink, width: 2),
                                                  ),
                                                  child: Text('+ EXERCISE', style: JinatraTokens.monoData(fontSize: 10)),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 18),
                                                onPressed: () async {
                                                  await DatabaseService.instance.deleteDay(day.id);
                                                  _loadAllRoutinesData();
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (exercises.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Column(
                                          children: exercises.map((ex) {
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(ex.name, style: JinatraTokens.bodyText(fontWeight: FontWeight.w600)),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: JinatraTokens.mistTeal,
                                                      border: Border.all(color: JinatraTokens.ink, width: 1),
                                                    ),
                                                    child: Text(
                                                      '${ex.targetSets}x${ex.targetRepsMin}-${ex.targetRepsMax} @ ${ex.targetWeightKg}kg',
                                                      style: JinatraTokens.monoData(fontSize: 11),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
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
