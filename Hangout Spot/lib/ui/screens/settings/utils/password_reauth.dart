import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

Future<String?> reauthenticateCurrentUserWithPassword({
  required String password,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) {
    return 'No signed-in account found. Please log in again.';
  }

  final trimmedPassword = password.trim();
  if (trimmedPassword.isEmpty) {
    return 'Password cannot be empty.';
  }

  try {
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: trimmedPassword,
    );

    await user.reauthenticateWithCredential(credential).timeout(timeout);
    return null;
  } on TimeoutException {
    return 'Password verification timed out. Check your internet and try again.';
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-mismatch':
      case 'user-not-found':
        return 'Incorrect password.';
      case 'network-request-failed':
        return 'Network error while verifying password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'requires-recent-login':
        return 'Session expired. Please sign in again and retry.';
      default:
        return e.message ??
            'Unable to verify password right now. Please try again.';
    }
  } catch (_) {
    return 'Unable to verify password right now. Please try again.';
  }
}
