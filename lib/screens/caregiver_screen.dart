import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emergency_contact_dialog.dart';
import '../widgets/safety_line.dart';
import '../widgets/v2.dart';

/// MVP item 4, V2 "Reports" (the caregiver view renamed per the
/// boards): adherence ring, today's doses with taken / missed /
/// upcoming status so a family member can see at a glance whether
/// medicines were taken on time, the stat tiles, the recent dose
/// log, and the emergency-contact settings card.
///
/// Day 1 reads local state (the same store the patient uses). The
/// data layer ([ScheduleRepository]) is the seam where Firestore
/// sync will slot in, so this screen will later show a remote
/// parent's live status without changes here.
///
/// Everything renders in the app's ONE selected language.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.store});

  final AppStore store;

  AppLanguage get lang => store.language;
  String tr(String en, String ta) => lang.pick(en, ta);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final schedule = store.schedule;
        final children = <Widget>[
          Text(
            tr('Reports', 'அறிக்கைகள்'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              "Today's doses, adherence and whether medicines were "
              'taken on time — the caregiver view.',
              'இன்றைய டோஸ்கள், ஒழுங்கு, மருந்துகள் நேரத்தில் '
              'எடுக்கப்பட்டதா — பராமரிப்பாளர் பார்வை.',
            ),
            style: const TextStyle(color: PillTheme.inkSoft),
          ),
          const SizedBox(height: 16),
        ];

        if (schedule == null) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                tr(
                  'No schedule yet — nothing to follow up on.',
                  'இன்னும் அட்டவணை இல்லை — பின்தொடர எதுவும் இல்லை.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
            ),
          );
        } else {
          children.addAll(_scheduleSections(context, schedule));
        }

        children.addAll([
          const SizedBox(height: 16),
          _EmergencyContactCard(store: store),
          const SizedBox(height: 8),
          Text(
            tr(
              'Family sync (see a parent\'s status from your own '
              'phone) arrives with the Firestore step — see '
              'FIREBASE-SETUP.md.',
              'குடும்ப ஒத்திசைவு (உங்கள் தொலைபேசியிலிருந்து '
              'பெற்றோரின் நிலையைப் பார்ப்பது) Firestore படியில் '
              'வரும் — FIREBASE-SETUP.md பார்க்கவும்.',
            ),
            style: const TextStyle(color: PillTheme.inkSoft, fontSize: 14),
          ),
        ]);

        return ListView(padding: const EdgeInsets.all(16), children: children);
      },
    );
  }

  List<Widget> _scheduleSections(
    BuildContext context,
    GeneratedSchedule schedule,
  ) {
    final now = DateTime.now();
    final items = [...schedule.items]
      ..sort((a, b) =>
          (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    final counts = <EffectiveDoseStatus, int>{
      for (final s in EffectiveDoseStatus.values) s: 0,
    };
    for (final item in items) {
      final s = store.effectiveStatusFor(item, now);
      counts[s] = counts[s]! + 1;
    }

    final adherence = adherencePercent(store.doseLog);
    final recentLog = store.doseLog.reversed.take(15).toList();

    return [
      if (schedule.isSample) SampleBanner(language: lang),
      // Adherence ring card (boards).
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              AdherenceRing(
                percent: adherence,
                caption: tr('Adherence', 'ஒழுங்கு'),
                size: 118,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Dose adherence', 'மருந்து ஒழுங்கு'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adherence == null
                          ? tr(
                              'No doses recorded yet.',
                              'இன்னும் டோஸ் பதிவு இல்லை.',
                            )
                          : tr(
                              '${counts[EffectiveDoseStatus.taken]} taken '
                              'today · ${counts[EffectiveDoseStatus.missed]} '
                              'missed today.',
                              'இன்று ${counts[EffectiveDoseStatus.taken]} '
                              'எடுத்தது · ${counts[EffectiveDoseStatus.missed]} '
                              'தவறியது.',
                            ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: PillTheme.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Summary tiles: 3 per row, wrapping (never squeezed).
      LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - 16) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in EffectiveDoseStatus.values)
                SizedBox(
                  width: tileWidth,
                  child: _SummaryTile(
                    label: status.labelFor(lang),
                    value: '${counts[status]}',
                    color: statusStyle(status).color,
                    icon: statusStyle(status).icon,
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      ...items.map((item) {
        final effective = store.effectiveStatusFor(item, now);
        final style = statusStyle(effective);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Container(
              decoration: BoxDecoration(
                color: style.tint.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(PillTheme.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: StatusCircle(status: effective),
                    title: Text(
                      item.medicineName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.timeLabel} · ${item.doseFor(lang)}',
                    ),
                    // Status word on its own line under the title
                    // area is in the subtitle flow; the trailing
                    // slot carries only the status circle.
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      effective.labelFor(lang),
                      style: TextStyle(
                        color: style.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (item.caution)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: CautionStrip(
                        note: item.cautionNoteFor(lang),
                      ),
                    ),
                  if (effective == EffectiveDoseStatus.missed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        missedDoseAdviceFor(lang),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PillTheme.danger,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 16),
      Text(
        tr('Recent dose log', 'அண்மைய டோஸ் பதிவு'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (recentLog.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tr('No doses recorded yet.', 'இன்னும் பதிவு இல்லை.'),
            ),
          ),
        )
      else
        ...recentLog.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: StatusCircle(status: e.status, size: 26),
                title: Text(
                  e.medicineName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_formatLogTime(e.scheduledAt)),
                trailing: Text(
                  e.status.labelFor(lang),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  static String _formatLogTime(DateTime t) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = t.hour < 12 ? 'AM' : 'PM';
    return '${t.day} ${months[t.month - 1]}, '
        '$h:${t.minute.toString().padLeft(2, '0')} $suffix';
  }
}

/// Settings card for the emergency contact shown on the Schedule
/// screen's emergency button.
class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final contact = store.emergencyContact;
    final lang = store.language;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency, color: PillTheme.danger),
                const SizedBox(width: 8),
                Text(
                  lang.pick('Emergency contact', 'அவசர தொடர்பு'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              contact == null
                  ? lang.pick(
                      'Not set yet. Add a family member the patient '
                      'can call in one tap from the Schedule screen.',
                      'இன்னும் சேர்க்கவில்லை. அட்டவணை '
                      'பக்கத்திலிருந்து ஒரே தொடுதலில் அழைக்கக்கூடிய '
                      'குடும்ப உறுப்பினரை சேர்க்கவும்.',
                    )
                  : '${contact.name} — ${contact.phone}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showEmergencyContactDialog(context, store),
              icon: const Icon(Icons.edit),
              label: Text(
                contact == null
                    ? lang.pick('Add', 'சேர்')
                    : lang.pick('Edit', 'திருத்து'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
