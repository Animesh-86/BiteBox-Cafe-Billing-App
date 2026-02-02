import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'pdf_service.dart';
import 'package:hangout_spot/ui/screens/settings/settings_screen.dart';

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

  Future<void> shareInvoiceWhatsApp(
    Order order,
    List<OrderItem> items,
    Customer? customer,
  ) async {
    final message = _buildWhatsAppMessage(order, customer);
    final uri = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final fallback = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
      return;
    }

    await shareInvoice(order, items, customer);
  }

  String _buildWhatsAppMessage(Order order, Customer? customer) {
    final name = customer?.name ?? 'Customer';
    return 'Hi $name, thanks for visiting! Your bill is ready.\n'
        'Invoice: ${order.invoiceNumber}\n'
        'Total: ₹${order.totalAmount.toStringAsFixed(2)}';
  }
}

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService(ref.watch(appDatabaseProvider));
});
