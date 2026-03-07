import 'package:hangout_spot/utils/log_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/local/db/menu_seeder.dart';
import 'package:hangout_spot/data/constants/customer_defaults.dart';
import 'package:drift/drift.dart';
import '../providers/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Keys for SharedPreferences that should be backed up to the cloud.
const _backupPrefKeys = [
  'store_name',
  'store_address',
  'store_phone',
  'store_email',
  'store_logo',
  'store_logo_url',
  'receipt_footer',
  'receipt_show_thank_you',
  'bill_whatsapp_enabled',
  'cloud_auto_sync_enabled',
  'cloud_auto_sync_interval_mins',
  'promo_enabled',
  'promo_title',
  'promo_discount',
  'promo_bundle_ids',
  'promo_start_iso',
  'promo_end_iso',
  'reward_feature_enabled',
  'reward_earning_rate',
  'reward_redemption_rate',
  'last_active_outlet_id',
  // Operating hours (shift window) so all devices share the same timing
  'opening_hour',
  'closing_hour',
];

class SyncRepository {
  final AppDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  SyncRepository(this._db, this._auth, this._firestore);

  // ─── BACKUP ────────────────────────────────────────────────────────────────

  /// Backs up non-order data (menu, customers, config, prefs).
  /// Orders are pushed individually by OrderRepository; this method
  /// only syncs bounded/static datasets that fit comfortably in a single
  /// Firestore document (<1 MB each).
  Future<bool> backupData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      // Fetch bounded data from local database (exclude soft-deleted)
      final categories = await (_db.select(
        _db.categories,
      )..where((t) => t.isDeleted.equals(false))).get();
      final items = await (_db.select(
        _db.items,
      )..where((t) => t.isDeleted.equals(false))).get();
      final customers = await _db.select(_db.customers).get();
      final locations = await _db.select(_db.locations).get();
      final settings = await _db.select(_db.settings).get();
      final rewardTransactions = await _db.select(_db.rewardTransactions).get();

      final baseRef = _firestore.collection('cafes').doc(user.uid);
      final batch = _firestore.batch();

