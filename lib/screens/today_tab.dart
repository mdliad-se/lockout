import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/energy_estimator.dart';
import '../services/goal_service.dart';
import '../services/schedule_service.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/exercise_picker.dart';
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
  const TodayTab({super.key});

  @override
  State<TodayTab> createState() => TodayTabState();
}

class TodayTabState extends State<TodayTab> {
  ScheduledDay? _scheduled;
  bool _isLoading = true;

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
    _loadSchedule();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Called by MainScreen when the user returns to this tab, so a routine
  /// edited on the Routines tab shows up here without an app restart.
  Future<void> reload() => _loadSchedule();

  Future<void> _loadSchedule() async {
    final resolved = await ScheduleService.resolveToday();
    if (!mounted) return;
    setState(() {
      _scheduled = resolved;
      _isLoading = false;
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
    final setRows = <Map<String, dynamic>>[];
    var seq = 0;
    for (final ex in _liveExercises) {
      for (var i = 0; i < ex.sets.length; i++) {
        final s = ex.sets[i];
        if (!s.completed) continue;
        setRows.add(SetLog(
          id: '$sessionId-${seq++}',
          sessionExerciseId: ex.exerciseId,
          sessionId: sessionId,
          exerciseName: ex.name,
          setIndex: i + 1,
          weightKg: s.weightKg,
          reps: s.reps,
          isCompleted: true,
        ).toMap());
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
      sets: setRows.map(SetLog.fromMap).toList(),
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

    await DatabaseService.instance.insertSessionLog(session.toMap());
    await DatabaseService.instance.insertSetLogs(setRows);

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
          borderRadius: BorderRadius.zero,
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
    );
  }

  // --- PRE-SESSION ---

  Widget _buildPreSession() {
    final sched = _scheduled;
    final today = DateTime.now();
    final code = ScheduleService.weekdayCode(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TODAY WORKOUT', style: JinatraTokens.sectionHeader()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: JinatraTokens.signal,
                border: Border.all(color: JinatraTokens.ink, width: 2),
              ),
              child: Text(code, style: JinatraTokens.monoData(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: sched == null ? _buildRestDay() : _buildScheduledPreview(sched),
        ),
      ],
    );
  }

  Widget _buildRestDay() {
    return ListView(
      children: [
        JinatraCard(
          shadowOffset: JinatraTokens.shadowLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REST DAY', style: JinatraTokens.displayHeader(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                'No training day is scheduled for today in your active routine. '
                'Add a day for this weekday on the Routines tab, or train something off-plan.',
                style: JinatraTokens.bodyText(),
              ),
              const SizedBox(height: 18),
              JinatraButton(
                label: 'START CUSTOM SESSION',
                isSignal: true,
                onPressed: _startCustomSession,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledPreview(ScheduledDay sched) {
    final hasExercises = sched.exercises.isNotEmpty;

    return ListView(
      children: [
        // Day header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: JinatraTokens.deepTeal,
            border: Border.all(color: JinatraTokens.ink, width: JinatraTokens.borderHero),
            boxShadow: [JinatraTokens.hardShadow(offset: JinatraTokens.shadowMd)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sched.day.name.toUpperCase(),
                style: JinatraTokens.displayHeader(color: JinatraTokens.onPrimary, fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                '${sched.routine.name}  -  ${sched.exercises.length} EXERCISES',
                style: JinatraTokens.monoData(color: JinatraTokens.sweetCream, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (!hasExercises)
          JinatraCard(
            child: Text(
              'This training day has no exercises yet. Add them on the Routines tab, '
              'then come back to start the session.',
              style: JinatraTokens.bodyText(fontSize: 13),
            ),
          )
        else
          ...sched.exercises.asMap().entries.map((entry) {
            final i = entry.key;
            final ex = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: JinatraTokens.paper,
                border: Border.all(color: JinatraTokens.ink, width: 2),
                boxShadow: [JinatraTokens.hardShadow(offset: 3)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: JinatraTokens.mistTeal,
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                    ),
                    child: Text('${i + 1}', style: JinatraTokens.monoData(fontSize: 11)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ex.name,
                      style: JinatraTokens.bodyText(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(ex.targetLabel, style: JinatraTokens.monoData(fontSize: 11)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openVideo(ex.name, ex.videoUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: JinatraTokens.sweetCream,
                        border: Border.all(color: JinatraTokens.ink, width: 2),
                      ),
                      child: Icon(Icons.play_arrow, size: 14, color: JinatraTokens.ink),
                    ),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 8),
        if (hasExercises)
          JinatraButton(label: 'START LIVE SESSION', onPressed: _startScheduledSession),
        const SizedBox(height: 10),
        JinatraButton(
          label: 'START CUSTOM SESSION',
          background: JinatraTokens.paper,
          textColor: JinatraTokens.ink,
          onPressed: _startCustomSession,
        ),
      ],
    );
  }

  // --- ACTIVE SESSION ---

  Widget _buildActiveSession() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JinatraTokens.deepTeal,
            border: Border.all(color: JinatraTokens.ink, width: JinatraTokens.borderControl),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _sessionTitle.toUpperCase(),
                      style: JinatraTokens.monoData(color: JinatraTokens.onPrimary, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _elapsedLabel,
                    style: JinatraTokens.monoData(
                      color: JinatraTokens.signal,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SETS: $_sessionCompletedSets / $_sessionTotalSets',
                    style: JinatraTokens.monoData(
                      color: JinatraTokens.sweetCream,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'VOLUME: ${_fmtWeight(_sessionVolumeKg)} kg',
                    style: JinatraTokens.monoData(
                      color: JinatraTokens.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

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

        if (_restRunning) _buildRestBar(),

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
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: JinatraTokens.paper,
        border: Border.all(color: JinatraTokens.signal, width: 3),
        boxShadow: [JinatraTokens.hardShadow(offset: 4)],
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
    );
  }
}
