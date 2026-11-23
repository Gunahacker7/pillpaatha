import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpaatha/data/app_store.dart';
import 'package:pillpaatha/l10n.dart';
import 'package:pillpaatha/main.dart';
import 'package:pillpaatha/models.dart';
import 'package:pillpaatha/screens/medicines_screen.dart';
import 'package:pillpaatha/services/schedule_service.dart';
import 'package:pillpaatha/theme.dart';
import 'package:pillpaatha/widgets/safety_line.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Finds a bottom-nav label (Home also carries quick-action cards
/// with some of the same words, so scope to the NavigationBar).
Finder navLabel(String text) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(text),
    );

/// The shell's safety line specifically — Profile's About card
/// quotes the same sentence, so unscoped text finds it twice there.
Finder safetyText(String text) => find.descendant(
      of: find.byType(SafetyLine),
      matching: find.textContaining(text),
    );

Future<AppStore> _loadedStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(InMemoryScheduleRepository());
  await store.load();
  return store;
}

Widget _app(AppStore store) => PillPaathaApp(
      store: store,
      scheduleService: SampleScheduleService(),
      firebaseReady: false,
    );

void main() {
  testWidgets(
      'V2 shell: Tamil by default on Home, safety line on all five '
      'tabs, Profile language pill switches the whole UI to English',
      (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // Home is the first tab: teal header brand + today's card,
    // Tamil safety line, no English safety line.
    expect(find.text('PillPaatha'), findsOneWidget);
    expect(find.text('இன்றைய மருந்துகள்'), findsOneWidget);
    expect(safetyText(kSafetyLineTa), findsOneWidget);
    expect(safetyText(kSafetyLineEn), findsNothing);

    // Walk every tab; the safety line never leaves.
    for (final label in ['அட்டவணை', 'மருந்துகள்', 'அறிக்கைகள்', 'சுயவிவரம்']) {
      await tester.tap(navLabel(label));
      await tester.pumpAndSettle();
      expect(safetyText(kSafetyLineTa), findsOneWidget);
    }

    // Profile: the language pill switches the whole UI to English.
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(store.language, AppLanguage.en);
    expect(safetyText(kSafetyLineEn), findsOneWidget);
    expect(safetyText(kSafetyLineTa), findsNothing);
    expect(navLabel('Profile'), findsOneWidget);
    expect(navLabel('Home'), findsOneWidget);
  });

  testWidgets(
      'sample schedule: Home count + SAMPLE banner, Schedule dose '
      'actions work, Reports shows the recorded dose + 100% ring',
      (tester) async {
    final store = await _loadedStore();
    await store.setSchedule(
      await SampleScheduleService().generate(
        [MedicineEntry(id: 'm1', name: 'Metformin', strength: '500 mg')],
        'Metformin 500 mg',
      ),
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // Home: SAMPLE banner + today's count.
    expect(find.textContaining('மாதிரி அட்டவணை'), findsOneWidget);
    expect(find.text('1 மருந்துகள்'), findsOneWidget);

    // Schedule tab: the dose card with its Taken action.
    await tester.tap(navLabel('அட்டவணை'));
    await tester.pumpAndSettle();
    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('சாப்பிட்டது'), findsOneWidget);

    // Recording the dose updates the store…
    await tester.ensureVisible(find.text('சாப்பிட்டது'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('சாப்பிட்டது'));
    await tester.pumpAndSettle();
    expect(store.doseLog.single.status, EffectiveDoseStatus.taken);

    // …and Reports reflects it: Taken tile/log + 100% adherence ring.
    await tester.tap(navLabel('அறிக்கைகள்'));
    await tester.pumpAndSettle();
    expect(find.text('சாப்பிட்டது'), findsWidgets);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets(
      'Medicines tab lists schedule + entries and manual add works; '
      'Profile shows the emergency contact card', (tester) async {
    final store = await _loadedStore();
    await store.addMedicine(
      MedicineEntry(id: 'm1', name: 'Metformin', strength: '500 mg'),
    );
    await store.setSchedule(
      await SampleScheduleService().generate(
        [MedicineEntry(id: 'm1', name: 'Metformin', strength: '500 mg')],
        'Metformin 500 mg',
      ),
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(navLabel('மருந்துகள்'));
    await tester.pumpAndSettle();
    // The scheduled dose card sits at the top…
    expect(find.text('Metformin'), findsOneWidget);
    // …and the confirmed entry is further down the list.
    await tester.scrollUntilVisible(
      find.text('உங்கள் மருந்து பட்டியல்'),
      300,
      scrollable: find.descendant(
        of: find.byType(MedicinesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    // Both the scheduled dose and the confirmed entry now exist.
    expect(find.text('Metformin'), findsNWidgets(2));

    // Manual add via the V2 form.
    await tester.ensureVisible(find.text('மருந்து சேர்'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('மருந்து சேர்'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Amlodipine');
    await tester.tap(find.text('சேமி'));
    await tester.pumpAndSettle();
    expect(store.medicines.map((m) => m.name), contains('Amlodipine'));

    // Profile: emergency contact card with its Add action.
    await tester.tap(navLabel('சுயவிவரம்'));
    await tester.pumpAndSettle();
    expect(find.text('அவசர தொடர்பு'), findsOneWidget);
    expect(find.text('சேர்'), findsOneWidget);
  });

  testWidgets('Scan route opens from Home and generates a schedule',
      (tester) async {
    final store = await _loadedStore();
    await store.addMedicine(
      MedicineEntry(id: 'm1', name: 'Metformin', strength: '500 mg'),
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // Prominent Scan button on Home pushes the Scan screen.
    await tester.ensureVisible(find.text('மருத்துவ சீட்டை ஸ்கேன் செய்யவும்'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('மருத்துவ சீட்டை ஸ்கேன் செய்யவும்'));
    await tester.pumpAndSettle();
    expect(find.text('கேமரா'), findsOneWidget);
    expect(safetyText(kSafetyLineTa), findsOneWidget);

    // Generate (sample service, firebaseReady false): lands on the
    // Schedule tab with the new schedule.
    await tester.tap(find.text('மாதிரி அட்டவணை (டெமோ)'));
    await tester.pumpAndSettle();
    expect(store.schedule, isNotNull);
    expect(store.schedule!.isSample, isTrue);
    expect(find.text('Metformin'), findsOneWidget);
  });
}
