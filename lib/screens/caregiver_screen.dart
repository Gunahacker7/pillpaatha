import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/safety_line.dart';

/// MVP item 4: caregiver view — today's doses with taken / missed /
/// upcoming status, so a family member can see at a glance whether
/// medicines were taken on time.
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
        if (schedule == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No schedule yet — nothing to follow up on.\n\n'
                'அட்டவணை இல்லை.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
              ),
            ),
          );
        }

        final now = DateTime.now();
        final items = [...schedule.items]
          ..sort((a, b) =>
              (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

        var taken = 0, skipped = 0, missed = 0, upcoming = 0;
        for (final item in items) {
          final s = store.statusFor(item, now);
          if (s == DoseStatus.taken) {
            taken++;
          } else if (s == DoseStatus.skipped) {
            skipped++;
          } else if (store.isMissed(item, now)) {
            missed++;
          } else {
            upcoming++;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (schedule.isSample) const SampleBanner(),
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
            Row(
              children: [
                _SummaryTile(
                  label: 'Taken',
                  ta: 'சாப்பிட்டது',
                  count: taken,
                  color: PillTheme.primary,
                  icon: Icons.check_circle,
                ),
                _SummaryTile(
                  label: 'Missed',
                  ta: 'தவறியது',
                  count: missed,
                  color: PillTheme.danger,
                  icon: Icons.alarm_off,
                ),
                _SummaryTile(
                  label: 'Skipped',
                  ta: 'தவிர்த்தது',
                  count: skipped,
                  color: PillTheme.inkSoft,
                  icon: Icons.remove_circle,
                ),
                _SummaryTile(
                  label: 'Upcoming',
                  ta: 'வரவிருப்பது',
                  count: upcoming,
                  color: PillTheme.accent,
                  icon: Icons.schedule,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              final s = store.statusFor(item, now);
              final isMissed = s == null && store.isMissed(item, now);
              final (label, color, icon) = switch ((s, isMissed)) {
                (DoseStatus.taken, _) => (
                    'Taken · சாப்பிட்டாச்சு',
                    PillTheme.primary,
                    Icons.check_circle,
                  ),
                (DoseStatus.skipped, _) => (
                    'Skipped · தவிர்த்தது',
                    PillTheme.inkSoft,
                    Icons.remove_circle,
                  ),
                (null, true) => (
                    'Missed · தவறிவிட்டது',
                    PillTheme.danger,
                    Icons.alarm_off,
                  ),
                _ => (
                    'Upcoming · வரவிருப்பது',
                    PillTheme.accent,
                    Icons.schedule,
                  ),
              };
              return Card(
                child: ListTile(
                  leading: Icon(icon, color: color, size: 28),
                  title: Text(
                    item.medicineName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${item.timeLabel} · ${item.dose}'),
                  trailing: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Family sync (see a parent\'s status from your own phone) '
              'arrives with the Firestore step — see FIREBASE-SETUP.md.',
              style: TextStyle(color: PillTheme.inkSoft, fontSize: 14),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.ta,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final String ta;
  final int count;
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
                '$count',
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
