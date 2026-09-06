import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_button.dart';

class TodayTab extends StatefulWidget {
  const TodayTab({super.key});

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  bool _isSessionActive = false;
  int _timerSeconds = 60;
  bool _isTimerRunning = false;
  Timer? _timer;

  // Active workout mock data for interactive session
  List<Map<String, dynamic>> _activeSets = [
    {'set': 1, 'target': '60kg × 10', 'weight': 60.0, 'reps': 10, 'completed': false},
    {'set': 2, 'target': '60kg × 10', 'weight': 60.0, 'reps': 10, 'completed': false},
    {'set': 3, 'target': '60kg × 10', 'weight': 60.0, 'reps': 10, 'completed': false},
    {'set': 4, 'target': '60kg × 10', 'weight': 60.0, 'reps': 10, 'completed': false},
  ];

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timerSeconds = seconds;
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isTimerRunning = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY WORKOUT', style: JinatraTokens.sectionHeader()),
            const SizedBox(height: 12),
            if (!_isSessionActive) ...[
              JinatraCard(
                shadowOffset: JinatraTokens.shadowLg,
                child: Column(
                  children: [
                    Text('READY TO LIFT?', style: JinatraTokens.displayHeader(fontSize: 22)),
                    const SizedBox(height: 8),
                    Text(
                      'No active workout session in progress. Select a scheduled day or start a custom session.',
                      textAlign: TextAlign.center,
                      style: JinatraTokens.bodyText(),
                    ),
                    const SizedBox(height: 20),
                    JinatraButton(
                      label: 'START LIVE SESSION',
                      onPressed: () => setState(() => _isSessionActive = true),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Active Live Workout Session View
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JinatraTokens.deepTeal,
                  border: Border.all(color: JinatraTokens.ink, width: 3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BENCH PRESS', style: JinatraTokens.monoData(color: Colors.white, fontSize: 16)),
                    Text('LAST: 60kg × 10,10,8', style: JinatraTokens.monoData(color: JinatraTokens.sweetCream, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _activeSets.length,
                  itemBuilder: (ctx, idx) {
                    final setItem = _activeSets[idx];
                    final isDone = setItem['completed'] as bool;

                    return JinatraCard(
                      background: isDone ? JinatraTokens.mistTeal : JinatraTokens.paper,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  border: Border.all(color: JinatraTokens.ink, width: 2),
                                  color: isDone ? JinatraTokens.deepTeal : JinatraTokens.paper,
                                ),
                                child: Center(
                                  child: Text(
                                    '${setItem['set']}',
                                    style: JinatraTokens.monoData(
                                      color: isDone ? Colors.white : JinatraTokens.ink,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(setItem['target'] as String, style: JinatraTokens.monoData(fontSize: 14)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                setItem['completed'] = !isDone;
                              });
                              if (!isDone) {
                                _startTimer(60);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 60),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDone ? JinatraTokens.deepTeal : JinatraTokens.sweetCream,
                                border: Border.all(color: JinatraTokens.ink, width: 2),
                                boxShadow: [JinatraTokens.hardShadow(offset: isDone ? 0 : 2)],
                              ),
                              child: Text(
                                isDone ? 'DONE ✓' : 'LOG SET',
                                style: JinatraTokens.monoData(
                                  color: isDone ? Colors.white : JinatraTokens.ink,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Neubrutalist Rest Timer Drawer
              if (_isTimerRunning)
                Container(
                  padding: const EdgeInsets.all(14),
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
                          const Icon(Icons.timer, color: JinatraTokens.signal),
                          const SizedBox(width: 10),
                          Text('REST TIMER:', style: JinatraTokens.monoData(fontSize: 12)),
                          const SizedBox(width: 8),
                          Text(
                            '${_timerSeconds}s',
                            style: JinatraTokens.monoData(fontSize: 18, color: JinatraTokens.signal),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _timerSeconds += 15),
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
                            onTap: () {
                              _timer?.cancel();
                              setState(() => _isTimerRunning = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: JinatraTokens.ink, width: 2),
                                color: JinatraTokens.signal,
                              ),
                              child: Text('SKIP', style: JinatraTokens.monoData(fontSize: 11, color: JinatraTokens.ink)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              JinatraButton(
                label: 'FINISH SESSION & SAVE',
                onPressed: () async {
                  await DatabaseService.instance.insertSessionLog({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'day_name': 'Push Session',
                    'date_str': DateTime.now().toIso8601String().split('T').first,
                    'duration_seconds': 2400,
                    'total_volume_kg': 2400.0,
                    'status': 'completed',
                  });
                  setState(() => _isSessionActive = false);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
