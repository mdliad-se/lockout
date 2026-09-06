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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final rows = await DatabaseService.instance.getRoutines();
    setState(() {
      _routines = rows.map((r) => Routine.fromMap(r)).toList();
      _isLoading = false;
    });
  }

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
                hint: 'e.g. 5-Day Push/Pull/Legs',
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
                  _loadRoutines();
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
            const SizedBox(height: 20),
            if (_routines.isEmpty)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: JinatraTokens.paper,
                      border: Border.all(
                        color: JinatraTokens.ink,
                        width: 3,
                      ),
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
                          'LOCKOUT starts empty. Tap "+ NEW ROUTINE" to build your custom training split.',
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
                  itemBuilder: (ctx, idx) {
                    final routine = _routines[idx];
                    return JinatraCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                routine.name,
                                style: JinatraTokens.sectionHeader(fontSize: 18),
                              ),
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
                          IconButton(
                            icon: const Icon(Icons.delete, color: JinatraTokens.ink),
                            onPressed: () async {
                              await DatabaseService.instance.deleteRoutine(routine.id);
                              _loadRoutines();
                            },
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
