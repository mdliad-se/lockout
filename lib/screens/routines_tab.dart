import 'package:flutter/material.dart';
import '../data/exercise_library.dart';
import '../data/routine_templates.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/numeric_guard.dart';
import '../services/routine_factory.dart';
import '../services/routine_focus.dart';
import '../services/schedule_service.dart';
import '../theme/lockout_semantics.dart';
import '../theme/lockout_theme.dart';
import '../widgets/day_block.dart';
import '../widgets/lockout_card.dart';
import '../widgets/lockout_field.dart';
import '../widgets/today_day_card.dart';
import '../widgets/week_day_row.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/sheet_scaffold.dart';
import 'exercise_video_screen.dart';

/// Runs a nested sheet/pick action that resolves whether it changed
/// anything, so the caller knows whether to refresh.
typedef RefreshAfter = Future<void> Function(Future<bool?> Function() action);

/// A fresh row id. Time-based rather than a counter/uuid dependency; every
/// caller inserts immediately, so collision would require two inserts in the
/// same microsecond.
String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

class RoutinesTab extends StatefulWidget {
  /// Starts today's scheduled session from the featured-day card.
  ///
  /// `MainScreen` wires this to the Home tab's own session starter, so the
  /// user presses Start once here instead of being sent to Home to press a
  /// second button. Null when the tab is pumped standalone (widget tests), in
  /// which case the card simply offers no Start.
  final VoidCallback? onStartToday;

  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart. This tab
  // lives in `MainScreen`'s `IndexedStack` and never unmounts, so a skipped
  // rebuild would strand it in the old palette for the process lifetime.
  // ignore: prefer_const_constructors_in_immutables
  RoutinesTab({super.key, this.onStartToday});

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

  /// Opens the create-routine form. `_CreateRoutineForm` owns its own
  /// controller and selection state (see its class doc for why that, rather
  /// than hoisting, is what keeps typed state alive across a non-dismissing
  /// drag without also reintroducing a use-after-dispose).
  Future<void> _openCreateRoutineSheet() async {
    final saved = await showLockoutSheet<bool>(
      context: context,
      title: 'CREATE NEW ROUTINE',
      builder: (ctx) => _CreateRoutineForm(),
    );
    if (saved == true && mounted) await reload();
  }

  // --- ADD / EDIT TRAINING DAY ---

  /// Opens the training-day form. Resolves `true` only when the day was
  /// actually saved, so a caller that must close a parent sheet (the day
  /// detail sheet, on an edit) can tell a save apart from a dismiss.
  Future<bool?> _openDayFormSheet(String routineId, {TrainingDay? existing}) {
    final dayCount = (_routineDays[routineId] ?? []).length;
    return showLockoutSheet<bool>(
      context: context,
      title: existing == null ? 'ADD TRAINING DAY' : 'EDIT DAY',
      builder: (ctx) => _DayForm(
        routineId: routineId,
        existing: existing,
        dayCount: dayCount,
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
  }) {
    return showLockoutSheet<bool>(
      context: context,
      title: isWarmup ? 'ADD WARM-UP ITEM' : 'ADD FINISHER ITEM',
      builder: (ctx) => _SubItemForm(
        dayId: dayId,
        isWarmup: isWarmup,
        index: index,
      ),
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
  Future<bool?> _openExerciseSheet(ExerciseDef ex, {bool isNew = false}) {
    return showLockoutSheet<bool>(
      context: context,
      title: isNew ? 'ADD EXERCISE' : 'EDIT EXERCISE',
      builder: (ctx) => _ExerciseForm(
        ex: ex,
        isNew: isNew,
        onWatch: _openVideo,
      ),
    );
  }

  Future<void> _confirmDeleteRoutine(Routine routine) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text(
          '"${routine.name}" and all of its training days and exercises will be '
          'removed. Past workout history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
    await showLockoutSheet<void>(
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

    final theme = Theme.of(sheetCtx);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // v1 showed the day's focus (muscle groups) on the card's summary
        // row; `DayRow`'s signature is fixed and has no slot for it, so it
        // surfaces here instead — read-only, the edit form is where it's set.
        if (day.focus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
            child: Text(day.focus, style: theme.textTheme.bodySmall),
          ),
        if (day.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: LockoutTheme.spaceMd),
            child: LockoutCard(
              color: colors.tertiaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Read first',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.onTertiaryContainer),
                  ),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text(
                    day.note,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.onTertiaryContainer),
                  ),
                ],
              ),
            ),
          ),

