import 'package:expense_tracker_app/core/services/demo_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoDataGenerator Pure Tests', () {
    final list = DemoDataGenerator.generate();

    test('Generates expected transaction counts', () {
      expect(list.isNotEmpty, isTrue);
      // August (31) + September (31) + October (8) = 70 total
      expect(list.length, 70);

      final aug = list.where((t) => t.date.startsWith('2026-08')).toList();
      final sep = list.where((t) => t.date.startsWith('2026-09')).toList();
      final oct = list.where((t) => t.date.startsWith('2026-10')).toList();

      expect(aug.length, 31);
      expect(sep.length, 31);
      expect(oct.length, 8);
    });

    test('Invariant: No transaction date is after 2026-10-20', () {
      const maxDate = '2026-10-20';
      for (final tx in list) {
        expect(
          tx.date.compareTo(maxDate) <= 0,
          isTrue,
          reason: 'Transaction ${tx.id} has date ${tx.date} which is after $maxDate',
        );
      }
    });

    test('Invariant: All amounts are strictly positive (> 0)', () {
      for (final tx in list) {
        expect(
          tx.amount > 0,
          isTrue,
          reason: 'Transaction ${tx.id} has invalid amount ${tx.amount}',
        );
      }
    });

    test('Date format strictly adheres to YYYY-MM-DD', () {
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      for (final tx in list) {
        expect(
          dateRegex.hasMatch(tx.date),
          isTrue,
          reason: 'Transaction ${tx.id} date ${tx.date} does not match YYYY-MM-DD',
        );
      }
    });

    test('All generated IDs are unique, non-empty, and deterministic', () {
      final ids = <String>{};
      for (final tx in list) {
        expect(tx.id.isNotEmpty, isTrue);
        expect(tx.id.startsWith('demo_'), isTrue);
        expect(
          ids.contains(tx.id),
          isFalse,
          reason: 'Duplicate ID detected: ${tx.id}',
        );
        ids.add(tx.id);
      }
      expect(ids.length, list.length);

      // Verify determinism across multiple runs
      final secondRun = DemoDataGenerator.generate();
      for (var i = 0; i < list.length; i++) {
        expect(list[i].id, secondRun[i].id);
        expect(list[i].amount, secondRun[i].amount);
        expect(list[i].date, secondRun[i].date);
        expect(list[i].categoryName, secondRun[i].categoryName);
      }
    });

    test('Every transaction has isDemo == true', () {
      for (final tx in list) {
        expect(tx.isDemo, isTrue);
        final map = tx.toMap(categoryId: 'cat_123');
        expect(map['isDemo'], isTrue);
        expect(map['amount'], tx.amount);
        expect(map['category_id'], 'cat_123');
      }
    });

    test('Verifies income records in Aug and Sep and no income in Oct', () {
      final incomes = list.where((t) => t.isIncome).toList();
      expect(incomes.length, 4); // Aug salary, Aug freelance, Sep salary, Sep freelance

      final augSalary = incomes.firstWhere((t) => t.id == 'demo_2026-08-01_salary');
      expect(augSalary.amount, 60000.0);
      expect(augSalary.categoryName, 'Salary');

      final augFreelance = incomes.firstWhere((t) => t.id == 'demo_2026-08-15_freelance');
      expect(augFreelance.amount, 12000.0);

      final sepSalary = incomes.firstWhere((t) => t.id == 'demo_2026-09-01_salary');
      expect(sepSalary.amount, 60000.0);

      final sepFreelance = incomes.firstWhere((t) => t.id == 'demo_2026-09-18_freelance');
      expect(sepFreelance.amount, 8000.0);

      final octIncomes = list.where((t) => t.isIncome && t.date.startsWith('2026-10')).toList();
      expect(octIncomes.isEmpty, isTrue);
    });

    test('Verifies recurring bills exist across all 3 months with correct amounts', () {
      // Rent: 12000 on 3rd of Aug, Sep, Oct
      final rents = list.where((t) => t.categoryName == 'Rent & Housing').toList();
      expect(rents.length, 3);
      for (final r in rents) {
        expect(r.amount, 12000.0);
        expect(r.date.endsWith('-03'), isTrue);
      }

      // Electricity: 1800 (Aug), 2100 (Sep), 2500 (Oct) on the 5th
      final elecAug = list.firstWhere((t) => t.id == 'demo_2026-08-05_electricity');
      final elecSep = list.firstWhere((t) => t.id == 'demo_2026-09-05_electricity');
      final elecOct = list.firstWhere((t) => t.id == 'demo_2026-10-05_electricity');
      expect(elecAug.amount, 1800.0);
      expect(elecSep.amount, 2100.0);
      expect(elecOct.amount, 2500.0);

      // Internet: 1000 (Aug), 1000 (Sep), 1050 (Oct) on the 10th
      final netAug = list.firstWhere((t) => t.id == 'demo_2026-08-10_internet');
      final netSep = list.firstWhere((t) => t.id == 'demo_2026-09-10_internet');
      final netOct = list.firstWhere((t) => t.id == 'demo_2026-10-10_internet');
      expect(netAug.amount, 1000.0);
      expect(netSep.amount, 1000.0);
      expect(netOct.amount, 1050.0);

      // Mobile: 300 (Aug), 300 (Sep), 350 (Oct) on the 12th
      final mobAug = list.firstWhere((t) => t.id == 'demo_2026-08-12_mobile');
      final mobSep = list.firstWhere((t) => t.id == 'demo_2026-09-12_mobile');
      final mobOct = list.firstWhere((t) => t.id == 'demo_2026-10-12_mobile');
      expect(mobAug.amount, 300.0);
      expect(mobSep.amount, 300.0);
      expect(mobOct.amount, 350.0);
    });

    test('Verifies shopping transactions and October anomaly', () {
      final tshirt = list.firstWhere((t) => t.id == 'demo_2026-08-20_shopping_tshirt');
      final shoes = list.firstWhere((t) => t.id == 'demo_2026-09-22_shopping_shoes');
      final headphones = list.firstWhere((t) => t.id == 'demo_2026-10-15_shopping_headphones');

      expect(tshirt.amount, 1500.0);
      expect(shoes.amount, 1800.0);
      expect(headphones.amount, 9500.0); // Anomaly spike
      expect(headphones.date, '2026-10-15');
    });

    test('Verifies October contains only the specified items', () {
      final oct = list.where((t) => t.date.startsWith('2026-10')).toList();
      expect(oct.length, 8);

      final rent = oct.where((t) => t.categoryName == 'Rent & Housing');
      final bills = oct.where((t) => t.categoryName == 'Bills & Utilities');
      final shopping = oct.where((t) => t.categoryName == 'Shopping');
      final food = oct.where((t) => t.categoryName == 'Food & Dining');

      expect(rent.length, 1);
      expect(bills.length, 3); // Electricity, Internet, Mobile
      expect(shopping.length, 1); // Headphones
      expect(food.length, 3); // 3 small food expenses
    });
  });
}
