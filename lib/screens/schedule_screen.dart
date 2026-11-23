import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emergency_contact_dialog.dart';
import '../widgets/safety_line.dart';

/// MVP item 3: today's schedule in Tamil + English, with Taken /
/// Skip / Snooze actions that record dose status (the same actions
/// offered on the reminder notifications), a one-tap emergency call
/// button, a voice read-out of today's medicines, and tap-to-edit
/// for dose time and dose text.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // --- Emergency ------------------------------------------------------

  Future<void> _onEmergencyPressed() async {
    final contact = store.emergencyContact;
    if (contact == null) {
      await showEmergencyContactDialog(context, store);
      return;
    }
    // Opens the dialer with the number filled in — never auto-dials;
    // the user always presses the call button themselves.
    final uri = Uri(
      scheme: 'tel',
      path: contact.phone.replaceAll(RegExp(r'[\s-]'), ''),
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the dialer. · டயலரை திறக்க முடியவில்லை.',
          ),
        ),
      );
    }
  }

  Widget _emergencyButton() {
    final contact = store.emergencyContact;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: PillTheme.danger,
          foregroundColor: Colors.white,
        ),
        onPressed: _onEmergencyPressed,
        icon: const Icon(Icons.emergency),
        label: Text(
          contact != null
              ? 'Emergency · அவசரம் — Call ${contact.name}'
              : 'Set emergency contact · அவசர எண் சேர்க்கவும்',
        ),
      ),
    );
  }

  // --- Voice read-out ---------------------------------------------------

  Future<void> _toggleListen(List<ScheduleItem> items) async {
    if (_speaking) {
      try {
        await _tts.stop();
      } catch (_) {
        // Stopping is best-effort.
      }
      if (mounted) setState(() => _speaking = false);
      return;
    }
    try {
      final sorted = [...items]..sort((a, b) =>
          (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      final text = sorted
          .map((i) =>
              '${i.timeLabel} — ${i.medicineName}, ${i.dose}, '
              '${i.foodRelation.en}.')
          .join(' ');
      setState(() => _speaking = true);
      try {
        await _tts.setLanguage('en-IN');
      } catch (_) {
        // Some devices lack en-IN; the default voice still works.
      }
      await _tts.speak(text);
    } catch (e) {
      if (mounted) {
        setState(() => _speaking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not read aloud. · படிக்க முடியவில்லை. ($e)'),
          ),
        );
      }
    }
  }

  // --- Edit dose time / text ---------------------------------------------

  Future<void> _editItem(ScheduleItem item) async {
    var picked = TimeOfDay(hour: item.hour, minute: item.minute);
    final doseCtrl = TextEditingController(text: item.dose);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit dose · திருத்து — ${item.medicineName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule,
                    color: PillTheme.primary),
                title: const Text('Time · நேரம்'),
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
                decoration: const InputDecoration(
                  labelText: 'Dose, as prescribed · மருந்தளவு',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Keep the dose exactly as your doctor prescribed — '
                'this app never changes a dose for you.',
                style: TextStyle(color: PillTheme.inkSoft, fontSize: 14),
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
      ),
    );
    if (saved != true) return;
    final doseText = doseCtrl.text.trim();
    await store.updateScheduleItem(
      item.copyWith(
        hour: picked.hour,
        minute: picked.minute,
        dose: doseText.isEmpty ? item.dose : doseText,
      ),
    );
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final schedule = store.schedule;
        if (schedule == null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _emergencyButton(),
              const SizedBox(height: 24),
              const Text(
                'No schedule yet.\nGo to the Scan tab, photo your '
                'medicines, and tap "Make my schedule".\n\n'
                'அட்டவணை இல்லை. ஸ்கேன் பக்கத்தில் மருந்துகளை '
                'புகைப்படம் எடுக்கவும்.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
              ),
            ],
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
            _emergencyButton(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's medicines · இன்றைய மருந்துகள்",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleListen(items),
                  icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                  label: Text(
                    _speaking ? 'Stop · நிறுத்து' : 'Listen · கேளுங்கள்',
                  ),
                ),
              ],
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
                    effective: store.effectiveStatusFor(item, now),
                    onTaken: () =>
                        store.markStatus(item, DoseStatus.taken),
                    onSkip: () =>
                        store.markStatus(item, DoseStatus.skipped),
                    onSnooze: () => store.markSnoozed(item),
                    onUndo: () => store.clearStatus(item),
                    onTap: () => _editItem(item),
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
    required this.effective,
    required this.onTaken,
    required this.onSkip,
    required this.onSnooze,
    required this.onUndo,
    required this.onTap,
  });

  final ScheduleItem item;
  final EffectiveDoseStatus effective;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;
  final VoidCallback onUndo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusChip = switch (effective) {
      EffectiveDoseStatus.taken => const Chip(
          avatar: Icon(Icons.check_circle, color: Colors.white, size: 18),
          label: Text('Taken · சாப்பிட்டாச்சு'),
          backgroundColor: PillTheme.primary,
          labelStyle: TextStyle(color: Colors.white),
        ),
      EffectiveDoseStatus.skipped => const Chip(
          avatar: Icon(Icons.remove_circle, color: Colors.white, size: 18),
          label: Text('Skipped · தவிர்த்தது'),
          backgroundColor: PillTheme.inkSoft,
          labelStyle: TextStyle(color: Colors.white),
        ),
      EffectiveDoseStatus.snoozed => const Chip(
          avatar: Icon(Icons.snooze, color: PillTheme.ink, size: 18),
          label: Text('Snoozed · ஒத்திவைத்தது'),
          backgroundColor: PillTheme.accent,
          labelStyle: TextStyle(color: PillTheme.ink),
        ),
      EffectiveDoseStatus.missed => const Chip(
          avatar: Icon(Icons.alarm_off, color: Colors.white, size: 18),
          label: Text('Missed · தவறிவிட்டது'),
          backgroundColor: PillTheme.danger,
          labelStyle: TextStyle(color: Colors.white),
        ),
      EffectiveDoseStatus.pending => null,
    };

    final hasRecordedStatus = effective == EffectiveDoseStatus.taken ||
        effective == EffectiveDoseStatus.skipped ||
        effective == EffectiveDoseStatus.snoozed;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PillTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor:
                        PillTheme.primary.withValues(alpha: 0.12),
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
              if (effective == EffectiveDoseStatus.missed) ...[
                const SizedBox(height: 10),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: PillTheme.danger, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kMissedDoseAdvice,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PillTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (!hasRecordedStatus)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onTaken,
                        icon: const Icon(Icons.check),
                        label: const Text('Taken'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSnooze,
                        icon: const Icon(Icons.snooze),
                        label: const Text('Snooze'),
                      ),
                    ),
                    const SizedBox(width: 8),
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
      ),
    );
  }
}
