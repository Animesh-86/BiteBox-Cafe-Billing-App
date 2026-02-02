import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/db/app_database.dart';

AppDatabase? _database;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  _database ??= AppDatabase();
  return _database!;
});
