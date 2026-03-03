import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
      debugPrint('🕐 Timezone set to: $timeZoneName');
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
        debugPrint('🕐 Timezone fallback to: $fallbackTz');
      } catch (_) {
        debugPrint('⚠️ Could not set timezone, using UTC');
      }
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  Future<void> requestPermissions() async {
    if (_permissionsRequested) return;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _permissionsRequested = true;
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

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

    debugPrint(
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
      debugPrint('✅ Notification scheduled (exact) with id=$id');
    } catch (e) {
      debugPrint('⚠️ Exact alarm failed ($e), trying inexact...');
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
        debugPrint('✅ Notification scheduled (inexact) with id=$id');
      } catch (e2) {
        debugPrint('❌ Failed to schedule notification: $e2');
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

    debugPrint(
      '🧪 Scheduling test notification at $scheduled (in ${seconds}s)',
    );

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
      debugPrint('✅ Test notification scheduled with id=$id');
    } catch (e) {
      debugPrint('⚠️ Exact test alarm failed ($e), trying inexact...');
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
      debugPrint('✅ Test notification scheduled (inexact) with id=$id');
    }
  }
}
