import 'package:firebase_auth/firebase_auth.dart';
import 'failure.dart';

Failure handleFirebaseException(dynamic e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return Failure("Invalid email or password. Please try again.");
      case 'user-not-found':
        return Failure("No account found with this email. Please register first.");
      case 'invalid-email':
        return Failure("Please enter a valid email address.");
      case 'user-disabled':
        return Failure("This user account has been disabled.");
      case 'email-already-in-use':
        return Failure("An account already exists with this email address.");
      case 'weak-password':
        return Failure("Password is too weak. Please use at least 6 characters.");
      case 'network-request-failed':
        return Failure("Network error. Please check your internet connection.");
      case 'too-many-requests':
        return Failure("Too many failed attempts. Please try again later.");
      default:
        return Failure(e.message ?? "Authentication Error: ${e.code}");
    }
  }

  if (e is FirebaseException) {
    return Failure(e.message ?? "Firebase Error: ${e.code}");
  }

  return Failure(e.toString());
}
