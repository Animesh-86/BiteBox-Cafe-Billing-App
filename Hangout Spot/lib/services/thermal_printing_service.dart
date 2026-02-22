import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

class ThermalPrintingService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  ThermalPrintingService();

  Future<bool> get isConnected =>
      _bluetooth.isConnected.then((v) => v ?? false);

  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      return [];
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    if (await isConnected) {
      await _bluetooth.disconnect();
    }
    await _bluetooth.connect(device);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_mac', device.address ?? '');
  }

  Future<void> disconnect() async {
    await _bluetooth.disconnect();
  }

  Future<void> printBill(
    Order order,
    List<OrderItem> items,
    Customer? customer, {
    String? storeName,
    String? storeAddress,
    String? footerMessage,
    double? customerRewardBalance,
  }) async {
    try {
      debugPrint(
        "[printBill] Starting bill print for order ${order.invoiceNumber}",
      );

      if (!await isConnected) {
        debugPrint("[printBill] Not connected, attempting auto-connect...");
        // Try to auto-connect if saved
        final prefs = await SharedPreferences.getInstance();
        final savedMac = prefs.getString('selected_printer_mac');
        debugPrint("[printBill] Saved printer MAC: $savedMac");

        if (savedMac != null) {
          final devices = await getBondedDevices();
          debugPrint("[printBill] Found ${devices.length} bonded devices");

          if (devices.isEmpty) {
            debugPrint("[printBill] No bonded devices found!");
            throw Exception('No Bluetooth devices found');
          }

          final device = devices.firstWhere(
            (d) => d.address == savedMac,
            orElse: () => devices.first,
          );
          debugPrint("[printBill] Connecting to device: ${device.address}");

          // ignore: unnecessary_null_comparison
          if (device != null) {
            try {
              await _bluetooth.connect(device);
              debugPrint("[printBill] Connected successfully");
            } catch (e) {
              debugPrint("[printBill] Connection failed: $e");
              rethrow;
            }
          }
        }
      }

      if (!await isConnected) {
        throw Exception(
          'Bluetooth printer not connected. Please connect printer in Settings.',
        );
      }

      debugPrint("[printBill] Loading capability profile...");
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.reset();

      // Logo
      try {
        debugPrint("[printBill] Loading logo...");
        final ByteData data = await rootBundle.load('assets/logo.png');
        final Uint8List imgBytes = data.buffer.asUint8List();
        final img.Image? image = img.decodeImage(imgBytes);
        if (image != null) {
          // Resize if needed, thermal printers usually 384 dots width
          final resized = img.copyResize(image, width: 150);
          bytes += generator.image(resized);
          bytes += generator.feed(1);
          debugPrint("[printBill] Logo added");
        }
      } catch (e) {
        // Logo failed, skip
        debugPrint("[printBill] Logo load failed (skipping): $e");
      }

      bytes += generator.text(
        storeName ?? 'HANGOUT SPOT',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );
      if (storeAddress != null) {
        bytes += generator.text(
          storeAddress,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      bytes += generator.feed(1);

      // Bill Details
      bytes += generator.text(
        'Bill No: ${order.invoiceNumber}',
        styles: const PosStyles(bold: true),
      );
      final date = DateFormat('dd/MM/yy hh:mm a').format(order.createdAt);
      bytes += generator.text('Date: $date');
      if (customer != null) {
        bytes += generator.text('Customer: ${customer.name}');
      } else {
        bytes += generator.text('Bill To: Walk In');
      }

      bytes += generator.hr();

      // Items Header
      bytes += generator.row([
        PosColumn(text: 'ITEM', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'QTY',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'RATE',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'TOTAL',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr();

      // Items - Print full names with wrapping
      for (var item in items) {
        // Print full item name (allows natural wrapping)
        bytes += generator.text(
          item.itemName,
          styles: const PosStyles(bold: true),
        );

        // Format: Qty: X  Rate: Rs.Price  Total: Rs.Total
        final detailsLine =
            'Qty: ${item.quantity}  Rate: Rs.${item.price.toStringAsFixed(0)}  Total: Rs.${(item.price * item.quantity).toStringAsFixed(0)}';
        bytes += generator.text(
          detailsLine,
          styles: const PosStyles(
            align: PosAlign.right,
            fontType: PosFontType.fontB,
          ),
        );

        // Print discount if any
        if (item.discountAmount > 0) {
          bytes += generator.text(
            'Discount: Rs.${item.discountAmount.toStringAsFixed(0)}',
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              align: PosAlign.right,
            ),
          );
        }
        bytes += generator.feed(1); // Space between items
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.row([
        PosColumn(text: 'Total Qty:', width: 6),
        PosColumn(
          text: items
              .fold<int>(0, (sum, item) => sum + item.quantity)
              .toString(),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Sub Total:', width: 6),
        PosColumn(
          text: 'Rs.${order.subtotal.toStringAsFixed(0)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      if (order.discountAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Order Discount:', width: 6),
          PosColumn(
            text: 'Rs.${order.discountAmount.toStringAsFixed(0)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      if (order.taxAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Tax GST:', width: 6),
          PosColumn(
            text: 'Rs.${order.taxAmount.toStringAsFixed(0)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      // Show loyalty points if customer is selected
      if (customer != null &&
          customerRewardBalance != null &&
          customerRewardBalance > 0) {
        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: 'Loyalty Points:', width: 6),
          PosColumn(
            text: customerRewardBalance.toStringAsFixed(0),
            width: 6,
            styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size2,
            ),
          ),
        ]);
      }

      bytes += generator.text(
        'Grand Total: Rs.${order.totalAmount.toStringAsFixed(0)}',
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
          align: PosAlign.center,
        ),
      );

      bytes += generator.hr();

      // Payment Mode
      bytes += generator.text(
        'Mode: ${order.paymentMode}',
        styles: const PosStyles(align: PosAlign.center),
      );

      if (footerMessage != null) {
        bytes += generator.feed(1);
        bytes += generator.text(
          footerMessage,
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.feed(1);
      bytes += generator.text(
        'Thank You! Visit Again!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Powered by BiteBox',
        styles: const PosStyles(
          align: PosAlign.center,
          fontType: PosFontType.fontB,
        ),
      );

      bytes += generator.feed(2);
      bytes += generator.cut();

      debugPrint("[printBill] Sending ${bytes.length} bytes to printer...");
      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      debugPrint("[printBill] Print completed successfully!");
    } catch (e) {
      debugPrint("[printBill] ERROR: $e");
      rethrow;
    }
  }

  Future<void> printKot(
    Order order,
    List<OrderItem> items, {
    String? storeName,
    String? storeAddress,
  }) async {
    if (!await isConnected) {
      // Try to auto-connect if saved
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString('selected_printer_mac');
      if (savedMac != null) {
        final devices = await getBondedDevices();
        try {
          final device = devices.firstWhere((d) => d.address == savedMac);
          await _bluetooth.connect(device);
        } catch (e) {
          // ignore
        }
      }
    }
    if (!await isConnected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // RESET PRINTER START
    bytes += generator.reset();

    // Header
    bytes += generator.text(
      'KOT',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      'Order #${order.invoiceNumber}',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    final date = DateFormat('dd/MM/yy hh:mm a').format(order.createdAt);
    bytes += generator.text(
      'Date: $date',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr();

    // Items
    for (var item in items) {
      // Print full item name (allows wrapping for long names)
      bytes += generator.text(
        item.itemName,
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );

      // Print quantity
      bytes += generator.text(
        'Qty: ${item.quantity}',
        styles: const PosStyles(height: PosTextSize.size2, bold: true),
      );

      if (item.note != null && item.note!.isNotEmpty) {
        bytes += generator.text(
          'Note: ${item.note}',
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
      bytes += generator.hr();
    }

    bytes += generator.feed(3); // Feed more lines before cut
    bytes += generator.cut();

    await _bluetooth.writeBytes(Uint8List.fromList(bytes));
  }
}

final thermalPrintingServiceProvider = Provider<ThermalPrintingService>((ref) {
  return ThermalPrintingService();
});