      void addToBatch(String col, String doc, List<dynamic> list) {
        batch.set(baseRef.collection(col).doc(doc), {
          'list': list.map((e) => e.toJson()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Menu
      addToBatch('menu', 'categories', categories);
      addToBatch('menu', 'items', items);

      // Customers — merge with cloud to preserve entries from other devices
      // (fetch cloud list, union by ID with local winning on conflicts)
      try {
        final cloudCustDoc = await baseRef
            .collection('data')
            .doc('customers')
            .get();
        final cloudCustList = cloudCustDoc.exists
            ? List<Map<String, dynamic>>.from(
                cloudCustDoc.data()!['list'] ?? [],
              )
            : <Map<String, dynamic>>[];

        final mergedMap = <String, Map<String, dynamic>>{};
        for (final c in cloudCustList) {
          final id = c['id'] as String?;
          if (id != null) mergedMap[id] = c;
        }
        // Local entries overwrite cloud on conflict (local is fresher)
        for (final c in customers) {
          mergedMap[c.id] = c.toJson();
        }

        batch.set(baseRef.collection('data').doc('customers'), {
          'list': mergedMap.values.toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Fallback to simple overwrite if merge fails
        logDebug('⚠️ Customer merge failed, falling back to overwrite: $e');
        addToBatch('data', 'customers', customers);
      }

      // Config
      addToBatch('config', 'locations', locations);
      addToBatch('config', 'settings', settings);

      // Loyalty
      addToBatch('loyalty', 'reward_transactions', rewardTransactions);

      await batch.commit();

      // Backup SharedPreferences (outside batch – single doc, idempotent)
      await _backupSharedPreferences(baseRef);

      return true;
    } catch (e) {
      logDebug('Backup failed: $e');
      return false;
    }
  }

  /// Persist selected SharedPreferences keys to Firestore.
  Future<void> _backupSharedPreferences(DocumentReference baseRef) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> prefsMap = {};
      for (final key in _backupPrefKeys) {
        final value = prefs.getString(key);
        if (value != null) prefsMap[key] = value;
        // Also check bool values
        final boolValue = prefs.getBool(key);
        if (boolValue != null) prefsMap[key] = boolValue.toString();
      }
      if (prefsMap.isNotEmpty) {
        await baseRef.collection('config').doc('preferences').set({
          'data': prefsMap,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      logDebug('⚠️ SharedPreferences backup failed: $e');
    }
  }

  // ─── RESTORE ───────────────────────────────────────────────────────────────

  Future<void> restoreData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final baseRef = _firestore.collection('cafes').doc(user.uid);

      // Helper to fetch array-based document
      Future<List<Map<String, dynamic>>> fetchList(
        String col,
        String doc,
      ) async {
        final s = await baseRef.collection(col).doc(doc).get();
        if (!s.exists || s.data() == null) return [];
        return List<Map<String, dynamic>>.from(s.data()!['list'] ?? []);
      }

      // Fetch bounded data from array-based docs
      final categories = await fetchList('menu', 'categories');
      final items = await fetchList('menu', 'items');
      final customers = await fetchList('data', 'customers');
      final locations = await fetchList('config', 'locations');
      final settings = await fetchList('config', 'settings');
      final rewardTransactions = await fetchList(
        'loyalty',
        'reward_transactions',
      );

      // Fetch orders from INDIVIDUAL documents (scalable approach)
      final orderDocs = await baseRef.collection('orders').get();
      final List<Map<String, dynamic>> orders = [];
      final List<Map<String, dynamic>> orderItemsList = [];

      for (final doc in orderDocs.docs) {
        final data = doc.data();
        orders.add(data);
        // Extract embedded items from each order document
        final embeddedItems = data['items'] as List<dynamic>?;
        if (embeddedItems != null) {
          for (final item in embeddedItems) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            itemMap['orderId'] = data['id'];
            // Generate id if missing (old Firestore data didn't include it)
            itemMap['id'] ??= const Uuid().v4();
            orderItemsList.add(itemMap);
          }
        }
      }

      // Fallback: if no individual order docs found, try legacy array
      if (orders.isEmpty) {
        logDebug('📖 No individual order docs found – trying legacy array…');
        final legacyOrders = await fetchList('data', 'orders');
        orders.addAll(legacyOrders);
        final legacyItems = await fetchList('data', 'order_items');
        orderItemsList.addAll(legacyItems);
      }

      // Clear ALL local data before restore so deleted items/categories
      // on one device don't persist as ghosts on another (Bug 4 fix).
      logDebug('🧹 Clearing all local data before restore...');
      await _db.batch((batch) {
        batch.deleteWhere(_db.categories, (t) => const Constant(true));
        batch.deleteWhere(_db.items, (t) => const Constant(true));
        batch.deleteWhere(_db.customers, (t) => const Constant(true));
        batch.deleteWhere(_db.orders, (t) => const Constant(true));
        batch.deleteWhere(_db.orderItems, (t) => const Constant(true));
        batch.deleteWhere(_db.rewardTransactions, (t) => const Constant(true));
        batch.deleteWhere(_db.locations, (t) => const Constant(true));
        batch.deleteWhere(_db.settings, (t) => const Constant(true));
      });

      // Insert clean data from cloud in safe-sized batches (≤500 rows each)
      // Each record is parsed individually so one bad JSON doesn't crash the
      // entire restore — bad records are skipped with a warning.
      logDebug('📥 Inserting fresh data from cloud...');

      int skipped = 0;

      List<T> _safeParse<T>(
        List<Map<String, dynamic>> list,
        T Function(Map<String, dynamic>) fromJson,
        String label,
      ) {
        final result = <T>[];
        for (final e in list) {
          try {
            result.add(fromJson(e));
          } catch (err) {
            skipped++;
            logDebug('⚠️ Skipping malformed $label record: $err');
          }
        }
        return result;
      }

      // Deduplicate cloud categories/items before inserting
      final dedupedCategories = <Map<String, dynamic>>[];
      final seenCatNames = <String>{};
      for (final c in categories) {
        final name = (c['name'] as String? ?? '')
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        final isDeleted = c['isDeleted'] == true || c['is_deleted'] == true;
        if (!isDeleted && seenCatNames.add(name)) {
          dedupedCategories.add(c);
        }
      }

      final dedupedItems = <Map<String, dynamic>>[];
      final seenItemKeys = <String>{};
      for (final it in items) {
        final catId =
            it['categoryId'] as String? ?? it['category_id'] as String? ?? '';
        final name = (it['name'] as String? ?? '')
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        final isDeleted = it['isDeleted'] == true || it['is_deleted'] == true;
        final key = '$catId|$name';
        if (!isDeleted && seenItemKeys.add(key)) {
          dedupedItems.add(it);
        }
      }

      await _db.batch((batch) {
        batch.insertAll(
          _db.categories,
          _safeParse(dedupedCategories, Category.fromJson, 'category'),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.items,
          _safeParse(dedupedItems, Item.fromJson, 'item'),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.customers,
          _safeParse(customers, Customer.fromJson, 'customer'),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.locations,
          _safeParse(locations, Location.fromJson, 'location'),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.settings,
          _safeParse(settings, Setting.fromJson, 'setting'),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.rewardTransactions,
          _safeParse(
            rewardTransactions,
            RewardTransaction.fromJson,
            'rewardTransaction',
          ),
          mode: InsertMode.insertOrReplace,
        );
      });

      // Insert orders in chunks of 200 to avoid overwhelming SQLite
      final parsedOrders = _safeParse(orders, Order.fromJson, 'order');
      for (var i = 0; i < parsedOrders.length; i += 200) {
        final chunk = parsedOrders.skip(i).take(200).toList();
        await _db.batch((batch) {
          batch.insertAll(_db.orders, chunk, mode: InsertMode.insertOrReplace);
        });
      }

      // Insert order items in chunks of 200
      final parsedItems = _safeParse(
        orderItemsList,
        OrderItem.fromJson,
        'orderItem',
      );
      for (var i = 0; i < parsedItems.length; i += 200) {
        final chunk = parsedItems.skip(i).take(200).toList();
        await _db.batch((batch) {
          batch.insertAll(
            _db.orderItems,
            chunk,
            mode: InsertMode.insertOrReplace,
          );
        });
      }

      if (skipped > 0) {
        logDebug('⚠️ Restore completed with $skipped skipped records');
      }

      // Deduplicate categories & items that may exist in the cloud data
      await MenuSeeder.deduplicateAll(_db);

      // Re-seed default customers (Walk-in, Zomato, Swiggy) in case cloud
      // data didn't include them
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

      // Restore SharedPreferences from cloud
      await _restoreSharedPreferences(baseRef);

      await Future.delayed(const Duration(milliseconds: 100));
      logDebug('✅ Data restored successfully and streams refreshed');
    } catch (e) {
      logDebug(
        'Restore failed (Firestore may not be configured or no backup exists): $e',
      );
      throw Exception('Restore failed: $e');
    }
  }

  /// Restore saved SharedPreferences from Firestore.
  Future<void> _restoreSharedPreferences(DocumentReference baseRef) async {
    try {
      final doc = await baseRef.collection('config').doc('preferences').get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!['data'] as Map<String, dynamic>?;
      if (data == null || data.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        await prefs.setString(entry.key, entry.value.toString());
      }
      logDebug('✅ SharedPreferences restored (${data.length} keys)');
    } catch (e) {
      logDebug('⚠️ SharedPreferences restore failed: $e');
    }
  }

  // ─── CLEAR LOCAL ───────────────────────────────────────────────────────────

  /// Clears transactional & config data but PRESERVES menu (categories/items)
  Future<void> clearLocalData() async {
    logDebug('🗑️ Starting data deletion...');

    await _db.batch((batch) {
      batch.deleteWhere(_db.customers, (t) => const Constant(true));
      batch.deleteWhere(_db.orders, (t) => const Constant(true));
      batch.deleteWhere(_db.orderItems, (t) => const Constant(true));
      batch.deleteWhere(_db.rewardTransactions, (t) => const Constant(true));
      batch.deleteWhere(_db.syncLogs, (t) => const Constant(true));
      batch.deleteWhere(_db.locations, (t) => const Constant(true));
      batch.deleteWhere(_db.settings, (t) => const Constant(true));
    });

    logDebug('✅ Batch deletion completed');

    final remainingOrders = await (_db.select(_db.orders).get());
    final remainingCustomers = await (_db.select(_db.customers).get());
    logDebug('📊 Remaining orders: ${remainingOrders.length}');
    logDebug('📊 Remaining customers: ${remainingCustomers.length}');

    // Re-seed default outlet
    await _db
        .into(_db.locations)
        .insert(
          LocationsCompanion(
            id: const Value('default-outlet-001'),
            name: const Value('Hangout Spot'),
            address: const Value('Kanha Dreamland'),
            phoneNumber: const Value(''),
            isActive: const Value(true),
            createdAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
    logDebug('✅ Default outlet re-seeded: Hangout Spot – Kanha Dreamland');

    await _db
        .into(_db.settings)
        .insert(
          SettingsCompanion(
            key: const Value('current_location_id'),
            value: const Value('default-outlet-001'),
            description: const Value('ID of the currently active outlet'),
          ),
          mode: InsertMode.insertOrReplace,
        );
    logDebug('✅ Default location setting re-seeded');

    await Future.delayed(const Duration(milliseconds: 200));
    logDebug('✅ Local data cleared and streams refreshed');

    // Clear promo & outlet SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    for (final key in _backupPrefKeys) {
      await prefs.remove(key);
    }
    await prefs.remove('last_active_outlet_id');

    // Clear persisted cart state
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('cart_state_v1_') || key == 'cart_state_temp') {
        await prefs.remove(key);
      }
    }

    await prefs.setString('last_active_outlet_id', 'default-outlet-001');
    logDebug('✅ Set default outlet as active in preferences');
  }

  // ─── DELETE CLOUD ──────────────────────────────────────────────────────────

  /// Deletes ALL cloud data EXCEPT menu (categories/items are preserved)
  Future<void> deleteCloudData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final baseRef = _firestore.collection('cafes').doc(user.uid);

      Future<void> deleteCollectionDocs(
        CollectionReference<Map<String, dynamic>> col,
      ) async {
        // Delete in batches of 400 to stay under Firestore batch limits
        QuerySnapshot<Map<String, dynamic>> snapshot;
        do {
          snapshot = await col.limit(400).get();
          if (snapshot.docs.isEmpty) break;
          final batch = _firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } while (snapshot.docs.length == 400);
      }

      // Delete transactional array-based data
      final dataRef = baseRef.collection('data');
      await dataRef.doc('customers').delete();
      await dataRef.doc('orders').delete();
      await dataRef.doc('order_items').delete();

      // Delete individual order documents (scalable batch delete)
      await deleteCollectionDocs(baseRef.collection('orders'));

      // Delete config (outlets, settings, preferences) — menu/* kept
      final configRef = baseRef.collection('config');
      await configRef.doc('locations').delete();
      await configRef.doc('settings').delete();
      await configRef.doc('preferences').delete();

      // Delete loyalty data
      await baseRef.collection('loyalty').doc('reward_transactions').delete();

      // Delete session counters so order numbers reset to #1001
      await deleteCollectionDocs(baseRef.collection('counters'));

      // Delete inventory collections (cloud-only data)
      await deleteCollectionDocs(baseRef.collection('inventory_items'));
      await deleteCollectionDocs(baseRef.collection('inventory_daily'));
      await deleteCollectionDocs(baseRef.collection('inventory_movements'));
      await deleteCollectionDocs(baseRef.collection('inventory_reminders'));
      await deleteCollectionDocs(baseRef.collection('platform_orders'));

      // Delete base document
      await baseRef.delete();

      logDebug('✅ Cloud data deleted (menu preserved)');
    } catch (e) {
      logDebug('Delete cloud data failed: $e');
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
