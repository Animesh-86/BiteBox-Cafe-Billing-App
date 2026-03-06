import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/widgets/glass_container.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/ui/screens/inventory/inventory_screen.dart';
import 'item_list_tab.dart';
import 'package:hangout_spot/ui/screens/menu/menu_providers.dart';
import 'widgets/menu_categories_row.dart';
import 'dialogs/category_dialogs.dart';
import 'dialogs/item_dialogs.dart';

class ManageMenuScreen extends ConsumerWidget {
  const ManageMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedCat = ref.watch(adminSelectedCategoryProvider);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark
        ? theme.colorScheme.background
        : const Color(0xFFFEF9F5);
    final surface = isDark
        ? theme.colorScheme.surface
        : const Color(0xFFFFF3E8);
    final coffee = isDark ? theme.colorScheme.primary : const Color(0xFF95674D);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);
    final caramel = isDark
        ? theme.colorScheme.secondary
        : const Color(0xFFEDAD4C);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: caramel.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: coffeeDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Menu Management',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                fontSize: 18,
                color: coffeeDark,
              ),
            ),
          ],
        ),
        backgroundColor: cream,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Inventory',
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            color: coffee,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Edit Category',
            icon: Icon(Icons.edit_outlined, size: 18, color: coffee),
            onPressed: () {
              showEditCategorySelectDialog(context, ref);
            },
          ),
          IconButton(
            tooltip: 'New Category',
            icon: Icon(Icons.add_circle_outline, size: 18, color: coffee),
            onPressed: () {
              showAddCategoryDialog(context, ref);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: coffeeDark,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showSmartAddItemDialog(context, ref, selectedCat);
                  },
                  icon: Icon(Icons.add_circle_outline, size: 16, color: coffee),
                  label: Text(
                    'Add Item',
                    style: TextStyle(color: coffee, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Categories Row (horizontal like billing)
            SizedBox(
              height: 52,
              child: MenuCategoriesRow(
                onEditCategory: (category) {
                  showEditCategoryDialog(context, ref, category);
                },
              ),
            ),
            const SizedBox(height: 16),
            // Items Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Menu Items',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: coffeeDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: caramel.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedCat == null || selectedCat == 'all'
                        ? 'All Items'
                        : _getCategoryName(ref, selectedCat),
                    style: TextStyle(
                      color: coffeeDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Items Grid
            Expanded(
              child: GlassContainer(
                borderRadius: BorderRadius.circular(20),
                color: surface,
                opacity: 1,
                padding: const EdgeInsets.all(12),
                child: const ItemListTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(WidgetRef ref, String? categoryId) {
    if (categoryId == null || categoryId == 'all') return 'Category';
    final categoriesAsync = ref.read(categoriesStreamProvider);
    return categoriesAsync.when(
      data: (categories) {
        final cat = categories.where((c) => c.id == categoryId).firstOrNull;
        return cat?.name ?? 'Category';
      },
      loading: () => 'Category',
      error: (_, __) => 'Category',
    );
  }
}
