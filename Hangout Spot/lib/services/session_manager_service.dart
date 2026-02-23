import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hangout_spot/data/models/user_session.dart';
import 'package:hangout_spot/data/models/user_metadata.dart' as app_models;
import 'package:hangout_spot/services/device_info_service.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';

/// Service for managing user sessions across devices
class SessionManagerService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AppDatabase? _db; // Optional for retry sync

  String? _currentSessionId;
  Timer? _heartbeatTimer;
  StreamSubscription? _sessionListener;

  SessionManagerService(this._firestore, this._auth, [this._db]);

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Start a new session on login
  Future<void> startSession({String? outletId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot start session: No user logged in');
      return;
    }

    try {
      final deviceInfo = await DeviceInfoService.getDeviceInfo();
      _currentSessionId = DeviceInfoService.generateSessionId();

      // Check if this is the first device (auto-trust)
      final trustLevel = await _determineInitialTrustLevel(user.uid);

      final session = UserSession(
        sessionId: _currentSessionId!,
        userId: user.uid,
        deviceName: deviceInfo['deviceName']!,
        deviceType: deviceInfo['deviceType']!,
        appVersion: deviceInfo['appVersion']!,
        outletId: outletId,
        lastActivity: DateTime.now(),
        status: 'active',
        createdAt: DateTime.now(),
        androidVersion: deviceInfo['androidVersion'],
        trustLevel: trustLevel,
      );

      // Create session document in Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .set(session.toJson());

      // Update metadata if first device
      if (trustLevel == 'trusted') {
        await _updateMetadataForFirstDevice(user.uid, _currentSessionId!);
      }

      // Start heartbeat to keep session alive
      _startHeartbeat();

      // Listen for remote logout commands
      _listenForRemoteLogout();

      debugPrint(
        '✅ Session started: $_currentSessionId on ${deviceInfo['deviceName']} (Trust: $trustLevel)',
      );
    } catch (e) {
      debugPrint('❌ Error starting session: $e');
    }
  }

  /// Determine initial trust level for new session
  Future<String> _determineInitialTrustLevel(String userId) async {
    try {
      // Check if any sessions exist
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .limit(1)
          .get();

      // If no sessions exist, this is the first device - auto-trust
      if (sessionsSnapshot.docs.isEmpty) {
        debugPrint('🟢 First device detected - auto-trusting');
        return 'trusted';
      }

      // Otherwise, new devices start as pending
      debugPrint('🟡 Additional device detected - pending approval');
      return 'pending';
    } catch (e) {
      debugPrint('⚠️ Error determining trust level: $e');
      return 'pending'; // Default to pending on error
    }
  }

  /// Update metadata for first device
  Future<void> _updateMetadataForFirstDevice(
    String userId,
    String sessionId,
  ) async {
    try {
      final metadata = app_models.UserMetadata(
        userId: userId,
        firstDeviceSessionId: sessionId,
        trustedSessionIds: [sessionId],
        recoveryEmail: _auth.currentUser?.email,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('metadata')
          .doc('account')
          .set(metadata.toJson());

      debugPrint('📝 Metadata created for first device');
    } catch (e) {
      debugPrint('⚠️ Error updating metadata: $e');
    }
  }

  /// Send heartbeat every 30 seconds to update last activity and retry failed syncs
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateLastActivity();
      _retryFailedSyncs();
    });
  }

  /// Update last activity timestamp
  Future<void> _updateLastActivity() async {
    final user = _auth.currentUser;
    if (user == null || _currentSessionId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .update({'lastActivity': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('⚠️ Error updating heartbeat: $e');
    }
  }

  /// Retry syncing orders that failed to push to Firestore
  Future<void> _retryFailedSyncs() async {
    if (_db == null) return;

    try {
      final orderRepo = OrderRepository(_db);
      await orderRepo.syncUnsyncedOrders();
    } catch (e) {
      debugPrint('⚠️ Error in retry sync: $e');
    }
  }

  /// Listen for remote logout command from another device
  void _listenForRemoteLogout() {
    final user = _auth.currentUser;
    if (user == null || _currentSessionId == null) return;

    _sessionListener = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(_currentSessionId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final status = snapshot.data()?['status'];
            if (status == 'logged_out') {
              debugPrint('🚪 Remote logout detected - logging out this device');
              _handleRemoteLogout();
            }
          }
        });
  }

  /// Handle remote logout - sign out the user
  Future<void> _handleRemoteLogout() async {
    await endSession();
    await _auth.signOut();
    // The auth state listener in the app will handle navigation to login
  }

  /// End the current session (on logout)
  Future<void> endSession() async {
    final user = _auth.currentUser;
    if (user == null || _currentSessionId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .update({
            'status': 'logged_out',
            'lastActivity': FieldValue.serverTimestamp(),
          });

      _heartbeatTimer?.cancel();
      _sessionListener?.cancel();
      _currentSessionId = null;

      debugPrint('🚪 Session ended');
    } catch (e) {
      debugPrint('⚠️ Error ending session: $e');
    }
  }

  /// Remote logout a specific session (from another device)
  Future<void> remoteLogout(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(sessionId)
          .update({
            'status': 'logged_out',
            'lastActivity': FieldValue.serverTimestamp(),
          });

      debugPrint('🚪 Remote logout sent for session: $sessionId');
    } catch (e) {
      debugPrint('❌ Error sending remote logout: $e');
    }
  }

  /// Get all active sessions for the current user
  Stream<List<UserSession>> getActiveSessions() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .where('status', isEqualTo: 'active')
        // Removed .orderBy to avoid needing composite index
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs.map((doc) {
            return UserSession.fromJson(doc.data());
          }).toList();

          // Sort by lastActivity in memory (most recent first)
          sessions.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

          return sessions;
        });
  }

  /// Get pending sessions (awaiting approval)
  Stream<List<UserSession>> getPendingSessions() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .where('status', isEqualTo: 'active')
        .where('trustLevel', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserSession.fromJson(doc.data()))
              .toList();
        });
  }

  /// Approve a pending device
  Future<void> approveDevice(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null || _currentSessionId == null) return;

    try {
      // Verify current device is trusted
      final currentSession = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .get();

      if (currentSession.data()?['trustLevel'] != 'trusted') {
        debugPrint('❌ Only trusted devices can approve others');
        return;
      }

      // Approve the device
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(sessionId)
          .update({
            'trustLevel': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': _currentSessionId,
          });

      debugPrint('✅ Device approved: $sessionId');
    } catch (e) {
      debugPrint('❌ Error approving device: $e');
    }
  }

  /// Promote an approved device to trusted
  Future<bool> promoteToTrusted(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null || _currentSessionId == null) return false;

    try {
      // Verify current device is trusted
      final currentSession = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .get();

      if (currentSession.data()?['trustLevel'] != 'trusted') {
        debugPrint('❌ Only trusted devices can promote others');
        return false;
      }

      // Check trusted device limit
      final metadata = await _getUserMetadata(user.uid);
      if (metadata.trustedSessionIds.length >= metadata.maxTrustedDevices) {
        debugPrint(
          '❌ Maximum trusted devices reached (${metadata.maxTrustedDevices})',
        );
        return false;
      }

      // Promote to trusted
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(sessionId)
          .update({'trustLevel': 'trusted'});

      // Update metadata
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('metadata')
          .doc('account')
          .update({
            'trustedSessionIds': FieldValue.arrayUnion([sessionId]),
          });

      debugPrint('✅ Device promoted to trusted: $sessionId');
      return true;
    } catch (e) {
      debugPrint('❌ Error promoting device: $e');
      return false;
    }
  }

  /// Claim trust with password verification
  Future<bool> claimTrust(String password) async {
    final user = _auth.currentUser;
    if (user == null || _currentSessionId == null) return false;

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) return false;

    try {
      // Check claim attempts
      final session = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .get();

      final attempts = session.data()?['trustClaimAttempts'] ?? 0;
      final lastAttempt = session.data()?['lastClaimAttempt'];

      // Rate limiting: max 3 attempts per hour
      if (attempts >= 3 && lastAttempt != null) {
        final lastAttemptTime = DateTime.parse(lastAttempt);
        final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
        if (lastAttemptTime.isAfter(hourAgo)) {
          debugPrint('❌ Too many claim attempts. Try again later.');
          return false;
        }
      }

      // Re-authenticate with password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: trimmedPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Check trusted device limit
      final metadata = await _getUserMetadata(user.uid);
      if (metadata.trustedSessionIds.length >= metadata.maxTrustedDevices) {
        debugPrint('❌ Maximum trusted devices reached');
        return false;
      }

      // Promote to trusted
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .update({
            'trustLevel': 'trusted',
            'trustClaimAttempts': 0,
            'lastClaimAttempt': null,
          });

      // Update metadata
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('metadata')
          .doc('account')
          .update({
            'trustedSessionIds': FieldValue.arrayUnion([_currentSessionId]),
          });

      debugPrint('✅ Trust claimed successfully');
      return true;
    } catch (e) {
      // Increment failed attempts
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .update({
            'trustClaimAttempts': FieldValue.increment(1),
            'lastClaimAttempt': DateTime.now().toIso8601String(),
          });

      debugPrint('❌ Trust claim failed: $e');
      return false;
    }
  }

  /// Get user metadata
  Future<app_models.UserMetadata> _getUserMetadata(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('metadata')
          .doc('account')
          .get();

      if (doc.exists) {
        return app_models.UserMetadata.fromJson(doc.data()!);
      }

      // Return default metadata if doesn't exist
      return app_models.UserMetadata(userId: userId);
    } catch (e) {
      debugPrint('⚠️ Error getting metadata: $e');
      return app_models.UserMetadata(userId: userId);
    }
  }

  /// Check if current device is trusted
  Future<bool> isCurrentDeviceTrusted() async {
    final user = _auth.currentUser;
    if (user == null || _currentSessionId == null) return false;

    try {
      final session = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .get();

      return session.data()?['trustLevel'] == 'trusted';
    } catch (e) {
      return false;
    }
  }

  /// Cleanup old sessions (older than 7 days)
  Future<void> cleanupOldSessions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .where('lastActivity', isLessThan: cutoffDate)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('🧹 Cleaned up ${snapshot.docs.length} old sessions');
    } catch (e) {
      debugPrint('⚠️ Error cleaning up sessions: $e');
    }
  }

  /// Global Logout: End all active sessions across all devices (Danger Zone)
  Future<void> endAllSessions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'logged_out',
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      _heartbeatTimer?.cancel();
      _sessionListener?.cancel();
      _currentSessionId = null;

      debugPrint('💥 All device sessions have been globally terminated.');
    } catch (e) {
      debugPrint('⚠️ Error ending all sessions globally: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _sessionListener?.cancel();
  }
}
