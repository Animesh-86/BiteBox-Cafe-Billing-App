import 'package:hangout_spot/utils/log_utils.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

class MenuSeeder {
  static Future<void> seedDefaultMenu(AppDatabase db) async {
    // 1. Deduplicate existing categories and items FIRST before checking
    final catDupeCount = await _dedupeCategories(db);
    final itemDupeCount = await _dedupeItems(db);

    final existingCategories = await db.select(db.categories).get();

    final uuid = const Uuid();

    // --- Define Categories ---
    final categories = [
      {'name': 'Toast', 'color': 0xFFFFB74D},
      {'name': 'Sandwich', 'color': 0xFFFF9800},
      {'name': 'Grilled Sandwich', 'color': 0xFFF57C00},
      {'name': 'Pizza', 'color': 0xFFFFC107},
      {'name': 'Burger', 'color': 0xFFF44336},
      {'name': 'Frankie', 'color': 0xFF8D6E63},
      {'name': 'French Fries', 'color': 0xFFFFEB3B},
      {'name': 'Garlic Bread', 'color': 0xFFD4E157},
      {'name': 'Pasta', 'color': 0xFF9C27B0},
      {'name': 'Maggi', 'color': 0xFFFFCA28},
      {'name': 'Tea & Coffee', 'color': 0xFF795548},
      {'name': 'Cold Beverages', 'color': 0xFF2196F3},
      {'name': 'Shakes', 'color': 0xFFE91E63},
      {'name': 'Mojito & Mocktail', 'color': 0xFF00BCD4},
      {'name': 'SPECIAL COMBO MEALS', 'color': 0xFF4CAF50},
      {'name': 'Cold Drink', 'color': 0xFF1976D2},
      {'name': 'Water Bottle', 'color': 0xFF90CAF9},
    ];

    // Cache existing categories for lookup (case-insensitive)
    final categoryIds = <String, String>{
      for (final cat in existingCategories)
        if (!cat.isDeleted) cat.name.toLowerCase().trim(): cat.id,
    };

    // Ensure all categories exist
    var sortIndex = existingCategories.length;
    for (var i = 0; i < categories.length; i++) {
      final name = categories[i]['name'] as String;
      final lowerName = name.toLowerCase().trim();

      if (categoryIds.containsKey(lowerName)) continue;

      final id = uuid.v4();
      categoryIds[lowerName] = id;
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion(
              id: Value(id),
              name: Value(name),
              color: Value(categories[i]['color'] as int),
              sortOrder: Value(sortIndex++),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    // Build composite key set (categoryId|name) from ALL existing items
    // (including soft-deleted) to prevent re-inserting anything
    final existingItems = await db.select(db.items).get();
    final existingKeys = <String>{};
    for (final item in existingItems) {
      existingKeys.add('${item.categoryId}|${item.name.toLowerCase().trim()}');
    }

    // --- Define Items ---
    final items = [
      // 🥪 TOAST
      {'category': 'Toast', 'name': 'Cheese Chilly Toast', 'price': 80},
      {'category': 'Toast', 'name': 'Corn Chilly Toast', 'price': 90},
      {'category': 'Toast', 'name': 'Paneer Toast', 'price': 99},
      {'category': 'Toast', 'name': 'Olive Jalapeno Toast', 'price': 110},

      // 🥪 SANDWICH
      {'category': 'Sandwich', 'name': 'Bread Butter with Cheese', 'price': 59},
      {'category': 'Sandwich', 'name': 'Bread Butter Jam', 'price': 69},
      {'category': 'Sandwich', 'name': 'Bread Butter Jam Cheese', 'price': 79},
      {'category': 'Sandwich', 'name': 'Cheese Chutney', 'price': 79},

      // 🔥 GRILLED SANDWICH
      {
        'category': 'Grilled Sandwich',
        'name': 'Cheese Chutney (Grilled)',
        'price': 89,
      },
      {'category': 'Grilled Sandwich', 'name': 'Veg Cheese', 'price': 99},
      {
        'category': 'Grilled Sandwich',
        'name': 'Peri Peri Cheese',
        'price': 110,
      },
      {
        'category': 'Grilled Sandwich',
        'name': 'Chilli Mayo Cheese',
        'price': 120,
      },
      {
        'category': 'Grilled Sandwich',
        'name': 'Cheese Chilli Corn',
        'price': 130,
      },
      {'category': 'Grilled Sandwich', 'name': 'Tandoori Paneer', 'price': 130},
      {'category': 'Grilled Sandwich', 'name': 'Makhani Paneer', 'price': 140},
      {'category': 'Grilled Sandwich', 'name': 'Mexican', 'price': 140},

      // 🍕 PIZZA (Small 7 inch)
      {'category': 'Pizza', 'name': 'Margherita (Small 7")', 'price': 130},
      {'category': 'Pizza', 'name': 'Veg Delight (Small 7")', 'price': 150},
      {'category': 'Pizza', 'name': 'Tandoori Paneer (Small 7")', 'price': 160},
      {'category': 'Pizza', 'name': 'Mexican (Small 7")', 'price': 160},
      {'category': 'Pizza', 'name': 'American Corn (Small 7")', 'price': 180},
      {'category': 'Pizza', 'name': 'Double Cheese (Small 7")', 'price': 190},
      {'category': 'Pizza', 'name': 'Cheese Burst (Small 7")', 'price': 210},
      {'category': 'Pizza', 'name': 'Hangout Special (Small 7")', 'price': 210},

      // 🍕 PIZZA (Large 9 inch)
      {'category': 'Pizza', 'name': 'Margherita (Large 9")', 'price': 180},
      {'category': 'Pizza', 'name': 'Veg Delight (Large 9")', 'price': 200},
      {'category': 'Pizza', 'name': 'Tandoori Paneer (Large 9")', 'price': 210},
      {'category': 'Pizza', 'name': 'Mexican (Large 9")', 'price': 210},
      {'category': 'Pizza', 'name': 'American Corn (Large 9")', 'price': 230},
      {'category': 'Pizza', 'name': 'Double Cheese (Large 9")', 'price': 240},
      {'category': 'Pizza', 'name': 'Cheese Burst (Large 9")', 'price': 270},
      {'category': 'Pizza', 'name': 'Hangout Special (Large 9")', 'price': 270},

      // Extra Cheese
      {'category': 'Pizza', 'name': 'Extra Cheese Add-on', 'price': 20},

      // 🍔 BURGER
      {'category': 'Burger', 'name': 'Classic Burger', 'price': 59},
      {'category': 'Burger', 'name': 'Veg Cheese Burger', 'price': 79},
      {'category': 'Burger', 'name': 'Tandoori Burger', 'price': 89},
      {'category': 'Burger', 'name': 'Peri Peri Burger', 'price': 89},
      {'category': 'Burger', 'name': 'Thousand Burger', 'price': 89},
      {'category': 'Burger', 'name': 'Makhani Burger', 'price': 99},
      {'category': 'Burger', 'name': 'American Burger', 'price': 99},

      // 🌯 FRANKIE
      {'category': 'Frankie', 'name': 'Veg Cheese', 'price': 89},
      {'category': 'Frankie', 'name': 'Peri Peri Frankie', 'price': 100},
      {'category': 'Frankie', 'name': 'Veg Schezwan', 'price': 100},
      {'category': 'Frankie', 'name': 'Paneer Tandoori', 'price': 120},
      {'category': 'Frankie', 'name': 'Cheese Chilli', 'price': 130},

      // 🍟 FRENCH FRIES
      {
        'category': 'French Fries',
        'name': 'French Fries (Salted)',
        'price': 89,
      },
      {
        'category': 'French Fries',
        'name': 'French Fries (Peri Peri)',
        'price': 99,
      },
      {'category': 'French Fries', 'name': 'Tandoori Fries', 'price': 119},
      {'category': 'French Fries', 'name': 'Cheese Fries', 'price': 119},

      // 🧄 GARLIC BREAD (4 PCS)
      {'category': 'Garlic Bread', 'name': 'Cheese Garlic', 'price': 99},
      {'category': 'Garlic Bread', 'name': 'Veg Garlic', 'price': 110},
      {'category': 'Garlic Bread', 'name': 'Corn Chilli Garlic', 'price': 120},
      {'category': 'Garlic Bread', 'name': 'Olives & Jalapeno', 'price': 129},

      // 🍝 PASTA
      {'category': 'Pasta', 'name': 'Red Sauce Pasta', 'price': 100},
      {'category': 'Pasta', 'name': 'White Sauce Pasta', 'price': 130},
      {'category': 'Pasta', 'name': 'Olive Oil Pasta', 'price': 150},

      // 🍜 MAGGI
      {'category': 'Maggi', 'name': 'Masala Maggi', 'price': 69},
      {'category': 'Maggi', 'name': 'Veg Cheese Maggi', 'price': 80},
      {'category': 'Maggi', 'name': 'Olives Jalapeno Maggi', 'price': 90},
      {'category': 'Maggi', 'name': 'Corn Cheese Maggi', 'price': 90},
      {'category': 'Maggi', 'name': 'Tadka Maggi', 'price': 100},

      // ☕ TEA / COFFEE
      {'category': 'Tea & Coffee', 'name': 'Masala Tea (Half)', 'price': 15},
      {'category': 'Tea & Coffee', 'name': 'Masala Tea (Full)', 'price': 25},
      {'category': 'Tea & Coffee', 'name': 'Adrak Tea (Half)', 'price': 15},
      {'category': 'Tea & Coffee', 'name': 'Adrak Tea (Full)', 'price': 25},
      {'category': 'Tea & Coffee', 'name': 'Elaichi Tea (Half)', 'price': 20},
      {'category': 'Tea & Coffee', 'name': 'Elaichi Tea (Full)', 'price': 30},
      {'category': 'Tea & Coffee', 'name': 'Pudina Tea (Half)', 'price': 20},
      {'category': 'Tea & Coffee', 'name': 'Pudina Tea (Full)', 'price': 30},
      {'category': 'Tea & Coffee', 'name': 'Hot Coffee', 'price': 40},
      {'category': 'Tea & Coffee', 'name': 'Hot Bornvita', 'price': 50},

      // 🥤 COLD BEVERAGES (350ml)
      {'category': 'Cold Beverages', 'name': 'Cold Coffee', 'price': 99},
      {
        'category': 'Cold Beverages',
        'name': 'Chocolate Cold Coffee',
        'price': 110,
      },
      {'category': 'Cold Beverages', 'name': 'Cold Bornvita', 'price': 120},
      {
        'category': 'Cold Beverages',
        'name': 'Cold Coffee with Ice Cream',
        'price': 140,
      },

      // 🥤 SHAKES
      {'category': 'Shakes', 'name': 'Vanilla Shake', 'price': 89},
      {'category': 'Shakes', 'name': 'Chocolate Shake', 'price': 110},
      {'category': 'Shakes', 'name': 'Oreo Shake', 'price': 120},
      {'category': 'Shakes', 'name': 'Kit Kat Shake', 'price': 120},
      {'category': 'Shakes', 'name': 'Strawberry Shake', 'price': 130},
      {'category': 'Shakes', 'name': 'Blueberry Shake', 'price': 130},

      // 🍹 MOJITO / MOCKTAIL
      {'category': 'Mojito & Mocktail', 'name': 'Virgin Mojito', 'price': 99},
      {'category': 'Mojito & Mocktail', 'name': 'Blue Lagoon', 'price': 99},
      {
        'category': 'Mojito & Mocktail',
        'name': 'Blueberry Mojito',
        'price': 99,
      },
      {
        'category': 'Mojito & Mocktail',
        'name': 'Green Apple Mojito',
        'price': 99,
      },
      {
        'category': 'Mojito & Mocktail',
        'name': 'Watermelon Mojito',
        'price': 110,
      },
      {'category': 'Mojito & Mocktail', 'name': 'Chilli Guava', 'price': 120},

      // 🍱 SPECIAL COMBO MEALS
      {
        'category': 'SPECIAL COMBO MEALS',
        'name': 'Veg Cheese Frankie + Corn Chilly Toast + Cold Drink (20rs)',
        'price': 149,
      },
      {
        'category': 'SPECIAL COMBO MEALS',
        'name':
            'Veg Cheese Burger + Peri Peri French Fries + Cold Drink (20rs)',
        'price': 159,
      },
      {
        'category': 'SPECIAL COMBO MEALS',
        'name':
            'Tandoori Paneer Sandwich + Peri Peri Burger + Cold Drink (20rs)',
        'price': 189,
      },
      {
        'category': 'SPECIAL COMBO MEALS',
        'name': 'Tandoori Paneer Pizza + Garlic Bread + Cold Drink (20rs)',
        'price': 229,
      },

      // 🥤 COLD DRINK (bottled)
      {'category': 'Cold Drink', 'name': 'Coca Cola', 'price': 20},
      {'category': 'Cold Drink', 'name': 'Sprite', 'price': 20},
      {'category': 'Cold Drink', 'name': 'Fanta', 'price': 20},
      {'category': 'Cold Drink', 'name': 'Thumbs Up', 'price': 20},

      // 💧 WATER BOTTLE
      {'category': 'Water Bottle', 'name': 'Water Bottle (Small)', 'price': 10},
      {'category': 'Water Bottle', 'name': 'Water Bottle (Large)', 'price': 20},
    ];

    var insertedItems = 0;
    for (final item in items) {
      final name = item['name'] as String;
      final catName = (item['category'] as String).toLowerCase().trim();
      final catId = categoryIds[catName];
      if (catId == null) continue;

      // Use category+name composite key to prevent cross-category false skips
      final compositeKey = '$catId|${name.toLowerCase().trim()}';
      if (existingKeys.contains(compositeKey)) continue;

      await db
          .into(db.items)
          .insert(
            ItemsCompanion(
              id: Value(uuid.v4()),
              categoryId: Value(catId),
              name: Value(name),
              price: Value((item['price'] as int).toDouble()),
            ),
            mode: InsertMode.insertOrReplace,
          );
      existingKeys.add(compositeKey);
      insertedItems++;
    }

    if (insertedItems > 0 || catDupeCount > 0 || itemDupeCount > 0) {
      logDebug(
        '🌱 Menu seed: inserted $insertedItems new items, '
        'removed $catDupeCount duplicate categories, '
        'removed $itemDupeCount duplicate items',
      );
    } else {
      logDebug('✅ Menu already seeded. Skipping default seeding.');
    }
  }
}

/// Consolidates duplicate categories (same case-insensitive name) into a single category.
/// Re-parents items to the kept category and soft-deletes the duplicates.
Future<int> _dedupeCategories(AppDatabase db) async {
  final all = await db.select(db.categories).get();
  final seen = <String, String>{};
  final dupes = <String>[];

  // Map lowercase name -> ID of the kept category
  for (final cat in all) {
    if (cat.isDeleted) continue;

    final key = cat.name.toLowerCase().trim();
    if (seen.containsKey(key)) {
      final keptId = seen[key]!;
      dupes.add(cat.id);

      // Re-parent all items from this duplicate category to the kept category
      await (db.update(db.items)..where((t) => t.categoryId.equals(cat.id)))
          .write(ItemsCompanion(categoryId: Value(keptId)));
    } else {
      seen[key] = cat.id;
    }
  }

  if (dupes.isNotEmpty) {
    await (db.update(db.categories)..where((t) => t.id.isIn(dupes))).write(
      const CategoriesCompanion(isDeleted: Value(true)),
    );
    logDebug(
      '🧹 Soft-deleted ${dupes.length} duplicate categories and migrated their items.',
    );
  }
  return dupes.length;
}

/// Soft-deletes duplicate items (same categoryId + name), keeping the first one.
Future<int> _dedupeItems(AppDatabase db) async {
  final all = await db.select(db.items).get();
  final seen = <String, String>{};
  final dupes = <String>[];

  for (final item in all) {
    if (item.isDeleted) continue;
    final key = '${item.categoryId}|${item.name.toLowerCase().trim()}';
    if (seen.containsKey(key)) {
      dupes.add(item.id);
    } else {
      seen[key] = item.id;
    }
  }

  if (dupes.isNotEmpty) {
    await (db.update(db.items)..where((t) => t.id.isIn(dupes))).write(
      const ItemsCompanion(isDeleted: Value(true)),
    );
    logDebug('🧹 Soft-deleted ${dupes.length} duplicate menu items');
  }
  return dupes.length;
}