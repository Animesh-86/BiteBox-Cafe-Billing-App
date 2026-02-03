import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/analytics_repository.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsRepositoryProvider);
    final authFunc = ref.watch(authRepositoryProvider);
    final user = authFunc.currentUser;
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Admin';
    final sessionManager = ref.watch(sessionManagerProvider);
    final sessionInfo = sessionManager.getSessionInfo();
    final sessionStart = sessionInfo['opensAt'] as DateTime;
    final sessionEnd = sessionInfo['closesAt'] as DateTime;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEE, d MMM').format(DateTime.now()),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Hello, $userName! 👋",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: theme.colorScheme.primary, // Gold Title
              ),
            ),
            const SizedBox(height: 32),

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
                          sessionStart,
                          sessionEnd,
                        ),
                        builder: (context, snapshot) => _StatCard(
                          title: "Total Sales",
                          value: snapshot.hasData
                              ? snapshot.data!.toStringAsFixed(0)
                              : "...",
                          icon: Icons.currency_rupee,
                          prefix: "₹",
                          // Gold Palette
                          iconColor: const Color(0xFFFFD54F),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: FutureBuilder<int>(
                        future: analytics.getSessionOrdersCount(
                          sessionStart,
                          sessionEnd,
                        ),
                        builder: (context, snapshot) => _StatCard(
                          title: "Orders",
                          value: snapshot.hasData ? "${snapshot.data}" : "...",
                          icon: Icons.receipt_long,
                          // Blue/Grey Palette for contrast
                          iconColor: const Color(0xFF64B5F6),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: FutureBuilder<int>(
                        future: analytics.getSessionItemsSold(
                          sessionStart,
                          sessionEnd,
                        ),
                        builder: (context, snapshot) => _StatCard(
                          title: "Items Sold",
                          value: snapshot.hasData ? "${snapshot.data}" : "...",
                          icon: Icons.inventory_2,
                          // Orange Palette
                          iconColor: const Color(0xFFFFB74D),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: FutureBuilder<int>(
                        future: analytics.getSessionUniqueCustomersCount(
                          sessionStart,
                          sessionEnd,
                        ),
                        builder: (context, snapshot) => _StatCard(
                          title: "Customers",
                          value: snapshot.hasData ? "${snapshot.data}" : "...",
                          icon: Icons.people,
                          // Green Palette
                          iconColor: const Color(0xFF81C784),
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
                const Text(
                  "Live Activity",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
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
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                    );
                  }

                  final orders = snapshot.data!.take(5).toList();
                  return Column(
                    children: orders.map((order) {
                      final timeAgo = _getTimeAgo(order.createdAt);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.1),
                          child: Icon(
                            Icons.local_cafe,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          "Order ${order.invoiceNumber}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "$timeAgo • ${order.status}",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        trailing: Text(
                          "₹${order.totalAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
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

    return Card(
      // Use Theme Card
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                  Icons.show_chart,
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "$prefix$value",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
