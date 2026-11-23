import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

/// Dose reminders via flutter_local_notifications.
///
/// Each schedule item gets a daily-repeating local notification at
/// its dose time, with **Taken** / **Skip** action buttons. Actions
/// are reported back through [onAction] with the schedule item id so
/// the store can record the status — the same status the caregiver
/// view reads.
class NotificationService {
  NotificationService({required this.onAction});

  /// Called with (scheduleItemId, 'taken' | 'skipped') when the user
  /// taps an action on a reminder notification.
  final void Function(String itemId, String action) onAction;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const takenActionId = 'pp_taken';
  static const skipActionId = 'pp_skip';
  static const _channelId = 'pillpaatha_doses';
  static const _channelName = 'Dose reminders · மருந்து நினைவூட்டல்';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      // Fall back to the device location database default.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _ready = true;
  }

  void _handleResponse(NotificationResponse response) {
    final itemId = response.payload;
    if (itemId == null) return;
    if (response.actionId == takenActionId) {
      onAction(itemId, 'taken');
    } else if (response.actionId == skipActionId) {
      onAction(itemId, 'skipped');
    }
  }

  /// (Re)schedules a daily reminder for every item. Stable ids are
  /// derived from the item id so re-saving replaces, never duplicates.
  Future<void> scheduleAll(List<ScheduleItem> items) async {
    if (!_ready) return;
    await cancelAll();
    for (final item in items) {
      await _plugin.zonedSchedule(
        item.id.hashCode & 0x7fffffff,
        'Time for ${item.medicineName} · மருந்து நேரம்',
        '${item.dose} · ${item.foodRelation.en}',
        _nextInstance(item),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Daily medicine dose reminders',
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                takenActionId,
                'Taken ✓',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                skipActionId,
                'Skip',
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'pillpaatha_dose',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // daily repeat
        payload: item.id,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstance(ScheduleItem item) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      item.hour,
      item.minute,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    return when;
  }
}
