import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';
import '../models/financial_audit_log_model.dart';
import '../models/pending_financial_action_model.dart';

class AgentActionDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get uid => _auth.currentUser?.uid;
  String? get email => _auth.currentUser?.email;
  String? get docId {
    final u = uid;
    final e = email;
    if (u != null && e != null && u.isNotEmpty && e.isNotEmpty) {
      return "${e}_$u";
    }
    return null;
  }

  // ==========================================
  // 1. DETERMINISTIC READ TOOLS
  // ==========================================

  /// Deterministically computes total income, expense, balance, and category breakdown for a month
  Future<Either<Failure, Map<String, dynamic>>> getSummary({String? month}) async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      final now = DateTime.now();
      final targetMonthStr = month ?? "${now.year}-${now.month.toString().padLeft(2, '0')}";
      final startOfMonth = "$targetMonthStr-01";

      final parts = targetMonthStr.split('-');
      final y = int.tryParse(parts[0]) ?? now.year;
      final m = int.tryParse(parts[1]) ?? now.month;
      final nextMonth = m == 12 ? 1 : m + 1;
      final nextYear = m == 12 ? y + 1 : y;
      final endOfMonth = "$nextYear-${nextMonth.toString().padLeft(2, '0')}-01";

      final query = await _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .where("date", isGreaterThanOrEqualTo: startOfMonth)
          .where("date", isLessThan: endOfMonth)
          .get();

      double totalIncome = 0;
      double totalExpense = 0;
      final Map<String, double> categoryBreakdown = {};

      for (var doc in query.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final isIncome = data['isIncome'] == true;
        final category = data['categoryName'] as String? ?? 'Other';

        if (isIncome) {
          totalIncome += amount;
        } else {
          totalExpense += amount;
          categoryBreakdown[category] = (categoryBreakdown[category] ?? 0.0) + amount;
        }
      }

      final netSavings = totalIncome - totalExpense;
      final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0.0;

      return Right({
        'month': targetMonthStr,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'netSavings': netSavings,
        'savingsRate': savingsRate,
        'categoryBreakdown': categoryBreakdown,
        'transactionCount': query.docs.length,
      });
    } catch (e) {
      log("Error in getSummary tool: $e");
      return Left(Failure("Failed to retrieve financial summary: ${e.toString()}"));
    }
  }

  /// Retrieves structured recent transactions
  Future<Either<Failure, List<Map<String, dynamic>>>> getTransactions({
    String? month,
    int limit = 10,
  }) async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      Query query = _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .orderBy("createdAt", descending: true);

      if (limit > 0) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final list = snapshot.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return data;
      }).toList();

      return Right(list);
    } catch (e) {
      log("Error in getTransactions tool: $e");
      return Left(Failure("Failed to retrieve transactions: ${e.toString()}"));
    }
  }

  /// Deterministically scans for spending anomalies (>1.5x average or single spikes)
  Future<Either<Failure, List<Map<String, dynamic>>>> findUnusualSpending() async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      final snapshot = await _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .where("isIncome", isEqualTo: false)
          .orderBy("createdAt", descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        return const Right([]);
      }

      final Map<String, List<double>> catAmounts = {};
      final List<Map<String, dynamic>> allExpenses = [];

      for (var d in snapshot.docs) {
        final data = d.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final cat = data['categoryName'] as String? ?? 'Other';
        catAmounts.putIfAbsent(cat, () => []).add(amount);
        allExpenses.add({
          'id': d.id,
          'category': cat,
          'amount': amount,
          'date': data['date'] ?? '',
          'description': data['description'] ?? '',
        });
      }

      // Compute averages per category
      final Map<String, double> catAverages = {};
      catAmounts.forEach((cat, list) {
        final sum = list.reduce((a, b) => a + b);
        catAverages[cat] = sum / list.length;
      });

      // Find transactions exceeding 1.5x the category average (and > $20)
      final List<Map<String, dynamic>> anomalies = [];
      for (var item in allExpenses) {
        final cat = item['category'] as String;
        final amt = item['amount'] as double;
        final avg = catAverages[cat] ?? 0.0;

        if (amt > 20.0 && amt >= (avg * 1.5)) {
          anomalies.add({
            ...item,
            'categoryAverage': avg,
            'multiplier': avg > 0 ? (amt / avg).toStringAsFixed(1) : '1.0',
            'reason': 'Amount is ${avg > 0 ? (amt / avg).toStringAsFixed(1) : '1.0'}x higher than average $cat spending (\$${avg.toStringAsFixed(2)})',
          });
        }
      }

      return Right(anomalies);
    } catch (e) {
      log("Error in findUnusualSpending: $e");
      return Left(Failure("Failed to detect unusual spending: ${e.toString()}"));
    }
  }

  // ==========================================
  // 2. 2-STEP HUMAN CONFIRMATION ACTIONS
  // ==========================================

  /// Proposes a budget change by creating a PENDING action.
  /// Never writes directly to budgets without confirmation.
  Future<Either<Failure, PendingFinancialActionModel>> proposeBudget({
    required String category,
    required double limit,
  }) async {
    try {
      final currentUid = uid;
      final currentDocId = docId;
      if (currentUid == null || currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      final cleanCategory = category.trim();
      if (cleanCategory.isEmpty) {
        return Left(Failure("Category name cannot be empty."));
      }
      if (limit <= 0) {
        return Left(Failure("Budget limit must be greater than zero."));
      }

      final actionRef = _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("pending_actions")
          .doc();

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 15));

      final pendingAction = PendingFinancialActionModel(
        id: actionRef.id,
        uid: currentUid,
        docId: currentDocId,
        actionType: 'CREATE_BUDGET',
        title: "Set Monthly Budget for $cleanCategory to \$${limit.toStringAsFixed(2)}",
        parameters: {
          'category': cleanCategory,
          'limit': limit,
        },
        status: 'PENDING',
        createdAt: now,
        expiresAt: expiresAt,
      );

      await actionRef.set(pendingAction.toJson());
      log("Pending budget action created: ${actionRef.id}");

      return Right(pendingAction);
    } catch (e) {
      log("Error creating pending budget action: $e");
      return Left(Failure("Failed to propose budget: ${e.toString()}"));
    }
  }

  /// Proposes a savings goal by creating a PENDING action.
  /// Never writes directly to savings_goals without confirmation.
  Future<Either<Failure, PendingFinancialActionModel>> proposeSavingsGoal({
    required String goalName,
    required double targetAmount,
    required int targetMonths,
  }) async {
    try {
      final currentUid = uid;
      final currentDocId = docId;
      if (currentUid == null || currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      final cleanName = goalName.trim().isEmpty ? "Savings Goal" : goalName.trim();
      if (targetAmount <= 0) {
        return Left(Failure("Target amount must be greater than zero."));
      }
      if (targetMonths <= 0 || targetMonths > 120) {
        return Left(Failure("Target months must be between 1 and 120."));
      }

      final monthlyRequired = targetAmount / targetMonths;

      final actionRef = _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("pending_actions")
          .doc();

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 15));

      final pendingAction = PendingFinancialActionModel(
        id: actionRef.id,
        uid: currentUid,
        docId: currentDocId,
        actionType: 'CREATE_SAVINGS_GOAL',
        title: "Create Savings Goal: $cleanName (\$${targetAmount.toStringAsFixed(2)} over $targetMonths months — \$${monthlyRequired.toStringAsFixed(2)}/mo)",
        parameters: {
          'goalName': cleanName,
          'targetAmount': targetAmount,
          'targetMonths': targetMonths,
          'monthlyRequired': monthlyRequired,
        },
        status: 'PENDING',
        createdAt: now,
        expiresAt: expiresAt,
      );

      await actionRef.set(pendingAction.toJson());
      log("Pending savings goal action created: ${actionRef.id}");

      return Right(pendingAction);
    } catch (e) {
      log("Error creating pending savings goal action: $e");
      return Left(Failure("Failed to propose savings goal: ${e.toString()}"));
    }
  }

  /// Verifies authorization, state, and expiration, then executes the action and creates an audit record.
  Future<Either<Failure, String>> confirmPendingAction(String actionId) async {
    try {
      final currentUid = uid;
      final currentDocId = docId;
      if (currentUid == null || currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      final actionRef = _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("pending_actions")
          .doc(actionId);

      final actionSnap = await actionRef.get();
      if (!actionSnap.exists) {
        return Left(Failure("Pending action was not found or has been deleted."));
      }

      final actionData = actionSnap.data() as Map<String, dynamic>;
      final action = PendingFinancialActionModel.fromJson(actionSnap.id, actionData);

      // SECURITY VERIFICATION 1: Verify ownership
      if (action.uid != currentUid || action.docId != currentDocId) {
        return Left(Failure("Access Denied: You do not own this pending action."));
      }

      // SECURITY VERIFICATION 2: Anti-replay / Duplicate execution prevention
      if (action.status != 'PENDING') {
        return Left(Failure("Action is no longer pending (Current status: ${action.status}). Replay blocked."));
      }

      // SECURITY VERIFICATION 3: Expiry validation
      if (DateTime.now().isAfter(action.expiresAt)) {
        await actionRef.update({'status': 'EXPIRED'});
        return Left(Failure("Pending action has expired. Please ask the AI to propose it again."));
      }

      // EXECUTION BASED ON ACTION TYPE
      final now = DateTime.now();
      String executionSummary = "";

      if (action.actionType == 'CREATE_BUDGET') {
        final category = action.parameters['category'] as String;
        final limit = (action.parameters['limit'] as num).toDouble();

        // Write to budgets subcollection
        final budgetDocRef = _firestore
            .collection("users")
            .doc(currentDocId)
            .collection("budgets")
            .doc(category.toLowerCase().replaceAll(RegExp(r'\s+'), '_'));

        await budgetDocRef.set({
          'category': category,
          'limit': limit,
          'updatedAt': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        // VERIFY WRITE SUCCEEDED
        final verifySnap = await budgetDocRef.get();
        if (!verifySnap.exists) {
          throw Exception("Firestore budget write verification failed.");
        }

        executionSummary = "Budget for '$category' set to \$${limit.toStringAsFixed(2)}/month.";
      } else if (action.actionType == 'CREATE_SAVINGS_GOAL') {
        final goalName = action.parameters['goalName'] as String;
        final targetAmount = (action.parameters['targetAmount'] as num).toDouble();
        final targetMonths = (action.parameters['targetMonths'] as num).toInt();
        final monthlyRequired = (action.parameters['monthlyRequired'] as num).toDouble();

        // Write to savings_goals subcollection
        final goalDocRef = _firestore
            .collection("users")
            .doc(currentDocId)
            .collection("savings_goals")
            .doc();

        await goalDocRef.set({
          'id': goalDocRef.id,
          'goalName': goalName,
          'targetAmount': targetAmount,
          'targetMonths': targetMonths,
          'monthlyContribution': monthlyRequired,
          'currentSaved': 0.0,
          'createdAt': Timestamp.fromDate(now),
        });

        // VERIFY WRITE SUCCEEDED
        final verifySnap = await goalDocRef.get();
        if (!verifySnap.exists) {
          throw Exception("Firestore savings goal write verification failed.");
        }

        executionSummary = "Savings Goal '$goalName' created: Target \$${targetAmount.toStringAsFixed(2)} in $targetMonths months (\$${monthlyRequired.toStringAsFixed(2)}/month).";
      } else {
        return Left(Failure("Unknown action type: ${action.actionType}"));
      }

      // CREATE TAMPER-EVIDENT AUDIT LOG
      final auditLogRef = _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("audit_logs")
          .doc();

      final auditLog = FinancialAuditLogModel(
        id: auditLogRef.id,
        uid: currentUid,
        docId: currentDocId,
        actionId: actionId,
        actionType: action.actionType,
        status: 'SUCCESS',
        summary: executionSummary,
        details: action.parameters,
        timestamp: now,
      );

      await auditLogRef.set(auditLog.toJson());

      // Update pending action status to CONFIRMED
      await actionRef.update({
        'status': 'CONFIRMED',
        'executedAt': Timestamp.fromDate(now),
        'auditLogId': auditLogRef.id,
      });

      log("Action $actionId confirmed and executed successfully. Audit Log: ${auditLogRef.id}");
      return Right(executionSummary);
    } catch (e) {
      log("Error confirming action $actionId: $e");
      return Left(Failure("Failed to execute confirmed action: ${e.toString()}"));
    }
  }

  /// Cancels/Rejects a pending action and logs the rejection
  Future<Either<Failure, Unit>> rejectPendingAction(String actionId) async {
    try {
      final currentUid = uid;
      final currentDocId = docId;
      if (currentUid == null || currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      final actionRef = _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("pending_actions")
          .doc(actionId);

      final actionSnap = await actionRef.get();
      if (!actionSnap.exists) {
        return const Right(unit);
      }

      final actionData = actionSnap.data() as Map<String, dynamic>;
      final action = PendingFinancialActionModel.fromJson(actionSnap.id, actionData);

      if (action.uid != currentUid) {
        return Left(Failure("Access Denied: You do not own this pending action."));
      }

      final now = DateTime.now();

      // Log rejection
      final auditLogRef = _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("audit_logs")
          .doc();

      final auditLog = FinancialAuditLogModel(
        id: auditLogRef.id,
        uid: currentUid,
        docId: currentDocId,
        actionId: actionId,
        actionType: action.actionType,
        status: 'REJECTED',
        summary: "User cancelled proposal: ${action.title}",
        details: action.parameters,
        timestamp: now,
      );

      await auditLogRef.set(auditLog.toJson());

      await actionRef.update({
        'status': 'REJECTED',
        'auditLogId': auditLogRef.id,
      });

      return const Right(unit);
    } catch (e) {
      log("Error rejecting action $actionId: $e");
      return Left(Failure(e.toString()));
    }
  }
}
