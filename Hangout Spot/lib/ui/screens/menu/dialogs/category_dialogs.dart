import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:uuid/uuid.dart';

void showEditCategorySelectDialog(BuildContext context, WidgetRef ref) {
  final categoriesAsync = ref.read(categoriesStreamProvider);
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final cream = isDark ? theme.colorScheme.background : const Color(0xFFFEF9F5);
  final coffee = isDark ? theme.colorScheme.primary : const Color(0xFF95674D);
  final coffeeDark = isDark
      ? theme.colorScheme.onSurface
      : const Color(0xFF98664D);
  final caramel = isDark
      ? theme.colorScheme.secondary
      : const Color(0xFFEDAD4C);

  categoriesAsync.when(
    data: (categories) {
      if (categories.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No categories to edit')));
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
                child: Icon(Icons.edit_outlined, color: coffeeDark, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select Category',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: coffeeDark,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  leading: Icon(
                    _getCategoryIconForDialog(category.name),
                    color: coffee,
                    size: 20,
                  ),
                  title: Text(
                    category.name,
                    style: TextStyle(color: coffeeDark, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showEditCategoryDialog(context, ref, category);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: coffeeDark.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      );
    },
    loading: () {},
    error: (_, __) {},
  );
}

IconData _getCategoryIconForDialog(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('all')) return Icons.apps;
  if (lower.contains('coffee') ||
      lower.contains('tea') ||
      lower.contains('beverage')) {
    return Icons.coffee;
  }
  if (lower.contains('toast') || lower.contains('bread')) {
    return Icons.breakfast_dining;
  }
  if (lower.contains('sandwich')) return Icons.lunch_dining;
  if (lower.contains('pizza')) return Icons.local_pizza;
  if (lower.contains('burger')) return Icons.fastfood;
  if (lower.contains('frankie')) return Icons.wrap_text;
  if (lower.contains('fries')) return Icons.fastfood;
  if (lower.contains('shake')) return Icons.local_cafe;
  if (lower.contains('mojito') || lower.contains('mocktail')) {
    return Icons.local_bar;
  }
  if (lower.contains('maggi') || lower.contains('pasta')) {
    return Icons.ramen_dining;
  }
  if (lower.contains('garlic')) return Icons.bakery_dining;
  if (lower.contains('dessert') || lower.contains('sweet')) return Icons.cake;
  return Icons.restaurant;
}

void showEditCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  Category category,
) {
  final nameController = TextEditingController(text: category.name);
  final discountController = TextEditingController(
    text: category.discountPercent.toString(),
  );
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final cream = isDark ? theme.colorScheme.background : const Color(0xFFFEF9F5);
  final surface = isDark ? theme.colorScheme.surface : const Color(0xFFFFF3E8);
  final coffee = isDark ? theme.colorScheme.primary : const Color(0xFF95674D);
  final coffeeDark = isDark
      ? theme.colorScheme.onSurface
      : const Color(0xFF98664D);
  final caramel = isDark
      ? theme.colorScheme.secondary
      : const Color(0xFFEDAD4C);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: caramel.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.edit_rounded, color: coffeeDark, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Edit Category',
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
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.label_rounded, size: 20),
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(color: coffeeDark, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: discountController,
              decoration: InputDecoration(
                labelText: 'Category Discount %',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.local_offer_rounded, size: 20),
                suffixText: '%',
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(color: coffeeDark, fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            ref.read(menuRepositoryProvider).deleteCategory(category.id);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${category.name} deleted'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
          style: TextButton.styleFrom(foregroundColor: Colors.red[300]),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: coffeeDark.withOpacity(0.8)),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              final discount = double.tryParse(discountController.text) ?? 0.0;
              ref
                  .read(menuRepositoryProvider)
                  .updateCategory(
                    category.copyWith(
                      name: nameController.text,
                      discountPercent: discount,
                    ),
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Category updated'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: coffee,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

void showAddCategoryDialog(BuildContext context, WidgetRef ref) {
  final nameController = TextEditingController();
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final cream = isDark ? theme.colorScheme.background : const Color(0xFFFEF9F5);
  final surface = isDark ? theme.colorScheme.surface : const Color(0xFFFFF3E8);
  final coffeeDark = isDark
      ? theme.colorScheme.onSurface
      : const Color(0xFF98664D);
  final caramel = isDark
      ? theme.colorScheme.secondary
      : const Color(0xFFEDAD4C);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: caramel.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.category_rounded, color: coffeeDark, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Add Category',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: coffeeDark,
              ),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(
          labelText: 'Category Name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: const Icon(Icons.label_rounded, size: 20),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: coffeeDark.withOpacity(0.8)),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              ref
                  .read(menuRepositoryProvider)
                  .addCategory(
                    CategoriesCompanion(
                      id: drift.Value(const Uuid().v4()),
                      name: drift.Value(nameController.text),
                      color: const drift.Value(0xFF6750A4),
                    ),
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${nameController.text} category added'),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Add',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
