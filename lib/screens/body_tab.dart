import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_input.dart';

class BodyTab extends StatefulWidget {
  const BodyTab({super.key});

  @override
  State<BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends State<BodyTab> {
  List<BodyEntry> _bodyLogs = [];
  double _userHeightCm = 175.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rows = await DatabaseService.instance.getBodyLogs();
    final heightStr = await DatabaseService.instance.getSetting('height_cm', defaultValue: '175.0');
    
    setState(() {
      _bodyLogs = rows.map((r) => BodyEntry.fromMap(r)).toList();
      _userHeightCm = double.tryParse(heightStr) ?? 175.0;
      _isLoading = false;
    });
  }

  double? get _latestWeight => _bodyLogs.isNotEmpty ? _bodyLogs.first.weightKg : null;

  double? get _calculatedBMI {
    if (_latestWeight == null || _userHeightCm <= 0) return null;
    final hMeters = _userHeightCm / 100.0;
    return _latestWeight! / (hMeters * hMeters);
  }

  void _showAddEntryModal() {
    final weightCtrl = TextEditingController();
    final waistCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JinatraTokens.sweetCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LOG BODY METRICS', style: JinatraTokens.sectionHeader()),
            const SizedBox(height: 14),
            JinatraInput(label: 'Weight (kg)', controller: weightCtrl, keyboardType: TextInputType.number),
            JinatraInput(label: 'Waist (cm)', controller: waistCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            JinatraButton(
              label: 'SAVE MEASUREMENT',
              onPressed: () async {
                if (weightCtrl.text.isEmpty) return;
                final dateToday = DateTime.now().toIso8601String().split('T').first;
                final entry = BodyEntry(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  dateStr: dateToday,
                  weightKg: double.parse(weightCtrl.text),
                  waistCm: double.tryParse(waistCtrl.text) ?? 0.0,
                );
                await DatabaseService.instance.insertBodyLog(entry.toMap());
                Navigator.pop(ctx);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: JinatraTokens.deepTeal));
    }

    final bmi = _calculatedBMI;

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BODY METRICS', style: JinatraTokens.sectionHeader()),
                JinatraButton(label: '+ LOG WEIGHT', onPressed: _showAddEntryModal),
              ],
            ),
            const SizedBox(height: 16),

            // BMI & Weight Overview Card
            JinatraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LATEST WEIGHT', style: JinatraTokens.monoData(fontSize: 11)),
                          Text(
                            _latestWeight != null ? '${_latestWeight!.toStringAsFixed(1)} kg' : '--',
                            style: JinatraTokens.displayHeader(fontSize: 24),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('CALCULATED BMI', style: JinatraTokens.monoData(fontSize: 11)),
                          Text(
                            bmi != null ? bmi.toStringAsFixed(1) : '--',
                            style: JinatraTokens.displayHeader(fontSize: 24, color: JinatraTokens.deepTeal),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: JinatraTokens.mistTeal,
                      border: Border.all(color: JinatraTokens.ink, width: 2),
                    ),
                    child: Text(
                      'Note: BMI is one reference indicator and does not distinguish muscle mass from fat mass for strength athletes.',
                      style: JinatraTokens.bodyText(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Text('LOG HISTORY', style: JinatraTokens.monoData(fontSize: 14)),
            const SizedBox(height: 8),

            Expanded(
              child: _bodyLogs.isEmpty
                  ? Center(
                      child: Text(
                        'NO WEIGHT ENTRIES LOGGED YET\nTap "+ LOG WEIGHT" to add a measurement.',
                        textAlign: TextAlign.center,
                        style: JinatraTokens.monoData(color: JinatraTokens.ink.withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _bodyLogs.length,
                      itemBuilder: (ctx, idx) {
                        final log = _bodyLogs[idx];
                        return JinatraCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(log.dateStr, style: JinatraTokens.monoData(fontSize: 14)),
                              Row(
                                children: [
                                  Text('${log.weightKg} kg', style: JinatraTokens.sectionHeader(fontSize: 16)),
                                  if (log.waistCm > 0) ...[
                                    const SizedBox(width: 12),
                                    Text('(${log.waistCm} cm waist)', style: JinatraTokens.monoData(fontSize: 12)),
                                  ],
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
