import 'package:hangout_spot/utils/log_utils.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/models/user_session.dart';
import 'package:hangout_spot/data/models/user_metadata.dart' as app_models;
import 'package:hangout_spot/services/device_info_service.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist the current session ID across cold restarts.
const _kSessionIdKey = 'session_manager_session_id';

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

  /// Start a new session on login, or resume the previous session after a cold
  /// restart.  The session ID is persisted in SharedPreferences so a killed /
  /// restarted app picks up the same session document in Firestore instead of
  /// creating an orphan.
  Future<void> startSession({String? outletId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      logDebug('❌ Cannot start session: No user logged in');
      return;
    }

    // If heartbeat is already running we are already in a session — skip.
    if (_heartbeatTimer != null && _currentSessionId != null) return;

    try {
      // Try to resume a persisted session
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kSessionIdKey);
      if (savedId != null) {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(savedId)
            .get();
        if (doc.exists && doc.data()?['status'] == 'active') {
          _currentSessionId = savedId;
          _startHeartbeat();
          _listenForRemoteLogout();
          logDebug('♻️ Resumed session: $_currentSessionId');
          return;
        }
      }

      // No valid saved session — create a new one
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

      // Persist session ID locally
      await prefs.setString(_kSessionIdKey, _currentSessionId!);

      // Update metadata if first device
      if (trustLevel == 'trusted') {
        await _updateMetadataForFirstDevice(user.uid, _currentSessionId!);
      }

      // Start heartbeat to keep session alive
      _startHeartbeat();

      // Listen for remote logout commands
      _listenForRemoteLogout();

      logDebug(
        '✅ Session started: $_currentSessionId on ${deviceInfo['deviceName']} (Trust: $trustLevel)',
      );
    } catch (e) {
      logDebug('❌ Error starting session: $e');
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
        logDebug('🟢 First device detected - auto-trusting');
        return 'trusted';
      }

      // Otherwise, new devices start as pending
      logDebug('🟡 Additional device detected - pending approval');
      return 'pending';
    } catch (e) {
      logDebug('⚠️ Error determining trust level: $e');
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

      logDebug('📝 Metadata created for first device');
    } catch (e) {
      logDebug('⚠️ Error updating metadata: $e');
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
      logDebug('⚠️ Error updating heartbeat: $e');
    }
  }

  /// Retry syncing orders that failed to push to Firestore
  Future<void> _retryFailedSyncs() async {
    if (_db == null) return;

    try {
      final orderRepo = OrderRepository(_db);
      await orderRepo.syncUnsyncedOrders();
    } catch (e) {
      logDebug('⚠️ Error in retry sync: $e');
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
              logDebug('🚪 Remote logout detected - logging out this device');
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
      _heartbeatTimer = null;
      _sessionListener?.cancel();
      _currentSessionId = null;

      // Clear persisted session ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionIdKey);

      logDebug('🚪 Session ended');
    } catch (e) {
      logDebug('⚠️ Error ending session: $e');
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

      logDebug('🚪 Remote logout sent for session: $sessionId');
    } catch (e) {
      logDebug('❌ Error sending remote logout: $e');
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
        logDebug('❌ Only trusted devices can approve others');
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

      logDebug('✅ Device approved: $sessionId');
    } catch (e) {
      logDebug('❌ Error approving device: $e');
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
        logDebug('❌ Only trusted devices can promote others');
        return false;
      }

      // Check trusted device limit
      final metadata = await _getUserMetadata(user.uid);
      if (metadata.trustedSessionIds.length >= metadata.maxTrustedDevices) {
        logDebug(
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

      logDebug('✅ Device promoted to trusted: $sessionId');
      return true;
    } catch (e) {
      logDebug('❌ Error promoting device: $e');
      return false;
    }
  }

  /// Claim trust with password verification.
  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> claimTrust(String password) async {
    final user = _auth.currentUser;
    if (user == null) return 'No signed-in account found. Please log in again.';
    if (_currentSessionId == null)
      return 'Session not initialised. Restart the app and try again.';

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) return 'Password cannot be empty.';

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
          logDebug('❌ Too many claim attempts. Try again later.');
          return 'Too many attempts. Please wait an hour and try again.';
        }
      }

      // Re-authenticate with password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: trimmedPassword,
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (authErr) {
        // Increment failed attempts for wrong-password
        _incrementClaimAttempts(user.uid);
        switch (authErr.code) {
          case 'wrong-password':
          case 'invalid-credential':
          case 'user-mismatch':
          case 'user-not-found':
            return 'Incorrect password. Please try again.';
          case 'network-request-failed':
            return 'Network error. Check your internet and try again.';
          case 'too-many-requests':
            return 'Too many attempts. Please wait a moment and try again.';
          default:
            return authErr.message ??
                'Password verification failed. Please try again.';
        }
      }

      // Check trusted device limit
      final metadata = await _getUserMetadata(user.uid);
      if (metadata.trustedSessionIds.length >= metadata.maxTrustedDevices) {
        logDebug('❌ Maximum trusted devices reached');
        return 'Maximum trusted devices reached (${metadata.maxTrustedDevices}). Remove a trusted device first.';
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

      logDebug('✅ Trust claimed successfully');
      return null; // success
    } catch (e) {
      _incrementClaimAttempts(user.uid);
      logDebug('❌ Trust claim failed: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  /// Helper to increment failed claim attempts without blocking the caller.
  void _incrementClaimAttempts(String userId) {
    if (_currentSessionId == null) return;
    _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(_currentSessionId)
        .update({
          'trustClaimAttempts': FieldValue.increment(1),
          'lastClaimAttempt': DateTime.now().toIso8601String(),
        })
        .catchError((e) => logDebug('⚠️ Failed to update claim attempts: $e'));
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
      logDebug('⚠️ Error getting metadata: $e');
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

  /// Cleanup old sessions (older than 7 days) that are NOT still trusted
  Future<void> cleanupOldSessions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Fetch trusted session IDs so we don't accidentally delete them
      final metadata = await _getUserMetadata(user.uid);
      final trustedIds = metadata.trustedSessionIds.toSet();

      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .where('lastActivity', isLessThan: cutoffDate)
          .get();

      int deleted = 0;
      for (var doc in snapshot.docs) {
        // Skip sessions that are still in the trusted list
        if (trustedIds.contains(doc.id)) continue;
        await doc.reference.delete();
        deleted++;
      }

      logDebug(
        '🧹 Cleaned up $deleted old sessions (${snapshot.docs.length - deleted} trusted kept)',
      );
    } catch (e) {
      logDebug('⚠️ Error cleaning up sessions: $e');
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
      _heartbeatTimer = null;
      _sessionListener?.cancel();
      _currentSessionId = null;

      // Clear persisted session ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionIdKey);

      logDebug('💥 All device sessions have been globally terminated.');
    } catch (e) {
      logDebug('⚠️ Error ending all sessions globally: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _sessionListener?.cancel();
  }
}
