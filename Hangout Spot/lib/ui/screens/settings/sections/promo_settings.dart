import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/settings_shared.dart';

class PromoSettingsScreen extends StatefulWidget {
  const PromoSettingsScreen({super.key});

  @override
  State<PromoSettingsScreen> createState() => _PromoSettingsScreenState();
}

class _PromoSettingsScreenState extends State<PromoSettingsScreen> {
  // PROMO CONTROLLERS
  final TextEditingController _promoTitleController = TextEditingController();
  final TextEditingController _promoDiscountController =
      TextEditingController();
  final TextEditingController _promoBundleController = TextEditingController();

  bool _promoEnabled = false;
  DateTime? _promoStart;
  DateTime? _promoEnd;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromoSettings();
  }

  @override
  void dispose() {
    _promoTitleController.dispose();
    _promoDiscountController.dispose();
    _promoBundleController.dispose();
    super.dispose();
  }

  Future<void> _loadPromoSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _promoEnabled = prefs.getBool('promo_enabled') ?? false;
      _promoTitleController.text = prefs.getString('promo_title') ?? '';
      _promoDiscountController.text = (prefs.getDouble('promo_discount') ?? 0.0)
          .toString();
      _promoBundleController.text = prefs.getString('promo_bundle_ids') ?? '';
      final startStr = prefs.getString('promo_start_iso');
      final endStr = prefs.getString('promo_end_iso');
      if (startStr != null) _promoStart = DateTime.tryParse(startStr);
      if (endStr != null) _promoEnd = DateTime.tryParse(endStr);
      _isLoading = false;
    });
  }

  Future<void> _savePromoSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('promo_enabled', _promoEnabled);
    if (_promoEnabled) {
      await prefs.setString('promo_title', _promoTitleController.text);
      await prefs.setDouble(
        'promo_discount',
        double.tryParse(_promoDiscountController.text) ?? 0.0,
      );
      await prefs.setString('promo_bundle_ids', _promoBundleController.text);
      if (_promoStart != null) {
        await prefs.setString(
          'promo_start_iso',
          _promoStart!.toIso8601String(),
        );
      }
      if (_promoEnd != null) {
        await prefs.setString('promo_end_iso', _promoEnd!.toIso8601String());
      }
    }
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
        title: const Text("Active Promotion"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: SingleChildScrollView(
          child: SettingsSection(
            title: "Manage Campaign",
            icon: Icons.local_offer_rounded,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Promo Campaign'),
                value: _promoEnabled,
                onChanged: (val) => setState(() => _promoEnabled = val),
              ),
              if (_promoEnabled) ...[
                const SizedBox(height: 12),
                SettingsTextField(
                  controller: _promoTitleController,
                  label: "Promo Title",
                  icon: Icons.title,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SettingsTextField(
                        controller: _promoDiscountController,
                        label: "Discount %",
                        icon: Icons.percent,
                        inputType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SettingsTextField(
                  controller: _promoBundleController,
                  label: "Bundle IDs (csv)",
                  icon: Icons.list_alt,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SettingsDateBtn(
                        label: "Start",
                        date: _promoStart,
                        onPick: (d) => setState(() => _promoStart = d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SettingsDateBtn(
                        label: "End",
                        date: _promoEnd,
                        isEnd: true,
                        onPick: (d) => setState(() => _promoEnd = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: SettingsActionBtn(
                    label: "Save Campaign",
                    onPressed: () async {
                      await _savePromoSettings();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Offer settings saved')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
