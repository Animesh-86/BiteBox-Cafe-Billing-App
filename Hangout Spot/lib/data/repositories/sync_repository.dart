import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Using simple Provider for now as we don't have riverpod_generator set up fully in this plan
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncRepository {
  final AppDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  SyncRepository(this._db, this._auth, this._firestore);

  Future<bool> backupData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      // Fetch all data from local database
      final categories = await _db.select(_db.categories).get();
      final items = await _db.select(_db.items).get();
      final customers = await _db.select(_db.customers).get();
      final orders = await _db.select(_db.orders).get();
      final orderItems = await _db.select(_db.orderItems).get();

      // NEW: Fetch additional data types
      final locations = await _db.select(_db.locations).get();
      // Removed tables as feature is deprecated
      final settings = await _db.select(_db.settings).get();
      final rewardTransactions = await _db.select(_db.rewardTransactions).get();

      final baseRef = _firestore.collection('cafes').doc(user.uid);
      final batch = _firestore.batch(); // ATOMIC BATCH START

      // Helper to add to batch
      void addToBatch(String col, String doc, List<dynamic> list) {
        batch.set(baseRef.collection(col).doc(doc), {
          'list': list.map((e) => e.toJson()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Upload Menu data
      addToBatch('menu', 'categories', categories);
      addToBatch('menu', 'items', items);

      // Upload Customer data
      addToBatch('data', 'customers', customers);

      // Upload Order data
      addToBatch('data', 'orders', orders);
      addToBatch('data', 'order_items', orderItems);

      // Upload Locations/Outlets data
      addToBatch('config', 'locations', locations);

      // Upload Settings data
      addToBatch('config', 'settings', settings);

      // Upload Reward Transactions data
      addToBatch('loyalty', 'reward_transactions', rewardTransactions);

      await batch.commit(); // ATOMIC COMMIT

      return true;
    } catch (e) {
      // Firestore not set up or other error - fail silently and return false
      print('Backup failed (Firestore may not be configured): $e');
      return false;
    }
  }

  Future<void> restoreData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final baseRef = _firestore.collection('cafes').doc(user.uid);

      // Helper to fetch list
      Future<List<Map<String, dynamic>>> fetchList(
        String col,
        String doc,
      ) async {
        final s = await baseRef.collection(col).doc(doc).get();
        if (!s.exists || s.data() == null) return [];
        return List<Map<String, dynamic>>.from(s.data()!['list'] ?? []);
      }

      final categories = await fetchList('menu', 'categories');
      final items = await fetchList('menu', 'items');
      final customers = await fetchList('data', 'customers');
      final orders = await fetchList('data', 'orders');
      final orderItems = await fetchList('data', 'order_items');

      // NEW: Fetch missing data (Tables excluded as unused)
      final locations = await fetchList('config', 'locations');
      final settings = await fetchList('config', 'settings');
      final rewardTransactions = await fetchList(
        'loyalty',
        'reward_transactions',
      );

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

        // NEW: Insert missing data (Tables excluded)
        batch.insertAll(
          _db.locations,
          locations.map((e) => Location.fromJson(e)),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.settings,
          settings.map((e) => Setting.fromJson(e)),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.rewardTransactions,
          rewardTransactions.map((e) => RewardTransaction.fromJson(e)),
          mode: InsertMode.insertOrReplace,
        );
      });
    } catch (e) {
      // Firestore not set up or no data to restore - fail silently
      print(
        'Restore failed (Firestore may not be configured or no backup exists): $e',
      );
      throw Exception('Restore failed: $e');
    }
  }

  /// Clears transactional & config data but PRESERVES menu (categories/items)
  Future<void> clearLocalData() async {
    await _db.batch((batch) {
      // Transactional data
      batch.deleteWhere(_db.customers, (t) => const Constant(true));
      batch.deleteWhere(_db.orders, (t) => const Constant(true));
      batch.deleteWhere(_db.orderItems, (t) => const Constant(true));
      batch.deleteWhere(_db.rewardTransactions, (t) => const Constant(true));
      batch.deleteWhere(_db.syncLogs, (t) => const Constant(true));

      // Config data (outlets, settings) — menu is intentionally preserved
      batch.deleteWhere(_db.locations, (t) => const Constant(true));
      batch.deleteWhere(_db.settings, (t) => const Constant(true));

      // NOTE: categories and items are NOT deleted (menu is preserved)
    });

    // Also clear promo & outlet SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('promo_enabled');
    await prefs.remove('promo_title');
    await prefs.remove('promo_discount');
    await prefs.remove('promo_bundle_ids');
    await prefs.remove('promo_start_iso');
    await prefs.remove('promo_end_iso');
    await prefs.remove('last_active_outlet_id');
  }

  /// Deletes all cloud data EXCEPT menu (categories/items are preserved)
  Future<void> deleteCloudData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final baseRef = _firestore.collection('cafes').doc(user.uid);

      // Delete transactional data
      final dataRef = baseRef.collection('data');
      await dataRef.doc('customers').delete();
      await dataRef.doc('orders').delete();
      await dataRef.doc('order_items').delete();

      // Delete config (outlets, settings) — menu/* is intentionally kept
      final configRef = baseRef.collection('config');
      await configRef.doc('locations').delete();
      await configRef.doc('settings').delete();

      // Delete loyalty data
      final loyaltyRef = baseRef.collection('loyalty');
      await loyaltyRef.doc('reward_transactions').delete();

      // Delete base document
      await baseRef.delete();

      // NOTE: menu/categories and menu/items are NOT deleted
    } catch (e) {
      // Firestore not set up or already deleted - fail silently
      print('Delete cloud data failed (Firestore may not be configured): $e');
      // Don't throw - allow factory reset to continue with local deletion
    }
  }
}

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    ref.watch(appDatabaseProvider),
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});
