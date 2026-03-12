import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/analytics_repository.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/realtime_services_provider.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:intl/intl.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/repositories/customer_repository.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/main.dart';
import 'package:hangout_spot/services/notification_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _selectedDate; // Null means 'current session date'
  ProviderSubscription<AsyncValue<List<InventoryItem>>>? _lowStockSubscription;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.requestPermissions();
    _lowStockSubscription = ref.listenManual(inventoryItemsStreamProvider, (
      previous,
      next,
    ) async {
      final items = next.valueOrNull ?? [];
      await _handleLowStockNotifications(items);
    });
  }

  @override
  void dispose() {
    _lowStockSubscription?.close();
    super.dispose();
  }

  /// Returns a compact label showing the session time window, e.g.
  /// "14:00 → Tue 14:00" for an overnight shift that spans two days.
  String _sessionRangeLabel(DateTime start, DateTime end) {
    final startStr = DateFormat('H:mm').format(start);
    if (end.day != start.day) {
      final endStr = DateFormat('EEE H:mm').format(end);
      return '$startStr → $endStr';
    }
    return '$startStr → ${DateFormat('H:mm').format(end)}';
  }

  Future<void> _pickDate(BuildContext context) async {
    final sessionManager = ref.read(sessionManagerProvider);
    final initialDate = _selectedDate ?? sessionManager.getCurrentSessionDate();

    // Limit lastDate to the current session date so the user cannot accidentally
    // navigate to a "future" session whose window hasn't started yet.
    // (e.g. if today is 10 Mar before 2 PM the current session is still 9 Mar;
    // picking 10 Mar would show an empty session that starts at 2 PM on 10 Mar.)
    final lastDate = sessionManager.getCurrentSessionDate();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
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

  Future<void> _handleLowStockNotifications(List<InventoryItem> items) async {
    if (items.isEmpty) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final todayKey = _dateKey(DateTime.now());

    for (final item in items) {
      final key = 'dash_low_${item.id}_$todayKey';

      if (item.currentQty > item.minQty) {
        // Stock is healthy; reset the notified flag so if it falls low again today, we alert again.
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
        }
        continue;
      }

      if (prefs.getBool(key) == true) continue;

      await NotificationService.instance.showNow(
        id: _hashId('dash_${item.id}'),
        title: 'Low stock: ${item.name}',
        body:
            'Only ${_formatQty(item.currentQty)} ${item.unit} left (min ${_formatQty(item.minQty)}).',
      );

      await prefs.setBool(key, true);
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _hashId(String value) {
    return value.hashCode & 0x7fffffff;
  }

  String _formatQty(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsRepositoryProvider);
    final sessionManager = ref.watch(sessionManagerProvider);

    // Rebuild dashboard when remote orders arrive from another device
    ref.watch(remoteSyncGenerationProvider);

    // Watch location
    final currentLocationAsync = ref.watch(currentLocationIdProvider);
    final currentLocationId = currentLocationAsync.value;

    final currentDate = _selectedDate ?? sessionManager.getCurrentSessionDate();

    // Compute session window using the canonical helper so any change to the
    // session-boundary logic in SessionManager is reflected here automatically.
    final sessionRange = sessionManager.getSessionRange(currentDate);
    final startOfDay = sessionRange['start']!;
    final endOfDay = sessionRange['end']!;

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

    final inventoryAsync = ref.watch(inventoryItemsStreamProvider);

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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: coffee,
                              ),
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
                          Text(
                            _sessionRangeLabel(startOfDay, endOfDay),
                            style: TextStyle(
                              fontSize: 10,
                              color: coffeeDark.withOpacity(0.55),
                            ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      caramel.withOpacity(0.18),
                      coffee.withOpacity(0.10),
                    ],
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
                    Builder(
                      builder: (context) {
                        final hour = DateTime.now().hour;
                        String greeting;
                        if (hour < 12) {
                          greeting = 'Good morning';
                        } else if (hour < 17) {
                          greeting = 'Good afternoon';
                        } else {
                          greeting = 'Good evening';
                        }
                        return Text(
                          greeting,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: coffeeDark.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 6),
                    inventoryAsync.when(
                      data: (items) {
                        final lowStock = items
                            .where((i) => i.currentQty <= i.minQty)
                            .toList();
                        if (lowStock.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final preview = lowStock
                            .take(3)
                            .map(
                              (i) =>
                                  '${i.name} (${_formatQty(i.currentQty)}/${_formatQty(i.minQty)} ${i.unit})',
                            )
                            .join(' • ');
                        final remaining = lowStock.length - 3;
                        final subtitle = remaining > 0
                            ? '$preview • +$remaining more'
                            : preview;

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: caramel.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: caramel.withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: caramel.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.warning_rounded,
                                  color: coffeeDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Low stock alert',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: coffeeDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${lowStock.length} item(s) below minimum',
                                      style: TextStyle(
                                        color: coffeeDark.withOpacity(0.85),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: coffeeDark.withOpacity(0.75),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    (_selectedDate == null)
                        ? Consumer(
                            builder: (context, ref, child) {
                              final splitAsync = ref.watch(
                                livePlatformSplitProvider,
                              );
                              return splitAsync.when(
                                data: (split) =>
                                    _buildPlatformSplit(split, theme),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          )
                        : FutureBuilder<PlatformSplit>(
                            future: analytics.getPlatformSplit(
                              startOfDay,
                              endOfDay,
                              locationId: currentLocationId,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData)
                                return const SizedBox.shrink();
                              return _buildPlatformSplit(snapshot.data!, theme);
                            },
                          ),
                  ],
                ),
              ),
              // Peak Hour Forecast Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Consumer(
                  builder: (context, ref, child) {
                    final analyticsData = ref.watch(
                      analyticsDataProvider((
                        startDate: startOfDay,
                        endDate: endOfDay,
                        filterName: 'Today',
                      )),
                    );

                    return analyticsData.when(
                      data: (data) {
                        if (data.todayPeakForecast != null) {
                          final forecast = data.todayPeakForecast!;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  caramel.withOpacity(0.25),
                                  coffee.withOpacity(0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: caramel.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: caramel.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.schedule_rounded,
                                    color: coffeeDark,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expected Peak Today',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: coffeeDark.withOpacity(0.7),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        forecast.formattedTime,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: coffeeDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: coffee.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    forecast.dayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: coffeeDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Stats Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = isWide
                            ? (constraints.maxWidth - 48) / 4
                            : (constraints.maxWidth - 16) / 2;

                        // Check if we're viewing current session (enables live mode)
                        final isCurrentSession = _selectedDate == null;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            // Total Sales Card (Live or Historical)
                            SizedBox(
                              width: cardWidth,
                              child: isCurrentSession
                                  ? Consumer(
                                      builder: (context, ref, child) {
                                        final revenueAsync = ref.watch(
                                          liveRevenueProvider,
                                        );
                                        return revenueAsync.when(
                                          data: (revenue) => _StatCard(
                                            title: "Total Sales",
                                            value: revenue.toStringAsFixed(0),
                                            icon: Icons.currency_rupee,
                                            prefix: "₹",
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.secondary
                                                : const Color(0xFFEDAD4C),
                                            isLive: true,
                                          ),
                                          loading: () => _StatCard(
                                            title: "Total Sales",
                                            value:
                                                revenueAsync.valueOrNull != null
                                                ? revenueAsync.valueOrNull!
                                                      .toStringAsFixed(0)
                                                : "0",
                                            icon: Icons.currency_rupee,
                                            prefix: "₹",
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.secondary
                                                : const Color(0xFFEDAD4C),
                                            isLive: true,
                                          ),
                                          error: (_, __) => _StatCard(
                                            title: "Total Sales",
                                            value: "0",
                                            icon: Icons.currency_rupee,
                                            prefix: "₹",
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.secondary
                                                : const Color(0xFFEDAD4C),
                                          ),
                                        );
                                      },
                                    )
                                  : FutureBuilder<double>(
                                      future: analytics.getSessionSales(
                                        startOfDay,
                                        endOfDay,
                                        locationId: currentLocationId,
                                      ),
                                      builder: (context, snapshot) => _StatCard(
                                        title: "Total Sales",
                                        value: snapshot.hasData
                                            ? snapshot.data!.toStringAsFixed(0)
                                            : "0",
                                        icon: Icons.currency_rupee,
                                        prefix: "₹",
                                        iconColor:
                                            theme.brightness == Brightness.dark
                                            ? theme.colorScheme.secondary
                                            : const Color(0xFFEDAD4C),
                                      ),
                                    ),
                            ),

                            // Orders Card (Live or Historical)
                            SizedBox(
                              width: cardWidth,
                              child: isCurrentSession
                                  ? Consumer(
                                      builder: (context, ref, child) {
                                        final orderCountAsync = ref.watch(
                                          liveOrderCountProvider,
                                        );
                                        return orderCountAsync.when(
                                          data: (count) => _StatCard(
                                            title: "Orders",
                                            value: "$count",
                                            icon: Icons.receipt_long,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.primary
                                                : const Color(0xFF95674D),
                                            isLive: true,
                                          ),
                                          loading: () => _StatCard(
                                            title: "Orders",
                                            value:
                                                orderCountAsync.valueOrNull !=
                                                    null
                                                ? "${orderCountAsync.valueOrNull}"
                                                : "0",
                                            icon: Icons.receipt_long,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.primary
                                                : const Color(0xFF95674D),
                                            isLive: true,
                                          ),
                                          error: (_, __) => _StatCard(
                                            title: "Orders",
                                            value: "0",
                                            icon: Icons.receipt_long,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.primary
                                                : const Color(0xFF95674D),
                                          ),
                                        );
                                      },
                                    )
                                  : FutureBuilder<int>(
                                      future: analytics.getSessionOrdersCount(
                                        startOfDay,
                                        endOfDay,
                                        locationId: currentLocationId,
                                      ),
                                      builder: (context, snapshot) => _StatCard(
                                        title: "Orders",
                                        value: snapshot.hasData
                                            ? "${snapshot.data}"
                                            : "0",
                                        icon: Icons.receipt_long,
                                        iconColor:
                                            theme.brightness == Brightness.dark
                                            ? theme.colorScheme.primary
                                            : const Color(0xFF95674D),
                                      ),
                                    ),
                            ),

                            // Items Sold Card (Live or Historical)
                            SizedBox(
                              width: cardWidth,
                              child: isCurrentSession
                                  ? Consumer(
                                      builder: (context, ref, child) {
                                        final itemCountAsync = ref.watch(
                                          liveItemCountProvider,
                                        );
                                        return itemCountAsync.when(
                                          data: (count) => _StatCard(
                                            title: "Items Sold",
                                            value: "$count",
                                            icon: Icons.inventory_2,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.onSurface
                                                : const Color(0xFF98664D),
                                            isLive: true,
                                          ),
                                          loading: () => _StatCard(
                                            title: "Items Sold",
                                            value:
                                                itemCountAsync.valueOrNull !=
                                                    null
                                                ? "${itemCountAsync.valueOrNull}"
                                                : "0",
                                            icon: Icons.inventory_2,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.onSurface
                                                : const Color(0xFF98664D),
                                            isLive: true,
                                          ),
                                          error: (_, __) => _StatCard(
                                            title: "Items Sold",
                                            value: "0",
                                            icon: Icons.inventory_2,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.onSurface
                                                : const Color(0xFF98664D),
                                          ),
                                        );
                                      },
                                    )
                                  : FutureBuilder<int>(
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
                                        iconColor:
                                            theme.brightness == Brightness.dark
                                            ? theme.colorScheme.onSurface
                                            : const Color(0xFF98664D),
                                      ),
                                    ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: isCurrentSession
                                  ? Consumer(
                                      builder: (context, ref, child) {
                                        final customerCountAsync = ref.watch(
                                          liveCustomerCountProvider,
                                        );
                                        return customerCountAsync.when(
                                          data: (count) => _StatCard(
                                            title: "Customers",
                                            value: "$count",
                                            icon: Icons.people,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.secondary
                                                : const Color(0xFFEDAD4C),
                                            isLive: true,
                                          ),
                                          loading: () => _StatCard(
                                            title: "Customers",
                                            value:
                                                customerCountAsync
                                                        .valueOrNull !=
                                                    null
                                                ? "${customerCountAsync.valueOrNull}"
                                                : "...",
                                            icon: Icons.people,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.secondary
                                                : const Color(0xFFEDAD4C),
                                            isLive: true,
                                          ),
                                          error: (_, __) => _StatCard(
                                            title: "Customers",
                                            value: "...",
                                            icon: Icons.people,
                                            iconColor:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.secondary
                                                : const Color(0xFFEDAD4C),
                                          ),
                                        );
                                      },
                                    )
                                  : FutureBuilder<int>(
                                      future: analytics
                                          .getSessionUniqueCustomersCount(
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
                                        iconColor:
                                            theme.brightness == Brightness.dark
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
                        stream: sessionManager.watchOrdersForSession(
                          currentDate,
                          locationId: currentLocationId,
                        ),
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

                          final orders = snapshot.data!.toList();
                          return Column(
                            children: orders.map((order) {
                              final timeAgo = _getTimeAgo(order.createdAt);
                              final isCancelled = order.status == 'cancelled';

                              return FutureBuilder<
                                (Customer?, List<OrderItem>)
                              >(
                                future:
                                    Future.wait([
                                      order.customerId != null
                                          ? ref
                                                .read(
                                                  customerRepositoryProvider,
                                                )
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
                                  final customerDisplay =
                                      order.customerId != null
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
                                      onTap: isCancelled
                                          ? null
                                          : () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: Text(
                                                    'Order ${order.invoiceNumber}',
                                                  ),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Time: $timeAgo\nCustomer: $customerDisplay',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Items: $itemsDisplay',
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                      const Text(
                                                        'Are you sure you want to cancel this order?',
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: const Text('Back'),
                                                    ),
                                                    FilledButton(
                                                      style:
                                                          FilledButton.styleFrom(
                                                            backgroundColor:
                                                                Colors.red,
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Cancel Order',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                final syncRepo = ref.read(
                                                  syncRepositoryProvider,
                                                );
                                                final custRepo = ref.read(
                                                  customerRepositoryProvider,
                                                );
                                                await ref
                                                    .read(
                                                      orderRepositoryProvider,
                                                    )
                                                    .cancelOrder(
                                                      order.id,
                                                      syncRepo: syncRepo,
                                                      customerRepo: custRepo,
                                                      onCancelled: () {
                                                        setState(() {});
                                                      },
                                                    );
                                                // Bump so live stats re-query
                                                ref
                                                    .read(
                                                      remoteSyncGenerationProvider
                                                          .notifier,
                                                    )
                                                    .state++;
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Order cancelled successfully.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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

  Widget _buildPlatformSplit(PlatformSplit split, ThemeData theme) {
    Widget badge(String label, int count, double total) {
      final isDark = theme.brightness == Brightness.dark;
      final cream = isDark ? const Color(0xFF2C2420) : const Color(0xFFFDFBF7);
      final coffee = isDark ? const Color(0xFFD3A889) : const Color(0xFF8B5E3C);
      final coffeeDark = isDark
          ? const Color(0xFFE5CCB9)
          : const Color(0xFF4A3424);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: coffee.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: coffeeDark),
            ),
            const SizedBox(height: 4),
            Text(
              '$count orders · ₹${total.toStringAsFixed(0)}',
              style: TextStyle(
                color: coffeeDark.withOpacity(0.75),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    final coffee = isDark ? const Color(0xFFD3A889) : const Color(0xFF8B5E3C);
    final coffeeDark = isDark
        ? const Color(0xFFE5CCB9)
        : const Color(0xFF4A3424);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: coffee.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orders by channel',
            style: TextStyle(fontWeight: FontWeight.w700, color: coffeeDark),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: badge(
                  'Zomato',
                  split.counts['Zomato'] ?? 0,
                  split.totals['Zomato'] ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: badge(
                  'Swiggy',
                  split.counts['Swiggy'] ?? 0,
                  split.totals['Swiggy'] ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: badge(
                  'Dine-in',
                  (split.counts['Dine-in'] ?? 0) +
                      (split.counts['Walk-in'] ?? 0),
                  (split.totals['Dine-in'] ?? 0) +
                      (split.totals['Walk-in'] ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor; // Single color, no gradient
  final String prefix;
  final bool isLive;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.prefix = "",
    this.isLive = false,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: coffeeDark.withOpacity(0.7),
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$prefix$value",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: coffeeDark,
            ),
          ),
        ],
      ),
    );
  }
}
