import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hangout_spot/data/repositories/analytics_repository.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final analyticsDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(analyticsRepositoryProvider);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final last7Start = startOfDay.subtract(const Duration(days: 6));
    final selectedRange = ref.watch(analyticsDateRangeProvider);
    final rangeStart = DateTime(
      (selectedRange?.start ?? last7Start).year,
      (selectedRange?.start ?? last7Start).month,
      (selectedRange?.start ?? last7Start).day,
    );
    final rangeEnd = DateTime(
      (selectedRange?.end ?? now).year,
      (selectedRange?.end ?? now).month,
      (selectedRange?.end ?? now).day,
    ).add(const Duration(days: 1));
    final rangeLabel = _formatRange(rangeStart, rangeEnd);
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: const Text('Analytics & Insights'),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                  initialDateRange:
                      selectedRange ??
                      DateTimeRange(start: last7Start, end: now),
                );
                if (picked != null) {
                  ref.read(analyticsDateRangeProvider.notifier).state = picked;
                }
              },
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(rangeLabel, style: const TextStyle(fontSize: 12)),
            ),
            IconButton(
              tooltip: 'Export Report',
              icon: const Icon(Icons.file_download_outlined, size: 18),
              onPressed: () =>
                  _showExportSheet(context, analytics, rangeStart, rangeEnd),
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
              Tab(icon: Icon(Icons.insights), text: 'Forecast'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Overview Tab
            _OverviewTab(
              analytics: analytics,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              rangeLabel: rangeLabel,
              isWide: isWide,
            ),

            // Trends Tab
            _TrendsTab(
              analytics: analytics,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              rangeLabel: rangeLabel,
            ),

            // Forecast Tab
            _ForecastTab(
              analytics: analytics,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              rangeLabel: rangeLabel,
            ),
          ],
        ),
      ),
    );
  }
}

// Overview Tab
class _OverviewTab extends StatelessWidget {
  final AnalyticsRepository analytics;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;
  final bool isWide;

