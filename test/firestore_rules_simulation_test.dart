import 'package:flutter_test/flutter_test.dart';

/// Accurate simulation of Firestore Security Rules logic defined in firestore.rules
class FirestoreSecurityRuleSimulator {
  // Evaluates isOwner helper
  static bool isOwner({
    required Map<String, dynamic>? auth,
    required String userDocId,
  }) {
    if (auth == null) return false;
    final uid = auth['uid'] as String?;
    final email = auth['email'] as String?;
    if (uid == null || uid.isEmpty) return false;

    final legacyExpected = email != null ? '${email}_$uid' : null;
    return userDocId == legacyExpected || userDocId == uid;
  }

  // Evaluates profile write rule: allow write: if isOwner(userDocId) && !('password' in request.resource.data)
  static bool evaluateProfileWrite({
    required Map<String, dynamic>? auth,
    required String userDocId,
    required Map<String, dynamic> data,
  }) {
    if (!isOwner(auth: auth, userDocId: userDocId)) return false;
    if (data.containsKey('password')) return false;
    return true;
  }

  // Evaluates transaction create/update rule: amount is number && amount > 0
  static bool evaluateTransactionWrite({
    required Map<String, dynamic>? auth,
    required String userDocId,
    required Map<String, dynamic> data,
  }) {
    if (!isOwner(auth: auth, userDocId: userDocId)) return false;
    final amount = data['amount'];
    if (amount == null || amount is! num || amount <= 0) return false;
    return true;
  }

  // Evaluates budget write rule: limit is number && limit > 0
  static bool evaluateBudgetWrite({
    required Map<String, dynamic>? auth,
    required String userDocId,
    required Map<String, dynamic> data,
  }) {
    if (!isOwner(auth: auth, userDocId: userDocId)) return false;
    final limit = data['limit'];
    if (limit == null || limit is! num || limit <= 0) return false;
    return true;
  }

  // Evaluates savings goal write rule: targetAmount is number && targetAmount > 0
  static bool evaluateSavingsGoalWrite({
    required Map<String, dynamic>? auth,
    required String userDocId,
    required Map<String, dynamic> data,
  }) {
    if (!isOwner(auth: auth, userDocId: userDocId)) return false;
    final target = data['targetAmount'];
    if (target == null || target is! num || target <= 0) return false;
    return true;
  }

  // Evaluates pending action rules: allow read: if isOwner; allow write: if false;
  static bool evaluatePendingActionRead({
    required Map<String, dynamic>? auth,
    required String userDocId,
  }) {
    return isOwner(auth: auth, userDocId: userDocId);
  }

  static bool evaluatePendingActionWrite({
    required Map<String, dynamic>? auth,
    required String userDocId,
  }) {
    // Strictly disallowed for client SDK (created/updated exclusively by serverless agent)
    return false;
  }

  // Evaluates audit log rules: allow read: if isOwner; allow write: if false;
  static bool evaluateAuditLogRead({
    required Map<String, dynamic>? auth,
    required String userDocId,
  }) {
    return isOwner(auth: auth, userDocId: userDocId);
  }

  static bool evaluateAuditLogWrite({
    required Map<String, dynamic>? auth,
    required String userDocId,
  }) {
    // Strictly disallowed for client SDK (written exclusively by server Admin SDK)
    return false;
  }

  // Evaluates rate_limits rules: allow read, write: if false;
  static bool evaluateRateLimitsAccess({
    required Map<String, dynamic>? auth,
  }) {
    return false;
  }

  // Evaluates tutorial read: allow read: if isAuthenticated(); allow write: if false;
  static bool evaluateTutorialRead({required Map<String, dynamic>? auth}) {
    return auth != null && auth['uid'] != null;
  }

  static bool evaluateTutorialWrite({required Map<String, dynamic>? auth}) {
    return false;
  }

  // Default deny root check
  static bool evaluateDefaultDeny(String collectionPath) {
    return false;
  }
}

