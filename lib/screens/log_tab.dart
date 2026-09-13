import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/schedule_service.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/hero_card.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/stat_tile.dart';
import '../widgets/undo_banner.dart';

/// The archive card's detail line.
///
/// A top-level function rather than a private method so it can be tested
/// without pumping the screen, and so the burn's presence rule lives in one
/// place: no estimate means the segment is absent, never "0 kcal".
String sessionArchiveLine(SessionLog log) => [
      log.dateStr,
      log.durationLabel,
      '${log.totalSets} sets',
      if (log.kcalLabel.isNotEmpty) log.kcalLabel,
    ].join('  -  ');

class LogTab extends StatefulWidget {
  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart. This tab
  // lives in `MainScreen`'s `IndexedStack` and never unmounts, so a skipped
  // rebuild would strand it in the old palette for the process lifetime.
  // ignore: prefer_const_constructors_in_immutables
  LogTab({super.key});

  @override
  State<LogTab> createState() => LogTabState();
}

class LogTabState extends State<LogTab> {
  List<SessionLog> _logs = [];
  int _streakDays = 0;
  bool _isLoading = true;

  /// Sets for sessions the user has expanded, loaded lazily.
  final Map<String, List<SetLog>> _expandedSets = {};
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  /// Called by MainScreen so a session finished on the Today tab shows here
  /// immediately, without an app restart.
  Future<void> reload() => _loadLogs();

  Future<void> _loadLogs() async {
    final db = DatabaseService.instance;
    final rows = await db.getSessionLogs();
    final dates = await db.getWorkoutDates();

    if (!mounted) return;
    setState(() {
      _logs = rows.map(SessionLog.fromMap).toList();
      _streakDays = ScheduleService.currentStreakDays(dates);
      _isLoading = false;
      _expanded.clear();
      _expandedSets.clear();
    });
  }

  Future<void> _toggleExpand(SessionLog log) async {
    if (_expanded.contains(log.id)) {
      setState(() => _expanded.remove(log.id));
      return;
    }

    if (!_expandedSets.containsKey(log.id)) {
      final rows = await DatabaseService.instance.getSetLogsForSession(log.id);
      if (!mounted) return;
      _expandedSets[log.id] = rows.map(SetLog.fromMap).toList();
    }
    setState(() => _expanded.add(log.id));
  }

  /// Deletes [log] and its set detail immediately (`deleteSessionLog`
  /// removes both, atomically), then offers a few seconds to reverse it
  /// through the same `showUndoBanner` mechanism BODY and FOOD already use
  /// (Ruling F) — not the pre-v2 confirm-dialog, which guarded the tap with
  /// a modal but left no way back once DELETE was actually pressed. The
  /// sets are fetched *before* the delete — a closed card never populates
  /// `_expandedSets`, so that cache cannot be relied on to still hold them
  /// for restore.
  Future<void> _deleteLog(SessionLog log) async {
    final db = DatabaseService.instance;
    final setRows = (await db.getSetLogsForSession(log.id))
        .map(SetLog.fromMap)
        .toList();

    await db.deleteSessionLog(log.id);
    if (!mounted) return;
    await _loadLogs();
    if (!mounted) return;

    showUndoBanner(
      context,
      message: 'DELETED ${log.dayName.toUpperCase()} SESSION',
      onUndo: () => _restoreLog(log, setRows),
    );
  }

  /// Re-inserts [log] with its original id and every field intact, then its
  /// [sets] the same way, atomically (`DatabaseService.restoreSessionLog`)
  /// so an interruption mid-restore cannot leave a header with no sets.
  /// `ConflictAlgorithm.replace` on both tables makes this a true restore,
  /// not a near-copy with freshly minted ids. Reinserting the sets in their
  /// original order preserves `getSetLogsForSession`'s `rowid ASC` reading
  /// of them even though the delete cleared their prior rowids.
  Future<void> _restoreLog(SessionLog log, List<SetLog> sets) async {
    final db = DatabaseService.instance;
    await db.restoreSessionLog(
      log.toMap(),
      sets.map((s) => s.toMap()).toList(),
    );
    if (!mounted) return;
    await _loadLogs();
  }

