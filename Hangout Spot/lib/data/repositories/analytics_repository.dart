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
    // Debug logging
    print('DEBUG: getSessionItemsSold called');
    print('  Start: $start');
    print('  End: $end');
    print('  LocationId: $locationId');

    // Check total orders in database
    final totalOrdersQuery = _db.select(_db.orders);
    final allOrders = await totalOrdersQuery.get();
    print('  Total orders in DB: ${allOrders.length}');

    // Check orders in date range
    final ordersInRange = allOrders
        .where((o) => o.createdAt.isAfter(start) && o.createdAt.isBefore(end))
        .toList();
    print('  Orders in date range: ${ordersInRange.length}');

    // Check completed orders
    final completedOrders = ordersInRange
        .where((o) => o.status == 'completed')
        .toList();
    print('  Completed orders: ${completedOrders.length}');

    // Check location filtered
    final locationFiltered = locationId != null
        ? completedOrders.where((o) => o.locationId == locationId).toList()
        : completedOrders;
    print('  After location filter: ${locationFiltered.length}');

    // Check orderItems table
    final allOrderItems = await _db.select(_db.orderItems).get();
    print('  Total orderItems in DB: ${allOrderItems.length}');

    // Check if orderItems match the filtered orders
    if (locationFiltered.isNotEmpty) {
      final filteredOrderIds = locationFiltered.map((o) => o.id).toSet();
      print('  Sample order IDs: ${filteredOrderIds.take(3).join(", ")}');

      final matchingItems = allOrderItems
          .where((item) => filteredOrderIds.contains(item.orderId))
          .toList();
      print('  OrderItems matching filtered orders: ${matchingItems.length}');

      if (matchingItems.isNotEmpty) {
        final totalQty = matchingItems.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );
        print('  Manual quantity sum: $totalQty');
      }
    }

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
    final itemsSold = result.read(_db.orderItems.quantity.sum()) ?? 0;
    print('  Items sold result: $itemsSold');
    return itemsSold;
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
      query.join([
        innerJoin(_db.orders, _db.orders.id.equalsExp(_db.orderItems.orderId)),
      ]);
      query.where(_db.orders.locationId.equals(locationId));
    }
    final result = await query.get();
    return result.map((row) {
      return MapEntry(
        row.read(_db.orderItems.itemName) ?? 'Unknown',
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
      result.read(_db.orderItems.itemName) ?? 'Unknown',
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
      final count = row.read<int?>('orderCount') ?? 0;
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
    sql += "GROUP BY oi.item_name ORDER BY qty DESC LIMIT $limit";
    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();
    return rows.map((row) {
      final name = row.read<String?>('name') ?? 'Unknown Item';
      final qty = (row.read<int?>('qty') ?? 0).toDouble();
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
    sql += "GROUP BY oi.item_name ORDER BY qty ASC LIMIT $limit";
    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();
    return rows.map((row) {
      final name = row.read<String?>('name') ?? 'Unknown Item';
      final qty = (row.read<int?>('qty') ?? 0).toDouble();
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
      sql += " AND o.location_id = ?";
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
      final orderId = row.read<String?>('orderId') ?? '';
      final name = row.read<String?>('name') ?? 'Unknown Item';
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
    sql += "GROUP BY oi.item_name ORDER BY qty DESC";
    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();

    final totalQty = rows.fold<double>(
      0,
      (sum, row) => sum + (row.read<int?>('qty') ?? 0).toDouble(),
    );
    if (totalQty == 0) return [];
    final topRows = rows.take(limit);
    return topRows.map((row) {
      final name = row.read<String?>('name') ?? 'Unknown Item';
      final qty = (row.read<int?>('qty') ?? 0).toDouble();
      return MapEntry(name, qty / totalQty);
    }).toList();
  }

  Future<String?> getSalesAnomalyNote(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
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

  // ─────────────────────────────────────────────────────────────────────────────
  // NEW FEATURE METHODS
  // ─────────────────────────────────────────────────────────────────────────────

  /// 1. Smart Daily Brief — plain-English summary of today vs period avg
  Future<String> getSmartDailyBrief({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? locationId,
  }) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todaySales = await getSessionSales(
      todayStart,
      todayEnd,
      locationId: locationId,
    );
    final todayOrders = await getSessionOrdersCount(
      todayStart,
      todayEnd,
      locationId: locationId,
    );
    final avgDaily = await getAverageDailySales(
      rangeStart,
      rangeEnd,
      locationId: locationId,
    );
    final topItems = await getTopSellingItemsSince(
      rangeStart,
      rangeEnd,
      limit: 1,
      locationId: locationId,
    );
    final peakHours = await getPeakHours(
      rangeStart,
      rangeEnd,
      locationId: locationId,
    );

    final parts = <String>[];

    if (avgDaily > 0) {
      final pct = ((todaySales - avgDaily) / avgDaily * 100).round().abs();
      if (todaySales > avgDaily * 1.15) {
        parts.add('🔥 Today is trending $pct% above the period average.');
      } else if (todaySales < avgDaily * 0.85) {
        parts.add('⚠️ Today is $pct% below the period average — a slow day.');
      } else {
        parts.add('✅ Today is tracking on par with the period average.');
      }
    }
    if (todayOrders > 0) {
      parts.add(
        '📋 $todayOrders orders placed today · ₹${todaySales.toStringAsFixed(0)} collected.',
      );
    }
    if (topItems.isNotEmpty) {
      parts.add('⭐ Top-seller this period: ${topItems.first.key}.');
    }
    if (peakHours.isNotEmpty) {
      final peak = peakHours.reduce((a, b) => a.value >= b.value ? a : b);
      final h = peak.key;
      final ampm = h < 12 ? 'AM' : 'PM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      parts.add('⏱️ Busiest hour this period: $h12 $ampm.');
    }
    if (parts.isEmpty) {
      return 'No orders recorded yet. Start billing to see your daily brief!';
    }
    return parts.join('\n\n');
  }

  Future<List<Map<String, dynamic>>> getItemBcgData(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String sql =
        'SELECT oi.item_name as name, '
        'SUM(oi.quantity) as qty, '
        'SUM(oi.price) as revenue '
        'FROM order_items oi '
        'INNER JOIN orders o ON o.id = oi.order_id '
        "WHERE o.status = 'completed' "
        'AND o.created_at >= ? AND o.created_at < ? ';
    final vars = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      sql += 'AND o.location_id = ? ';
      vars.add(Variable.withString(locationId));
    }
    sql += 'GROUP BY oi.item_name ORDER BY revenue DESC';
    final rows = await _db
        .customSelect(
          sql,
          variables: vars,
          readsFrom: {_db.orderItems, _db.orders},
        )
        .get();
    return rows
        .map(
          (r) => <String, dynamic>{
            'name': r.read<String?>('name') ?? 'Unknown Item',
            'qty': (r.read<int?>('qty') ?? 0).toDouble(),
            'revenue': r.read<double?>('revenue') ?? 0.0,
          },
        )
        .toList();
  }

  /// 3. Revenue Leakage — discount totals and walk-in (untracked) order count
  Future<Map<String, dynamic>> getRevenueLeakage(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String discSql =
        'SELECT COALESCE(SUM(discount_amount), 0) as totalDiscount, '
        'COUNT(*) as discountedOrders '
        'FROM orders '
        "WHERE status = 'completed' AND discount_amount > 0 "
        'AND created_at >= ? AND created_at < ?';
    final vars = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      discSql += ' AND location_id = ?';
      vars.add(Variable.withString(locationId));
    }
    final discRow = await _db
        .customSelect(discSql, variables: vars, readsFrom: {_db.orders})
        .getSingle();

    String walkSql =
        'SELECT COUNT(*) as cnt FROM orders '
        "WHERE status = 'completed' AND customer_id IS NULL "
        'AND created_at >= ? AND created_at < ?';
    final vars2 = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      walkSql += ' AND location_id = ?';
      vars2.add(Variable.withString(locationId));
    }
    final walkRow = await _db
        .customSelect(walkSql, variables: vars2, readsFrom: {_db.orders})
        .getSingle();

    return {
      'totalDiscount': discRow.read<double?>('totalDiscount') ?? 0.0,
      'discountedOrders': discRow.read<int?>('discountedOrders') ?? 0,
      'walkInOrders': walkRow.read<int?>('cnt') ?? 0,
    };
  }

  /// 4. At-risk customers — visited ≥ minVisits but gone silent for lastSeenDays
  Future<List<Map<String, dynamic>>> getAtRiskCustomers({
    int minVisits = 3,
    int lastSeenDays = 30,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: lastSeenDays));
    const sql =
        'SELECT c.id, c.name, c.phone, '
        'COUNT(o.id) as visits, '
        'MAX(o.created_at) as lastVisit '
        'FROM customers c '
        'INNER JOIN orders o ON o.customer_id = c.id '
        "WHERE o.status = 'completed' "
        'GROUP BY c.id '
        'HAVING visits >= ? AND lastVisit < ? '
        'ORDER BY lastVisit ASC LIMIT 20';
    final rows = await _db
        .customSelect(
          sql,
          variables: [
            Variable.withInt(minVisits),
            Variable.withDateTime(cutoff),
          ],
          readsFrom: {_db.customers, _db.orders},
        )
        .get();
    return rows.map((r) {
      final ts = r.read<int?>('lastVisit');
      final last = ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts * 1000)
          : null;
      return <String, dynamic>{
        'name': r.read<String?>('name') ?? 'Customer',
        'phone': r.read<String?>('phone') ?? '',
        'visits': r.read<int?>('visits') ?? 0,
        'lastVisit': last,
        'daysSince': last != null
            ? DateTime.now().difference(last).inDays
            : lastSeenDays,
      };
    }).toList();
  }

  /// 5. Orders by weekday (0=Mon … 6=Sun)
  Future<List<MapEntry<int, double>>> getOrdersByWeekday(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.createdAt])
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end));
    if (locationId != null)
      query.where(_db.orders.locationId.equals(locationId));
    final rows = await query.get();
    final counts = List.filled(7, 0.0);
    for (final r in rows) {
      final dt = r.read(_db.orders.createdAt);
      if (dt != null) counts[dt.weekday - 1] += 1;
    }
    return List.generate(7, (i) => MapEntry(i, counts[i]));
  }

  /// Outlet Comparison - Get revenue comparison across multiple outlets
  Future<List<Map<String, dynamic>>> getOutletComparison(
    DateTime start,
    DateTime end,
    List<String> outletIds,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final outletId in outletIds) {
      final sales = await getSessionSales(start, end, locationId: outletId);
      final orders = await getSessionOrdersCount(
        start,
        end,
        locationId: outletId,
      );
      final avgOrderValue = await getAverageOrderValue(
        start,
        end,
        locationId: outletId,
      );
      final repeatRate = await getRepeatCustomerRate(
        start,
        end,
        locationId: outletId,
      );

      results.add({
        'outletId': outletId,
        'sales': sales,
        'orders': orders,
        'avgOrderValue': avgOrderValue,
        'repeatRate': repeatRate,
      });
    }

    return results;
  }

  /// Get all outlets revenue summary for comparison
  Future<List<Map<String, dynamic>>> getAllOutletsRevenueSummary(
    DateTime start,
    DateTime end,
  ) async {
    final sql = '''
      SELECT 
        o.location_id as outletId,
        COUNT(DISTINCT o.id) as orders,
        SUM(o.total_amount) as sales,
        AVG(o.total_amount) as avgOrderValue
      FROM orders o
      WHERE o.status = 'completed'
        AND o.created_at >= ?
        AND o.created_at < ?
      GROUP BY o.location_id
      ORDER BY sales DESC
    ''';

    final rows = await _db
        .customSelect(
          sql,
          variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
          readsFrom: {_db.orders},
        )
        .get();

    return rows
        .map(
          (r) => {
            'outletId': r.read<String?>('outletId'),
            'sales': r.read<double?>('sales') ?? 0.0,
            'orders': r.read<int?>('orders') ?? 0,
            'avgOrderValue': r.read<double?>('avgOrderValue') ?? 0.0,
          },
        )
        .toList();
  }

  /// Get daily sales comparison across outlets
  Future<Map<String, List<MapEntry<DateTime, double>>>> getDailySalesComparison(
    DateTime start,
    DateTime end,
    List<String> outletIds,
  ) async {
    final comparison = <String, List<MapEntry<DateTime, double>>>{};

    for (final outletId in outletIds) {
      final dailySales = await getDailySales(start, end, locationId: outletId);
      comparison[outletId] = dailySales;
    }

    return comparison;
  }

  /// Get payment method distribution
  Future<List<Map<String, dynamic>>> getPaymentMethodDistribution(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String sql =
        'SELECT payment_mode, COUNT(*) as count, SUM(total_amount) as amount '
        'FROM orders '
        "WHERE status = 'completed' AND created_at >= ? AND created_at < ? ";
    final vars = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      sql += 'AND location_id = ? ';
      vars.add(Variable.withString(locationId));
    }
    sql += 'GROUP BY payment_mode';
    final rows = await _db
        .customSelect(sql, variables: vars, readsFrom: {_db.orders})
        .get();
    return rows.map((row) {
      return {
        'method': row.read<String?>('payment_mode') ?? 'Cash',
        'count': row.read<int?>('count') ?? 0,
        'amount': row.read<double?>('amount') ?? 0.0,
      };
    }).toList();
  }

  /// Get payment method trends over time
  Future<Map<String, List<MapEntry<DateTime, int>>>> getPaymentMethodTrends(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String sql =
        'SELECT payment_mode, DATE(created_at) as date, COUNT(*) as count '
        'FROM orders '
        "WHERE status = 'completed' AND created_at >= ? AND created_at < ? ";
    final vars = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      sql += 'AND location_id = ? ';
      vars.add(Variable.withString(locationId));
    }
    sql += 'GROUP BY payment_mode, date ORDER BY date';
    final rows = await _db
        .customSelect(sql, variables: vars, readsFrom: {_db.orders})
        .get();

    final result = <String, List<MapEntry<DateTime, int>>>{};
    for (final row in rows) {
      final mode = row.read<String?>('payment_mode') ?? 'Cash';
      final dateStr = row.read<String?>('date');
      if (dateStr == null) continue;
      final count = row.read<int?>('count') ?? 0;
      final date = DateTime.parse(dateStr);

      result.putIfAbsent(mode, () => []);
      result[mode]!.add(MapEntry(date, count));
    }
    return result;
  }

  /// Get category performance
  Future<List<Map<String, dynamic>>> getCategoryPerformance(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String sql =
        'SELECT c.name as category, '
        'SUM(oi.quantity) as quantity, '
        'SUM(oi.price * oi.quantity) as revenue '
        'FROM order_items oi '
        'INNER JOIN orders o ON o.id = oi.order_id '
        'INNER JOIN items i ON i.id = oi.item_id '
        'INNER JOIN categories c ON c.id = i.category_id '
        "WHERE o.status = 'completed' AND o.created_at >= ? AND o.created_at < ? ";
    final vars = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      sql += 'AND o.location_id = ? ';
      vars.add(Variable.withString(locationId));
    }
    sql += 'GROUP BY c.id, c.name ORDER BY revenue DESC';
    final rows = await _db
        .customSelect(
          sql,
          variables: vars,
          readsFrom: {_db.orderItems, _db.orders, _db.items, _db.categories},
        )
        .get();
    return rows.map((r) {
      return <String, dynamic>{
        'category': r.read<String?>('category') ?? 'Uncategorized',
        'quantity': r.read<int?>('quantity') ?? 0,
        'revenue': r.read<double?>('revenue') ?? 0.0,
      };
    }).toList();
  }

  /// Get monthly sales for bar graph
  Future<List<MapEntry<String, double>>> getMonthlySales({
    String? locationId,
    int months = 12,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months, 1);

    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.createdAt, _db.orders.totalAmount])
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startDate));

    if (locationId != null) {
      query.where(_db.orders.locationId.equals(locationId));
    }

    final rows = await query.get();

    final salesByMonth = <String, double>{};
    for (final row in rows) {
      final date = row.read(_db.orders.createdAt);
      final total = row.read(_db.orders.totalAmount) ?? 0.0;

      if (date != null) {
        final monthStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        salesByMonth[monthStr] = (salesByMonth[monthStr] ?? 0.0) + total;
      }
    }

    final sorted = salesByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted;
  }

  /// Get customer frequency segmentation
  Future<Map<String, int>> getCustomerFrequencySegments(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String sql =
        'SELECT customer_id, COUNT(*) as orders '
        'FROM orders '
        "WHERE status = 'completed' AND customer_id IS NOT NULL "
        'AND created_at >= ? AND created_at < ? ';
    final vars = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      sql += 'AND location_id = ? ';
      vars.add(Variable.withString(locationId));
    }
    sql += 'GROUP BY customer_id';
    final rows = await _db
        .customSelect(sql, variables: vars, readsFrom: {_db.orders})
        .get();

    final segments = {'oneTime': 0, 'occasional': 0, 'regular': 0, 'vip': 0};

    for (final row in rows) {
      final orderCount = row.read<int?>('orders') ?? 0;
      if (orderCount == 1) {
        segments['oneTime'] = segments['oneTime']! + 1;
      } else if (orderCount <= 5) {
        segments['occasional'] = segments['occasional']! + 1;
      } else if (orderCount <= 15) {
        segments['regular'] = segments['regular']! + 1;
      } else {
        segments['vip'] = segments['vip']! + 1;
      }
    }
    return segments;
  }

  /// Get day of week sales (with amounts, not just counts)
  Future<List<MapEntry<int, double>>> getDayOfWeekSales(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([_db.orders.createdAt, _db.orders.totalAmount])
      ..where(_db.orders.status.equals('completed'))
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start))
      ..where(_db.orders.createdAt.isSmallerThanValue(end));
    if (locationId != null)
      query.where(_db.orders.locationId.equals(locationId));
    final rows = await query.get();
    final amounts = List.filled(7, 0.0);
    for (final r in rows) {
      final dt = r.read(_db.orders.createdAt);
      final amt = r.read(_db.orders.totalAmount) ?? 0.0;
      if (dt != null) amounts[dt.weekday - 1] += amt;
    }
    return List.generate(7, (i) => MapEntry(i, amounts[i]));
  }

  /// Get discount effectiveness data
  Future<Map<String, dynamic>> getDiscountEffectivenessData(
    DateTime start,
    DateTime end, {
    String? locationId,
  }) async {
    String withDiscSql =
        'SELECT COUNT(*) as orders, '
        'SUM(total_amount) as revenue, '
        'SUM(discount_amount) as totalDiscount '
        'FROM orders '
        "WHERE status = 'completed' AND discount_amount > 0 "
        'AND created_at >= ? AND created_at < ?';
    final vars1 = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      withDiscSql += ' AND location_id = ?';
      vars1.add(Variable.withString(locationId));
    }

    String withoutDiscSql =
        'SELECT COUNT(*) as orders, '
        'SUM(total_amount) as revenue '
        'FROM orders '
        "WHERE status = 'completed' AND discount_amount = 0 "
        'AND created_at >= ? AND created_at < ?';
    final vars2 = <Variable>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];
    if (locationId != null) {
      withoutDiscSql += ' AND location_id = ?';
      vars2.add(Variable.withString(locationId));
    }

    final withDisc = await _db
        .customSelect(withDiscSql, variables: vars1, readsFrom: {_db.orders})
        .getSingle();
    final withoutDisc = await _db
        .customSelect(withoutDiscSql, variables: vars2, readsFrom: {_db.orders})
        .getSingle();

    return {
      'ordersWithDiscount': withDisc.read<int?>('orders') ?? 0,
      'revenueWithDiscount': withDisc.read<double?>('revenue') ?? 0.0,
      'totalDiscountAmount': withDisc.read<double?>('totalDiscount') ?? 0.0,
      'ordersWithoutDiscount': withoutDisc.read<int?>('orders') ?? 0,
      'revenueWithoutDiscount': withoutDisc.read<double?>('revenue') ?? 0.0,
    };
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(appDatabaseProvider));
});
