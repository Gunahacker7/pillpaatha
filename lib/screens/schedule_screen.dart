import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/dose_edit_dialog.dart';
import '../widgets/emergency_contact_dialog.dart';
import '../widgets/safety_line.dart';
import '../widgets/v2.dart';

/// MVP item 3, V2 styling: today's schedule as status-tinted dose
/// rows (boards) with Taken / Skip / Snooze actions that record
/// dose status (the same actions offered on the reminder
/// notifications), a one-tap emergency call button, a voice
/// read-out of today's medicines, and tap-to-edit for dose time
/// and dose text.
///
/// Everything renders in the app's ONE selected language.
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
  AppLanguage get lang => store.language;
  String tr(String en, String ta) => lang.pick(en, ta);

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
        SnackBar(
          content: Text(tr(
            'Could not open the dialer.',
            'டயலரை திறக்க முடியவில்லை.',
          )),
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
              ? tr(
                  'Emergency — Call ${contact.name}',
                  'அவசரம் — ${contact.name} ஐ அழைக்கவும்',
                )
              : tr(
                  'Set emergency contact',
                  'அவசர தொடர்பை சேர்க்கவும்',
                ),
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
              '${i.timeLabel} — ${i.medicineName}, ${i.doseFor(lang)}, '
              '${i.foodRelation.labelFor(lang)}.')
          .join(' ');
      setState(() => _speaking = true);
      try {
        await _tts.setLanguage(lang.isTamil ? 'ta-IN' : 'en-IN');
      } catch (_) {
        // Some devices lack the voice; the default still works.
      }
      await _tts.speak(text);
    } catch (e) {
      if (mounted) {
        setState(() => _speaking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(
              'Could not read aloud. ($e)',
              'படிக்க முடியவில்லை. ($e)',
            )),
          ),
        );
      }
    }
  }

  // --- Build ---------------------------------------------------------------

  static String _dateLabel(DateTime now, AppLanguage lang) {
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const monthsTa = [
      'ஜன', 'பிப்', 'மார்', 'ஏப்', 'மே', 'ஜூன்',
      'ஜூலை', 'ஆக', 'செப்', 'அக்', 'நவ', 'டிச',
    ];
    final month =
        (lang.isTamil ? monthsTa : monthsEn)[now.month - 1];
    return '${now.day} $month ${now.year}';
  }

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
              Text(
                tr(
                  'No schedule yet.\nGo to the Scan tab, photo your '
                  'medicines, and tap "Make my schedule".',
                  'இன்னும் அட்டவணை இல்லை.\nஸ்கேன் பக்கத்தில் '
                  'மருந்துகளை புகைப்படம் எடுத்து, "அட்டவணை '
                  'உருவாக்கு" என்பதை தொடவும்.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
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
          groups.putIfAbsent(item.dayPartFor(lang), () => []).add(item);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (schedule.isSample) SampleBanner(language: lang),
            _emergencyButton(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    tr("Today's medicines", 'இன்றைய மருந்துகள்'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _dateLabel(now, lang),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PillTheme.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Listen: full-width row of its own (v0.2.0 squeezed it
            // beside the heading).
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _toggleListen(items),
                icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                label: Text(
                  _speaking
                      ? tr('Stop', 'நிறுத்து')
                      : tr('Listen', 'கேளுங்கள்'),
                ),
              ),
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
              ...entry.value.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DoseCard(
                      item: item,
                      lang: lang,
                      effective: store.effectiveStatusFor(item, now),
                      onTaken: () =>
                          store.markStatus(item, DoseStatus.taken),
                      onSkip: () =>
                          store.markStatus(item, DoseStatus.skipped),
                      onSnooze: () => store.markSnoozed(item),
                      onUndo: () => store.clearStatus(item),
                      onTap: () => showDoseEditDialog(context, store, item),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }
}

/// One dose as a status-tinted card (boards): time big and bold,
/// medicine name + purpose, status chip on its OWN row (never
/// sharing the header row — the v0.2.0 squeeze bug), then the
/// Taken / Snooze / Skip actions.
class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.item,
    required this.lang,
    required this.effective,
    required this.onTaken,
    required this.onSkip,
    required this.onSnooze,
    required this.onUndo,
    required this.onTap,
  });

  final ScheduleItem item;
  final AppLanguage lang;
  final EffectiveDoseStatus effective;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;
  final VoidCallback onUndo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(effective);
    final hasRecordedStatus = effective == EffectiveDoseStatus.taken ||
        effective == EffectiveDoseStatus.skipped ||
        effective == EffectiveDoseStatus.snoozed;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      item.timeLabel,
                      style: const TextStyle(
                        fontSize: 21,
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
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item.doseFor(lang)} · '
                          '${item.foodRelation.labelFor(lang)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusCircle(status: effective),
                ],
              ),
              // Status chip on its own row.
              const SizedBox(height: 10),
              Chip(
                avatar: Icon(style.icon, color: Colors.white, size: 18),
                label: Text(effective.labelFor(lang)),
                backgroundColor: style.color,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.explanationFor(lang),
                style: const TextStyle(fontSize: 16),
              ),
              if (item.caution)
                CautionStrip(note: item.cautionNoteFor(lang)),
              if (effective == EffectiveDoseStatus.missed) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: PillTheme.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        missedDoseAdviceFor(lang),
                        style: const TextStyle(
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
                      child: GradientButton(
                        onPressed: onTaken,
                        icon: Icons.check,
                        label: lang.pick('Taken', 'சாப்பிட்டது'),
                        minHeight: 54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSnooze,
                        icon: const Icon(Icons.snooze, size: 20),
                        label: _ButtonLabel(
                          lang.pick('Snooze', 'ஒத்திவை'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSkip,
                        icon: const Icon(Icons.skip_next, size: 20),
                        label: _ButtonLabel(
                          lang.pick('Skip', 'தவிர்'),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onUndo,
                    child: Text(lang.pick('Undo', 'மாற்று')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Button label that scales down to fit instead of wrapping
/// mid-word (the v0.2.0 "Ta-ke-n" bug).
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}
