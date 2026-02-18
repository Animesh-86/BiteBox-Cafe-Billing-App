import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/services/session_manager_service.dart';

/// Provider for SessionManagerService
final sessionManagerProvider = Provider<SessionManagerService>((ref) {
  return SessionManagerService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});
