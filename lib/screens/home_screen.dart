import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/safety_line.dart';
import '../widgets/v2.dart';

/// V2 Home dashboard (boards 1/3/5/6): teal header with greeting
/// and the language toggle pill, today's medicine count, the
/// next-medicine card with its big Take action, this week's
/// adherence ring, quick actions, and a prominent Scan
/// Prescription button. Everything on it reads the same store the
/// other screens use — no function is duplicated, only surfaced.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onOpenTab,
    required this.onScan,
  });

  final AppStore store;

  /// Jump to a shell tab: 1 Schedule · 2 Medicines · 3 Reports ·
  /// 4 Profile.
  final ValueChanged<int> onOpenTab;

  /// Open the Scan screen (pushed route).
  final VoidCallback onScan;

  AppLanguage get lang => store.language;
  String tr(String en, String ta) => lang.pick(en, ta);

  String _greeting(DateTime now) {
    if (now.hour < 12) return tr('Good Morning', 'காலை வணக்கம்');
    if (now.hour < 17) return tr('Good Afternoon', 'மதிய வணக்கம்');
    return tr('Good Evening', 'மாலை வணக்கம்');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final schedule = store.schedule;
        final items = schedule == null
            ? <ScheduleItem>[]
            : ([...schedule.items]..sort((a, b) =>
                (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute)));
        final next = items
            .where((i) =>
                store.effectiveStatusFor(i, now) ==
                EffectiveDoseStatus.pending)
            .firstOrNull;
        // This week's adherence, from the dose log (last 7 days).
        final weekStart = now.subtract(const Duration(days: 7));
        final weekLog = store.doseLog
            .where((e) => e.scheduledAt.isAfter(weekStart))
            .toList();
        final adherence = adherencePercent(weekLog);
        final contact = store.emergencyContact;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // --- Teal header band --------------------------------
            Container(
              decoration: const BoxDecoration(
                gradient: PillTheme.headerGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medication_liquid,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'PillPaatha',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      // Language toggle pill (boards): தமிழ் / English.
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final l in AppLanguage.values)
                              GestureDetector(
                                onTap: () => store.setLanguage(l),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: lang == l
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l.isTamil ? 'தமிழ்' : 'English',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: lang == l
                                          ? PillTheme.primaryDark
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    contact != null
                        ? '${_greeting(now)}, ${contact.name}!'
                        : '${_greeting(now)}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      "Let's keep your health on track.",
                      'உங்கள் உடல்நலத்தை சரியாக வைத்திருப்போம்.',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (schedule?.isSample ?? false)
                    SampleBanner(language: lang),
                  // --- Today's medicines count ---------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: PillTheme.takenTint,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.calendar_today,
                                color: PillTheme.primary, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr("Today's Medicines",
                                      'இன்றைய மருந்துகள்'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: PillTheme.inkSoft,
                                  ),
                                ),
                                Text(
                                  schedule == null
                                      ? tr('No schedule yet',
                                          'இன்னும் அட்டவணை இல்லை')
                                      : tr(
                                          '${items.length} medicines',
                                          '${items.length} மருந்துகள்',
                                        ),
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (schedule != null)
                            TextButton(
                              onPressed: () => onOpenTab(1),
                              child: Text(tr('View All', 'அனைத்தும்')),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // --- Next medicine --------------------------------
                  if (next != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    color: PillTheme.primary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  tr('Next Medicine', 'அடுத்த மருந்து'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: PillTheme.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              next.timeLabel,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${next.medicineName} · ${next.doseFor(lang)}',
                              style: const TextStyle(fontSize: 17),
                            ),
                            Text(
                              next.foodRelation.labelFor(lang),
                              style: const TextStyle(
                                fontSize: 15,
                                color: PillTheme.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 14),
                            GradientButton(
                              icon: Icons.check,
                              label: tr('Take Medicine', 'மருந்து எடுக்கவும்'),
                              onPressed: () =>
                                  store.markStatus(next, DoseStatus.taken),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // --- Adherence ring + quick actions ---------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AdherenceRing(
                            percent: adherence,
                            caption: tr('This Week', 'இந்த வாரம்'),
                            size: 118,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('Adherence', 'ஒழுங்கு'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  adherence == null
                                      ? tr(
                                          'Take doses to start your record.',
                                          'பதிவு தொடங்க டோஸ்களை எடுக்கவும்.',
                                        )
                                      : tr(
                                          'You took ${adherence.round()}% of doses this week.',
                                          'இந்த வாரம் ${adherence.round()}% டோஸ்கள் எடுத்துள்ளீர்கள்.',
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
                  const SizedBox(height: 14),
                  // --- Quick actions --------------------------------
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _QuickAction(
                            width: w,
                            icon: Icons.schedule,
                            label: tr('Schedule', 'அட்டவணை'),
                            onTap: () => onOpenTab(1),
                          ),
                          _QuickAction(
                            width: w,
                            icon: Icons.medication,
                            label: tr('Medicines', 'மருந்துகள்'),
                            onTap: () => onOpenTab(2),
                          ),
                          _QuickAction(
                            width: w,
                            icon: Icons.bar_chart,
                            label: tr('Reports', 'அறிக்கைகள்'),
                            onTap: () => onOpenTab(3),
                          ),
                          _QuickAction(
                            width: w,
                            icon: Icons.family_restroom,
                            label: tr('Caregiver', 'பராமரிப்பாளர்'),
                            onTap: () => onOpenTab(3),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  // --- Scan (prominent) ------------------------------
                  GradientButton(
                    icon: Icons.document_scanner,
                    label: tr(
                      'Scan Prescription',
                      'மருத்துவ சீட்டை ஸ்கேன் செய்யவும்',
                    ),
                    onPressed: onScan,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr(
                      'Photo a medicine strip or prescription — '
                      'reading happens on your phone itself.',
                      'மருந்து ஸ்ட்ரிப் அல்லது சீட்டை புகைப்படம் '
                      'எடுக்கவும் — படிப்பது உங்கள் தொலைபேசியிலேயே.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: PillTheme.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(PillTheme.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: PillTheme.takenTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: PillTheme.primary, size: 24),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
