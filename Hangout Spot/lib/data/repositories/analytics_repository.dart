import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';

class AnalyticsRepository {
  final AppDatabase _db;

  AnalyticsRepository(this._db);

  Future<double> getTodaySales({String? locationId}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.totalAmount.sum()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startOfDay))
      ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    return result.read(_db.orders.totalAmount.sum()) ?? 0.0;
  }

  Future<double> getSessionSales(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.totalAmount.sum()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    return result.read(_db.orders.totalAmount.sum()) ?? 0.0;
  }

  Future<int> getTodayOrdersCount({String? locationId}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startOfDay))
      ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    return result.read(_db.orders.id.count()) ?? 0;
  }

  Future<int> getSessionOrdersCount(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    return result.read(_db.orders.id.count()) ?? 0;
  }

  Future<int> getTotalItemsSold({String? locationId}) async {
    final query =
        _db.selectOnly(_db.orderItems).join([
            innerJoin(
              _db.orders,
              _db.orders.id.equalsExp(_db.orderItems.orderId),
            ),
          ])
          ..addColumns([_db.orderItems.quantity.sum()])
          ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    return result.read(_db.orderItems.quantity.sum()) ?? 0;
  }

  Future<int> getSessionItemsSold(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query =
        _db.selectOnly(_db.orderItems).join([
            innerJoin(
              _db.orders,
              _db.orders.id.equalsExp(_db.orderItems.orderId),
            ),
          ])
          ..addColumns([_db.orderItems.quantity.sum()])
          ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
          ..where(_db.orders.createdAt.isSmallerThanValue(end))
          ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    return result.read(_db.orderItems.quantity.sum()) ?? 0;
  }

  Future<int> getUniqueCustomersCount({String? locationId}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final namedQuery = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.customerId.count(distinct: true)])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startOfDay))
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.customerId.isNotNull());

    if (locationId != null) {
      namedQuery.where(_db.orders.locationId.equals(locationId));
    }

    final namedResult = await namedQuery.getSingle();
    final namedCount =
        namedResult.read(_db.orders.customerId.count(distinct: true)) ?? 0;

    final walkInQuery = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startOfDay))
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.customerId.isNull());

    if (locationId != null) {
      walkInQuery.where(_db.orders.locationId.equals(locationId));
    }

    final walkInResult = await walkInQuery.getSingle();
    final walkInCount = walkInResult.read(_db.orders.id.count()) ?? 0;

    return namedCount + walkInCount;
  }

  Future<int> getSessionUniqueCustomersCount(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final namedQuery = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.customerId.count(distinct: true)])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.customerId.isNotNull());

    if (locationId != null) {
      namedQuery.where(_db.orders.locationId.equals(locationId));
    }

    final namedResult = await namedQuery.getSingle();
    final namedCount =
        namedResult.read(_db.orders.customerId.count(distinct: true)) ?? 0;

    final walkInQuery = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.customerId.isNull());

    if (locationId != null) {
      walkInQuery.where(_db.orders.locationId.equals(locationId));
    }

    final walkInResult = await walkInQuery.getSingle();
    final walkInCount = walkInResult.read(_db.orders.id.count()) ?? 0;

    return namedCount + walkInCount;
  }

  Future<List<MapEntry<String, double>>> getTopSellingItems({
    String? locationId,
  }) async {
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

    if (locationId != null) {
      // Join with orders to filter by location
      query.join([
        innerJoin(_db.orders, _db.orders.id.equalsExp(_db.orderItems.orderId)),
      ]);
      query.where(_db.orders.locationId.equals(locationId));
    }

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

  Future<double> getAverageOrderValue(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.totalAmount.sum(), _db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    final sum = result.read(_db.orders.totalAmount.sum()) ?? 0.0;
    final count = result.read(_db.orders.id.count()) ?? 0;
    if (count == 0) return 0.0;
    return sum / count;
  }

  Future<double> getAverageDailySales(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.totalAmount.sum()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final result = await query.getSingle();
    final sum = result.read(_db.orders.totalAmount.sum()) ?? 0.0;
    final days = end.difference(start).inDays + 1;
    if (days <= 0) return sum;
    return sum / days;
  }

  Future<Map<String, int>> getCustomerSegments(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String sql =
        "SELECT customer_id as customerId, COUNT(*) as orderCount "
        "FROM orders "
        "WHERE status = 'completed' AND customer_id IS NOT NULL "
        "AND created_at >= ? AND created_at < ? ";

    final variables = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];

    if (locationId != null) {
      sql += "AND location_id = ? ";
      variables.add(Variable.withString(locationId));
    }

    sql += "GROUP BY customer_id";

    final rows = await _db
        .customSelect(sql, variables: variables, readsFrom: {_db.orders})
        .get();

    int newCustomers = 0;
    int returningCustomers = 0;
    for (final row in rows) {
      final count = row.read<int>('orderCount') ?? 0;
      if (count <= 1) {
        newCustomers++;
      } else {
        returningCustomers++;
      }
    }

    return {
      'new': newCustomers,
      'returning': returningCustomers,
      'total': rows.length,
    };
  }

  Future<double> getRepeatCustomerRate(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final segments = await getCustomerSegments(
      start,
      end,
      locationId: locationId,
    );
    final total = segments['total'] ?? 0;
    if (total == 0) return 0.0;
    return (segments['returning'] ?? 0) / total;
  }

  Future<Map<String, double>> getDiscountImpact(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final discountedQuery = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.totalAmount.sum(), _db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.discountAmount.isBiggerThanValue(0));

    final nonDiscountedQuery = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.totalAmount.sum(), _db.orders.id.count()])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end))
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.discountAmount.equals(0));

    if (locationId != null) {
      discountedQuery.where(_db.orders.locationId.equals(locationId));
      nonDiscountedQuery.where(_db.orders.locationId.equals(locationId));
    }

    final discounted = await discountedQuery.getSingle();
    final nonDiscounted = await nonDiscountedQuery.getSingle();

    final discountedSum = discounted.read(_db.orders.totalAmount.sum()) ?? 0.0;
    final discountedCount = discounted.read(_db.orders.id.count()) ?? 0;
    final nonDiscountedSum =
        nonDiscounted.read(_db.orders.totalAmount.sum()) ?? 0.0;
    final nonDiscountedCount = nonDiscounted.read(_db.orders.id.count()) ?? 0;

    final discountedAvg = discountedCount == 0
        ? 0.0
        : discountedSum / discountedCount;
    final nonDiscountedAvg = nonDiscountedCount == 0
        ? 0.0
        : nonDiscountedSum / nonDiscountedCount;

    return {
      'discountedAvg': discountedAvg,
      'nonDiscountedAvg': nonDiscountedAvg,
    };
  }

  Future<List<MapEntry<int, double>>> getPeakHours(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.createdAt])
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final rows = await query.get();

    final hourCounts = <int, int>{};

    for (final row in rows) {
      final date = row.read(_db.orders.createdAt);
      if (date != null) {
        final hour = date.hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }
    }

    final sorted = hourCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted.map((e) => MapEntry(e.key, e.value.toDouble())).toList();
  }

  Future<List<MapEntry<String, double>>> getTopSellingItemsSince(
    DateTime start,
    DateTime end, {
    int limit = 5,
    String? locationId,
  }) async {
    String sql =
        "SELECT oi.item_name as name, SUM(oi.quantity) as qty "
        "FROM order_items oi "
        "INNER JOIN orders o ON o.id = oi.order_id "
        "WHERE o.status = 'completed' AND o.created_at >= ? AND o.created_at < ? ";

    final variables = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];

    if (locationId != null) {
      sql += "AND o.location_id = ? ";
      variables.add(Variable.withString(locationId));
    }

    sql +=
        "GROUP BY oi.item_name "
        "ORDER BY qty DESC "
        "LIMIT $limit";

    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();

    return rows.map((row) {
      final name = row.read<String>('name') ?? 'Unknown';
      final qty = (row.read<int>('qty') ?? 0).toDouble();
      return MapEntry(name, qty);
    }).toList();
  }

  Future<List<MapEntry<String, double>>> getLowSellingItemsSince(
    DateTime start,
    DateTime end, {
    int limit = 5,
    String? locationId,
  }) async {
    String sql =
        "SELECT oi.item_name as name, SUM(oi.quantity) as qty "
        "FROM order_items oi "
        "INNER JOIN orders o ON o.id = oi.order_id "
        "WHERE o.status = 'completed' AND o.created_at >= ? AND o.created_at < ? ";

    final variables = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];

    if (locationId != null) {
      sql += "AND o.location_id = ? ";
      variables.add(Variable.withString(locationId));
    }

    sql +=
        "GROUP BY oi.item_name "
        "ORDER BY qty ASC "
        "LIMIT $limit";

    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();

    return rows.map((row) {
      final name = row.read<String>('name') ?? 'Unknown';
      final qty = (row.read<int>('qty') ?? 0).toDouble();
      return MapEntry(name, qty);
    }).toList();
  }

  Future<List<MapEntry<String, double>>> getDemandForecast(
    DateTime start,
    DateTime end, {
    int limit = 10,
    String? locationId,
  }) async {
    final days = end.difference(start).inDays + 1;
    if (days <= 0) return [];

    final query =
        _db.selectOnly(_db.orderItems).join([
            innerJoin(
              _db.orders,
              _db.orders.id.equalsExp(_db.orderItems.orderId),
            ),
          ])
          ..addColumns([
            _db.orderItems.itemName,
            _db.orders.createdAt,
            _db.orderItems.quantity,
          ])
          ..where(_db.orders.status.equals('completed'))
          ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
          ..where(_db.orders.createdAt.isSmallerThanValue(end));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final rows = await query.get();

    final itemTotals = <String, double>{};
    for (final row in rows) {
      final name = row.read(_db.orderItems.itemName) ?? 'Unknown';
      final qty = (row.read(_db.orderItems.quantity) ?? 0).toDouble();
      itemTotals[name] = (itemTotals[name] ?? 0) + qty;
    }

    final forecast = itemTotals.entries
        .map((e) => MapEntry(e.key, e.value / days))
        .toList();

    forecast.sort((a, b) => b.value.compareTo(a.value));
    return forecast.take(limit).toList();
  }

  Future<List<MapEntry<String, int>>> getTopBundles(
    DateTime start,
    DateTime end, {
    int limit = 5,
    String? locationId,
  }) async {
    String sql =
        "SELECT oi.order_id as orderId, oi.item_name as name "
        "FROM order_items oi "
        "INNER JOIN orders o ON o.id = oi.order_id "
        "WHERE o.status = 'completed' AND o.created_at >= ? AND o.created_at < ?";

    final variables = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];

    if (locationId != null) {
      sql += "AND o.location_id = ? ";
      variables.add(Variable.withString(locationId));
    }

    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();

    final orderItems = <String, Set<String>>{};
    for (final row in rows) {
      final orderId = row.read<String>('orderId') ?? '';
      final name = row.read<String>('name') ?? '';
      if (orderId.isEmpty || name.isEmpty) continue;
      orderItems.putIfAbsent(orderId, () => <String>{}).add(name);
    }

    final pairCounts = <String, int>{};
    for (final items in orderItems.values) {
      final list = items.toList()..sort();
      for (int i = 0; i < list.length; i++) {
        for (int j = i + 1; j < list.length; j++) {
          final key = '${list[i]} + ${list[j]}';
          pairCounts[key] = (pairCounts[key] ?? 0) + 1;
        }
      }
    }

    final bundles = pairCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return bundles.take(limit).toList();
  }

  Future<List<MapEntry<DateTime, double>>> getDailySales(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.createdAt, _db.orders.totalAmount])
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final rows = await query.get();

    final salesByDay = <DateTime, double>{};

    for (final row in rows) {
      final date = row.read(_db.orders.createdAt);
      final total = row.read(_db.orders.totalAmount) ?? 0.0;
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        salesByDay[day] = (salesByDay[day] ?? 0) + total;
      }
    }

    final sorted = salesByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted;
  }

  Future<List<MapEntry<String, double>>> getItemSalesShare(
    DateTime start,
    DateTime end, {
    int limit = 5,
    String? locationId,
  }) async {
    String sql =
        "SELECT oi.item_name as name, SUM(oi.quantity) as qty "
        "FROM order_items oi "
        "INNER JOIN orders o ON o.id = oi.order_id "
        "WHERE o.status = 'completed' AND o.created_at >= ? AND o.created_at < ? ";

    final variables = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];

    if (locationId != null) {
      sql += "AND o.location_id = ? ";
      variables.add(Variable.withString(locationId));
    }

    sql +=
        "GROUP BY oi.item_name "
        "ORDER BY qty DESC";

    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();

    final totalQty = rows.fold<double>(
      0,
      (sum, row) => sum + ((row.read<int>('qty') ?? 0).toDouble()),
    );
    if (totalQty == 0) return [];

    final topRows = rows.take(limit);
    return topRows.map((row) {
      final name = row.read<String>('name') ?? 'Unknown';
      final qty = (row.read<int>('qty') ?? 0).toDouble();
      return MapEntry(name, qty / totalQty);
    }).toList();
  }

  Future<String?> getSalesAnomalyNote(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    // These methods already accept locationId, so we just pass it through
    final todaySales = await getTodaySales(locationId: locationId);
    final avg = await getAverageDailySales(start, end, locationId: locationId);
    if (avg <= 0) return null;
    if (todaySales < avg * 0.7) {
      return 'Sales are below the recent average.';
    }
    if (todaySales > avg * 1.5) {
      return 'Sales are above the recent average.';
    }
    return null;
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(appDatabaseProvider));
});
