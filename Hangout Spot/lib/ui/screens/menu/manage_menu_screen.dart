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
import 'package:hangout_spot/ui/screens/menu/menu_providers.dart';
import 'widgets/menu_categories_row.dart';
import 'dialogs/category_dialogs.dart';
import 'dialogs/item_dialogs.dart';
import 'package:hangout_spot/ui/widgets/trust_gate.dart';

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
                    TrustedDeviceGate(
                      child: TextButton.icon(
                        onPressed: () {
                          showEditCategorySelectDialog(context, ref);
                        },
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: coffee,
                        ),
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
                    ),
                    const SizedBox(width: 4),
                    TrustedDeviceGate(
                      child: TextButton.icon(
                        onPressed: () {
                          showAddCategoryDialog(context, ref);
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
                    ),
                  ],
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
      // Floating Action Button at bottom
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: TrustedDeviceGate(
          child: FloatingActionButton.extended(
            onPressed: () {
              showSmartAddItemDialog(context, ref, selectedCat);
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
}
