import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets/emergency_contact_dialog.dart';
import '../widgets/v2.dart';

/// V2 Profile / Settings screen (boards): the language toggle
/// (தமிழ் / English segmented pill), the emergency contact with
/// its edit dialog and one-tap dialer (never auto-dials), the App
/// Check setup token tile for this sideloaded build, and the
/// safety line in full.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    required this.firebaseReady,
  });

  final AppStore store;
  final bool firebaseReady;

  AppLanguage get lang => store.language;
  String tr(String en, String ta) => lang.pick(en, ta);

  Future<void> _callContact(BuildContext context) async {
    final contact = store.emergencyContact;
    if (contact == null) return;
    // Opens the dialer with the number filled in — never auto-dials.
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
    if (!opened && context.mounted) {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final contact = store.emergencyContact;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('Profile & Settings', 'சுயவிவரம் & அமைப்புகள்'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            // --- Language -------------------------------------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language, color: PillTheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          tr('Language', 'மொழி'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'The whole app speaks one language at a time.',
                        'செயலி முழுவதும் ஒரு நேரத்தில் ஒரு மொழியில் '
                        'மட்டுமே பேசும்.',
                      ),
                      style: const TextStyle(
                        color: PillTheme.inkSoft,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedPills(
                      labels: const ['தமிழ்', 'English'],
                      selectedIndex: lang.isTamil ? 0 : 1,
                      onSelected: (i) => store.setLanguage(
                        i == 0 ? AppLanguage.ta : AppLanguage.en,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // --- Emergency contact ------------------------------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emergency, color: PillTheme.danger),
                        const SizedBox(width: 10),
                        Text(
                          tr('Emergency contact', 'அவசர தொடர்பு'),
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
                          ? tr(
                              'Not set yet. Add a family member the '
                              'patient can call in one tap from the '
                              'Schedule screen.',
                              'இன்னும் சேர்க்கவில்லை. அட்டவணை '
                              'பக்கத்திலிருந்து ஒரே தொடுதலில் '
                              'அழைக்கக்கூடிய குடும்ப உறுப்பினரை '
                              'சேர்க்கவும்.',
                            )
                          : '${contact.name} — ${contact.phone}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                showEmergencyContactDialog(context, store),
                            icon: const Icon(Icons.edit, size: 20),
                            label: Text(
                              contact == null
                                  ? tr('Add', 'சேர்')
                                  : tr('Edit', 'திருத்து'),
                            ),
                          ),
                        ),
                        if (contact != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: PillTheme.danger,
                              ),
                              onPressed: () => _callContact(context),
                              icon: const Icon(Icons.call, size: 20),
                              label: Text(tr('Call', 'அழை')),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // --- About / safety ---------------------------------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: PillTheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          tr('About PillPaatha', 'PillPaatha பற்றி'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'Your daily medicine partner. Photo a '
                        'prescription, get a simple schedule with '
                        'reminders — in Tamil or English.',
                        'உங்கள் தினசரி மருந்து தோழன். சீட்டை '
                        'புகைப்படம் எடுக்கவும், நினைவூட்டல்களுடன் '
                        'எளிய அட்டவணை பெறவும் — தமிழில் அல்லது '
                        'ஆங்கிலத்தில்.',
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medical_services_outlined,
                            color: PillTheme.primaryDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(
                              'This app does not replace your doctor.',
                              'இந்த செயலி உங்கள் மருத்துவருக்கு '
                              'மாற்றாகாது.',
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
