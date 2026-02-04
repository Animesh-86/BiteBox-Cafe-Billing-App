import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/ui/screens/billing/billing_providers.dart';

class BillingItemsGrid extends ConsumerWidget {
  const BillingItemsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItemsAsync = ref.watch(allItemsStreamProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final query = ref.watch(itemSearchQueryProvider).trim().toLowerCase();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return allItemsAsync.when(
      data: (items) {
        final availableItems = items.where((i) => i.isAvailable).toList();

        var filtered = (selectedCat == null || selectedCat == 'all')
            ? availableItems
            : availableItems.where((i) => i.categoryId == selectedCat).toList();

        if (query.isNotEmpty) {
          filtered = filtered
              .where((i) => i.name.toLowerCase().contains(query))
              .toList();
        }

        final crossAxisCount = isTablet
            ? ((screenWidth - 50) / 180).floor().clamp(2, 5)
            : 2;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                onChanged: (value) =>
                    ref.read(itemSearchQueryProvider.notifier).state = value,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              ref.read(itemSearchQueryProvider.notifier).state =
                                  '',
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).inputDecorationTheme.fillColor ??
                      Colors.white.withOpacity(0.04),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        query.isNotEmpty
                            ? "No items match your search"
                            : "No items",
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          BillingItemCard(item: filtered[index]),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
    );
  }
}

class BillingItemCard extends ConsumerWidget {
  final Item item;
  const BillingItemCard({super.key, required this.item});

  Widget _buildPricePill(BuildContext context, String text, bool inCart) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final caramel = isDark
        ? theme.colorScheme.secondary
        : const Color(0xFFEDAD4C);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: inCart
            ? theme.colorScheme.primary.withOpacity(0.18)
            : caramel.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: inCart ? theme.colorScheme.primary : coffeeDark,
        ),
      ),
    );
  }

  Widget _buildItemImage(BuildContext context) {
    final imagePath = item.imageUrl;
    if (imagePath == null || imagePath.isEmpty) {
      return BillingItemLetterBadge(item: item);
    }

    final isNetwork = imagePath.startsWith('http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: isNetwork
          ? Image.network(
              imagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return BillingItemLetterBadge(item: item);
              },
            )
          : Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return BillingItemLetterBadge(item: item);
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider).items;
    final notifier = ref.read(cartProvider.notifier);
    final inCart = cartItems.any((i) => i.item.id == item.id);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (inCart) {
          notifier.removeByItemId(item.id);
        } else {
          notifier.addItem(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: inCart
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.2),
                    colorScheme.primary.withOpacity(0.1),
                  ],
                )
              : null,
          color: inCart
              ? null
              : Theme.of(context).cardTheme.color ??
                    Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: inCart
                ? colorScheme.primary
                : Theme.of(context).dividerTheme.color ??
                      Colors.white.withOpacity(0.1),
            width: inCart ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: inCart
                      ? LinearGradient(
                          colors: [
                            colorScheme.primary.withOpacity(0.15),
                            colorScheme.primary.withOpacity(0.05),
                          ],
                        )
                      : null,
                  color: inCart
                      ? null
                      : Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: inCart
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 28,
                          color: colorScheme.primary,
                        )
                      : _buildItemImage(context),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: inCart
                              ? colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPricePill(
                          context,
                          "₹${item.price.toStringAsFixed(0)}",
                          inCart,
                        ),
                        if (item.discountPercent > 0)
                          Text(
                            "-${item.discountPercent.toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade300,
                              fontWeight: FontWeight.w600,
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

class BillingItemLetterBadge extends StatelessWidget {
  final Item item;

  const BillingItemLetterBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Text(
        item.name.isNotEmpty ? item.name[0].toUpperCase() : "?",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}
