import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:uuid/uuid.dart';

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  return TableRepository(ref.watch(databaseProvider));
});

final tablesStreamProvider = StreamProvider<List<RestaurantTable>>((ref) {
  return ref.watch(tableRepositoryProvider).watchAllTables();
});

final tableWithOrderProvider = FutureProvider.family<TableWithOrder?, String>((
  ref,
  tableId,
) async {
  return ref.watch(tableRepositoryProvider).getTableWithActiveOrder(tableId);
});

class TableWithOrder {
  final RestaurantTable table;
  final Order? activeOrder;

  TableWithOrder({required this.table, this.activeOrder});
}

class TableRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  TableRepository(this._db);

  // Watch all non-deleted tables
  Stream<List<RestaurantTable>> watchAllTables() {
    return (_db.select(_db.restaurantTables)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.tableNumber)]))
        .watch();
  }

  // Get all tables
  Future<List<RestaurantTable>> getAllTables() {
    return (_db.select(_db.restaurantTables)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.tableNumber)]))
        .get();
  }

  // Get table by ID
  Future<RestaurantTable?> getTableById(String id) {
    return (_db.select(_db.restaurantTables)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  // Get table with its active order
  Future<TableWithOrder?> getTableWithActiveOrder(String tableId) async {
    final table = await getTableById(tableId);
    if (table == null) return null;

    // Get pending order for this table
    final order =
        await (_db.select(_db.orders)..where(
              (o) => o.tableId.equals(tableId) & o.status.equals('pending'),
            ))
            .getSingleOrNull();

    return TableWithOrder(table: table, activeOrder: order);
  }

  // Create new table
  Future<RestaurantTable> createTable(String tableNumber) async {
    final id = _uuid.v4();
    final table = RestaurantTablesCompanion.insert(
      id: id,
      tableNumber: tableNumber,
      status: const Value('available'),
      createdAt: Value(DateTime.now()),
    );

    await _db.into(_db.restaurantTables).insert(table);
    return (await getTableById(id))!;
  }

  // Update table status
  Future<void> updateTableStatus(String tableId, String status) async {
    await (_db.update(_db.restaurantTables)..where((t) => t.id.equals(tableId)))
        .write(RestaurantTablesCompanion(status: Value(status)));
  }

  // Delete table (soft delete)
  Future<void> deleteTable(String tableId) async {
    await (_db.update(_db.restaurantTables)..where((t) => t.id.equals(tableId)))
        .write(const RestaurantTablesCompanion(isDeleted: Value(true)));
  }

  // Get next available table number
  Future<String> getNextTableNumber() async {
    final tables = await getAllTables();
    if (tables.isEmpty) return '1001';

    // Extract numbers from table numbers
    final numbers = tables
        .map((t) => int.tryParse(t.tableNumber) ?? 0)
        .where((n) => n > 0)
        .toList();

    if (numbers.isEmpty) return '1001';

    final maxNumber = numbers.reduce((a, b) => a > b ? a : b);
    return (maxNumber + 1).toString();
  }
}
