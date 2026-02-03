import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:uuid/uuid.dart';

const String CURRENT_LOCATION_ID_KEY = 'current_location_id';

final locationsStreamProvider = StreamProvider<List<Location>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.locations)..orderBy([
        (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
      ]))
      .watch();
});

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
      return LocationsController(ref.watch(appDatabaseProvider));
    });

class LocationsController extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;

  LocationsController(this._db) : super(const AsyncData(null));

  Future<void> addLocation(String name, String address) async {
    state = const AsyncLoading();
    try {
      final location = LocationsCompanion(
        id: Value(const Uuid().v4()),
        name: Value(name),
        address: Value(address),
      );
      await _db.into(_db.locations).insert(location);
      state = const AsyncData(null);
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
}
