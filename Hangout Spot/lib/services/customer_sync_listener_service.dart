import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/constants/customer_defaults.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/utils/log_utils.dart';

/// Listens to Firestore customer changes and updates local DB in real-time
class CustomerSyncListenerService {
  final AppDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription? _sub;

  CustomerSyncListenerService(this._db, this._auth, this._firestore);

  void start() {
    final user = _auth.currentUser;
    if (user == null) {
      logDebug('❌ CustomerSyncListener: User not logged in');
      return;
    }
    final docRef = _firestore
        .collection('cafes')
        .doc(user.uid)
        .collection('data')
        .doc('customers');
    _sub?.cancel();
    _sub = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) return;
      final list = List<Map<String, dynamic>>.from(
        snapshot.data()!['list'] ?? [],
      );
      logDebug(
        '🔄 CustomerSyncListener: Received ${list.length} customers from Firestore',
      );

      // BUG-35: Replace batch delete-all + re-insert with per-customer upsert
      // that preserves the higher of local vs cloud stats. This prevents the
      // race where the listener fires between updateCustomerStats writing to
      // local DB and syncCustomersNow() pushing the fresh data to Firestore,
      // which would roll back the local stats to the previous cloud values.
      for (final e in list) {
        final cloudCustomer = Customer.fromJson(e);
        final local = await (_db.select(_db.customers)
              ..where((t) => t.id.equals(cloudCustomer.id)))
            .getSingleOrNull();

        // Always keep whichever value is larger so a freshly-written local
        // stat is never overwritten by an older cloud snapshot.
        final maxVisits = math.max(
          cloudCustomer.totalVisits,
          local?.totalVisits ?? 0,
        );
        final maxSpent = math.max(
          cloudCustomer.totalSpent,
          local?.totalSpent ?? 0.0,
        );
        final latestVisit = _laterOf(cloudCustomer.lastVisit, local?.lastVisit);

        await _db.into(_db.customers).insertOnConflictUpdate(
          CustomersCompanion(
            id: Value(cloudCustomer.id),
            name: Value(cloudCustomer.name),
            phone: Value(cloudCustomer.phone),
            discountPercent: Value(cloudCustomer.discountPercent),
            totalVisits: Value(maxVisits),
            totalSpent: Value(maxSpent),
            lastVisit: Value(latestVisit),
          ),
        );
      }

      // Remove customers that were deleted on another device (absent from
      // cloud list), but never remove the seeded defaults or do a mass-delete
      // if the cloud list arrives empty (e.g. transient read failure).
      final cloudIds = list.map((e) => e['id'] as String).toSet();
      final seededIds = CustomerDefaults.seeded.map((s) => s.id).toSet();
      if (cloudIds.isNotEmpty) {
        await (_db.delete(_db.customers)
              ..where((t) => t.id.isNotIn([...cloudIds, ...seededIds])))
            .go();
      }

      // Re-seed default customers (Walk-in, Zomato, Swiggy) ONLY if they
      // were not present in the cloud list, so we never overwrite cloud stats.
      for (final seed in CustomerDefaults.seeded) {
        if (cloudIds.contains(seed.id)) continue; // already in cloud, skip
        await _db
            .into(_db.customers)
            .insertOnConflictUpdate(
              CustomersCompanion(
                id: Value(seed.id),
                name: Value(seed.name),
                phone: const Value(null),
                discountPercent: const Value(0.0),
                totalVisits: const Value(0),
                totalSpent: const Value(0.0),
                lastVisit: const Value(null),
              ),
            );
      }
      logDebug('✅ CustomerSyncListener: Local DB updated');
    });
    logDebug('👂 CustomerSyncListener: Listening for Firestore changes');
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    logDebug('🛑 CustomerSyncListener: Stopped');
  }

  /// Returns whichever DateTime is later, or the non-null one if only one exists.
  static DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}

final customerSyncListenerServiceProvider =
    Provider<CustomerSyncListenerService>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final service = CustomerSyncListenerService(db, auth, firestore);
      ref.onDispose(() => service.stop());
      return service;
    });
