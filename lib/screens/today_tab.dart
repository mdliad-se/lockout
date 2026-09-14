import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/energy_estimator.dart';
import '../services/goal_service.dart';
import '../services/numeric_guard.dart';
import '../services/schedule_service.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/action_grid.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_hub.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_card.dart';
import 'exercise_video_screen.dart';

/// One set inside a running session.
class _LiveSet {
  double weightKg;
  int reps;
  bool completed = false;

  _LiveSet({required this.weightKg, required this.reps});
}

/// One exercise inside a running session, seeded from the routine's target.
class _LiveExercise {
  final String exerciseId; // '' when added ad-hoc mid-session
  final String name;
  final String videoUrl;
  final int restSeconds;
  final String targetLabel;
  final List<_LiveSet> sets;

  /// Completed sets from the last time this exercise was trained.
  String lastPerformance = '';

  _LiveExercise({
    required this.exerciseId,
    required this.name,
    required this.videoUrl,
    required this.restSeconds,
    required this.targetLabel,
    required this.sets,
  });

  int get completedCount => sets.where((s) => s.completed).length;

  double get volumeKg => sets
      .where((s) => s.completed)
      .fold(0.0, (sum, s) => sum + s.weightKg * s.reps);
}

class TodayTab extends StatefulWidget {
  /// Switches tabs by id — 'routines', 'food', 'body', 'log'. Supplied by
  /// MainScreen; null in tests that pump this tab on its own.
  final void Function(String tabId)? onNavigate;

  /// Whether the Food tab is currently reachable. When false, the hub must
  /// not offer a tap target that silently does nothing.
  final bool foodTabEnabled;

  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart. This tab
  // lives in `MainScreen`'s `IndexedStack` and never unmounts, so a skipped
  // rebuild would strand it in the old palette for the process lifetime.
  // ignore: prefer_const_constructors_in_immutables
  TodayTab({
    super.key,
    this.onNavigate,
    this.foodTabEnabled = true,
  });

  @override
  State<TodayTab> createState() => TodayTabState();
}

class TodayTabState extends State<TodayTab> {
  ScheduledDay? _scheduled;
  bool _isLoading = true;

  HomeHubSummary _summary = const HomeHubSummary(
    kcalEaten: 0,
    kcalTarget: null,
    weightKg: null,
    weightDeltaKg: null,
    burnedTodayKcal: null,
  );

  bool _sessionActive = false;
  DateTime? _startedAt;
  String _sessionTitle = '';
  List<_LiveExercise> _liveExercises = [];

