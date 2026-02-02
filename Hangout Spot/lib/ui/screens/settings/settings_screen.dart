import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:hangout_spot/ui/screens/auth/login_screen.dart';
import 'package:hangout_spot/data/providers/theme_provider.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;
  late TextEditingController _earningRateController;
  late TextEditingController _redemptionRateController;

  @override
  void initState() {
    super.initState();
    _earningRateController = TextEditingController();
    _redemptionRateController = TextEditingController();
  }

  @override
  void dispose() {
    _earningRateController.dispose();
    _redemptionRateController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncRepositoryProvider).backupData();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Backup Successful!")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Backup Failed: $e")));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
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
                      'Earning Rate: ${((double.tryParse(settings[REWARD_RATE_KEY] ?? '0.08') ?? 0.08) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Redemption Rate: ₹${double.tryParse(settings[REDEMPTION_RATE_KEY] ?? '1.0') ?? 1.0}/point',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
