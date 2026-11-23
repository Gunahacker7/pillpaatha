import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Persistence boundary for PillPaatha.
///
/// Day 1 ships [LocalScheduleRepository] (on-device only). The
/// caregiver Firestore sync planned for the full entry slots in as a
/// second implementation of this interface — no screen code changes.
abstract class ScheduleRepository {
  Future<List<MedicineEntry>> loadMedicines();
  Future<void> saveMedicines(List<MedicineEntry> medicines);

  Future<GeneratedSchedule?> loadSchedule();
  Future<void> saveSchedule(GeneratedSchedule? schedule);

  /// Dose statuses keyed by `yyyy-mm-dd|scheduleItemId`.
  Future<Map<String, String>> loadStatuses();
  Future<void> saveStatuses(Map<String, String> statuses);

  Future<String> loadRawOcrText();
  Future<void> saveRawOcrText(String text);

  /// The dose log: one entry per status action, oldest first.
  Future<List<DoseLogEntry>> loadDoseLog();
  Future<void> saveDoseLog(List<DoseLogEntry> log);

  Future<EmergencyContact?> loadEmergencyContact();
  Future<void> saveEmergencyContact(EmergencyContact? contact);
}

/// On-device implementation backed by SharedPreferences + JSON.
class LocalScheduleRepository implements ScheduleRepository {
  static const _kMedicines = 'pp_medicines';
  static const _kSchedule = 'pp_schedule';
  static const _kStatuses = 'pp_statuses';
  static const _kRawOcr = 'pp_raw_ocr';
  static const _kDoseLog = 'pp_dose_log';
  static const _kEmergency = 'pp_emergency_contact';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<MedicineEntry>> loadMedicines() async {
    final raw = (await _prefs).getString(_kMedicines);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MedicineEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveMedicines(List<MedicineEntry> medicines) async {
    (await _prefs).setString(
      _kMedicines,
      jsonEncode(medicines.map((m) => m.toJson()).toList()),
    );
  }

  @override
  Future<GeneratedSchedule?> loadSchedule() async {
    final raw = (await _prefs).getString(_kSchedule);
    if (raw == null) return null;
    return GeneratedSchedule.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> saveSchedule(GeneratedSchedule? schedule) async {
    final prefs = await _prefs;
    if (schedule == null) {
      await prefs.remove(_kSchedule);
    } else {
      await prefs.setString(_kSchedule, jsonEncode(schedule.toJson()));
    }
  }

  @override
  Future<Map<String, String>> loadStatuses() async {
    final raw = (await _prefs).getString(_kStatuses);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
  }

  @override
  Future<void> saveStatuses(Map<String, String> statuses) async {
    (await _prefs).setString(_kStatuses, jsonEncode(statuses));
  }

  @override
  Future<String> loadRawOcrText() async =>
      (await _prefs).getString(_kRawOcr) ?? '';

  @override
  Future<void> saveRawOcrText(String text) async {
    (await _prefs).setString(_kRawOcr, text);
  }

  @override
  Future<List<DoseLogEntry>> loadDoseLog() async {
    final raw = (await _prefs).getString(_kDoseLog);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DoseLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveDoseLog(List<DoseLogEntry> log) async {
    (await _prefs).setString(
      _kDoseLog,
      jsonEncode(log.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<EmergencyContact?> loadEmergencyContact() async {
    final raw = (await _prefs).getString(_kEmergency);
    if (raw == null) return null;
    return EmergencyContact.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveEmergencyContact(EmergencyContact? contact) async {
    final prefs = await _prefs;
    if (contact == null) {
      await prefs.remove(_kEmergency);
    } else {
      await prefs.setString(_kEmergency, jsonEncode(contact.toJson()));
    }
  }
}

/// In-memory repository for tests and previews.
class InMemoryScheduleRepository implements ScheduleRepository {
  List<MedicineEntry> _medicines = [];
  GeneratedSchedule? _schedule;
  Map<String, String> _statuses = {};
  String _rawOcr = '';
  List<DoseLogEntry> _doseLog = [];
  EmergencyContact? _emergencyContact;

  @override
  Future<List<MedicineEntry>> loadMedicines() async => List.of(_medicines);

  @override
  Future<void> saveMedicines(List<MedicineEntry> medicines) async {
    _medicines = List.of(medicines);
  }

  @override
  Future<GeneratedSchedule?> loadSchedule() async => _schedule;

  @override
  Future<void> saveSchedule(GeneratedSchedule? schedule) async {
    _schedule = schedule;
  }

  @override
  Future<Map<String, String>> loadStatuses() async => Map.of(_statuses);

  @override
  Future<void> saveStatuses(Map<String, String> statuses) async {
    _statuses = Map.of(statuses);
  }

  @override
  Future<String> loadRawOcrText() async => _rawOcr;

  @override
  Future<void> saveRawOcrText(String text) async {
    _rawOcr = text;
  }

  @override
  Future<List<DoseLogEntry>> loadDoseLog() async => List.of(_doseLog);

  @override
  Future<void> saveDoseLog(List<DoseLogEntry> log) async {
    _doseLog = List.of(log);
  }

  @override
  Future<EmergencyContact?> loadEmergencyContact() async => _emergencyContact;

  @override
  Future<void> saveEmergencyContact(EmergencyContact? contact) async {
    _emergencyContact = contact;
  }
}

/// App-wide state: the editable medicine list, the current schedule,
/// and today's dose statuses.
class AppStore extends ChangeNotifier {
  AppStore(this._repo);

  final ScheduleRepository _repo;

  List<MedicineEntry> medicines = [];
  GeneratedSchedule? schedule;
  Map<String, String> statuses = {};
  String rawOcrText = '';
  List<DoseLogEntry> doseLog = [];
  EmergencyContact? emergencyContact;
  bool loaded = false;

  /// Set by main.dart once notifications are ready: schedules the
  /// one-off reminder (+15 min) for a snoozed dose. Kept as a hook so
  /// the store stays free of notification-plugin code.
  Future<void> Function(ScheduleItem item)? snoozeReminderHook;

  /// Maximum dose-log entries kept (oldest dropped beyond this).
  static const maxDoseLogEntries = 500;

  Future<void> load() async {
    medicines = await _repo.loadMedicines();
    schedule = await _repo.loadSchedule();
    statuses = await _repo.loadStatuses();
    rawOcrText = await _repo.loadRawOcrText();
    doseLog = await _repo.loadDoseLog();
    emergencyContact = await _repo.loadEmergencyContact();
    loaded = true;
    notifyListeners();
  }

  // --- Medicines -----------------------------------------------------

  Future<void> setMedicinesFromOcr(
    List<MedicineEntry> entries,
    String rawText,
  ) async {
    medicines = entries;
    rawOcrText = rawText;
    await _repo.saveMedicines(medicines);
    await _repo.saveRawOcrText(rawText);
    notifyListeners();
  }

  Future<void> addMedicine(MedicineEntry entry) async {
    medicines = [...medicines, entry];
    await _repo.saveMedicines(medicines);
    notifyListeners();
  }

  Future<void> updateMedicine(MedicineEntry entry) async {
    medicines = [
      for (final m in medicines) if (m.id == entry.id) entry else m,
    ];
    await _repo.saveMedicines(medicines);
    notifyListeners();
  }

  Future<void> removeMedicine(String id) async {
    medicines = medicines.where((m) => m.id != id).toList();
    await _repo.saveMedicines(medicines);
    notifyListeners();
  }

  // --- Schedule ------------------------------------------------------

  Future<void> setSchedule(GeneratedSchedule newSchedule) async {
    schedule = newSchedule;
    await _repo.saveSchedule(newSchedule);
    notifyListeners();
  }

  Future<void> clearSchedule() async {
    schedule = null;
    await _repo.saveSchedule(null);
    notifyListeners();
  }

  /// Replaces one schedule item (e.g. after the user edits its time
  /// or dose text). Notifying listeners re-schedules the reminders.
  Future<void> updateScheduleItem(ScheduleItem updated) async {
    final current = schedule;
    if (current == null) return;
    schedule = GeneratedSchedule(
      items: [
        for (final i in current.items) if (i.id == updated.id) updated else i,
      ],
      isSample: current.isSample,
      generatedAt: current.generatedAt,
    );
    await _repo.saveSchedule(schedule);
    notifyListeners();
  }

  // --- Dose status ---------------------------------------------------

  static String statusKey(DateTime date, String itemId) {
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return '$d|$itemId';
  }

  DoseStatus? statusFor(ScheduleItem item, DateTime date) =>
      DoseStatusName.fromName(statuses[statusKey(date, item.id)]);

  /// The status to show for [item] today: recorded status wins,
  /// otherwise missed (time passed) or pending (still ahead).
  EffectiveDoseStatus effectiveStatusFor(ScheduleItem item, DateTime now) =>
      effectiveStatus(item, statusFor(item, now), now);

  Future<void> markStatus(
    ScheduleItem item,
    DoseStatus status, {
    DateTime? date,
  }) async {
    final day = date ?? DateTime.now();
    statuses = {
      ...statuses,
      statusKey(day, item.id): status.name,
    };
    await _repo.saveStatuses(statuses);
    await _appendDoseLog(item, status, day);
    notifyListeners();
  }

  /// Records a snooze and asks the notification layer (via
  /// [snoozeReminderHook]) for a one-off reminder 15 minutes later.
  Future<void> markSnoozed(ScheduleItem item, {DateTime? date}) async {
    await markStatus(item, DoseStatus.snoozed, date: date);
    final hook = snoozeReminderHook;
    if (hook != null) {
      try {
        await hook(item);
      } catch (_) {
        // The snooze itself is recorded; the extra reminder is
        // best-effort, like all reminders in this app.
      }
    }
  }

  Future<void> _appendDoseLog(
    ScheduleItem item,
    DoseStatus status,
    DateTime day,
  ) async {
    final scheduled =
        DateTime(day.year, day.month, day.day, item.hour, item.minute);
    doseLog = [
      ...doseLog,
      DoseLogEntry(
        itemId: item.id,
        medicineName: item.medicineName,
        scheduledIso: scheduled.toIso8601String(),
        status: status.effective,
        actedIso: DateTime.now().toIso8601String(),
      ),
    ];
    if (doseLog.length > maxDoseLogEntries) {
      doseLog = doseLog.sublist(doseLog.length - maxDoseLogEntries);
    }
    await _repo.saveDoseLog(doseLog);
  }

  Future<void> clearStatus(ScheduleItem item, {DateTime? date}) async {
    statuses = Map.of(statuses)
      ..remove(statusKey(date ?? DateTime.now(), item.id));
    await _repo.saveStatuses(statuses);
    notifyListeners();
  }

  /// A dose counts as missed when its time has passed today and the
  /// user recorded neither Taken nor Skip.
  bool isMissed(ScheduleItem item, DateTime now) =>
      effectiveStatusFor(item, now) == EffectiveDoseStatus.missed;

  // --- Emergency contact ----------------------------------------------

  Future<void> setEmergencyContact(EmergencyContact? contact) async {
    emergencyContact = contact;
    await _repo.saveEmergencyContact(contact);
    notifyListeners();
  }
}
