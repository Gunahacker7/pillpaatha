import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/safety_line.dart';

/// MVP item 3: today's schedule in Tamil + English, with Taken / Skip
/// actions that record dose status (the same actions offered on the
/// reminder notifications).
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.store});

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
                'No schedule yet.\nGo to the Scan tab, photo your '
                'medicines, and tap "Make my schedule".\n\n'
                'அட்டவணை இல்லை. ஸ்கேன் பக்கத்தில் மருந்துகளை '
                'புகைப்படம் எடுக்கவும்.',
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

        // Group by day-part, preserving time order.
        final groups = <String, List<ScheduleItem>>{};
        for (final item in items) {
          groups.putIfAbsent(item.dayPart, () => []).add(item);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (schedule.isSample) const SampleBanner(),
            const Text(
              "Today's medicines · இன்றைய மருந்துகள்",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PillTheme.primaryDark,
                  ),
                ),
              ),
              ...entry.value.map((item) => _DoseCard(
                    item: item,
                    status: store.statusFor(item, now),
                    missed: store.isMissed(item, now),
                    onTaken: () =>
                        store.markStatus(item, DoseStatus.taken),
                    onSkip: () =>
                        store.markStatus(item, DoseStatus.skipped),
                    onUndo: () => store.clearStatus(item),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.item,
    required this.status,
    required this.missed,
    required this.onTaken,
    required this.onSkip,
    required this.onUndo,
  });

  final ScheduleItem item;
  final DoseStatus? status;
  final bool missed;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final statusChip = switch (status) {
      DoseStatus.taken => const Chip(
          avatar: Icon(Icons.check_circle, color: Colors.white, size: 18),
          label: Text('Taken · சாப்பிட்டாச்சு'),
          backgroundColor: PillTheme.primary,
          labelStyle: TextStyle(color: Colors.white),
        ),
      DoseStatus.skipped => const Chip(
          avatar: Icon(Icons.remove_circle, color: Colors.white, size: 18),
          label: Text('Skipped · தவிர்த்தது'),
          backgroundColor: PillTheme.inkSoft,
          labelStyle: TextStyle(color: Colors.white),
        ),
      null when missed => const Chip(
          avatar: Icon(Icons.alarm_off, color: Colors.white, size: 18),
          label: Text('Missed · தவறிவிட்டது'),
          backgroundColor: PillTheme.danger,
          labelStyle: TextStyle(color: Colors.white),
        ),
      null => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: PillTheme.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.medication,
                      color: PillTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicineName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${item.timeLabel} · ${item.dose}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        '${item.foodRelation.en} · ${item.foodRelation.ta}',
                        style: const TextStyle(
                          color: PillTheme.inkSoft,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                ?statusChip,
              ],
            ),
            const SizedBox(height: 10),
            Text(item.explanationTa, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              item.explanationEn,
              style: const TextStyle(
                fontSize: 15,
                color: PillTheme.inkSoft,
              ),
            ),
            if (item.caution) CautionStrip(note: item.cautionNote),
            const SizedBox(height: 12),
            if (status == null)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onTaken,
                      icon: const Icon(Icons.check),
                      label: const Text('Taken'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSkip,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Skip'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onUndo,
                  child: const Text('Undo · மாற்று'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
