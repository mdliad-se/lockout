import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../services/notification_service.dart';
import '../services/nutrition_planner.dart';
import '../services/units.dart';
import '../theme/app_palette.dart';
import '../theme/jinatra_tokens.dart';
import '../widgets/jinatra_button.dart';
import '../widgets/jinatra_card.dart';
import '../widgets/jinatra_input.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSettingsUpdated;

  const SettingsScreen({super.key, required this.onSettingsUpdated});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _heightCmCtrl = TextEditingController();
  final _heightFtCtrl = TextEditingController();
  final _heightInCtrl = TextEditingController();
  final _calorieCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController();

  Sex _sex = Sex.male;
  ActivityLevel _activity = ActivityLevel.moderate;
  int _daysPerWeek = 4;
  NutritionPlan? _plan;

  bool _foodTabEnabled = true;
  bool _remindersEnabled = false;
  bool _streakAlertsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);

  /// 'cm' or 'ft' — controls which height inputs are shown.
  String _heightUnit = 'cm';
  String _themeKey = AppPalette.fallback.key;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _heightCmCtrl.dispose();
    _heightFtCtrl.dispose();
    _heightInCtrl.dispose();
    _calorieCtrl.dispose();
    _ageCtrl.dispose();
    _targetWeightCtrl.dispose();
    _weeksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService.instance;
    final h = await db.getSetting('height_cm', defaultValue: '175.0');
    final c = await db.getSetting('calorie_target', defaultValue: '2200');
    final f = await db.getSetting('food_tab_enabled', defaultValue: 'true');
    final u = await db.getSetting('height_unit', defaultValue: 'cm');
    final t =
        await db.getSetting('theme_key', defaultValue: AppPalette.fallback.key);
    final rEnabled =
        await db.getSetting('reminders_enabled', defaultValue: 'false');
    final rHour = await db.getSetting('reminder_hour', defaultValue: '18');
    final rMin = await db.getSetting('reminder_minute', defaultValue: '0');
    final sAlerts =
        await db.getSetting('streak_alerts_enabled', defaultValue: 'true');

    final goal = await GoalService.instance.loadProfile();
    final snap = await GoalService.instance.snapshot();

    final cm = double.tryParse(h) ?? 175.0;
    final split = Units.cmToFeetInches(cm);

    if (!mounted) return;
    setState(() {
      _heightCmCtrl.text = cm.toStringAsFixed(cm % 1 == 0 ? 0 : 1);
      _heightFtCtrl.text = split.feet.toString();
      _heightInCtrl.text =
          split.inches.toStringAsFixed(split.inches % 1 == 0 ? 0 : 1);
      _calorieCtrl.text = c;
      _foodTabEnabled = f == 'true';
      _heightUnit = u == 'ft' ? 'ft' : 'cm';
      _themeKey = t;
      _remindersEnabled = rEnabled == 'true';
      _streakAlertsEnabled = sAlerts == 'true';
      _reminderTime = TimeOfDay(
        hour: int.tryParse(rHour) ?? 18,
        minute: int.tryParse(rMin) ?? 0,
      );

      _ageCtrl.text = goal.age > 0 ? goal.age.toString() : '';
      _targetWeightCtrl.text =
          goal.targetWeightKg > 0 ? goal.targetWeightKg.toString() : '';
      _weeksCtrl.text = goal.weeks.toString();
      _sex = goal.sex;
      _activity = goal.activity;
      _daysPerWeek = goal.daysPerWeek;
      _plan = snap.nutrition;
    });
  }

  /// Persists the goal inputs, then recomputes the calorie target from them.
  /// The target is derived, never typed — that is the whole point.
  Future<void> _saveGoalAndRecalculate() async {
    final db = DatabaseService.instance;
    await db.saveSetting('height_cm', _resolveHeightCm().toStringAsFixed(2));
    await db.saveSetting('height_unit', _heightUnit);
    await db.saveSetting('age', _ageCtrl.text.trim());
    await db.saveSetting('sex', _sex.name);
    await db.saveSetting('activity_level', _activity.name);
    await db.saveSetting('target_weight_kg', _targetWeightCtrl.text.trim());
    await db.saveSetting('goal_weeks', _weeksCtrl.text.trim());
    await db.saveSetting('training_days_per_week', _daysPerWeek.toString());

    final plan = await GoalService.instance.recalculateAndSaveTarget();
    if (!mounted) return;

    setState(() {
      _plan = plan;
      if (plan != null) _calorieCtrl.text = plan.targetKcal.toString();
    });
    widget.onSettingsUpdated();

    if (plan == null) {
      _toast(
        'Add your age, target weight and one body-weight entry to calculate a target.',
        warn: true,
      );
    } else {
      _toast('Target set to ${plan.targetKcal} kcal/day.');
    }
  }

  /// Height in cm from whichever unit the user is currently editing.
  double _resolveHeightCm() {
    if (_heightUnit == 'ft') {
      final feet = int.tryParse(_heightFtCtrl.text.trim()) ?? 0;
      final inches = double.tryParse(_heightInCtrl.text.trim()) ?? 0;
      final cm = Units.feetInchesToCm(feet, inches);
      return cm > 0 ? cm : 175.0;
    }
    final cm = double.tryParse(_heightCmCtrl.text.trim()) ?? 0;
    return cm > 0 ? cm : 175.0;
  }

  /// Keeps the hidden unit's fields in sync so switching units never loses
  /// the value the user just typed.
  void _switchHeightUnit(String unit) {
    final cm = _resolveHeightCm();
    setState(() {
      _heightUnit = unit;
      _heightCmCtrl.text = cm.toStringAsFixed(cm % 1 == 0 ? 0 : 1);
      final split = Units.cmToFeetInches(cm);
      _heightFtCtrl.text = split.feet.toString();
      _heightInCtrl.text =
          split.inches.toStringAsFixed(split.inches % 1 == 0 ? 0 : 1);
    });
  }

  void _toast(String message, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: warn ? JinatraTokens.signal : JinatraTokens.deepTeal,
        content: Text(
          message,
          style: JinatraTokens.monoData(
            color: warn ? JinatraTokens.onAccent : JinatraTokens.onPrimary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // --- THEME ---

  Future<void> _applyTheme(AppPalette palette) async {
    await DatabaseService.instance.saveSetting('theme_key', palette.key);
    AppPalette.apply(palette);
    if (!mounted) return;
    setState(() => _themeKey = palette.key);
  }

  // --- REMINDERS ---

  Future<void> _toggleReminders(bool value) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        _toast('Notification permission denied in system settings.', warn: true);
        return;
      }
    }

    await DatabaseService.instance
        .saveSetting('reminders_enabled', value ? 'true' : 'false');
    if (!mounted) return;
    setState(() => _remindersEnabled = value);

    await NotificationService.instance.rescheduleAll();
    _toast(value ? 'Reminders scheduled.' : 'Reminders switched off.');
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null || !mounted) return;

    setState(() => _reminderTime = picked);
    final db = DatabaseService.instance;
    await db.saveSetting('reminder_hour', picked.hour.toString());
    await db.saveSetting('reminder_minute', picked.minute.toString());
    await NotificationService.instance.rescheduleAll();

    if (!mounted) return;
    _toast('Reminder set for ${picked.format(context)}.');
  }

  Future<void> _toggleStreakAlerts(bool value) async {
    await DatabaseService.instance
        .saveSetting('streak_alerts_enabled', value ? 'true' : 'false');
    if (!mounted) return;
    setState(() => _streakAlertsEnabled = value);
    await NotificationService.instance.rescheduleAll();
  }

  // --- BACKUP ---

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await BackupService.instance.exportAndShare();
    } catch (e) {
      _toast('Export failed: $e', warn: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JinatraTokens.sweetCream,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JinatraTokens.ink, width: 3),
          borderRadius: BorderRadius.zero,
        ),
        title: Text('REPLACE ALL DATA?',
            style: JinatraTokens.sectionHeader(fontSize: 16)),
        content: Text(
          'Importing a backup deletes every routine, workout, meal and body '
          'entry currently on this device and replaces them with the file\'s '
          'contents. This cannot be undone — export a backup first if you are '
          'not sure.',
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
              'CHOOSE FILE',
              style: JinatraTokens.monoData(
                  fontSize: 12, color: JinatraTokens.signal),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = await BackupService.instance.pickAndImport();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      _toast(result.message, warn: true);
      return;
    }

    // Restored settings include the theme, so re-read everything.
    final db = DatabaseService.instance;
    final restoredTheme =
        await db.getSetting('theme_key', defaultValue: AppPalette.fallback.key);
    AppPalette.applyKey(restoredTheme);
    if (!mounted) return;
    await _loadSettings();
    await NotificationService.instance.rescheduleAll();
    widget.onSettingsUpdated();

    if (!mounted) return;
    _toast('Import complete. ${result.rowsRestored} rows restored.');
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      appBar: AppBar(
        backgroundColor: JinatraTokens.sweetCream,
        elevation: 0,
        iconTheme: IconThemeData(color: JinatraTokens.ink),
        shape: Border(
          bottom: BorderSide(
              color: JinatraTokens.ink, width: JinatraTokens.borderControl),
        ),
        title:
            Text('SETTINGS', style: JinatraTokens.sectionHeader(fontSize: 18)),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThemeCard(),
              const SizedBox(height: 12),
              _buildProfileCard(),
              const SizedBox(height: 12),
              _buildGoalCard(),
              const SizedBox(height: 12),
              _buildRemindersCard(),
              const SizedBox(height: 12),
              _buildDataCard(),
              const SizedBox(height: 12),
              _buildAboutCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard() {
    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPEARANCE', style: JinatraTokens.monoData(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'Eight neubrutalist palettes. Applies instantly.',
            style: JinatraTokens.bodyText(
              fontSize: 12,
              color: JinatraTokens.ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          Text('LIGHT', style: JinatraTokens.monoData(fontSize: 11)),
          const SizedBox(height: 8),
          _themeGrid(AppPalette.light),
          const SizedBox(height: 16),
          Text('DARK', style: JinatraTokens.monoData(fontSize: 11)),
          const SizedBox(height: 8),
          _themeGrid(AppPalette.dark),
        ],
      ),
    );
  }

  Widget _themeGrid(List<AppPalette> palettes) {
    return Column(
      children: [
        for (var i = 0; i < palettes.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _themeSwatch(palettes[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < palettes.length
                      ? _themeSwatch(palettes[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _themeSwatch(AppPalette p) {
    final selected = p.key == _themeKey;

    return GestureDetector(
      onTap: () => _applyTheme(p),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.canvas,
          border: Border.all(
            color: selected ? JinatraTokens.signal : JinatraTokens.ink,
            width: selected ? 4 : 2,
          ),
          boxShadow: [JinatraTokens.hardShadow(offset: selected ? 4 : 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature of a card carrying a primary, accent and alt chip.
            Container(
              height: 34,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.ink, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Container(color: p.primary)),
                  const SizedBox(width: 4),
                  Expanded(child: Container(color: p.accent)),
                  const SizedBox(width: 4),
                  Expanded(child: Container(color: p.surfaceAlt)),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name.toUpperCase(),
                    style: JinatraTokens.monoData(fontSize: 9, color: p.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected) Icon(Icons.check, size: 13, color: p.ink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROFILE & PREFERENCES',
              style: JinatraTokens.monoData(fontSize: 14)),
          const SizedBox(height: 14),

          Text('HEIGHT UNIT', style: JinatraTokens.monoData(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _unitChoice(
                  label: 'FEET / INCHES',
                  selected: _heightUnit == 'ft',
                  onTap: () => _switchHeightUnit('ft'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _unitChoice(
                  label: 'CENTIMETRES',
                  selected: _heightUnit == 'cm',
                  onTap: () => _switchHeightUnit('cm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_heightUnit == 'ft')
            Row(
              children: [
                Expanded(
                  child: JinatraInput(
                    label: 'Height (ft)',
                    controller: _heightFtCtrl,
                    hint: '5',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: JinatraInput(
                    label: 'Height (in)',
                    controller: _heightInCtrl,
                    hint: '9',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            )
          else
            JinatraInput(
              label: 'Height (cm)',
              controller: _heightCmCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),

          JinatraInput(
            label: 'Daily Calorie Target (kcal)',
            controller: _calorieCtrl,
            keyboardType: TextInputType.number,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Set automatically by "Calculate My Target" below. Override it '
              'here only if you already know what you are doing.',
              style: JinatraTokens.bodyText(
                fontSize: 11,
                color: JinatraTokens.ink.withValues(alpha: 0.6),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ENABLE NUTRITION TAB',
                  style: JinatraTokens.monoData(fontSize: 13)),
              Switch(
                value: _foodTabEnabled,
                activeThumbColor: JinatraTokens.deepTeal,
                onChanged: (val) => setState(() => _foodTabEnabled = val),
              ),
            ],
          ),
          const SizedBox(height: 14),
          JinatraButton(
            label: 'SAVE SETTINGS',
            onPressed: () async {
              final db = DatabaseService.instance;
              final cm = _resolveHeightCm();

              await db.saveSetting('height_cm', cm.toStringAsFixed(2));
              await db.saveSetting('height_unit', _heightUnit);
              await db.saveSetting('calorie_target', _calorieCtrl.text);
              await db.saveSetting(
                'food_tab_enabled',
                _foodTabEnabled ? 'true' : 'false',
              );

              widget.onSettingsUpdated();
              _toast('Saved - height ${Units.formatHeight(cm, _heightUnit)}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard() {
    final plan = _plan;

    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GOAL & CALORIE TARGET',
              style: JinatraTokens.monoData(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'Your daily calories are calculated from these, not guessed. BMR '
            'uses the Mifflin-St Jeor equation, then activity, then the deficit '
            'or surplus your goal needs.',
            style: JinatraTokens.bodyText(
              fontSize: 12,
              color: JinatraTokens.ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: JinatraInput(
                  label: 'Age',
                  controller: _ageCtrl,
                  hint: '28',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: JinatraInput(
                  label: 'Target Weight (kg)',
                  controller: _targetWeightCtrl,
                  hint: '72',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),

          Text('SEX (FOR BMR EQUATION)',
              style: JinatraTokens.monoData(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _unitChoice(
                  label: 'MALE',
                  selected: _sex == Sex.male,
                  onTap: () => setState(() => _sex = Sex.male),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _unitChoice(
                  label: 'FEMALE',
                  selected: _sex == Sex.female,
                  onTap: () => setState(() => _sex = Sex.female),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('ACTIVITY LEVEL', style: JinatraTokens.monoData(fontSize: 12)),
          const SizedBox(height: 8),
          ...ActivityLevel.values.map((a) {
            final selected = a == _activity;
            return GestureDetector(
              onTap: () => setState(() => _activity = a),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      selected ? JinatraTokens.mistTeal : JinatraTokens.paper,
                  border: Border.all(
                    color:
                        selected ? JinatraTokens.deepTeal : JinatraTokens.ink,
                    width: selected ? 3 : 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: JinatraTokens.ink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.label.toUpperCase(),
                              style: JinatraTokens.monoData(fontSize: 11)),
                          Text(a.blurb,
                              style: JinatraTokens.bodyText(
                                fontSize: 11,
                                color:
                                    JinatraTokens.ink.withValues(alpha: 0.6),
                              )),
                        ],
                      ),
                    ),
                    Text('x${a.multiplier}',
                        style: JinatraTokens.monoData(fontSize: 10)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: JinatraInput(
                  label: 'Timeframe (weeks)',
                  controller: _weeksCtrl,
                  hint: '12',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DAYS / WEEK',
                        style: JinatraTokens.monoData(fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: JinatraTokens.paper,
                        border: Border.all(
                            color: JinatraTokens.ink,
                            width: JinatraTokens.borderControl),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() {
                              if (_daysPerWeek > 2) _daysPerWeek--;
                            }),
                            child: Text('-',
                                style: JinatraTokens.monoData(fontSize: 18)),
                          ),
                          Text('$_daysPerWeek',
                              style: JinatraTokens.monoData(fontSize: 15)),
                          GestureDetector(
                            onTap: () => setState(() {
                              if (_daysPerWeek < 6) _daysPerWeek++;
                            }),
                            child: Text('+',
                                style: JinatraTokens.monoData(fontSize: 18)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          JinatraButton(
            label: 'CALCULATE MY TARGET',
            onPressed: _saveGoalAndRecalculate,
          ),

          if (plan != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: JinatraTokens.deepTeal,
                border: Border.all(
                    color: JinatraTokens.ink,
                    width: JinatraTokens.borderControl),
                boxShadow: [JinatraTokens.hardShadow(offset: 3)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DAILY TARGET',
                          style: JinatraTokens.monoData(
                              color: JinatraTokens.onPrimary, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: JinatraTokens.signal,
                          border:
                              Border.all(color: JinatraTokens.ink, width: 2),
                        ),
                        child: Text(plan.directionLabel,
                            style: JinatraTokens.monoData(
                                fontSize: 9, color: JinatraTokens.onAccent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${plan.targetKcal} kcal',
                      style: JinatraTokens.displayHeader(
                          color: JinatraTokens.onPrimary, fontSize: 26)),
                  const SizedBox(height: 8),
                  Text(
                    'BMR ${plan.bmr.round()} -> TDEE ${plan.tdee.round()} -> '
                    '${plan.dailyDeltaKcal >= 0 ? '+' : ''}${plan.dailyDeltaKcal} kcal/day',
                    style: JinatraTokens.monoData(
                        color: JinatraTokens.sweetCream, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'P ${plan.proteinG}g  -  C ${plan.carbG}g  -  F ${plan.fatG}g',
                    style: JinatraTokens.monoData(
                        color: JinatraTokens.onPrimary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (plan.warning != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: JinatraTokens.signal,
                  border: Border.all(color: JinatraTokens.ink, width: 2),
                ),
                child: Text(
                  plan.warning!,
                  style: JinatraTokens.bodyText(
                      fontSize: 12, color: JinatraTokens.onAccent),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRemindersCard() {
    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REMINDERS & ACCOUNTABILITY',
              style: JinatraTokens.monoData(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'Scheduled by your device from local data. Nothing is sent anywhere.',
            style: JinatraTokens.bodyText(
              fontSize: 12,
              color: JinatraTokens.ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('DAILY TRAINING NUDGE',
                    style: JinatraTokens.monoData(fontSize: 13)),
              ),
              Switch(
                value: _remindersEnabled,
                activeThumbColor: JinatraTokens.deepTeal,
                onChanged: _toggleReminders,
              ),
            ],
          ),

          if (_remindersEnabled) ...[
            GestureDetector(
              onTap: _pickReminderTime,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: JinatraTokens.mistTeal,
                  border: Border.all(color: JinatraTokens.ink, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('REMINDER TIME',
                        style: JinatraTokens.monoData(fontSize: 12)),
                    Text(
                      _reminderTime.format(context),
                      style: JinatraTokens.monoData(
                          fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('STREAK WARNING AT 21:00',
                      style: JinatraTokens.monoData(fontSize: 13)),
                ),
                Switch(
                  value: _streakAlertsEnabled,
                  activeThumbColor: JinatraTokens.deepTeal,
                  onChanged: _toggleStreakAlerts,
                ),
              ],
            ),
            const SizedBox(height: 6),
            JinatraButton(
              label: 'SEND TEST NOTIFICATION',
              background: JinatraTokens.paper,
              textColor: JinatraTokens.ink,
              onPressed: () async {
                await NotificationService.instance.showTestNotification();
                _toast('Test notification sent.');
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataCard() {
    return JinatraCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DATA BACKUP', style: JinatraTokens.monoData(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'Export writes every routine, workout, set, meal, body entry and '
            'setting to a single JSON file. Import replaces everything on this '
            'device with the contents of a backup.',
            style: JinatraTokens.bodyText(fontSize: 13),
          ),
          const SizedBox(height: 16),
          JinatraButton(
            label: _busy ? 'WORKING...' : 'EXPORT BACKUP JSON',
            onPressed: _busy ? () {} : _export,
          ),
          const SizedBox(height: 10),
          JinatraButton(
            label: _busy ? 'WORKING...' : 'IMPORT BACKUP JSON',
            isSignal: true,
            onPressed: _busy ? () {} : _import,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return JinatraCard(
      margin: EdgeInsets.zero,
      background: JinatraTokens.mistTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ABOUT LOCKOUT', style: JinatraTokens.monoData(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'LOCKOUT v1.1.0\nPublished by Jinatra Ltd. under GPL-3.0-or-later.\n'
            'Offline-first: routines, workout logs, nutrition and body data are '
            'stored only on this device in SQLite. No analytics, no ads, no '
            'account.\nThe network is used for one thing — streaming exercise '
            'form videos from YouTube when you tap WATCH.',
            style: JinatraTokens.bodyText(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _unitChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? JinatraTokens.deepTeal : JinatraTokens.paper,
          border: Border.all(color: JinatraTokens.ink, width: 3),
        ),
        child: Center(
          child: Text(
            label,
            style: JinatraTokens.monoData(
              fontSize: 11,
              color: selected ? JinatraTokens.onPrimary : JinatraTokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}
