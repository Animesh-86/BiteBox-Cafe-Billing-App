import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import '../widgets/settings_shared.dart';
import 'package:hangout_spot/ui/widgets/trust_gate.dart';

class LocationsSettingsScreen extends ConsumerStatefulWidget {
  const LocationsSettingsScreen({super.key});

  @override
  ConsumerState<LocationsSettingsScreen> createState() =>
      _LocationsSettingsScreenState();
}

class _LocationsSettingsScreenState
    extends ConsumerState<LocationsSettingsScreen> {
  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
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
              await ref
                  .read(locationsControllerProvider.notifier)
                  .addLocation(
                    nameController.text,
                    addressController.text,
                    phoneController.text,
                  );
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditLocationDialog(Location location) {
    final nameController = TextEditingController(text: location.name);
    final addressController = TextEditingController(text: location.address);
    final phoneController = TextEditingController(text: location.phoneNumber);

    showDialog(
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
              await ref
                  .read(locationsControllerProvider.notifier)
                  .updateLocation(
                    location.id,
                    nameController.text,
                    addressController.text,
                    phoneController.text,
                  );
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(locationsStreamProvider);
    final activeOutletAsync = ref.watch(activeOutletProvider);

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
          // Background/Structure
          Container(color: Theme.of(context).scaffoldBackgroundColor),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
            child: SingleChildScrollView(
              child: SettingsSection(
                title: "Manage Outlets",
                icon: Icons.store_rounded,
                children: [
                  locationsAsync.when(
                    data: (locations) {
                      final activeOutlet = activeOutletAsync.valueOrNull;
                      if (locations.isEmpty) {
                        return Card(
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
                        );
                      }
                      return Column(
                        children: locations.map((loc) {
                          final isActive = loc.isActive ?? false; // Handle null
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
                                  // Header Row
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
                                              loc.address ??
                                                  'No Address', // Handle null
                                              style: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
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
                                                  loc.phoneNumber ??
                                                      'No Phone', // Handle null
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
                                      // Edit Button
                                      TrustedDeviceGate(
                                        child: IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () =>
                                              _showEditLocationDialog(loc),
                                          tooltip: 'Edit Outlet',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  // Action Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (!isActive)
                                        TrustedDeviceGate(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              ref
                                                  .read(
                                                    locationsControllerProvider
                                                        .notifier,
                                                  )
                                                  .activateOutlet(loc.id);
                                            },
                                            icon: const Icon(
                                              Icons.check_circle_outline,
                                              size: 18,
                                            ),
                                            label: const Text('Activate'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        )
                                      else
                                        TrustedDeviceGate(
                                          child: ElevatedButton.icon(
                                            onPressed: locations.length > 1
                                                ? () {
                                                    ref
                                                        .read(
                                                          locationsControllerProvider
                                                              .notifier,
                                                        )
                                                        .deactivateOutlet(
                                                          loc.id,
                                                        );
                                                  }
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
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TrustedDeviceGate(
                      child: TextButton.icon(
                        onPressed: _showAddLocationDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Outlet'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
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