        if (day.isRestDay)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: LockoutTheme.spaceMd,
            ),
            child: Row(
              children: [
                Icon(Icons.bedtime_outlined, color: colors.onSurfaceVariant),
                const SizedBox(width: LockoutTheme.spaceSm),
                Expanded(
                  child: Text(
                    'Recovery is part of the plan.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Every section is built the same way: heading, rows, labelled
          // add link. The heading never carries its own `+` and the link is
          // never swapped out once the section fills up, so the control the
          // user just pressed is still where they left it.
          // --- Warm-up ---
          SectionHeading(
            title: 'Warm-Up',
            amount: warmups.isEmpty ? '' : '~6-8 min',
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
          AddLink(
            label: '+ ADD WARM-UP',
            onTap: () => refreshAfter(() => _openSubItemSheet(
                dayId: day.id, isWarmup: true, index: warmups.length)),
          ),

          // --- Exercises ---
          SectionHeading(
            title: 'Exercises',
            amount: exercises.isEmpty ? '' : '${exercises.length}',
          ),
          ...exercises.asMap().entries.map(
                (e) => _buildExerciseRow(
                    e.key + 1, e.value, accent, onAccent, refreshAfter, theme),
              ),
          AddLink(
            label: '+ ADD EXERCISE',
            onTap: () => refreshAfter(() => _addExerciseToDay(day.id)),
          ),

          // --- Finisher ---
          SectionHeading(
            title: 'Conditioning Finisher',
            amount: finishers.isEmpty ? '' : 'x3 rounds',
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
          AddLink(
            label: '+ ADD FINISHER',
            onTap: () => refreshAfter(() => _openSubItemSheet(
                dayId: day.id, isWarmup: false, index: finishers.length)),
          ),
        ],

        // --- Day actions ---
        Padding(
          padding: const EdgeInsets.only(top: LockoutTheme.spaceSm),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final saved =
                      await _openDayFormSheet(routine.id, existing: day);
                  if (saved != true || !mounted) return;
                  await _loadAllRoutinesData();
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).maybePop();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit day'),
              ),
              const SizedBox(width: LockoutTheme.spaceSm),
              TextButton.icon(
                onPressed: () async {
                  await DatabaseService.instance.deleteDay(day.id);
                  if (!mounted) return;
                  await _loadAllRoutinesData();
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).maybePop();
                },
                style: TextButton.styleFrom(foregroundColor: colors.error),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Delete day'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Number, name, then target and WATCH on a second line — a long name and a
  /// target chip competing for one row forced three-line wraps.
  /// One exercise line inside the day sheet.
  ///
  /// Deliberately a line, not a card. Each of the three sections used to
  /// draw its rows differently — warm-ups and finishers as plain text, the
  /// exercises as bordered, shadowed cards — so one sheet spoke three visual
  /// languages for three lists of the same kind of thing, and the exercises
  /// read as a wall of rectangles between them. Now every row in the sheet
  /// is a name on the left, its prescription in mono on the right, and a
  /// 40dp control at the end. Only the number chip and WATCH tell an
  /// exercise apart, and those carry information the other rows do not have.
  Widget _buildExerciseRow(
    int number,
    ExerciseDef ex,
    Color accent,
    Color onAccent,
    RefreshAfter refreshAfter,
    // The sheet's own theme, not the tab's — this row only ever renders
    // inside the day sheet, whose context `_buildDayDetail` already resolves
    // two frames up as `Theme.of(sheetCtx)`. Reading `Theme.of(context)` here
    // (the tab's element) is harmless only while the sheet shares the tab's
    // tree today; it stops being harmless the moment a sheet wraps its own
    // `Theme`.
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => refreshAfter(() => _openExerciseSheet(ex)),
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(minHeight: LockoutTheme.minTouchTarget),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: LockoutTheme.numeric(context, size: 11, color: onAccent),
              ),
            ),
            const SizedBox(width: LockoutTheme.spaceSm),
            Expanded(
              child: Text(
                ex.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: LockoutTheme.spaceSm),
            Text(
              ex.targetWeightKg > 0
                  ? '${ex.targetLabel} @ ${ex.targetWeightKg}kg'
                  : ex.targetLabel,
              style: theme.textTheme.labelSmall,
            ),
            // Sits where the remove glyph sits on a warm-up or finisher row,
            // on the same 40dp box, so the right edge of the sheet is one
            // column of controls rather than three.
            GestureDetector(
              onTap: () => _openVideo(ex.name, ex.videoUrl),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: LockoutTheme.minTouchTarget,
                  minHeight: LockoutTheme.minTouchTarget,
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
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
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // SafeArea(bottom: false): MainScreen dropped its global AppBar in the
      // five-tab restructure, so each tab now owns its top inset. Without it
      // the header paints under the status bar on an edge-to-edge window and
      // swallows taps there. Bottom is left alone — BottomNav carries its own
      // inset and content should scroll under it.
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Workout',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  // A tonal button rather than the old pill: the label and its
                  // icon overflowed an 11dp-narrow Row on a 360dp window.
                  FilledButton.tonalIcon(
                    onPressed: _openCreateRoutineSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('New'),
                  ),
                ],
              ),
            const SizedBox(height: LockoutTheme.spaceMd),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: LockoutCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: LockoutTheme.spaceSm),
            Text('No routines yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: LockoutTheme.spaceXs),
            Text(
              'Tap New and pick a starter split. Every day arrives with a '
              'warm-up, numbered exercises and a conditioning finisher already '
              'filled in.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard(Routine routine) {
    final theme = Theme.of(context);
    final days = _routineDays[routine.id] ?? [];
    final isActive = routine.id == _activeRoutineId;
    final todayCode = ScheduleService.weekdayCode(DateTime.now());

    // Not elevated: the featured `TodayDayCard` inside is the card that
    // leads on this screen (see `LockoutCard`'s own doc), so the container
    // stays flat and lets that one lift.
    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(routine.name, style: theme.textTheme.titleLarge),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'active') _setActive(routine);
                  if (v == 'delete') _confirmDeleteRoutine(routine);
                },
                // v1 hid SET AS ACTIVE once the routine was already active;
                // a fixed two-item menu can't express that, so filter here.
                itemBuilder: (_) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'active',
                      child: Text('Set as active'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceSm),
          Wrap(
            spacing: LockoutTheme.spaceSm,
            runSpacing: LockoutTheme.spaceSm,
            children: [
              _tag(routine.schedulingMode.name.toUpperCase()),
              _tag('${days.length} DAYS'),
              if (isActive) _tag('ACTIVE', filled: true),
            ],
          ),
          const Divider(),
          if (days.isEmpty)
            Text(
              'No training days yet. Open the week and tap "Add day" to pin a '
              'workout to a weekday.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            // One colour assignment per routine: the uniqueness rule is only
            // meaningful across the whole week, so it is computed once here
            // and shared by the featured card and the collapsed rows.
            ...(() {
              final colours = DayColours.assign(days);
              final focus = RoutineFocus.resolve(
                routine: routine,
                days: days,
                now: DateTime.now(),
                isActive: isActive,
              );

              return [
                if (focus != null) ...[
                  if (focus.day == null)
                    _buildNothingScheduledCard(focus.kind)
                  else
                    _buildFeaturedDay(routine, focus, colours),
                  const SizedBox(height: LockoutTheme.spaceMd),
                ],
                _buildWeekExpander(routine, days, colours, todayCode, isActive),
              ];
            })(),
        ],
      ),
    );
  }

  /// The featured day: the one the routine is actually on right now.
  Widget _buildFeaturedDay(
    Routine routine,
    RoutineFocusResult focus,
    Map<String, Color> colours,
  ) {
    final day = focus.day!;
    final hydrated = _hydrated(day);
    // A rest day has nothing to start, and neither does a day whose exercises
    // have not been added yet — offering START SESSION there would open a
    // session with zero exercises.
    final startable = !hydrated.isRestDay && hydrated.exercises.isNotEmpty;

    return TodayDayCard(
      day: hydrated,
      accent: colours[day.id] ?? LockoutSemantics.of(context).restDay,
      summary: dayRowSummary(hydrated),
      kind: focus.kind,
      onTap: () => _openDaySheet(routine, day),
      onStart: startable ? widget.onStartToday : null,
    );
  }

  /// Shown when the routine is the active one but has nothing scheduled right
  /// now — a gap in the week, or a rotation that has not started yet.
  Widget _buildNothingScheduledCard(FeaturedDayKind kind) {
    final theme = Theme.of(context);

    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind == FeaturedDayKind.today ? 'TODAY' : 'NEXT',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: LockoutTheme.spaceXs),
          Text('Nothing scheduled today', style: theme.textTheme.titleLarge),
          const SizedBox(height: LockoutTheme.spaceXs),
          Text(
            'Open the week to add a day, or train off-plan.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// The rest of the week, collapsed by default.
  ///
  /// The expansion state is deliberately NOT persisted: reopening the tab
  /// returns to the focused view, which is the entire point of featuring one
  /// day. `+ Add day` lives inside, so building a routine means opening the
  /// week rather than the week being permanently open for the sake of one
  /// button.
  Widget _buildWeekExpander(
    Routine routine,
    List<TrainingDay> days,
    Map<String, Color> colours,
    String todayCode,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
    );

    return ExpansionTile(
      shape: shape,
      collapsedShape: shape,
      tilePadding: const EdgeInsets.symmetric(
        horizontal: LockoutTheme.spaceSm,
      ),
      childrenPadding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
      title: Text(
        'Full week (${days.length})',
        style: theme.textTheme.titleSmall,
      ),
      children: [
        for (final d in days)
          WeekDayRow(
            day: _hydrated(d),
            accent: colours[d.id] ?? LockoutSemantics.of(context).restDay,
            summary: dayRowSummary(_hydrated(d)),
            isToday: isActive &&
                routine.schedulingMode == SchedulingMode.weekday &&
                d.tag.trim().toUpperCase() == todayCode,
            onTap: () => _openDaySheet(routine, d),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final saved = await _openDayFormSheet(routine.id);
              if (saved == true && mounted) await reload();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add day'),
          ),
        ),
      ],
    );
  }

  /// A day tag/status chip. Outline by default; filled only for the
  /// currently-active routine's ACTIVE badge, so the header reads calmer.
  Widget _tag(String label, {bool filled = false}) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: filled ? colors.primaryContainer : null,
      labelStyle: filled
          ? TextStyle(color: colors.onPrimaryContainer)
          : null,
      side: filled ? BorderSide.none : null,
    );
  }
}

