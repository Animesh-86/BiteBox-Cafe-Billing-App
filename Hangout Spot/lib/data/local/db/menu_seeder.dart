import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

class MenuSeeder {
  static Future<void> seedDefaultMenu(AppDatabase db) async {
    final existingCategories = await db.select(db.categories).get();
    debugPrint('🌱 Seeding menu entries (idempotent)...');

    final uuid = const Uuid();

    // --- Define Categories ---
    final categories = [
      {'name': 'Toast', 'color': 0xFFFFB74D}, // Orange Light
      {'name': 'Sandwich', 'color': 0xFFFF9800}, // Orange
      {'name': 'Grilled Sandwich', 'color': 0xFFF57C00}, // Orange Dark
      {'name': 'Pizza', 'color': 0xFFFFC107}, // Amber
      {'name': 'Burger', 'color': 0xFFF44336}, // Red
      {'name': 'Frankie', 'color': 0xFF8D6E63}, // Brown Light
      {'name': 'French Fries', 'color': 0xFFFFEB3B}, // Yellow
      {'name': 'Garlic Bread', 'color': 0xFFD4E157}, // Lime
      {'name': 'Pasta', 'color': 0xFF9C27B0}, // Purple
      {'name': 'Maggi', 'color': 0xFFFFCA28}, // Amber Light
      {'name': 'Tea & Coffee', 'color': 0xFF795548}, // Brown
      {'name': 'Cold Beverages', 'color': 0xFF2196F3}, // Blue
      {'name': 'Shakes', 'color': 0xFFE91E63}, // Pink
      {'name': 'Mojito & Mocktail', 'color': 0xFF00BCD4}, // Cyan
      {'name': 'SPECIAL COMBO MEALS', 'color': 0xFF4CAF50}, // Green
      {'name': 'Cold Drink', 'color': 0xFF1976D2}, // Blue darker
      {'name': 'Water Bottle', 'color': 0xFF90CAF9}, // Light blue
    ];

    // Cache existing categories and items for idempotent inserts
    final categoryIds = {
      for (final cat in existingCategories) cat.name: cat.id,
    };
    final existingItems = await db.select(db.items).get();
    final existingItemNames = existingItems.map((e) => e.name).toSet();

    // Ensure all categories exist
    var sortIndex = existingCategories.length;
    for (var i = 0; i < categories.length; i++) {
      final name = categories[i]['name'] as String;
      if (categoryIds.containsKey(name)) continue;
      final id = uuid.v4();
      categoryIds[name] = id;
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

    for (final item in items) {
      final name = item['name'] as String;
      if (existingItemNames.contains(name)) continue;

      final catId = categoryIds[item['category'] as String];
      if (catId == null) continue;

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
      existingItemNames.add(name);
    }

    // Soft-delete duplicate items (same name + category) while keeping the first
    await _dedupeItems(db);

    debugPrint('🌱 Exact Hangout Spot menu seeded successfully!');
  }
}

Future<void> _dedupeItems(AppDatabase db) async {
  final all = await db.select(db.items).get();
  final seen = <String, String>{};
  final dupes = <String>[];

  for (final item in all) {
    if (item.isDeleted) continue;
    final key = '${item.categoryId}|${item.name.toLowerCase()}';
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
    debugPrint('ℹ️ Soft-deleted ${dupes.length} duplicate menu items');
  }
}
