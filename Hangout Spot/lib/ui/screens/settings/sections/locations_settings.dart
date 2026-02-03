import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangout_spot/logic/locations/location_provider.dart';
import '../widgets/settings_shared.dart';

class LocationsSettingsScreen extends ConsumerStatefulWidget {
  const LocationsSettingsScreen({super.key});

  @override
  ConsumerState<LocationsSettingsScreen> createState() =>
      _LocationsSettingsScreenState();
}

class _LocationsSettingsScreenState
    extends ConsumerState<LocationsSettingsScreen> {
  void _setCurrentLocation(String id) {
    ref.read(locationsControllerProvider.notifier).setCurrentLocation(id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Current location updated')));
    }
  }

  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Add Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
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
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref
                    .read(locationsControllerProvider.notifier)
                    .addLocation(nameController.text, addressController.text);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(locationsStreamProvider);
    final currentLocationIdAsync = ref.watch(currentLocationIdProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Locations"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background/Structure could be reused or just simple dark bg
          Container(color: Colors.black),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
            child: SingleChildScrollView(
              child: SettingsSection(
                title: "Manage Locations",
                icon: Icons.place_rounded,
                children: [
                  locationsAsync.when(
                    data: (locations) {
                      final currentId = currentLocationIdAsync.valueOrNull;
                      if (locations.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('No locations added yet'),
                          ),
                        );
                      }
                      return Column(
                        children: locations.map((loc) {
                          final isSelected = loc.id == currentId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: RadioListTile<String>(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              activeColor: Theme.of(context).primaryColor,
                              title: Text(
                                loc.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                              subtitle: Text(loc.address ?? ''),
                              value: loc.id,
                              groupValue: currentId,
                              onChanged: (val) {
                                if (val != null) _setCurrentLocation(val);
                              },
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
                    child: TextButton.icon(
                      onPressed: _showAddLocationDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Location'),
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
