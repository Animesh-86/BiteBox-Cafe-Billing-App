import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/database_provider.dart';

// Using simple Provider for now as we don't have riverpod_generator set up fully in this plan
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncRepository {
  final AppDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  SyncRepository(this._db, this._auth, this._firestore);

  Future<void> backupData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    // Fetch all data
    final categories = await _db.select(_db.categories).get();
    final items = await _db.select(_db.items).get();
    final customers = await _db.select(_db.customers).get();
    final orders = await _db.select(_db.orders).get();
    final orderItems = await _db.select(_db.orderItems).get();

    // Upload to Firestore
    // Using a single document for simplicity unless size is huge.
    // For a small cafe, this might suffice initially.
    // Better: Subcollections. But explicit requirement: "Backup".
    // "Store Orders, Customers, Menu snapshot..."
    // Let's use collections for scalability.
    final baseRef = _firestore.collection('cafes').doc(user.uid);

    // We can't batch set ALL docs if there are thousands.
    // Manual Sync usually implies incremental or full dump.
    // For "Backup", let's use a subcollection `backups` with a single large JSON doc
    // OR just updating the current state tables.
    // Let's go with updating current state tables in Firestore (Mirroring).

    // BUT, Firestore writes cost money. "Cost-safe".
    // "No per-action writes".
    // So "Sync Now" -> Bulk write.
    // 500 writes limit per batch.

    // Efficient strategy: Dump JSON to Firebase Storage?
    // "Store PDF in Firebase Storage". user request said: "Store: Orders, Customers, Menu snapshot".
    // Firestore is usually for querying.
    // If we only need "Restore", Storage is cheaper and better for "Backup".
    // BUT "Cloud-backed" implies we might want to see data on a web dashboard later (even if forbidden now).
    // Requirement says: "Firestore used ONLY for Auth, Backup". "Store Orders... in Firestore".
    // Let's stick to Firestore collections.

    // For cost safety and "Sync Now", we will overwrite/merge.
    // We will just upload changed data? We don't track "isDirty" easily yet (except `isSynced` flag in Orders).
    // Let's use `isSynced` flag for Orders.
    // For Menu/Customers, we just dump all? Menu is small. Customers can be large.

    // Simplified: Just dumping everything to a "backup" document or JSON buffer in a restricted collection.
    // Actually, let's use `isSynced` for Orders.

    final unsyncedOrders = orders.where((o) => !o.isSynced).toList();
    if (unsyncedOrders.isEmpty && categories.isEmpty)
      return; // Nothing to sync? (Menu changes not tracked with flag)

    // Let's just upload Menu every time (small).
    await baseRef.collection('menu').doc('categories').set({
      'list': categories.map((e) => e.toJson()).toList(),
    });
    await baseRef.collection('menu').doc('items').set({
      'list': items.map((e) => e.toJson()).toList(),
    });

    // Customers (All)
    await baseRef.collection('data').doc('customers').set({
      'list': customers.map((e) => e.toJson()).toList(),
    });

    // Orders - Only unsynced?
    // If we restore, we need ALL.
    // So we should upload ALL or append.
    // Appending is hard without dupes.
    // Simplest "Backup": Overwrite "orders_backup" doc.
    // If too large, we split.
    // For this MVP: Overwrite `data/orders`.
    await baseRef.collection('data').doc('orders').set({
      'list': orders.map((e) => e.toJson()).toList(),
    });
    await baseRef.collection('data').doc('order_items').set({
      'list': orderItems.map((e) => e.toJson()).toList(),
    });

    // Mark local as synced?
    // We are overwriting cloud with local (Source of Truth is Local).
    // So we don't strictly need to mark `isSynced`, but good practice.
    // await _db.update(_db.orders).write(const OrdersCompanion(isSynced: Value(true))); // Logic for specific IDs needed.
  }

  Future<void> restoreData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final baseRef = _firestore.collection('cafes').doc(user.uid);

    // Helper to fetch list
    Future<List<Map<String, dynamic>>> fetchList(String col, String doc) async {
      final s = await baseRef.collection(col).doc(doc).get();
      if (!s.exists || s.data() == null) return [];
      return List<Map<String, dynamic>>.from(s.data()!['list'] ?? []);
    }

    final categories = await fetchList('menu', 'categories');
    final items = await fetchList('menu', 'items');
    final customers = await fetchList('data', 'customers');
    final orders = await fetchList('data', 'orders');
    final orderItems = await fetchList('data', 'order_items');

    await _db.batch((batch) {
      batch.insertAll(
        _db.categories,
        categories.map((e) => Category.fromJson(e)),
        mode: InsertMode.insertOrReplace,
      );
      batch.insertAll(
        _db.items,
        items.map((e) => Item.fromJson(e)),
        mode: InsertMode.insertOrReplace,
      );
      batch.insertAll(
        _db.customers,
        customers.map((e) => Customer.fromJson(e)),
        mode: InsertMode.insertOrReplace,
      );
      batch.insertAll(
        _db.orders,
        orders.map((e) => Order.fromJson(e)),
        mode: InsertMode.insertOrReplace,
      );
      batch.insertAll(
        _db.orderItems,
        orderItems.map((e) => OrderItem.fromJson(e)),
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    ref.watch(appDatabaseProvider),
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});
