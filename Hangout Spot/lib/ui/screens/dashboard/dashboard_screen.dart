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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: coffeeDark),
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: coffeeDark,
        ),
        title: const Text("Dashboard"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: coffee.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: coffee),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEE, d MMM').format(DateTime.now()),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: coffeeDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                border: Border.all(color: coffee.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back,",
                    style: TextStyle(
                      fontSize: 14,
                      color: coffeeDark.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Hello, $userName",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: coffeeDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: caramel.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Session: ${DateFormat('hh:mm a').format(sessionStart)} - ${DateFormat('hh:mm a').format(sessionEnd)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: coffeeDark,
                          ),
                        ),
                      ),
                    ],
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
                                sessionStart,
                                sessionEnd,
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
                                sessionStart,
                                sessionEnd,
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
                                sessionStart,
                                sessionEnd,
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
                        "Live Activity",
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
                      border: Border.all(color: coffee.withOpacity(0.2)),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "$timeAgo • ${order.status}",
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
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
    final coffee = isDark ? theme.colorScheme.primary : const Color(0xFF95674D);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: coffee.withOpacity(0.18)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: coffee.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Today",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: coffeeDark,
                  ),
                ),
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
