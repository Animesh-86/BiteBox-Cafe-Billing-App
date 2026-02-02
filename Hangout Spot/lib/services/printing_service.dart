import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'pdf_service.dart';

class PrintingService {
  final PdfService _pdfService = PdfService();

  Future<void> printInvoice(Order order, List<OrderItem> items, Customer? customer) async {
    final pdfBytes = await _pdfService.generateInvoice(order, items, customer);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice-${order.invoiceNumber}',
    );
  }

  Future<void> printKot(Order order, List<OrderItem> items) async {
    final pdfBytes = await _pdfService.generateInvoice(order, items, null, isKot: true);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'KOT-${order.invoiceNumber}',
    );
  }
}

final printingServiceProvider = Provider<PrintingService>((ref) => PrintingService());
