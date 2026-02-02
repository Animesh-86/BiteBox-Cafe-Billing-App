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
import 'package:hangout_spot/logic/offers/promo_provider.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:uuid/uuid.dart';

const String CLOUD_AUTO_SYNC_ENABLED_KEY = 'cloud_auto_sync_enabled';
const String CLOUD_AUTO_SYNC_INTERVAL_KEY = 'cloud_auto_sync_interval_minutes';
const int DEFAULT_AUTO_SYNC_INTERVAL_MINUTES = 15;
const String STORE_NAME_KEY = 'store_name';
const String STORE_ADDRESS_KEY = 'store_address';
const String STORE_LOGO_URL_KEY = 'store_logo_url';
const String RECEIPT_FOOTER_KEY = 'receipt_footer';
const String RECEIPT_SHOW_THANK_YOU_KEY = 'receipt_show_thank_you';

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
  late TextEditingController _storeNameController;
  late TextEditingController _storeAddressController;
  late TextEditingController _storeLogoController;
  late TextEditingController _receiptFooterController;
  bool _showThankYou = true;
  bool _storeSettingsLoaded = false;
  late TextEditingController _promoTitleController;
  late TextEditingController _promoDiscountController;
  late TextEditingController _promoBundleController;
  bool _promoEnabled = false;
  DateTime? _promoStart;
  DateTime? _promoEnd;
  bool _promoSettingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _earningRateController = TextEditingController();
    _redemptionRateController = TextEditingController();
    _storeNameController = TextEditingController();
    _storeAddressController = TextEditingController();
    _storeLogoController = TextEditingController();
    _receiptFooterController = TextEditingController();
    _promoTitleController = TextEditingController();
    _promoDiscountController = TextEditingController();
    _promoBundleController = TextEditingController();
    _loadSyncSettings();
    _loadStoreSettings();
    _loadPromoSettings();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _earningRateController.dispose();
    _redemptionRateController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storeLogoController.dispose();
    _receiptFooterController.dispose();
    _promoTitleController.dispose();
    _promoDiscountController.dispose();
    _promoBundleController.dispose();
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

  Future<void> _loadStoreSettings() async {
    final db = ref.read(appDatabaseProvider);
    final settings =
        await (db.select(db.settings)..where(
              (tbl) => tbl.key.isIn([
                STORE_NAME_KEY,
                STORE_ADDRESS_KEY,
                STORE_LOGO_URL_KEY,
                RECEIPT_FOOTER_KEY,
                RECEIPT_SHOW_THANK_YOU_KEY,
              ]),
            ))
            .get();

    final map = <String, String>{for (final s in settings) s.key: s.value};
    _storeNameController.text = map[STORE_NAME_KEY] ?? 'Hangout Spot';
    _storeAddressController.text = map[STORE_ADDRESS_KEY] ?? '';
    _storeLogoController.text = map[STORE_LOGO_URL_KEY] ?? '';
    _receiptFooterController.text = map[RECEIPT_FOOTER_KEY] ?? '';
    _showThankYou = (map[RECEIPT_SHOW_THANK_YOU_KEY] ?? 'true') == 'true';

    if (mounted) {
      setState(() => _storeSettingsLoaded = true);
    }
  }

  Future<void> _saveStoreSettings() async {
    final db = ref.read(appDatabaseProvider);
    final entries = <MapEntry<String, String>>[
      MapEntry(STORE_NAME_KEY, _storeNameController.text.trim()),
      MapEntry(STORE_ADDRESS_KEY, _storeAddressController.text.trim()),
      MapEntry(STORE_LOGO_URL_KEY, _storeLogoController.text.trim()),
      MapEntry(RECEIPT_FOOTER_KEY, _receiptFooterController.text.trim()),
      MapEntry(RECEIPT_SHOW_THANK_YOU_KEY, _showThankYou.toString()),
    ];

    for (final entry in entries) {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion(
              key: drift.Value(entry.key),
              value: drift.Value(entry.value),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _loadPromoSettings() async {
    final db = ref.read(appDatabaseProvider);
    final settings =
        await (db.select(db.settings)..where(
              (tbl) => tbl.key.isIn([
                PROMO_ENABLED_KEY,
                PROMO_TITLE_KEY,
                PROMO_START_KEY,
                PROMO_END_KEY,
                PROMO_DISCOUNT_PERCENT_KEY,
                PROMO_BUNDLE_ITEM_IDS_KEY,
              ]),
            ))
            .get();

    final map = <String, String>{for (final s in settings) s.key: s.value};
    _promoEnabled = (map[PROMO_ENABLED_KEY] ?? 'false') == 'true';
    _promoTitleController.text = map[PROMO_TITLE_KEY] ?? 'Valentine Combo';
    _promoDiscountController.text = map[PROMO_DISCOUNT_PERCENT_KEY] ?? '0';
    _promoBundleController.text = map[PROMO_BUNDLE_ITEM_IDS_KEY] ?? '';
    _promoStart = DateTime.tryParse(map[PROMO_START_KEY] ?? '');
    _promoEnd = DateTime.tryParse(map[PROMO_END_KEY] ?? '');

    if (mounted) {
      setState(() => _promoSettingsLoaded = true);
    }
  }

  Future<void> _savePromoSettings() async {
    final db = ref.read(appDatabaseProvider);
    final entries = <MapEntry<String, String>>[
      MapEntry(PROMO_ENABLED_KEY, _promoEnabled.toString()),
      MapEntry(PROMO_TITLE_KEY, _promoTitleController.text.trim()),
      MapEntry(PROMO_START_KEY, _promoStart?.toIso8601String() ?? ''),
      MapEntry(PROMO_END_KEY, _promoEnd?.toIso8601String() ?? ''),
      MapEntry(
        PROMO_DISCOUNT_PERCENT_KEY,
        _promoDiscountController.text.trim(),
      ),
      MapEntry(PROMO_BUNDLE_ITEM_IDS_KEY, _promoBundleController.text.trim()),
    ];

    for (final entry in entries) {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion(
              key: drift.Value(entry.key),
              value: drift.Value(entry.value),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
    }
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

  Future<void> _setCurrentLocation(String locationId) async {
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.settings)
        .insert(
          SettingsCompanion(
            key: const drift.Value(CURRENT_LOCATION_ID_KEY),
            value: drift.Value(locationId),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
  }

  Future<void> _showAddLocationDialog() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Location name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(appDatabaseProvider);
              final id = const Uuid().v4();
              await db
                  .into(db.locations)
                  .insert(
                    LocationsCompanion(
                      id: drift.Value(id),
                      name: drift.Value(name),
                      address: drift.Value(address.isEmpty ? null : address),
                    ),
                  );
              await _setCurrentLocation(id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authRepositoryProvider).currentUser;
    final themeMode = ref.watch(themeProvider);
    final locationsAsync = ref.watch(locationsStreamProvider);
    final currentLocationIdAsync = ref.watch(currentLocationIdProvider);

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
                    "Store Information",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _storeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Store Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _storeAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _storeLogoController,
                        decoration: const InputDecoration(
                          labelText: 'Logo URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _storeSettingsLoaded
                              ? () async {
                                  await _saveStoreSettings();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Store info saved'),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: const Text('Save Store Info'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Receipt Customization",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show Thank You line'),
                        value: _showThankYou,
                        onChanged: (val) {
                          setState(() => _showThankYou = val);
                        },
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _receiptFooterController,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Footer Note',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _storeSettingsLoaded
                              ? () async {
                                  await _saveStoreSettings();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Receipt settings saved'),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: const Text('Save Receipt'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Marketing Offers",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable limited-time offer'),
                        value: _promoEnabled,
                        onChanged: (val) {
                          setState(() => _promoEnabled = val);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _promoTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Offer title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _promoDiscountController,
                        decoration: const InputDecoration(
                          labelText: 'Discount % for combo',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _promoBundleController,
                        decoration: const InputDecoration(
                          labelText: 'Bundle Item IDs (comma separated)',
                          border: OutlineInputBorder(),
                          helperText:
                              'Paste item IDs from menu export for combo offers',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _promoStart ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null && mounted) {
                                  setState(
                                    () => _promoStart = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                _promoStart == null
                                    ? 'Start Date'
                                    : 'Start: ${_promoStart!.toLocal().toString().split(' ').first}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _promoEnd ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null && mounted) {
                                  setState(
                                    () => _promoEnd = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      23,
                                      59,
                                      59,
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                _promoEnd == null
                                    ? 'End Date'
                                    : 'End: ${_promoEnd!.toLocal().toString().split(' ').first}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _promoSettingsLoaded
                              ? () async {
                                  await _savePromoSettings();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Offer settings saved'),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: const Text('Save Offer'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Locations",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      locationsAsync.when(
                        data: (locations) {
                          final currentId = currentLocationIdAsync.valueOrNull;
                          if (locations.isEmpty) {
                            return const Text('No locations added yet');
                          }
                          return Column(
                            children: locations
                                .map(
                                  (loc) => RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(loc.name),
                                    subtitle: Text(loc.address ?? ''),
                                    value: loc.id,
                                    groupValue: currentId,
                                    onChanged: (val) {
                                      if (val != null) {
                                        _setCurrentLocation(val);
                                      }
                                    },
                                  ),
                                )
                                .toList(),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _showAddLocationDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Location'),
                        ),
                      ),
                    ],
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
