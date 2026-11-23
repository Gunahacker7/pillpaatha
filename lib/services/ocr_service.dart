import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

/// Result of one OCR pass: the candidate medicine rows plus the full
/// raw text (kept so Gemini can see dosage hints like "1-0-1" that the
/// line parser does not try to interpret on-device).
class OcrResult {
  OcrResult({required this.medicines, required this.rawText});
  final List<MedicineEntry> medicines;
  final String rawText;
}

/// On-device OCR — the device half of PillPaatha's hybrid AI.
/// ML Kit runs entirely on the phone: offline, private, instant.
class OcrService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage(ImageSource source) =>
      _picker.pickImage(source: source, imageQuality: 92);

  Future<OcrResult> readMedicines(XFile image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(image.path);
      final recognized = await recognizer.processImage(input);
      return OcrResult(
        medicines: parseMedicineLines(recognized.text),
        rawText: recognized.text,
      );
    } finally {
      await recognizer.close();
    }
  }

  static final _strengthPattern =
      RegExp(r'(\d+(?:\.\d+)?\s?(?:mg|mcg|µg|ml|g|iu)\b)', caseSensitive: false);
  static final _formWords = <String>[
    'tablet',
    'tablets',
    'capsule',
    'capsules',
    'syrup',
    'drops',
    'cream',
    'ointment',
    'inhaler',
    'injection',
    'sachet',
    'strip',
  ];

  /// Heuristic line parser: a line is a candidate medicine when it
  /// carries a strength ("500 mg") or a dosage-form word ("Tablet").
  /// The user always confirms/edits the result — OCR output is never
  /// trusted blindly for medicine names.
  static List<MedicineEntry> parseMedicineLines(String text) {
    final seen = <String>{};
    final out = <MedicineEntry>[];
    var n = 0;
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.length < 3) continue;
      final lower = line.toLowerCase();
      final strengthMatch = _strengthPattern.firstMatch(line);
      final hasForm = _formWords.any(lower.contains);
      if (strengthMatch == null && !hasForm) continue;

      var name = line;
      var strength = '';
      if (strengthMatch != null) {
        strength = strengthMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
        name = (line.substring(0, strengthMatch.start) +
                line.substring(strengthMatch.end))
            .trim();
      }
      // Drop trailing form words / pack noise from the name.
      name = name
          .replaceAll(
            RegExp(
              r'\b(tablets?|capsules?|strip of \d+|x\s?\d+)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      // A line that was ONLY pack/form noise ("Strip of 10 Tablets")
      // leaves no name behind — it is not a medicine row.
      if (name.isEmpty) continue;
      final key = '${name.toLowerCase()}|$strength';
      if (!seen.add(key)) continue;
      n += 1;
      out.add(MedicineEntry(id: 'ocr-$n', name: name, strength: strength));
    }
    return out;
  }
}
