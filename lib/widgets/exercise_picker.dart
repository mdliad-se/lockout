import 'package:flutter/material.dart';
import '../data/exercise_library.dart';
import '../data/food_search.dart';
import '../theme/lockout_theme.dart';
import 'lockout_card.dart';
import 'sheet_scaffold.dart';

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
  return showLockoutRawSheet<PickedExercise>(
    context: context,
    builder: (_) => _ExercisePickerSheet(),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  // Non-const constructor: see "Why some constructors in this app are
  // not const" at the top of lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  _ExercisePickerSheet();

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
    if (_query.trim().isNotEmpty) {
      list = searchExercises(_query, source: list).map((h) => h.item).toList();
    }
    return list;
  }

  /// True when the typed text is not an exact catalog name — lets the user add
  /// a gym-specific machine the catalog does not know about.
  bool get _canAddCustom =>
      _query.trim().isNotEmpty && ExerciseLibrary.findByName(_query) == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              padding: const EdgeInsets.fromLTRB(
                LockoutTheme.screenPadding,
                LockoutTheme.spaceSm,
                LockoutTheme.screenPadding,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pick exercise', style: theme.textTheme.titleLarge),
                  Text('${results.length} found',
                      style: theme.textTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: LockoutTheme.screenPadding),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                style: theme.textTheme.bodyLarge,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search bench, squat, cable...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close,
                              semanticLabel: 'Clear search'),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),

            // Muscle group filter strip
            SizedBox(
              height: LockoutTheme.minTouchTarget,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: LockoutTheme.screenPadding),
                itemCount: groups.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: LockoutTheme.spaceSm),
                itemBuilder: (_, i) {
                  final g = groups[i];
                  return ChoiceChip(
                    label: Text(g),
                    selected: g == _group,
                    onSelected: (_) => setState(() => _group = g),
                  );
                },
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),

            if (_canAddCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LockoutTheme.screenPadding,
                  0,
                  LockoutTheme.screenPadding,
                  LockoutTheme.spaceMd,
                ),
                child: LockoutCard(
                  color: theme.colorScheme.tertiaryContainer,
                  onTap: () => Navigator.pop(
                    context,
                    PickedExercise.custom(_searchCtrl.text.trim()),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: theme.colorScheme.onTertiaryContainer),
                      const SizedBox(width: LockoutTheme.spaceSm),
                      Expanded(
                        child: Text(
                          'Add custom: "${_searchCtrl.text.trim()}"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No match in catalog.\nType a name to add it as custom.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        LockoutTheme.screenPadding,
                        0,
                        LockoutTheme.screenPadding,
                        LockoutTheme.screenPadding +
                            MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: LockoutTheme.spaceSm),
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

  // Non-const constructor: see "Why some constructors in this app are
  // not const" at the top of lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  _ExerciseRow({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(LockoutTheme.cardPadding),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercise.muscleGroup} – ${exercise.equipment}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LockoutTheme.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
                ),
                child: Text(
                  '${exercise.defaultSets}x${exercise.defaultRepsMin}-'
                  '${exercise.defaultRepsMax}',
                  style: LockoutTheme.numeric(
                    context,
                    size: 11,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
