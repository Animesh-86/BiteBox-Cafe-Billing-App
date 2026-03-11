import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/db/app_database.dart';
import '../providers/database_provider.dart';
import 'package:hangout_spot/data/constants/customer_defaults.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';

class CustomerRepository {
  final AppDatabase _db;

  CustomerRepository(this._db);

  Stream<List<Customer>> watchCustomers(String query) {
    // Exclude platform/default customers (Walk-in, Zomato, Swiggy) from search
    // results — they are selected via dedicated chips, not the customer lookup.
    final platformIds = CustomerDefaults.seeded.map((s) => s.id).toList();
    if (query.isEmpty) {
      return (_db.select(_db.customers)
            ..where((t) => t.id.isNotIn(platformIds))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.lastVisit, mode: OrderingMode.desc),
            ]))
          .watch();
    }
    return (_db.select(_db.customers)
          ..where(
            (tbl) =>
                tbl.id.isNotIn(platformIds) &
                (tbl.name.contains(query) | tbl.phone.contains(query)),
          ))
        .watch();
  }

  Future<Customer?> getCustomerById(String id) {
    return (_db.select(
      _db.customers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Customer?> watchCustomerById(String id) {
    return (_db.select(
      _db.customers,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<Customer?> getCustomerByPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return (_db.select(
      _db.customers,
    )..where((t) => t.phone.equals(trimmed))).getSingleOrNull();
  }

  Future<Customer?> getCustomerByName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return (_db.select(
      _db.customers,
    )..where((t) => t.name.equals(trimmed))).getSingleOrNull();
  }

  Future<void> addCustomer(
    CustomersCompanion customer, {
    SyncRepository? syncRepo,
  }) async {
    // Check for duplicate phone number before inserting
    if (customer.phone.present && customer.phone.value != null) {
      final phoneValue = customer.phone.value!;
      final existing = await (_db.select(
        _db.customers,
      )..where((t) => t.phone.equals(phoneValue))).getSingleOrNull();

      if (existing != null) {
        throw Exception('Customer with phone $phoneValue already exists');
      }
    }
    await _db.into(_db.customers).insert(customer);
    syncRepo?.syncCustomersNow(); // immediately propagate to other devices
  }

  Future<void> updateCustomer(
    Customer customer, {
    SyncRepository? syncRepo,
  }) async {
    // Check for duplicate phone when phone is being changed
    if (customer.phone != null && customer.phone!.isNotEmpty) {
      final existing = await (_db.select(_db.customers)
            ..where((t) => t.phone.equals(customer.phone!))
            ..where((t) => t.id.isNotValue(customer.id)))
          .getSingleOrNull();
      if (existing != null) {
        throw Exception(
          'Phone ${customer.phone} is already used by ${existing.name}',
        );
      }
    }
    await _db.update(_db.customers).replace(customer);
    syncRepo?.syncCustomersNow();
  }

  Future<void> deleteCustomer(String id, {SyncRepository? syncRepo}) async {
    if (CustomerDefaults.seeded.any((c) => c.id == id)) {
      throw Exception('Default customers cannot be deleted');
    }
    // ISSUE-05 fix: delete orphaned reward transactions atomically with the
    // customer row so no ghost balance streams persist after deletion.
    await _db.transaction(() async {
      await (_db.delete(_db.rewardTransactions)
            ..where((t) => t.customerId.equals(id)))
          .go();
      await (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
    });
    syncRepo?.syncCustomersNow();
  }

  Future<void> ensureDefaultCustomers() async {
    for (final seed in CustomerDefaults.seeded) {
      final existing = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(seed.id))).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.customers)
            .insert(
              CustomersCompanion(
                id: Value(seed.id),
                name: Value(seed.name),
                phone: const Value(null),
                discountPercent: const Value(0.0),
                totalVisits: const Value(0),
                totalSpent: const Value(0.0),
                lastVisit: const Value(null),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    }
  }

  Future<void> updateVisitStats(
    String id,
    double amount, {
    SyncRepository? syncRepo,
  }) async {
    // Transaction to update connection stats safely
    await _db.transaction(() async {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (customer == null) return; // deleted mid-transaction, skip gracefully
      final newVisits = customer.totalVisits + 1;
      final newSpent = customer.totalSpent + amount;

      await _db
          .update(_db.customers)
          .replace(
            customer.copyWith(
              totalVisits: newVisits,
              totalSpent: newSpent,
              lastVisit: Value(DateTime.now()),
            ),
          );
    });
    syncRepo?.syncCustomersNow();
  }

  Future<void> revertVisitStats(
    String id,
    double amount, {
    SyncRepository? syncRepo,
  }) async {
    // Transaction to securely deduct connection stats safely
    await _db.transaction(() async {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (customer == null) return;

      final newVisits = customer.totalVisits > 0 ? customer.totalVisits - 1 : 0;
      final newSpent = customer.totalSpent >= amount
          ? customer.totalSpent - amount
          : 0.0;
      // Clear lastVisit when no visits remain so the field stays accurate
      final newLastVisit = newVisits == 0 ? const Value<DateTime?>(null) : Value<DateTime?>(customer.lastVisit);

      await _db
          .update(_db.customers)
          .replace(
            customer.copyWith(
              totalVisits: newVisits,
              totalSpent: newSpent,
              lastVisit: newLastVisit,
            ),
          );
    });
    syncRepo?.syncCustomersNow();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomerRepository(db);
});

/// Live stream of a single customer by ID — updates whenever the row changes.
final customerByIdStreamProvider =
    StreamProvider.family<Customer?, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).watchCustomerById(id);
});
