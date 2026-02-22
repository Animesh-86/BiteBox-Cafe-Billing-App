import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/analytics_repository.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:intl/intl.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/repositories/customer_repository.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _selectedDate; // Null means 'current session date'
  late String _quote;

  final List<String> _quotes = [
    "Life happens, coffee helps.",
    "Espresso yourself.",
    "Better latte than never.",
    "Procaffeinating: The tendency to not start anything until you've had a cup of coffee.",
    "Coffee: A hug in a mug.",
    "Love is in the air, and it smells like coffee.",
    "Stressed, blessed, and coffee obsessed.",
    "First I drink the coffee, then I do the things.",
    "Coffee is always a good idea.",
    "Behind every successful person is a substantial amount of coffee.",
  ];

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
  }

  Future<void> _pickDate(BuildContext context) async {
    final sessionManager = ref.read(sessionManagerProvider);
    final initialDate = _selectedDate ?? sessionManager.getCurrentSessionDate();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? theme.colorScheme.copyWith(
                    primary: const Color(0xFFEDAD4C), // Caramel for primary
                    onPrimary: const Color(0xFF2C1A1D), // Dark coffee for text
                    surface: const Color(0xFF2C1A1D), // Dark background
                    onSurface: const Color(0xFFEDAD4C), // Caramel text
                  )
                : theme.colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null &&
        picked != (_selectedDate ?? sessionManager.getCurrentSessionDate())) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsRepositoryProvider);
    final authFunc = ref.watch(authRepositoryProvider);
    final user = authFunc.currentUser;
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Admin';
    final sessionManager = ref.watch(sessionManagerProvider);

    // Watch location
    final currentLocationAsync = ref.watch(currentLocationIdProvider);
    final currentLocationId = currentLocationAsync.value;

    final currentDate = _selectedDate ?? sessionManager.getCurrentSessionDate();

    // Calculate start and end based on SESSION WINDOW
    final startOfDay = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
      sessionManager.openingHour,
      0,
      0,
    );

    DateTime endOfDay;
    if (sessionManager.closingHour <= sessionManager.openingHour) {
      endOfDay = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        sessionManager.closingHour,
        0,
        0,
      ).add(const Duration(days: 1));
    } else {
      endOfDay = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        sessionManager.closingHour,
        0,
        0,
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: cream,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: cream.withOpacity(0.8),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(color: coffeeDark),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: coffee.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.store_mall_directory_rounded,
                      color: coffee,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Hangout Spot",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: coffeeDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            final locationsAsync = ref.watch(
                              locationsStreamProvider,
                            );
                            final currentIdAsync = ref.watch(
                              currentLocationIdProvider,
                            );

                            return locationsAsync.when(
                              data: (locations) {
                                final currentId = currentIdAsync.valueOrNull;
                                final location = locations.firstWhere(
                                  (l) => l.id == currentId,
                                  orElse: () => locations.isNotEmpty
                                      ? locations.first
                                      : Location(
                                          id: '',
                                          name: '',
                                          address: '',
                                          phoneNumber: '',
                                          isActive: true,
                                          createdAt: DateTime.now(),
                                        ),
                                );

                                // Use address if available, falling back to name
                                String subtitle =
                                    (location.address ?? '').isNotEmpty
                                    ? location.address!
                                    : location.name;
                                if (subtitle.isEmpty) subtitle = location.name;

                                return Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: coffeeDark.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                              loading: () => const SizedBox(
                                height: 10,
                                width: 50,
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _pickDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: coffee.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: coffee),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, d MMM').format(currentDate),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: coffeeDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: coffeeDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                24,
                20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [caramel.withOpacity(0.18), coffee.withOpacity(0.10)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello, $userName",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: coffeeDark.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "\"$_quote\"",
                    style: TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      color: coffeeDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = isWide
                          ? (constraints.maxWidth - 48) / 4
                          : (constraints.maxWidth - 16) / 2;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: FutureBuilder<double>(
                              future: analytics.getSessionSales(
                                startOfDay,
                                endOfDay,
                                locationId: currentLocationId,
                              ),
                              builder: (context, snapshot) => _StatCard(
                                title: "Total Sales",
                                value: snapshot.hasData
                                    ? snapshot.data!.toStringAsFixed(0)
                                    : "...",
                                icon: Icons.currency_rupee,
                                prefix: "₹",
                                iconColor: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.secondary
                                    : const Color(0xFFEDAD4C),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: FutureBuilder<int>(
                              future: analytics.getSessionOrdersCount(
                                startOfDay,
                                endOfDay,
                                locationId: currentLocationId,
                              ),
                              builder: (context, snapshot) => _StatCard(
                                title: "Orders",
                                value: snapshot.hasData
                                    ? "${snapshot.data}"
                                    : "...",
                                icon: Icons.receipt_long,
                                iconColor: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.primary
                                    : const Color(0xFF95674D),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: FutureBuilder<int>(
                              future: analytics.getSessionItemsSold(
                                startOfDay,
                                endOfDay,
                                locationId: currentLocationId,
                              ),
                              builder: (context, snapshot) => _StatCard(
                                title: "Items Sold",
                                value: snapshot.hasData
                                    ? "${snapshot.data}"
                                    : "...",
                                icon: Icons.inventory_2,
                                iconColor: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.onSurface
                                    : const Color(0xFF98664D),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: FutureBuilder<int>(
                              future: analytics.getSessionUniqueCustomersCount(
                                startOfDay,
                                endOfDay,
                                locationId: currentLocationId,
                              ),
                              builder: (context, snapshot) => _StatCard(
                                title: "Customers",
                                value: snapshot.hasData
                                    ? "${snapshot.data}"
                                    : "...",
                                icon: Icons.people,
                                iconColor: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.secondary
                                    : const Color(0xFFEDAD4C),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  // Recent Activity Section
                  Row(
                    children: [
                      Icon(Icons.history, color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        "Recent Activity",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: coffeeDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: StreamBuilder<List<Order>>(
                      stream: sessionManager.watchSessionOrders(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                "No recent orders",
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ),
                          );
                        }

                        // Filter orders if needed or just show latest 5
                        // Note: watchSessionOrders might just show current session orders
                        // If user wants historical, meaningful 'watch' might need refactor in future.
                        // For now, let's keep showing session orders but filtered by _selectedDate if possible?
                        // `watchSessionOrders` likely watches the *current* session ID in pure Drift.
                        // If we want to support date filtering on the stream, we'd need a different query.
                        // Use `analytics` or verify if session filtering matches date.
                        // Assuming current request just wants top stats date-filtered.
                        // Keeping stream as-is for "Live/Recent Activity" context.

                        final orders = snapshot.data!.take(5).toList();
                        return Column(
                          children: orders.map((order) {
                            final timeAgo = _getTimeAgo(order.createdAt);
                            final isCancelled = order.status == 'cancelled';

                            return FutureBuilder<(Customer?, List<OrderItem>)>(
                              future:
                                  Future.wait([
                                    order.customerId != null
                                        ? ref
                                              .read(customerRepositoryProvider)
                                              .getCustomerById(
                                                order.customerId!,
                                              )
                                        : Future.value(null)
                                              as Future<Customer?>,
                                    ref
                                        .read(orderRepositoryProvider)
                                        .getOrderItems(order.id),
                                  ]).then(
                                    (results) => (
                                      results[0] as Customer?,
                                      results[1] as List<OrderItem>,
                                    ),
                                  ),
                              builder: (context, snapshot) {
                                final customer = snapshot.data?.$1;
                                final items = snapshot.data?.$2 ?? [];

                                // Consistent customer display
                                final customerDisplay = order.customerId != null
                                    ? (customer?.name ?? 'Customer')
                                    : 'Walk-In';

                                // Get item names
                                final itemNames = items
                                    .map((item) => item.itemName)
                                    .toList();
                                final itemsDisplay = itemNames.isNotEmpty
                                    ? itemNames.join(', ')
                                    : 'No items';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 1),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: isCancelled
                                          ? Colors.red.withOpacity(0.1)
                                          : theme.colorScheme.primary
                                                .withOpacity(0.1),
                                      child: Icon(
                                        isCancelled
                                            ? Icons.cancel
                                            : Icons.local_cafe,
                                        size: 20,
                                        color: isCancelled
                                            ? Colors.red
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${order.invoiceNumber} • $customerDisplay",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            decoration: isCancelled
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: isCancelled
                                                ? Colors.red.withOpacity(0.8)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          itemsDisplay,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      "$timeAgo • ${order.status.toUpperCase()}",
                                      style: TextStyle(
                                        color: isCancelled
                                            ? Colors.red.withOpacity(0.7)
                                            : theme.colorScheme.onSurface
                                                  .withOpacity(0.5),
                                        fontWeight: isCancelled
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    trailing: Text(
                                      "₹${order.totalAmount.toStringAsFixed(0)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isCancelled
                                            ? Colors.red
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor; // Single color, no gradient
  final String prefix;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.prefix = "",
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark ? theme.colorScheme.surface : const Color(0xFFFEF9F5);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: coffeeDark.withOpacity(0.7),
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$prefix$value",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: coffeeDark,
            ),
          ),
        ],
      ),
    );
  }
}
