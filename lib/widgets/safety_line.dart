import 'package:flutter/material.dart';

import '../theme.dart';

/// The safety line rendered on every screen (MVP item 5):
/// "This app does not replace your doctor." — bilingual, always
/// visible, never dismissible.
class SafetyLine extends StatelessWidget {
  const SafetyLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: PillTheme.primaryDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              '$kSafetyLineEn\n$kSafetyLineTa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amber banner shown wherever a SAMPLE schedule is displayed, so
/// sample data can never be mistaken for real Gemini output.
class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PillTheme.sampleBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PillTheme.accent),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: PillTheme.primaryDark),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'SAMPLE schedule — demo only. Timings and explanations are '
              'placeholders until Firebase + Gemini are connected. Do '
              'not follow this schedule.\n'
              'மாதிரி அட்டவணை — செயல்விளக்கத்திற்கு மட்டும்.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Caution strip for look-alike medicine names.
class CautionStrip extends StatelessWidget {
  const CautionStrip({super.key, required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PillTheme.cautionBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: PillTheme.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(note, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
