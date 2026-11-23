/// Core data models for PillPaatha.
///
/// Safety note: PillPaatha never invents medical information. A
/// [ScheduleItem]'s dose and timing come either from the user's own
/// prescription text (via Gemini structuring) or from the clearly
/// labelled sample generator used until Firebase is configured.
///
/// Language note: content is STORED in both English and Tamil, and
/// the UI displays exactly one language at a time (see l10n.dart).
library;

import 'l10n.dart';

/// One medicine row, as read by OCR and then confirmed/edited by the
/// user before any schedule is generated.
class MedicineEntry {
  MedicineEntry({required this.id, required this.name, this.strength = ''});

  final String id;
  String name;

  /// Strength exactly as printed, e.g. "500 mg". Empty when the strip /
  /// prescription did not state one that OCR could read.
  String strength;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'strength': strength,
      };

  factory MedicineEntry.fromJson(Map<String, dynamic> json) => MedicineEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        strength: (json['strength'] as String?) ?? '',
      );
}

/// Food relation for a dose, worded exactly as prescriptions phrase it.
enum FoodRelation {
  beforeFood('Before food', 'சாப்பாட்டுக்கு முன்'),
  afterFood('After food', 'சாப்பாட்டுக்கு பின்'),
  withFood('With food', 'சாப்பாட்டுடன்'),
  anyTime('Any time', 'எந்த நேரமும்');

  const FoodRelation(this.en, this.ta);
  final String en;
  final String ta;

  String labelFor(AppLanguage lang) => lang.pick(en, ta);

  static FoodRelation fromName(String? name) => FoodRelation.values
      .firstWhere((f) => f.name == name, orElse: () => FoodRelation.anyTime);
}

/// One scheduled dose of one medicine.
class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.medicineName,
    required this.dose,
    this.doseTa = '',
    required this.hour,
    required this.minute,
    required this.foodRelation,
    required this.explanationEn,
    required this.explanationTa,
    this.caution = false,
    this.cautionNoteEn = '',
    this.cautionNoteTa = '',
  });

  final String id;
  final String medicineName;

  /// Dose exactly as the prescription states it, e.g. "1 tablet".
  /// Never generated beyond the prescription text; when unknown the
  /// value is "As directed by your doctor".
  final String dose;

  /// Tamil rendering of [dose] when one exists (the sample generator
  /// provides one). Empty for real schedules — a prescription's dose
  /// text is data, shown verbatim in either language.
  final String doseTa;

  final int hour; // 0-23
  final int minute; // 0-59
  final FoodRelation foodRelation;

  /// Plain-language explanation of what the medicine is for,
  ///  in English and in Tamil.
  final String explanationEn;
  final String explanationTa;

  /// True when this medicine's name looks/sounds like another medicine
  /// on the same list — the user must double-check before taking.
  final bool caution;
  final String cautionNoteEn;
  final String cautionNoteTa;

  String doseFor(AppLanguage lang) =>
      (lang.isTamil && doseTa.isNotEmpty) ? doseTa : dose;

  String explanationFor(AppLanguage lang) =>
      lang.pick(explanationEn, explanationTa);

  String cautionNoteFor(AppLanguage lang) {
    final picked = lang.pick(cautionNoteEn, cautionNoteTa);
    if (picked.isNotEmpty) return picked;
    // One side empty (e.g. a pre-0.3.0 schedule): show the other
    // rather than nothing — a safety note must never vanish.
    return lang.isTamil ? cautionNoteEn : cautionNoteTa;
  }

  ScheduleItem copyWith({
    String? medicineName,
    String? dose,
    String? doseTa,
    int? hour,
    int? minute,
    FoodRelation? foodRelation,
    String? explanationEn,
    String? explanationTa,
    bool? caution,
    String? cautionNoteEn,
    String? cautionNoteTa,
  }) =>
      ScheduleItem(
        id: id,
        medicineName: medicineName ?? this.medicineName,
        dose: dose ?? this.dose,
        doseTa: doseTa ?? this.doseTa,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        foodRelation: foodRelation ?? this.foodRelation,
        explanationEn: explanationEn ?? this.explanationEn,
        explanationTa: explanationTa ?? this.explanationTa,
        caution: caution ?? this.caution,
        cautionNoteEn: cautionNoteEn ?? this.cautionNoteEn,
        cautionNoteTa: cautionNoteTa ?? this.cautionNoteTa,
      );

  String get timeLabel {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// Day-part label derived from the clock time, in one language.
  String dayPartFor(AppLanguage lang) {
    if (hour < 11) return lang.pick('Morning', 'காலை');
    if (hour < 16) return lang.pick('Afternoon', 'மதியம்');
    if (hour < 20) return lang.pick('Evening', 'மாலை');
    return lang.pick('Night', 'இரவு');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineName': medicineName,
        'dose': dose,
        'doseTa': doseTa,
        'hour': hour,
        'minute': minute,
        'foodRelation': foodRelation.name,
        'explanationEn': explanationEn,
        'explanationTa': explanationTa,
        'caution': caution,
        'cautionNoteEn': cautionNoteEn,
        'cautionNoteTa': cautionNoteTa,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: json['id'] as String,
        medicineName: json['medicineName'] as String,
        dose: json['dose'] as String,
        doseTa: (json['doseTa'] as String?) ?? '',
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        foodRelation: FoodRelation.fromName(json['foodRelation'] as String?),
        explanationEn: json['explanationEn'] as String,
        explanationTa: json['explanationTa'] as String,
        caution: (json['caution'] as bool?) ?? false,
        // Pre-0.3.0 schedules stored one bilingual 'cautionNote';
        // it lands in the English slot and Tamil falls back to it
        // via the empty-check in cautionNoteFor callers' data —
        // acceptable for a schedule that predates the split.
        cautionNoteEn: (json['cautionNoteEn'] as String?) ??
            (json['cautionNote'] as String?) ??
            '',
        cautionNoteTa: (json['cautionNoteTa'] as String?) ?? '',
      );
}

