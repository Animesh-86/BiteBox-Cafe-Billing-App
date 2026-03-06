import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/db/app_database.dart';
import '../providers/database_provider.dart';

import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/repositories/inventory_repository.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';

class MenuRepository {
  final AppDatabase _db;
  final InventoryRepository _inventoryRepo;

  MenuRepository(this._db, this._inventoryRepo);

  // Categories
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch()
        .map((categories) {
          // Deduplicate by normalized name, keeping the first (lowest sortOrder)
          final seen = <String>{};
          return categories.where((cat) {
            final key = cat.name.toLowerCase().trim().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            );
            return seen.add(key);
          }).toList();
        });
  }

  Future<void> addCategory(CategoriesCompanion category) {
    return _db
        .into(_db.categories)
        .insert(category, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateCategory(Category category) {
    return _db.update(_db.categories).replace(category);
  }

  Future<void> deleteCategory(String id) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      const CategoriesCompanion(isDeleted: Value(true)),
    );
  }

  // Items
  Stream<List<Item>> watchItems(String categoryId) {
    return (_db.select(_db.items)..where(
          (tbl) =>
              tbl.categoryId.equals(categoryId) & tbl.isDeleted.equals(false),
        ))
        .watch();
  }

  Stream<List<Item>> watchAllItems() {
    return (_db.select(
      _db.items,
    )..where((tbl) => tbl.isDeleted.equals(false))).watch().map((items) {
      // Deduplicate by categoryId + normalized name, keeping the first occurrence
      final seen = <String>{};
      return items.where((item) {
        final key =
            '${item.categoryId}|${item.name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
        return seen.add(key);
      }).toList();
    });
  }

  Future<void> addItem(ItemsCompanion item, {String? categoryName}) async {
    await _db.into(_db.items).insert(item, mode: InsertMode.insertOrReplace);

    // Auto-sync specific beverages to Inventory mapping
    if (categoryName != null) {
      final name = categoryName.toLowerCase();
      if (name == 'cold drink' || name == 'water bottle') {
        try {
          // Push a default mock instance into Firebase to keep both spaces synchronized
          await _inventoryRepo.addItem(
            InventoryItem(
              id: const Uuid().v4(),
              name: item.name.value,
              category: categoryName,
              unit: 'piece',
              currentQty: 0,
              minQty: 0,
            ),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> updateItem(Item item, {String? categoryName}) async {
    await _db.update(_db.items).replace(item);

    // Auto-sync specific beverages to Inventory mapping
    if (categoryName != null) {
      final name = categoryName.toLowerCase();
      if (name == 'cold drink' || name == 'water bottle') {
        try {
          // Assume the user is just editing the definition of the beverage.
          // Note: Full syncing here implies the Inventory name also edits if it matches by an ID.
          // Since they don't share identical relational row IDs, we enforce a unidirectional sync on Add/Delete for simplicity.
        } catch (_) {}
      }
    }
  }

  Future<void> deleteItem(String id) async {
    // Look up the item first to check its category
    final itemOrNull = await (_db.select(
      _db.items,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      const ItemsCompanion(isDeleted: Value(true)),
    );

    // Cross-sync deletes to the Inventory module for gateways
    if (itemOrNull != null) {
      final catId = itemOrNull.categoryId;
      final catOrNull = await (_db.select(
        _db.categories,
      )..where((t) => t.id.equals(catId))).getSingleOrNull();
      if (catOrNull != null) {
        final catName = catOrNull.name.toLowerCase();
        if (catName == 'cold drink' || catName == 'water bottle') {
          try {
            // Because Drift IDs don't match Firebase IDs directly (we use uuid for drift, but firestore generate its own doc id if not specified),
            // We must filter by name.
            final itemsSnapshot = await _inventoryRepo.watchItems().first;
            final targetItem = itemsSnapshot
                .where(
                  (i) => i.name.toLowerCase() == itemOrNull.name.toLowerCase(),
                )
                .firstOrNull;

            if (targetItem != null) {
              await _inventoryRepo.deleteItem(targetItem.id);
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<bool> hasCategories() async {
    final count = await (_db.select(_db.categories)..limit(1)).get();
    return count.isNotEmpty;
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final inventoryRepo = ref.watch(inventoryRepositoryProvider);
  return MenuRepository(db, inventoryRepo);
});

final categoriesStreamProvider = StreamProvider((ref) {
  return ref.watch(menuRepositoryProvider).watchCategories();
});

final allItemsStreamProvider = StreamProvider((ref) {
  return ref.watch(menuRepositoryProvider).watchAllItems();
});
