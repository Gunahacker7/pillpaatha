import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models.dart';

/// Turns a confirmed medicine list into a daily schedule.
///
/// Two implementations:
///  * [GeminiScheduleService] — the cloud half of the hybrid AI:
///    Gemini via Firebase AI Logic structures the list.
///  * [SampleScheduleService] — offline/demo fallback used until
///    Firebase is configured. Its output is flagged
///    [GeneratedSchedule.isSample] and the UI labels it as a sample
///    everywhere. It is NEVER presented as real Gemini output.
abstract class ScheduleService {
  Future<GeneratedSchedule> generate(
    List<MedicineEntry> medicines,
    String rawOcrText,
  );
}

class ScheduleGenerationException implements Exception {
  ScheduleGenerationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Deterministic local look-alike check, applied to every generated
/// schedule (Gemini or sample) as a backstop: two medicines whose
/// names share a long prefix (e.g. "Metformin" / "Metoprolol") get a
/// caution flag so the user double-checks the strip before taking.
List<ScheduleItem> applyLookAlikeFlags(List<ScheduleItem> items) {
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  bool lookAlike(String a, String b) {
    if (a == b) return false;
    var prefix = 0;
    while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
      prefix++;
    }
    // Long shared prefix (Metformin/Metronidazole), or a shorter
    // prefix on near-identical lengths (Metformin/Metoprolol share
    // only "met" but are the classic confused pair), or containment.
    return prefix >= 4 ||
        (prefix >= 3 && (a.length - b.length).abs() <= 2) ||
        a.contains(b) ||
        b.contains(a);
  }

  return [
    for (final item in items)
      () {
        final twin = items
            .where((o) =>
                o.id != item.id &&
                lookAlike(norm(item.medicineName), norm(o.medicineName)))
            .firstOrNull;
        if (twin == null || item.caution) return item;
        return ScheduleItem(
          id: item.id,
          medicineName: item.medicineName,
          dose: item.dose,
          hour: item.hour,
          minute: item.minute,
          foodRelation: item.foodRelation,
          explanationEn: item.explanationEn,
          explanationTa: item.explanationTa,
          caution: true,
          cautionNote:
              'This name looks similar to "${twin.medicineName}". '
              'Please double-check the strip before taking. · '
              'இந்த பெயர் "${twin.medicineName}" போலவே உள்ளது. '
              'சாப்பிடும் முன் ஸ்ட்ரிப்பை சரிபார்க்கவும்.',
        );
      }(),
  ];
}

/// Gemini via Firebase AI Logic (Firebase's `firebase_ai` package).
class GeminiScheduleService implements ScheduleService {
  static const _modelName = 'gemini-2.5-flash';

  static final _schema = Schema.object(
    properties: {
      'items': Schema.array(
        items: Schema.object(
          properties: {
            'medicineName': Schema.string(),
            'dose': Schema.string(
              description:
                  'Dose exactly as written in the prescription text, '
                  'e.g. "1 tablet". If the text does not state a dose, '
                  'use "As directed by your doctor". Never invent a dose.',
            ),
            'hour': Schema.integer(description: '0-23'),
            'minute': Schema.integer(description: '0-59'),
            'foodRelation': Schema.enumString(
              enumValues: ['beforeFood', 'afterFood', 'withFood', 'anyTime'],
            ),
            'explanationEn': Schema.string(
              description:
                  'One or two plain-language sentences on what this '
                  'medicine is commonly for. General information only.',
            ),
            'explanationTa': Schema.string(
              description: 'The same explanation in simple Tamil.',
            ),
            'caution': Schema.boolean(
              description:
                  'True if this medicine name looks or sounds like '
                  'another medicine in the same list.',
            ),
            'cautionNote': Schema.string(),
          },
          optionalProperties: ['cautionNote'],
        ),
      ),
    },
  );

