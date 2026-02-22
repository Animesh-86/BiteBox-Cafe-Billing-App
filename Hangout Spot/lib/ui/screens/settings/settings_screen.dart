import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/providers/theme_provider.dart';

import '../customer/customer_list_screen.dart';
import 'providers/settings_auth_provider.dart';
import 'sections/backup_settings.dart';
import 'sections/locations_settings.dart';
import 'sections/loyalty_settings.dart';
import 'sections/promo_settings.dart';
import 'sections/receipt_settings.dart';
import 'sections/operating_hours_settings.dart';
import 'active_sessions_screen.dart';
import 'widgets/settings_shared.dart';
import 'sections/printer_settings_screen.dart';
import 'utils/password_reauth.dart';

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
            'Enter your account password to open ${widget.action}.',
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
            onSubmitted: (_) => Navigator.pop(context, _controller.text),
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
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

/// Returns true if granted, false if wrong password, null if cancelled.
Future<bool?> verifyManagerPassword(
  BuildContext context,
  WidgetRef ref,
  String action,
) async {
  // Check if we have an active session
  final lastAuth = ref.read(settingsAuthSessionProvider);
  if (lastAuth != null) {
    if (DateTime.now().difference(lastAuth) < kSettingsAuthTimeout) {
      return true; // Auto-grant access since recently authenticated
    } else {
      // Session expired, clear it
      ref.read(settingsAuthSessionProvider.notifier).state = null;
    }
  }

  final password = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(action: action),
  );
  if (password == null) return null; // cancelled

  final errorMessage = await reauthenticateCurrentUserWithPassword(
    password: password,
  );
  if (errorMessage != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return false;
  }

  // Save success time to create session
  ref.read(settingsAuthSessionProvider.notifier).state = DateTime.now();
  return true;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final activeOutletAsync = ref.watch(activeOutletProvider);

    final navigationItems = [
      {
        "title": "Customers",
        "icon": Icons.people_rounded,
        "subtitle": "Add, edit, discount & manage",
        "screen": const CustomerListScreen(),
      },
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
                      // 1. Read-only Cafe Profile (auto-fetched from outlet)
                      SettingsSection(
                        title: "Cafe Profile",
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
                              return _StoreProfileContent(
                                outlet: outlet,
                                userEmail: user?.email ?? '—',
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
                            ref,
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

  Widget _buildNavGridItem(
    BuildContext context,
    WidgetRef ref,
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
            final result = await verifyManagerPassword(context, ref, title);
            if (result == null) return; // cancelled — silent, no message
            if (result == false) return;
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

// ─── Store Profile Content Widget (with logo picker) ─────────────────────────

class _StoreProfileContent extends StatefulWidget {
  final dynamic outlet;
  final String userEmail;
  const _StoreProfileContent({required this.outlet, required this.userEmail});

  @override
  State<_StoreProfileContent> createState() => _StoreProfileContentState();
}

class _StoreProfileContentState extends State<_StoreProfileContent> {
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _logoPath = prefs.getString('store_logo_path'));
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store_logo_path', path);
      if (mounted) setState(() => _logoPath = path);
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outlet = widget.outlet;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: info rows
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(Icons.store_rounded, 'Cafe Name', outlet?.name ?? '—'),
              _infoRow(
                Icons.location_on_rounded,
                'Address',
                outlet?.address ?? '—',
              ),
              _infoRow(
                Icons.phone_rounded,
                'Phone',
                outlet?.phoneNumber ?? '—',
              ),
              _infoRow(Icons.email_rounded, 'Email', widget.userEmail),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Profile is managed through Outlets settings.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right: logo avatar
        GestureDetector(
          onTap: _pickLogo,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                backgroundImage: _logoPath != null
                    ? FileImage(File(_logoPath!))
                    : null,
                child: _logoPath == null
                    ? Icon(
                        Icons.store_rounded,
                        size: 36,
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
