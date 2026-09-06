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

  // Active workout session sets with detailed weight & reps counter controls
  List<Map<String, dynamic>> _activeSets = [
    {'setNum': 1, 'weight': 60.0, 'reps': 10, 'completed': false},
    {'setNum': 2, 'weight': 60.0, 'reps': 10, 'completed': false},
    {'setNum': 3, 'weight': 60.0, 'reps': 10, 'completed': false},
    {'setNum': 4, 'weight': 60.0, 'reps': 8, 'completed': false},
  ];

  double get _totalVolumeKg {
    double total = 0.0;
    for (var s in _activeSets) {
      if (s['completed'] == true) {
        total += (s['weight'] as double) * (s['reps'] as int);
      }
    }
    return total;
  }

  int get _completedSetsCount => _activeSets.where((s) => s['completed'] == true).length;

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
              // Active Live Session Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JinatraTokens.deepTeal,
                  border: Border.all(color: JinatraTokens.ink, width: 3),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('BENCH PRESS', style: JinatraTokens.monoData(color: Colors.white, fontSize: 16)),
                        Text('LAST: 60kg × 10,10,8', style: JinatraTokens.monoData(color: JinatraTokens.sweetCream, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SETS COMPLETED: $_completedSetsCount / ${_activeSets.length}',
                          style: JinatraTokens.monoData(color: JinatraTokens.sweetCream, fontSize: 12),
                        ),
                        Text(
                          'VOLUME: ${_totalVolumeKg.toInt()} kg',
                          style: JinatraTokens.monoData(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Interactive Set Cards with Reps & Weight Controls
              Expanded(
                child: ListView.builder(
                  itemCount: _activeSets.length,
                  itemBuilder: (ctx, idx) {
                    final setItem = _activeSets[idx];
                    final isDone = setItem['completed'] as bool;
                    final reps = setItem['reps'] as int;
                    final weight = setItem['weight'] as double;

                    return JinatraCard(
                      background: isDone ? JinatraTokens.mistTeal : JinatraTokens.paper,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SET ${setItem['setNum']}',
                                style: JinatraTokens.monoData(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDone ? JinatraTokens.deepTeal : JinatraTokens.ink,
                                ),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDone ? JinatraTokens.deepTeal : JinatraTokens.sweetCream,
                                    border: Border.all(color: JinatraTokens.ink, width: 2),
                                    boxShadow: [JinatraTokens.hardShadow(offset: isDone ? 0 : 2)],
                                  ),
                                  child: Text(
                                    isDone ? 'COMPLETED ✓' : 'LOG SET',
                                    style: JinatraTokens.monoData(
                                      color: isDone ? Colors.white : JinatraTokens.ink,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Weight Counter Control
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: JinatraTokens.ink, width: 2),
                                    color: JinatraTokens.paper,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (weight > 0) {
                                            setState(() => setItem['weight'] = weight - 2.5);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: JinatraTokens.mistTeal,
                                            border: Border.all(color: JinatraTokens.ink, width: 1),
                                          ),
                                          child: Text('-', style: JinatraTokens.monoData(fontSize: 14)),
                                        ),
                                      ),
                                      Text('${weight.toStringAsFixed(1)} kg', style: JinatraTokens.monoData(fontSize: 12)),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => setItem['weight'] = weight + 2.5);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: JinatraTokens.mistTeal,
                                            border: Border.all(color: JinatraTokens.ink, width: 1),
                                          ),
                                          child: Text('+', style: JinatraTokens.monoData(fontSize: 14)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Reps Counter Control
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: JinatraTokens.ink, width: 2),
                                    color: JinatraTokens.paper,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (reps > 1) {
                                            setState(() => setItem['reps'] = reps - 1);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: JinatraTokens.mistTeal,
                                            border: Border.all(color: JinatraTokens.ink, width: 1),
                                          ),
                                          child: Text('-', style: JinatraTokens.monoData(fontSize: 14)),
                                        ),
                                      ),
                                      Text('$reps reps', style: JinatraTokens.monoData(fontSize: 12)),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => setItem['reps'] = reps + 1);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: JinatraTokens.mistTeal,
                                            border: Border.all(color: JinatraTokens.ink, width: 1),
                                          ),
                                          child: Text('+', style: JinatraTokens.monoData(fontSize: 14)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Rest Timer Drawer
              if (_isTimerRunning)
                Container(
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
                          const Icon(Icons.timer, color: JinatraTokens.signal),
                          const SizedBox(width: 8),
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

              JinatraButton(
                label: 'FINISH SESSION & SAVE',
                onPressed: () async {
                  await DatabaseService.instance.insertSessionLog({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'day_name': 'Push Session',
                    'date_str': DateTime.now().toIso8601String().split('T').first,
                    'duration_seconds': 2400,
                    'total_volume_kg': _totalVolumeKg,
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
