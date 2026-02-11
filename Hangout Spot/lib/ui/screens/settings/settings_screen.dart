import 'dart:ui';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hangout_spot/data/repositories/auth_repository.dart';

import 'package:hangout_spot/ui/screens/auth/login_screen.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';
import 'sections/appearance_settings.dart';
import 'sections/backup_settings.dart';
import 'sections/locations_settings.dart';
import 'sections/loyalty_settings.dart';
import 'sections/promo_settings.dart';
import 'sections/receipt_settings.dart';
import 'widgets/settings_shared.dart';
import 'sections/printer_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // STORE DETAILS CONTROLLERS
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _storePhoneController = TextEditingController();
  final TextEditingController _storeEmailController = TextEditingController();

  String? _storeLogoPath;
  bool _storeSettingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStoreSettings();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _storeEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeNameController.text = prefs.getString(STORE_NAME_KEY) ?? '';
      _storeAddressController.text = prefs.getString(STORE_ADDRESS_KEY) ?? '';
      _storePhoneController.text = prefs.getString(STORE_PHONE_KEY) ?? '';
      _storeLogoPath = prefs.getString(STORE_LOGO_KEY);
      _storeSettingsLoaded = true;
    });
  }

  Future<void> _saveStoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(STORE_NAME_KEY, _storeNameController.text);
    await prefs.setString(STORE_ADDRESS_KEY, _storeAddressController.text);
    await prefs.setString(STORE_PHONE_KEY, _storePhoneController.text);
    if (_storeLogoPath != null) {
      await prefs.setString(STORE_LOGO_KEY, _storeLogoPath!);
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _storeLogoPath = result.files.single.path;
      });
      await _saveStoreSettings();
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildNavTile(
    String title,
    IconData icon,
    String subtitle,
    Widget screen,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? theme.colorScheme.onSurface : theme.primaryColor;
    final iconBgColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.1)
        : theme.primaryColor.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          onTap: () => _navigateTo(screen),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (_storeEmailController.text != user?.email) {
      _storeEmailController.text = user?.email ?? '';
    }

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
                    child: Text(
                      "Settings",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
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
                      // 1. Redesigned Store Profile
                      SettingsSection(
                        title: "Store Profile",
                        icon: Icons.store_rounded,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Picker
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                    image: _storeLogoPath != null
                                        ? DecorationImage(
                                            image: FileImage(
                                              File(_storeLogoPath!),
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _storeLogoPath == null
                                      ? Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 32,
                                          color: Theme.of(context).primaryColor,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Name and Address
                              Expanded(
                                child: Column(
                                  children: [
                                    SettingsTextField(
                                      controller: _storeNameController,
                                      label: "Store Name",
                                      icon: Icons.storefront,
                                    ),
                                    const SizedBox(height: 12),
                                    SettingsTextField(
                                      controller: _storeAddressController,
                                      label: "Address",
                                      icon: Icons.location_on_rounded,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SettingsTextField(
                            controller: _storePhoneController,
                            label: "Phone Number",
                            icon: Icons.phone_rounded,
                            inputType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          SettingsTextField(
                            controller: _storeEmailController,
                            label: "Email",
                            icon: Icons.email_rounded,
                            inputType: TextInputType.emailAddress,
                            readOnly: true,
                          ),
                          const SizedBox(height: 24),

                          // Save & Logout Buttons
                          Row(
                            children: [
                              Expanded(
                                child: SettingsActionBtn(
                                  label: "Save Profile",
                                  onPressed: _storeSettingsLoaded
                                      ? () async {
                                          await _saveStoreSettings();
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Store profile saved',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ref.read(authRepositoryProvider).signOut();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                                side: BorderSide(
                                  color: Colors.redAccent.withOpacity(0.5),
                                ),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 20),
                              label: const Text("Logout"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Navigation Items
                      _buildNavTile(
                        "Locations",
                        Icons.place_rounded,
                        "Manage store locations",
                        const LocationsSettingsScreen(),
                      ),
                      _buildNavTile(
                        "Loyalty Program",
                        Icons.stars_rounded,
                        "Configure rewards and points",
                        const LoyaltySettingsScreen(),
                      ),
                      _buildNavTile(
                        "Active Promotion",
                        Icons.local_offer_rounded,
                        "Set up campaigns and discounts",
                        const PromoSettingsScreen(),
                      ),
                      _buildNavTile(
                        "Receipt Config",
                        Icons.receipt_long_rounded,
                        "Customize printed receipts",
                        const ReceiptSettingsScreen(),
                      ),
                      _buildNavTile(
                        "Cloud Backup",
                        Icons.cloud_sync_rounded,
                        "Sync data and restore",
                        const BackupSettingsScreen(),
                      ),
                      _buildNavTile(
                        "Appearance",
                        Icons.palette_rounded,
                        "Change app theme",
                        const AppearanceSettingsScreen(),
                      ),

                      _buildNavTile(
                        "Printer Settings",
                        Icons.print_rounded,
                        "Connect thermal printer",
                        const PrinterSettingsScreen(),
                      ),

                      const SizedBox(height: 48),

                      Center(
                        child: Column(
                          children: [
                            Text(
                              "Hangout Spot v1.0.0",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.3),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Developed by Animesh Sharma",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80), // Bottom padding
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
}