/// A generated schedule plus its provenance. [isSample] is true when
/// the schedule came from the built-in offline sample generator
/// (Firebase/Gemini not configured yet) — the UI must label it as a
/// sample wherever it is shown. Sample data is NEVER presented as
/// real Gemini output.
class GeneratedSchedule {
  GeneratedSchedule({
    required this.items,
    required this.isSample,
    required this.generatedAt,
  });

  final List<ScheduleItem> items;
  final bool isSample;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'isSample': isSample,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory GeneratedSchedule.fromJson(Map<String, dynamic> json) =>
      GeneratedSchedule(
        items: (json['items'] as List<dynamic>)
            .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        isSample: json['isSample'] as bool,
        generatedAt: DateTime.parse(json['generatedAt'] as String),
      );
}

/// Recorded state of one dose on one day — only what the user (or a
/// reminder action) actually recorded. "Pending" and "Missed" are
/// never stored; they are derived by [effectiveStatus].
enum DoseStatus { taken, skipped, snoozed }

extension DoseStatusName on DoseStatus {
  static DoseStatus? fromName(String? name) =>
      DoseStatus.values.where((s) => s.name == name).firstOrNull;

  /// The stored status viewed as an [EffectiveDoseStatus].
  EffectiveDoseStatus get effective => switch (this) {
        DoseStatus.taken => EffectiveDoseStatus.taken,
        DoseStatus.skipped => EffectiveDoseStatus.skipped,
        DoseStatus.snoozed => EffectiveDoseStatus.snoozed,
      };
}

/// The status of a dose as the user should see it right now: the
/// recorded status when there is one, otherwise derived from the
/// clock — a dose whose time has passed with nothing recorded is
/// **missed**; one still to come is **pending**.
enum EffectiveDoseStatus {
  pending('Pending', 'காத்திருப்பு'),
  taken('Taken', 'சாப்பிட்டது'),
  skipped('Skipped', 'தவிர்த்தது'),
  snoozed('Snoozed', 'ஒத்திவைத்தது'),
  missed('Missed', 'தவறிவிட்டது');

