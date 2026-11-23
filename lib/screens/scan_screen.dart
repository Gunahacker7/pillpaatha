import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_store.dart';
import '../services/ocr_service.dart';
import '../services/schedule_service.dart';
import '../theme.dart';
import '../widgets/medicine_edit_dialog.dart';
import '../widgets/v2.dart';

/// MVP item 1 + 2, V2 styling: photo → on-device OCR → editable
/// medicine list → Gemini (or labelled sample) schedule generation.
///
/// Everything renders in the app's ONE selected language.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.store,
    required this.scheduleService,
    required this.firebaseReady,
    required this.onScheduleReady,
  });

  final AppStore store;
  final ScheduleService scheduleService;
  final bool firebaseReady;
  final VoidCallback onScheduleReady;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final OcrService _ocr = OcrService();
  bool _reading = false;
  bool _generating = false;

  AppStore get store => widget.store;
  String tr(String en, String ta) => store.tr(en, ta);

  Future<void> _capture(ImageSource source) async {
    final image = await _ocr.pickImage(source);
    if (image == null) return;
    setState(() => _reading = true);
    try {
      final result = await _ocr.readMedicines(image);
      await store.setMedicinesFromOcr(result.medicines, result.rawText);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.medicines.isEmpty
                ? tr(
                    'No medicine lines found. Please check the photo '
                    'or add medicines manually.',
                    'மருந்து வரிகள் கிடைக்கவில்லை. புகைப்படத்தை '
                    'சரிபார்க்கவும் அல்லது கைமுறையாக சேர்க்கவும்.',
                  )
                : tr(
                    'Found ${result.medicines.length} medicine(s). '
                    'Please check each name carefully.',
                    '${result.medicines.length} மருந்து(கள்) '
                    'கிடைத்தது. ஒவ்வொரு பெயரையும் கவனமாக '
                    'சரிபார்க்கவும்.',
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
            'Could not read the photo: $e',
            'புகைப்படத்தை படிக்க முடியவில்லை: $e',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _generate({bool forceSample = false}) async {
    if (store.medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
            'Add at least one medicine first.',
            'முதலில் ஒரு மருந்தாவது சேர்க்கவும்.',
          )),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final service =
          forceSample ? SampleScheduleService() : widget.scheduleService;
      final schedule = await service.generate(
        store.medicines,
        store.rawOcrText,
      );
      await store.setSchedule(schedule);
      if (!mounted) return;
      widget.onScheduleReady();
    } on ScheduleGenerationException catch (e) {
      if (!mounted) return;
      await _offerSampleFallback(e.message);
    } catch (_) {
      // Any other failure (network, App Check token, parsing…) gets
      // the same way out as a ScheduleGenerationException — never a
      // dead end. The sample is only used when the user picks it in
      // the dialog, and it stays labelled via isSample.
      if (!mounted) return;
      // Never dump a raw exception at the user — a plain-language
      // line only. (The service already converts model/busy errors
      // into friendly ScheduleGenerationExceptions; this catch is
      // for anything unexpected, e.g. a parse failure.)
      await _offerSampleFallback(tr(
        'Something went wrong while generating. Please try again.',
        'உருவாக்கும் போது சிக்கல் ஏற்பட்டது. மீண்டும் முயற்சிக்கவும்.',
      ));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Explains why generation failed and offers the clearly-labelled
  /// SAMPLE schedule as the user's choice — never substituted
  /// silently behind their back.
  Future<void> _offerSampleFallback(String message) async {
    final useSample = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Could not generate', 'உருவாக்க முடியவில்லை')),
        content: Text(
          '$message\n\n${tr(
            'You can view a clearly-labelled SAMPLE schedule '
            'instead, to see how the app works.',
            'செயலி எப்படி வேலை செய்கிறது என்று பார்க்க, '
            'தெளிவாக குறிக்கப்பட்ட மாதிரி அட்டவணையைப் '
            'பார்க்கலாம்.',
          )}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel', 'ரத்து')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Use sample schedule', 'மாதிரி அட்டவணை')),
          ),
        ],
      ),
    );
    if (useSample == true) await _generate(forceSample: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final medicines = store.medicines;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // --- Teal header band -------------------------------
            Container(
              decoration: const BoxDecoration(
                gradient: PillTheme.headerGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      'Photo your medicine strip or prescription',
                      'மருந்து ஸ்ட்ரிப் அல்லது மருத்துவ சீட்டை '
                      'புகைப்படம் எடுக்கவும்',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Reading happens on your phone itself — '
                      'private and offline.',
                      'படிப்பது உங்கள் தொலைபேசியிலேயே நடக்கும் — '
                      'தனிப்பட்டது, ஆஃப்லைனில்.',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          onPressed: _reading
                              ? null
                              : () => _capture(ImageSource.camera),
                          icon: Icons.photo_camera,
                          label: tr('Camera', 'கேமரா'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _reading
                              ? null
                              : () => _capture(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: Text(tr('Gallery', 'கேலரி')),
                        ),
                      ),
                    ],
                  ),
                  if (_reading) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 12),
                        Text(tr('Reading…', 'படிக்கிறது…')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    tr('Your medicines', 'உங்கள் மருந்துகள்'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    tr(
                      'Check every name against the strip. OCR can '
                      'misread — tap a row to correct it.',
                      'ஒவ்வொரு பெயரையும் ஸ்ட்ரிப்புடன் '
                      'சரிபார்க்கவும். OCR தவறாக படிக்கலாம் — '
                      'வரியை தொட்டு திருத்தவும்.',
                    ),
                    style: const TextStyle(
                      color: PillTheme.inkSoft,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showMedicineEditDialog(context, store),
                      icon: const Icon(Icons.add),
                      label: Text(tr(
                        'Add medicine manually',
                        'கைமுறையாக சேர்',
                      )),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (medicines.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          tr(
                            'No medicines yet. Take a photo or tap Add.',
                            'இன்னும் மருந்துகள் இல்லை. புகைப்படம் '
                            'எடுக்கவும் அல்லது சேர் என்பதை தொடவும்.',
                          ),
                        ),
                      ),
                    )
                  else
                    ...medicines.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: const BoxDecoration(
                                color: PillTheme.takenTint,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.medication,
                                  color: PillTheme.primary, size: 22),
                            ),
                            title: Text(
                              m.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle:
                                m.strength.isEmpty ? null : Text(m.strength),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: PillTheme.danger),
                              onPressed: () => store.removeMedicine(m.id),
                            ),
                            onTap: () =>
                                showMedicineEditDialog(context, store, m),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_generating)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 12),
                        Text(tr(
                          'Making your schedule…',
                          'அட்டவணை உருவாக்குகிறது…',
                        )),
                      ],
                    )
                  else
                    GradientButton(
                      onPressed: () => _generate(),
                      icon: Icons.auto_awesome,
                      label: widget.firebaseReady
                          ? tr('Make my schedule', 'அட்டவணை உருவாக்கு')
                          : tr(
                              'Make SAMPLE schedule (demo)',
                              'மாதிரி அட்டவணை (டெமோ)',
                            ),
                    ),
                  if (!widget.firebaseReady)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tr(
                          'Firebase is not connected yet, so the '
                          'schedule will be a clearly-labelled sample '
                          '— never real medical output.',
                          'Firebase இன்னும் இணையவில்லை; அட்டவணை '
                          'தெளிவாக குறிக்கப்பட்ட மாதிரியாகவே '
                          'இருக்கும் — உண்மையான மருத்துவ வெளியீடு '
                          'அல்ல.',
                        ),
                        style: const TextStyle(
                          color: PillTheme.inkSoft,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
