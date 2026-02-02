import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'connection.dart';

part 'app_database.g.dart';

// Tables

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().unique()();
  TextColumn get name => text()();
  TextColumn get role =>
      text().withDefault(const Constant('staff'))(); // owner, staff
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFFFFFFFF))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get name => text()();
  RealColumn get price => real()();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  TextColumn get description => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  IntColumn get totalVisits => integer().withDefault(const Constant(0))();
  RealColumn get totalSpent => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastVisit => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RestaurantTables extends Table {
  TextColumn get id => text()();
  TextColumn get tableNumber => text().unique()();
  TextColumn get status => text().withDefault(
    const Constant('available'),
  )(); // available, occupied, reserved
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text().unique()();
  TextColumn get customerId =>
      text().nullable()(); // No FK constraint for nullable field
  TextColumn get tableId =>
      text().nullable()(); // No FK constraint for nullable field
  RealColumn get subtotal => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  RealColumn get paidCash => real().withDefault(const Constant(0.0))();
  RealColumn get paidUPI => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMode => text()(); // Cash, UPI, Card, Split
  TextColumn get status => text().withDefault(
    const Constant('completed'),
  )(); // completed, cancelled, pending
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get itemName => text()(); // Snapshot name in case item changes
  RealColumn get price => real()(); // Snapshot price
  IntColumn get quantity => integer()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()(); // Orders, Customers
  DateTimeColumn get lastSyncedAt => dateTime()();
  TextColumn get status => text()(); // Success, Failed
}

class RewardTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get type => text()(); // earn, redeem, adjustment
  RealColumn get amount => real()(); // Points
  TextColumn get orderId => text().nullable()(); // For earning from orders
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Users,
    Categories,
    Items,
    Customers,
    RestaurantTables,
    Orders,
    OrderItems,
    SyncLogs,
    RewardTransactions,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // Wrap each in try-catch to handle potential duplicates if migration ran partially or columns existed
          try {
            await m.addColumn(orders, orders.paidCash);
          } catch (e) {
            debugPrint('Migration: paidCash column might already exist: $e');
          }
          try {
            await m.addColumn(orders, orders.paidUPI);
          } catch (e) {
            debugPrint('Migration: paidUPI column might already exist: $e');
          }
          try {
            await m.addColumn(orders, orders.paymentMode);
          } catch (e) {
            debugPrint('Migration: paymentMode column might already exist: $e');
          }
        }
        if (from < 3) {
          // Add RestaurantTables table
          try {
            await m.createTable(restaurantTables);
          } catch (e) {
            debugPrint(
              'Migration: RestaurantTables table might already exist: $e',
            );
          }
          // Add tableId column to Orders
          try {
            await m.addColumn(orders, orders.tableId);
          } catch (e) {
            debugPrint('Migration: tableId column might already exist: $e');
          }
        }
        if (from < 4) {
          // Foreign keys disabled at connection level
        }
        if (from < 5) {
          // Add RewardTransactions and Settings tables
          try {
            await m.createTable(rewardTransactions);
          } catch (e) {
            debugPrint(
              'Migration: RewardTransactions table might already exist: $e',
            );
          }
          try {
            await m.createTable(settings);
          } catch (e) {
            debugPrint('Migration: Settings table might already exist: $e');
          }
        }
      },
      beforeOpen: (details) async {
        // Disable foreign keys for this connection
        await customSelect('PRAGMA foreign_keys = OFF').get();
      },
    );
  }
}