  const _OverviewTab({
    required this.analytics,
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Performance Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Key metrics for $rangeLabel',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Key Metrics Grid
          FutureBuilder(
            future: Future.wait([
              analytics.getSessionSales(rangeStart, rangeEnd),
              analytics.getSessionOrdersCount(rangeStart, rangeEnd),
              analytics.getAverageOrderValue(rangeStart, rangeEnd),
              analytics.getRepeatCustomerRate(rangeStart, rangeEnd),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final data = snapshot.data as List<num>;
              return LayoutBuilder(
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
                        child: _MetricCard(
                          title: "Sales",
                          value: "₹${data[0].toStringAsFixed(0)}",
                          icon: Icons.currency_rupee,
                          iconColor: const Color(0xFFFFD54F),
                          subtitle: rangeLabel,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: "Orders",
                          value: "${data[1]}",
                          icon: Icons.receipt_long,
                          iconColor: const Color(0xFF64B5F6),
                          subtitle: rangeLabel,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: "Avg Order Value",
                          value: "₹${data[2].toStringAsFixed(0)}",
                          icon: Icons.shopping_cart,
                          iconColor: const Color(0xFFFFB74D),
                          subtitle: rangeLabel,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: "Repeat Rate",
                          value: "${(data[3] * 100).toStringAsFixed(0)}%",
                          icon: Icons.loyalty,
                          iconColor: const Color(0xFFBA68C8),
                          subtitle: rangeLabel,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // AI Insights Section
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'AI Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: Future.wait([
              analytics.getSalesAnomalyNote(rangeStart, rangeEnd),
              analytics.getTopBundles(rangeStart, rangeEnd),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final values = snapshot.data as List<dynamic>;
              final note = values[0] as String?;
              final bundles = values[1] as List<MapEntry<String, int>>;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.insights,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Smart Analysis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (note != null)
                        _InsightItem(
                          icon: Icons.trending_up,
                          text: note,
                          color: note.contains('below')
                              ? Colors.orange
                              : Colors.green,
                        ),
                      if (bundles.isNotEmpty) ...[
                        if (note != null) const SizedBox(height: 12),
                        _InsightItem(
                          icon: Icons.local_offer,
                          text:
                              "Top bundle: ${bundles.first.key} (${bundles.first.value}x orders)",
                          color: theme.colorScheme.primary,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Based on $rangeLabel',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Additional Metrics Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = isWide
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _CustomerSegmentsCard(
                      analytics: analytics,
                      last7Start: rangeStart,
                      now: rangeEnd,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _DiscountImpactCard(
                      analytics: analytics,
                      last7Start: rangeStart,
                      now: rangeEnd,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// Trends Tab
class _TrendsTab extends StatelessWidget {
  final AnalyticsRepository analytics;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;

  const _TrendsTab({
    required this.analytics,
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Trends',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing patterns for $rangeLabel',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          _ModernSectionCard(
            title: 'Daily Sales Trend',
            subtitle: 'Revenue by day',
            icon: Icons.show_chart,
            child: SizedBox(
              height: 220,
              child: FutureBuilder(
                future: analytics.getDailySales(rangeStart, rangeEnd),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rawPoints =
                      snapshot.data as List<MapEntry<DateTime, double>>;
                  if (rawPoints.isEmpty) {
                    return Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    );
                  }
                  final salesMap = {for (final e in rawPoints) e.key: e.value};
                  final totalDays = rangeEnd.difference(rangeStart).inDays;
                  final filled = List.generate(totalDays, (i) {
                    final day = rangeStart.add(Duration(days: i));
                    return MapEntry(day, salesMap[day] ?? 0.0);
                  });
                  return _buildLineChart(filled, theme.colorScheme.primary);
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          _ModernSectionCard(
            title: 'Item Share',
            subtitle: 'Top items contribution',
            icon: Icons.pie_chart,
            child: SizedBox(
              height: 220,
              child: FutureBuilder(
                future: analytics.getItemSalesShare(rangeStart, rangeEnd),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final shares =
                      snapshot.data as List<MapEntry<String, double>>;
                  if (shares.isEmpty) {
                    return Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    );
                  }
                  return _buildPieChart(shares, theme);
                },
              ),
            ),
          ),

          // Peak Hours Chart
          _ModernSectionCard(
            title: 'Peak Hours',
            subtitle: 'Order distribution by hour',
            icon: Icons.access_time,
            child: SizedBox(
              height: 250,
              child: FutureBuilder(
                future: analytics.getPeakHours(rangeStart, rangeEnd),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data as List<MapEntry<int, double>>;
                  if (data.isEmpty) {
                    return Center(
                      child: Text(
                        "No order data available",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    );
                  }
                  final byHour = {for (var e in data) e.key: e.value};
                  final hours = List.generate(
                    24,
                    (i) => MapEntry(i, byHour[i] ?? 0),
                  );
                  return _buildModernBarChart(
                    context,
                    hours.map((e) => e.value).toList(),
                    (index) => _formatHour(hours[index].key),
                    theme.colorScheme.primary,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          _ModernSectionCard(
            title: 'Hourly Heat Map',
            subtitle: 'Intensity by hour',
            icon: Icons.grid_on,
            child: FutureBuilder(
              future: analytics.getPeakHours(rangeStart, rangeEnd),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data as List<MapEntry<int, double>>;
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  );
                }
                return _buildHeatMap(data, theme.colorScheme.primary);
              },
            ),
          ),

          const SizedBox(height: 20),

          // Top Selling Items
          _ModernSectionCard(
            title: 'Top Selling Items',
            subtitle: 'Best performers',
            icon: Icons.star,
            child: SizedBox(
              height: 250,
              child: FutureBuilder(
                future: analytics.getTopSellingItemsSince(rangeStart, rangeEnd),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data as List<MapEntry<String, double>>;
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        "No items sold yet",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    );
                  }
                  return _buildModernBarChart(
                    context,
                    items.map((e) => e.value).toList(),
                    (index) => _truncate(items[index].key, 15),
                    const Color(0xFF64B5F6),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Low Performing Items
          _ModernSectionCard(
            title: 'Low Performing Items',
            subtitle: 'Items needing attention',
            icon: Icons.warning_amber_rounded,
            child: FutureBuilder(
              future: analytics.getLowSellingItemsSince(rangeStart, rangeEnd),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data as List<MapEntry<String, double>>;
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No low performers yet",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    color: theme.dividerColor.withOpacity(0.3),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        child: Icon(
                          Icons.inventory_2,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${item.value.toStringAsFixed(0)} units",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Forecast Tab
class _ForecastTab extends StatelessWidget {
  final AnalyticsRepository analytics;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;

  const _ForecastTab({
    required this.analytics,
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demand Forecast',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Predictions based on $rangeLabel',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Demand Forecast
          _ModernSectionCard(
            title: 'Expected Demand',
            subtitle: 'Next day average forecast',
            icon: Icons.trending_up,
            child: FutureBuilder(
              future: analytics.getDemandForecast(rangeStart, rangeEnd),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data as List<MapEntry<String, double>>;
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No forecast available",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    color: theme.dividerColor.withOpacity(0.3),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1,
                        ),
                        child: Icon(
                          Icons.inventory,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        "Expected quantity",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${item.value.toStringAsFixed(1)}",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Bundle Suggestions
          _ModernSectionCard(
            title: 'Bundle Suggestions',
            subtitle: 'Popular item combinations',
            icon: Icons.local_offer,
            child: FutureBuilder(
              future: analytics.getTopBundles(rangeStart, rangeEnd),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bundles = snapshot.data as List<MapEntry<String, int>>;
                if (bundles.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No bundle patterns yet",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bundles.length,
                  separatorBuilder: (_, __) => Divider(
                    color: theme.dividerColor.withOpacity(0.3),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final bundle = bundles[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(
                          0xFFBA68C8,
                        ).withOpacity(0.1),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Color(0xFFBA68C8),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        bundle.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        "Frequently ordered together",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA68C8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${bundle.value} orders",
                          style: const TextStyle(
                            color: Color(0xFFBA68C8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
        : theme.colorScheme.surface;
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Icon(
                  Icons.trending_up,
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onBackground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRange(DateTime start, DateTime endExclusive) {
  final end = endExclusive.subtract(const Duration(days: 1));
  final fmt = DateFormat('d MMM');
  if (start.year == end.year) {
    return '${fmt.format(start)} - ${fmt.format(end)}';
  }
  final fmtYear = DateFormat('d MMM yyyy');
  return '${fmtYear.format(start)} - ${fmtYear.format(end)}';
}

Future<void> _showExportSheet(
  BuildContext context,
  AnalyticsRepository analytics,
  DateTime start,
  DateTime end,
) async {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export CSV'),
            onTap: () async {
              Navigator.pop(ctx);
              await _exportAnalyticsCsv(context, analytics, start, end);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export PDF'),
            onTap: () async {
              Navigator.pop(ctx);
              await _exportAnalyticsPdf(context, analytics, start, end);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _exportAnalyticsCsv(
  BuildContext context,
  AnalyticsRepository analytics,
  DateTime start,
  DateTime end,
) async {
  final sales = await analytics.getSessionSales(start, end);
  final orders = await analytics.getSessionOrdersCount(start, end);
  final avgOrder = await analytics.getAverageOrderValue(start, end);
  final repeat = await analytics.getRepeatCustomerRate(start, end);
  final topItems = await analytics.getTopSellingItemsSince(start, end);
  final bundles = await analytics.getTopBundles(start, end);

  final buffer = StringBuffer();
  buffer.writeln('Metric,Value');
  buffer.writeln('Sales,${sales.toStringAsFixed(2)}');
  buffer.writeln('Orders,$orders');
  buffer.writeln('AvgOrderValue,${avgOrder.toStringAsFixed(2)}');
  buffer.writeln('RepeatRate,${(repeat * 100).toStringAsFixed(1)}%');
  buffer.writeln('');
  buffer.writeln('Top Items');
  buffer.writeln('Item,Units');
  for (final item in topItems) {
    buffer.writeln('${item.key},${item.value.toStringAsFixed(0)}');
  }
  buffer.writeln('');
  buffer.writeln('Top Bundles');
  buffer.writeln('Bundle,Orders');
  for (final bundle in bundles) {
    buffer.writeln('${bundle.key},${bundle.value}');
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/analytics_export.csv');
  await file.writeAsString(buffer.toString());
  await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
}

Future<void> _exportAnalyticsPdf(
  BuildContext context,
  AnalyticsRepository analytics,
  DateTime start,
  DateTime end,
) async {
  final sales = await analytics.getSessionSales(start, end);
  final orders = await analytics.getSessionOrdersCount(start, end);
  final avgOrder = await analytics.getAverageOrderValue(start, end);
  final repeat = await analytics.getRepeatCustomerRate(start, end);
  final topItems = await analytics.getTopSellingItemsSince(start, end);
  final bundles = await analytics.getTopBundles(start, end);

  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Analytics Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Range: ${_formatRange(start, end)}'),
            pw.SizedBox(height: 16),
            pw.Text(
              'Summary',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Sales: ₹${sales.toStringAsFixed(2)}'),
            pw.Text('Orders: $orders'),
            pw.Text('Avg Order: ₹${avgOrder.toStringAsFixed(2)}'),
            pw.Text('Repeat Rate: ${(repeat * 100).toStringAsFixed(1)}%'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Top Items',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Column(
              children: topItems
                  .map(
                    (e) => pw.Text('${e.key} • ${e.value.toStringAsFixed(0)}'),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Top Bundles',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Column(
              children: bundles
                  .map((e) => pw.Text('${e.key} • ${e.value} orders'))
                  .toList(),
            ),
          ],
        );
      },
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/analytics_report.pdf');
  await file.writeAsBytes(await pdf.save());
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
}

Widget _buildLineChart(List<MapEntry<DateTime, double>> points, Color color) {
  final spots = <FlSpot>[];
  for (int i = 0; i < points.length; i++) {
    spots.add(FlSpot(i.toDouble(), points[i].value));
  }
  final labelStep = points.length <= 5
      ? 1
      : points.length <= 10
      ? 2
      : points.length <= 16
      ? 3
      : 4;
  return LineChart(
    LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= points.length) return const Text('');
              if (index % labelStep != 0) return const SizedBox();
              final date = points[index].key;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Transform.rotate(
                  angle: -0.6,
                  child: SizedBox(
                    width: 44,
                    child: Text(
                      DateFormat('d MMM').format(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              );
            },
            reservedSize: 44,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withOpacity(0.15)),
        ),
      ],
    ),
  );
}

Widget _buildPieChart(List<MapEntry<String, double>> shares, ThemeData theme) {
  final colors = [
    theme.colorScheme.primary,
    const Color(0xFF64B5F6),
    const Color(0xFFFFB74D),
    const Color(0xFFBA68C8),
    const Color(0xFF81C784),
  ];
  return Row(
    children: [
      Expanded(
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            sections: shares.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              return PieChartSectionData(
                color: color,
                value: e.value.value * 100,
                title: '${(e.value.value * 100).toStringAsFixed(0)}%',
                radius: 60,
                titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: shares
              .asMap()
              .entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[e.key % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.value.key,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

Widget _buildHeatMap(List<MapEntry<int, double>> hours, Color baseColor) {
  final maxValue = hours.fold<double>(
    0,
    (max, e) => e.value > max ? e.value : max,
  );
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: List.generate(24, (index) {
      final value = hours.firstWhere(
        (e) => e.key == index,
        orElse: () => MapEntry(index, 0),
      );
      final intensity = maxValue == 0 ? 0 : (value.value / maxValue);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.15 + (0.75 * intensity)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 2),
          const SizedBox(height: 2),
          Text(_formatHour(index), style: const TextStyle(fontSize: 9)),
        ],
      );
    }),
  );
}

class _CustomerSegmentsCard extends StatelessWidget {
  final AnalyticsRepository analytics;
  final DateTime last7Start;
  final DateTime now;

  const _CustomerSegmentsCard({
    required this.analytics,
    required this.last7Start,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
        : theme.colorScheme.surface;
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.people,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Customer Segments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder(
              future: analytics.getCustomerSegments(last7Start, now),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final segments = snapshot.data as Map<String, int>;
                return Column(
                  children: [
                    _SegmentItem(
                      label: 'New Customers',
                      value: segments['new'] ?? 0,
                      color: const Color(0xFF64B5F6),
                    ),
                    const SizedBox(height: 12),
                    _SegmentItem(
                      label: 'Returning Customers',
                      value: segments['returning'] ?? 0,
                      color: const Color(0xFF81C784),
                    ),
                    const SizedBox(height: 12),
                    _SegmentItem(
                      label: 'Total Named Customers',
                      value: segments['total'] ?? 0,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SegmentItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "$value",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscountImpactCard extends StatelessWidget {
  final AnalyticsRepository analytics;
  final DateTime last7Start;
  final DateTime now;

  const _DiscountImpactCard({
    required this.analytics,
    required this.last7Start,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.discount,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Discount Impact',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder(
              future: analytics.getDiscountImpact(last7Start, now),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final impact = snapshot.data as Map<String, double>;
                return Column(
                  children: [
                    _ImpactItem(
                      label: 'With Discount',
                      value: impact['discountedAvg'] ?? 0,
                      color: const Color(0xFF81C784),
                    ),
                    const SizedBox(height: 16),
                    _ImpactItem(
                      label: 'Without Discount',
                      value: impact['nonDiscountedAvg'] ?? 0,
                      color: const Color(0xFF64B5F6),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ImpactItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.currency_rupee, color: color, size: 20),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InsightItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModernSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _ModernSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onBackground,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _buildModernBarChart(
  BuildContext context,
  List<double> values,
  String Function(int index) labelBuilder,
  Color color,
) {
  final maxValue = values.isEmpty
      ? 1.0
      : values.reduce((a, b) => a > b ? a : b);
  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxValue * 1.2,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
          tooltipRoundedRadius: 8,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, meta) {
              final index = val.toInt();
              if (index < 0 || index >= values.length) return const SizedBox();
              // Reduce clutter for dense data (e.g. 24 hours)
              if (values.length > 12 && index % 3 != 0) {
                return const SizedBox();
              }
              if (values.length > 6 && index % 2 != 0) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Transform.rotate(
                  angle: -0.6,
                  child: SizedBox(
                    width: 60,
                    child: Text(
                      labelBuilder(index),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                ),
              );
            },
            reservedSize: 60,
            interval: 1,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
              );
            },
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxValue > 0 ? maxValue / 5 : 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: const Color(0xFF333333),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      borderData: FlBorderData(show: false),
      barGroups: values.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value,
              color: color,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

String _truncate(String text, int len) {
  if (text.length <= len) return text;
  return "${text.substring(0, len)}...";
}

String _formatHour(int hour) {
  if (hour == 0) return '12 AM';
  if (hour == 12) return '12 PM';
  if (hour < 12) return '$hour AM';
  return '${hour - 12} PM';
}
