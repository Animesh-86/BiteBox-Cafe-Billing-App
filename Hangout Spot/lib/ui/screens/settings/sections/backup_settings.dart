import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/ui/screens/auth/login_screen.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';
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
          int.tryParse(prefs.getString(CLOUD_AUTO_SYNC_INTERVAL_KEY) ?? '15') ??
          15;
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
                          items: const [15, 30, 60].map((m) {
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      "Logging out will backup your data to the cloud and clear all local data from this device.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
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
                            content: const Text(
                              'Your data will be backed up to the cloud and this device will be cleared.\n\n'
                              'Are you sure you want to logout?',
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
                            builder: (c) => const Center(
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text("Backing up data..."),
                                    ],
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
            ],
          ),
        ),
      ),
    );
  }
}
