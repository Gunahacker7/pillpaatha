import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/app_store.dart';
import 'models.dart';
import 'screens/caregiver_screen.dart';
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

  final store = AppStore(LocalScheduleRepository());
  await store.load();

  final notifications = NotificationService(
    onAction: (itemId, action) {
      final item = store.schedule?.items
          .where((i) => i.id == itemId)
          .firstOrNull;
      if (item == null) return;
      store.markStatus(
        item,
        action == 'taken' ? DoseStatus.taken : DoseStatus.skipped,
      );
    },
  );
  try {
    await notifications.init();
    final items = store.schedule?.items;
    if (items != null) await notifications.scheduleAll(items);
  } catch (_) {
    // Reminders are best-effort on Day 1; in-app Taken/Skip always works.
  }

  // Keep reminders in step with the schedule.
  store.addListener(() {
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

/// Three-tab shell: Scan · Schedule · Caregiver. The safety line sits
/// permanently above the tab bar, so it is on every screen (MVP 5).
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      ScanScreen(
        store: widget.store,
        scheduleService: widget.scheduleService,
        firebaseReady: widget.firebaseReady,
        onScheduleReady: () => setState(() => _tab = 1),
      ),
      ScheduleScreen(store: widget.store),
      CaregiverScreen(store: widget.store),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.medication_liquid, color: PillTheme.primary),
            SizedBox(width: 8),
            Text('PillPaatha · பில் பாத்தா'),
          ],
        ),
      ),
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SafetyLine(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner),
                label: 'Scan · ஸ்கேன்',
              ),
              NavigationDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule),
                label: 'Today · இன்று',
              ),
              NavigationDestination(
                icon: Icon(Icons.family_restroom_outlined),
                selectedIcon: Icon(Icons.family_restroom),
                label: 'Caregiver · பராமரிப்பு',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
