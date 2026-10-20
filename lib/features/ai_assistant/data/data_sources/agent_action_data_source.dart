import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';

/// Read-only data source for deterministic financial calculations and offline analysis.
/// All proposal creations, confirmations, cancellations, and audit logging happen
/// EXCLUSIVELY on the secure backend via AgentService.
class AgentActionDataSource {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  AgentActionDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  FirebaseFirestore get _effectiveFirestore =>
      _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _effectiveAuth => _auth ?? FirebaseAuth.instance;

  String? get uid => _effectiveAuth.currentUser?.uid;
  String? get email => _effectiveAuth.currentUser?.email;
  String? get docId {
    final u = uid;
    final e = email;
    if (u != null && e != null && u.isNotEmpty && e.isNotEmpty) {
      return "${e}_$u";
    }
    return null;
  }

  // ==========================================
  // READ-ONLY DETERMINISTIC TOOLS
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

      final query = await _effectiveFirestore
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

      Query query = _effectiveFirestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses");

      if (month != null && month.isNotEmpty) {
        final startOfMonth = "$month-01";
        final parts = month.split('-');
        final y = int.tryParse(parts[0]) ?? DateTime.now().year;
        final m = int.tryParse(parts[1]) ?? DateTime.now().month;
        final nextM = m == 12 ? 1 : m + 1;
        final nextY = m == 12 ? y + 1 : y;
        final endOfMonth = "$nextY-${nextM.toString().padLeft(2, '0')}-01";

        query = query
            .where("date", isGreaterThanOrEqualTo: startOfMonth)
            .where("date", isLessThan: endOfMonth);
      }

      final snapshot = await query.get();
      final List<Map<String, dynamic>> results = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        results.add({
          'id': doc.id,
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'isIncome': data['isIncome'] == true,
          'categoryName': data['categoryName'] ?? 'Other',
          'date': data['date'] ?? '',
          'time': data['time'] ?? '',
          'description': data['description'] ?? '',
        });
      }

      // Sort by date descending in-memory
      results.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      return Right(results.take(limit).toList());
    } catch (e) {
      log("Error in getTransactions tool: $e");
      return Left(Failure("Failed to retrieve transactions: ${e.toString()}"));
    }
  }

  /// Scans expenses and detects unusual spikes above 1.5x category average
  Future<Either<Failure, List<Map<String, dynamic>>>> findUnusualSpending() async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated."));
      }

      final snapshot = await _effectiveFirestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .where("isIncome", isEqualTo: false)
          .get();

      final Map<String, List<double>> categoryExpenses = {};
      final List<Map<String, dynamic>> allExpenses = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final category = data['categoryName'] as String? ?? 'Other';
        final date = data['date'] as String? ?? '';

        categoryExpenses.putIfAbsent(category, () => []).add(amount);
        allExpenses.add({
          'category': category,
          'amount': amount,
          'date': date,
          'description': data['description'] ?? '',
        });
      }

      // Compute average per category
      final Map<String, double> categoryAverages = {};
      categoryExpenses.forEach((cat, amounts) {
        if (amounts.isNotEmpty) {
          categoryAverages[cat] = amounts.reduce((a, b) => a + b) / amounts.length;
        }
      });

      // Find transactions exceeding 1.5x category average and >= 500 BDT
      final List<Map<String, dynamic>> anomalies = [];
      for (var exp in allExpenses) {
        final cat = exp['category'] as String;
        final amt = exp['amount'] as double;
        final avg = categoryAverages[cat] ?? 0.0;

        if (avg > 0 && amt >= (avg * 1.5) && amt >= 500.0) {
          anomalies.add({
            'category': cat,
            'amount': amt,
            'date': exp['date'],
            'description': exp['description'],
            'categoryAverage': avg,
            'spikeRatio': amt / avg,
            'reason': '${(amt / avg).toStringAsFixed(1)}x above average (\$${avg.toStringAsFixed(2)})',
          });
        }
      }

      anomalies.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      return Right(anomalies);
    } catch (e) {
      log("Error in findUnusualSpending: $e");
      return Left(Failure("Failed to detect unusual spending: ${e.toString()}"));
    }
  }
}
