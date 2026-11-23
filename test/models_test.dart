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
}
