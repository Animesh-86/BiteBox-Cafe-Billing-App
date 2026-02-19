import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/settings_shared.dart';

// The manager password for outlet operations
const String _kOutletPassword = 'admin123';

class LocationsSettingsScreen extends ConsumerStatefulWidget {
  const LocationsSettingsScreen({super.key});

  @override
  ConsumerState<LocationsSettingsScreen> createState() =>
      _LocationsSettingsScreenState();
}

class _LocationsSettingsScreenState
    extends ConsumerState<LocationsSettingsScreen> {
  List<Location> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  /// Load locations directly from the DB and refresh the UI
  Future<void> _loadLocations() async {
    final db = ref.read(appDatabaseProvider);
    final rows = await (db.select(
      db.locations,
    )..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
    if (mounted) {
      setState(() {
        _locations = rows;
        _loading = false;
      });
    }
  }

  /// Shows a password dialog. Returns true if the correct password was entered.
  Future<bool> _verifyPassword(String action) async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Manager Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter password to $action',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (_) {
                  Navigator.pop(
                    ctx,
                    passwordController.text == _kOutletPassword,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, passwordController.text == _kOutletPassword);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (result == false && mounted) {
      if (passwordController.text.isNotEmpty &&
          passwordController.text != _kOutletPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return result ?? false;
  }

  void _showAddLocationDialog() async {
    final ok = await _verifyPassword('add a new outlet');
    if (!ok) return;

    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Add Outlet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Outlet Name *',
                  hintText: 'e.g., Downtown Branch',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: 'Full address',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+91 XXXXXXXXXX',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  addressController.text.isEmpty ||
                  phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              final db = ref.read(appDatabaseProvider);
              await db
                  .into(db.locations)
                  .insert(
                    LocationsCompanion(
                      id: Value(const Uuid().v4()),
                      name: Value(nameController.text.trim()),
                      address: Value(addressController.text.trim()),
                      phoneNumber: Value(phoneController.text.trim()),
                      isActive: const Value(false),
                      createdAt: Value(DateTime.now()),
                    ),
                  );
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    // Refresh after dialog closes (whether saved or cancelled)
    await _loadLocations();
  }

  void _showEditLocationDialog(Location location) async {
    final ok = await _verifyPassword('edit this outlet');
    if (!ok) return;

    final nameController = TextEditingController(text: location.name);
    final addressController = TextEditingController(text: location.address);
    final phoneController = TextEditingController(text: location.phoneNumber);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Edit Outlet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Outlet Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number *'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  addressController.text.isEmpty ||
                  phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              final db = ref.read(appDatabaseProvider);
              await (db.update(
                db.locations,
              )..where((t) => t.id.equals(location.id))).write(
                LocationsCompanion(
                  name: Value(nameController.text.trim()),
                  address: Value(addressController.text.trim()),
                  phoneNumber: Value(phoneController.text.trim()),
                ),
              );
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    await _loadLocations();
  }

  Future<void> _activateOutlet(Location loc) async {
    final ok = await _verifyPassword('switch to ${loc.name}');
    if (!ok) return;

    final db = ref.read(appDatabaseProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_outlet_id', loc.id);

    await db.transaction(() async {
      await db
          .update(db.locations)
          .write(const LocationsCompanion(isActive: Value(false)));
      await (db.update(db.locations)..where((t) => t.id.equals(loc.id))).write(
        const LocationsCompanion(isActive: Value(true)),
      );
    });

    await _loadLocations();
    // Also invalidate Riverpod stream providers so other screens update
    ref.invalidate(locationsStreamProvider);
    ref.invalidate(activeOutletProvider);
  }

  Future<void> _deactivateOutlet(Location loc) async {
    final ok = await _verifyPassword('deactivate ${loc.name}');
    if (!ok) return;

    final db = ref.read(appDatabaseProvider);
    await (db.update(db.locations)..where((t) => t.id.equals(loc.id))).write(
      const LocationsCompanion(isActive: Value(false)),
    );

    await _loadLocations();
    ref.invalidate(locationsStreamProvider);
    ref.invalidate(activeOutletProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Outlets"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(color: Theme.of(context).scaffoldBackgroundColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
            child: SingleChildScrollView(
              child: SettingsSection(
                title: "Manage Outlets",
                icon: Icons.store_rounded,
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_locations.isEmpty)
                    Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No outlets configured',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add your first outlet to start billing',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _locations.map((loc) {
                        final isActive = loc.isActive ?? false;
                        final theme = Theme.of(context);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? theme.colorScheme.primary.withOpacity(0.5)
                                  : theme.dividerColor.withOpacity(0.2),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                loc.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isActive
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurface,
                                                ),
                                              ),
                                              if (isActive) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'ACTIVE',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            loc.address ?? 'No Address',
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.7),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone,
                                                size: 12,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.5),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                loc.phoneNumber ?? 'No Phone',
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () =>
                                          _showEditLocationDialog(loc),
                                      tooltip: 'Edit Outlet',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (!isActive)
                                      ElevatedButton.icon(
                                        onPressed: () => _activateOutlet(loc),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Activate'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed: _locations.length > 1
                                            ? () => _deactivateOutlet(loc)
                                            : null,
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Deactivate'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _showAddLocationDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Outlet'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
