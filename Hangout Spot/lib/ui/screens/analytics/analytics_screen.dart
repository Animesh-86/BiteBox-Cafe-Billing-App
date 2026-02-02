import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hangout_spot/data/repositories/analytics_repository.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(analyticsRepositoryProvider);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final last7Start = startOfDay.subtract(const Duration(days: 6));
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Analytics & Insights'),
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
              last7Start: last7Start,
              now: now,
              isWide: isWide,
            ),

            // Trends Tab
            _TrendsTab(
              analytics: analytics,
              last7Start: last7Start,
              now: now,
            ),

            // Forecast Tab
            _ForecastTab(
              analytics: analytics,
              last7Start: last7Start,
              now: now,
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
  final DateTime last7Start;
  final DateTime now;
  final bool isWide;

  const _OverviewTab({
    required this.analytics,
    required this.last7Start,
    required this.now,
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
            'Key metrics for today and last 7 days',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Key Metrics Grid
          FutureBuilder(
            future: Future.wait([
              analytics.getTodaySales(),
              analytics.getTodayOrdersCount(),
              analytics.getAverageOrderValue(last7Start, now),
              analytics.getRepeatCustomerRate(last7Start, now),
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
                          title: "Today's Sales",
                          value: "₹${data[0].toStringAsFixed(0)}",
                          icon: Icons.currency_rupee,
                          iconColor: const Color(0xFFFFD54F),
                          subtitle: "Revenue today",
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: "Orders",
                          value: "${data[1]}",
                          icon: Icons.receipt_long,
                          iconColor: const Color(0xFF64B5F6),
                          subtitle: "Completed today",
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: "Avg Order Value",
                          value: "₹${data[2].toStringAsFixed(0)}",
                          icon: Icons.shopping_cart,
                          iconColor: const Color(0xFFFFB74D),
                          subtitle: "Last 7 days",
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: "Repeat Rate",
                          value: "${(data[3] * 100).toStringAsFixed(0)}%",
                          icon: Icons.loyalty,
                          iconColor: const Color(0xFFBA68C8),
                          subtitle: "Returning customers",
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
              analytics.getSalesAnomalyNote(last7Start, now),
              analytics.getTopBundles(last7Start, now),
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
                        'Based on the last 7 days of order data',
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
                      last7Start: last7Start,
                      now: now,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _DiscountImpactCard(
                      analytics: analytics,
                      last7Start: last7Start,
                      now: now,
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
  final DateTime last7Start;
  final DateTime now;

  const _TrendsTab({
    required this.analytics,
    required this.last7Start,
    required this.now,
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
            'Analyzing patterns from the last 7 days',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Peak Hours Chart
          _ModernSectionCard(
            title: 'Peak Hours',
            subtitle: 'Order distribution by hour (last 7 days)',
            icon: Icons.access_time,
            child: SizedBox(
              height: 250,
              child: FutureBuilder(
                future: analytics.getPeakHours(last7Start, now),
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
                    hours.map((e) => e.value).toList(),
                    (index) => "${hours[index].key}:00",
                    theme.colorScheme.primary,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Top Selling Items
          _ModernSectionCard(
            title: 'Top Selling Items',
            subtitle: 'Best performers (last 7 days)',
            icon: Icons.star,
            child: SizedBox(
              height: 250,
              child: FutureBuilder(
                future: analytics.getTopSellingItemsSince(last7Start, now),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items =
                      snapshot.data as List<MapEntry<String, double>>;
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
              future: analytics.getLowSellingItemsSince(last7Start, now),
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
  final DateTime last7Start;
  final DateTime now;

  const _ForecastTab({
    required this.analytics,
    required this.last7Start,
    required this.now,
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
            'Predictions based on historical data',
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
              future: analytics.getDemandForecast(last7Start, now),
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
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
              future: analytics.getTopBundles(last7Start, now),
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
                        backgroundColor: const Color(0xFFBA68C8).withOpacity(0.1),
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
    return Card(
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
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
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
  List<double> values,
  String Function(int index) labelBuilder,
  Color color,
) {
  final maxValue = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxValue * 1.2,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.black87,
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
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  labelBuilder(index),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              );
            },
            reservedSize: 40,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9E9E9E),
                ),
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
