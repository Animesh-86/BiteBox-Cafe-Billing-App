import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import '../utils/constants/app_keys.dart';
import 'pdf_service.dart';

class ShareService {
  final PdfService _pdfService = PdfService();
  final AppDatabase _db;

  ShareService(this._db);

  Future<void> shareInvoice(
    Order order,
    List<OrderItem> items,
    Customer? customer,
  ) async {
    final settings =
        await (_db.select(_db.settings)..where(
              (tbl) => tbl.key.isIn([
                STORE_NAME_KEY,
                STORE_ADDRESS_KEY,
                STORE_LOGO_URL_KEY,
                RECEIPT_FOOTER_KEY,
                RECEIPT_SHOW_THANK_YOU_KEY,
              ]),
            ))
            .get();
    final map = {for (final s in settings) s.key: s.value};

    final pdfBytes = await _pdfService.generateInvoice(
      order,
      items,
      customer,
      storeName: map[STORE_NAME_KEY],
      storeAddress: map[STORE_ADDRESS_KEY],
      footerNote: map[RECEIPT_FOOTER_KEY],
      showThankYou: (map[RECEIPT_SHOW_THANK_YOU_KEY] ?? 'true') == 'true',
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Invoice-${order.invoiceNumber}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Invoice ${order.invoiceNumber} from Hangout Spot');
  }

  Future<String> _buildWhatsAppMessage(
    Order order,
    List<OrderItem> items,
    Customer? customer,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Get store name from database
    final storeSettings = await (_db.select(
      _db.settings,
    )..where((tbl) => tbl.key.equals(STORE_NAME_KEY))).get();
    final storeName = storeSettings.isNotEmpty
        ? storeSettings.first.value
        : 'Hangout Spot';

    // Read WhatsApp template settings
    final greeting =
        prefs.getString('wa_greeting') ??
        'Hi {{customer_name}} 👋, thank you for visiting *{{store_name}}*!';
    final showInvoice = prefs.getBool('wa_show_invoice') ?? true;
    final showItems = prefs.getBool('wa_show_items') ?? true;
    final showTotal = prefs.getBool('wa_show_total') ?? true;
    final showPayment = prefs.getBool('wa_show_payment') ?? true;
    final closing =
        prefs.getString('wa_closing') ?? 'We hope to see you again! 😊';

    final customerName = customer?.name ?? 'Customer';
    final buffer = StringBuffer();

    // 1. Greeting with placeholders replaced
    buffer.writeln(
      greeting
          .replaceAll('{{customer_name}}', customerName)
          .replaceAll('{{store_name}}', storeName),
    );
    buffer.writeln();

    // 2. Invoice No. & Date
    if (showInvoice) {
      final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
      buffer.writeln('📋 *Invoice:* ${order.invoiceNumber}');
      buffer.writeln('📅 *Date:* ${dateFormat.format(order.createdAt)}');
      buffer.writeln();
    }

    // 3. Items List
    if (showItems && items.isNotEmpty) {
      buffer.writeln('🛍️ *Items:*');
      for (final item in items) {
        final price = item.price * item.quantity;
        buffer.writeln(
          '  • ${item.quantity}x ${item.itemName} - ₹${price.toStringAsFixed(2)}',
        );
      }
      buffer.writeln();
    }

    // 4. Total Amount
    if (showTotal) {
      buffer.writeln(
        '💰 *Total Amount:* ₹${order.totalAmount.toStringAsFixed(2)}',
      );
      buffer.writeln();
    }

    // 5. Payment Mode
    if (showPayment) {
      final paymentMode = order.paymentMode ?? 'Cash';
      buffer.writeln('💳 *Payment:* $paymentMode');
      buffer.writeln();
    }

    // 6. Closing line
    buffer.write(closing);

    return buffer.toString();
  }

  Future<void> shareInvoiceWhatsApp(
    Order order,
    List<OrderItem> items,
    Customer? customer,
  ) async {
    final message = await _buildWhatsAppMessage(order, items, customer);

    // Use customer phone if available
    String url = "whatsapp://send?text=${Uri.encodeComponent(message)}";

    if (customer != null && (customer.phone?.isNotEmpty ?? false)) {
      // Sanitize phone (remove + if needed, app expects 10 digits usually or full with country code)
      // Assuming country code 91 if internal, but better to keep as is if user enters it
      String phone = customer.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      // If length is 10, prepend 91 for India (common assumption) or just use as is
      if (phone.length == 10) phone = "91$phone";

      url = "whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}";
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback web url
    if (customer != null && (customer.phone?.isNotEmpty ?? false)) {
      String phone = customer.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.length == 10) phone = "91$phone";
      final fallback = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
        return;
      }
    } else {
      final fallback = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
        return;
      }
    }

    await shareInvoice(order, items, customer);
  }

  Future<void> openWhatsAppChat(String phone, {String? text}) async {
    if (phone.isEmpty) return;

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) cleanPhone = "91$cleanPhone";

    final message = text != null ? "&text=${Uri.encodeComponent(text)}" : "";
    final url = "whatsapp://send?phone=$cleanPhone$message";
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final fallback = Uri.parse("https://wa.me/$cleanPhone$message");
    if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }
}

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService(ref.watch(appDatabaseProvider));
});
