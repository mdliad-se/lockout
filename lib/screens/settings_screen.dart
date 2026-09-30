import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../services/notification_service.dart';
import '../services/numeric_guard.dart';
import '../services/nutrition_planner.dart';
import '../services/units.dart';
import '../theme/lockout_semantics.dart';
import '../theme/lockout_theme.dart';
import '../theme/schemes.dart';
import '../theme/theme_controller.dart';
import '../widgets/calm_row.dart';
import '../widgets/lockout_card.dart';
import '../widgets/lockout_field.dart';

/// The settings content, independent of how it is presented.
///
/// Split from its route so the Profile tab can host the same body without an
/// `AppBar`: a tab has nothing to pop back to, and a tab that grew its own bar
/// would sit a bar taller than its neighbours.
class SettingsBody extends StatefulWidget {
  final VoidCallback onSettingsUpdated;

  /// False when hosted as the Profile tab, where the surrounding screen owns
  /// the title and there is no route to pop.
  final bool showAppBar;

  // Non-const constructor: see "Why some constructors in this app are
  // not const" at the top of lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  SettingsBody({
    super.key,
    required this.onSettingsUpdated,
    this.showAppBar = true,
  });

  @override
  State<SettingsBody> createState() => SettingsBodyState();
}

/// The pushed-route form of settings.
///
/// Kept so anything that still navigates to a settings page - a notification
/// tap, a deep link, an older test - lands somewhere with a back button, even
/// though the primary entry point is now the Profile tab.
class SettingsScreen extends StatelessWidget {
  final VoidCallback onSettingsUpdated;

  // ignore: prefer_const_constructors_in_immutables
  SettingsScreen({super.key, required this.onSettingsUpdated});

  @override
  Widget build(BuildContext context) =>
      SettingsBody(onSettingsUpdated: onSettingsUpdated, showAppBar: true);
}

class SettingsBodyState extends State<SettingsBody> {
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

  /// Re-reads every setting. Public so `ProfileTab` can refresh the hosted
  /// body the same way the other tabs are refreshed on the way in.
  Future<void> reload() => _loadSettings();

