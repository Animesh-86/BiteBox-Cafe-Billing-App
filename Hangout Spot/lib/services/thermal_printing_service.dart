import 'package:hangout_spot/utils/log_utils.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

class ThermalPrintingService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  // Cached to avoid re-parsing on every print
  CapabilityProfile? _cachedProfile;
  img.Image? _cachedLogo;
  bool _logoLoadAttempted = false;

  ThermalPrintingService();

  /// Word-wrap text so lines break at word boundaries, not mid-word.
  /// [maxCols] is the number of characters per line for the current font/size.
  List<String> _wordWrap(String text, int maxCols) {
    if (text.length <= maxCols) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';
    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine.length + 1 + word.length) <= maxCols) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);
    return lines;
  }

  /// Write complete payload in one shot — much faster than small chunks.
  Future<void> _writeBytes(Uint8List data) async {
    await _bluetooth.writeBytes(data);
  }

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

  /// Ensure Bluetooth is connected; auto-reconnect to saved printer if not.
  /// Returns true if connected after the check.
  Future<bool> _ensureConnected() async {
    if (await isConnected) return true;
    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString('selected_printer_mac');
    if (savedMac == null) return false;
    final devices = await getBondedDevices();
    try {
      final device = devices.firstWhere((d) => d.address == savedMac);
      await _bluetooth
          .connect(device)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () =>
                logDebug("[_ensureConnected] Connection timed out"),
          );
      return await isConnected;
    } catch (_) {
      return false;
    }
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
      logDebug(
        "[printBill] Starting bill print for order ${order.invoiceNumber}",
      );

      if (!await _ensureConnected()) {
        logDebug("[printBill] Not connected, skipping print");
        return;
      }

      logDebug("[printBill] Loading capability profile...");
      _cachedProfile ??= await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, _cachedProfile!);
      List<int> bytes = [];

      // Header
      bytes += generator.reset();

      // Logo (cached after first load)
      if (!_logoLoadAttempted) {
        _logoLoadAttempted = true;
        try {
          logDebug("[printBill] Loading logo...");
          final ByteData data = await rootBundle.load('assets/logo.png');
          final Uint8List imgBytes = data.buffer.asUint8List();
          final decoded = img.decodeImage(imgBytes);
          if (decoded != null) {
            _cachedLogo = img.copyResize(decoded, width: 150);
          }
        } catch (e) {
          logDebug("[printBill] Logo load failed (skipping): $e");
        }
      }
      if (_cachedLogo != null) {
        bytes += generator.image(_cachedLogo!);
        bytes += generator.feed(1);
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
        PosColumn(text: 'ITEM', width: 5, styles: const PosStyles(bold: true)),
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
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr();

      // Items - print with word-wrap (no mid-word breaks)
      for (var item in items) {
        final itemTotal =
            (item.price * item.quantity) -
            (item.discountAmount * item.quantity);

        // Word-wrap item name at word boundaries (32 chars/line for normal font on 58mm)
        for (final line in _wordWrap(item.itemName, 32)) {
          bytes += generator.text(line, styles: const PosStyles(bold: true));
        }

        // Print qty, rate, total in a row
        bytes += generator.row([
          PosColumn(text: 'Qty: ${item.quantity}', width: 4),
          PosColumn(
            text: 'Rs.${item.price.toStringAsFixed(0)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: 'Rs.${itemTotal.toStringAsFixed(0)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);

        // Print discount if any
        if (item.discountAmount > 0) {
          // Calculate discount percentage from amount and price
          final discountPercent = item.price > 0
              ? (item.discountAmount / item.price * 100)
              : 0.0;
          bytes += generator.text(
            '  Discount (${discountPercent.toStringAsFixed(0)}%): -Rs.${(item.discountAmount * item.quantity).toStringAsFixed(0)}',
            styles: const PosStyles(align: PosAlign.left),
          );
        }
        bytes += generator.feed(1);
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
        // Calculate order discount percentage
        final orderDiscountPercent = order.subtotal > 0
            ? (order.discountAmount / order.subtotal * 100)
            : 0.0;
        bytes += generator.row([
          PosColumn(
            text: 'Discount (${orderDiscountPercent.toStringAsFixed(0)}%):',
            width: 6,
          ),
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

      // Grand Total — use size1 height + size2 width to fit on one line
      bytes += generator.text(
        'Total: Rs.${order.totalAmount.toStringAsFixed(0)}',
        styles: const PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
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

      bytes += generator.feed(1);
      bytes += generator.cut();

      logDebug("[printBill] Sending ${bytes.length} bytes to printer...");
      await _writeBytes(Uint8List.fromList(bytes));
      logDebug("[printBill] Print completed successfully!");
    } catch (e) {
      logDebug("[printBill] ERROR: $e");
      rethrow;
    }
  }

  Future<void> printKot(
    Order order,
    List<OrderItem> items, {
    String? storeName,
    String? storeAddress,
    Map<String, String>? itemCategories,
  }) async {
    if (!await _ensureConnected()) return;

    _cachedProfile ??= await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, _cachedProfile!);
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
      'Order ${order.invoiceNumber}',
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
      // Print category name above item if available
      final category = itemCategories?[item.itemId];
      if (category != null && category.isNotEmpty) {
        bytes += generator.text('[$category]');
      }
      bytes += generator.text(item.itemName);
      bytes += generator.text('Qty: ${item.quantity}');
      if (item.note != null && item.note!.isNotEmpty) {
        bytes += generator.text('Note: ${item.note}');
      }
      bytes += generator.hr();
    }

    bytes += generator.feed(2); // Feed before cut for KOT
    bytes += generator.cut();

    await _writeBytes(Uint8List.fromList(bytes));
  }
}

final thermalPrintingServiceProvider = Provider<ThermalPrintingService>((ref) {
  return ThermalPrintingService();
});
