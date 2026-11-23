/// Core data models for PillPaatha.
///
/// Safety note: PillPaatha never invents medical information. A
/// [ScheduleItem]'s dose and timing come either from the user's own
/// prescription text (via Gemini structuring) or from the clearly
/// labelled sample generator used until Firebase is configured.
library;

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

  static FoodRelation fromName(String? name) => FoodRelation.values
      .firstWhere((f) => f.name == name, orElse: () => FoodRelation.anyTime);
}

/// One scheduled dose of one medicine.
class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.medicineName,
    required this.dose,
    required this.hour,
    required this.minute,
    required this.foodRelation,
    required this.explanationEn,
    required this.explanationTa,
    this.caution = false,
    this.cautionNote = '',
  });

  final String id;
  final String medicineName;

  /// Dose exactly as the prescription states it, e.g. "1 tablet".
  /// Never generated beyond the prescription text; when unknown the
  /// value is "As directed by your doctor".
  final String dose;

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
  final String cautionNote;

  ScheduleItem copyWith({
    String? medicineName,
    String? dose,
    int? hour,
    int? minute,
    FoodRelation? foodRelation,
    String? explanationEn,
    String? explanationTa,
    bool? caution,
    String? cautionNote,
  }) =>
      ScheduleItem(
        id: id,
        medicineName: medicineName ?? this.medicineName,
        dose: dose ?? this.dose,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        foodRelation: foodRelation ?? this.foodRelation,
        explanationEn: explanationEn ?? this.explanationEn,
        explanationTa: explanationTa ?? this.explanationTa,
        caution: caution ?? this.caution,
        cautionNote: cautionNote ?? this.cautionNote,
      );

  String get timeLabel {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// Day-part label derived from the clock time.
  String get dayPart {
    if (hour < 11) return 'Morning · காலை';
    if (hour < 16) return 'Afternoon · மதியம்';
    if (hour < 20) return 'Evening · மாலை';
    return 'Night · இரவு';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineName': medicineName,
        'dose': dose,
        'hour': hour,
        'minute': minute,
        'foodRelation': foodRelation.name,
        'explanationEn': explanationEn,
        'explanationTa': explanationTa,
        'caution': caution,
        'cautionNote': cautionNote,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: json['id'] as String,
        medicineName: json['medicineName'] as String,
        dose: json['dose'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        foodRelation: FoodRelation.fromName(json['foodRelation'] as String?),
        explanationEn: json['explanationEn'] as String,
        explanationTa: json['explanationTa'] as String,
        caution: (json['caution'] as bool?) ?? false,
        cautionNote: (json['cautionNote'] as String?) ?? '',
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
  pending('Pending', 'காத்திருப்பு', 'Pending · காத்திருப்பு'),
  taken('Taken', 'சாப்பிட்டது', 'Taken · சாப்பிட்டாச்சு'),
  skipped('Skipped', 'தவிர்த்தது', 'Skipped · தவிர்த்தது'),
  snoozed('Snoozed', 'ஒத்திவைத்தது', 'Snoozed · ஒத்திவைத்தது'),
  missed('Missed', 'தவறியது', 'Missed · தவறிவிட்டது');

  const EffectiveDoseStatus(this.en, this.ta, this.label);
  final String en;
  final String ta;

  /// Combined bilingual label, e.g. "Taken · சாப்பிட்டாச்சு".
  final String label;

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
const String kMissedDoseAdvice =
    'Missed — do NOT take an extra or double dose. Ask your doctor or '
    'pharmacist. · தவறவிட்ட மருந்துக்கு இரட்டை டோஸ் எடுக்காதீர்கள்; '
    'மருத்துவரிடம் கேளுங்கள்.';

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
