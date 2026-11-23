import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_store.dart';
import '../models.dart';
import '../services/ocr_service.dart';
import '../services/schedule_service.dart';
import '../theme.dart';

/// MVP item 1 + 2: photo → on-device OCR → editable medicine list →
/// Gemini (or labelled sample) schedule generation.
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

  Future<void> _capture(ImageSource source) async {
    final image = await _ocr.pickImage(source);
    if (image == null) return;
    setState(() => _reading = true);
    try {
      final result = await _ocr.readMedicines(image);
      await widget.store.setMedicinesFromOcr(result.medicines, result.rawText);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.medicines.isEmpty
                ? 'No medicine lines found. Please check the photo or add medicines manually. · மருந்து வரிகள் கிடைக்கவில்லை.'
                : 'Found ${result.medicines.length} medicine(s). Please check each name carefully. · பெயர்களை சரிபார்க்கவும்.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read the photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _editMedicine([MedicineEntry? existing]) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final strengthCtrl =
        TextEditingController(text: existing?.strength ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? 'Add medicine · மருந்து சேர்'
            : 'Edit medicine · திருத்து'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Medicine name (as printed)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: strengthCtrl,
              decoration: const InputDecoration(
                labelText: 'Strength, e.g. 500 mg (if printed)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    if (existing == null) {
      await widget.store.addMedicine(
        MedicineEntry(
          id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
          name: nameCtrl.text.trim(),
          strength: strengthCtrl.text.trim(),
        ),
      );
    } else {
      existing.name = nameCtrl.text.trim();
      existing.strength = strengthCtrl.text.trim();
      await widget.store.updateMedicine(existing);
    }
  }

  Future<void> _generate({bool forceSample = false}) async {
    if (widget.store.medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Add at least one medicine first. · முதலில் மருந்து சேர்க்கவும்.'),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final service =
          forceSample ? SampleScheduleService() : widget.scheduleService;
      final schedule = await service.generate(
        widget.store.medicines,
        widget.store.rawOcrText,
      );
      await widget.store.setSchedule(schedule);
      if (!mounted) return;
      widget.onScheduleReady();
    } on ScheduleGenerationException catch (e) {
      if (!mounted) return;
      final useSample = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could not generate · முடியவில்லை'),
          content: Text(
            '${e.message}\n\nYou can view a clearly-labelled SAMPLE '
            'schedule instead, to see how the app works.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Show sample'),
            ),
          ],
        ),
      );
      if (useSample == true) await _generate(forceSample: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final medicines = widget.store.medicines;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Photo your medicine strip or prescription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'மருந்து ஸ்ட்ரிப் அல்லது மருத்துவ சீட்டை புகைப்படம் எடுக்கவும். '
              'Reading happens on your phone itself — private and offline.',
              style: TextStyle(color: PillTheme.inkSoft),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _reading ? null : () => _capture(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _reading ? null : () => _capture(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            if (_reading) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 12),
                  Text('Reading… · படிக்கிறது…'),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your medicines · உங்கள் மருந்துகள்',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _editMedicine(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const Text(
              'Check every name against the strip. OCR can misread — '
              'tap a row to correct it.',
              style: TextStyle(color: PillTheme.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (medicines.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No medicines yet. Take a photo or tap Add. · '
                    'மருந்துகள் இல்லை.',
                  ),
                ),
              )
            else
              ...medicines.map(
                (m) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.medication,
                        color: PillTheme.primary),
                    title: Text(
                      m.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        m.strength.isEmpty ? null : Text(m.strength),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: PillTheme.danger),
                      onPressed: () => widget.store.removeMedicine(m.id),
                    ),
                    onTap: () => _editMedicine(m),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _generating ? null : () => _generate(),
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                widget.firebaseReady
                    ? 'Make my schedule · அட்டவணை உருவாக்கு'
                    : 'Make SAMPLE schedule (demo) · மாதிரி அட்டவணை',
              ),
            ),
            if (!widget.firebaseReady)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Firebase is not connected yet, so the schedule will be '
                  'a clearly-labelled sample — never real medical output.',
                  style: TextStyle(color: PillTheme.inkSoft, fontSize: 14),
                ),
              ),
          ],
        );
      },
    );
  }
}
