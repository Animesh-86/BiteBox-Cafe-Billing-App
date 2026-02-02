import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';

class MenuSeeder {
  static const Map<String, List<String>> menuData = {
    "TOAST": [
      "Cheese Chilli Toast — 80",
      "Corn Chilli Toast — 90",
      "Paneer Toast — 99",
      "Olive Jalapeno Toast — 110",
    ],
    "SANDWICH": [
      "Bread Butter with Cheese — 59",
      "Bread Butter Jam — 69",
      "Bread Butter Jam Cheese — 79",
      "Cheese Chutney — 79",
    ],
    "GRILLED SANDWICH": [
      "Cheese Chutney — 89",
      "Veg Cheese — 99",
      "Peri Peri Cheese — 110",
      "Chilli Mayo Cheese — 110",
      "Cheese Chilli Corn — 120",
    ],
    "PIZZA": [
      "Margherita (Small) — 130",
      "Margherita (Large) — 180",
      "Veg Delight (Small) — 150",
      "Veg Delight (Large) — 200",
      "Tandoori Paneer (Small) — 160",
      "Tandoori Paneer (Large) — 210",
      "Mexican (Small) — 160",
      "Mexican (Large) — 210",
      "American Corn (Small) — 180",
      "American Corn (Large) — 230",
      "Double Cheese (Small) — 190",
      "Double Cheese (Large) — 240",
      "Cheese Burst (Small) — 210",
      "Cheese Burst (Large) — 270",
      "Hangout Special (Small) — 210",
      "Hangout Special (Large) — 270",
    ],
    "BURGER": [
      "Classic Burger — 59",
      "Veg Cheese Burger — 79",
      "Tandoori Burger — 89",
      "Peri Peri Burger — 89",
      "Thousand Burger — 89",
      "Makhani Burger — 99",
      "American Burger — 99",
    ],
    "FRANKIE": [
      "Veg Frankie — 89",
      "Peri Peri Frankie — 100",
      "Veg Schezwan Frankie — 100",
      "Paneer Tandoori Frankie — 120",
      "Cheese Chilli Frankie — 130",
    ],
    "TEA / COFFEE": [
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
      "Chocolate Cold Coffee — 110",
      "Cold Bornvita — 120",
      "Cold Coffee with Ice Cream — 140",
    ],
    "FRENCH FRIES": [
      "French Fries (Salted) — 89",
      "French Fries (Peri Peri) — 99",
      "Tandoori Fries — 119",
      "Cheese Fries — 119",
    ],
    "SHAKES": [
      "Vanilla Shake — 89",
      "Chocolate Shake — 110",
      "Oreo Shake — 120",
      "KitKat Shake — 120",
      "Strawberry Shake — 130",
      "Blue Berry Shake — 130",
    ],
    "MOJITO / MOCKTAIL": [
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
      "Olives Jalapeno Maggi — 90",
      "Corn Cheese Maggi — 90",
      "Tadka Maggi — 100",
    ],
    "PASTA": [
      "Red Sauce Pasta — 100",
      "White Sauce Pasta — 130",
      "Olive Oil Pasta — 150",
    ],
    "GARLIC BREAD": [
      "Cheese Garlic Bread — 99",
      "Veg Garlic Bread — 110",
      "Corn Chilli Garlic Bread — 120",
    ],
  };

  static Future<void> seed(MenuRepository repo) async {
    final hasData = await repo.hasCategories();
    if (hasData) return;

    int sortOrder = 0;
    for (var entry in menuData.entries) {
      final catId = const Uuid().v4();
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
            id: drift.Value(const Uuid().v4()),
            categoryId: drift.Value(catId),
            name: drift.Value(name),
            price: drift.Value(price),
            isAvailable: const drift.Value(true),
          ),
        );
      }
    }
  }
}
