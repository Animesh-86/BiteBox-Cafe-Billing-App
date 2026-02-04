import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';
import '../widgets/settings_shared.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  final TextEditingController _receiptFooterController =
      TextEditingController();
  bool _showThankYou = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceiptSettings();
  }

  @override
  void dispose() {
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _loadReceiptSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showThankYou = prefs.getBool(RECEIPT_SHOW_THANK_YOU_KEY) ?? true;
      _receiptFooterController.text = prefs.getString(RECEIPT_FOOTER_KEY) ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveReceiptSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(RECEIPT_SHOW_THANK_YOU_KEY, _showThankYou);
    await prefs.setString(RECEIPT_FOOTER_KEY, _receiptFooterController.text);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Receipt Config"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: SingleChildScrollView(
          child: SettingsSection(
            title: "Receipt Configuration",
            icon: Icons.receipt_long_rounded,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show "Thank You" Line'),
                value: _showThankYou,
                onChanged: (val) => setState(() => _showThankYou = val),
              ),
              const SizedBox(height: 8),
              SettingsTextField(
                controller: _receiptFooterController,
                label: "Footer Note",
                icon: Icons.notes,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: SettingsActionBtn(
                  label: "Update Receipt",
                  onPressed: () async {
                    await _saveReceiptSettings();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt settings saved')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
