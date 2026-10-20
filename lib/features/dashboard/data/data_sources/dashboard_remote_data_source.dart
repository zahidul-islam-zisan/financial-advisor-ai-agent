import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_exception_handler.dart';
import '../../../transactions/data/models/transaction_list_response_model.dart';

class DashboardRemoteDataSource {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  DashboardRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  FirebaseFirestore get _effectiveFirestore =>
      _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _effectiveAuth => _auth ?? FirebaseAuth.instance;

  String get uid => _effectiveAuth.currentUser?.uid ?? "";
  String get email => _effectiveAuth.currentUser?.email ?? "";
  String get docId => email.isNotEmpty && uid.isNotEmpty ? "${email}_$uid" : "";
  Future<Either<Failure, List<TransactionListResponseModel>>> getDashboardData(
    String? status,
  ) async {
    try {
      List<TransactionListResponseModel> transactionList = [];
      final now = DateTime.now();
      final startOfMonth =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextMonthYear = now.month == 12 ? now.year + 1 : now.year;
      final lastOfMonth =
          "$nextMonthYear-${nextMonth.toString().padLeft(2, '0')}-01";
      if (status == 'Monthly') {
        final transactions = await _effectiveFirestore
            .collection("users")
            .doc(docId)
            .collection("income_expenses")
            .where("date", isGreaterThanOrEqualTo: startOfMonth)
            .where("date", isLessThan: lastOfMonth)
            .get();
        transactionList = transactions.docs.map((doc) {
          return TransactionListResponseModel.fromJson(doc.id, doc.data());
        }).toList();
        log(
          "DASHBOARD transaction Summery: ${transactionList.map((e) => e.toJson()).toList()}",
        );
      } else {
        final transactions = await _effectiveFirestore
            .collection("users")
            .doc(docId)
            .collection("income_expenses")
            .get();
        transactionList = transactions.docs.map((doc) {
          return TransactionListResponseModel.fromJson(doc.id, doc.data());
        }).toList();
        log(
          "DASHBOARD transaction Summery: ${transactionList.map((e) => e.toJson()).toList()}",
        );
      }
      return Right(transactionList);
    } catch (e) {
      log("Error DASHBOARD transaction Summery: $e");
      return Left(handleFirebaseException(e));
    }
  }
}