  double get _totalVolumeAllTime =>
      _logs.fold(0.0, (sum, l) => sum + l.totalVolumeKg);

  double get _totalBurnedKcal =>
      _logs.fold<double>(0, (s, l) => s + l.kcalBurned);

  /// Estimates stay marked as estimates even in an aggregate. Reuses
  /// `SessionLog.formatKcal` rather than re-deriving its rounding and `~`
  /// prefix rules — the exact duplication `sessionArchiveLine` exists to
  /// eliminate — falling back to `--` since `formatKcal` returns `''` for
  /// "no estimate", not "0 kcal".
  String get _totalBurnedLabel {
    final label = SessionLog.formatKcal(_totalBurnedKcal);
    return label.isEmpty ? '--' : label;
  }

  String get _streakLabel {
    if (_streakDays == 0) return 'NO ACTIVE STREAK';
    return _streakDays == 1 ? '1 DAY STREAK' : '$_streakDays DAY STREAK';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: JinatraTokens.deepTeal));
    }

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRAINING LOG & HISTORY', style: JinatraTokens.sectionHeader()),
            const SizedBox(height: 16),

            HeroCard(
              eyebrow: 'CONSISTENCY',
              title: _streakLabel,
              subtitle: '${_logs.length} WORKOUTS - '
                  '${_totalVolumeAllTime.toInt()} KG TOTAL',
              background: JinatraTokens.accentAt(0),
            ),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'WORKOUTS',
                    value: '${_logs.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'TOTAL BURNED',
                    value: _totalBurnedLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('WORKOUT ARCHIVE', style: JinatraTokens.monoData(fontSize: 14)),
            const SizedBox(height: 8),

            Expanded(
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        'NO COMPLETED WORKOUTS YET\nFinish a live session on the TODAY tab '
                        'and it lands here automatically.',
                        textAlign: TextAlign.center,
                        style: JinatraTokens.monoData(
                          color: JinatraTokens.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) => _buildLogCard(_logs[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(SessionLog log) {
    final isOpen = _expanded.contains(log.id);
    final sets = _expandedSets[log.id] ?? const <SetLog>[];

    return JinatraCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleExpand(log),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.dayName,
                        style: JinatraTokens.sectionHeader(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sessionArchiveLine(log),
                        style: JinatraTokens.monoData(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${log.totalVolumeKg.toInt()} kg',
                      style: JinatraTokens.monoData(
                        fontSize: 14,
                        color: JinatraTokens.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      isOpen ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: JinatraTokens.ink,
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isOpen) ...[
            Divider(color: JinatraTokens.ink, height: 20, thickness: 2),
            if (sets.isEmpty)
              Text(
                'No set detail stored for this entry.',
                style: JinatraTokens.bodyText(
                  fontSize: 12,
                  color: JinatraTokens.ink.withValues(alpha: 0.6),
                ),
              )
            else
              ..._groupByExercise(sets).entries.map((entry) {
                final reps = entry.value.map((s) => s.reps).join(', ');
                final weight = entry.value.first.weightKg;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: JinatraTokens.bodyText(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: JinatraTokens.mistTeal,
                          border: Border.all(color: JinatraTokens.ink, width: 1),
                        ),
                        child: Text(
                          weight > 0
                              ? '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)}kg x $reps'
                              : '$reps reps',
                          style: JinatraTokens.monoData(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 6),
            // Padding lives *inside* the detector so the tappable area
            // grows to a 40dp-tall bar without enlarging the visible text.
            // The affordance itself is deliberately not BODY/FOOD's —
            // those use an `Icons.delete_outline` button; the brief
            // specifies a red text link for LOG. What matches (Ruling F)
            // is the hit box and the shared `showUndoBanner` mechanism,
            // not the widget.
            GestureDetector(
              onTap: () => _deleteLog(log),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'DELETE ENTRY',
                  style: JinatraTokens.monoData(fontSize: 10, color: JinatraTokens.signal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Preserves insertion order so exercises read back in the order trained.
  Map<String, List<SetLog>> _groupByExercise(List<SetLog> sets) {
    final grouped = <String, List<SetLog>>{};
    for (final s in sets) {
      grouped.putIfAbsent(s.exerciseName, () => []).add(s);
    }
    return grouped;
  }
}
