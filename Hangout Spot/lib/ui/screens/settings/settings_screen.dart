import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:hangout_spot/ui/screens/auth/login_screen.dart';
import 'package:hangout_spot/data/providers/theme_provider.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';

const String CLOUD_AUTO_SYNC_ENABLED_KEY = 'cloud_auto_sync_enabled';
const String CLOUD_AUTO_SYNC_INTERVAL_KEY = 'cloud_auto_sync_interval_minutes';
const int DEFAULT_AUTO_SYNC_INTERVAL_MINUTES = 15;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;
  bool _autoSyncEnabled = false;
  int _autoSyncIntervalMinutes = DEFAULT_AUTO_SYNC_INTERVAL_MINUTES;
  bool _syncSettingsLoaded = false;
  Timer? _autoSyncTimer;
  late TextEditingController _earningRateController;
  late TextEditingController _redemptionRateController;

  @override
  void initState() {
    super.initState();
    _earningRateController = TextEditingController();
    _redemptionRateController = TextEditingController();
    _loadSyncSettings();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _earningRateController.dispose();
    _redemptionRateController.dispose();
    super.dispose();
  }

  Future<void> _sync({bool showSnackBar = true}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncRepositoryProvider).backupData();
      if (mounted && showSnackBar)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Backup Successful!")));
    } catch (e) {
      if (mounted && showSnackBar)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Backup Failed: $e")));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadSyncSettings() async {
    final db = ref.read(appDatabaseProvider);
    final settings =
        await (db.select(db.settings)..where(
              (tbl) => tbl.key.isIn([
                CLOUD_AUTO_SYNC_ENABLED_KEY,
                CLOUD_AUTO_SYNC_INTERVAL_KEY,
              ]),
            ))
            .get();

    final map = <String, String>{for (final s in settings) s.key: s.value};

    final enabled = map[CLOUD_AUTO_SYNC_ENABLED_KEY] == 'true';
    final interval =
        int.tryParse(
          map[CLOUD_AUTO_SYNC_INTERVAL_KEY] ??
              DEFAULT_AUTO_SYNC_INTERVAL_MINUTES.toString(),
        ) ??
        DEFAULT_AUTO_SYNC_INTERVAL_MINUTES;

    if (mounted) {
      setState(() {
        _autoSyncEnabled = enabled;
        _autoSyncIntervalMinutes = interval;
        _syncSettingsLoaded = true;
      });
    }

    _applyAutoSync();
  }

  Future<void> _saveSyncSetting(String key, String value) async {
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.settings)
        .insert(
          SettingsCompanion(key: drift.Value(key), value: drift.Value(value)),
          mode: drift.InsertMode.insertOrReplace,
        );
  }

  void _applyAutoSync() {
    _autoSyncTimer?.cancel();
    if (!_autoSyncEnabled) return;

    _autoSyncTimer = Timer.periodic(
      Duration(minutes: _autoSyncIntervalMinutes),
      (_) => _sync(showSnackBar: false),
    );
  }

  Future<void> _restore() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncRepositoryProvider).restoreData();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Restore Successful!")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Restore Failed: $e")));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authRepositoryProvider).currentUser;
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text("Cafe Details"),
                  subtitle: Text(user?.email ?? "Not logged in"),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Appearance",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text("Theme"),
                  subtitle: Text(
                    themeMode == ThemeMode.system
                        ? "System"
                        : (themeMode == ThemeMode.light ? "Light" : "Dark"),
                  ),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text("System"),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text("Light"),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text("Dark"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null)
                        ref.read(themeProvider.notifier).setTheme(val);
                    },
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Loyalty & Rewards",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildRewardSettingsSection(ref),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Cloud Sync",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text("Auto Sync"),
                  subtitle: const Text("Automatically backup to cloud"),
                  trailing: Switch(
                    value: _autoSyncEnabled,
                    onChanged: !_syncSettingsLoaded
                        ? null
                        : (value) async {
                            setState(() => _autoSyncEnabled = value);
                            await _saveSyncSetting(
                              CLOUD_AUTO_SYNC_ENABLED_KEY,
                              value.toString(),
                            );
                            _applyAutoSync();
                          },
                  ),
                ),
                if (_autoSyncEnabled)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text("Sync Interval"),
                    subtitle: Text("Every $_autoSyncIntervalMinutes minutes"),
                    trailing: DropdownButton<int>(
                      value: _autoSyncIntervalMinutes,
                      items: const [15, 30, 60]
                          .map(
                            (m) => DropdownMenuItem<int>(
                              value: m,
                              child: Text("$m min"),
                            ),
                          )
                          .toList(),
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
                  ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text("Sync Now (Backup)"),
                  subtitle: const Text("Upload local data to Cloud"),
                  trailing: _isSyncing
                      ? const CircularProgressIndicator()
                      : null,
                  onTap: _isSyncing ? null : _sync,
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text("Restore from Cloud"),
                  subtitle: const Text("Overwrite local data from Cloud"),
                  onTap: _isSyncing ? null : _restore,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    ref.read(authRepositoryProvider).signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: const [
                  Text(
                    "Hangout Spot v1.0.0",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Developed by Animesh Sharma",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardSettingsSection(WidgetRef ref) {
    final settingsAsync = ref.watch(rewardSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        final isEnabled = settings[REWARD_FEATURE_TOGGLE_KEY] == 'true';
        final earningRate =
            double.tryParse(settings[REWARD_RATE_KEY] ?? '0.08') ?? 0.08;
        final redemptionRate =
            double.tryParse(settings[REDEMPTION_RATE_KEY] ?? '1.0') ?? 1.0;

        if (_earningRateController.text.isEmpty) {
          _earningRateController.text = (earningRate * 100).toStringAsFixed(1);
        }
        if (_redemptionRateController.text.isEmpty) {
          _redemptionRateController.text = redemptionRate.toStringAsFixed(2);
        }

        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: const Text('Enable Reward System'),
              subtitle: const Text('Allow customers to earn and redeem points'),
              trailing: Switch(
                value: isEnabled,
                onChanged: (value) async {
                  await ref
                      .read(rewardNotifierProvider.notifier)
                      .setRewardSystemEnabled(value);
                  ref.invalidate(rewardSettingsProvider);
                  ref.invalidate(isRewardSystemEnabledProvider);
                },
              ),
            ),
            if (isEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Earning Rate: ${(earningRate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Redemption Rate: ₹${redemptionRate.toStringAsFixed(2)}/point',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _earningRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Earning Rate (%)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _redemptionRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Redemption Rate (₹/point)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          final earningPercent =
                              double.tryParse(_earningRateController.text) ??
                              (earningRate * 100);
                          final redemption =
                              double.tryParse(_redemptionRateController.text) ??
                              redemptionRate;

                          await ref
                              .read(rewardNotifierProvider.notifier)
                              .setRewardEarningRate(earningPercent / 100);
                          await ref
                              .read(rewardNotifierProvider.notifier)
                              .setRedemptionRate(redemption);

                          ref.invalidate(rewardSettingsProvider);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reward rates updated'),
                              ),
                            );
                          }
                        },
                        child: const Text('Save Rates'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