  @override
  Future<GeneratedSchedule> generate(
    List<MedicineEntry> medicines,
    String rawOcrText,
  ) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema,
      ),
      systemInstruction: Content.system(
        'You are the scheduling assistant inside PillPaatha, a medicine '
        'reminder app for elderly patients in India. Follow these rules '
        'without exception: (1) Use ONLY the medicine names, strengths, '
        'doses and timings present in the user-provided prescription '
        'text. Never invent a dose, a strength, or a medical fact. '
        '(2) If a dose or timing is not stated, set dose to "As directed '
        'by your doctor" and choose a neutral morning time, and say so '
        'in the explanation. (3) Explanations are general plain-language '
        'information about what a medicine is commonly used for — not '
        'advice for this patient. End every explanation with a reminder '
        'to confirm with their doctor or pharmacist. (4) Flag '
        'look-alike / sound-alike medicine names within the list with '
        'caution=true. (5) Never diagnose anything.',
      ),
    );

    final medList = medicines
        .map((m) => '- ${m.name}${m.strength.isEmpty ? '' : ' (${m.strength})'}')
        .join('\n');
    final prompt = 'Medicines confirmed by the user:\n$medList\n\n'
        'Raw text read from the prescription / strips (may contain '
        'dosage hints such as 1-0-1):\n"""\n$rawOcrText\n"""\n\n'
        'Return the daily schedule as JSON matching the schema. One '
        'item per dose per medicine.';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw ScheduleGenerationException(
        'Gemini returned an empty response. Please try again.',
      );
    }

    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final rawItems = decoded['items'] as List<dynamic>? ?? [];
    var n = 0;
    final items = rawItems.map((e) {
      final j = e as Map<String, dynamic>;
      n += 1;
      return ScheduleItem(
        id: 'dose-$n',
        medicineName: j['medicineName'] as String,
        dose: j['dose'] as String,
        hour: (j['hour'] as num).toInt(),
        minute: (j['minute'] as num).toInt(),
        foodRelation: FoodRelation.fromName(j['foodRelation'] as String?),
        explanationEn: j['explanationEn'] as String,
        explanationTa: j['explanationTa'] as String,
        caution: (j['caution'] as bool?) ?? false,
        cautionNote: (j['cautionNote'] as String?) ?? '',
      );
    }).toList();

    return GeneratedSchedule(
      items: applyLookAlikeFlags(items),
      isSample: false,
      generatedAt: DateTime.now(),
    );
  }
}

/// Built-in offline sample generator. Builds a schedule from the
/// user's own confirmed medicine names (so the end-to-end flow is
/// demonstrable), with placeholder timings/explanations that are
/// labelled as samples in the UI. Used only until Firebase is
/// configured, or when the user explicitly chooses it after a Gemini
/// failure.
class SampleScheduleService implements ScheduleService {
  @override
  Future<GeneratedSchedule> generate(
    List<MedicineEntry> medicines,
    String rawOcrText,
  ) async {
    final source = medicines.isEmpty
        ? [MedicineEntry(id: 'sample-1', name: 'Sample Medicine')]
        : medicines;
    var n = 0;
    final items = source.map((m) {
      n += 1;
      return ScheduleItem(
        id: 'dose-$n',
        medicineName: m.name,
        dose: 'As written on your prescription — sample timing, '
            'please confirm with your doctor',
        hour: 8,
        minute: 0,
        foodRelation: FoodRelation.afterFood,
        explanationEn:
            'Sample explanation. Connect Firebase (see FIREBASE-SETUP.md) '
            'and Gemini will explain in plain words what ${m.name} is for.',
        explanationTa:
            'மாதிரி விளக்கம். Firebase இணைத்தால், ${m.name} எதற்காக '
            'என்பதை Gemini எளிய தமிழில் விளக்கும்.',
      );
    }).toList();

    return GeneratedSchedule(
      items: applyLookAlikeFlags(items),
      isSample: true,
      generatedAt: DateTime.now(),
    );
  }
}

/// Picks the live Gemini service when Firebase initialised, otherwise
/// the clearly-labelled sample service.
ScheduleService createScheduleService({required bool firebaseReady}) =>
    firebaseReady ? GeminiScheduleService() : SampleScheduleService();
