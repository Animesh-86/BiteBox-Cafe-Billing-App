import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String CURRENT_LOCATION_ID_KEY = 'current_location_id';

Future<Location> _ensureDefaultOutlet(AppDatabase db) async {
  final defaultLocation = LocationsCompanion(
    id: const Value('default-outlet-001'),
    name: const Value('Hangout Spot'),
    address: const Value('Kanha Dreamland'),
    phoneNumber: const Value(''),
    isActive: const Value(true),
    createdAt: Value(DateTime.now()),
  );

  await db.into(db.locations).insert(
    defaultLocation,
    mode: InsertMode.insertOrReplace,
  );

  // Persist as last active outlet so other providers pick it up
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_active_outlet_id', 'default-outlet-001');

  return await (db.select(
    db.locations,
  )..where((t) => t.id.equals('default-outlet-001'))).getSingle();
}

final locationsStreamProvider = StreamProvider<List<Location>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.locations)..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]))
      .watch()
      .asyncMap((locations) async {
        if (locations.isEmpty) {
          final seeded = await _ensureDefaultOutlet(db);
          return [seeded];
        }
        return locations;
      });
});

// Provider for the single active outlet - with fallback to default outlet
final activeOutletProvider = StreamProvider<Location?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(
    db.locations,
  )..where((t) => t.isActive.equals(true))).watchSingleOrNull().asyncMap((
    activeOutlet,
  ) async {
    // If no active outlet found, ensure default outlet exists and is active
    if (activeOutlet == null) {
      debugPrint(
        '⚠️ No active outlet found, ensuring default outlet is set as active...',
      );
      try {
        // Ensure default outlet exists and is marked as active
        await _ensureActiveDefaultOutlet(db);

        // Now fetch and return the default outlet
        return await (db.select(
          db.locations,
        )..where((t) => t.id.equals('default-outlet-001'))).getSingleOrNull();
      } catch (e) {
        debugPrint('❌ Error ensuring default outlet: $e');
        return null;
      }
    }
    return activeOutlet;
  });
});

Future<void> _ensureActiveDefaultOutlet(AppDatabase db) async {
  // First, deactivate all outlets
  await db
      .update(db.locations)
      .write(const LocationsCompanion(isActive: Value(false)));

  // Then, ensure default outlet exists and is active
  await db.into(db.locations).insert(
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

  debugPrint('✅ Default outlet ensured and activated');
}

final currentLocationIdProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.settings)
    ..where((tbl) => tbl.key.equals(CURRENT_LOCATION_ID_KEY));

  return query.watch().map((rows) {
    if (rows.isEmpty) return null;
    return rows.first.value;
  });
});

final locationsControllerProvider =
    StateNotifierProvider<LocationsController, AsyncValue<void>>((ref) {
      return LocationsController(ref.watch(appDatabaseProvider), ref);
    });

class LocationsController extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;
  final Ref _ref;

  LocationsController(this._db, this._ref) : super(const AsyncData(null));

  /// Force a refresh of the locations list
  void _refresh() {
    _ref.invalidate(locationsStreamProvider);
    _ref.invalidate(activeOutletProvider);
  }

  Future<void> addLocation(
    String name,
    String address,
    String phoneNumber,
  ) async {
    state = const AsyncLoading();
    try {
      final location = LocationsCompanion(
        id: Value(const Uuid().v4()),
        name: Value(name),
        address: Value(address),
        phoneNumber: Value(phoneNumber),
        isActive: const Value(false), // New outlets start inactive
        createdAt: Value(DateTime.now()),
      );
      await _db.into(_db.locations).insert(location);
      debugPrint('✅ Outlet added successfully: $name');
      state = const AsyncData(null);
      _refresh();
    } catch (e, st) {
      debugPrint('❌ Error adding outlet: $e');
      state = AsyncError(e, st);
    }
  }

  Future<void> updateLocation(
    String id,
    String name,
    String address,
    String phoneNumber,
  ) async {
    state = const AsyncLoading();
    try {
      await (_db.update(_db.locations)..where((t) => t.id.equals(id))).write(
        LocationsCompanion(
          name: Value(name),
          address: Value(address),
          phoneNumber: Value(phoneNumber),
        ),
      );
      state = const AsyncData(null);
      _refresh();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> setCurrentLocation(String id) async {
    state = const AsyncLoading();
    try {
      final setting = SettingsCompanion(
        key: const Value(CURRENT_LOCATION_ID_KEY),
        value: Value(id),
      );
      await _db.into(_db.settings).insertOnConflictUpdate(setting);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // Activate an outlet (deactivates all others first - single active outlet)
  Future<void> activateOutlet(String id) async {
    state = const AsyncLoading();
    try {
      // Persist to SharedPreferences for auto-connect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_outlet_id', id);

      await _db.transaction(() async {
        // First, deactivate all outlets
        await _db
            .update(_db.locations)
            .write(const LocationsCompanion(isActive: Value(false)));

        // Then activate the selected one
        await (_db.update(_db.locations)..where((t) => t.id.equals(id))).write(
          const LocationsCompanion(isActive: Value(true)),
        );
      });
      state = const AsyncData(null);
      _refresh();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // Deactivate an outlet
  Future<void> deactivateOutlet(String id) async {
    state = const AsyncLoading();
    try {
      await (_db.update(_db.locations)..where((t) => t.id.equals(id))).write(
        const LocationsCompanion(isActive: Value(false)),
      );
      state = const AsyncData(null);
      _refresh();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
