import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hangout_spot/data/repositories/analytics_repository.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Insights')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder(
              future: Future.wait([
                ref.read(analyticsRepositoryProvider).getTodaySales(),
                ref.read(analyticsRepositoryProvider).getTodayOrdersCount(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final data = snapshot.data as List<num>;
                return Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        "Today's Sales",
                        "₹${data[0].toStringAsFixed(2)}",
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard("Orders", "${data[1]}", Colors.blue),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Top Selling Items",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder(
                future: ref
                    .read(analyticsRepositoryProvider)
                    .getTopSellingItems(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final items = snapshot.data as List<MapEntry<String, double>>;
                  if (items.isEmpty)
                    return const Center(child: Text("No items sold yet."));

                  // Simple Bar Chart
                  return BarChart(
                    BarChartData(
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              if (val.toInt() >= 0 &&
                                  val.toInt() < items.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    items[val.toInt()].key.substring(0, 3),
                                  ),
                                ); // Truncate
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      barGroups: items.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.value,
                              color: Colors.purple,
                              width: 20,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _InfoCard(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
