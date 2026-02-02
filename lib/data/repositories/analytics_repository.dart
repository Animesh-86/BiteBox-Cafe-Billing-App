import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';

class AnalyticsRepository {
  final AppDatabase _db;

  AnalyticsRepository(this._db);

  Future<double> getTodaySales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.totalAmount.sum()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startOfDay));

    final result = await query.getSingle();
    return result.read(_db.orders.totalAmount.sum()) ?? 0.0;
  }

  Future<int> getTodayOrdersCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startOfDay));

    final result = await query.getSingle();
    return result.read(_db.orders.id.count()) ?? 0;
  }

  Future<int> getTotalItemsSold() async {
    final query = _db.selectOnly(_db.orderItems)
      ..addColumns([_db.orderItems.quantity.sum()]);

    final result = await query.getSingle();
    return result.read(_db.orderItems.quantity.sum()) ?? 0;
  }

  Future<int> getUniqueCustomersCount() async {
    final query = _db.selectOnly(_db.customers)
      ..addColumns([_db.customers.id.count()]);

    final result = await query.getSingle();
    return result.read(_db.customers.id.count()) ?? 0;
  }

  Future<List<MapEntry<String, double>>> getTopSellingItems() async {
    final query = _db.selectOnly(_db.orderItems)
      ..addColumns([_db.orderItems.itemName, _db.orderItems.quantity.sum()])
      ..groupBy([_db.orderItems.itemName])
      ..orderBy([
        OrderingTerm(
          expression: _db.orderItems.quantity.sum(),
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(5);

    final result = await query.get();

    return result.map((row) {
      return MapEntry(
        row.read(_db.orderItems.itemName) ?? "Unknown",
        (row.read(_db.orderItems.quantity.sum()) ?? 0).toDouble(),
      );
    }).toList();
  }

  Future<MapEntry<String, int>?> getMostOrderedItem() async {
    final query = _db.selectOnly(_db.orderItems)
      ..addColumns([_db.orderItems.itemName, _db.orderItems.quantity.sum()])
      ..groupBy([_db.orderItems.itemName])
      ..orderBy([
        OrderingTerm(
          expression: _db.orderItems.quantity.sum(),
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(1);

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return MapEntry(
      result.read(_db.orderItems.itemName) ?? "Unknown",
      result.read(_db.orderItems.quantity.sum()) ?? 0,
    );
  }

  Future<Order?> getHighestValueOrder() async {
    final query = _db.select(_db.orders)
      ..orderBy([
        (t) => OrderingTerm(expression: t.totalAmount, mode: OrderingMode.desc),
      ])
      ..limit(1);

    return await query.getSingleOrNull();
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(appDatabaseProvider));
});
