import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emergency_contact_dialog.dart';
import '../widgets/safety_line.dart';

/// MVP item 4: caregiver view — today's doses with taken / missed /
/// upcoming status, so a family member can see at a glance whether
/// medicines were taken on time. Also shows adherence over the dose
/// log, the most recent dose-log entries, and the emergency-contact
/// settings card.
///
/// Day 1 reads local state (the same store the patient uses). The
/// data layer ([ScheduleRepository]) is the seam where Firestore sync
/// will slot in, so this screen will later show a remote parent's
/// live status without changes here.
class CaregiverScreen extends StatelessWidget {
  const CaregiverScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final schedule = store.schedule;
        final children = <Widget>[
          const Text(
            'Caregiver view · பராமரிப்பாளர் பார்வை',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            "Today's doses and whether they were taken on time.",
            style: TextStyle(color: PillTheme.inkSoft),
          ),
          const SizedBox(height: 16),
        ];

        if (schedule == null) {
          children.add(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No schedule yet — nothing to follow up on.\n\n'
                'அட்டவணை இல்லை.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
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
          const Text(
            'Family sync (see a parent\'s status from your own phone) '
            'arrives with the Firestore step — see FIREBASE-SETUP.md.',
            style: TextStyle(color: PillTheme.inkSoft, fontSize: 14),
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
      if (schedule.isSample) const SampleBanner(),
      Row(
        children: [
          _SummaryTile(
            label: EffectiveDoseStatus.taken.en,
            ta: EffectiveDoseStatus.taken.ta,
            value: '${counts[EffectiveDoseStatus.taken]}',
            color: PillTheme.primary,
            icon: Icons.check_circle,
          ),
          _SummaryTile(
            label: EffectiveDoseStatus.skipped.en,
            ta: EffectiveDoseStatus.skipped.ta,
            value: '${counts[EffectiveDoseStatus.skipped]}',
            color: PillTheme.inkSoft,
            icon: Icons.remove_circle,
          ),
          _SummaryTile(
            label: EffectiveDoseStatus.snoozed.en,
            ta: EffectiveDoseStatus.snoozed.ta,
            value: '${counts[EffectiveDoseStatus.snoozed]}',
            color: PillTheme.accent,
            icon: Icons.snooze,
          ),
          _SummaryTile(
            label: EffectiveDoseStatus.missed.en,
            ta: EffectiveDoseStatus.missed.ta,
            value: '${counts[EffectiveDoseStatus.missed]}',
            color: PillTheme.danger,
            icon: Icons.alarm_off,
          ),
          _SummaryTile(
            label: EffectiveDoseStatus.pending.en,
            ta: EffectiveDoseStatus.pending.ta,
            value: '${counts[EffectiveDoseStatus.pending]}',
            color: PillTheme.accent,
            icon: Icons.schedule,
          ),
        ],
      ),
      const SizedBox(height: 12),
      ...items.map((item) {
        final effective = store.effectiveStatusFor(item, now);
        final (color, icon) = switch (effective) {
          EffectiveDoseStatus.taken => (PillTheme.primary, Icons.check_circle),
          EffectiveDoseStatus.skipped => (
              PillTheme.inkSoft,
              Icons.remove_circle
            ),
          EffectiveDoseStatus.snoozed => (PillTheme.accent, Icons.snooze),
          EffectiveDoseStatus.missed => (PillTheme.danger, Icons.alarm_off),
          EffectiveDoseStatus.pending => (PillTheme.accent, Icons.schedule),
        };
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(icon, color: color, size: 28),
                title: Text(
                  item.medicineName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${item.timeLabel} · ${item.dose}'),
                trailing: Text(
                  effective.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (effective == EffectiveDoseStatus.missed)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    kMissedDoseAdvice,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PillTheme.danger,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.insights,
                  color: PillTheme.primaryDark, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Adherence · ஒழுங்கு',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                adherence == null ? '—' : '${adherence.round()}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: PillTheme.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Recent dose log · அண்மைய பதிவு',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (recentLog.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No doses recorded yet. · இன்னும் பதிவு இல்லை.',
            ),
          ),
        )
      else
        ...recentLog.map(
          (e) => Card(
            child: ListTile(
              leading: Icon(
                switch (e.status) {
                  EffectiveDoseStatus.taken => Icons.check_circle,
                  EffectiveDoseStatus.skipped => Icons.remove_circle,
                  EffectiveDoseStatus.snoozed => Icons.snooze,
                  EffectiveDoseStatus.missed => Icons.alarm_off,
                  EffectiveDoseStatus.pending => Icons.schedule,
                },
                color: PillTheme.primaryDark,
              ),
              title: Text(
                e.medicineName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_formatLogTime(e.scheduledAt)),
              trailing: Text(
                e.status.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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

/// Settings card for the emergency contact shown on the Today
/// screen's emergency button.
class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final contact = store.emergencyContact;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emergency, color: PillTheme.danger),
                SizedBox(width: 8),
                Text(
                  'Emergency contact · அவசர தொடர்பு',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              contact == null
                  ? 'Not set yet. Add a family member the patient can '
                      'call in one tap from the Today screen.'
                  : '${contact.name} — ${contact.phone}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showEmergencyContactDialog(context, store),
              icon: const Icon(Icons.edit),
              label: Text(contact == null ? 'Add · சேர்' : 'Edit · திருத்து'),
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
    required this.ta,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String ta;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              Text(ta,
                  style: const TextStyle(
                      fontSize: 12, color: PillTheme.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
