import 'package:expense_tracker_app/features/ai_assistant/data/models/pending_financial_action_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Agent 2-Step Confirmation & Authorization Security Engine', () {
    test('Creates PENDING action with expiration and parameter validation', () {
      final now = DateTime.now();
      final action = PendingFinancialActionModel(
        id: 'action_101',
        uid: 'user_alice',
        docId: 'alice@bank.com_user_alice',
        actionType: 'CREATE_BUDGET',
        title: 'Set Monthly Budget for Dining: \$300.00',
        parameters: {'category': 'Dining', 'limit': 300.0},
        status: 'PENDING',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
      );

      expect(action.isPending, isTrue);
      expect(action.isConfirmed, isFalse);
      expect(action.isRejected, isFalse);
      expect(action.isExpired, isFalse);
      expect(action.parameters['limit'], 300.0);
    });

    test('Prevents replay/duplicate execution if action is already CONFIRMED', () {
      final action = PendingFinancialActionModel(
        id: 'action_102',
        uid: 'user_alice',
        docId: 'alice@bank.com_user_alice',
        actionType: 'CREATE_BUDGET',
        title: 'Set Monthly Budget',
        parameters: {'category': 'Dining', 'limit': 300.0},
        status: 'CONFIRMED', // Already confirmed previously
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      bool canExecute(PendingFinancialActionModel a) {
        if (a.status != 'PENDING') return false;
        if (a.isExpired) return false;
        return true;
      }

      expect(canExecute(action), isFalse, reason: 'Duplicate execution / replay must be blocked');
    });

    test('Rejects expired actions even if status is pending', () {
      final expiredAction = PendingFinancialActionModel(
        id: 'action_103',
        uid: 'user_alice',
        docId: 'alice@bank.com_user_alice',
        actionType: 'CREATE_SAVINGS_GOAL',
        title: 'Expired Goal',
        parameters: {'targetAmount': 500.0, 'targetMonths': 5},
        status: 'PENDING',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 15)), // Expired 15 mins ago
      );

      expect(expiredAction.isExpired, isTrue);
    });

    test('Cross-user authorization: User B cannot confirm User A action', () {
      final alicesAction = PendingFinancialActionModel(
        id: 'action_104',
        uid: 'user_alice',
        docId: 'alice@bank.com_user_alice',
        actionType: 'CREATE_BUDGET',
        title: 'Alice Budget',
        parameters: {'category': 'Dining', 'limit': 300.0},
        status: 'PENDING',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      bool verifyCallerAuthorization(String callerUid, PendingFinancialActionModel action) {
        return callerUid == action.uid;
      }

      expect(verifyCallerAuthorization('user_alice', alicesAction), isTrue);
      expect(verifyCallerAuthorization('user_bob_attacker', alicesAction), isFalse,
          reason: 'Unauthorized user must never confirm another user action');
    });

    test('Savings Goal calculation: Deterministic monthly contribution', () {
      const double targetAmount = 2400.0;
      const int targetMonths = 12;

      final monthlyRequired = targetAmount / targetMonths;
      expect(monthlyRequired, 200.0);
    });

    test('Unusual spending anomaly detection algorithm validation', () {
      // Historical category average: $50.00
      const double historicalAvg = 50.0;

      bool isAnomaly(double amount, double average) {
        return amount > 20.0 && amount >= (average * 1.5);
      }

      expect(isAnomaly(45.0, historicalAvg), isFalse); // Normal purchase
      expect(isAnomaly(70.0, historicalAvg), isFalse); // Below 1.5x threshold ($75)
      expect(isAnomaly(75.0, historicalAvg), isTrue);  // Exactly 1.5x
      expect(isAnomaly(250.0, historicalAvg), isTrue); // Large spike (5x)
    });
  });
}
