import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';

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
