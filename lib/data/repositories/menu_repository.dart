import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/db/app_database.dart';
import '../providers/database_provider.dart';

class MenuRepository {
  final AppDatabase _db;

  MenuRepository(this._db);

  // Categories
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  Future<void> addCategory(CategoriesCompanion category) {
    return _db.into(_db.categories).insert(category);
  }

  Future<void> updateCategory(Category category) {
    return _db.update(_db.categories).replace(category);
  }
  
  Future<void> deleteCategory(String id) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id)))
        .write(const CategoriesCompanion(isDeleted: Value(true)));
  }

  // Items
  Stream<List<Item>> watchItems(String categoryId) {
    return (_db.select(_db.items)
          ..where((tbl) => tbl.categoryId.equals(categoryId) & tbl.isDeleted.equals(false)))
        .watch();
  }
  
  Stream<List<Item>> watchAllItems() {
    return (_db.select(_db.items)
          ..where((tbl) => tbl.isDeleted.equals(false)))
        .watch();
  }

  Future<void> addItem(ItemsCompanion item) {
    return _db.into(_db.items).insert(item);
  }

  Future<void> updateItem(Item item) {
    return _db.update(_db.items).replace(item);
  }

  Future<void> deleteItem(String id) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id)))
        .write(const ItemsCompanion(isDeleted: Value(true)));
  }
  Future<bool> hasCategories() async {
    final count = await (_db.select(_db.categories)..limit(1)).get();
    return count.isNotEmpty;
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MenuRepository(db);
});

final categoriesStreamProvider = StreamProvider((ref) {
  return ref.watch(menuRepositoryProvider).watchCategories();
});

final allItemsStreamProvider = StreamProvider((ref) {
  return ref.watch(menuRepositoryProvider).watchAllItems();
});
