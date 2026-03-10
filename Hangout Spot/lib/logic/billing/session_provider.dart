import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // To access sharedPreferencesProvider

/// Session Provider - manages cafe opening/closing hours and order numbering
/// Default: opens 2 PM, closes 5 AM next day (overnight shift).

class SessionManager {
  final AppDatabase _db;
  final SharedPreferences _prefs;

  // Cafe default hours (if not set in preferences)
  int get openingHour => _prefs.getInt('opening_hour') ?? 14; // Default 2 PM
  int get closingHour => _prefs.getInt('closing_hour') ?? 5; // Default 5 AM

  SessionManager(this._db, this._prefs);

  // ─── Private helpers ───────────────────────────────────────────────────────

  /// Returns the exclusive end DateTime for a session.
  ///
  /// **Overnight shifts** (`closingHour ≤ openingHour`, e.g. 2 PM → 5 AM):
  ///   The window runs from `openingHour` on `sessionDate` to `openingHour`
  ///   on the *next* calendar day.  Using `openingHour` (not `closingHour`)
  ///   as the end closes the dead-zone that existed between the official
  ///   closing time and the next opening — orders placed in that gap were
  ///   previously invisible on the dashboard.
  ///
  /// **Same-day shifts** (`closingHour > openingHour`, e.g. 8 AM → 8 PM):
  ///   The window ends at `closingHour` on the same day.
  DateTime _sessionEnd(DateTime sessionDate) {
    if (closingHour <= openingHour) {
      // Overnight: session runs open → open (next day) to cover the gap.
      return DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        openingHour,
      ).add(const Duration(days: 1));
    } else {
      return DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      );
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Returns the calendar date that identifies the current session.
  ///
  /// For overnight shifts any time *before* `openingHour` today belongs to
  /// yesterday's session — this closes the gap where orders placed after the
  /// official close but before the next open were previously orphaned.
  DateTime getCurrentSessionDate() {
    final now = DateTime.now();
    final bool crossesMidnight = closingHour <= openingHour;

    if (crossesMidnight) {
      // Overnight shift (e.g. opens 2 PM, closes 5 AM).
      // Any hour before today's opening → still in yesterday's session.
      if (now.hour >= openingHour) {
        return DateTime(now.year, now.month, now.day);
      } else {
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
      }
    } else {
      // Same-day shift (e.g. 8 AM – 8 PM).
      if (now.hour < openingHour) {
        // Before today's opening → last session was yesterday.
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
      }
      return DateTime(now.year, now.month, now.day);
    }
  }

  /// Get the session ID for the current session
  String getCurrentSessionId() {
    final sessionDate = getCurrentSessionDate();
    return 'SESSION-${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';
  }

  /// Get next invoice number for current session.
  /// Optimized for speed: purely local, no network calls.
  Future<String> getNextInvoiceNumber() async {
    final sessionDate = getCurrentSessionDate();
    final sessionStart = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      openingHour,
    );
    final sessionEnd = _sessionEnd(sessionDate);

    final query = _db.select(_db.orders)
      ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart))
      ..where((tbl) => tbl.createdAt.isSmallerThanValue(sessionEnd))
      ..where((tbl) => tbl.status.isNotValue('pending'));

    final count = await query.get();
    final nextNumber = 1001 + count.length;
    return '#$nextNumber';
  }

  /// Peek at the next invoice number for current session without incrementing it
  /// Used for UI display purposes to prevent burning sequence numbers on rebuilds.
  /// Always uses local SQLite count — the Firestore path for counters is RTDB
  /// (not Firestore), so we skip the cloud check entirely.  (BUG-15)
  Future<String> peekNextInvoiceNumber() async {
    final sessionDate = getCurrentSessionDate();

    final sessionStart = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      openingHour,
    );
    final sessionEnd = _sessionEnd(sessionDate);

    final query = _db.select(_db.orders)
      ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart))
      ..where((tbl) => tbl.createdAt.isSmallerThanValue(sessionEnd))
      ..where((tbl) => tbl.status.isNotValue('pending'));

    final count = await query.get();
    final nextNumber = 1001 + count.length;
    return '#$nextNumber';
  }

  /// Get all orders for a specific session date (for dashboard date switching).
  Stream<List<Order>> watchOrdersForSession(DateTime sessionDate) {
    final sessionStart = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      openingHour,
    );
    final sessionEnd = _sessionEnd(sessionDate);

    return (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart))
          ..where((tbl) => tbl.createdAt.isSmallerThanValue(sessionEnd))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get all orders for current session (delegates to watchOrdersForSession).
  Stream<List<Order>> watchSessionOrders() {
    return watchOrdersForSession(getCurrentSessionDate());
  }

  /// Get session info (for display)
  Map<String, dynamic> getSessionInfo() {
    final now = DateTime.now();
    final sessionDate = getCurrentSessionDate();
    final nextSessionDate = sessionDate.add(const Duration(days: 1));
    final sessionEnd = _sessionEnd(sessionDate);

    return {
      'sessionId': getCurrentSessionId(),
      'sessionDate': sessionDate,
      'nextSessionDate': nextSessionDate,
      'currentTime': now,
      'opensAt': DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        openingHour,
      ),
      'closesAt': sessionEnd,
    };
  }

  Map<String, DateTime> getSessionRange(DateTime sessionDate) {
    return {
      'start': DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        openingHour,
      ),
      'end': _sessionEnd(sessionDate),
    };
  }
}

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SessionManager(db, prefs);
});
