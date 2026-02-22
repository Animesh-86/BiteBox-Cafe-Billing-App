import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/providers/theme_provider.dart';

import 'sections/backup_settings.dart';
import 'sections/locations_settings.dart';
import 'sections/loyalty_settings.dart';
import 'sections/promo_settings.dart';
import 'sections/receipt_settings.dart';
import 'sections/operating_hours_settings.dart';
import 'active_sessions_screen.dart';
import 'widgets/settings_shared.dart';
import 'sections/printer_settings_screen.dart';

// The manager password — same as the one used in locations_settings.dart
const String _kManagerPassword = 'admin123';

/// A self-contained password dialog widget — avoids stale context crashes.
class _PasswordDialog extends StatefulWidget {
  final String action;
  const _PasswordDialog({required this.action});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            Icons.lock_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Text('Manager Access'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter password to open ${widget.action}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            onSubmitted: (_) =>
                Navigator.pop(context, _controller.text == _kManagerPassword),
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // null = cancelled
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _controller.text == _kManagerPassword),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

/// Returns true if granted, false if wrong password, null if cancelled.
Future<bool?> _verifyPassword(BuildContext context, String action) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(action: action),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final activeOutletAsync = ref.watch(activeOutletProvider);

    final navigationItems = [
      {
        "title": "Outlets",
        "icon": Icons.place_rounded,
        "subtitle": "Manage store outlets",
        "screen": const LocationsSettingsScreen(),
      },
      {
        "title": "Loyalty Program",
        "icon": Icons.stars_rounded,
        "subtitle": "Configure rewards and points",
        "screen": const LoyaltySettingsScreen(),
      },
      {
        "title": "Operating Hours",
        "icon": Icons.access_time_rounded,
        "subtitle": "Configure shift cutoffs",
        "screen": const OperatingHoursSettingsScreen(),
      },
      {
        "title": "Active Promotion",
        "icon": Icons.local_offer_rounded,
        "subtitle": "Set up campaigns and discounts",
        "screen": const PromoSettingsScreen(),
      },
      {
        "title": "Receipt Config",
        "icon": Icons.receipt_long_rounded,
        "subtitle": "Customize printed receipts",
        "screen": const ReceiptSettingsScreen(),
      },
      {
        "title": "Cloud Backup",
        "icon": Icons.cloud_sync_rounded,
        "subtitle": "Sync data and restore",
        "screen": const BackupSettingsScreen(),
      },
      {
        "title": "Active Devices",
        "icon": Icons.devices,
        "subtitle": "Manage logged-in devices",
        "screen": const ActiveSessionsScreen(),
      },
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Custom Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Settings",
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        // Quick Actions
                        Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.print_rounded),
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) =>
                                        const PrinterSettingsScreen(),
                                  );
                                },
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Builder(
                                builder: (context) {
                                  final themeMode = ref.watch(themeProvider);
                                  IconData themeIcon = Icons.smartphone_rounded;
                                  if (themeMode == ThemeMode.dark) {
                                    themeIcon = Icons.dark_mode_rounded;
                                  } else if (themeMode == ThemeMode.light) {
                                    themeIcon = Icons.light_mode_rounded;
                                  }

                                  return IconButton(
                                    icon: Icon(
                                      themeIcon,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      final modes = [
                                        ThemeMode.light,
                                        ThemeMode.dark,
                                        ThemeMode.system,
                                      ];
                                      final currentIndex = modes.indexOf(
                                        themeMode,
                                      );
                                      final nextMode =
                                          modes[(currentIndex + 1) %
                                              modes.length];
                                      ref
                                          .read(themeProvider.notifier)
                                          .setTheme(nextMode);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Read-only Store Profile (auto-fetched from outlet)
                      SettingsSection(
                        title: "Store Profile",
                        icon: Icons.store_rounded,
                        children: [
                          activeOutletAsync.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (_, __) =>
                                const Text("Unable to load outlet data"),
                            data: (outlet) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                    context,
                                    Icons.store_rounded,
                                    "Store Name",
                                    outlet?.name ?? '—',
                                  ),
                                  _buildInfoRow(
                                    context,
                                    Icons.location_on_rounded,
                                    "Address",
                                    outlet?.address ?? '—',
                                  ),
                                  _buildInfoRow(
                                    context,
                                    Icons.phone_rounded,
                                    "Phone Number",
                                    outlet?.phoneNumber ?? '—',
                                  ),
                                  _buildInfoRow(
                                    context,
                                    Icons.email_rounded,
                                    "Email",
                                    user?.email ?? '—',
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "Profile is managed through Outlets settings.",
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.4),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Navigation Items Grid — each protected by password
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.25,
                            ),
                        itemCount: navigationItems.length,
                        itemBuilder: (context, index) {
                          final item = navigationItems[index];
                          return _buildNavGridItem(
                            context,
                            item['title'] as String,
                            item['icon'] as IconData,
                            item['subtitle'] as String,
                            item['screen'] as Widget,
                          );
                        },
                      ),

                      const SizedBox(height: 48),

                      Center(
                        child: Column(
                          children: [
                            Text(
                              "Hangout Spot v1.0.0",
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Developed by Animesh Sharma",
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                value.isNotEmpty ? value : '—',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavGridItem(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
    Widget screen,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? theme.colorScheme.onSurface : theme.primaryColor;
    final iconBgColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
        : theme.primaryColor.withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await _verifyPassword(context, title);
            if (result == null) return; // cancelled — silent, no message
            if (result == false) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect password.'),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
            if (context.mounted) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => screen));
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Icon Container and Trailing Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),

                // Bottom Row: Text Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