  Future<void> _loadSettings() async {
    final db = DatabaseService.instance;
    final c = await db.getSetting(
      'calorie_target',
      defaultValue: '${DatabaseService.defaultCalorieTarget}',
    );
    final f = await db.getSetting('food_tab_enabled', defaultValue: 'true');
    final u = await db.getSetting('height_unit', defaultValue: 'cm');
    final rEnabled =
        await db.getSetting('reminders_enabled', defaultValue: 'false');
    final rHour = await db.getSetting('reminder_hour', defaultValue: '18');
    final rMin = await db.getSetting('reminder_minute', defaultValue: '0');
    final sAlerts =
        await db.getSetting('streak_alerts_enabled', defaultValue: 'true');

    final goal = await GoalService.instance.loadProfile();
    final snap = await GoalService.instance.snapshot();

    // Height comes from the profile, not a second raw read of the same row:
    // `GoalService.loadProfile` is where `height_cm` is clamped, and
    // `Units.cmToFeetInches` does `totalInches ~/ 12.0`, which throws
    // `Unsupported operation: Infinity or NaN toInt` on a non-finite value.
    // Parsing the row again here reintroduced exactly that throw — inside
    // `_loadSettings`, ahead of its `setState`, so a backup carrying
    // `height_cm = 'Infinity'` (import writes `user_settings` verbatim) left
    // Settings with every field empty and no plan, and took the reschedule,
    // the `onSettingsUpdated` callback and the "Import complete" toast in
    // `_import` down with it.
    final cm = goal.heightCm;
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

  /// Persists the training-days stepper the instant it changes.
  ///
  /// The Training card has no save button of its own — before this, its two
  /// controls lived nowhere near a writer, so `_daysPerWeek` only ever
  /// reached `training_days_per_week` if the user also opened the Food card
  /// and pressed "Calculate my target". `MainScreen` calls `reload()` on
  /// every tab switch, and `reload()` re-reads the database, so a stepper tap
  /// followed by switching tabs silently reverted with no feedback. Written
  /// directly rather than routed through `_saveGoalAndRecalculate`: that
  /// method also recalculates and reports a new calorie target, which is the
  /// Food card's action, not this one, and `training_days_per_week` does not
  /// feed the nutrition calculation at all (it only feeds the training
  /// recommendation `GoalService.snapshot()` derives on the fly, which is
  /// never persisted). A direct write here is the same shape
  /// `_saveHeightSettings` already takes for `height_cm` — a setting saved
  /// from more than one place in this file — and it matches the pattern this
  /// card's own reminder toggles already use: persist on change, no button.
  Future<void> _setDaysPerWeek(int days) async {
    setState(() => _daysPerWeek = days);
    await DatabaseService.instance
        .saveSetting('training_days_per_week', days.toString());
  }

  /// Persists the activity-level radio the instant it changes. See
  /// [_setDaysPerWeek] for why this is a direct write rather than a route
  /// through `_saveGoalAndRecalculate`.
  Future<void> _setActivity(ActivityLevel activity) async {
    setState(() => _activity = activity);
    await DatabaseService.instance.saveSetting('activity_level', activity.name);
    final snap = await GoalService.instance.snapshot();
    if (!mounted) return;
    setState(() => _plan = snap.nutrition);
  }

  /// Persists only the height fields. Split from the food/nutrition save
  /// action below so each grouped card commits what it actually owns.
  Future<void> _saveHeightSettings() async {
    final db = DatabaseService.instance;
    final cm = _resolveHeightCm();
    await db.saveSetting('height_cm', cm.toStringAsFixed(2));
    await db.saveSetting('height_unit', _heightUnit);
    widget.onSettingsUpdated();
    _toast('Saved height ${Units.formatHeight(cm, _heightUnit)}.');
  }

  /// Persists the manual calorie override and the nutrition tab toggle.
  Future<void> _saveFoodSettings() async {
    final db = DatabaseService.instance;
    await db.saveSetting('calorie_target', _calorieCtrl.text);
    await db.saveSetting(
      'food_tab_enabled',
      _foodTabEnabled ? 'true' : 'false',
    );
    widget.onSettingsUpdated();
    _toast('Saved food settings.');
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
    await db.saveSetting(
      'target_weight_kg',
      _sanitisedTargetWeightKg(_targetWeightCtrl.text),
    );
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

  /// The target weight as it may be persisted.
  ///
  /// `double.tryParse` accepts 'Infinity', '-Infinity' and 'NaN', so saving
  /// the field's raw text let a non-finite value reach `target_weight_kg`.
  /// `GoalService.loadProfile` parses it back unchanged, which made the BODY
  /// screen's TARGET tile render 'Infinity kg' and poisoned every calculation
  /// downstream of the goal profile. Anything that is not a finite,
  /// non-negative number is stored as '0' — exactly where unparseable text
  /// already lands on read, and the value that leaves `isConfigured` false so
  /// the user is asked for a real target rather than shown a fabricated
  /// plan. The finite/non-negative rule itself is `NumericGuard`'s, shared
  /// with BODY's measurement form and the routine builder's weight field.
  static String _sanitisedTargetWeightKg(String raw) {
    final text = raw.trim();
    return NumericGuard.parse(text, min: 0.0) == null ? '0' : text;
  }

  /// Height in cm from whichever unit the user is currently editing.
  ///
  /// Guarded the same way [_sanitisedTargetWeightKg] is, and for the same
  /// reason: `double.tryParse` accepts 'Infinity' and 'NaN', `Infinity > 0`
  /// is true, and `double.infinity.toStringAsFixed(2)` is the literal string
  /// 'Infinity'. No numeric field here carries `inputFormatters`, so paste or
  /// a letters keyboard reaches this. A non-finite height stored to
  /// `height_cm` made `NutritionPlanner.build` throw `Unsupported operation:
  /// Infinity or NaN toInt` out of `GoalService.snapshot()` — which BODY,
  /// FOOD, TODAY and Settings itself all call, so one typed word bricked four
  /// screens until the row was overwritten. Anything not finite and positive
  /// falls back to the same 175.0 default unparseable text already lands on.
  double _resolveHeightCm() {
    if (_heightUnit == 'ft') {
      final feet = int.tryParse(_heightFtCtrl.text.trim()) ?? 0;
      final inches = NumericGuard.parse(_heightInCtrl.text) ?? 0;
      final cm = Units.feetInchesToCm(feet, inches);
      return _usableHeightCm(cm);
    }
    final cm = NumericGuard.parse(_heightCmCtrl.text) ?? 0;
    return _usableHeightCm(cm);
  }

  static double _usableHeightCm(double cm) =>
      NumericGuard.finite(cm, min: 0.0, minExclusive: true) ?? 175.0;

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
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: warn ? colors.errorContainer : colors.inverseSurface,
        content: Text(
          message,
          style: TextStyle(
            color: warn ? colors.onErrorContainer : colors.onInverseSurface,
          ),
        ),
      ),
    );
  }

  // --- THEME ---

  /// `key` is a [LockoutScheme.key], or [LockoutScheme.dynamicKey].
  Future<void> _applyTheme(String key) => ThemeController.instance.select(key);

  /// Tap handler for a theme swatch. `_applyTheme` persists the selection;
  /// a throw there (bad key, storage failure) must not vanish as a silent,
  /// unhandled async error — surface it the same way every other write on
  /// this screen does.
  Future<void> _selectTheme(String key) async {
    try {
      await _applyTheme(key);
    } catch (_) {
      _toast('Could not apply theme.', warn: true);
    }
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
    final semantics = LockoutSemantics.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Importing a backup deletes every routine, workout, meal and body '
          'entry currently on this device and replaces them with the file\'s '
          'contents. This cannot be undone — export a backup first if you are '
          'not sure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            // `semantics.danger`, not `colorScheme.error` — replacing every
            // row in the database is a destructive confirmation, the role
            // `LockoutSemantics` reserves `danger` for (see that class's
            // doc, and today_tab's discard dialog for the same rule). The
            // Import button that opens this dialog carries the same role:
            // the trigger and its confirmation are one action, so they
            // cannot resolve to two different reds.
            style: TextButton.styleFrom(foregroundColor: semantics.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Choose file'),
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
        await db.getSetting('theme_key', defaultValue: LockoutScheme.fallback.key);
    await ThemeController.instance.select(restoredTheme);
    if (!mounted) return;

    // A belt, and deliberately kept as one now that both braces hold:
    // `BackupService` coerces numeric columns on import, and every read on
    // the far side of this `await` goes through `NumericGuard` rather than
    // a cast, so nothing arriving through an import can still throw here.
    // What that leaves is an unenumerable class — any future failure in
    // `_loadSettings`, from a schema the running build does not know to a
    // disk error — and the consequence has not changed: unguarded, the
    // throw takes the reschedule, the callback and the toast with it, so
    // the import applies while the OS keeps the pre-restore reminder
    // schedule and the user is told nothing.
    // Re-reading settings is best-effort; everything after it is not.
    var reloaded = true;
    try {
      await _loadSettings();
    } catch (_) {
      reloaded = false;
    }
    await NotificationService.instance.rescheduleAll();
    widget.onSettingsUpdated();

    if (!mounted) return;
    // Two different things can be worth warning about, and they are
    // independent. `reloaded` is the belt above failing — rare, and now
    // unreachable from an import. `coercedValues` is the common one: the
    // restore succeeded by rewriting cells it could not read as `0`, and
    // saying only "Import complete" there reports a silent edit of the
    // user's own data as an unqualified success.
    final rewritten = result.coercedValues > 0;
    _toast(
      reloaded
          ? 'Import complete. ${result.rowsRestored} rows restored.'
              '${ImportResult.coercionNote(result.coercedValues)}'
          : 'Import complete. ${result.rowsRestored} rows restored, but some '
              'of them could not be read back. Check the backup file.',
      warn: !reloaded || rewritten,
    );
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // Null when hosted as the Profile tab: that screen owns the title, and
      // a pushed route is the only presentation with something to pop back to.
      appBar: widget.showAppBar ? AppBar(title: const Text('Settings')) : null,
      body: AbsorbPointer(
        absorbing: _busy,
        child: SingleChildScrollView(
          // Padding rather than a `SafeArea`: this route has an `AppBar` but
          // no `bottomNavigationBar`, so on an edge-to-edge window the list
          // runs to the physical bottom of the screen and the nav bar inset
          // cannot be cleared by a fixed padding alone. The tab screens
          // escape this only because `BottomNav` carries its own `SafeArea`.
          // Padding keeps content scrolling UNDER the bar, which a `SafeArea`
          // would stop, while still letting the user scroll the last line
          // clear of it.
          //
          // `paddingOf`, not `viewPaddingOf`: `resizeToAvoidBottomInset` has
          // already shortened this body when the keyboard is up, and
          // `viewPadding` ignores insets, so it would reserve another chunk
          // of dead space above the keyboard. `padding.bottom` collapses to 0
          // in exactly that case.
          padding: EdgeInsets.fromLTRB(
            LockoutTheme.screenPadding,
            LockoutTheme.spaceMd,
            LockoutTheme.screenPadding,
            LockoutTheme.spaceMd + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCaption(context, 'Appearance'),
              _buildAppearanceCard(context),
              const SizedBox(height: LockoutTheme.sectionGap),
              _sectionCaption(context, 'Units'),
              _buildUnitsCard(context),
              const SizedBox(height: LockoutTheme.sectionGap),
              _sectionCaption(context, 'Training'),
              _buildTrainingCard(context),
              const SizedBox(height: LockoutTheme.sectionGap),
              _sectionCaption(context, 'Food'),
              _buildFoodCard(context),
              const SizedBox(height: LockoutTheme.sectionGap),
              _sectionCaption(context, 'Notifications'),
              _buildNotificationsCard(context),
              const SizedBox(height: LockoutTheme.sectionGap),
              _sectionCaption(context, 'Data'),
              _buildDataCard(context),
              const SizedBox(height: LockoutTheme.sectionGap),
              _sectionCaption(context, 'About'),
              _buildAboutCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCaption(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ThemeController.instance;

    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Applies instantly.', style: theme.textTheme.bodySmall),
          const SizedBox(height: LockoutTheme.spaceMd),
          Wrap(
            spacing: LockoutTheme.spaceMd,
            runSpacing: LockoutTheme.spaceMd,
            // `pickerKeys` is the single source of "what the picker should
            // offer, in order" — it already gates the dynamic entry on
            // `dynamicAvailable`, so re-deriving that gate here would just be
            // a second copy of the same rule to keep in sync.
            children: [
              for (final key in controller.pickerKeys)
                if (key == LockoutScheme.dynamicKey)
                  _ThemeSwatch(
                    name: 'Match my phone',
                    colors: null,
                    icon: Icons.palette,
                    selected: controller.selectedKey == LockoutScheme.dynamicKey,
                    onTap: () => _selectTheme(LockoutScheme.dynamicKey),
                  )
                else
                  _ThemeSwatch(
                    name: LockoutScheme.byKey(key).name,
                    colors: LockoutScheme.byKey(key).colors,
                    selected: controller.selectedKey == key,
                    onTap: () => _selectTheme(key),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsCard(BuildContext context) {
    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cm', label: Text('Centimetres')),
                ButtonSegment(value: 'ft', label: Text('Feet / inches')),
              ],
              selected: {_heightUnit},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _switchHeightUnit(s.first),
            ),
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          if (_heightUnit == 'ft')
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LockoutField(
                    label: 'Height (ft)',
                    controller: _heightFtCtrl,
                    hint: '5',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: LockoutTheme.spaceSm),
                Expanded(
                  child: LockoutField(
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
            LockoutField(
              label: 'Height (cm)',
              controller: _heightCmCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          const SizedBox(height: LockoutTheme.spaceSm),
          FilledButton(
            onPressed: _saveHeightSettings,
            child: const Text('Save height'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingCard(BuildContext context) {
    final theme = Theme.of(context);

    return LockoutCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LockoutTheme.cardPadding,
              LockoutTheme.cardPadding,
              LockoutTheme.cardPadding,
              LockoutTheme.spaceSm,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: LockoutTheme.spaceMd,
                vertical: LockoutTheme.spaceSm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Training days per week',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _daysPerWeek > 2
                        ? () => _setDaysPerWeek(_daysPerWeek - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: LockoutTheme.minTouchTarget,
                      minHeight: LockoutTheme.minTouchTarget,
                    ),
                  ),
                  Text('$_daysPerWeek', style: theme.textTheme.titleMedium),
                  IconButton(
                    onPressed: _daysPerWeek < 6
                        ? () => _setDaysPerWeek(_daysPerWeek + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: LockoutTheme.minTouchTarget,
                      minHeight: LockoutTheme.minTouchTarget,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final a in ActivityLevel.values)
            RadioListTile<ActivityLevel>(
              value: a,
              groupValue: _activity,
              onChanged: (v) => _setActivity(v ?? _activity),
              title: Text(a.label),
              subtitle: Text(a.blurb),
              secondary: Text('x${a.multiplier}', style: theme.textTheme.labelMedium),
            ),
          const SizedBox(height: LockoutTheme.spaceXs),
        ],
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;

    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calories are calculated from these, not guessed — BMR by the '
            'Mifflin-St Jeor equation, then activity, then the deficit or '
            'surplus your goal needs.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: LockoutField(
                  label: 'Age',
                  controller: _ageCtrl,
                  hint: '28',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: LockoutTheme.spaceSm),
              Expanded(
                child: LockoutField(
                  label: 'Target weight (kg)',
                  controller: _targetWeightCtrl,
                  hint: '72',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: LockoutTheme.spaceSm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Sex>(
              segments: const [
                ButtonSegment(value: Sex.male, label: Text('Male')),
                ButtonSegment(value: Sex.female, label: Text('Female')),
              ],
              selected: {_sex},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          LockoutField(
            label: 'Timeframe (weeks)',
            controller: _weeksCtrl,
            hint: '12',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: LockoutTheme.spaceSm),
          FilledButton(
            onPressed: _saveGoalAndRecalculate,
            child: const Text('Calculate my target'),
          ),
          if (plan != null) ...[
            const SizedBox(height: LockoutTheme.spaceMd),
            Container(
              padding: const EdgeInsets.all(LockoutTheme.cardPadding),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(LockoutTheme.radiusCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily target',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                      ),
                      Chip(label: Text(plan.directionLabel)),
                    ],
                  ),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text(
                    '${plan.targetKcal} kcal',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: LockoutTheme.spaceSm),
                  Text(
                    'BMR ${plan.bmr.round()} -> TDEE ${plan.tdee.round()} -> '
                    '${plan.dailyDeltaKcal >= 0 ? '+' : ''}${plan.dailyDeltaKcal} kcal/day',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: LockoutTheme.spaceXs),
                  Text(
                    'P ${plan.proteinG}g  ·  C ${plan.carbG}g  ·  F ${plan.fatG}g',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (plan.warning != null) ...[
              const SizedBox(height: LockoutTheme.spaceSm),
              Container(
                padding: const EdgeInsets.all(LockoutTheme.spaceMd),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
                ),
                child: Text(
                  plan.warning!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                ),
              ),
            ],
          ],
          const Divider(height: LockoutTheme.sectionGap),
          LockoutField(
            label: 'Daily calorie target (kcal)',
            controller: _calorieCtrl,
            keyboardType: TextInputType.number,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: LockoutTheme.spaceSm),
            child: Text(
              'Set automatically by "Calculate my target" above. Override it '
              'here only if you already know what you are doing.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable nutrition tab'),
            value: _foodTabEnabled,
            onChanged: (val) => setState(() => _foodTabEnabled = val),
          ),
          const SizedBox(height: LockoutTheme.spaceSm),
          FilledButton(
            onPressed: _saveFoodSettings,
            child: const Text('Save food settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(BuildContext context) {
    return LockoutCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Daily training nudge'),
            subtitle: const Text('Scheduled on this device. Nothing is sent anywhere.'),
            value: _remindersEnabled,
            onChanged: _toggleReminders,
          ),
          if (_remindersEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LockoutTheme.cardPadding,
              ),
              child: CalmRow(
                icon: Icons.schedule,
                title: 'Reminder time',
                value: _reminderTime.format(context),
                onTap: _pickReminderTime,
              ),
            ),
            SwitchListTile(
              title: const Text('Streak warning at 21:00'),
              value: _streakAlertsEnabled,
              onChanged: _toggleStreakAlerts,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LockoutTheme.cardPadding,
                0,
                LockoutTheme.cardPadding,
                LockoutTheme.cardPadding,
              ),
              child: OutlinedButton(
                onPressed: () async {
                  await NotificationService.instance.showTestNotification();
                  _toast('Test notification sent.');
                },
                child: const Text('Send test notification'),
              ),
            ),
          ] else
            const SizedBox(height: LockoutTheme.spaceXs),
        ],
      ),
    );
  }

  Widget _buildDataCard(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = LockoutSemantics.of(context);

    return LockoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export writes every routine, workout, set, meal, body entry and '
            'setting to a single JSON file. Import replaces everything on this '
            'device with the contents of a backup.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: LockoutTheme.spaceMd),
          FilledButton(
            onPressed: _busy ? null : _export,
            child: Text(_busy ? 'Working…' : 'Export backup JSON'),
          ),
          const SizedBox(height: LockoutTheme.spaceSm),
          // Destructive: this replaces every row on the device. It sits at
          // the bottom of the card, behind the confirmation dialog in
          // `_import`, and carries `semantics.danger` — the same role as
          // that dialog's confirm button. Colouring the trigger `error` and
          // the confirmation `danger` split one action across two roles,
          // which `ThemeController._harmonised` can resolve to two visibly
          // different reds under a dynamic (Material You) scheme.
          OutlinedButton(
            key: const Key('importBackupButton'),
            onPressed: _busy ? null : _import,
            style: OutlinedButton.styleFrom(
              foregroundColor: semantics.danger,
              side: BorderSide(color: semantics.danger),
            ),
            child: Text(_busy ? 'Working…' : 'Import backup JSON'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    final theme = Theme.of(context);

    return LockoutCard(
      child: Text(
        'LOCKOUT v1.1.0\nPublished by Jinatra Ltd. under GPL-3.0-or-later.\n'
        'Offline-first: routines, workout logs, nutrition and body data are '
        'stored only on this device in SQLite. No analytics, no ads, no '
        'account.\nThe network is used for one thing — streaming exercise '
        'form videos from YouTube when you tap WATCH.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

/// One selectable appearance in the theme picker: a 2-column miniature card
/// preview, the scheme name, and a check mark when selected.
///
/// [colors] is null only for the dynamic ("Match my phone") entry, which has
/// no fixed swatch of its own — its preview is [icon] instead.
class _ThemeSwatch extends StatelessWidget {
  final String name;
  final ColorScheme? colors;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.name,
    required this.colors,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final swatchColors = colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
      child: Container(
        width: LockoutTheme.swatchWidth,
        padding: const EdgeInsets.all(LockoutTheme.spaceSm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: LockoutTheme.swatchPreviewHeight,
                  width: double.infinity,
                  padding: const EdgeInsets.all(LockoutTheme.spaceXs),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: swatchColors?.surface ??
                        theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(LockoutTheme.radiusButton),
                  ),
                  child: swatchColors == null
                      ? Icon(icon, color: theme.colorScheme.onSurfaceVariant)
                      : Row(
                          children: [
                            Expanded(child: _pill(swatchColors.primary)),
                            const SizedBox(width: LockoutTheme.spaceXs),
                            Expanded(child: _pill(swatchColors.secondary)),
                          ],
                        ),
                ),
                if (selected)
                  Positioned(
                    top: LockoutTheme.swatchCheckOffset,
                    right: LockoutTheme.swatchCheckOffset,
                    child: Icon(
                      Icons.check_circle,
                      size: LockoutTheme.swatchCheckSize,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LockoutTheme.spaceXs),
            Text(
              name,
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(Color color) => Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(LockoutTheme.radiusPill),
        ),
      );
}
