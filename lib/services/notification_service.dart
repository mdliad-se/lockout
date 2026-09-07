import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'database_service.dart';
import 'schedule_service.dart';

/// Local-only reminders. Nothing leaves the device — these are scheduled by
/// the OS from data already stored in SQLite.
///
/// Reminders are scheduled *inexactly*. Exact alarms would need the
/// SCHEDULE_EXACT_ALARM grant, which Android treats as a restricted permission
/// and which a training nudge does not justify; a few minutes of drift is fine.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _workoutReminderId = 1001;
  static const int _streakReminderId = 1002;

  static const String _channelId = 'lockout_training';
  static const String _channelName = 'Training Reminders';
  static const String _channelDescription =
      'Daily workout nudges and streak warnings from LOCKOUT.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Safe to call more than once; later calls are no-ops.
  Future<void> init() async {
    if (_ready) return;

    try {
      tzdata.initializeTimeZones();
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Falls back to UTC. Reminders still fire, just anchored to UTC offset.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    _ready = true;
  }

  /// Asks the OS for permission. Returns false when the user declines, so the
  /// settings toggle can refuse to switch on rather than lying to the user.
  Future<bool> requestPermission() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final darwin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      final granted = await darwin.requestPermissions(alert: true, sound: true);
      return granted ?? false;
    }

    return false;
  }

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Next occurrence of [hour]:[minute], today if still ahead, else tomorrow.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Rebuilds every scheduled reminder from current settings. Call after any
  /// settings change so the OS never holds a stale schedule.
  Future<void> rescheduleAll() async {
    await init();
    await cancelAll();

    final db = DatabaseService.instance;
    final enabled =
        await db.getSetting('reminders_enabled', defaultValue: 'false');
    if (enabled != 'true') return;

    final hour = int.tryParse(
          await db.getSetting('reminder_hour', defaultValue: '18'),
        ) ??
        18;
    final minute = int.tryParse(
          await db.getSetting('reminder_minute', defaultValue: '0'),
        ) ??
        0;

    await _scheduleDaily(
      id: _workoutReminderId,
      hour: hour,
      minute: minute,
      title: 'Training time',
      body: await _workoutReminderBody(),
    );

    final streakOn =
        await db.getSetting('streak_alerts_enabled', defaultValue: 'true');
    if (streakOn == 'true') {
      // Late-evening backstop: only useful if the day is about to lapse.
      await _scheduleDaily(
        id: _streakReminderId,
        hour: 21,
        minute: 0,
        title: 'Streak check',
        body: await _streakReminderBody(),
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Body text is baked in at schedule time, so it names the day that was
  /// scheduled rather than recomputing while the app is dead.
  Future<String> _workoutReminderBody() async {
    final sched = await ScheduleService.resolveToday();
    if (sched == null) return 'No session scheduled today. Rest or train off-plan.';
    return '${sched.day.name} - ${sched.exercises.length} exercises queued up.';
  }

  Future<String> _streakReminderBody() async {
    final dates = await DatabaseService.instance.getWorkoutDates();
    final streak = ScheduleService.currentStreakDays(dates);
    if (streak == 0) return 'No active streak. Today is a good day to start one.';
    return '$streak day streak on the line. Log a session before midnight.';
  }

  /// Immediate confirmation so the user can see the channel actually works.
  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      9999,
      'LOCKOUT reminders are on',
      'This is what a training nudge looks like.',
      _details,
    );
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancel(_workoutReminderId);
    await _plugin.cancel(_streakReminderId);
  }
}
