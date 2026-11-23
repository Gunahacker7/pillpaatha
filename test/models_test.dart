import 'package:flutter_test/flutter_test.dart';
import 'package:pillpaatha/data/app_store.dart';
import 'package:pillpaatha/models.dart';
import 'package:pillpaatha/services/ocr_service.dart';
import 'package:pillpaatha/services/schedule_service.dart';

void main() {
  group('OCR line parser', () {
    test('extracts medicine name + strength from strip text', () {
      final meds = OcrService.parseMedicineLines(
        'Metformin 500 mg\n'
        'Strip of 10 Tablets\n'
        'Mfg Date 01/2026\n'
        'Amlodipine 5 mg Tablets',
      );
      expect(meds.length, 2);
      expect(meds.first.name, contains('Metformin'));
      expect(meds.first.strength, '500 mg');
      expect(meds.last.name, contains('Amlodipine'));
    });

    test('ignores lines without strength or dosage form', () {
      final meds = OcrService.parseMedicineLines(
        'Apollo Pharmacy\nChennai\nBill No 12345',
      );
      expect(meds, isEmpty);
    });

    test('numbered prescription: strips list numbers, skips dose lines',
        () {
      final meds = OcrService.parseMedicineLines(
        '1. Metformin 500 mg\n'
        '1 tablet - Morning & Night - After food\n'
        '2. Metoprolol 25 mg\n'
        '1 tablet - Morning - After food\n'
        '3. Amlodipine 5 mg\n'
        '1 tablet - Morning - After food\n'
        '4. Atorvastatin 10 mg\n'
        '1 tablet - Night - After food\n'
        '5. Paracetamol 650 mg\n'
        '1 tablet - Only when fever (SOS)',
      );
      expect(meds.length, 5);
      expect(
        meds.map((m) => m.name).toList(),
        ['Metformin', 'Metoprolol', 'Amlodipine', 'Atorvastatin', 'Paracetamol'],
      );
      expect(
        meds.map((m) => m.strength).toList(),
        ['500 mg', '25 mg', '5 mg', '10 mg', '650 mg'],
      );
    });
  });

  group('Sample schedule service', () {
    test('flags output as sample and carries user medicine names', () async {
      final schedule = await SampleScheduleService().generate(
        [MedicineEntry(id: 'm1', name: 'Metformin', strength: '500 mg')],
        'Metformin 500 mg',
      );
      expect(schedule.isSample, isTrue);
      expect(schedule.items.single.medicineName, 'Metformin');
      // Sample dose text must never look like real medical instruction.
      expect(schedule.items.single.dose, contains('sample'));
    });
  });

  group('Look-alike flags', () {
    ScheduleItem item(String id, String name) => ScheduleItem(
          id: id,
          medicineName: name,
          dose: '1 tablet',
          hour: 8,
          minute: 0,
          foodRelation: FoodRelation.afterFood,
          explanationEn: 'x',
          explanationTa: 'x',
        );

    test('flags Metformin vs Metoprolol, leaves others alone', () {
      final flagged = applyLookAlikeFlags([
        item('1', 'Metformin'),
        item('2', 'Metoprolol'),
        item('3', 'Vitamin D3'),
      ]);
      expect(flagged[0].caution, isTrue);
      expect(flagged[1].caution, isTrue);
      expect(flagged[2].caution, isFalse);
    });
  });

  group('AppStore dose status', () {
    test('taken / missed logic follows recorded status and clock', () async {
      final store = AppStore(InMemoryScheduleRepository());
      final dose = ScheduleItem(
        id: 'd1',
        medicineName: 'Metformin',
        dose: '1 tablet',
        hour: 8,
        minute: 0,
        foodRelation: FoodRelation.afterFood,
        explanationEn: 'x',
        explanationTa: 'x',
      );
      final after = DateTime(2026, 11, 23, 9, 0); // 9 AM, dose was 8 AM
      expect(store.isMissed(dose, after), isTrue);
      await store.markStatus(dose, DoseStatus.taken, date: after);
      expect(store.statusFor(dose, after), DoseStatus.taken);
      expect(store.isMissed(dose, after), isFalse);
    });

    test('markStatus appends to the dose log', () async {
      final store = AppStore(InMemoryScheduleRepository());
      final dose = ScheduleItem(
        id: 'd1',
        medicineName: 'Metformin',
        dose: '1 tablet',
        hour: 8,
        minute: 30,
        foodRelation: FoodRelation.afterFood,
        explanationEn: 'x',
        explanationTa: 'x',
      );
      final day = DateTime(2026, 11, 23, 9, 0);
      await store.markStatus(dose, DoseStatus.taken, date: day);
      await store.markSnoozed(dose, date: day);
      expect(store.doseLog.length, 2);
      expect(store.doseLog.first.medicineName, 'Metformin');
      expect(store.doseLog.first.status, EffectiveDoseStatus.taken);
      expect(store.doseLog.first.scheduledIso,
          DateTime(2026, 11, 23, 8, 30).toIso8601String());
      expect(store.doseLog.last.status, EffectiveDoseStatus.snoozed);
    });

    test('dose log is capped at 500 entries, newest kept', () async {
      final store = AppStore(InMemoryScheduleRepository());
      final dose = ScheduleItem(
        id: 'd1',
        medicineName: 'Metformin',
        dose: '1 tablet',
        hour: 8,
        minute: 0,
        foodRelation: FoodRelation.afterFood,
        explanationEn: 'x',
        explanationTa: 'x',
      );
      final day = DateTime(2026, 11, 23);
      for (var i = 0; i < AppStore.maxDoseLogEntries + 5; i++) {
        await store.markStatus(dose, DoseStatus.taken, date: day);
      }
      expect(store.doseLog.length, AppStore.maxDoseLogEntries);
    });

    test('updateScheduleItem changes time and dose text', () async {
      final store = AppStore(InMemoryScheduleRepository());
      final dose = ScheduleItem(
        id: 'd1',
        medicineName: 'Metformin',
        dose: '1 tablet',
        hour: 8,
        minute: 0,
        foodRelation: FoodRelation.afterFood,
        explanationEn: 'x',
        explanationTa: 'x',
      );
      await store.setSchedule(GeneratedSchedule(
        items: [dose],
        isSample: false,
        generatedAt: DateTime(2026, 11, 23),
      ));
      await store.updateScheduleItem(
        dose.copyWith(hour: 21, minute: 15, dose: '2 tablets'),
      );
      final updated = store.schedule!.items.single;
      expect(updated.hour, 21);
      expect(updated.minute, 15);
      expect(updated.dose, '2 tablets');
      expect(updated.timeLabel, '9:15 PM');
    });

    test('emergency contact saves and loads through the repository',
        () async {
      final repo = InMemoryScheduleRepository();
      final store = AppStore(repo);
      expect(store.emergencyContact, isNull);
      await store.setEmergencyContact(
        EmergencyContact(name: 'Son', phone: '9876543210'),
      );
      expect(store.emergencyContact?.name, 'Son');

      final reloaded = AppStore(repo);
      await reloaded.load();
      expect(reloaded.emergencyContact?.phone, '9876543210');
    });

    test('schedule JSON round-trips', () {
      final s = GeneratedSchedule(
        items: [
          ScheduleItem(
            id: 'd1',
            medicineName: 'Amlodipine',
            dose: '1 tablet',
            hour: 21,
            minute: 30,
            foodRelation: FoodRelation.beforeFood,
            explanationEn: 'en',
            explanationTa: 'ta',
            caution: true,
            cautionNote: 'note',
          ),
        ],
        isSample: false,
        generatedAt: DateTime(2026, 11, 23),
      );
      final back = GeneratedSchedule.fromJson(s.toJson());
      expect(back.items.single.medicineName, 'Amlodipine');
      expect(back.items.single.foodRelation, FoodRelation.beforeFood);
      expect(back.items.single.timeLabel, '9:30 PM');
      expect(back.isSample, isFalse);
    });
  });

  group('effectiveStatus', () {
    ScheduleItem doseAt(int hour, int minute) => ScheduleItem(
          id: 'd1',
          medicineName: 'Metformin',
          dose: '1 tablet',
          hour: hour,
          minute: minute,
          foodRelation: FoodRelation.afterFood,
          explanationEn: 'x',
          explanationTa: 'x',
        );

    test('stored status always wins over the clock', () {
      final now = DateTime(2026, 11, 23, 18, 0); // 6 PM
      // Dose was 8 AM (past) but recorded taken → taken, not missed.
      expect(
        effectiveStatus(doseAt(8, 0), DoseStatus.taken, now),
        EffectiveDoseStatus.taken,
      );
      // Dose is 9 PM (future) but recorded skipped → skipped.
      expect(
        effectiveStatus(doseAt(21, 0), DoseStatus.skipped, now),
        EffectiveDoseStatus.skipped,
      );
      // Snoozed stays snoozed even after its time passes.
      expect(
        effectiveStatus(doseAt(8, 0), DoseStatus.snoozed, now),
        EffectiveDoseStatus.snoozed,
      );
    });

    test('no stored status: past dose is missed, future dose is pending',
        () {
      final now = DateTime(2026, 11, 23, 9, 0); // 9 AM
      expect(
        effectiveStatus(doseAt(8, 0), null, now),
        EffectiveDoseStatus.missed,
      );
      expect(
        effectiveStatus(doseAt(21, 30), null, now),
        EffectiveDoseStatus.pending,
      );
    });

    test('store.effectiveStatusFor reads the stored status map', () async {
      final store = AppStore(InMemoryScheduleRepository());
      final dose = doseAt(8, 0);
      final now = DateTime(2026, 11, 23, 9, 0);
      expect(store.effectiveStatusFor(dose, now),
          EffectiveDoseStatus.missed);
      await store.markStatus(dose, DoseStatus.snoozed, date: now);
      expect(store.effectiveStatusFor(dose, now),
          EffectiveDoseStatus.snoozed);
    });
  });

  group('adherencePercent', () {
    DoseLogEntry entry(EffectiveDoseStatus status) => DoseLogEntry(
          itemId: 'd1',
          medicineName: 'Metformin',
          scheduledIso: '2026-11-23T08:00:00.000',
          status: status,
          actedIso: '2026-11-23T08:05:00.000',
        );

    test('taken / (taken + skipped + missed), snoozed ignored', () {
      final log = [
        entry(EffectiveDoseStatus.taken),
        entry(EffectiveDoseStatus.taken),
        entry(EffectiveDoseStatus.taken),
        entry(EffectiveDoseStatus.skipped),
        entry(EffectiveDoseStatus.missed),
        entry(EffectiveDoseStatus.snoozed),
        entry(EffectiveDoseStatus.snoozed),
      ];
      expect(adherencePercent(log), 60.0);
    });

    test('null when nothing measurable (empty or snoozed-only)', () {
      expect(adherencePercent([]), isNull);
      expect(
        adherencePercent([entry(EffectiveDoseStatus.snoozed)]),
        isNull,
      );
    });

    test('dose log JSON round-trips', () {
      final e = entry(EffectiveDoseStatus.taken);
      final back = DoseLogEntry.fromJson(e.toJson());
      expect(back.medicineName, 'Metformin');
      expect(back.status, EffectiveDoseStatus.taken);
      expect(back.scheduledAt, DateTime(2026, 11, 23, 8, 0));
    });
  });
}