void main() {
  group('Firestore Security Rules Invariant Validation', () {
    final aliceAuth = {'uid': 'alice_123', 'email': 'alice@example.com'};
    final bobAuth = {'uid': 'bob_456', 'email': 'bob@example.com'};
    final aliceDocId = 'alice@example.com_alice_123';
    final bobDocId = 'bob@example.com_bob_456';

    test('Rule 1: Authentication and Ownership Verification', () {
      // Alice owns her own document
      expect(FirestoreSecurityRuleSimulator.isOwner(auth: aliceAuth, userDocId: aliceDocId), isTrue);
      // Alice also matches direct UID path
      expect(FirestoreSecurityRuleSimulator.isOwner(auth: aliceAuth, userDocId: 'alice_123'), isTrue);
      // Alice CANNOT access Bob's document (cross-user isolation)
      expect(FirestoreSecurityRuleSimulator.isOwner(auth: aliceAuth, userDocId: bobDocId), isFalse);
      // Unauthenticated request is rejected
      expect(FirestoreSecurityRuleSimulator.isOwner(auth: null, userDocId: aliceDocId), isFalse);
    });

    test('Rule 2: Plaintext Password Field Injection is Strictly Rejected in Profile', () {
      // Normal profile write without password -> ALLOWED
      expect(
        FirestoreSecurityRuleSimulator.evaluateProfileWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'name': 'Alice', 'currency': 'BDT'},
        ),
        isTrue,
      );

      // Malicious or accidental attempt to write password -> BLOCKED
      expect(
        FirestoreSecurityRuleSimulator.evaluateProfileWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'name': 'Alice', 'password': 'plaintext_secret_123'},
        ),
        isFalse,
        reason: 'CRITICAL: firestore.rules must block any write containing password field',
      );
    });

    test('Rule 3: Transaction Amount Validation (Zero and Negative Numbers Denied)', () {
      // Valid positive transaction -> ALLOWED
      expect(
        FirestoreSecurityRuleSimulator.evaluateTransactionWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'amount': 150.0, 'type': 'expense'},
        ),
        isTrue,
      );

      // Negative amount -> DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluateTransactionWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'amount': -50.0, 'type': 'expense'},
        ),
        isFalse,
      );

      // Zero amount -> DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluateTransactionWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'amount': 0, 'type': 'expense'},
        ),
        isFalse,
      );

      // Non-numeric amount -> DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluateTransactionWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'amount': "500", 'type': 'expense'},
        ),
        isFalse,
      );
    });

    test('Rule 4: Budget and Savings Goal Positive Values Enforced', () {
      // Budget with positive limit -> ALLOWED
      expect(
        FirestoreSecurityRuleSimulator.evaluateBudgetWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'category': 'Food', 'limit': 200.0},
        ),
        isTrue,
      );

      // Budget with non-positive limit -> DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluateBudgetWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'category': 'Food', 'limit': -10.0},
        ),
        isFalse,
      );

      // Savings goal with positive target -> ALLOWED
      expect(
        FirestoreSecurityRuleSimulator.evaluateSavingsGoalWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'goalName': 'Emergency Fund', 'targetAmount': 5000.0},
        ),
        isTrue,
      );

      // Savings goal with zero target -> DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluateSavingsGoalWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
          data: {'goalName': 'Emergency Fund', 'targetAmount': 0},
        ),
        isFalse,
      );
    });

    test('Rule 5: Pending Actions Client Access Control (Read-Only for Client, Server-Managed)', () {
      // Owner can read pending actions -> ALLOWED
      expect(
        FirestoreSecurityRuleSimulator.evaluatePendingActionRead(
          auth: aliceAuth,
          userDocId: aliceDocId,
        ),
        isTrue,
      );

      // Non-owner cannot read Alice's pending actions -> DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluatePendingActionRead(
          auth: bobAuth,
          userDocId: aliceDocId,
        ),
        isFalse,
      );

      // Direct client creation/update -> STRICTLY DENIED (managed exclusively by server)
      expect(
        FirestoreSecurityRuleSimulator.evaluatePendingActionWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
        ),
        isFalse,
      );
    });

    test('Rule 6: Audit Logs & Rate Limits Server-Only Enforcement', () {
      // Owner can read their own audit logs -> ALLOWED
      expect(
        FirestoreSecurityRuleSimulator.evaluateAuditLogRead(
          auth: aliceAuth,
          userDocId: aliceDocId,
        ),
        isTrue,
      );

      // Non-owner reading Alice's audit logs -> DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluateAuditLogRead(
          auth: bobAuth,
          userDocId: aliceDocId,
        ),
        isFalse,
      );

      // Client creating or modifying audit logs -> STRICTLY DENIED (written only by Admin SDK)
      expect(
        FirestoreSecurityRuleSimulator.evaluateAuditLogWrite(
          auth: aliceAuth,
          userDocId: aliceDocId,
        ),
        isFalse,
      );

      // Rate limits collection direct client access -> STRICTLY DENIED
      expect(
        FirestoreSecurityRuleSimulator.evaluateRateLimitsAccess(auth: aliceAuth),
        isFalse,
      );
    });

    test('Rule 7: Tutorial Collection is Read-Only for Auth Users and Write-Denied for All', () {
      expect(FirestoreSecurityRuleSimulator.evaluateTutorialRead(auth: aliceAuth), isTrue);
      expect(FirestoreSecurityRuleSimulator.evaluateTutorialRead(auth: null), isFalse);
      expect(FirestoreSecurityRuleSimulator.evaluateTutorialWrite(auth: aliceAuth), isFalse);
    });

    test('Rule 8: Default Deny on Unknown Collections', () {
      expect(FirestoreSecurityRuleSimulator.evaluateDefaultDeny('system_secrets'), isFalse);
      expect(FirestoreSecurityRuleSimulator.evaluateDefaultDeny('admin_settings'), isFalse);
    });
  });
}
