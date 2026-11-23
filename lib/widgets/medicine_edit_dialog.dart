import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models.dart';
import '../theme.dart';

/// Add / edit one entry in the confirmed medicine list (name +
/// strength, exactly as printed). Shared by the Scan and Medicines
/// screens — this is the existing manual add/edit form, restyled
/// for V2 with labelled, icon-led fields and a green Save button.
Future<void> showMedicineEditDialog(
  BuildContext context,
  AppStore store, [
  MedicineEntry? existing,
]) async {
  String tr(String en, String ta) => store.tr(en, ta);
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final strengthCtrl = TextEditingController(text: existing?.strength ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null
          ? tr('Add medicine', 'மருந்து சேர்')
          : tr('Edit medicine', 'மருந்தை திருத்து')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: tr(
                'Medicine name (as printed)',
                'மருந்தின் பெயர் (அச்சிட்டபடி)',
              ),
              prefixIcon:
                  const Icon(Icons.medication, color: PillTheme.primary),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: strengthCtrl,
            decoration: InputDecoration(
              labelText: tr(
                'Strength, e.g. 500 mg (if printed)',
                'வலிமை, எ.கா. 500 mg (இருந்தால்)',
              ),
              prefixIcon:
                  const Icon(Icons.science_outlined, color: PillTheme.primary),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Cancel', 'ரத்து')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.check, size: 20),
          label: Text(tr('Save', 'சேமி')),
        ),
      ],
    ),
  );
  if (saved != true || nameCtrl.text.trim().isEmpty) return;
  if (existing == null) {
    await store.addMedicine(
      MedicineEntry(
        id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
        name: nameCtrl.text.trim(),
        strength: strengthCtrl.text.trim(),
      ),
    );
  } else {
    existing.name = nameCtrl.text.trim();
    existing.strength = strengthCtrl.text.trim();
    await store.updateMedicine(existing);
  }
}
