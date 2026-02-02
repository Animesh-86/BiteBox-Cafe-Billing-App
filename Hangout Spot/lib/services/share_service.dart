import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'pdf_service.dart';

class ShareService {
  final PdfService _pdfService = PdfService();

  Future<void> shareInvoice(Order order, List<OrderItem> items, Customer? customer) async {
    final pdfBytes = await _pdfService.generateInvoice(order, items, customer);
    
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Invoice-${order.invoiceNumber}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Invoice ${order.invoiceNumber} from Hangout Spot',
    );
  }
}

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());