  const EffectiveDoseStatus(this.en, this.ta);
  final String en;
  final String ta;

  String labelFor(AppLanguage lang) => lang.pick(en, ta);

  static EffectiveDoseStatus fromName(String? name) =>
      EffectiveDoseStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => EffectiveDoseStatus.pending,
      );
}

/// Derives the effective status of [item] for today: a recorded
/// [storedStatus] always wins; otherwise the dose is missed when its
/// time today is already past, pending when it is still ahead.
EffectiveDoseStatus effectiveStatus(
  ScheduleItem item,
  DoseStatus? storedStatus,
  DateTime now,
) {
  if (storedStatus != null) return storedStatus.effective;
  final doseTime =
      DateTime(now.year, now.month, now.day, item.hour, item.minute);
  return now.isAfter(doseTime)
      ? EffectiveDoseStatus.missed
      : EffectiveDoseStatus.pending;
}

/// Safety copy shown wherever a missed dose appears. PillPaatha
/// NEVER advises making up a missed dose with an extra/double dose.
const String kMissedDoseAdviceEn =
    'Missed — do NOT take an extra or double dose. Ask your doctor or '
    'pharmacist.';
const String kMissedDoseAdviceTa =
    'தவறவிட்ட மருந்துக்கு இரட்டை டோஸ் எடுக்காதீர்கள்; மருத்துவரிடம் '
    'அல்லது மருந்தாளரிடம் கேளுங்கள்.';

String missedDoseAdviceFor(AppLanguage lang) =>
    lang.pick(kMissedDoseAdviceEn, kMissedDoseAdviceTa);

/// One entry in the dose log: a status action the user took, kept so
/// the caregiver view can show recent activity and adherence.
class DoseLogEntry {
  DoseLogEntry({
    required this.itemId,
    required this.medicineName,
    required this.scheduledIso,
    required this.status,
    required this.actedIso,
  });

  final String itemId;
  final String medicineName;

  /// When the dose was scheduled (ISO-8601, local time).
  final String scheduledIso;

  /// The status the user recorded (taken / skipped / snoozed).
  final EffectiveDoseStatus status;

  /// When the user recorded it (ISO-8601, local time).
  final String actedIso;

  DateTime get scheduledAt =>
      DateTime.tryParse(scheduledIso) ?? DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'medicineName': medicineName,
        'scheduledIso': scheduledIso,
        'status': status.name,
        'actedIso': actedIso,
      };

  factory DoseLogEntry.fromJson(Map<String, dynamic> json) => DoseLogEntry(
        itemId: json['itemId'] as String,
        medicineName: json['medicineName'] as String,
        scheduledIso: json['scheduledIso'] as String,
        status: EffectiveDoseStatus.fromName(json['status'] as String?),
        actedIso: json['actedIso'] as String,
      );
}

/// Adherence over a dose log: taken / (taken + skipped + missed),
/// as a percentage. Snoozed and pending entries do not count either
/// way. Returns null when there is nothing measurable yet (the UI
/// shows "—").
double? adherencePercent(List<DoseLogEntry> log) {
  var taken = 0, skipped = 0, missed = 0;
  for (final e in log) {
    switch (e.status) {
      case EffectiveDoseStatus.taken:
        taken++;
      case EffectiveDoseStatus.skipped:
        skipped++;
      case EffectiveDoseStatus.missed:
        missed++;
      case EffectiveDoseStatus.pending:
      case EffectiveDoseStatus.snoozed:
        break;
    }
  }
  final denominator = taken + skipped + missed;
  if (denominator == 0) return null;
  return taken * 100 / denominator;
}

/// The family/emergency contact the patient can call in one tap.
class EmergencyContact {
  EmergencyContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: (json['name'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
      );
}
