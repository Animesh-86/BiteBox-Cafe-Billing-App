import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/constants/customer_defaults.dart';
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
      // Replace local customers with cloud list
      await _db.batch((batch) {
        batch.deleteWhere(_db.customers, (t) => const Constant(true));
        batch.insertAll(
          _db.customers,
          list.map((e) => Customer.fromJson(e)).toList(),
          mode: InsertMode.insertOrReplace,
        );
      });
      // Re-seed default customers if missing
      for (final seed in CustomerDefaults.seeded) {
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
