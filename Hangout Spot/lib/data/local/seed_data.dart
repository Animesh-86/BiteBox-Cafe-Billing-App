import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';

class MenuSeeder {
  static const String _comboCategory = 'SPECIAL COMBO MEALS';
  static const List<Map<String, dynamic>> _comboItems = [
    {
      'name': 'Veg Cheese Frankie + Corn Chilly Toast + Cold Drink (20rs)',
      'price': 149.0,
    },
    {
      'name': 'Veg Cheese Burger + Peri Peri French Fries + Cold Drink (20rs)',
      'price': 159.0,
    },
    {
      'name': 'Tandoori Paneer Sandwich + Peri Peri Burger + Cold Drink (20rs)',
      'price': 189.0,
    },
    {
      'name': 'Tandoori Paneer Pizza + Garlic Bread + Cold Drink (20rs)',
      'price': 229.0,
    },
  ];

  static const Map<String, List<String>> menuData = {
    "TOAST": [
      "Cheese Chilly Toast — 80",
      "Corn chilly Toast — 90",
      "Paneer Toast — 99",
      "Olive Jalapeno Toast — 110",
    ],
    "SANDWICH": [
      "Bread Butter with cheese — 59",
      "Bread Butter Jam — 69",
      "Bread Butter jam cheese — 79",
      "Cheese Chutney — 79",
    ],
    "GRILLED SANDWICH": [
      "Cheese Chutney — 89",
      "Veg. Cheese — 99",
      "Pari Peri Cheese — 110",
      "Chilli Mayo Cheese — 110",
      "Cheese Chilli Corn — 120",
      "Tandoori Paneer — 130",
      "Makhani Paneer — 130",
      "Maxican — 140",
    ],
    "PIZZA": [
      "Margherita (Small) — 130",
      "Margherita (Large) — 180",
      "Veg.Delight (Small) — 150",
      "Veg.Delight (Large) — 200",
      "Tandoori Paneer (Small) — 160",
      "Tandoori Paneer (Large) — 210",
      "Maxican (Small) — 160",
      "Maxican (Large) — 210",
      "American corn (Small) — 180",
      "American corn (Large) — 230",
      "Double Cheese (Small) — 190",
      "Double Cheese (Large) — 240",
      "Cheese Burst (Small) — 210",
      "Cheese Burst (Large) — 270",
      "Hangout special (Small) — 210",
      "Hangout special (Large) — 270",
      "Extra Cheese — 20",
    ],
    "BURGER": [
      "Classic Burger — 59",
      "Veg cheese Burger — 79",
      "Tandoori Burger — 89",
      "Peri peri Burger — 89",
      "Thousand Burger — 89",
      "Makhani Burger — 99",
      "American Burger — 99",
    ],
    "FRANKIE": [
      "Veg.Cheese — 89",
      "Peri Peri Frankie — 100",
      "Veg.Schezwan — 100",
      "Paneer Tandoori — 120",
      "Cheese Chilli — 130",
    ],
    "TEA/COFFEE": [
      "Masala Tea (Half) — 15",
      "Masala Tea (Full) — 25",
      "Adrak Tea (Half) — 15",
      "Adrak Tea (Full) — 25",
      "Elaichi Tea (Half) — 20",
      "Elaichi Tea (Full) — 30",
      "Pudina Tea (Half) — 20",
      "Pudina Tea (Full) — 30",
      "Hot Coffee — 40",
      "Hot Bornvita — 50",
    ],
    "COLD BEVERAGES": [
      "Cold Coffee — 99",
      "Chocolate cold coffee — 110",
      "Cold Bornvita — 120",
      "Cold Coffee with Ice-crem — 140",
    ],
    "FRENCH FRIES": [
      "French Fries(salted) — 89",
      "French Fries(peri peri) — 99",
      "Tandoori Fries — 119",
      "Cheese Fries — 119",
    ],
    "SHAKES": [
      "Vanila Shake — 89",
      "Chocolate Shake — 110",
      "Oreo Shake — 120",
      "Kit Kat Shake — 120",
      "Strawberry Shake — 130",
      "Blue Berry Shake — 130",
    ],
    "MOJITO/MOCKTAIL": [
      "Virgin Mojito — 99",
      "Blue Lagoon — 99",
      "Blue Berry — 99",
      "Green Apple — 99",
      "Watermelon — 110",
      "Chilli Gava — 120",
    ],
    "MAGGI": [
      "Masala Maggi — 69",
      "Veg Cheese Maggi — 80",
      "Olives Jalapeno — 90",
      "Corn Cheese Maggi — 90",
      "Tadka Maggi — 100",
    ],
    "PASTA": [
      "Red Sauce Pasta — 100",
      "White Sauce Pasta — 130",
      "Olive Oil Pasta — 150",
    ],
    "GARLIC BREAD": [
      "Cheese Garlic — 99",
      "Veg.Garlic — 110",
      "Corn Chilli Garlic — 120",
      "Olives & Jalapeno — 129",
    ],
  };

