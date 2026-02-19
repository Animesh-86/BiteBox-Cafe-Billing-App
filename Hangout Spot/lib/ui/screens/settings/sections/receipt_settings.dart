import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';
import '../widgets/settings_shared.dart';

// ─── SharedPreferences keys ──────────────────────────────────────────────────
const String _kPrinterShowThankYou = 'printer_show_thank_you';
const String _kPrinterFooter = 'printer_footer';
const String _kPrinterShowUpi = 'printer_show_upi';
const String _kPrinterUpiId = 'printer_upi_id';
const String _kPrinterShowLogo = 'printer_show_logo';

const String _kKotShowTime = 'kot_show_time';
const String _kKotShowOrderNo = 'kot_show_order_no';
const String _kKotNotes = 'kot_notes';

// WhatsApp block keys
const String _kWaGreeting = 'wa_greeting';
const String _kWaShowItems = 'wa_show_items';
const String _kWaShowTotal = 'wa_show_total';
const String _kWaShowPayment = 'wa_show_payment';
const String _kWaClosing = 'wa_closing';
const String _kWaShowInvoice = 'wa_show_invoice';

class ReceiptSettingsScreen extends ConsumerStatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  ConsumerState<ReceiptSettingsScreen> createState() =>
      _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends ConsumerState<ReceiptSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // ── Printer Receipt ────────────────────
  bool _printerShowThankYou = true;
  bool _printerShowUpi = false;
  bool _printerShowLogo = true;
  final _printerFooterCtrl = TextEditingController();
  final _printerUpiCtrl = TextEditingController();

  // ── KOT Receipt ───────────────────────
  bool _kotShowTime = true;
  bool _kotShowOrderNo = true;
  final _kotNotesCtrl = TextEditingController();

  // ── WhatsApp blocks ───────────────────
  final _waGreetingCtrl = TextEditingController();
  bool _waShowInvoice = true;
  bool _waShowItems = true;
  bool _waShowTotal = true;
  bool _waShowPayment = true;
  final _waClosingCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _printerFooterCtrl.dispose();
    _printerUpiCtrl.dispose();
    _kotNotesCtrl.dispose();
    _waGreetingCtrl.dispose();
    _waClosingCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _printerShowThankYou = p.getBool(_kPrinterShowThankYou) ?? true;
      _printerShowUpi = p.getBool(_kPrinterShowUpi) ?? false;
      _printerShowLogo = p.getBool(_kPrinterShowLogo) ?? true;
      _printerFooterCtrl.text =
          p.getString(_kPrinterFooter) ?? p.getString(RECEIPT_FOOTER_KEY) ?? '';
      _printerUpiCtrl.text = p.getString(_kPrinterUpiId) ?? '';

      _kotShowTime = p.getBool(_kKotShowTime) ?? true;
      _kotShowOrderNo = p.getBool(_kKotShowOrderNo) ?? true;
      _kotNotesCtrl.text = p.getString(_kKotNotes) ?? '';

      _waGreetingCtrl.text =
          p.getString(_kWaGreeting) ??
          'Hi {{customer_name}} 👋, thank you for visiting *{{store_name}}*!';
      _waShowInvoice = p.getBool(_kWaShowInvoice) ?? true;
      _waShowItems = p.getBool(_kWaShowItems) ?? true;
      _waShowTotal = p.getBool(_kWaShowTotal) ?? true;
      _waShowPayment = p.getBool(_kWaShowPayment) ?? true;
      _waClosingCtrl.text =
          p.getString(_kWaClosing) ?? 'We hope to see you again! 😊';

      _isLoading = false;
    });
  }

  Future<void> _savePrinter() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPrinterShowThankYou, _printerShowThankYou);
    await p.setBool(_kPrinterShowUpi, _printerShowUpi);
    await p.setBool(_kPrinterShowLogo, _printerShowLogo);
    await p.setString(_kPrinterFooter, _printerFooterCtrl.text);
    await p.setString(_kPrinterUpiId, _printerUpiCtrl.text);
    await p.setBool(RECEIPT_SHOW_THANK_YOU_KEY, _printerShowThankYou);
    await p.setString(RECEIPT_FOOTER_KEY, _printerFooterCtrl.text);
    _snack('Printer receipt settings saved');
  }

  Future<void> _saveKot() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kKotShowTime, _kotShowTime);
    await p.setBool(_kKotShowOrderNo, _kotShowOrderNo);
    await p.setString(_kKotNotes, _kotNotesCtrl.text);
    _snack('KOT settings saved');
  }

  Future<void> _saveWhatsApp() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kWaGreeting, _waGreetingCtrl.text);
    await p.setBool(_kWaShowInvoice, _waShowInvoice);
    await p.setBool(_kWaShowItems, _waShowItems);
    await p.setBool(_kWaShowTotal, _waShowTotal);
    await p.setBool(_kWaShowPayment, _waShowPayment);
    await p.setString(_kWaClosing, _waClosingCtrl.text);
    _snack('WhatsApp template saved');
  }

  Future<void> _resetWhatsApp() async {
    const defaultGreeting =
        'Hi {{customer_name}} 👋, thank you for visiting *{{store_name}}*!';
    const defaultClosing = 'We hope to see you again! 😊';
    setState(() {
      _waGreetingCtrl.text = defaultGreeting;
      _waClosingCtrl.text = defaultClosing;
      _waShowInvoice = true;
      _waShowItems = true;
      _waShowTotal = true;
      _waShowPayment = true;
    });
    final p = await SharedPreferences.getInstance();
    await p.setString(_kWaGreeting, defaultGreeting);
    await p.setString(_kWaClosing, defaultClosing);
    await p.setBool(_kWaShowInvoice, true);
    await p.setBool(_kWaShowItems, true);
    await p.setBool(_kWaShowTotal, true);
    await p.setBool(_kWaShowPayment, true);
    _snack('Template restored to default');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Config'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Printer'),
            Tab(icon: Icon(Icons.kitchen), text: 'KOT'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'WhatsApp'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _printerTab(theme),
                _kotTab(theme),
                _whatsappTab(theme),
              ],
            ),
    );
  }

  // ── TAB 1: Printer ─────────────────────────────────────────────────────────
  Widget _printerTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SettingsSection(
        title: 'Printer Receipt',
        icon: Icons.print_rounded,
        children: [
          _sw(
            'Show Logo',
            Icons.image_outlined,
            _printerShowLogo,
            (v) => setState(() => _printerShowLogo = v),
          ),
          _sw(
            'Show "Thank You" Line',
            Icons.favorite_border,
            _printerShowThankYou,
            (v) => setState(() => _printerShowThankYou = v),
          ),
          _sw(
            'Show UPI QR',
            Icons.qr_code,
            _printerShowUpi,
            (v) => setState(() => _printerShowUpi = v),
          ),
          if (_printerShowUpi) ...[
            const SizedBox(height: 8),
            SettingsTextField(
              controller: _printerUpiCtrl,
              label: 'UPI ID',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
          const SizedBox(height: 12),
          SettingsTextField(
            controller: _printerFooterCtrl,
            label: 'Footer Note',
            icon: Icons.notes,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _saveBtn('Save Printer Config', _savePrinter),
        ],
      ),
    );
  }

  // ── TAB 2: KOT ─────────────────────────────────────────────────────────────
  Widget _kotTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SettingsSection(
        title: 'KOT Slip',
        icon: Icons.kitchen_rounded,
        children: [
          _sw(
            'Show Order No.',
            Icons.tag,
            _kotShowOrderNo,
            (v) => setState(() => _kotShowOrderNo = v),
          ),
          _sw(
            'Show Order Time',
            Icons.access_time_outlined,
            _kotShowTime,
            (v) => setState(() => _kotShowTime = v),
          ),
          const SizedBox(height: 12),
          SettingsTextField(
            controller: _kotNotesCtrl,
            label: 'Kitchen Note (on every KOT)',
            icon: Icons.sticky_note_2_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _saveBtn('Save KOT Config', _saveKot),
        ],
      ),
    );
  }

  // ── TAB 3: WhatsApp ─────────────────────────────────────────────────────────
  Widget _whatsappTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live preview card
          _previewCard(theme),
          const SizedBox(height: 16),

          SettingsSection(
            title: 'Message Blocks',
            icon: Icons.chat_bubble_outline_rounded,
            children: [
              // Block 1: Greeting
              _blockEditor(
                theme,
                icon: Icons.waving_hand_outlined,
                label: '1. Greeting',
                hint: 'Opening line sent to the customer',
                controller: _waGreetingCtrl,
                // chips stored WITHOUT braces — label/insert adds them
                chips: const ['customer_name', 'store_name'],
              ),
              const SizedBox(height: 12),

              // Block 2: toggles for auto-generated lines
              _blockToggle(
                theme,
                Icons.receipt_outlined,
                '2. Invoice No. & Date',
                _waShowInvoice,
                (v) => setState(() => _waShowInvoice = v),
              ),
              _blockToggle(
                theme,
                Icons.shopping_bag_outlined,
                '3. Items List',
                _waShowItems,
                (v) => setState(() => _waShowItems = v),
              ),
              _blockToggle(
                theme,
                Icons.currency_rupee,
                '4. Total Amount',
                _waShowTotal,
                (v) => setState(() => _waShowTotal = v),
              ),
              _blockToggle(
                theme,
                Icons.payment_outlined,
                '5. Payment Mode',
                _waShowPayment,
                (v) => setState(() => _waShowPayment = v),
              ),
              const SizedBox(height: 12),

              // Block 3: Closing
              _blockEditor(
                theme,
                icon: Icons.sentiment_satisfied_alt_outlined,
                label: '6. Closing Line',
                hint: 'Sign-off line at the bottom',
                controller: _waClosingCtrl,
                chips: const [],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _resetWhatsApp,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Restore Default'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  _saveBtn('Save Template', _saveWhatsApp),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard(ThemeData theme) {
    final greeting = _waGreetingCtrl.text.isEmpty
        ? '...'
        : _waGreetingCtrl.text
              .replaceAll('{{customer_name}}', 'Animesh')
              .replaceAll('{{store_name}}', 'Hangout Spot');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF075E54).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble, color: Color(0xFF25D366), size: 16),
              const SizedBox(width: 6),
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF25D366),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(greeting, style: const TextStyle(fontSize: 13)),
          if (_waShowInvoice)
            const Text(
              '🧾 Invoice #1042 · 19 Feb 2026',
              style: TextStyle(fontSize: 12),
            ),
          if (_waShowItems) ...[
            const SizedBox(height: 4),
            const Text(
              '• Masala Chai × 2\n• Sandwich × 1',
              style: TextStyle(fontSize: 12),
            ),
          ],
          if (_waShowTotal)
            const Text('💰 Total: ₹280', style: TextStyle(fontSize: 12)),
          if (_waShowPayment)
            const Text('💳 Paid via UPI', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            _waClosingCtrl.text.isEmpty ? '' : _waClosingCtrl.text,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _blockEditor(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> chips,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final c in chips)
                  GestureDetector(
                    onTap: () {
                      final sel = controller.selection;
                      final text = controller.text;
                      final pos = sel.isValid && sel.baseOffset <= text.length
                          ? sel.baseOffset
                          : text.length;
                      final insert = '{{$c}}';
                      controller.text =
                          text.substring(0, pos) + insert + text.substring(pos);
                      controller.selection = TextSelection.collapsed(
                        offset: pos + insert.length,
                      );
                      setState(() {});
                    },
                    child: Chip(
                      label: Text(
                        '{{$c}}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _blockToggle(
    ThemeData theme,
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: value
            ? theme.colorScheme.primary.withOpacity(0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: value
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              onChanged(v);
              setState(() {});
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _sw(String label, IconData icon, bool value, ValueChanged<bool> cb) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: cb,
      );

  Widget _saveBtn(String label, VoidCallback onPressed) => Align(
    alignment: Alignment.centerRight,
    child: SettingsActionBtn(label: label, onPressed: onPressed),
  );
}
