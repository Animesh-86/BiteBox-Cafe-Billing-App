import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/db/app_database.dart';
import '../providers/database_provider.dart';

class CustomerRepository {
  final AppDatabase _db;

  CustomerRepository(this._db);

  Stream<List<Customer>> watchCustomers(String query) {
    if (query.isEmpty) {
      return (_db.select(_db.customers)..orderBy([
            (t) =>
                OrderingTerm(expression: t.lastVisit, mode: OrderingMode.desc),
          ]))
          .watch();
    }
    return (_db.select(
          _db.customers,
        )..where((tbl) => tbl.name.contains(query) | tbl.phone.contains(query)))
        .watch();
  }

  Future<Customer?> getCustomerById(String id) {
    return (_db.select(
      _db.customers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
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

  Future<void> addCustomer(CustomersCompanion customer) async {
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
  }

  Future<void> updateCustomer(Customer customer) {
    return _db.update(_db.customers).replace(customer);
  }

  Future<void> deleteCustomer(String id) {
    return (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateVisitStats(String id, double amount) async {
    // Transaction to update connection stats safely
    await _db.transaction(() async {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(id))).getSingle();
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
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomerRepository(db);
});
