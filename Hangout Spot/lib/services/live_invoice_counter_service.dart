import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hangout_spot/utils/exceptions/app_exceptions.dart';
import 'package:hangout_spot/utils/exceptions/error_handler.dart';

/// Live Invoice Counter Service using Firebase Realtime Database
/// Fixes multi-device hold order conflicts with real-time atomic counters
///
/// SOLUTION: Uses temporary invoice numbers (HOLD-timestamp) for pending orders,
/// and only assigns real sequential numbers when orders are completed.
class LiveInvoiceCounterService {
  final DatabaseReference _database;
  final FirebaseAuth _auth;

  LiveInvoiceCounterService({DatabaseReference? database, FirebaseAuth? auth})
    : _database = database ?? FirebaseDatabase.instance.ref(),
      _auth = auth ?? FirebaseAuth.instance;

  /// Get reference to user's invoice counter node
  DatabaseReference? _getUserCounterRef() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _database.child('invoiceCounters').child(user.uid);
  }

  /// Initialize counter for a session (call at app start)
  Future<void> initializeCounter({required String sessionId}) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) {
      debugPrint('⚠️ Cannot initialize counter: User not logged in');
      return;
    }

    try {
      final sessionRef = counterRef.child('sessions').child(sessionId);

      // Check if session already exists
      final snapshot = await sessionRef.get();
      if (snapshot.exists) {
        debugPrint('✅ Counter already initialized for session: $sessionId');
        return;
      }

      // Initialize new session
      await sessionRef.set({
        'startNumber':
            ServerValue.timestamp, // Use timestamp as unique identifier
        'currentNumber': 0,
        'createdAt': ServerValue.timestamp,
        'lastUpdated': ServerValue.timestamp,
      });

      debugPrint('✅ Initialized invoice counter for session: $sessionId');
    } catch (e) {
      debugPrint('❌ Failed to initialize counter: $e');
    }
  }

  /// Generate temporary invoice number for hold orders
  String generateHoldInvoiceNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'HOLD-$timestamp';
  }

  /// Check if invoice number is a temporary hold number
  bool isHoldInvoiceNumber(String invoiceNumber) {
    return invoiceNumber.startsWith('HOLD-');
  }

  /// Get next sequential invoice number (atomic, thread-safe)
  /// This should ONLY be called for COMPLETED orders
  Future<String> getNextInvoiceNumber({
    required String sessionId,
    required String prefix,
  }) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) {
      throw AuthException(userMessage: 'Please sign in to generate invoices.');
    }

    try {
      final sessionRef = counterRef.child('sessions').child(sessionId);

      // Use transaction for atomic increment
      final transactionResult = await sessionRef
          .child('currentNumber')
          .runTransaction((currentValue) {
            final current = (currentValue as int?) ?? 0;
            return Transaction.success(current + 1);
          });

      if (!transactionResult.committed) {
        throw InvoiceException(
          userMessage: 'Failed to generate invoice number. Please try again.',
          technicalMessage: 'Transaction failed to commit',
        );
      }

      final newNumber = transactionResult.snapshot.value as int;

      // Update last used timestamp
      await sessionRef.child('lastUpdated').set(ServerValue.timestamp);

      // Format invoice number with prefix and padding
      final invoiceNumber = '$prefix${newNumber.toString().padLeft(4, '0')}';

      if (kDebugMode) {
        debugPrint('✅ Generated invoice number: $invoiceNumber');
      }
      return invoiceNumber;
    } catch (e) {
      throw ErrorHandler.handleInvoiceError(e);
    }
  }

  /// Get current counter value (for display purposes)
  Future<int> getCurrentCounter({required String sessionId}) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) return 0;

    try {
      final snapshot = await counterRef
          .child('sessions')
          .child(sessionId)
          .child('currentNumber')
          .get();

      if (!snapshot.exists) return 0;
      return (snapshot.value as num?)?.toInt() ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to get current counter: $e');
      }
      return 0;
    }
  }

  /// Watch counter updates in real-time
  Stream<int> watchCounter({required String sessionId}) {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) return Stream.value(0);

    return counterRef
        .child('sessions')
        .child(sessionId)
        .child('currentNumber')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value == null) return 0;
          return (value as num).toInt();
        });
  }

  /// Convert hold invoice to real invoice (when completing held order)
  Future<String> convertHoldToRealInvoice({
    required String sessionId,
    required String prefix,
    required String oldHoldNumber,
  }) async {
    if (!isHoldInvoiceNumber(oldHoldNumber)) {
      // Already a real invoice number, return as-is
      return oldHoldNumber;
    }

    // Generate new sequential number
    final realInvoiceNumber = await getNextInvoiceNumber(
      sessionId: sessionId,
      prefix: prefix,
    );

    debugPrint('✅ Converted $oldHoldNumber → $realInvoiceNumber');
    return realInvoiceNumber;
  }

  /// Reserve a block of invoice numbers (for bulk operations)
  Future<List<String>> reserveInvoiceNumbers({
    required String sessionId,
    required String prefix,
    required int count,
  }) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) {
      throw AuthException(
        userMessage: 'Please sign in to reserve invoice numbers.',
      );
    }

    try {
      final sessionRef = counterRef.child('sessions').child(sessionId);

      // Use transaction to reserve block atomically
      final transactionResult = await sessionRef
          .child('currentNumber')
          .runTransaction((currentValue) {
            final current = (currentValue as int?) ?? 0;
            return Transaction.success(current + count);
          });

      if (!transactionResult.committed) {
        throw InvoiceException(
          userMessage: 'Failed to reserve invoice numbers. Please try again.',
          technicalMessage: 'Transaction failed to commit',
        );
      }

      final endNumber = transactionResult.snapshot.value as int;
      final startNumber = endNumber - count + 1;

      // Generate list of invoice numbers
      final List<String> invoiceNumbers = [];
      for (int i = startNumber; i <= endNumber; i++) {
        invoiceNumbers.add('$prefix${i.toString().padLeft(4, '0')}');
      }

      debugPrint(
        '✅ Reserved $count invoice numbers: ${invoiceNumbers.first} to ${invoiceNumbers.last}',
      );
      return invoiceNumbers;
    } catch (e) {
      throw ErrorHandler.handleInvoiceError(e);
    }
  }

  /// Reset counter (for new day/session)
  Future<void> resetCounter({
    required String sessionId,
    int startFrom = 0,
  }) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) return;

    try {
      final sessionRef = counterRef.child('sessions').child(sessionId);

      await sessionRef.update({
        'currentNumber': startFrom,
        'lastUpdated': ServerValue.timestamp,
        'resetAt': ServerValue.timestamp,
      });

      debugPrint('✅ Counter reset to $startFrom for session: $sessionId');
    } catch (e) {
      throw ErrorHandler.handleInvoiceError(e);
    }
  }

  /// Get counter statistics
  Future<Map<String, dynamic>> getCounterStats({
    required String sessionId,
  }) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) return {};

    try {
      final snapshot = await counterRef
          .child('sessions')
          .child(sessionId)
          .get();

      if (!snapshot.exists) return {};

      final data = snapshot.value as Map?;
      if (data == null) return {};

      return {
        'currentNumber': (data['currentNumber'] as num?)?.toInt() ?? 0,
        'createdAt': data['createdAt'],
        'lastUpdated': data['lastUpdated'],
        'resetAt': data['resetAt'],
      };
    } catch (e) {
      debugPrint('❌ Failed to get counter stats: $e');
      return {};
    }
  }

  /// Watch all sessions (for multi-device monitoring)
  Stream<Map<String, int>> watchAllSessions() {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) return Stream.value({});

    return counterRef.child('sessions').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <String, int>{};

      final Map<String, int> sessions = {};

      data.forEach((key, value) {
        if (value is Map) {
          final currentNumber = (value['currentNumber'] as num?)?.toInt() ?? 0;
          sessions[key.toString()] = currentNumber;
        }
      });

      return sessions;
    });
  }

  /// Sync local counter with cloud (for offline support)
  Future<void> syncWithCloud({
    required String sessionId,
    required int localCounter,
  }) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) return;

    try {
      final sessionRef = counterRef.child('sessions').child(sessionId);

      // Get cloud counter
      final snapshot = await sessionRef.child('currentNumber').get();
      final cloudCounter = (snapshot.value as num?)?.toInt() ?? 0;

      // Use max of local and cloud to prevent conflicts
      final syncedCounter = localCounter > cloudCounter
          ? localCounter
          : cloudCounter;

      if (syncedCounter > cloudCounter) {
        await sessionRef.child('currentNumber').set(syncedCounter);
        debugPrint(
          '✅ Synced counter: local=$localCounter, cloud=$cloudCounter, synced=$syncedCounter',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to sync counter: $e');
    }
  }

  /// Cleanup old sessions (run periodically)
  Future<void> cleanupOldSessions({int daysOld = 7}) async {
    final counterRef = _getUserCounterRef();
    if (counterRef == null) return;

    try {
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: daysOld))
          .millisecondsSinceEpoch;

      final snapshot = await counterRef.child('sessions').get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map?;
      if (data == null) return;

      final List<String> toDelete = [];

      data.forEach((key, value) {
        if (value is Map) {
          final lastUpdated = value['lastUpdated'] as int?;
          if (lastUpdated != null && lastUpdated < cutoffTime) {
            toDelete.add(key.toString());
          }
        }
      });

      // Delete old sessions
      for (final sessionId in toDelete) {
        await counterRef.child('sessions').child(sessionId).remove();
      }

      debugPrint('✅ Cleaned up ${toDelete.length} old sessions');
    } catch (e) {
      debugPrint('❌ Failed to cleanup old sessions: $e');
    }
  }

  /// Dispose/cleanup
  void dispose() {
    // Firebase Realtime Database handles cleanup automatically
  }
}
