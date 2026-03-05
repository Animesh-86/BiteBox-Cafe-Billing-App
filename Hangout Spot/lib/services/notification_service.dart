import 'package:hangout_spot/utils/log_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'inventory_reminders';
  static const String _channelName = 'Inventory Reminders';
  static const String _channelDescription =
      'Reminders for inventory updates and low stock alerts.';

  bool _permissionsRequested = false;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    // Detect the device's actual timezone (e.g., "Asia/Kolkata")
    // instead of defaulting to UTC.
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      logDebug('🕐 Timezone set to: $timeZoneName');
    } catch (e) {
      // Fallback: estimate timezone from Dart's DateTime offset
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours;
      // Try common timezone names based on offset
      String fallbackTz;
      if (hours == 5 && offset.inMinutes % 60 == 30) {
        fallbackTz = 'Asia/Kolkata';
      } else if (hours == 0) {
        fallbackTz = 'UTC';
      } else {
        fallbackTz = 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
      }
      try {
        tz.setLocalLocation(tz.getLocation(fallbackTz));
        logDebug('🕐 Timezone fallback to: $fallbackTz');
      } catch (_) {
        logDebug('⚠️ Could not set timezone, using UTC');
      }
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  /// Request all permissions needed for reliable scheduled notifications.
  /// Returns true if the critical notification permission was granted.
  Future<bool> requestPermissions() async {
    bool notificationsGranted = true;

    // 1. Notification permission (Android 13+)
    try {
      final notifStatus = await Permission.notification.request();
      notificationsGranted = notifStatus.isGranted;
      logDebug('🔔 Notification permission: $notifStatus');
    } catch (e) {
      logDebug('⚠️ Notification permission request failed: $e');
    }

    // 2. Exact alarm permission (Android 12+)
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await androidPlugin?.requestExactAlarmsPermission();
      logDebug('⏰ Exact alarm permission requested');
    } catch (e) {
      logDebug('⚠️ Exact alarm permission request failed: $e');
    }

    // 3. Battery optimization exemption — best-effort (can crash on some devices)
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations
          .request();
      logDebug('🔋 Battery optimization exemption: $batteryStatus');
    } catch (e) {
      logDebug('⚠️ Battery optimization request failed: $e');
    }

    _permissionsRequested = true;
    return notificationsGranted;
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all pending notifications and reschedule from a list of reminders.
  /// Call this on app startup to ensure time-based reminders survive app restarts.
  Future<void> rescheduleReminders(
    List<({String id, String title, String type, String time, bool isEnabled})>
    reminders,
  ) async {
    try {
      await requestPermissions();
    } catch (e) {
      logDebug('⚠️ requestPermissions failed during reschedule: $e');
    }
    for (final r in reminders) {
      final notifId = r.id.hashCode & 0x7fffffff;
      if (!r.isEnabled || (r.type != 'time' && r.type != 'daily_update')) {
        try {
          await _plugin.cancel(notifId);
        } catch (_) {}
        continue;
      }
      try {
        final parts = r.time.split(':');
        final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
        final time = TimeOfDay(hour: hour, minute: minute);
        await scheduleDaily(
          id: notifId,
          title: r.title,
          body: r.type == 'daily_update'
              ? "Please update today's inventory values."
              : 'Inventory reminder',
          time: time,
        );
      } catch (e) {
        logDebug('⚠️ Failed to reschedule reminder ${r.id}: $e');
      }
    }
    logDebug(
      '✅ Rescheduled ${reminders.where((r) => r.isEnabled && (r.type == 'time' || r.type == 'daily_update')).length} reminder notifications',
    );
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    return _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    logDebug(
      '📅 Scheduling notification "$title" at $scheduled '
      '(tz: ${tz.local.name}, now: $now)',
    );

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    // First try exact alarm; if permission is denied, fall back to inexact
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      logDebug('✅ Notification scheduled (exact) with id=$id');
    } catch (e) {
      logDebug('⚠️ Exact alarm failed ($e), trying inexact...');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        logDebug('✅ Notification scheduled (inexact) with id=$id');
      } catch (e2) {
        logDebug('❌ Failed to schedule notification: $e2');
      }
    }
  }

  /// Schedule a one-time notification after [seconds] delay (for testing)
  Future<void> scheduleTest({
    required int id,
    required String title,
    required String body,
    int seconds = 10,
  }) async {
    final scheduled = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    logDebug('🧪 Scheduling test notification at $scheduled (in ${seconds}s)');

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      logDebug('✅ Test notification scheduled with id=$id');
    } catch (e) {
      logDebug('⚠️ Exact test alarm failed ($e), trying inexact...');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      logDebug('✅ Test notification scheduled (inexact) with id=$id');
    }
  }
}
