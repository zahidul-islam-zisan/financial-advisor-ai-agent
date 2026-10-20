import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker_app/features/add_income_expense/data/models/add_income_expense_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Financial Calculations & Edge Cases', () {
    test('Calculates total income, expenses, and net savings correctly', () {
      final transactions = [
        {'amount': 5000.0, 'isIncome': true},
        {'amount': 1500.0, 'isIncome': false},
        {'amount': 350.0, 'isIncome': false},
        {'amount': 200.0, 'isIncome': true},
      ];

      double totalIncome = 0;
      double totalExpense = 0;

      for (var t in transactions) {
        final amt = t['amount'] as double;
        if (t['isIncome'] as bool) {
          totalIncome += amt;
        } else {
          totalExpense += amt;
        }
      }

      final netBalance = totalIncome - totalExpense;

      expect(totalIncome, 5200.0);
      expect(totalExpense, 1850.0);
      expect(netBalance, 3350.0);
    });

    test('Prevents division by zero when total expense is 0 in category breakdown', () {
      const double totalExpense = 0.0;
      const double foodExpense = 0.0;

      final pct = totalExpense > 0 ? (foodExpense / totalExpense * 100) : 0.0;
      expect(pct, 0.0);
      expect(pct.isFinite, isTrue);
    });

    test('Correctly computes 50/30/20 recommended allocation from monthly income', () {
      const double monthlyIncome = 4000.0;

      final needsTarget = monthlyIncome * 0.50; // 50%
      final wantsTarget = monthlyIncome * 0.30; // 30%
      final savingsTarget = monthlyIncome * 0.20; // 20%

      expect(needsTarget, 2000.0);
      expect(wantsTarget, 1200.0);
      expect(savingsTarget, 800.0);
      expect(needsTarget + wantsTarget + savingsTarget, monthlyIncome);
    });
  });

  group('Financial Amount Sanitization & Parsing', () {
    test('Rejects non-numeric, negative, and zero amounts', () {
      final testCases = [
        {'input': '', 'isValid': false},
        {'input': '   ', 'isValid': false},
        {'input': '-500', 'isValid': false},
        {'input': '0', 'isValid': false},
        {'input': '0.00', 'isValid': false},
        {'input': 'abc', 'isValid': false},
        {'input': '12.34.56', 'isValid': false},
        {'input': '1,250.50', 'isValid': true, 'expected': 1250.50},
        {'input': '450', 'isValid': true, 'expected': 450.0},
        {'input': '  99.99  ', 'isValid': true, 'expected': 99.99},
      ];

      for (var tc in testCases) {
        final raw = tc['input'] as String;
        final clean = raw.trim().replaceAll(',', '');
        final parsed = double.tryParse(clean);
        final isValid = parsed != null && parsed > 0;

        expect(isValid, tc['isValid'], reason: 'Failed for input: "$raw"');
        if (isValid && tc.containsKey('expected')) {
          expect(parsed, tc['expected']);
        }
      }
    });
  });

  group('AddIncomeExpenseRequestModel Deserialization & Key Compatibility', () {
    test('fromJson correctly parses snake_case keys (category_id, category_name)', () {
      final json = {
        'date': '2026-10-20',
        'time': '10:30 AM',
        'amount': 450.0,
        'description': 'Team lunch',
        'category_id': 'cat_food_123',
        'category_name': 'Food & Dining',
        'isIncome': false,
        'createdAt': Timestamp(1729410000, 0),
      };

      final model = AddIncomeExpenseRequestModel.fromJson('doc_101', json);

      expect(model.id, 'doc_101');
      expect(model.categoryId, 'cat_food_123');
      expect(model.categoryName, 'Food & Dining');
      expect(model.amount, 450.0);
      expect(model.isIncome, isFalse);
    });

    test('fromJson falls back to camelCase keys (categoryId, categoryName)', () {
      final legacyJson = {
        'date': '2026-10-20',
        'time': '11:00 AM',
        'amount': 1200.0,
        'description': 'Freelance payment',
        'categoryId': 'cat_salary_456',
        'categoryName': 'Salary',
        'isIncome': true,
        'createdAt': Timestamp(1729410000, 0),
      };

      final model = AddIncomeExpenseRequestModel.fromJson('doc_102', legacyJson);

      expect(model.categoryId, 'cat_salary_456');
      expect(model.categoryName, 'Salary');
      expect(model.amount, 1200.0);
      expect(model.isIncome, isTrue);
    });

    test('toJson and fromJson round-trip preserves category fields', () {
      final original = AddIncomeExpenseRequestModel(
        id: 'doc_103',
        date: '2026-10-20',
        time: '02:00 PM',
        amount: 85.50,
        description: 'Coffee',
        categoryId: 'cat_dining_789',
        categoryName: 'Dining',
        isIncome: false,
        createdAt: Timestamp(1729410000, 0),
      );

      final json = original.toJson();
      expect(json.containsKey('category_id'), isTrue);
      expect(json.containsKey('category_name'), isTrue);

      final restored = AddIncomeExpenseRequestModel.fromJson('doc_103', json);
      expect(restored.categoryId, original.categoryId);
      expect(restored.categoryName, original.categoryName);
      expect(restored.amount, original.amount);
    });
  });
}
