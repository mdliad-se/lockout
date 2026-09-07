import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/schedule_service.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/jinatra_card.dart';

class LogTab extends StatefulWidget {
  const LogTab({super.key});

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

  Future<void> _confirmDelete(SessionLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JinatraTokens.sweetCream,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JinatraTokens.ink, width: 3),
          borderRadius: BorderRadius.zero,
        ),
        title: Text('DELETE ENTRY?', style: JinatraTokens.sectionHeader(fontSize: 16)),
        content: Text(
          'This workout and its logged sets will be permanently removed from history.',
          style: JinatraTokens.bodyText(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: JinatraTokens.monoData(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DELETE',
              style: JinatraTokens.monoData(fontSize: 12, color: JinatraTokens.signal),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await DatabaseService.instance.deleteSessionLog(log.id);
      await _loadLogs();
    }
  }

  double get _totalVolumeAllTime =>
      _logs.fold(0.0, (sum, l) => sum + l.totalVolumeKg);

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

            JinatraCard(
              background: JinatraTokens.deepTeal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONSISTENCY',
                    style: JinatraTokens.monoData(
                      color: JinatraTokens.sweetCream,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _streakLabel,
                    style: JinatraTokens.displayHeader(color: JinatraTokens.onPrimary, fontSize: 22),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stat('WORKOUTS', '${_logs.length}'),
                      _stat('TOTAL VOLUME', '${_totalVolumeAllTime.toInt()} kg'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: JinatraTokens.monoData(color: JinatraTokens.sweetCream, fontSize: 9),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: JinatraTokens.monoData(
            color: JinatraTokens.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
                        '${log.dateStr}  -  ${log.durationLabel}  -  ${log.totalSets} sets',
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
            GestureDetector(
              onTap: () => _confirmDelete(log),
              child: Text(
                'DELETE ENTRY',
                style: JinatraTokens.monoData(fontSize: 10, color: JinatraTokens.signal),
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
