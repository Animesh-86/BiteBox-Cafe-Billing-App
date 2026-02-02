import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:drift/drift.dart';

/// Session Provider - manages cafe opening/closing hours and order numbering
/// Cafe operates 3 PM to 3 AM next day
/// After 3 AM, a new session starts and order numbers reset to 1001

class SessionManager {
  final AppDatabase _db;

  // Cafe opens at 3 PM (15:00) and closes at 3 AM (03:00)
  static const int OPENING_HOUR = 15; // 3 PM
  static const int CLOSING_HOUR = 3; // 3 AM

  SessionManager(this._db);

  /// Get current session date
  /// Session starts at 3 PM and ends at 3 AM next day
  /// So a session is identified by the date it started (3 PM date)
  DateTime getCurrentSessionDate() {
    final now = DateTime.now();
    // If current time is before 3 PM, session belongs to yesterday
    if (now.hour < CLOSING_HOUR || (now.hour >= OPENING_HOUR)) {
      // Current session
      if (now.hour >= OPENING_HOUR) {
        return DateTime(now.year, now.month, now.day);
      } else {
        // Before 3 AM, still in yesterday's session
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1));
      }
    }
    return DateTime(now.year, now.month, now.day);
  }

  /// Get the session ID for the current session
  String getCurrentSessionId() {
    final sessionDate = getCurrentSessionDate();
    return 'SESSION-${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';
  }

  /// Get next invoice number for current session
  Future<String> getNextInvoiceNumber() async {
    final sessionDate = getCurrentSessionDate();
    final sessionStart = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      OPENING_HOUR,
    );
    final sessionEnd = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      CLOSING_HOUR,
    ).add(const Duration(days: 1));

    // Get count of orders for this session
    final query = _db.select(_db.orders)
      ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart))
      ..where((tbl) => tbl.createdAt.isSmallerThanValue(sessionEnd));

    final count = await query.get();
    final nextNumber = 1001 + count.length;
    return '#$nextNumber';
  }

  /// Get all orders for current session
  Stream<List<Order>> watchSessionOrders() {
    final sessionDate = getCurrentSessionDate();
    final sessionStart = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      OPENING_HOUR,
    );
    final sessionEnd = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      CLOSING_HOUR,
    ).add(const Duration(days: 1));

    return (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart))
          ..where((tbl) => tbl.createdAt.isSmallerThanValue(sessionEnd))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get session info (for display)
  Map<String, dynamic> getSessionInfo() {
    final now = DateTime.now();
    final sessionDate = getCurrentSessionDate();
    final nextSessionDate = sessionDate.add(const Duration(days: 1));

    return {
      'sessionId': getCurrentSessionId(),
      'sessionDate': sessionDate,
      'nextSessionDate': nextSessionDate,
      'currentTime': now,
      'opensAt': DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        OPENING_HOUR,
      ),
      'closesAt': DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        CLOSING_HOUR,
      ).add(const Duration(days: 1)),
    };
  }
}

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(ref.watch(appDatabaseProvider));
});
