import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n.dart';
import '../models.dart';

/// Dose reminders via flutter_local_notifications.
///
/// Each schedule item gets a daily-repeating local notification at
/// its dose time, with **Taken** / **Skip** / **Snooze** action
/// buttons. Actions are reported back through [onAction] with the
/// schedule item id so the store can record the status — the same
/// status the caregiver view reads. A snooze additionally schedules
/// a one-off reminder 15 minutes later via [scheduleSnooze].
///
/// All notification text follows the app's ONE display language
/// ([language], kept in step with the store by main.dart).
class NotificationService {
  NotificationService({required this.onAction});

  /// Called with (scheduleItemId, 'taken' | 'skipped' | 'snoozed')
  /// when the user taps an action on a reminder notification.
  final void Function(String itemId, String action) onAction;

  /// The language notification titles, bodies and action buttons
  /// are written in. Updated by main.dart whenever the user
  /// switches the app language; already-scheduled reminders pick
  /// the new language up at the next re-schedule.
  AppLanguage language = AppLanguage.ta;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Pending one-off snooze reminders, item id → fire time. Kept so
  /// [scheduleAll] can restore them after its cancel-all cycle.
  final Map<String, tz.TZDateTime> _snoozes = {};

  static const takenActionId = 'pp_taken';
  static const skipActionId = 'pp_skip';
  static const snoozeActionId = 'pp_snooze';
  static const _channelId = 'pillpaatha_doses';

  String get _channelName =>
      language.pick('Dose reminders', 'மருந்து நினைவூட்டல்');

  /// How long a snoozed dose waits before reminding again.
  static const snoozeDelay = Duration(minutes: 15);

  /// Daily reminders use the low id range; snooze one-offs set the
  /// high bit so the two never collide for the same item.
  static int _dailyId(ScheduleItem item) => item.id.hashCode & 0x3fffffff;
  static int _snoozeId(ScheduleItem item) =>
      0x40000000 | (item.id.hashCode & 0x3fffffff);

  List<AndroidNotificationAction> get _actions => [
        AndroidNotificationAction(
          takenActionId,
          language.pick('Taken ✓', 'எடுத்தாச்சு ✓'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          skipActionId,
          language.pick('Skip', 'தவிர்'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          snoozeActionId,
          language.pick('Snooze', 'சற்று பிறகு'),
          showsUserInterface: true,
        ),
      ];

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: language.pick(
            'Daily medicine dose reminders',
            'தினசரி மருந்து நினைவூட்டல்',
          ),
          importance: Importance.high,
          priority: Priority.high,
          actions: _actions,
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'pillpaatha_dose',
        ),
      );

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
    } else if (response.actionId == snoozeActionId) {
      onAction(itemId, 'snoozed');
    }
  }

  /// (Re)schedules a daily reminder for every item. Stable ids are
  /// derived from the item id so re-saving replaces, never duplicates.
  /// Any still-pending snooze one-offs are restored afterwards —
  /// the cancel-all below would otherwise wipe them.
  Future<void> scheduleAll(List<ScheduleItem> items) async {
    if (!_ready) return;
    // NOTE: _plugin.cancelAll directly, not this.cancelAll() — the
    // latter also forgets pending snoozes, which we restore below.
    await _plugin.cancelAll();
    for (final item in items) {
      await _plugin.zonedSchedule(
        _dailyId(item),
        language.pick(
          'Time for ${item.medicineName}',
          '${item.medicineName} சாப்பிடும் நேரம்',
        ),
        '${item.doseFor(language)} · ${item.foodRelation.labelFor(language)}',
        _nextInstance(item),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // daily repeat
        payload: item.id,
      );
    }
    // Restore snooze one-offs that are still in the future.
    final now = tz.TZDateTime.now(tz.local);
    _snoozes.removeWhere((_, when) => !when.isAfter(now));
    for (final item in items) {
      final when = _snoozes[item.id];
      if (when != null) await _postSnooze(item, when);
    }
  }

  /// Schedules the one-off follow-up reminder for a snoozed dose,
  /// [snoozeDelay] from now.
  Future<void> scheduleSnooze(ScheduleItem item) async {
    if (!_ready) return;
    final when = tz.TZDateTime.now(tz.local).add(snoozeDelay);
    _snoozes[item.id] = when;
    await _postSnooze(item, when);
  }

  Future<void> _postSnooze(ScheduleItem item, tz.TZDateTime when) async {
    await _plugin.zonedSchedule(
      _snoozeId(item),
      language.pick(
        'Reminder: ${item.medicineName}',
        'நினைவூட்டல்: ${item.medicineName}',
      ),
      '${item.doseFor(language)} · ${item.foodRelation.labelFor(language)} '
      '${language.pick('(snoozed)', '(ஒத்திவைக்கப்பட்டது)')}',
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: item.id,
    );
  }

  Future<void> cancelAll() async {
    _snoozes.clear();
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
