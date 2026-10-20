import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';
import '../models/add_income_expense_request_model.dart';

class AddIncomeExpenseDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

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

  Future<Either<Failure, Unit>> addIncomeExpense(
    AddIncomeExpenseRequestModel incomeExpense,
  ) async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated. Please log in again."));
      }
      final docRef = await _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .add(incomeExpense.toJson());
      incomeExpense.copyWith(id: docRef.id);
      log("IncomeExpense added with ID: ${docRef.id}");
      return Right(unit);
    } on Exception catch (e) {
      log("Error adding incomeExpense: $e");
      return Left(Failure(e.toString()));
    }
  }

  Future<Either<Failure, Unit>> updateIncomeExpense(
    String transactionId,
    AddIncomeExpenseRequestModel incomeExpense,
  ) async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated. Please log in again."));
      }
      log("IncomeExpense updated : ${incomeExpense.toJson()}");
      await _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .doc(transactionId)
          .update(incomeExpense.toJson());
      log("IncomeExpense updated with ID: $transactionId");
      return Right(unit);
    } on Exception catch (e) {
      log("Error updating incomeExpense: $e");
      return Left(Failure(e.toString()));
    }
  }
}
