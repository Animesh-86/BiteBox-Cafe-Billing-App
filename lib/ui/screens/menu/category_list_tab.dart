import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'item_list_tab.dart';

class CategoryListTab extends ConsumerWidget {
  const CategoryListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) {
        final allCats = [
          const Category(
            id: 'all',
            name: 'All',
            color: 0,
            sortOrder: -1,
            isDeleted: false,
            discountPercent: 0.0,
          ),
          ...categories,
        ];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allCats.length,
                itemBuilder: (context, index) {
                  final cat = allCats[index];
                  final selectedCat = ref.watch(adminSelectedCategoryProvider);
                  final isSelected =
                      selectedCat == cat.id ||
                      (selectedCat == null && cat.id == 'all');

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Material(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          ref
                                  .read(adminSelectedCategoryProvider.notifier)
                                  .state =
                              cat.id;
                        },
                        onLongPress: () {
                          if (cat.id != 'all') {
                            _showAddEditDialog(context, ref, category: cat);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _getCategoryIcon(cat.name),
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white70,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('all')) return Icons.apps;
    if (lower.contains('coffee') || lower.contains('beverage'))
      return Icons.coffee;
    if (lower.contains('toast') || lower.contains('bread'))
      return Icons.breakfast_dining;
    if (lower.contains('sandwich')) return Icons.lunch_dining;
    if (lower.contains('pizza')) return Icons.local_pizza;
    if (lower.contains('burger')) return Icons.fastfood;
    if (lower.contains('dessert') || lower.contains('sweet')) return Icons.cake;
    return Icons.restaurant;
  }

  void _showAddEditDialog(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
  }) {
    final nameController = TextEditingController(text: category?.name ?? '');
    int selectedColor = category?.color ?? 0xFF6750A4;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          if (category != null)
            TextButton(
              onPressed: () {
                ref.read(menuRepositoryProvider).deleteCategory(category.id);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                if (category == null) {
                  ref
                      .read(menuRepositoryProvider)
                      .addCategory(
                        CategoriesCompanion(
                          id: drift.Value(const Uuid().v4()),
                          name: drift.Value(nameController.text),
                          color: drift.Value(selectedColor),
                        ),
                      );
                } else {
                  ref
                      .read(menuRepositoryProvider)
                      .updateCategory(
                        category.copyWith(name: nameController.text),
                      );
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
