import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/jinatra_tokens.dart';
import '../services/database_service.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_input.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSettingsUpdated;

  const SettingsScreen({super.key, required this.onSettingsUpdated});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _heightCtrl = TextEditingController();
  final _calorieCtrl = TextEditingController();
  bool _foodTabEnabled = true;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final h = await DatabaseService.instance.getSetting('height_cm', defaultValue: '175.0');
    final c = await DatabaseService.instance.getSetting('calorie_target', defaultValue: '2200');
    final f = await DatabaseService.instance.getSetting('food_tab_enabled', defaultValue: 'true');
    final w = await DatabaseService.instance.getSetting('unit_weight', defaultValue: 'kg');

    setState(() {
      _heightCtrl.text = h;
      _calorieCtrl.text = c;
      _foodTabEnabled = f == 'true';
      _weightUnit = w;
    });
  }

  Future<void> _exportBackup() async {
    final routines = await DatabaseService.instance.getRoutines();
    final sessionLogs = await DatabaseService.instance.getSessionLogs();
    final bodyLogs = await DatabaseService.instance.getBodyLogs();
    final foodLogs = await DatabaseService.instance.getFoodLogsForDate(DateTime.now().toIso8601String().split('T').first);

    final backupData = {
      'app': 'lockout',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'data': {
        'routines': routines,
        'session_logs': sessionLogs,
        'body_logs': bodyLogs,
        'food_logs': foodLogs,
      }
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/lockout-backup-${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles([XFile(file.path)], text: 'LOCKOUT JSON Data Backup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      appBar: AppBar(
        backgroundColor: JinatraTokens.cardDecoration().color,
        elevation: 0,
        iconTheme: const IconThemeData(color: JinatraTokens.ink),
        title: Text('SETTINGS', style: JinatraTokens.sectionHeader(fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JinatraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROFILE & PREFERENCES', style: JinatraTokens.monoData(fontSize: 14)),
                  const SizedBox(height: 14),
                  JinatraInput(label: 'Height (cm)', controller: _heightCtrl, keyboardType: TextInputType.number),
                  JinatraInput(label: 'Daily Calorie Target (kcal)', controller: _calorieCtrl, keyboardType: TextInputType.number),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ENABLE NUTRITION TAB', style: JinatraTokens.monoData(fontSize: 13)),
                      Switch(
                        value: _foodTabEnabled,
                        activeColor: JinatraTokens.deepTeal,
                        onChanged: (val) {
                          setState(() => _foodTabEnabled = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  JinatraButton(
                    label: 'SAVE SETTINGS',
                    onPressed: () async {
                      await DatabaseService.instance.saveSetting('height_cm', _heightCtrl.text);
                      await DatabaseService.instance.saveSetting('calorie_target', _calorieCtrl.text);
                      await DatabaseService.instance.saveSetting('food_tab_enabled', _foodTabEnabled ? 'true' : 'false');
                      widget.onSettingsUpdated();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings updated successfully')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            JinatraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DATA EXPORT & BACKUP', style: JinatraTokens.monoData(fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    'LOCKOUT stores all data on-device in SQLite. Export your data anytime to a standard JSON file.',
                    style: JinatraTokens.bodyText(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  JinatraButton(
                    label: 'EXPORT BACKUP JSON',
                    isSignal: true,
                    onPressed: _exportBackup,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            JinatraCard(
              background: JinatraTokens.mistTeal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ABOUT LOCKOUT', style: JinatraTokens.monoData(fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    'LOCKOUT v1.0.0\nPublished by Jinatra Ltd. under GPL-3.0-or-later.\n100% Offline Architecture — No network calls, no analytics, no ads.',
                    style: JinatraTokens.bodyText(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
