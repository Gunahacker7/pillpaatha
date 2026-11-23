import 'package:flutter_test/flutter_test.dart';
import 'package:pillpaatha/data/app_store.dart';
import 'package:pillpaatha/main.dart';
import 'package:pillpaatha/models.dart';
import 'package:pillpaatha/services/schedule_service.dart';
import 'package:pillpaatha/theme.dart';

void main() {
  testWidgets('shell shows all tabs and the safety line on every screen',
      (tester) async {
    final store = AppStore(InMemoryScheduleRepository());
    await store.load();
    await tester.pumpWidget(
      PillPaathaApp(
        store: store,
        scheduleService: SampleScheduleService(),
        firebaseReady: false,
      ),
    );
    await tester.pumpAndSettle();

    // Scan tab + safety line visible.
    expect(find.text('Camera'), findsOneWidget);
    expect(find.textContaining(kSafetyLineEn), findsOneWidget);

    // Schedule tab — safety line still visible.
    await tester.tap(find.text('Today · இன்று'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No schedule yet'), findsOneWidget);
    expect(find.textContaining(kSafetyLineEn), findsOneWidget);

    // Caregiver tab — safety line still visible.
    await tester.tap(find.text('Caregiver · பராமரிப்பு'));
    await tester.pumpAndSettle();
    expect(find.textContaining(kSafetyLineEn), findsOneWidget);
  });

  testWidgets('sample schedule renders with SAMPLE banner and dose actions',
      (tester) async {
    final store = AppStore(InMemoryScheduleRepository());
    await store.load();
    await store.setSchedule(
      await SampleScheduleService().generate(
        [MedicineEntry(id: 'm1', name: 'Metformin', strength: '500 mg')],
        'Metformin 500 mg',
      ),
    );
    await tester.pumpWidget(
      PillPaathaApp(
        store: store,
        scheduleService: SampleScheduleService(),
        firebaseReady: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today · இன்று'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SAMPLE schedule'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);

    // Recording a dose updates the caregiver summary.
    await tester.ensureVisible(find.text('Taken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caregiver · பராமரிப்பு'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Taken · சாப்பிட்டாச்சு'), findsWidgets);
  });
}
