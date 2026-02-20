import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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

  String _buildWhatsAppMessage(Order order, Customer? customer) {
    final name = customer?.name ?? 'Customer';
    return 'Hi $name, thanks for visiting! Your bill is ready.\n'
        'Invoice: ${order.invoiceNumber}\n'
        'Total: ₹${order.totalAmount.toStringAsFixed(2)}';
  }

  Future<void> shareInvoiceWhatsApp(
    Order order,
    List<OrderItem> items,
    Customer? customer,
  ) async {
    final message = _buildWhatsAppMessage(order, customer);

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
