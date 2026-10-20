import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';
import '../models/category_add_request_model.dart';
import '../models/category_list_response_model.dart';

class CategoryRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser?.uid ?? "";
  String get email => _auth.currentUser?.email ?? "";
  String get docId => email.isNotEmpty && uid.isNotEmpty ? "${email}_$uid" : "";

  static const List<String> defaultCategoriesList = [
    "Food & Dining",
    "Groceries",
    "Salary",
    "Freelance",
    "Rent & Housing",
    "Transportation",
    "Bills & Utilities",
    "Shopping",
    "Health & Medical",
    "Entertainment",
    "Investments",
    "Education",
  ];

  Future<Either<Failure, Unit>> addCategory(
    CategoryAddRequestModel category,
  ) async {
    try {
      if (docId.isEmpty) {
        return Left(Failure("User not authenticated"));
      }

      final docRef = await _firestore
          .collection("users")
          .doc(docId)
          .collection("categories")
          .add(category.toJson());

      log("Category added with ID: ${docRef.id}");
      return const Right(unit);
    } on Exception catch (e) {
      log("Error adding category: $e");
      return Left(Failure(e.toString()));
    }
  }

  Future<Either<Failure, Unit>> addDefaultCategories() async {
    try {
      if (docId.isEmpty) {
        return Left(Failure("User not authenticated"));
      }

      final existingCategories = await _firestore
          .collection("users")
          .doc(docId)
          .collection("categories")
          .get();

      final existingNames = existingCategories.docs
          .map((doc) => (doc.data()["name"] as String? ?? "").toLowerCase().trim())
          .toSet();

      final batch = _firestore.batch();
      int addedCount = 0;

      for (var catName in defaultCategoriesList) {
        if (!existingNames.contains(catName.toLowerCase().trim())) {
          final docRef = _firestore
              .collection("users")
              .doc(docId)
              .collection("categories")
              .doc();

          batch.set(docRef, {
            "name": catName,
            "createdAt": Timestamp.now(),
          });
          addedCount++;
        }
      }

      if (addedCount > 0) {
        await batch.commit();
      }

      return const Right(unit);
    } catch (e) {
      log("Error adding default categories: $e");
      return Left(Failure(e.toString()));
    }
  }

  Future<Either<Failure, List<CategoryListResponseModel>>>
  getCategories() async {
    try {
      if (docId.isEmpty) {
        return const Right([]);
      }

      final categories = await _firestore
          .collection("users")
          .doc(docId)
          .collection("categories")
          .orderBy("createdAt", descending: true)
          .get();

      final categoryList = categories.docs.map((doc) {
        final data = doc.data();
        return CategoryListResponseModel(
          id: doc.id,
          name: data["name"] ?? '',
          createdAt: data["createdAt"] ?? Timestamp.now(),
        );
      }).toList();

      log(
        "Categories fetched successfully: ${categoryList.map((e) => e.toJson()).toList()}",
      );
      return Right(categoryList);
    } on Exception catch (e) {
      log("Error getting categories: $e");
      return Left(Failure(e.toString()));
    }
  }
}
