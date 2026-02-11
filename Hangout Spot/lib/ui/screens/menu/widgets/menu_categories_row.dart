import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/ui/screens/menu/menu_providers.dart';

class MenuCategoriesRow extends ConsumerStatefulWidget {
  final Function(Category) onEditCategory;

  const MenuCategoriesRow({super.key, required this.onEditCategory});

  @override
  ConsumerState<MenuCategoriesRow> createState() => _CategoriesRowState();
}

class _CategoriesRowState extends ConsumerState<MenuCategoriesRow> {
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
    final selectedCat = ref.watch(adminSelectedCategoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark ? theme.colorScheme.surface : const Color(0xFFFEF9F5);
    final coffee = isDark ? theme.colorScheme.primary : const Color(0xFF95674D);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);
    final caramel = isDark
        ? theme.colorScheme.secondary
        : const Color(0xFFEDAD4C);

    ref.listen<String?>(adminSelectedCategoryProvider, (previous, next) {
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

        // Ensure keys exist
        for (final cat in allCats) {
          _categoryKeys.putIfAbsent(cat.id, () => GlobalKey());
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              for (int i = 0; i < allCats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _buildCategoryItem(
                  context,
                  ref,
                  allCats[i],
                  selectedCat,
                  isDark,
                  cream,
                  coffee,
                  coffeeDark,
                  caramel,
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    WidgetRef ref,
    Category cat,
    String? selectedCat,
    bool isDark,
    Color cream,
    Color coffee,
    Color coffeeDark,
    Color caramel,
  ) {
    final isSelected =
        selectedCat == cat.id || (selectedCat == null && cat.id == 'all');

    return GestureDetector(
      key: _categoryKeys[cat.id],
      onTap: () {
        ref.read(adminSelectedCategoryProvider.notifier).state = cat.id;
      },
      onLongPress: () {
        if (cat.id != 'all') {
          widget.onEditCategory(cat);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [caramel.withOpacity(0.55), coffee.withOpacity(0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            width: isSelected ? 1.5 : 1,
            color: isSelected ? coffee : coffee.withOpacity(0.25),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: coffee.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? coffeeDark : coffeeDark.withOpacity(0.8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
