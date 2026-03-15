import 'package:hangout_spot/utils/log_utils.dart';
import 'package:drift/drift.dart';
import 'connection.dart';
import 'menu_seeder.dart';
import 'package:hangout_spot/data/constants/customer_defaults.dart';

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
  TextColumn get imageUrl => text().nullable()();
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

class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get address =>
      text().nullable()(); // Relaxed to nullable for robustness
  TextColumn get phoneNumber => text().nullable()(); // Relaxed to nullable
  BoolColumn get isActive =>
      boolean().nullable().withDefault(const Constant(false))(); // Relaxed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get customerId =>
      text().nullable()(); // No FK constraint for nullable field
  TextColumn get locationId => text().nullable()();
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
  DateTimeColumn get lastModified => dateTime().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(1))();
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
    Locations,
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
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // Wrap each in try-catch to handle potential duplicates if migration ran partially or columns existed
          try {
            await m.addColumn(orders, orders.paidCash);
          } catch (e) {
            logDebug('Migration: paidCash column might already exist: $e');
          }
          try {
            await m.addColumn(orders, orders.paidUPI);
          } catch (e) {
            logDebug('Migration: paidUPI column might already exist: $e');
          }
          try {
            await m.addColumn(orders, orders.paymentMode);
          } catch (e) {
            logDebug('Migration: paymentMode column might already exist: $e');
          }
        }
        if (from < 3) {
          // RestaurantTables removed
        }
        if (from < 4) {
          // Foreign keys disabled at connection level
        }
        if (from < 5) {
          // Add RewardTransactions and Settings tables
          try {
            await m.createTable(rewardTransactions);
          } catch (e) {
            logDebug(
              'Migration: RewardTransactions table might already exist: $e',
            );
          }
          try {
            await m.createTable(settings);
          } catch (e) {
            logDebug('Migration: Settings table might already exist: $e');
          }
        }
        if (from < 6) {
          try {
            await m.addColumn(items, items.imageUrl);
          } catch (e) {
            logDebug('Migration: imageUrl column might already exist: $e');
          }
        }
        if (from < 7) {
          try {
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_orders_status_created ON orders(status, created_at)',
            );
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)',
            );
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)',
            );
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_order_items_item ON order_items(item_id)',
            );
          } catch (e) {
            logDebug('Migration: indexes might already exist: $e');
          }
        }
        if (from < 8) {
          try {
            await m.createTable(locations);
          } catch (e) {
            logDebug('Migration: locations table might already exist: $e');
          }
          try {
            await m.addColumn(orders, orders.locationId);
          } catch (e) {
            logDebug('Migration: locationId column might already exist: $e');
          }
          try {
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_orders_location ON orders(location_id)',
            );
          } catch (e) {
            logDebug('Migration: location index might already exist: $e');
          }
        }
        if (from < 9) {
          try {
            await m.addColumn(orders, orders.isSynced);
          } catch (e) {
            logDebug('Migration: isSynced column might already exist: $e');
          }
        }
        if (from < 10) {
          // Add missing columns to locations table that existed before these were added
          try {
            await m.database.customStatement(
              'ALTER TABLE locations ADD COLUMN phone_number TEXT',
            );
          } catch (e) {
            logDebug('Migration: phone_number column might already exist: $e');
          }
          try {
            await m.database.customStatement(
              'ALTER TABLE locations ADD COLUMN is_active INTEGER DEFAULT 0',
            );
          } catch (e) {
            logDebug('Migration: is_active column might already exist: $e');
          }
          try {
            await m.database.customStatement(
              // BUG-5 fix: store in microseconds to match Drift's DateTime encoding.
              "ALTER TABLE locations ADD COLUMN created_at INTEGER DEFAULT (strftime('%s', 'now') * 1000000)",
            );
          } catch (e) {
            logDebug('Migration: created_at column might already exist: $e');
          }
          try {
            await m.database.customStatement(
              'ALTER TABLE locations ADD COLUMN address TEXT',
            );
          } catch (e) {
            logDebug('Migration: address column might already exist: $e');
          }
        }
        if (from < 11) {
          // BUG-5 fix: upgrade any locations rows whose created_at was written
          // as epoch seconds (migration v10 used strftime('%s','now') which
          // returns seconds, but Drift encodes DateTime as microseconds).
          // Values under 10_000_000_000 are definitely seconds — multiply by
          // 1_000_000 to convert them to the microsecond representation Drift
          // expects. Values already in microseconds remain unchanged.
          try {
            await m.database.customStatement(
              'UPDATE locations '
              'SET created_at = created_at * 1000000 '
              "WHERE created_at IS NOT NULL AND created_at < 10000000000",
            );
            logDebug(
              'Migration v11: converted locations.created_at to microseconds',
            );
          } catch (e) {
            logDebug('Migration v11: created_at fix failed (non-fatal): $e');
          }
        }
        if (from < 12) {
          // FIX: Drift 2.x stores DateTime as Unix epoch *seconds*, NOT
          // microseconds. Migrations v10/v11 incorrectly stored/multiplied
          // locations.created_at into microseconds. Any value > 10 billion
          // is not a valid seconds timestamp — divide by 1_000_000 to fix.
          // Also fix any other tables that may have bad timestamps from
          // cloud restores that wrote raw epoch integers.
          const fixes = [
            'UPDATE locations SET created_at = created_at / 1000000 '
                "WHERE created_at IS NOT NULL AND created_at > 10000000000",
            'UPDATE customers SET last_visit = last_visit / 1000000 '
                "WHERE last_visit IS NOT NULL AND last_visit > 10000000000",
            'UPDATE orders SET created_at = created_at / 1000000 '
                "WHERE created_at IS NOT NULL AND created_at > 10000000000",
            'UPDATE users SET created_at = created_at / 1000000 '
                "WHERE created_at IS NOT NULL AND created_at > 10000000000",
            'UPDATE reward_transactions SET created_at = created_at / 1000000 '
                "WHERE created_at IS NOT NULL AND created_at > 10000000000",
            'UPDATE settings SET updated_at = updated_at / 1000000 '
                "WHERE updated_at IS NOT NULL AND updated_at > 10000000000",
            'UPDATE sync_logs SET last_synced_at = last_synced_at / 1000000 '
                "WHERE last_synced_at IS NOT NULL AND last_synced_at > 10000000000",
          ];
          for (final sql in fixes) {
            try {
              await m.database.customStatement(sql);
            } catch (e) {
              logDebug('Migration v12: fix failed (non-fatal): $e');
            }
          }
          logDebug('Migration v12: normalised all DateTime columns to seconds');
        }
        if (from < 13) {
          // Add lastModified and syncVersion columns to orders table for
          // proper conflict resolution and duplicate prevention.
          try {
            await m.database.customStatement(
              'ALTER TABLE orders ADD COLUMN last_modified INTEGER',
            );
          } catch (e) {
            logDebug('Migration: last_modified column might already exist: $e');
          }
          try {
            await m.database.customStatement(
              'ALTER TABLE orders ADD COLUMN sync_version INTEGER DEFAULT 1',
            );
          } catch (e) {
            logDebug('Migration: sync_version column might already exist: $e');
          }
          // Backfill lastModified from createdAt for existing orders
          try {
            await m.database.customStatement(
              'UPDATE orders SET last_modified = created_at WHERE last_modified IS NULL',
            );
          } catch (e) {
            logDebug(
              'Migration v13: backfill last_modified failed (non-fatal): $e',
            );
          }
          logDebug(
            'Migration v13: added lastModified and syncVersion to orders',
          );
        }
        if (from < 14) {
          // Drop the UNIQUE constraint on invoiceNumber. SQLite cannot drop
          // constraints directly — table must be recreated using the standard
          // rename-create-copy-drop pattern.
          // Invoice numbers intentionally reset to #1001 each new session/day;
          // same number across different days is valid by design.
          try {
            await m.database.customStatement('ALTER TABLE orders RENAME TO orders_old');
            await m.database.customStatement('''
              CREATE TABLE orders (
                id TEXT NOT NULL,
                invoice_number TEXT NOT NULL,
                customer_id TEXT,
                location_id TEXT,
                subtotal REAL NOT NULL,
                discount_amount REAL NOT NULL DEFAULT 0.0,
                tax_amount REAL NOT NULL DEFAULT 0.0,
                total_amount REAL NOT NULL,
                paid_cash REAL NOT NULL DEFAULT 0.0,
                paid_u_p_i REAL NOT NULL DEFAULT 0.0,
                payment_mode TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'completed',
                created_at INTEGER NOT NULL DEFAULT 0,
                last_modified INTEGER,
                sync_version INTEGER NOT NULL DEFAULT 1,
                is_synced INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (id)
              )
            ''');
            await m.database.customStatement('''
              INSERT INTO orders (id, invoice_number, customer_id, location_id,
                subtotal, discount_amount, tax_amount, total_amount, paid_cash,
                paid_u_p_i, payment_mode, status, created_at, last_modified,
                sync_version, is_synced)
              SELECT id, invoice_number, customer_id, location_id,
                subtotal, discount_amount, tax_amount, total_amount, paid_cash,
                paid_u_p_i, payment_mode, status, created_at, last_modified,
                sync_version, is_synced
              FROM orders_old
            ''');
            await m.database.customStatement('DROP TABLE orders_old');
            logDebug('Migration v14: removed UNIQUE constraint from invoiceNumber');
          } catch (e) {
            logDebug('Migration v14 failed (non-fatal, table may already be correct): $e');
          }
        }
        if (from < 15) {
          // Recovery migration for devices that ran the broken v14 which used
          // "paid_upi" instead of "paid_u_p_i". Those devices have:
          //   - orders       : empty table with wrong column name
          //   - orders_old   : all data with correct column name (left behind)
          // Recover by dropping the broken table, recreating correctly, copying.
          try {
            final hasOldTable = (await m.database.customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='orders_old'",
            ).get()).isNotEmpty;

            if (hasOldTable) {
              // Broken v14 ran — drop the empty broken table
              await m.database.customStatement('DROP TABLE IF EXISTS orders');
              await m.database.customStatement('''
                CREATE TABLE orders (
                  id TEXT NOT NULL,
                  invoice_number TEXT NOT NULL,
                  customer_id TEXT,
                  location_id TEXT,
                  subtotal REAL NOT NULL,
                  discount_amount REAL NOT NULL DEFAULT 0.0,
                  tax_amount REAL NOT NULL DEFAULT 0.0,
                  total_amount REAL NOT NULL,
                  paid_cash REAL NOT NULL DEFAULT 0.0,
                  paid_u_p_i REAL NOT NULL DEFAULT 0.0,
                  payment_mode TEXT NOT NULL,
                  status TEXT NOT NULL DEFAULT 'completed',
                  created_at INTEGER NOT NULL DEFAULT 0,
                  last_modified INTEGER,
                  sync_version INTEGER NOT NULL DEFAULT 1,
                  is_synced INTEGER NOT NULL DEFAULT 0,
                  PRIMARY KEY (id)
                )
              ''');
              await m.database.customStatement('''
                INSERT INTO orders (id, invoice_number, customer_id, location_id,
                  subtotal, discount_amount, tax_amount, total_amount, paid_cash,
                  paid_u_p_i, payment_mode, status, created_at, last_modified,
                  sync_version, is_synced)
                SELECT id, invoice_number, customer_id, location_id,
                  subtotal, discount_amount, tax_amount, total_amount, paid_cash,
                  paid_u_p_i, payment_mode, status, created_at, last_modified,
                  sync_version, is_synced
                FROM orders_old
              ''');
              await m.database.customStatement('DROP TABLE orders_old');
              logDebug('Migration v15: recovered orders data from orders_old');
            } else {
              logDebug('Migration v15: orders_old not found, no recovery needed');
            }
          } catch (e) {
            logDebug('Migration v15 recovery failed: $e');
          }
        }
      },
      beforeOpen: (details) async {
        // Disable foreign keys for this connection
        await customSelect('PRAGMA foreign_keys = OFF').get();

        // ── Schema repair: ensure orders.paid_u_p_i column exists ───────────
        // Runs every launch as a safety net in case migrations left the table
        // in a broken state (e.g., broken v14 created column as "paid_upi").
        try {
          final cols =
              (await customSelect('PRAGMA table_info(orders)').get())
                  .map((r) => r.data['name'] as String)
                  .toSet();

          if (!cols.contains('paid_u_p_i')) {
            logDebug(
              'beforeOpen: orders.paid_u_p_i missing – starting repair',
            );

            const createOrdersSql = '''
              CREATE TABLE orders (
                id TEXT NOT NULL,
                invoice_number TEXT NOT NULL,
                customer_id TEXT,
                location_id TEXT,
                subtotal REAL NOT NULL,
                discount_amount REAL NOT NULL DEFAULT 0.0,
                tax_amount REAL NOT NULL DEFAULT 0.0,
                total_amount REAL NOT NULL,
                paid_cash REAL NOT NULL DEFAULT 0.0,
                paid_u_p_i REAL NOT NULL DEFAULT 0.0,
                payment_mode TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'completed',
                created_at INTEGER NOT NULL DEFAULT 0,
                last_modified INTEGER,
                sync_version INTEGER NOT NULL DEFAULT 1,
                is_synced INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (id)
              )
            ''';

            const destCols =
                'id, invoice_number, customer_id, location_id, '
                'subtotal, discount_amount, tax_amount, total_amount, '
                'paid_cash, paid_u_p_i, payment_mode, status, created_at, '
                'last_modified, sync_version, is_synced';

            final hasOrdersOld = (await customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type='table' AND name='orders_old'",
            ).get()).isNotEmpty;

            if (hasOrdersOld) {
              // orders_old (from a failed v14) has data with the correct
              // paid_u_p_i column — recreate orders and copy from backup.
              await customStatement('DROP TABLE IF EXISTS orders');
              await customStatement(createOrdersSql);
              await customStatement(
                'INSERT INTO orders ($destCols) '
                'SELECT $destCols FROM orders_old',
              );
              await customStatement('DROP TABLE orders_old');
              logDebug('beforeOpen: repaired orders table from orders_old');
            } else if (cols.contains('paid_upi')) {
              // orders has the wrong column name "paid_upi" with live data —
              // rename it, recreate with the correct name, copy with alias.
              await customStatement(
                'ALTER TABLE orders RENAME TO orders_old',
              );
              await customStatement(createOrdersSql);
              const srcCols =
                  'id, invoice_number, customer_id, location_id, '
                  'subtotal, discount_amount, tax_amount, total_amount, '
                  'paid_cash, paid_upi, payment_mode, status, created_at, '
                  'last_modified, sync_version, is_synced';
              await customStatement(
                'INSERT INTO orders ($destCols) '
                'SELECT $srcCols FROM orders_old',
              );
              await customStatement('DROP TABLE orders_old');
              logDebug(
                'beforeOpen: repaired orders – renamed paid_upi → paid_u_p_i',
              );
            }
          }
        } catch (e) {
          logDebug('beforeOpen: orders column repair (non-fatal): $e');
        }
        // ────────────────────────────────────────────────────────────────────

        // Fix any DateTime columns with oversized values (microseconds instead
        // of seconds). This runs every launch so hot-restart also benefits.
        try {
          for (final sql in const [
            'UPDATE locations SET created_at = created_at / 1000000 '
                "WHERE created_at IS NOT NULL AND created_at > 10000000000",
            'UPDATE customers SET last_visit = last_visit / 1000000 '
                "WHERE last_visit IS NOT NULL AND last_visit > 10000000000",
            'UPDATE orders SET created_at = created_at / 1000000 '
                "WHERE created_at IS NOT NULL AND created_at > 10000000000",
          ]) {
            await customStatement(sql);
          }
        } catch (e) {
          logDebug('beforeOpen timestamp fix (non-fatal): $e');
        }

        // Seed default outlet if none exist yet
        List<Location> existing;
        try {
          existing = await select(locations).get();
        } catch (e) {
          logDebug('beforeOpen: locations query failed, assuming empty: $e');
          existing = [];
        }
        if (existing.isEmpty) {
          await into(locations).insert(
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
          logDebug('✅ Default outlet seeded: Hangout Spot – Kanha Dreamland');
        }

        // Seed default menu items
        await MenuSeeder.seedDefaultMenu(this);

        // Seed default customers (walk-in, zomato, swiggy)
        for (final seed in CustomerDefaults.seeded) {
          await into(customers).insertOnConflictUpdate(
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
      },
    );
  }
}
