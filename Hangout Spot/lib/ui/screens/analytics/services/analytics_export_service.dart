import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:intl/intl.dart';

class AnalyticsExportService {
  static Future<void> exportToExcel(
    AnalyticsData data, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Check if there's any data to export
    if (data.totalOrders == 0 &&
        data.totalSales == 0 &&
        data.totalItemsSold == 0) {
      throw Exception(
        'No data available for the selected period. Please ensure you have orders with status = "completed" in this date range.',
      );
    }

    var excel = Excel.createExcel();

    // Remove default sheet
    excel.delete('Sheet1');

    // Create Overview sheet
    _createOverviewSheet(excel, data, startDate, endDate);

    // Create Daily Sales sheet
    _createDailySalesSheet(excel, data);

    // Create Category Performance sheet
    _createCategoryPerformanceSheet(excel, data);

    // Create Payment Methods sheet
    _createPaymentMethodsSheet(excel, data);

    // Create Top Items sheet
    _createTopItemsSheet(excel, data);

    // Create Customer Analysis sheet
    _createCustomerAnalysisSheet(excel, data);

    // Save and share
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final filePath = '${directory.path}/Analytics_Export_$dateStr.xlsx';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject:
            'Analytics Export - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
      );
    }
  }

  static void _createOverviewSheet(
    Excel excel,
    AnalyticsData data,
    DateTime start,
    DateTime end,
  ) {
    var sheet = excel['Overview'];

    // Header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Analytics Overview',
    );
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
      'Period: ${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}',
    );

    // Metrics
    int row = 4;
    _addRow(sheet, row++, ['Metric', 'Value', 'Change (%)']);
    _addRow(sheet, row++, [
      'Total Sales',
      '₹${data.totalSales.toStringAsFixed(2)}',
      data.salesChange.toStringAsFixed(1),
    ]);
    _addRow(sheet, row++, [
      'Total Orders',
      data.totalOrders.toString(),
      data.ordersChange.toStringAsFixed(1),
    ]);
    _addRow(sheet, row++, [
      'Items Sold',
      data.totalItemsSold.toString(),
      data.itemsSoldChange.toStringAsFixed(1),
    ]);
    _addRow(sheet, row++, [
      'Customers',
      data.totalCustomers.toString(),
      data.customersChange.toStringAsFixed(1),
    ]);
    _addRow(sheet, row++, [
      'Average Order Value',
      '₹${data.averageOrderValue.toStringAsFixed(2)}',
      data.aovChange.toStringAsFixed(1),
    ]);
    _addRow(sheet, row++, ['New Customers', data.newCustomers.toString(), '']);
    _addRow(sheet, row++, [
      'Returning Customers',
      data.returningCustomers.toString(),
      '',
    ]);
    _addRow(sheet, row++, ['Walk-in Guests', data.walkInGuests.toString(), '']);
    _addRow(sheet, row++, [
      'Total Discounts Given',
      '₹${data.discountsGiven.toStringAsFixed(2)}',
      '',
    ]);
    _addRow(sheet, row++, [
      'Discounted Orders',
      data.discountedOrdersCount.toString(),
      '',
    ]);
  }

  static void _createDailySalesSheet(Excel excel, AnalyticsData data) {
    var sheet = excel['Daily Sales'];

    // Header
    _addRow(sheet, 0, ['Date', 'Sales Amount']);

    // Data
    int row = 1;
    for (var item in data.dailySales) {
      _addRow(sheet, row++, [
        DateFormat('MMM dd, yyyy').format(item.date),
        item.amount.toStringAsFixed(2),
      ]);
    }
  }

  static void _createCategoryPerformanceSheet(Excel excel, AnalyticsData data) {
    var sheet = excel['Category Performance'];

    // Header
    _addRow(sheet, 0, ['Category', 'Quantity Sold', 'Revenue']);

    // Data
    int row = 1;
    for (var item in data.categoryPerformance) {
      _addRow(sheet, row++, [
        item.category,
        item.quantity.toString(),
        item.revenue.toStringAsFixed(2),
      ]);
    }
  }

  static void _createPaymentMethodsSheet(Excel excel, AnalyticsData data) {
    var sheet = excel['Payment Methods'];

    // Header
    _addRow(sheet, 0, ['Payment Method', 'Count', 'Amount']);

    // Data
    int row = 1;
    if (data.paymentMethodDistribution != null) {
      for (var method in data.paymentMethodDistribution!) {
        _addRow(sheet, row++, [
          (method['method'] ?? 'Unknown').toString(),
          (method['count'] ?? 0).toString(),
          (method['amount'] ?? 0.0).toString(),
        ]);
      }
    }
  }

  static void _createTopItemsSheet(Excel excel, AnalyticsData data) {
    var sheet = excel['Top Items'];

    // Header
    _addRow(sheet, 0, ['Rank', 'Item Name', 'Quantity Sold']);

    // Data
    int row = 1;
    int rank = 1;
    for (var item in data.itemShare) {
      _addRow(sheet, row++, [
        rank.toString(),
        item.itemName,
        item.quantity.toString(),
      ]);
      rank++;
    }
  }

  static void _createCustomerAnalysisSheet(Excel excel, AnalyticsData data) {
    var sheet = excel['Customer Analysis'];

    // Customer Frequency Segments
    _addRow(sheet, 0, ['Customer Frequency Segments']);
    _addRow(sheet, 1, ['Segment', 'Count']);

    int segmentRow = 2;
    if (data.customerFrequencySegments != null) {
      for (var segment in data.customerFrequencySegments!) {
        _addRow(sheet, segmentRow++, [
          (segment['segment'] ?? 'Unknown').toString(),
          (segment['count'] ?? 0).toString(),
        ]);
      }
    }

    // Discount Effectiveness
    int discountRow = segmentRow + 1;
    _addRow(sheet, discountRow, ['Discount Effectiveness']);
    _addRow(sheet, discountRow + 1, ['Metric', 'Value']);
    _addRow(sheet, discountRow + 2, [
      'Orders with Discount',
      data.discountEffectiveness.ordersWithDiscount.toString(),
    ]);
    _addRow(sheet, discountRow + 3, [
      'Revenue with Discount',
      data.discountEffectiveness.revenueWithDiscount.toStringAsFixed(2),
    ]);
    _addRow(sheet, discountRow + 4, [
      'Orders without Discount',
      data.discountEffectiveness.ordersWithoutDiscount.toString(),
    ]);
    _addRow(sheet, discountRow + 5, [
      'Revenue without Discount',
      data.discountEffectiveness.revenueWithoutDiscount.toStringAsFixed(2),
    ]);
    _addRow(sheet, discountRow + 6, [
      'Total Discount Amount',
      data.discountEffectiveness.totalDiscountAmount.toStringAsFixed(2),
    ]);

    // At-Risk Customers
    if (data.atRiskCustomers.isNotEmpty) {
      _addRow(sheet, 15, ['At-Risk Customers']);
      _addRow(sheet, 16, ['Customer Name', 'Last Visit']);
      int row = 17;
      for (var customer in data.atRiskCustomers) {
        _addRow(sheet, row++, [
          customer.name,
          DateFormat('MMM dd, yyyy').format(customer.lastVisit),
        ]);
      }
    }
  }

  static void _addRow(Sheet sheet, int rowIndex, List<dynamic> values) {
    for (int i = 0; i < values.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(values[i].toString());
    }
  }
}
