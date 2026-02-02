import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';

class PdfService {
  Future<Uint8List> generateInvoice(
    Order order,
    List<OrderItem> items,
    Customer? customer, {
    bool isKot = false,
    String? storeName,
    String? storeAddress,
    String? footerNote,
    bool showThankYou = true,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Thermal printer width usually 80mm
        margin: const pw.EdgeInsets.all(10), // Small margins
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  storeName ?? 'Hangout Spot',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (storeAddress != null && storeAddress!.trim().isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    storeAddress!,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              pw.Divider(),
              if (isKot)
                pw.Center(
                  child: pw.Text(
                    "KITCHEN TICKET",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

              pw.Text("Inv: ${order.invoiceNumber}"),
              pw.Text("Date: ${dateFormat.format(order.createdAt)}"),
              if (customer != null && !isKot) pw.Text("Cust: ${customer.name}"),

              pw.SizedBox(height: 10),

              if (isKot)
                ...items.map((i) => _buildKotItem(i))
              else
                ...items.map((i) => _buildBillItem(i)),

              if (!isKot) ...[
                pw.Divider(),
                _buildRow("Subtotal", order.subtotal),
                if (order.discountAmount > 0)
                  _buildRow("Discount", -order.discountAmount),
                _buildRow("Tax", order.taxAmount),
                pw.Divider(),
                _buildRow(
                  "Total",
                  order.totalAmount,
                  isBold: true,
                  fontSize: 16,
                ),
                pw.SizedBox(height: 10),
                if (showThankYou)
                  pw.Center(child: pw.Text("Thank You! Visit Again!")),
                if (footerNote != null && footerNote!.trim().isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      footerNote!,
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.Center(
                  child: pw.Text(
                    "Developed by Animesh Sharma",
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildBillItem(OrderItem item) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text("${item.quantity} x ${item.itemName}")),
          pw.Text(item.price.toStringAsFixed(2)),
        ],
      ),
    );
  }

  pw.Widget _buildKotItem(OrderItem item) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "${item.quantity} x ${item.itemName}",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          if (item.note != null && item.note!.isNotEmpty)
            pw.Text(
              "Note: ${item.note}",
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildRow(
    String label,
    double value, {
    bool isBold = false,
    double fontSize = 12,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        pw.Text(
          value.toStringAsFixed(2),
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
