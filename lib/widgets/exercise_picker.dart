import 'package:flutter/material.dart';
import '../data/exercise_library.dart';
import '../theme/jinatra_tokens.dart';

/// Result of the picker: either a catalog entry or a user-typed custom name.
class PickedExercise {
  final String name;
  final String muscleGroup;
  final int sets;
  final int repsMin;
  final int repsMax;

  const PickedExercise({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
  });

  factory PickedExercise.fromLibrary(LibraryExercise e) => PickedExercise(
        name: e.name,
        muscleGroup: e.muscleGroup,
        sets: e.defaultSets,
        repsMin: e.defaultRepsMin,
        repsMax: e.defaultRepsMax,
      );

  factory PickedExercise.custom(String name) => PickedExercise(
        name: name,
        muscleGroup: '',
        sets: 3,
        repsMin: 10,
        repsMax: 12,
      );
}

/// Full-height searchable catalog picker. Returns null when dismissed.
Future<PickedExercise?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<PickedExercise>(
    context: context,
    isScrollControlled: true,
    backgroundColor: JinatraTokens.sweetCream,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => const _ExercisePickerSheet(),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _group = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LibraryExercise> get _results {
    var list = _group == 'All'
        ? ExerciseLibrary.all
        : ExerciseLibrary.byGroup(_group);
    if (_query.isNotEmpty) {
      list = list.where((e) => e.matches(_query)).toList();
    }
    return list;
  }

  /// True when the typed text is not an exact catalog name — lets the user add
  /// a gym-specific machine the catalog does not know about.
  bool get _canAddCustom =>
      _query.trim().isNotEmpty && ExerciseLibrary.findByName(_query) == null;

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final groups = ['All', ...ExerciseLibrary.muscleGroups];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PICK EXERCISE', style: JinatraTokens.sectionHeader()),
                  Text(
                    '${results.length} FOUND',
                    style: JinatraTokens.monoData(
                      fontSize: 11,
                      color: JinatraTokens.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: JinatraTokens.paper,
                  border: Border.all(color: JinatraTokens.ink, width: JinatraTokens.borderControl),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  style: JinatraTokens.bodyText(fontWeight: FontWeight.w600),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search bench, squat, cable...',
                    hintStyle: JinatraTokens.bodyText(
                      color: JinatraTokens.ink.withValues(alpha: 0.45),
                    ),
                    prefixIcon: Icon(Icons.search, color: JinatraTokens.ink, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close, size: 18, color: JinatraTokens.ink),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Muscle group filter strip
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final g = groups[i];
                  final active = g == _group;
                  return GestureDetector(
                    onTap: () => setState(() => _group = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? JinatraTokens.deepTeal : JinatraTokens.paper,
                        border: Border.all(color: JinatraTokens.ink, width: 2),
                        boxShadow: active ? null : [JinatraTokens.hardShadow(offset: 2)],
                      ),
                      child: Text(
                        g.toUpperCase(),
                        style: JinatraTokens.monoData(
                          fontSize: 11,
                          color: active ? JinatraTokens.onPrimary : JinatraTokens.ink,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            if (_canAddCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap: () => Navigator.pop(
                    context,
                    PickedExercise.custom(_searchCtrl.text.trim()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JinatraTokens.signal,
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                      boxShadow: [JinatraTokens.hardShadow(offset: 3)],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18, color: JinatraTokens.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ADD CUSTOM: "${_searchCtrl.text.trim()}"',
                            style: JinatraTokens.monoData(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'NO MATCH IN CATALOG\nType a name to add it as custom.',
                        textAlign: TextAlign.center,
                        style: JinatraTokens.monoData(
                          color: JinatraTokens.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: results.length,
                      itemBuilder: (_, i) => _ExerciseRow(
                        exercise: results[i],
                        onTap: () => Navigator.pop(
                          context,
                          PickedExercise.fromLibrary(results[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final LibraryExercise exercise;
  final VoidCallback onTap;

  const _ExerciseRow({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: JinatraTokens.paper,
          border: Border.all(color: JinatraTokens.ink, width: 2),
          boxShadow: [JinatraTokens.hardShadow(offset: 3)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: JinatraTokens.bodyText(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exercise.muscleGroup.toUpperCase()} - ${exercise.equipment.toUpperCase()}',
                    style: JinatraTokens.monoData(
                      fontSize: 10,
                      color: JinatraTokens.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: JinatraTokens.mistTeal,
                border: Border.all(color: JinatraTokens.ink, width: 1),
              ),
              child: Text(
                '${exercise.defaultSets}x${exercise.defaultRepsMin}-${exercise.defaultRepsMax}',
                style: JinatraTokens.monoData(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
