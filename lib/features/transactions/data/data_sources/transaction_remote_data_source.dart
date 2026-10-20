import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_exception_handler.dart';
import '../models/transaction_list_response_model.dart';

class TransactionRemoteDataSource {
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

  Future<Either<Failure, List<TransactionListResponseModel>>>
  getTransactionList() async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated. Please log in again."));
      }
      final transactions = await _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .orderBy("createdAt", descending: true)
          .get();
      final transactionList = transactions.docs.map((doc) {
        return TransactionListResponseModel.fromJson(doc.id, doc.data());
      }).toList();
      log(
        "transactionList: ${transactionList.map((e) => e.toJson()).toList()}",
      );
      return Right(transactionList);
    } catch (e) {
      log("Error getting transactions: $e");
      return Left(handleFirebaseException(e));
    }
  }

  Future<Either<Failure, Unit>> deleteTransaction(String transactionId) async {
    try {
      final currentDocId = docId;
      if (currentDocId == null) {
        return Left(Failure("User is not authenticated. Please log in again."));
      }
      await _firestore
          .collection("users")
          .doc(currentDocId)
          .collection("income_expenses")
          .doc(transactionId)
          .delete();
      return Right(unit);
    } catch (e) {
      log("Error deleting transaction: $e");
      return Left(handleFirebaseException(e));
    }
  }
}
