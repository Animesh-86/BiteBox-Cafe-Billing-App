import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/ui/widgets/glass_container.dart';
import 'package:file_picker/file_picker.dart';

// Local state for Admin Menu Selection
final adminSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final menuItemSearchProvider = StateProvider<String>((ref) => '');

class ItemListTab extends ConsumerWidget {
  const ItemListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItemsAsync = ref.watch(allItemsStreamProvider);
    final selectedCat = ref.watch(adminSelectedCategoryProvider);
    final query = ref.watch(menuItemSearchProvider).trim().toLowerCase();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark ? theme.colorScheme.surface : const Color(0xFFFEF9F5);
    final surface = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.35)
        : const Color(0xFFFFF6ED);
    final coffee = isDark ? theme.colorScheme.primary : const Color(0xFF95674D);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);
    final caramel = isDark
        ? theme.colorScheme.secondary
        : const Color(0xFFEDAD4C);
    final cardLift = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.45)
        : const Color(0xFFF8EBDD);

    return allItemsAsync.when(
      data: (items) {
        var filtered = (selectedCat == null || selectedCat == 'all')
            ? items
            : items.where((i) => i.categoryId == selectedCat).toList();

        if (query.isNotEmpty) {
          filtered = filtered
              .where((i) => i.name.toLowerCase().contains(query))
              .toList();
        }

        return Column(
          children: [
            TextField(
              onChanged: (value) =>
                  ref.read(menuItemSearchProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            ref.read(menuItemSearchProvider.notifier).state =
                                '',
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: coffee.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: coffee.withOpacity(0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: coffee.withOpacity(0.45)),
                ),
                filled: true,
                fillColor: cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              size: 40,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isNotEmpty
                                ? "No items match your search"
                                : "No items in this category",
                            style: TextStyle(
                              color: coffeeDark.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            query.isNotEmpty
                                ? "Try clearing your search"
                                : "Tap the + button to add items",
                            style: TextStyle(
                              color: coffeeDark.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onHorizontalDragEnd: (details) {
                        final categoriesAsync = ref.read(
                          categoriesStreamProvider,
                        );
                        categoriesAsync.whenData((categories) {
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

                          final currentIndex = allCats.indexWhere(
                            (c) =>
                                c.id ==
                                (selectedCat == null || selectedCat == 'all'
                                    ? 'all'
                                    : selectedCat),
                          );

                          if (currentIndex == -1) return;

                          // Swipe Left -> Next Category
                          if (details.primaryVelocity! < 0) {
                            if (currentIndex < allCats.length - 1) {
                              ref
                                  .read(adminSelectedCategoryProvider.notifier)
                                  .state = allCats[currentIndex + 1]
                                  .id;
                            }
                          }
                          // Swipe Right -> Previous Category
                          else if (details.primaryVelocity! > 0) {
                            if (currentIndex > 0) {
                              ref
                                  .read(adminSelectedCategoryProvider.notifier)
                                  .state = allCats[currentIndex - 1]
                                  .id;
                            }
                          }
                        });
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = (constraints.maxWidth / 140)
                              .floor()
                              .clamp(2, 6);
                          return GridView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 0.7,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _AdminItemCard(
                              item: filtered[index],
                              onEdit: () => _showAddEditDialog(
                                context,
                                ref,
                                item: filtered[index],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Error: $e")),
    );
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, {Item? item}) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final categories =
              ref.watch(categoriesStreamProvider).asData?.value ?? [];
          return _ItemDialog(item: item, categories: categories);
        },
      ),
    );
  }
}

class _AdminItemCard extends ConsumerWidget {
  final Item item;
  final VoidCallback onEdit;
  const _AdminItemCard({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark ? theme.colorScheme.surface : const Color(0xFFFEF9F5);
    final surface = isDark
        ? theme.colorScheme.surface
        : const Color(0xFFFFF3E8);
    final cardLift = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.45)
        : const Color(0xFFF8EBDD);
    final coffee = isDark ? theme.colorScheme.primary : const Color(0xFF95674D);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);
    final caramel = isDark
        ? theme.colorScheme.secondary
        : const Color(0xFFEDAD4C);
    return GestureDetector(
      onTap: onEdit,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(14),
        color: item.isAvailable ? cardLift : surface,
        opacity: 1,
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withOpacity(0.15)
              : Colors.transparent,
          width: 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: item.isAvailable
                        ? [caramel.withOpacity(0.18), coffee.withOpacity(0.08)]
                        : [coffee.withOpacity(0.08), coffee.withOpacity(0.04)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildItemImage(item.imageUrl!, item),
                        )
                      : _FallbackItemBadge(item: item),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: item.isAvailable
                              ? coffeeDark
                              : coffeeDark.withOpacity(0.5),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.isAvailable
                                ? caramel.withOpacity(0.25)
                                : coffee.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "₹${item.price.toStringAsFixed(0)}",
                            style: TextStyle(
                              color: item.isAvailable
                                  ? coffeeDark
                                  : coffeeDark.withOpacity(0.6),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: item.isAvailable,
                            activeColor: coffee,
                            onChanged: (val) {
                              ref
                                  .read(menuRepositoryProvider)
                                  .updateItem(item.copyWith(isAvailable: val));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackItemBadge extends StatelessWidget {
  final Item item;

  const _FallbackItemBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: item.isAvailable
            ? const Color(0xFFEDAD4C).withOpacity(0.25)
            : const Color(0xFF95674D).withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        item.name.isNotEmpty ? item.name[0].toUpperCase() : "?",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: item.isAvailable ? coffeeDark : coffeeDark.withOpacity(0.6),
        ),
      ),
    );
  }
}

Widget _buildItemImage(String path, Item item) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return _FallbackItemBadge(item: item);
      },
    );
  }

  final file = File(path);
  if (file.existsSync()) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return _FallbackItemBadge(item: item);
      },
    );
  }

  return _FallbackItemBadge(item: item);
}

