import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/dose_edit_dialog.dart';
import '../widgets/medicine_edit_dialog.dart';
import '../widgets/safety_line.dart';
import '../widgets/v2.dart';

/// V2 Medicines screen (boards): every medicine on the current
/// schedule with its time / dose / food relation — tap a row to
/// edit the dose (the existing dose-edit dialog) — plus the
/// confirmed medicine list from Scan with the existing manual
/// add/edit form, and a prominent Scan button.
///
/// Nothing here invents data: schedule rows come from the
/// generated schedule, list rows from the user's confirmed list.
class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({
    super.key,
    required this.store,
    required this.onScan,
  });

  final AppStore store;

  /// Open the Scan screen (pushed route).
  final VoidCallback onScan;

  AppLanguage get lang => store.language;
  String tr(String en, String ta) => lang.pick(en, ta);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final schedule = store.schedule;
        final items = schedule == null
            ? <ScheduleItem>[]
            : ([...schedule.items]..sort((a, b) =>
                (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute)));
        final now = DateTime.now();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('My Medicines', 'என் மருந்துகள்'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Tap a scheduled medicine to change its time or dose.',
                'நேரம் அல்லது டோஸை மாற்ற மருந்தை தொடவும்.',
              ),
              style: const TextStyle(color: PillTheme.inkSoft),
            ),
            const SizedBox(height: 16),
            if (schedule?.isSample ?? false) SampleBanner(language: lang),
            if (schedule == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr(
                      'No schedule yet. Scan a prescription to '
                      'build one.',
                      'இன்னும் அட்டவணை இல்லை. உருவாக்க சீட்டை '
                      'ஸ்கேன் செய்யவும்.',
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              )
            else ...[
              for (final item in items) ...[
                _ScheduleMedicineCard(
                  item: item,
                  lang: lang,
                  effective: store.effectiveStatusFor(item, now),
                  onTap: () => showDoseEditDialog(context, store, item),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 8),
            GradientButton(
              icon: Icons.document_scanner,
              label: tr('Scan Prescription', 'சீட்டை ஸ்கேன் செய்யவும்'),
              onPressed: onScan,
            ),
            const SizedBox(height: 24),
            Text(
              tr('Your medicine list', 'உங்கள் மருந்து பட்டியல்'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Names confirmed by you — from scans or added by '
                'hand. New schedules are made from this list.',
                'நீங்கள் உறுதிப்படுத்திய பெயர்கள் — ஸ்கேனிலிருந்து '
                'அல்லது கைமுறையாக. புதிய அட்டவணைகள் இந்த '
                'பட்டியலிலிருந்து உருவாகும்.',
              ),
              style: const TextStyle(color: PillTheme.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (store.medicines.isEmpty)
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
              ...store.medicines.map(
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: m.strength.isEmpty ? null : Text(m.strength),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: PillTheme.danger),
                        onPressed: () => store.removeMedicine(m.id),
                      ),
                      onTap: () => showMedicineEditDialog(context, store, m),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            GradientButton(
              icon: Icons.add,
              label: tr('Add Medicine', 'மருந்து சேர்'),
              onPressed: () => showMedicineEditDialog(context, store),
            ),
          ],
        );
      },
    );
  }
}

/// One scheduled medicine as a status-tinted row (boards): big
/// bold time, name + purpose line, status circle at the edge.
class _ScheduleMedicineCard extends StatelessWidget {
  const _ScheduleMedicineCard({
    required this.item,
    required this.lang,
    required this.effective,
    required this.onTap,
  });

  final ScheduleItem item;
  final AppLanguage lang;
  final EffectiveDoseStatus effective;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(effective);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PillTheme.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: style.tint.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PillTheme.cardRadius),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 86,
                child: Text(
                  item.timeLabel,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicineName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${item.doseFor(lang)} · '
                      '${item.foodRelation.labelFor(lang)}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: PillTheme.inkSoft,
                      ),
                    ),
                    Text(
                      item.explanationFor(lang),
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (item.caution)
                      CautionStrip(note: item.cautionNoteFor(lang)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusCircle(status: effective),
            ],
          ),
        ),
      ),
    );
  }
}
