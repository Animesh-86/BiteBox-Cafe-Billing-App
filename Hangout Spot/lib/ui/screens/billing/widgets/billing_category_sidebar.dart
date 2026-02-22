import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/ui/screens/billing/billing_providers.dart';

class CategorySidebar extends ConsumerStatefulWidget {
  const CategorySidebar({super.key});

  @override
  ConsumerState<CategorySidebar> createState() => _CategorySidebarState();
}

class _CategorySidebarState extends ConsumerState<CategorySidebar> {
  final Map<String, GlobalKey> _categoryKeys = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);

    ref.listen<String?>(selectedCategoryProvider, (previous, next) {
      if (next != null) {
        final key = _categoryKeys[next];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    return categoriesAsync.when(
      data: (cats) {
        final allCats = [
          const Category(
            id: 'all',
            name: 'All',
            color: 0,
            sortOrder: -1,
            isDeleted: false,
            discountPercent: 0.0,
          ),
          ...cats,
        ];

        // Ensure keys exist
        for (final cat in allCats) {
          _categoryKeys.putIfAbsent(cat.id, () => GlobalKey());
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Categories',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: allCats.map((cat) {
                    final isSelected =
                        selectedCat == cat.id ||
                        (selectedCat == null && cat.id == 'all');

                    return Padding(
                      key: _categoryKeys[cat.id],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Material(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () {
                            ref.read(selectedCategoryProvider.notifier).state =
                                cat.id;
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 6,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.2)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(cat.name),
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cat.name,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
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
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
}
