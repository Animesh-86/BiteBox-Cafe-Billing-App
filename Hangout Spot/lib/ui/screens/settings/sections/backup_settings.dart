import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/ui/screens/auth/login_screen.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/services/realtime_order_service.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import '../utils/password_reauth.dart';
import '../widgets/settings_shared.dart';

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _autoSyncEnabled = false;
  int _autoSyncIntervalMinutes = 15;
  bool _isSyncing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  Future<void> _loadBackupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSyncEnabled =
          (prefs.getString(CLOUD_AUTO_SYNC_ENABLED_KEY) == 'true');
      _autoSyncIntervalMinutes =
          int.tryParse(prefs.getString(CLOUD_AUTO_SYNC_INTERVAL_KEY) ?? '2') ??
          2;
      _isLoading = false;
    });
  }

  Future<void> _saveSyncSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncRepositoryProvider).backupData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sync completed successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Sync failed: $e")));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isSyncing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('skip_auto_restore', false);
      await ref.read(syncRepositoryProvider).restoreData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Restore completed successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Restore failed: $e")));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  // NOTE: In a real app, you would probably trigger a background service update here.
  // For this refactor, we just save the preferences.
  void _applyAutoSync() {
    // Placeholder for restarting background service
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Cloud Backup"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SettingsSection(
                title: "Backup & Restore",
                icon: Icons.cloud_sync_rounded,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Auto-Backup"),
                    subtitle: const Text("Sync data periodically"),
                    value: _autoSyncEnabled,
                    onChanged: (value) async {
                      setState(() => _autoSyncEnabled = value);
                      await _saveSyncSetting(
                        CLOUD_AUTO_SYNC_ENABLED_KEY,
                        value.toString(),
                      );
                      _applyAutoSync();
                    },
                  ),
                  if (_autoSyncEnabled)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Backup Frequency:"),
                        DropdownButton<int>(
                          value: _autoSyncIntervalMinutes,
                          dropdownColor: Theme.of(context).cardTheme.color,
                          underline: Container(),
                          items: const [1, 2, 5, 10, 15].map((m) {
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text("$m min"),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _autoSyncIntervalMinutes = value);
                            await _saveSyncSetting(
                              CLOUD_AUTO_SYNC_INTERVAL_KEY,
                              value.toString(),
                            );
                            _applyAutoSync();
                          },
                        ),
                      ],
                    ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSyncing ? null : _sync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_rounded),
                          label: const Text("Backup Now"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSyncing ? null : _restore,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text("Restore Data"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsSection(
                title: "Account Actions",
                icon: Icons.account_circle_rounded,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      "Logging out will backup your data to the cloud and clear all local data from this device.",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Show confirmation dialog first
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout Confirmation'),
                            content: SafeArea(
                              child: const Text(
                                'Your data will be backed up to the cloud and this device will be cleared.\n\n'
                                'Are you sure you want to logout?',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) return;

                        // 1. Show Loading Dialog
                        if (mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (c) => SafeArea(
                              child: Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Backing up data...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        try {
                          // 2. Perform Backup
                          final syncRepo = ref.read(syncRepositoryProvider);
                          await syncRepo.backupData();

                          if (mounted) {
                            Navigator.pop(context); // Hide "Backing up"
                          }

                          // 3. Clear Local Data
                          if (mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (c) => const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text("Clearing device data..."),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          await syncRepo.clearLocalData();

                          // 4. Sign Out
                          await ref.read(authRepositoryProvider).signOut();

                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            // Pop any existing dialogs if error occurs
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Backup/Logout Failed: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        side: BorderSide(
                          color: Colors.redAccent.withOpacity(0.5),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text("Backup & Logout"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── DANGER ZONE ──────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red.withOpacity(0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.red.withOpacity(0.04),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Danger Zone',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will permanently delete ALL data from the cloud and this device, then log you out. This action cannot be undone.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Step 0: Password gate
                          final password = await showDialog<String>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const _DangerPasswordDialog(),
                          );
                          if (password == null || !mounted) return; // Cancelled

                          final errorMessage =
                              await reauthenticateCurrentUserWithPassword(
                                password: password,
                              );
                          if (errorMessage != null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }

                          if (!mounted) return;
                          // Step 1: First confirmation
                          final confirm1 = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              title: Row(
                                children: const [
                                  Icon(Icons.delete_forever, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Clean All Data?',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              content: const Text(
                                'This will permanently erase ALL orders, customers, settings, and outlet data from both the cloud and this device.\n\nAre you absolutely sure?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Yes, Delete Everything'),
                                ),
                              ],
                            ),
                          );
                          if (confirm1 != true || !mounted) return;

                          // Step 2: Second confirmation (type to confirm)
                          final confirmController = TextEditingController();
                          final confirm2 = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => StatefulBuilder(
                              builder: (ctx, setS) => AlertDialog(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                title: const Text('Final Confirmation'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Type DELETE to confirm:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: confirmController,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          title: Row(
                                            children: const [
                                              Icon(Icons.delete_forever, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text(
                                                'Clean All Data?',
                                                style: TextStyle(color: Colors.red),
                                              ),
                                            ],
                                          ),
                                          content: SafeArea(
                                            child: const Text(
                                              'This will permanently delete all local data from this device.\n\n'
                                              'Are you sure you want to proceed?',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Delete All'),
                                            ),
                                          ],
                                        ),
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.red,
                                      ),
                                      SizedBox(height: 16),
                                      Text('Deleting all data...'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );

                          try {
                            final syncRepo = ref.read(syncRepositoryProvider);
                            final orderService = ref.read(
                              realTimeOrderServiceProvider,
                            );
                            orderService.stopListening();
                            // Delete cloud data first
                            await syncRepo.deleteCloudData();
                            // Then clear local data (this will re-seed default outlet)
                            await syncRepo.clearLocalData();

                            // Mark factory reset to skip any immediate restore
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'factory_reset_completed',
                              true,
                            );
                            await prefs.setBool('skip_auto_restore', true);
                            await prefs.remove('last_sync_app_version');

                            // Reset cart state to default (Walk-in)
                            ref.read(cartProvider.notifier).clearCart();

                            // IMPORTANT: Invalidate ALL providers to clear cached data
                            // This ensures analytics and other screens show fresh data after deletion
                            ref.invalidate(appDatabaseProvider);
                            ref.invalidate(locationsStreamProvider);
                            ref.invalidate(activeOutletProvider);
                            ref.invalidate(locationsControllerProvider);
                            ref.invalidate(analyticsDataProvider);
                            ref.invalidate(cartProvider);

                            // Add extra delay to ensure database operations complete
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );

                            if (mounted) {
                              Navigator.pop(context); // close progress dialog

                              // Show success message
                              await showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 28,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Data Cleared'),
                                    ],
                                  ),
                                  content: const Text(
                                    'All data has been successfully cleared.\n\n'
                                    'Default outlet "Hangout Spot - Kanha Dreamland" has been restored.\n\n'
                                    'IMPORTANT: After logging out, please FULLY RESTART the app (close and reopen) to ensure all cached data is cleared.',
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Terminate all remote sessions (Global Logout)
                            final authRepo = ref.read(authRepositoryProvider);
                            await authRepo.sessionManager.endAllSessions();

                            // Sign out current device securely
                            await authRepo.signOut();
                            orderService.stopListening();

                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(context); // close progress dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'Clean All Data & Logout',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
}

// ─── Password dialog for the Danger Zone ────────────────────────────────────

class _DangerPasswordDialog extends StatefulWidget {
  const _DangerPasswordDialog();

  @override
  State<_DangerPasswordDialog> createState() => _DangerPasswordDialogState();
}

class _DangerPasswordDialogState extends State<_DangerPasswordDialog> {
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
          const Icon(Icons.lock_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Text(
            'Manager Authorisation',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.red),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your account password to continue with data deletion.',
            style: TextStyle(fontSize: 13),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
