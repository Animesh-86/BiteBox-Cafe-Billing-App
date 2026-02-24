import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // To access sharedPreferencesProvider

/// Session Provider - manages cafe opening/closing hours and order numbering
/// Cafe operates 2 PM to 2 AM next day
/// After 2 AM, a new session starts and order numbers reset to 1001

class SessionManager {
  final AppDatabase _db;
  final SharedPreferences _prefs;

  // Cafe default hours (if not set in preferences)
  int get openingHour => _prefs.getInt('opening_hour') ?? 14; // Default 2 PM
  int get closingHour => _prefs.getInt('closing_hour') ?? 5; // Default 5 AM

  SessionManager(this._db, this._prefs);

  /// Get current session date
  /// Session starts at 2 PM and ends at 5 AM next day
  /// So a session is identified by the date it started (2 PM date)
  DateTime getCurrentSessionDate() {
    final now = DateTime.now();
    final bool crossesMidnight = closingHour <= openingHour;

    if (crossesMidnight) {
      // e.g. 2 PM to 5 AM next day
      if (now.hour < closingHour || now.hour >= openingHour) {
        if (now.hour >= openingHour) {
          return DateTime(now.year, now.month, now.day);
        } else {
          // It's after midnight but before closing (e.g. 2 AM), so session belongs to yesterday
          return DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 1));
        }
      }
    } else {
      // Standard day shift, e.g. 8 AM to 8 PM
      if (now.hour >= openingHour && now.hour < closingHour) {
        return DateTime(now.year, now.month, now.day);
      } else {
        // We are currently outside the operating hours.
        // We can snap to the most recent logical session
        if (now.hour < openingHour) {
          return DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 1));
        }
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
  /// Uses Firestore transaction to prevent duplicate invoice numbers across devices
  Future<String> getNextInvoiceNumber() async {
    final sessionDate = getCurrentSessionDate();
    final sessionId = getCurrentSessionId();

    try {
      // Use Firestore transaction for atomic counter increment
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final counterRef = FirebaseFirestore.instance
            .collection('cafes')
            .doc(user.uid)
            .collection('counters')
            .doc(sessionId);

        // Get actual actual order count for the session (self-healing for the bug)
        final sessionStart = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          openingHour,
        );

        DateTime sessionEnd;
        if (closingHour <= openingHour) {
          sessionEnd = DateTime(
            sessionDate.year,
            sessionDate.month,
            sessionDate.day,
            closingHour,
          ).add(const Duration(days: 1));
        } else {
          sessionEnd = DateTime(
            sessionDate.year,
            sessionDate.month,
            sessionDate.day,
            closingHour,
          );
        }
        final localCount =
            await (_db.select(_db.orders)
                  ..where(
                    (tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart),
                  )
                  ..where(
                    (tbl) => tbl.createdAt.isSmallerThanValue(sessionEnd),
                  ))
                .get()
                .then((list) => list.length);

        final result = await FirebaseFirestore.instance.runTransaction((
          transaction,
        ) async {
          final snapshot = await transaction.get(counterRef);

          int nextNumber;
          if (!snapshot.exists || localCount == 0) {
            // First order of the session (or self-heal if local count is 0)
            nextNumber = 1001;
            transaction.set(counterRef, {
              'count': nextNumber,
              'sessionDate': sessionDate.toIso8601String(),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          } else {
            // Self-heal: Ensure count is not lower than actual orders + 1000
            final currentCount = snapshot.data()?['count'] ?? 1000;
            nextNumber = currentCount + 1;
            transaction.update(counterRef, {
              'count': nextNumber,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }

          return nextNumber;
        });

        return '#$result';
      }
    } catch (e) {
      debugPrint('⚠️ Firestore counter failed, falling back to local: $e');
    }

    // Fallback to local counting (legacy behavior for offline mode)
    final sessionStart = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      openingHour,
    );

    DateTime sessionEnd;
    if (closingHour <= openingHour) {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      ).add(const Duration(days: 1));
    } else {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      );
    }

    final query = _db.select(_db.orders)
      ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart))
      ..where((tbl) => tbl.createdAt.isSmallerThanValue(sessionEnd));

    final count = await query.get();
    final nextNumber = 1001 + count.length;
    return '#$nextNumber';
  }

  /// Peek at the next invoice number for current session without incrementing it
  /// Used for UI display purposes to prevent burning sequence numbers on rebuilds
  Future<String> peekNextInvoiceNumber() async {
    final sessionDate = getCurrentSessionDate();
    final sessionId = getCurrentSessionId();

    try {
      final sessionStart = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        openingHour,
      );

      DateTime sessionEnd;
      if (closingHour <= openingHour) {
        sessionEnd = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          closingHour,
        ).add(const Duration(days: 1));
      } else {
        sessionEnd = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          closingHour,
        );
      }

      final localCount =
          await (_db.select(_db.orders)
                ..where(
                  (tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStart),
                )
                ..where(
                  (tbl) => tbl.createdAt.isSmallerOrEqualValue(sessionEnd),
                ))
              .get()
              .then((list) => list.length);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final counterRef = FirebaseFirestore.instance
            .collection('cafes')
            .doc(user.uid)
            .collection('counters')
            .doc(sessionId);

        final snapshot = await counterRef.get();
        if (snapshot.exists) {
          final currentCount = snapshot.data()?['count'] ?? 1000;
          final nextNumber = currentCount + 1;
          return '#$nextNumber';
        }

        // If Firestore counter missing but we have local orders, derive from local.
        if (localCount > 0) {
          return '#${1000 + localCount + 1}';
        }

        // Fallback to max existing invoice that starts with '#' (covers previous completed orders)
        final maxInvoice =
            await (_db.selectOnly(_db.orders)
                  ..addColumns([_db.orders.invoiceNumber])
                  ..where(_db.orders.invoiceNumber.like('#%'))
                  ..orderBy([OrderingTerm.desc(_db.orders.invoiceNumber)])
                  ..limit(1))
                .getSingleOrNull();

        if (maxInvoice != null) {
          final inv = maxInvoice.read(_db.orders.invoiceNumber) ?? '';
          final digits = int.tryParse(inv.replaceAll(RegExp(r'[^0-9]'), ''));
          if (digits != null) {
            return '#${digits + 1}';
          }
        }

        return '#1001';
      }
    } catch (e) {
      debugPrint('⚠️ Firestore peek failed, falling back to local: $e');
    }

    // Fallback to local counting
    final sessionStartFallback = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      openingHour,
    );

    DateTime sessionEndFallback;
    if (closingHour <= openingHour) {
      sessionEndFallback = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      ).add(const Duration(days: 1));
    } else {
      sessionEndFallback = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      );
    }

    final query = _db.select(_db.orders)
      ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(sessionStartFallback))
      ..where((tbl) => tbl.createdAt.isSmallerThanValue(sessionEndFallback));

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
      openingHour,
    );

    DateTime sessionEnd;
    if (closingHour <= openingHour) {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      ).add(const Duration(days: 1));
    } else {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      );
    }

    // Show most recent orders (no session cut-off) to avoid empty dashboard edge cases
    return (_db.select(_db.orders)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(20))
        .watch();
  }

  /// Get session info (for display)
  Map<String, dynamic> getSessionInfo() {
    final now = DateTime.now();
    final sessionDate = getCurrentSessionDate();
    final nextSessionDate = sessionDate.add(const Duration(days: 1));

    DateTime sessionEnd;
    if (closingHour <= openingHour) {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      ).add(const Duration(days: 1));
    } else {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      );
    }

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
    DateTime sessionEnd;
    if (closingHour <= openingHour) {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      ).add(const Duration(days: 1));
    } else {
      sessionEnd = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        closingHour,
      );
    }

    return {
      'start': DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        openingHour,
      ),
      'end': sessionEnd,
    };
  }
}

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SessionManager(db, prefs);
});
