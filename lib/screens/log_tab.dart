import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/jinatra_card.dart';

class LogTab extends StatefulWidget {
  const LogTab({super.key});

  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  List<SessionLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final rows = await DatabaseService.instance.getSessionLogs();
    setState(() {
      _logs = rows.map((r) => SessionLog.fromMap(r)).toList();
      _isLoading = false;
    });
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
            Text('TRAINING LOG & HISTORY', style: JinatraTokens.sectionHeader()),
            const SizedBox(height: 16),

            // Streak & Summary Card
            JinatraCard(
              background: JinatraTokens.deepTeal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONSISTENCY STREAK', style: JinatraTokens.monoData(color: JinatraTokens.sweetCream, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('4 WEEKS ACTIVE', style: JinatraTokens.displayHeader(color: Colors.white, fontSize: 20)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: JinatraTokens.signal,
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                    ),
                    child: Text('GPL-3.0 OFFLINE', style: JinatraTokens.monoData(color: JinatraTokens.ink, fontSize: 10)),
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
                        'NO COMPLETED WORKOUTS YET\nComplete a live session in "TODAY" tab to archive history.',
                        textAlign: TextAlign.center,
                        style: JinatraTokens.monoData(color: JinatraTokens.ink.withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (ctx, idx) {
                        final log = _logs[idx];
                        return JinatraCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log.dayName, style: JinatraTokens.sectionHeader(fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(log.dateStr, style: JinatraTokens.monoData(fontSize: 12)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${log.totalVolumeKg.toInt()} kg vol', style: JinatraTokens.monoData(fontSize: 14, color: JinatraTokens.deepTeal)),
                                  const SizedBox(height: 2),
                                  Text('${(log.durationSeconds / 60).toInt()} mins', style: JinatraTokens.monoData(fontSize: 11)),
                                ],
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
