import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models.dart';
import '../theme.dart';

/// Tap-to-edit for one scheduled dose: change its time and/or its
/// dose text. Shared by the Schedule and Medicines screens (it was
/// the Schedule screen's private dialog before V2).
///
/// Safety: the dose text is the user's own prescription wording —
/// the dialog says plainly that the app never changes a dose.
Future<void> showDoseEditDialog(
  BuildContext context,
  AppStore store,
  ScheduleItem item,
) async {
  final lang = store.language;
  String tr(String en, String ta) => lang.pick(en, ta);
  var picked = TimeOfDay(hour: item.hour, minute: item.minute);
  // Edit the dose text in the language it is displayed in: the
  // Tamil slot when one exists, otherwise the verbatim dose.
  final editTamilSlot = lang.isTamil && item.doseTa.isNotEmpty;
  final doseCtrl = TextEditingController(text: item.doseFor(lang));
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(tr(
          'Edit dose — ${item.medicineName}',
          'டோஸ் திருத்து — ${item.medicineName}',
        )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: PillTheme.primary),
              title: Text(tr('Time', 'நேரம்')),
              subtitle: Text(
                picked.format(ctx),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: ctx,
                  initialTime: picked,
                );
                if (t != null) setDialogState(() => picked = t);
              },
            ),
            TextField(
              controller: doseCtrl,
              decoration: InputDecoration(
                labelText: tr(
                  'Dose, as prescribed',
                  'மருத்துவர் குறித்த டோஸ்',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'Keep the dose exactly as your doctor prescribed — '
                'this app never changes a dose for you.',
                'டோஸை மருத்துவர் குறித்தபடியே வைக்கவும் — இந்த '
                'செயலி டோஸை மாற்றாது.',
              ),
              style: const TextStyle(color: PillTheme.inkSoft, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: ctx,
                builder: (c2) => AlertDialog(
                  title: Text(tr('Delete this dose?', 'இந்த டோஸை நீக்கவா?')),
                  content: Text(tr(
                    'This removes only this one dose from the '
                    'schedule. The medicine stays in your list.',
                    'அட்டவணையில் இருந்து இந்த ஒரு டோஸ் மட்டும் '
                    'நீங்கும். மருந்து பட்டியலில் இருக்கும்.',
                  )),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c2, false),
                      child: Text(tr('Cancel', 'ரத்து')),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: PillTheme.danger,
                      ),
                      onPressed: () => Navigator.pop(c2, true),
                      child: Text(tr('Delete', 'நீக்கு')),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await store.removeScheduleItem(item.id);
                if (ctx.mounted) Navigator.pop(ctx, false);
              }
            },
            child: Text(
              tr('Delete dose', 'டோஸை நீக்கு'),
              style: const TextStyle(color: PillTheme.danger),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel', 'ரத்து')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Save', 'சேமி')),
          ),
        ],
      ),
    ),
  );
  if (saved != true) return;
  final doseText = doseCtrl.text.trim();
  final updated = item.copyWith(
    hour: picked.hour,
    minute: picked.minute,
    dose: (!editTamilSlot && doseText.isNotEmpty) ? doseText : null,
    doseTa: (editTamilSlot && doseText.isNotEmpty) ? doseText : null,
  );
  await store.updateScheduleItem(updated);
}