  int _elapsedSeconds = 0;
  int _restSeconds = 0;
  bool _restRunning = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Called by MainScreen when the user returns to this tab, so a routine
  /// edited on the Routines tab, or a log entered on another tab, shows up
  /// here without an app restart.
  ///
  /// `_isLoading` only clears once both loads resolve. Clearing it after
  /// just the schedule load let the hub render its "not on record" prompts
  /// — `SET A GOAL`, `LOG A WEIGHT`, `NO SESSION YET` — for a frame or more
  /// even when the summary data exists but simply hasn't arrived yet, which
  /// reads as a lie rather than a loading state.
  Future<void> reload() async {
    await _loadSchedule();
    await _loadSummary();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadSchedule() async {
    final resolved = await ScheduleService.resolveToday();
    if (!mounted) return;
    setState(() => _scheduled = resolved);
  }

  /// Resolves the three calm-row values. Every one of them can legitimately
  /// be unknown, and the hub renders a prompt for a null rather than a zero.
  Future<void> _loadSummary() async {
    final today = ScheduleService.dateKey(DateTime.now());
    final db = DatabaseService.instance;

    final foodRows = await db.getFoodLogsForDate(today);
    final eaten = foodRows.fold<int>(
      0,
      (sum, row) => sum + (NumericGuard.readInt(row['kcal']) ?? 0),
    );

    // snapshot() already fetches body logs for currentWeightKg and resolves
    // the shared calorie target (Ruling A); reuse both instead of a second
    // getBodyLogs() call or re-deriving the target here.
    final snapshot = await GoalService.instance.snapshot();
    final delta = GoalService.weightDeltaKg(snapshot.bodyLogs);

    final sessionRows = await db.getSessionLogsForDate(today);
    // Null means "no session logged today" — the honest NO SESSION YET case.
    // A session that *was* logged but couldn't be estimated (no bodyweight
    // on record) sums to 0.0, which is a real, different state: the row
    // must not claim there was no session at all. See `HomeHub._burnValue`.
    final burnedToday = sessionRows.isEmpty
        ? null
        : sessionRows.fold<double>(
            0.0,
            (sum, r) => sum + (NumericGuard.read(r['kcal_burned']) ?? 0.0),
          );

    if (!mounted) return;
    setState(() {
      _summary = HomeHubSummary(
        kcalEaten: eaten,
        kcalTarget: snapshot.calorieTarget,
        weightKg: snapshot.currentWeightKg,
        weightDeltaKg: delta,
        burnedTodayKcal: burnedToday,
      );
    });
  }

  // --- SESSION LIFECYCLE ---

  Future<void> _startScheduledSession() async {
    final sched = _scheduled;
    if (sched == null) return;

    final live = <_LiveExercise>[];
    for (final ex in sched.exercises) {
      live.add(_LiveExercise(
        exerciseId: ex.id,
        name: ex.name,
        videoUrl: ex.videoUrl,
        restSeconds: ex.restDefaultS,
        targetLabel: ex.targetLabel,
        sets: List.generate(
          ex.targetSets,
          (_) => _LiveSet(weightKg: ex.targetWeightKg, reps: ex.targetRepsMax),
        ),
      ));
    }

    await _beginSession('${sched.day.tag} - ${sched.day.name}', live);
  }

  Future<void> _startCustomSession() async {
    await _beginSession('Custom Session', []);
  }

  Future<void> _beginSession(String title, List<_LiveExercise> exercises) async {
    for (final e in exercises) {
      e.lastPerformance = await _fetchLastPerformance(e.name);
    }
    if (!mounted) return;

    setState(() {
      _sessionActive = true;
      _sessionTitle = title;
      _liveExercises = exercises;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
      _restSeconds = 0;
      _restRunning = false;
    });
    _startTicker();
  }

  Future<String> _fetchLastPerformance(String exerciseName) async {
    final rows = await DatabaseService.instance.getLastPerformance(exerciseName);
    if (rows.isEmpty) return '';
    final sets = rows.map(SetLog.fromMap).toList();
    final reps = sets.map((s) => s.reps).join(',');
    final weight = sets.first.weightKg;
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)}kg x $reps';
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_startedAt != null) {
          _elapsedSeconds = DateTime.now().difference(_startedAt!).inSeconds;
        }
        if (_restRunning) {
          if (_restSeconds > 0) {
            _restSeconds--;
          } else {
            _restRunning = false;
          }
        }
      });
    });
  }

  void _beginRest(int seconds) {
    setState(() {
      _restSeconds = seconds;
      _restRunning = true;
    });
  }

  double get _sessionVolumeKg =>
      _liveExercises.fold(0.0, (sum, e) => sum + e.volumeKg);

  int get _sessionCompletedSets =>
      _liveExercises.fold(0, (sum, e) => sum + e.completedCount);

  int get _sessionTotalSets =>
      _liveExercises.fold(0, (sum, e) => sum + e.sets.length);

  String get _elapsedLabel {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _addExerciseMidSession() async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;

    final live = _LiveExercise(
      exerciseId: '',
      name: picked.name,
      videoUrl: '',
      restSeconds: 60,
      targetLabel: picked.repsMin == picked.repsMax
          ? '${picked.sets}x${picked.repsMin}'
          : '${picked.sets}x${picked.repsMin}-${picked.repsMax}',
      sets: List.generate(
        picked.sets,
        (_) => _LiveSet(weightKg: 0, reps: picked.repsMax),
      ),
    );
    live.lastPerformance = await _fetchLastPerformance(picked.name);

    if (!mounted) return;
    setState(() => _liveExercises.add(live));
  }

  Future<void> _finishSession() async {
    if (_sessionCompletedSets == 0) {
      final discard = await _confirmDiscard();
      if (discard != true) return;
      _endSessionState();
      return;
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final started = _startedAt ?? DateTime.now();
    final duration = DateTime.now().difference(started).inSeconds;
    final sched = _scheduled;

    // Only completed sets are archived — an untouched set is not a data point.
    final sessionSets = <SetLog>[];
    final setRows = <Map<String, dynamic>>[];
    var seq = 0;
    for (final ex in _liveExercises) {
      for (var i = 0; i < ex.sets.length; i++) {
        final s = ex.sets[i];
        if (!s.completed) continue;
        final setLog = SetLog(
          id: '$sessionId-${seq++}',
          sessionExerciseId: ex.exerciseId,
          sessionId: sessionId,
          exerciseName: ex.name,
          setIndex: i + 1,
          weightKg: s.weightKg,
          reps: s.reps,
          isCompleted: true,
        );
        sessionSets.add(setLog);
        setRows.add(setLog.toMap());
      }
    }

    // Bodyweight for the estimate: what the user last logged, else their
    // stated target, else no estimate at all.
    final snapshot = await GoalService.instance.snapshot();
    final bodyweightKg = snapshot.currentWeightKg ??
        (snapshot.profile.isConfigured
            ? snapshot.profile.targetWeightKg
            : null);

    final burn = EnergyEstimator.estimate(
      sets: sessionSets,
      dayName: _sessionTitle,
      bodyweightKg: bodyweightKg,
      durationSeconds: duration,
    );

    final session = SessionLog(
      id: sessionId,
      dayName: _sessionTitle,
      dateStr: ScheduleService.dateKey(DateTime.now()),
      durationSeconds: duration,
      totalVolumeKg: _sessionVolumeKg,
      status: 'completed',
      routineId: sched?.routine.id ?? '',
      dayId: sched?.day.id ?? '',
      totalSets: _sessionCompletedSets,
      kcalBurned: burn ?? 0.0,
    );

    // One transaction, not two writes: a kill between a header insert and
    // its sets leaves a session claiming `totalSets: N` with nothing behind
    // it, which nothing downstream can tell apart from a legitimately
    // detail-free entry. Same argument `deleteSessionLog` and
    // `restoreSessionLog` were given transactions for.
    await DatabaseService.instance
        .insertSessionWithSets(session.toMap(), setRows);

    if (!mounted) return;
    // Refresh BURNED TODAY (and the rest of the summary) so the hub the user
    // lands back on reflects the session just saved, rather than reporting
    // "not on record" about data that was just recorded.
    await _loadSummary();
    if (!mounted) return;
    _endSessionState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: JinatraTokens.deepTeal,
        content: Text(
          'SESSION SAVED - ${setRows.length} sets, ${_fmtWeight(session.totalVolumeKg)} kg volume',
          style: JinatraTokens.monoData(color: JinatraTokens.onPrimary, fontSize: 12),
        ),
      ),
    );
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JinatraTokens.sweetCream,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JinatraTokens.ink, width: 3),
          borderRadius: BorderRadius.circular(JinatraTokens.radiusCard),
        ),
        title: Text('DISCARD SESSION?', style: JinatraTokens.sectionHeader(fontSize: 16)),
        content: Text(
          'No sets were logged, so there is nothing to archive. End the session?',
          style: JinatraTokens.bodyText(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('KEEP GOING', style: JinatraTokens.monoData(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DISCARD',
              style: JinatraTokens.monoData(fontSize: 12, color: JinatraTokens.signal),
            ),
          ),
        ],
      ),
    );
  }

  void _endSessionState() {
    _ticker?.cancel();
    setState(() {
      _sessionActive = false;
      _liveExercises = [];
      _startedAt = null;
      _restRunning = false;
      _elapsedSeconds = 0;
    });
  }

  static String _fmtWeight(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _openVideo(String name, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseVideoScreen(exerciseName: name, videoUrl: url),
      ),
    );
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: JinatraTokens.deepTeal));
    }

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _sessionActive ? _buildActiveSession() : _buildPreSession(),
      ),
      // Kept visible while the exercise list scrolls, rather than inline in
      // the body. This is TodayTab's own Scaffold (nested inside MainScreen's
      // IndexedStack), so it does not compete with MainScreen's BottomNav.
      bottomNavigationBar:
          (_sessionActive && _restRunning) ? _buildRestBar() : null,
    );
  }

  // --- PRE-SESSION (the HOME hub) ---

  Widget _buildPreSession() {
    final sched = _scheduled;
    final code = ScheduleService.weekdayCode(DateTime.now());
    final isRest = sched == null;
    // A day can be scheduled with no exercises on it yet (routine still
    // being built). That is not a rest day, but it also has nothing to
    // start live — offer guidance to the Routines tab instead of a session
    // that would open with zero exercises.
    final isEmptyDay = sched != null && sched.exercises.isEmpty;

    return SingleChildScrollView(
      child: HomeHub(
        eyebrow: 'TODAY - $code',
        title: isRest ? 'REST DAY' : sched.day.name,
        subtitle: isRest
            ? 'Nothing scheduled. Train off-plan or take the day.'
            : isEmptyDay
                ? 'This training day has no exercises yet. Add them on the '
                    'Routines tab, then come back to start the session.'
                : _scheduleSubtitle(sched),
        heroColor: JinatraTokens.accentAt(isRest ? 7 : 0),
        heroActions: [
          if (!isRest && !isEmptyDay)
            JinatraButton(
              label: 'START SESSION',
              onPressed: _startScheduledSession,
            ),
          JinatraButton(
            label: 'CUSTOM SESSION',
            isSignal: true,
            onPressed: _startCustomSession,
          ),
        ],
        summary: _summary,
        foodTabEnabled: widget.foodTabEnabled,
        onOpenFood: widget.foodTabEnabled
            ? () => widget.onNavigate?.call('food')
            : null,
        onOpenBody: () => widget.onNavigate?.call('body'),
        onOpenLog: () => widget.onNavigate?.call('log'),
        actions: _quickActions(),
      ),
    );
  }

  String _scheduleSubtitle(ScheduledDay sched) {
    final sets = sched.exercises.fold<int>(0, (s, e) => s + e.targetSets);
    return '${sched.exercises.length} EX - $sets SETS';
  }

  List<ActionItem> _quickActions() {
    final go = widget.onNavigate;
    return [
      // Hidden entirely when the Food tab is off, rather than left as a
      // tile that taps to nowhere: `_goToTab` already no-ops for a hidden
      // tab id, so a visible "LOG FOOD" tile would silently do nothing.
      if (widget.foodTabEnabled)
        ActionItem(
          label: 'LOG FOOD',
          icon: Icons.restaurant,
          color: JinatraTokens.accentAt(0),
          onTap: () => go?.call('food'),
        ),
      ActionItem(
        label: 'WEIGH IN',
        icon: Icons.monitor_weight,
        color: JinatraTokens.accentAt(1),
        onTap: () => go?.call('body'),
      ),
      ActionItem(
        label: 'ROUTINES',
        icon: Icons.fitness_center,
        color: JinatraTokens.accentAt(2),
        onTap: () => go?.call('routines'),
      ),
      ActionItem(
        label: 'HISTORY',
        icon: Icons.calendar_month,
        color: JinatraTokens.accentAt(3),
        onTap: () => go?.call('log'),
      ),
      ActionItem(
        label: 'CUSTOM',
        icon: Icons.add,
        color: JinatraTokens.accentAt(4),
        onTap: _startCustomSession,
      ),
      ActionItem(
        label: 'STREAK',
        icon: Icons.local_fire_department,
        color: JinatraTokens.accentAt(5),
        onTap: () => go?.call('log'),
      ),
      ActionItem(
        label: 'PLAN',
        icon: Icons.insights,
        color: JinatraTokens.accentAt(6),
        onTap: () => go?.call('body'),
      ),
      ActionItem(
        label: 'EXERCISES',
        icon: Icons.list,
        color: JinatraTokens.accentAt(7),
        onTap: () => go?.call('routines'),
      ),
    ];
  }

  // --- ACTIVE SESSION ---

  Widget _buildActiveSession() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session header — the one saturated block this screen gets too.
        HeroCard(
          eyebrow: 'IN SESSION - $_sessionTitle',
          title: _elapsedLabel,
          subtitle:
              '$_sessionCompletedSets / $_sessionTotalSets SETS - ${_fmtWeight(_sessionVolumeKg)} KG',
          background: JinatraTokens.accentAt(0),
        ),

        Expanded(
          child: _liveExercises.isEmpty
              ? Center(
                  child: Text(
                    'EMPTY SESSION\nTap "+ ADD EXERCISE" to begin.',
                    textAlign: TextAlign.center,
                    style: JinatraTokens.monoData(
                      color: JinatraTokens.ink.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _liveExercises.length + 1,
                  itemBuilder: (ctx, idx) {
                    if (idx == _liveExercises.length) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: _addExerciseMidSession,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: JinatraTokens.mistTeal,
                              border: Border.all(color: JinatraTokens.ink, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '+ ADD EXERCISE',
                                style: JinatraTokens.monoData(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return _buildExerciseCard(_liveExercises[idx]);
                  },
                ),
        ),

        const SizedBox(height: 12),
        JinatraButton(label: 'FINISH SESSION & SAVE', onPressed: _finishSession),
      ],
    );
  }

  Widget _buildExerciseCard(_LiveExercise ex) {
    final done = ex.completedCount == ex.sets.length && ex.sets.isNotEmpty;

    return JinatraCard(
      margin: const EdgeInsets.only(bottom: 14),
      background: done ? JinatraTokens.mistTeal : JinatraTokens.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name.toUpperCase(),
                      style: JinatraTokens.sectionHeader(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ex.lastPerformance.isEmpty
                          ? 'TARGET ${ex.targetLabel}  -  NO HISTORY'
                          : 'TARGET ${ex.targetLabel}  -  LAST ${ex.lastPerformance}',
                      style: JinatraTokens.monoData(
                        fontSize: 10,
                        color: JinatraTokens.ink.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openVideo(ex.name, ex.videoUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: JinatraTokens.sweetCream,
                    border: Border.all(color: JinatraTokens.ink, width: 2),
                    boxShadow: [JinatraTokens.hardShadow(offset: 2)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 13, color: JinatraTokens.ink),
                      const SizedBox(width: 4),
                      Text('WATCH', style: JinatraTokens.monoData(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ex.sets.asMap().entries.map((e) => _buildSetRow(ex, e.key, e.value)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              final last = ex.sets.isNotEmpty ? ex.sets.last : null;
              setState(() => ex.sets.add(_LiveSet(
                    weightKg: last?.weightKg ?? 0,
                    reps: last?.reps ?? 10,
                  )));
            },
            child: Text(
              '+ ADD SET',
              style: JinatraTokens.monoData(fontSize: 10, color: JinatraTokens.deepTeal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(_LiveExercise ex, int index, _LiveSet set) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: set.completed ? JinatraTokens.mistTeal : JinatraTokens.sweetCream,
        border: Border.all(color: JinatraTokens.ink, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SET ${index + 1}',
                style: JinatraTokens.monoData(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: set.completed ? JinatraTokens.deepTeal : JinatraTokens.ink,
                ),
              ),
              Row(
                children: [
                  if (ex.sets.length > 1)
                    GestureDetector(
                      onTap: () => setState(() => ex.sets.removeAt(index)),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(Icons.close, size: 16, color: JinatraTokens.ink),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      final wasDone = set.completed;
                      setState(() => set.completed = !wasDone);
                      if (!wasDone) _beginRest(ex.restSeconds);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 60),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: set.completed
                            ? JinatraTokens.deepTeal
                            : JinatraTokens.paper,
                        border: Border.all(color: JinatraTokens.ink, width: 2),
                        boxShadow: [
                          JinatraTokens.hardShadow(offset: set.completed ? 0 : 2),
                        ],
                      ),
                      child: Text(
                        set.completed ? 'LOGGED' : 'LOG SET',
                        style: JinatraTokens.monoData(
                          color: set.completed ? JinatraTokens.onPrimary : JinatraTokens.ink,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _stepper(
                  label: '${_fmtWeight(set.weightKg)} kg',
                  onMinus: () {
                    if (set.weightKg >= 2.5) {
                      setState(() => set.weightKg -= 2.5);
                    } else if (set.weightKg > 0) {
                      setState(() => set.weightKg = 0);
                    }
                  },
                  onPlus: () => setState(() => set.weightKg += 2.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stepper(
                  label: '${set.reps} reps',
                  onMinus: () {
                    if (set.reps > 1) setState(() => set.reps--);
                  },
                  onPlus: () => setState(() => set.reps++),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper({
    required String label,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    Widget btn(String glyph, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: JinatraTokens.mistTeal,
              border: Border.all(color: JinatraTokens.ink, width: 1),
            ),
            child: Text(glyph, style: JinatraTokens.monoData(fontSize: 14)),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: JinatraTokens.ink, width: 2),
        color: JinatraTokens.paper,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          btn('-', onMinus),
          Text(label, style: JinatraTokens.monoData(fontSize: 12)),
          btn('+', onPlus),
        ],
      ),
    );
  }

  Widget _buildRestBar() {
    // Sitting in the Scaffold's bottomNavigationBar slot, this no longer
    // inherits the body's 16px padding, so it is reapplied here — otherwise
    // the bar runs edge to edge and its hard shadow clips on the right.
    // `radiusTile` brings it in line with the v2 12px control radius instead
    // of the old square v1 corners.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: JinatraTokens.cardDecoration(
          background: JinatraTokens.paper,
          borderColor: JinatraTokens.signal,
          shadowOffset: 4,
          radius: JinatraTokens.radiusTile,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: JinatraTokens.signal, size: 18),
                const SizedBox(width: 8),
                Text('REST', style: JinatraTokens.monoData(fontSize: 12)),
                const SizedBox(width: 8),
                Text(
                  '${_restSeconds}s',
                  style: JinatraTokens.monoData(fontSize: 18, color: JinatraTokens.signal),
                ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _restSeconds += 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                      color: JinatraTokens.mistTeal,
                    ),
                    child: Text('+15s', style: JinatraTokens.monoData(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _restRunning = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                      color: JinatraTokens.signal,
                    ),
                    child: Text('SKIP', style: JinatraTokens.monoData(fontSize: 11)),
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