  static Future<void> seed(MenuRepository repo) async {
    final hasData = await repo.hasCategories();
    if (hasData) {
      await _ensureComboMeals(repo);
      return;
    }

    int sortOrder = 0;
    const namespace = Uuid.NAMESPACE_URL;
    final uuid = const Uuid();

    for (var entry in menuData.entries) {
      final catId = uuid.v5(namespace, 'category_${entry.key}');
      await repo.addCategory(
        CategoriesCompanion(
          id: drift.Value(catId),
          name: drift.Value(entry.key),
          sortOrder: drift.Value(sortOrder++),
          color: drift.Value(0xFF2196F3), // Default Blue
        ),
      );

      for (var itemStr in entry.value) {
        final parts = itemStr.split('—');
        final name = parts[0].trim();
        final price = double.parse(parts[1].trim());

        await repo.addItem(
          ItemsCompanion(
            id: drift.Value(uuid.v5(namespace, 'item_${catId}_$name')),
            categoryId: drift.Value(catId),
            name: drift.Value(name),
            price: drift.Value(price),
            isAvailable: const drift.Value(true),
          ),
        );
      }
    }

    await _ensureComboMeals(repo);
  }

  static Future<void> _ensureComboMeals(MenuRepository repo) async {
    final categories = await repo.watchCategories().first;
    final namespace = Uuid.NAMESPACE_URL;
    final uuid = const Uuid();

    String? comboCategoryId;
    for (final category in categories) {
      if (category.name.trim().toUpperCase() == _comboCategory) {
        comboCategoryId = category.id;
        break;
      }
    }

    if (comboCategoryId == null || comboCategoryId.isEmpty) {
      final nextSortOrder = categories.isEmpty
          ? 0
          : categories
                    .map((category) => category.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;

      comboCategoryId = uuid.v5(namespace, 'category_$_comboCategory');
      await repo.addCategory(
        CategoriesCompanion(
          id: drift.Value(comboCategoryId),
          name: const drift.Value(_comboCategory),
          sortOrder: drift.Value(nextSortOrder),
          color: const drift.Value(0xFF4CAF50),
        ),
      );
    }

    final existingItems = await repo.watchAllItems().first;
    final existingNames = existingItems
        .where((item) => item.categoryId == comboCategoryId)
        .map((item) => item.name.trim().toLowerCase())
        .toSet();

    for (final item in _comboItems) {
      final itemName = item['name'] as String;
      if (existingNames.contains(itemName.trim().toLowerCase())) {
        continue;
      }

      await repo.addItem(
        ItemsCompanion(
          id: drift.Value(
            uuid.v5(namespace, 'item_${comboCategoryId}_$itemName'),
          ),
          categoryId: drift.Value(comboCategoryId),
          name: drift.Value(itemName),
          price: drift.Value(item['price'] as double),
          isAvailable: const drift.Value(true),
        ),
      );
    }
  }
}

class LocationSeeder {
  static Future<void> seed(AppDatabase db) async {
    final count = await (db.select(db.locations)..limit(1)).get();
    if (count.isEmpty) {
      // Seed default location
      await db
          .into(db.locations)
          .insert(
            LocationsCompanion(
              id: drift.Value(const Uuid().v4()),
              name: const drift.Value('Main Outlet'),
              address: const drift.Value('Main Street'),
              phoneNumber: const drift.Value(''),
              isActive: const drift.Value(true),
              createdAt: drift.Value(DateTime.now()),
            ),
          );
    }
  }
}
