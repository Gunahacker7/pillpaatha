import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/app_store.dart';
import 'models.dart';
import 'screens/caregiver_screen.dart';
import 'screens/home_screen.dart';
import 'screens/medicines_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/schedule_screen.dart';
import 'services/notification_service.dart';
import 'services/schedule_service.dart';
import 'theme.dart';
import 'widgets/safety_line.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is OPTIONAL at runtime: until the project is configured
  // (see FIREBASE-SETUP.md) initialisation fails, and the app runs
  // end-to-end on the clearly-labelled sample schedule instead.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  // App Check: AI Logic enforces App Check, so Gemini calls are
  // rejected without a valid token. This is a sideloaded hackathon
  // build (not on the Play Store), so Play Integrity cannot attest
  // it — use the DEBUG provider here and register the token shown in
  // the app (Scan screen / Profile) in the Firebase console.
  // FOR A PLAY STORE RELEASE: swap AndroidProvider.debug below for
  // AndroidProvider.playIntegrity.
  if (firebaseReady) {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidDebugProvider(),
        providerApple: const AppleDebugProvider(),
      );
    } catch (_) {
      // Never block startup on App Check; generation will surface
      // any token problem and offer the labelled sample instead.
    }
  }

  final store = AppStore(LocalScheduleRepository());
  await store.load();

  final notifications = NotificationService(
    onAction: (itemId, action) {
      final item = store.schedule?.items
          .where((i) => i.id == itemId)
          .firstOrNull;
      if (item == null) return;
      if (action == 'snoozed') {
        store.markSnoozed(item);
      } else {
        store.markStatus(
          item,
          action == 'taken' ? DoseStatus.taken : DoseStatus.skipped,
        );
      }
    },
  );
  // Snoozed doses get a one-off reminder 15 minutes later.
  store.snoozeReminderHook = (item) => notifications.scheduleSnooze(item);
  // Reminders speak the app's one language.
  notifications.language = store.language;
  try {
    await notifications.init();
    final items = store.schedule?.items;
    if (items != null) await notifications.scheduleAll(items);
  } catch (_) {
    // Reminders are best-effort on Day 1; in-app Taken/Skip always works.
  }

  // Keep reminders in step with the schedule — and with the
  // language, so a language switch re-writes pending reminders.
  store.addListener(() {
    notifications.language = store.language;
    final items = store.schedule?.items;
    if (items != null) {
      notifications.scheduleAll(items);
    } else {
      notifications.cancelAll();
    }
  });

  runApp(
    PillPaathaApp(
      store: store,
      scheduleService: createScheduleService(firebaseReady: firebaseReady),
      firebaseReady: firebaseReady,
    ),
  );
}

class PillPaathaApp extends StatelessWidget {
  const PillPaathaApp({
    super.key,
    required this.store,
    required this.scheduleService,
    required this.firebaseReady,
  });

  final AppStore store;
  final ScheduleService scheduleService;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillPaatha',
      debugShowCheckedModeBanner: false,
      theme: PillTheme.light(),
      home: HomeShell(
        store: store,
        scheduleService: scheduleService,
        firebaseReady: firebaseReady,
      ),
    );
  }
}

/// V2 five-tab shell (boards): Home · Schedule · Medicines ·
/// Reports · Profile. Scan is a pushed route from Home/Medicines,
/// so its flow (and its onScheduleReady jump to Schedule) works
/// exactly as before. The safety line sits permanently above the
/// tab bar, so it is on every screen (MVP 5).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.store,
    required this.scheduleService,
    required this.firebaseReady,
  });

  final AppStore store;
  final ScheduleService scheduleService;
  final bool firebaseReady;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  AppStore get store => widget.store;

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: Text(
              store.tr(
                'Scan Prescription',
                'மருத்துவ சீட்டை ஸ்கேன் செய்யவும்',
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ScanScreen(
                  store: store,
                  scheduleService: widget.scheduleService,
                  firebaseReady: widget.firebaseReady,
                  onScheduleReady: () {
                    Navigator.of(routeContext).pop();
                    setState(() => _tab = 1);
                  },
                ),
              ),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) =>
                    SafetyLine(language: store.language),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        store: store,
        onOpenTab: (i) => setState(() => _tab = i),
        onScan: _openScan,
      ),
      ScheduleScreen(store: store),
      MedicinesScreen(store: store, onScan: _openScan),
      ReportsScreen(store: store),
      ProfileScreen(store: store, firebaseReady: widget.firebaseReady),
    ];
    // Listens to the store so a language switch re-renders the
    // whole shell (tabs, safety line) at once.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final lang = store.language;
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _tab, children: screens),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafetyLine(language: lang),
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: lang.pick('Home', 'முகப்பு'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.schedule_outlined),
                    selectedIcon: const Icon(Icons.schedule),
                    label: lang.pick('Schedule', 'அட்டவணை'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.medication_outlined),
                    selectedIcon: const Icon(Icons.medication),
                    label: lang.pick('Medicines', 'மருந்துகள்'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.bar_chart_outlined),
                    selectedIcon: const Icon(Icons.bar_chart),
                    label: lang.pick('Reports', 'அறிக்கைகள்'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: lang.pick('Profile', 'சுயவிவரம்'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