class _ItemDialog extends ConsumerStatefulWidget {
  final Item? item;
  final List<Category> categories;
  const _ItemDialog({this.item, required this.categories});

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _imageUrlController;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(
      text: widget.item?.price.toString() ?? '',
    );
    _discountController = TextEditingController(
      text: widget.item?.discountPercent.toString() ?? '0.0',
    );
    _imageUrlController = TextEditingController(
      text: widget.item?.imageUrl ?? '',
    );
    final openCategory = ref.read(adminSelectedCategoryProvider);
    _selectedCategoryId =
        widget.item?.categoryId ??
        openCategory ??
        (widget.categories.isNotEmpty ? widget.categories[0].id : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark ? theme.colorScheme.surface : const Color(0xFFFEF9F5);
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
    return AlertDialog(
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
            child: Icon(
              widget.item == null
                  ? Icons.add_circle_rounded
                  : Icons.edit_rounded,
              color: coffeeDark,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.item == null ? 'Add Item' : 'Edit Item',
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
              value: _selectedCategoryId,
              items: widget.categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
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
              dropdownColor: cream,
              style: const TextStyle(color: Color(0xFF98664D), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(color: Color(0xFF98664D), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                prefixText: '₹ ',
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF98664D), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discountController,
              decoration: InputDecoration(
                labelText: 'Discount Percentage',
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
              style: const TextStyle(color: Color(0xFF98664D), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageUrlController,
              decoration: InputDecoration(
                labelText: 'Item Image',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.image_outlined, size: 20),
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              readOnly: true,
              style: const TextStyle(color: Color(0xFF98664D), fontSize: 14),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                );
                if (result != null && result.files.single.path != null) {
                  _imageUrlController.text = result.files.single.path!;
                  if (mounted) setState(() {});
                }
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );
                  if (result != null && result.files.single.path != null) {
                    _imageUrlController.text = result.files.single.path!;
                    if (mounted) setState(() {});
                  }
                },
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Upload Image'),
                style: FilledButton.styleFrom(
                  backgroundColor: coffee,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.item != null)
          TextButton.icon(
            onPressed: () {
              ref.read(menuRepositoryProvider).deleteItem(widget.item!.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.item!.name} deleted'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text("Delete"),
            style: TextButton.styleFrom(foregroundColor: Colors.red[300]),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: TextStyle(color: coffeeDark.withOpacity(0.8)),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _selectedCategoryId != null) {
              final price = double.tryParse(_priceController.text) ?? 0.0;
              final discount = double.tryParse(_discountController.text) ?? 0.0;
              final repo = ref.read(menuRepositoryProvider);

              if (widget.item == null) {
                repo.addItem(
                  ItemsCompanion(
                    id: drift.Value(const Uuid().v4()),
                    categoryId: drift.Value(_selectedCategoryId!),
                    name: drift.Value(_nameController.text),
                    price: drift.Value(price),
                    discountPercent: drift.Value(discount),
                    imageUrl: drift.Value<String?>(
                      _imageUrlController.text.trim().isEmpty
                          ? null
                          : _imageUrlController.text.trim(),
                    ),
                  ),
                );
              } else {
                repo.updateItem(
                  widget.item!.copyWith(
                    categoryId: _selectedCategoryId!,
                    name: _nameController.text,
                    price: price,
                    discountPercent: discount,
                    description: drift.Value(widget.item?.description),
                    imageUrl: drift.Value<String?>(
                      _imageUrlController.text.trim().isEmpty
                          ? null
                          : _imageUrlController.text.trim(),
                    ),
                  ),
                );
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.item == null
                        ? '${_nameController.text} added'
                        : 'Item updated',
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            "Save",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