// --- FORM WIDGETS ---
//
// Each of the four sheet forms below is its own `StatefulWidget` rather than
// a builder function fed hoisted controllers/locals. `showLockoutSheet`'s
// `builder` is re-invoked on every rebuild of the sheet's own drag-handling
// state (`_BottomSheetState._handleDragStart`/`_handleDragEnd`, both call
// `setState`), but re-invoking a builder only recreates the `Widget`
// description — a `StatefulWidget`'s `State` (and everything it owns,
// including its `TextEditingController`s) survives that exactly the way a
// `StatefulBuilder`'s closure state used to. The difference is disposal:
// `State.dispose()` runs when the widget is actually removed from the tree,
// which for a modal route is when its exit animation finishes — not when
// `showLockoutSheet`'s returned Future completes, which fires when the pop
// *starts* (`Route.didPop` -> `didComplete`), roughly 200ms earlier while
// the sheet is still mounted and rebuilding. Disposing controllers in a
// `finally` around that `await` (the previous fix wave's approach) tore them
// down while `EditableText` was still subscribed to them, producing a
// use-after-dispose the instant a field had been focused/edited before
// close. Owning the controllers in `State` ties disposal to the same
// lifecycle event that removes the widget, so there is no window where the
// controller is gone but something in the tree still points at it.

