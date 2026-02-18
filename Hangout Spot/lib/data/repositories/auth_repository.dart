import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/services/session_manager_service.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final SessionManagerService _sessionManager;

  AuthRepository(this._firebaseAuth, this._sessionManager);

  SessionManagerService get sessionManager => _sessionManager;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Start session tracking after successful login
    await _sessionManager.startSession();
  }

  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();

    // Start session tracking after successful login
    await _sessionManager.startSession();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    // End session before signing out
    await _sessionManager.endSession();
    await _firebaseAuth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final sessionManager = SessionManagerService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
  return AuthRepository(FirebaseAuth.instance, sessionManager);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
