import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:uuid/uuid.dart';

void showSmartAddItemDialog(
  BuildContext context,
  WidgetRef ref,
  String? selectedCategoryId,
) {
  final categoriesAsync = ref.read(categoriesStreamProvider);

  categoriesAsync.when(
    data: (categories) {
      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a category first')),
        );
        return;
      }

      // If "All" is selected or no selection, show category picker
      if (selectedCategoryId == null || selectedCategoryId == 'all') {
        _showAddItemWithCategoryPicker(context, ref, categories);
        return;
      }

      // Find the selected category
      final selectedCategory = categories.firstWhere(
        (c) => c.id == selectedCategoryId,
        orElse: () => categories.first,
      );

      // Show simplified dialog with pre-selected category
      final nameController = TextEditingController();
      final priceController = TextEditingController();
      final discountController = TextEditingController(text: '0.0');

      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final cream = isDark
              ? theme.colorScheme.background
              : const Color(0xFFFEF9F5);
          final surface = isDark
              ? theme.colorScheme.surface
              : const Color(0xFFFFF3E8);
          final coffee = isDark
              ? theme.colorScheme.primary
              : const Color(0xFF95674D);
          final coffeeDark = isDark
              ? theme.colorScheme.onSurface
              : const Color(0xFF98664D);
          final caramel = isDark
              ? theme.colorScheme.secondary
              : const Color(0xFFEDAD4C);
          return AlertDialog(
            backgroundColor: cream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: caramel.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_circle_rounded,
                    color: coffeeDark,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: coffeeDark,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show category as read-only info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          caramel.withOpacity(0.35),
                          coffee.withOpacity(0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: coffee.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          selectedCategory.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: coffeeDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    autofocus: true,
                    style: TextStyle(color: coffeeDark, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 20,
                      ),
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Color(0xFF98664D),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discountController,
                    decoration: InputDecoration(
                      labelText: 'Discount Percentage',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.local_offer_rounded,
                        size: 20,
                      ),
                      suffixText: '%',
                      filled: true,
                      fillColor:
                          theme.inputDecorationTheme.fillColor ??
                          theme.colorScheme.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    final price = double.tryParse(priceController.text) ?? 0.0;
                    final discount =
                        double.tryParse(discountController.text) ?? 0.0;

                    ref
                        .read(menuRepositoryProvider)
                        .addItem(
                          ItemsCompanion(
                            id: drift.Value(const Uuid().v4()),
                            categoryId: drift.Value(selectedCategoryId),
                            name: drift.Value(nameController.text),
                            price: drift.Value(price),
                            discountPercent: drift.Value(discount),
                          ),
                        );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${nameController.text} added to ${selectedCategory.name}',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Add Item',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          );
        },
      );
    },
    loading: () {},
    error: (_, __) {},
  );
}

void _showAddItemWithCategoryPicker(
  BuildContext context,
  WidgetRef ref,
  List<Category> categories,
) {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final discountController = TextEditingController(text: '0.0');
  String? selectedCategoryId = categories.first.id;

  showDialog(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      const cream = Color(0xFFFEF9F5);
      const surface = Color(0xFFFFF3E8);
      const coffee = Color(0xFF95674D);
      const coffeeDark = Color(0xFF98664D);
      const caramel = Color(0xFFEDAD4C);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: caramel.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_circle_rounded,
                  color: coffeeDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add Item',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: coffeeDark,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: categories
                      .map(
                        (c) =>
                            DropdownMenuItem(child: Text(c.name), value: c.id),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedCategoryId = v),
                  dropdownColor: cream,
                  style: const TextStyle(
                    color: Color(0xFF98664D),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF98664D),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(
                      Icons.currency_rupee_rounded,
                      size: 20,
                    ),
                    prefixText: '₹ ',
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Color(0xFF98664D),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  decoration: InputDecoration(
                    labelText: 'Discount Percentage',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.local_offer_rounded, size: 20),
                    suffixText: '%',
                    filled: true,
                    fillColor:
                        theme.inputDecorationTheme.fillColor ??
                        theme.colorScheme.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    selectedCategoryId != null) {
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  final discount =
                      double.tryParse(discountController.text) ?? 0.0;

                  ref
                      .read(menuRepositoryProvider)
                      .addItem(
                        ItemsCompanion(
                          id: drift.Value(const Uuid().v4()),
                          categoryId: drift.Value(selectedCategoryId!),
                          name: drift.Value(nameController.text),
                          price: drift.Value(price),
                          discountPercent: drift.Value(discount),
                        ),
                      );
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: coffee,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    },
  );
}
