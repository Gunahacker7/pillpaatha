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
}

/// On-device implementation backed by SharedPreferences + JSON.
class LocalScheduleRepository implements ScheduleRepository {
  static const _kMedicines = 'pp_medicines';
  static const _kSchedule = 'pp_schedule';
  static const _kStatuses = 'pp_statuses';
  static const _kRawOcr = 'pp_raw_ocr';

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
}

/// In-memory repository for tests and previews.
class InMemoryScheduleRepository implements ScheduleRepository {
  List<MedicineEntry> _medicines = [];
  GeneratedSchedule? _schedule;
  Map<String, String> _statuses = {};
  String _rawOcr = '';

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
  bool loaded = false;

  Future<void> load() async {
    medicines = await _repo.loadMedicines();
    schedule = await _repo.loadSchedule();
    statuses = await _repo.loadStatuses();
    rawOcrText = await _repo.loadRawOcrText();
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

  // --- Dose status ---------------------------------------------------

  static String statusKey(DateTime date, String itemId) {
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return '$d|$itemId';
  }

  DoseStatus? statusFor(ScheduleItem item, DateTime date) =>
      DoseStatusName.fromName(statuses[statusKey(date, item.id)]);

  Future<void> markStatus(
    ScheduleItem item,
    DoseStatus status, {
    DateTime? date,
  }) async {
    statuses = {
      ...statuses,
      statusKey(date ?? DateTime.now(), item.id): status.name,
    };
    await _repo.saveStatuses(statuses);
    notifyListeners();
  }

  Future<void> clearStatus(ScheduleItem item, {DateTime? date}) async {
    statuses = Map.of(statuses)
      ..remove(statusKey(date ?? DateTime.now(), item.id));
    await _repo.saveStatuses(statuses);
    notifyListeners();
  }

  /// A dose counts as missed when its time has passed today and the
  /// user recorded neither Taken nor Skip.
  bool isMissed(ScheduleItem item, DateTime now) {
    if (statusFor(item, now) != null) return false;
    final doseTime = DateTime(now.year, now.month, now.day, item.hour,
        item.minute);
    return now.isAfter(doseTime);
  }
}
