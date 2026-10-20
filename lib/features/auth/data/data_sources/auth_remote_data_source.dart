import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_exception_handler.dart';
import '../model/registration_model.dart';

class AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Either<Failure, RegistrationModel>> registerUser(
    String email,
    String password,
  ) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();

      log('Registering user... $cleanEmail');
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: cleanEmail, password: cleanPassword);
      String uid = userCredential.user!.uid;

      RegistrationModel userModel = RegistrationModel(
        uid: uid,
        email: cleanEmail,
      );

      /// Save to Firestore safely
      try {
        String docId = "${cleanEmail}_$uid";
        await _firestore
            .collection("users")
            .doc(docId)
            .collection("profile")
            .doc("info")
            .set(userModel.toJson());
      } catch (fsErr) {
        log("Warning saving profile to firestore: $fsErr");
      }

      return Right(userModel);
    } catch (e) {
      log("Error registering user: $e");
      return Left(handleFirebaseException(e));
    }
  }

  // login user
  Future<Either<Failure, bool>> loginUser(
    String email,
    String password,
  ) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();

      log('Login user... $cleanEmail');
      await _firebaseAuth
          .signInWithEmailAndPassword(email: cleanEmail, password: cleanPassword);
      return Right(true);
    } catch (e) {
      log("Error logging in user: $e");
      return Left(handleFirebaseException(e));
    }
  }
}
