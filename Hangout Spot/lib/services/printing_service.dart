import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/settings/settings_screen.dart';
import 'pdf_service.dart';
import '../utils/constants/app_keys.dart';

class PrintingService {
  final PdfService _pdfService = PdfService();
  final AppDatabase _db;

  PrintingService(this._db);

  Future<void> printInvoice(
    Order order,
    List<OrderItem> items,
    Customer? customer,
  ) async {
    final settings =
        await (_db.select(_db.settings)..where(
              (tbl) => tbl.key.isIn([
                STORE_NAME_KEY,
                STORE_ADDRESS_KEY,
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
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice-${order.invoiceNumber}',
    );
  }

  Future<void> printKot(Order order, List<OrderItem> items) async {
    final settings = await (_db.select(
      _db.settings,
    )..where((tbl) => tbl.key.isIn([STORE_NAME_KEY, STORE_ADDRESS_KEY]))).get();
    final map = {for (final s in settings) s.key: s.value};

    final pdfBytes = await _pdfService.generateInvoice(
      order,
      items,
      null,
      isKot: true,
      storeName: map[STORE_NAME_KEY],
      storeAddress: map[STORE_ADDRESS_KEY],
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'KOT-${order.invoiceNumber}',
    );
  }
}

final printingServiceProvider = Provider<PrintingService>((ref) {
  return PrintingService(ref.watch(appDatabaseProvider));
});
