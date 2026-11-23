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

/// Recorded state of one dose on one day.
enum DoseStatus { taken, skipped }

extension DoseStatusName on DoseStatus {
  static DoseStatus? fromName(String? name) =>
      DoseStatus.values.where((s) => s.name == name).firstOrNull;
}
