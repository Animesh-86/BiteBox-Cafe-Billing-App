import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/widgets/glass_container.dart';
import 'package:drift/drift.dart' as drift;
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'item_list_tab.dart';

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
            tooltip: 'Export CSV',
            icon: const Icon(Icons.file_download_outlined, size: 18),
            color: coffee,
            onPressed: () => _exportMenuCsv(context, ref),
          ),
          IconButton(
            tooltip: 'Import CSV',
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            color: coffee,
            onPressed: () => _importMenuCsv(context, ref),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _showEditCategorySelectDialog(context, ref);
                      },
                      icon: Icon(Icons.edit_outlined, size: 16, color: coffee),
                      label: Text(
                        'Edit',
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
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () {
                        _showAddCategoryDialog(context, ref);
                      },
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: 16,
                        color: coffee,
                      ),
                      label: Text(
                        'New',
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
              ],
            ),
            const SizedBox(height: 8),
            // Categories Row (horizontal like billing)
            SizedBox(
              height: 52,
              child: _CategoriesRow(
                onEditCategory: (category) {
                  _showEditCategoryDialog(context, ref, category);
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
      // Floating Action Button at bottom
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          onPressed: () {
            _showSmartAddItemDialog(context, ref, selectedCat);
          },
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            selectedCat == null || selectedCat == 'all'
                ? 'Add Item'
                : 'Add to ${_getCategoryName(ref, selectedCat)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          backgroundColor: theme.colorScheme.primary,
          elevation: 6,
        ),
      ),
    );
  }

  Future<void> _exportMenuCsv(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final categories = await db.select(db.categories).get();
    final items = await db.select(db.items).get();

    final categoryMap = {for (final c in categories) c.id: c.name};

    final buffer = StringBuffer();
    buffer.writeln(
      'category,name,price,discountPercent,isAvailable,description,imageUrl',
    );
    for (final item in items) {
      final categoryName = categoryMap[item.categoryId] ?? '';
      buffer.writeln(
        [
          _escapeCsv(categoryName),
          _escapeCsv(item.name),
          item.price.toString(),
          item.discountPercent.toString(),
          item.isAvailable ? 'true' : 'false',
          _escapeCsv(item.description ?? ''),
          _escapeCsv(item.imageUrl ?? ''),
        ].join(','),
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/menu_export.csv');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
  }

  Future<void> _importMenuCsv(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final content = await File(path).readAsString();
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length <= 1) return;

    final db = ref.read(appDatabaseProvider);
    final repo = ref.read(menuRepositoryProvider);
    final categories = await db.select(db.categories).get();
    final categoryByName = {
      for (final c in categories) c.name.toLowerCase(): c,
    };

    int imported = 0;
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = _splitCsvLine(line);
      if (parts.length < 2) continue;

      final categoryName = parts[0].trim();
      final name = parts.length > 1 ? parts[1].trim() : '';
      if (name.isEmpty) continue;

      final price = parts.length > 2 ? double.tryParse(parts[2]) ?? 0.0 : 0.0;
      final discount = parts.length > 3
          ? double.tryParse(parts[3]) ?? 0.0
          : 0.0;
      final isAvailable = parts.length > 4
          ? parts[4].toLowerCase() != 'false'
          : true;
      final description = parts.length > 5 ? parts[5].trim() : '';
      final imageUrl = parts.length > 6 ? parts[6].trim() : '';

      Category? category = categoryByName[categoryName.toLowerCase().trim()];
      if (category == null) {
        final id = const Uuid().v4();
        category = Category(
          id: id,
          name: categoryName.isEmpty ? 'Uncategorized' : categoryName,
          color: 0xFFFFFFFF,
          sortOrder: 0,
          discountPercent: 0.0,
          isDeleted: false,
        );
        await repo.addCategory(
          CategoriesCompanion(
            id: drift.Value(category.id),
            name: drift.Value(category.name),
            color: drift.Value(category.color),
            sortOrder: drift.Value(category.sortOrder),
            discountPercent: drift.Value(category.discountPercent),
          ),
        );
        categoryByName[category.name.toLowerCase()] = category;
      }

      await repo.addItem(
        ItemsCompanion(
          id: drift.Value(const Uuid().v4()),
          categoryId: drift.Value(category.id),
          name: drift.Value(name),
          price: drift.Value(price),
          discountPercent: drift.Value(discount),
          isAvailable: drift.Value(isAvailable),
          description: drift.Value(description.isEmpty ? null : description),
          imageUrl: drift.Value(imageUrl.isEmpty ? null : imageUrl),
        ),
      );
      imported++;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported $imported items')));
    }
  }

  String _escapeCsv(String value) {
    final needsQuotes = value.contains(',') || value.contains('"');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
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

  void _showEditCategoryDialog(
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
                final discount =
                    double.tryParse(discountController.text) ?? 0.0;
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

  void _showEditCategorySelectDialog(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.read(categoriesStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark
        ? theme.colorScheme.background
        : const Color(0xFFFEF9F5);
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No categories to edit')),
          );
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
                      _showEditCategoryDialog(context, ref, category);
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
        lower.contains('beverage'))
      return Icons.coffee;
    if (lower.contains('toast') || lower.contains('bread'))
      return Icons.breakfast_dining;
    if (lower.contains('sandwich')) return Icons.lunch_dining;
    if (lower.contains('pizza')) return Icons.local_pizza;
    if (lower.contains('burger')) return Icons.fastfood;
    if (lower.contains('frankie')) return Icons.wrap_text;
    if (lower.contains('fries')) return Icons.fastfood;
    if (lower.contains('shake')) return Icons.local_cafe;
    if (lower.contains('mojito') || lower.contains('mocktail'))
      return Icons.local_bar;
    if (lower.contains('maggi') || lower.contains('pasta'))
      return Icons.ramen_dining;
    if (lower.contains('garlic')) return Icons.bakery_dining;
    if (lower.contains('dessert') || lower.contains('sweet')) return Icons.cake;
    return Icons.restaurant;
  }

  /// Smart Add Item Dialog - automatically uses selected category
  void _showSmartAddItemDialog(
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
                      final price =
                          double.tryParse(priceController.text) ?? 0.0;
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

  /// Fallback: Add item with category picker (when "All" is selected)
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
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
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

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final theme = Theme.of(context);
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
}

/// Categories Row (horizontal like billing screen)
class _CategoriesRow extends ConsumerStatefulWidget {
  final Function(Category) onEditCategory;

  const _CategoriesRow({required this.onEditCategory});

  @override
  ConsumerState<_CategoriesRow> createState() => _CategoriesRowState();
}

class _CategoriesRowState extends ConsumerState<_CategoriesRow> {
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