class _CreateRoutineForm extends StatefulWidget {
  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  _CreateRoutineForm();

  @override
  State<_CreateRoutineForm> createState() => _CreateRoutineFormState();
}

class _CreateRoutineFormState extends State<_CreateRoutineForm> {
  final _nameCtrl = TextEditingController();
  var _mode = SchedulingMode.weekday;

  // Deliberately null, not `RoutineTemplate.all.first`. That first entry is
  // `blank`, so a pre-selected default meant the fastest path through this
  // form — type a name, hit SAVE — produced a routine with no days, while
  // the empty state behind the sheet promises every day arrives already
  // filled in. Nothing is ticked until the user picks, and SAVE waits.
  RoutineTemplate? _template;
  var _showTemplateError = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LockoutField(
          label: 'Routine name',
          controller: _nameCtrl,
          hint: 'e.g. Push / Pull / Legs',
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        Text('Scheduling mode', style: theme.textTheme.labelMedium),
        const SizedBox(height: LockoutTheme.spaceSm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<SchedulingMode>(
            segments: const [
              ButtonSegment(
                value: SchedulingMode.weekday,
                label: Text('Weekday'),
              ),
              ButtonSegment(
                value: SchedulingMode.rotating,
                label: Text('Rotating'),
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        const SizedBox(height: LockoutTheme.spaceSm),
        Text(
          _mode == SchedulingMode.weekday
              ? 'Each day is pinned to a weekday. Today\'s workout is whichever day matches today.'
              : 'Days cycle in order, one per calendar day, ignoring weekdays.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: LockoutTheme.spaceLg),
        Text('Start from', style: theme.textTheme.labelMedium),
        const SizedBox(height: LockoutTheme.spaceXs),
        Text(
          _showTemplateError
              ? 'Pick a starter split, or Blank Routine to add your own days.'
              : 'A starter split arrives with warm-ups, numbered exercises '
                  'and a finisher already filled in.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _showTemplateError ? theme.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: LockoutTheme.spaceSm),
        ...RoutineTemplate.all.map((t) {
          final selected = t.key == _template?.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
            child: InkWell(
              onTap: () => setState(() {
                _template = t;
                _showTemplateError = false;
              }),
              borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
              // Ink, not Container: Container's opaque BoxDecoration paints
              // over the InkWell's splash (which draws on the ancestor
              // Material), so a selected tile — the one with a fill — gave no
              // press feedback while an unselected one still did. Ink paints
              // its decoration onto that same ancestor Material, underneath
              // any splash, instead of into a new layer on top of it.
              child: Ink(
                padding: const EdgeInsets.all(LockoutTheme.spaceMd),
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.secondaryContainer : null,
                  borderRadius:
                      BorderRadius.circular(LockoutTheme.radiusButton),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: LockoutTheme.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: theme.textTheme.titleSmall),
                          const SizedBox(height: LockoutTheme.spaceXs),
                          Text(t.blurb, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: LockoutTheme.spaceSm),
        FilledButton(onPressed: () async {
            final template = _template;
            if (template == null) {
              setState(() => _showTemplateError = true);
              return;
            }
            final typed = _nameCtrl.text.trim();
            final name =
                typed.isNotEmpty ? typed : (template.key == 'blank' ? '' : template.name);
            if (name.isEmpty) return;

            await RoutineFactory.createFromTemplate(
              name: name,
              mode: _mode,
              template: template,
            );
            if (!context.mounted) return;
            Navigator.pop(context, true);
          }, child: Text('Save routine')),
      ],
    );
  }
}

class _DayForm extends StatefulWidget {
  final String routineId;
  final TrainingDay? existing;
  final int dayCount;

  const _DayForm({
    required this.routineId,
    required this.dayCount,
    this.existing,
  });

  @override
  State<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends State<_DayForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _focusCtrl;
  late final TextEditingController _noteCtrl;
  late String _tag;
  late bool _isRest;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _focusCtrl = TextEditingController(text: existing?.focus ?? '');
    _noteCtrl = TextEditingController(text: existing?.note ?? '');
    _tag = existing?.tag ?? ScheduleService.weekdayPickerOrder.first;
    _isRest = existing?.isRestDay ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Day of week', style: theme.textTheme.labelMedium),
        const SizedBox(height: LockoutTheme.spaceSm),
        Wrap(
          spacing: LockoutTheme.spaceSm,
          runSpacing: LockoutTheme.spaceSm,
          children: ScheduleService.weekdayPickerOrder.map((d) {
            final selected = _tag == d;
            return ChoiceChip(
              label: Text(d),
              selected: selected,
              onSelected: (_) => setState(() => _tag = d),
            );
          }).toList(),
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        LockoutField(
          label: 'Day name',
          controller: _nameCtrl,
          hint: 'e.g. Push',
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        LockoutField(
          label: 'Focus (muscle groups)',
          controller: _focusCtrl,
          hint: 'e.g. Chest - Shoulders - Triceps',
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        LockoutField(
          label: 'Day note (optional)',
          controller: _noteCtrl,
        ),
        // Guidance the user needs before typing, not a hint hidden inside
        // the field until focus — `LockoutField` has no `helperText` slot
        // (out of scope for this file), so this stands in for one.
        const SizedBox(height: LockoutTheme.spaceXs),
        Text('Injury cautions, tempo rules...', style: theme.textTheme.bodySmall),
        const SizedBox(height: LockoutTheme.spaceSm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mark as rest day'),
          value: _isRest,
          onChanged: (v) => setState(() => _isRest = v),
        ),
        const SizedBox(height: LockoutTheme.spaceSm),
        FilledButton(onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            await DatabaseService.instance.insertDay(TrainingDay(
              id: existing?.id ?? _newId(),
              routineId: widget.routineId,
              name: _nameCtrl.text.trim(),
              tag: _tag,
              orderIndex: existing?.orderIndex ?? widget.dayCount,
              focus: _focusCtrl.text.trim(),
              note: _noteCtrl.text.trim(),
              isRestDay: _isRest,
            ).toMap());
            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          // 'Create day', not 'Add day': the week expander's own action is
          // already called Add day, and two controls with the same words
          // one tap apart is ambiguous.
          child: Text(widget.existing == null ? 'Create day' : 'Save day'),
        ),
      ],
    );
  }
}

class _SubItemForm extends StatefulWidget {
  final String dayId;
  final bool isWarmup;
  final int index;

  const _SubItemForm({
    required this.dayId,
    required this.isWarmup,
    required this.index,
  });

  @override
  State<_SubItemForm> createState() => _SubItemFormState();
}

class _SubItemFormState extends State<_SubItemForm> {
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LockoutField(
          label: 'Movement',
          controller: _nameCtrl,
          hint: widget.isWarmup ? 'e.g. Arm circles' : 'e.g. Push-ups',
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        LockoutField(
          label: 'Amount',
          controller: _amtCtrl,
          hint: widget.isWarmup ? 'e.g. 3-4 min' : 'e.g. 12-15 reps',
        ),
        const SizedBox(height: LockoutTheme.spaceSm),
        FilledButton(onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            final db = DatabaseService.instance;
            if (widget.isWarmup) {
              await db.insertWarmup(WarmupItem(
                id: _newId(),
                dayId: widget.dayId,
                name: _nameCtrl.text.trim(),
                amt: _amtCtrl.text.trim(),
                orderIndex: widget.index,
              ).toMap());
            } else {
              await db.insertFinisher(FinisherItem(
                id: _newId(),
                dayId: widget.dayId,
                name: _nameCtrl.text.trim(),
                amt: _amtCtrl.text.trim(),
                orderIndex: widget.index,
              ).toMap());
            }
            if (!context.mounted) return;
            Navigator.pop(context, true);
          }, child: Text('Add')),
      ],
    );
  }
}

class _ExerciseForm extends StatefulWidget {
  final ExerciseDef ex;
  final bool isNew;
  final void Function(String name, String videoUrl) onWatch;

  const _ExerciseForm({
    required this.ex,
    required this.onWatch,
    this.isNew = false,
  });

  @override
  State<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<_ExerciseForm> {
  late final TextEditingController _setsCtrl;
  late final TextEditingController _repsMinCtrl;
  late final TextEditingController _repsMaxCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _restCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _videoCtrl;

  @override
  void initState() {
    super.initState();
    final ex = widget.ex;
    _setsCtrl = TextEditingController(text: ex.targetSets.toString());
    _repsMinCtrl = TextEditingController(text: ex.targetRepsMin.toString());
    _repsMaxCtrl = TextEditingController(text: ex.targetRepsMax.toString());
    _weightCtrl = TextEditingController(
      text: ex.targetWeightKg == 0 ? '' : ex.targetWeightKg.toString(),
    );
    _restCtrl = TextEditingController(text: ex.restDefaultS.toString());
    _noteCtrl = TextEditingController(text: ex.note);
    _videoCtrl = TextEditingController(text: ex.videoUrl);
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsMinCtrl.dispose();
    _repsMaxCtrl.dispose();
    _weightCtrl.dispose();
    _restCtrl.dispose();
    _noteCtrl.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = widget.ex;
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
                  // Not a titleLarge: the SheetScaffold title above
                  // ("ADD EXERCISE" / "EDIT EXERCISE") already carries that
                  // weight, so this is a secondary line, not a second
                  // heading.
                  Text(ex.name, style: theme.textTheme.titleMedium),
                  if (group.isNotEmpty) ...[
                    const SizedBox(height: LockoutTheme.spaceXs),
                    Chip(
                      label: Text(group),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                widget.onWatch(ex.name, _videoCtrl.text.trim());
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Watch'),
            ),
          ],
        ),
        const SizedBox(height: LockoutTheme.spaceLg),
        Row(
          children: [
            Expanded(
              child: LockoutField(
                label: 'Sets',
                controller: _setsCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: LockoutTheme.spaceSm),
            Expanded(
              child: LockoutField(
                label: 'Min reps',
                controller: _repsMinCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: LockoutTheme.spaceSm),
            Expanded(
              child: LockoutField(
                label: 'Max reps',
                controller: _repsMaxCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        Row(
          children: [
            Expanded(
              child: LockoutField(
                label: 'Weight (kg)',
                controller: _weightCtrl,
                hint: '0',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: LockoutTheme.spaceSm),
            Expanded(
              child: LockoutField(
                label: 'Rest (sec)',
                controller: _restCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        LockoutField(
          label: 'Note',
          controller: _noteCtrl,
        ),
        // Guidance the user needs before typing, not a hint hidden inside
        // the field until focus — `LockoutField` has no `helperText` slot
        // (out of scope for this file), so this stands in for one.
        const SizedBox(height: LockoutTheme.spaceXs),
        Text('Cues, injury notes, tempo...', style: theme.textTheme.bodySmall),
        const SizedBox(height: LockoutTheme.spaceMd),
        LockoutField(
          label: 'Pinned video URL (optional)',
          controller: _videoCtrl,
        ),
        const SizedBox(height: LockoutTheme.spaceXs),
        Text('Leave empty to auto-search YouTube',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: LockoutTheme.spaceXs),
        Text(
          'Empty video URL means Watch opens a YouTube search for a 3D / '
          'animated form demo of this exercise. Paste a link to pin one.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: LockoutTheme.spaceMd),
        FilledButton(onPressed: () async {
            final minReps =
                int.tryParse(_repsMinCtrl.text) ?? ex.targetRepsMin;
            var maxReps =
                int.tryParse(_repsMaxCtrl.text) ?? ex.targetRepsMax;
            if (maxReps < minReps) maxReps = minReps;

            await DatabaseService.instance.insertExercise(
              ex.copyWith(
                targetSets: int.tryParse(_setsCtrl.text) ?? ex.targetSets,
                targetRepsMin: minReps,
                targetRepsMax: maxReps,
                // `double.tryParse` accepts 'Infinity' and 'NaN', and this
                // field has no `inputFormatters`. A non-finite target weight
                // is copied into every live set the exercise starts,
                // multiplied into the session's `total_volume_kg`, and
                // persisted — after which LOG's `toInt()` throws on every
                // launch and the archive row that would let the user delete
                // the session is the thing that fails to paint.
                // `NumericGuard.sanitiseKg` is the same guard Settings and
                // BODY's measurement form already apply.
                targetWeightKg: NumericGuard.sanitiseKg(_weightCtrl.text),
                restDefaultS:
                    int.tryParse(_restCtrl.text) ?? ex.restDefaultS,
                note: _noteCtrl.text.trim(),
                videoUrl: _videoCtrl.text.trim(),
                muscleGroup: group,
              ).toMap(),
            );
            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          child: Text(widget.isNew ? 'Add to day' : 'Save changes'),
        ),
        if (!widget.isNew) ...[
          const SizedBox(height: LockoutTheme.spaceSm),
          FilledButton.tonal(onPressed: () async {
              await DatabaseService.instance.deleteExercise(ex.id);
              if (!context.mounted) return;
              Navigator.pop(context, true);
            }, child: Text('Remove exercise')),
        ],
      ],
    );
  }
}
