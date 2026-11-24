import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windows_printer/windows_printer.dart';

import 'package:test_bill/core/utils/portion_helper.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/models/table_model.dart';

/// Thrown when a print job can't be sent (no printer, driver error, etc.)
class PrintException implements Exception {
  final String message;
  PrintException(this.message);
  @override
  String toString() => message;
}

/// Handles everything printer-related: discovering Windows printers,
/// remembering which one to use, and turning a [Bill] into an ESC/POS
/// receipt for a Bluetooth/USB thermal printer.
class PrintService {
  PrintService._internal();
  static final PrintService instance = PrintService._internal();
  factory PrintService() => instance;

  final GetStorage _box = GetStorage();
  static const _printerKey = 'selected_printer';

  // ── Shop details shown on every receipt — configured in Settings ───────
  String get shopName => (_box.read<String>('shop_name') ?? '').trim();
  String get shopAddress => (_box.read<String>('shop_address') ?? '').trim();
  String get shopPhone => (_box.read<String>('shop_phone') ?? '').trim();
  String get footerLine => _box.read<String>('footer_note') ?? 'Thank you, visit again!';

  // ── Rounds a price for display — 29.99 -> 30 ──
  String _money(double amount) => amount.round().toString();

  // ── Printer selection ──────────────────────────────────────────────
  Future<List<String>> getAvailablePrinters() async {
    if (!GetPlatform.isWindows) {
      return [];
    }
    try {
      return await WindowsPrinter.getAvailablePrinters();
    } catch (_) {
      return [];
    }
  }

  String? get savedPrinter => _box.read<String>(_printerKey);

  Future<void> savePrinter(String printerName) =>
      _box.write(_printerKey, printerName);

  /// Picks which printer to send jobs to. Returns the saved printer instantly if available
  /// to avoid slow Windows Print Spooler (EnumPrinters) RPC delays. Passes forceRefresh=true
  /// to re-scan system printers.
  Future<String?> resolvePrinter({bool forceRefresh = false}) async {
    final saved = savedPrinter;
    if (!forceRefresh && saved != null && saved.isNotEmpty) {
      return saved;
    }
    final printers = await getAvailablePrinters();
    if (printers.isEmpty) return saved;
    if (saved != null && saved.isNotEmpty && printers.contains(saved)) {
      return saved;
    }
    if (printers.isNotEmpty) {
      final selected = printers.first;
      await savePrinter(selected);
      return selected;
    }
    return null;
  }

  // ── Printing ─────────────────────────────────────────────────────────
  /// Builds a receipt for [bill] and sends it to the thermal printer.
  /// Pass [printerName] to force a specific printer; otherwise the saved /
  /// default one is used. Throws [PrintException] on failure.
  Future<void> printBill(Bill bill, {String? printerName}) async {
    if (!GetPlatform.isWindows) {
      debugPrint("Direct thermal printing is only supported on Windows.");
      return;
    }
    var target = printerName ?? await resolvePrinter();
    if (target == null || target.isEmpty) {
      throw PrintException(
        'No printer found. Make sure your thermal printer is connected and selected in Settings.',
      );
    }

    final bytes = _buildReceiptBytes(bill);

    try {
      await WindowsPrinter.printRawData(
        printerName: target,
        data: bytes,
        useRawDatatype: true, // required for thermal/ESC-POS printers
      );
    } catch (e) {
      // If printing failed with cached printer, try resolving fresh from Windows once
      if (printerName == null) {
        final freshTarget = await resolvePrinter(forceRefresh: true);
        if (freshTarget != null && freshTarget != target) {
          try {
            await WindowsPrinter.printRawData(
              printerName: freshTarget,
              data: bytes,
              useRawDatatype: true,
            );
            return;
          } catch (_) {}
        }
      }
      throw PrintException('Could not print bill ${bill.billNumber}: $e');
    }
  }

  Uint8List _buildReceiptBytes(Bill bill) {
    const centerBold = WPTextStyle(align: WPTextAlign.center, bold: true);
    const center = WPTextStyle(align: WPTextAlign.center);
    const centerItalic = WPTextStyle(align: WPTextAlign.center, italic: true);
    const totalStyle = WPTextStyle(
      bold: false,
      align: WPTextAlign.center,
      size: WPTextSize.doubleHeight,
    );

    final builder = WPReceiptBuilder(wpPaperSize: WPPaperSize.mm80);

    if (shopName.isNotEmpty) {
      builder.header(shopName);
    }
    if (shopAddress.isNotEmpty) {
      builder.line(shopAddress, style: center);
    }
    if (shopPhone.isNotEmpty) {
      builder.line('Ph: $shopPhone', style: center);
    }
    builder.separator();

    builder.line('Bill #${bill.billNumber}', style: centerBold);
    builder.line(_formatDate(bill.createdAt), style: center);
    builder.separator();

    if (bill.tableId != null && bill.tableId!.isNotEmpty) {
      builder.item('Table', bill.tableId!);
    }
    if (bill.waiter != null && bill.waiter!.isNotEmpty) {
      builder.item('Waiter', bill.waiter!);
    }
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      builder.item('Customer', bill.customerName!);
    }
    builder.separator();

    builder.line('ITEMS', style: centerBold);
    for (final item in bill.items) {
      final isPortion = PortionHelper.isPortionItemByName(item.name);
      final qtyLabel = PortionHelper.formatQtyForItem(
        item.name,
        item.qty,
        forcePortion: isPortion,
      );
      final label = isPortion
          ? '${item.name} ($qtyLabel)'
          : '${item.name} x$qtyLabel';
      builder.item(label, _money(item.total));
    }

    builder.separator();
    builder.item('Subtotal', _money(bill.subtotal));

    if (bill.discount > 0) {
      builder.item('Discount', '-${_money(bill.discount)}');
    }

    final noTaxTotal = bill.subtotal - bill.discount;

    builder.separator();
    builder.line('TOTAL: ${_money(noTaxTotal)}', style: totalStyle);
    builder.item('Payment', bill.paymentMethod);
    builder.separator();
    builder.line(footerLine, style: centerBold);
    builder.line('Please visit again', style: centerItalic);
    _cutPaper(builder);

    return Uint8List.fromList(builder.build());
  }

  /// Single cut helper — feeds ~5cm of paper before cut command (GS V 1)
  /// so both Bill and KOT receipts have an extra 5cm height.
  void _cutPaper(WPReceiptBuilder builder) {
    builder.blank(6);
    builder.raw([0x1D, 0x56, 0x01]);
  }

  /// Sends bill to printer twice: normal customer copy + kitchen copy (no prices).
  Future<void> printBillWithKOT(Bill bill, {String? printerName}) async {
    final target = printerName ?? await resolvePrinter();
    await printBill(bill, printerName: target);
    await printKitchenBill(bill, printerName: target);
  }

  /// Print Kitchen Order Ticket (KOT) directly from table order items
  Future<void> printKOT({
    required String tableId,
    required String waiter,
    required List<OrderItem> items,
    String? printerName,
  }) async {
    final subtotal = items.fold(0.0, (s, i) => s + i.total);
    final kotBill = Bill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      billNumber: 'KOT-$tableId-${DateTime.now().minute}${DateTime.now().second}',
      source: 'table',
      tableId: tableId,
      waiter: waiter,
      items: items.map((i) => BillItem(name: i.name, qty: i.qty, rate: i.rate, total: i.total)).toList(),
      subtotal: subtotal,
      taxRate: 0.0,
      taxAmount: 0.0,
      discount: 0.0,
      grandTotal: subtotal,
      paymentMethod: 'KOT',
      status: BillStatus.pending,
      createdAt: DateTime.now(),
    );
    await printKitchenBill(kotBill, printerName: printerName);
  }

  /// Kitchen Order Ticket — item names + qty only, no prices/totals.
  Future<void> printKitchenBill(Bill bill, {String? printerName}) async {
    if (!GetPlatform.isWindows) {
      debugPrint("KOT request sent to central server for Table ${bill.tableId}.");
      return;
    }
    final target = printerName ?? await resolvePrinter();
    if (target == null || target.isEmpty) {
      debugPrint('No thermal printer connected. KOT logged for Table ${bill.tableId}.');
      return;
    }

    final bytes = _buildKitchenReceiptBytes(bill);

    try {
      await WindowsPrinter.printRawData(
        printerName: target,
        data: bytes,
        useRawDatatype: true,
      );
    } catch (e) {
      debugPrint('Printer offline or error printing KOT for bill ${bill.billNumber}: $e');
    }
  }

  /// Print raw ESC/POS bytes directly over Wi-Fi network socket to an IP printer (TCP Port 9100)
  Future<void> printOverNetwork({
    required String ipAddress,
    required Uint8List bytes,
    int port = 9100,
  }) async {
    try {
      final socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 4));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      debugPrint("Printed successfully over Wi-Fi network socket to $ipAddress:$port");
    } catch (e) {
      debugPrint("Wi-Fi network socket print note ($ipAddress:$port): $e");
    }
  }

  /// Thermal print Z-Report / Daily Register Shift Settlement
  Future<void> printShiftSettlementReport({
    required String shiftLabel,
    required double openingCash,
    required double openingBank,
    required double cashSales,
    required double onlineSales,
    required double totalExpenses,
    required double expectedCash,
    required double actualCash,
    required double cashVariance,
    required double expectedBank,
    required double actualBank,
    required double bankVariance,
    String? printerName,
  }) async {
    if (!GetPlatform.isWindows) {
      debugPrint("Direct thermal printing is only supported on Windows.");
      return;
    }
    final target = printerName ?? await resolvePrinter();
    if (target == null || target.isEmpty) {
      throw PrintException('No printer connected or selected in Settings.');
    }

    const centerBold = WPTextStyle(align: WPTextAlign.center, bold: true);
    const center = WPTextStyle(align: WPTextAlign.center);

    final builder = WPReceiptBuilder(wpPaperSize: WPPaperSize.mm80);

    if (shopName.isNotEmpty) {
      builder.header(shopName);
    }
    builder.line('SHIFT CLOSE & CASH Z-REPORT', style: centerBold);
    builder.line('Time: $shiftLabel', style: center);
    builder.separator();

    builder.item('Opening Cash Float', '₹${openingCash.round()}');
    builder.item('Opening Bank Balance', '₹${openingBank.round()}');
    builder.separator();

    builder.item('+ Today Cash Sales', '₹${cashSales.round()}');
    builder.item('+ Today Online Sales', '₹${onlineSales.round()}');
    builder.item('- Cash Drops/Expenses', '₹${totalExpenses.round()}');
    builder.separator();

    builder.item('Expected Cash in Drawer', '₹${expectedCash.round()}');
    builder.item('Actual Cash Counted', '₹${actualCash.round()}');
    builder.item('Cash Variance', '₹${cashVariance.round() >= 0 ? "+" : ""}${cashVariance.round()}');
    builder.separator();

    builder.item('Expected Bank Total', '₹${expectedBank.round()}');
    builder.item('Actual Bank Counted', '₹${actualBank.round()}');
    builder.item('Bank Variance', '₹${bankVariance.round() >= 0 ? "+" : ""}${bankVariance.round()}');
    builder.separator();

    final netTotal = actualCash + actualBank;
    builder.item('NET DAY REVENUE (POS)', '₹${(cashSales + onlineSales).round()}');
    builder.item('NET CASH + BANK IN HAND', '₹${netTotal.round()}');

    builder.separator();
    builder.line('--- SHIFT CLOSED ---', style: centerBold);
    _cutPaper(builder);

    final bytes = Uint8List.fromList(builder.build());
    try {
      await WindowsPrinter.printRawData(
        printerName: target,
        data: bytes,
        useRawDatatype: true,
      );
    } catch (e) {
      throw PrintException('Could not print shift report: $e');
    }
  }

  /// Manual thermal print for Sales Summary Report (total sales, revenue,
  /// payment breakdown, most sold item, and top/all sold items) for any date range.
  Future<void> printSalesSummaryReport({
    required String periodLabel,
    required String dateRangeLabel,
    required int totalOrders,
    required int paidOrders,
    required int pendingOrders,
    required int cancelledOrders,
    required double totalRevenue,
    required double totalDiscount,
    required double totalItemsSold,
    required Map<String, double> paymentBreakdown,
    required List<Map<String, dynamic>> itemSales,
    bool includeAllItems = false,
    String? printerName,
  }) async {
    if (!GetPlatform.isWindows) {
      throw PrintException(
        'Direct thermal printing is only supported on Windows.',
      );
    }
    final target = printerName ?? await resolvePrinter();
    if (target == null || target.isEmpty) {
      throw PrintException(
        'No printer found. Make sure your thermal printer is connected and selected in Settings.',
      );
    }

    const centerBold = WPTextStyle(align: WPTextAlign.center, bold: true);
    const center = WPTextStyle(align: WPTextAlign.center);
    const totalStyle = WPTextStyle(
      bold: true,
      align: WPTextAlign.center,
      size: WPTextSize.doubleHeight,
    );

    String fmtQty(num q) =>
        q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

    String trimName(String name, {int max = 22}) =>
        name.length <= max ? name : '${name.substring(0, max - 1)}.';

    final builder = WPReceiptBuilder(wpPaperSize: WPPaperSize.mm80);

    if (shopName.isNotEmpty) {
      builder.header(shopName);
    }
    if (shopAddress.isNotEmpty) {
      builder.line(shopAddress, style: center);
    }
    if (shopPhone.isNotEmpty) {
      builder.line('Ph: $shopPhone', style: center);
    }
    builder.separator();

    builder.line('SALES SUMMARY REPORT', style: centerBold);
    builder.line(periodLabel, style: centerBold);
    builder.line(dateRangeLabel, style: center);
    builder.line('Printed: ${_formatDate(DateTime.now())}', style: center);
    builder.separator();

    builder.item('Total Sales (Orders)', '$totalOrders');
    builder.item('Paid / Pending', '$paidOrders / $pendingOrders');
    if (cancelledOrders > 0) {
      builder.item('Cancelled Orders', '$cancelledOrders');
    }
    builder.item('Total Items Sold', fmtQty(totalItemsSold));
    final avgBill = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    builder.item('Avg Bill Value', 'Rs.${_money(avgBill)}');
    if (totalDiscount > 0) {
      builder.item('Total Discount', 'Rs.${_money(totalDiscount)}');
    }

    builder.separator();
    builder.line('TOTAL SALES: Rs.${_money(totalRevenue)}', style: totalStyle);
    builder.separator();

    if (paymentBreakdown.isNotEmpty) {
      builder.line('PAYMENT BREAKDOWN', style: centerBold);
      paymentBreakdown.forEach((method, amount) {
        if (amount > 0) {
          final label = method.isEmpty
              ? 'Other'
              : '${method[0].toUpperCase()}${method.substring(1)}';
          builder.item(label, 'Rs.${_money(amount)}');
        }
      });
      builder.separator();
    }

    if (itemSales.isNotEmpty) {
      final top = itemSales.first;
      final topName = top['name']?.toString() ?? '-';
      final topQty = fmtQty((top['qty'] as num?) ?? 0);
      final topTotal = _money(((top['total'] as num?) ?? 0).toDouble());

      builder.line('MOST SOLD ITEM', style: centerBold);
      builder.line(topName, style: centerBold);
      builder.line('$topQty sold  (Rs.$topTotal)', style: center);
      builder.separator();

      final itemsToPrint = includeAllItems
          ? itemSales
          : itemSales.take(10).toList();
      builder.line(
        includeAllItems
            ? 'ALL ITEMS SOLD (${itemsToPrint.length})'
            : 'TOP ${itemsToPrint.length} SELLING ITEMS',
        style: centerBold,
      );

      for (int i = 0; i < itemsToPrint.length; i++) {
        final item = itemsToPrint[i];
        final name = trimName(item['name']?.toString() ?? 'Item');
        final qty = fmtQty((item['qty'] as num?) ?? 0);
        final rev = _money(((item['total'] as num?) ?? 0).toDouble());
        builder.item('${i + 1}. $name x$qty', 'Rs.$rev');
      }
      builder.separator();
    } else {
      builder.line('No item sales in this period', style: center);
      builder.separator();
    }

    builder.line('--- END OF REPORT ---', style: centerBold);
    _cutPaper(builder);

    final bytes = Uint8List.fromList(builder.build());
    try {
      await WindowsPrinter.printRawData(
        printerName: target,
        data: bytes,
        useRawDatatype: true,
      );
    } catch (e) {
      if (printerName == null) {
        final freshTarget = await resolvePrinter(forceRefresh: true);
        if (freshTarget != null && freshTarget != target) {
          try {
            await WindowsPrinter.printRawData(
              printerName: freshTarget,
              data: bytes,
              useRawDatatype: true,
            );
            return;
          } catch (_) {}
        }
      }
      throw PrintException('Could not print sales summary report: $e');
    }
  }

  Uint8List _buildKitchenReceiptBytes(Bill bill) {
    const center = WPTextStyle(align: WPTextAlign.center);
    const centerBold = WPTextStyle(align: WPTextAlign.center, bold: true);
    const itemStyle = WPTextStyle(bold: true, size: WPTextSize.doubleHeight);

    final builder = WPReceiptBuilder(wpPaperSize: WPPaperSize.mm80);

    builder.header('KITCHEN ORDER');
    builder.line('Bill #${bill.billNumber}', style: center);
    builder.line(_formatDate(bill.createdAt), style: center);
    builder.separator();

    if (bill.tableId != null && bill.tableId!.isNotEmpty) {
      builder.item('Table', bill.tableId!);
    }
    if (bill.waiter != null && bill.waiter!.isNotEmpty) {
      builder.item('Waiter', bill.waiter!);
    }
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      builder.item('Customer', bill.customerName!);
    }
    builder.separator();
    builder.line('ITEMS', style: centerBold);

    for (final item in bill.items) {
      final isPortion = PortionHelper.isPortionItemByName(item.name);
      final qtyLabel = PortionHelper.formatQtyForItem(
        item.name,
        item.qty,
        forcePortion: isPortion,
      );
      final kotLine = isPortion
          ? '$qtyLabel  ${item.name}'
          : '$qtyLabel x ${item.name}';
      builder.line(kotLine, style: itemStyle);
    }

    builder.separator();
    _cutPaper(builder);

    final bytes = Uint8List.fromList(builder.build());

    // ── DEBUG: dump what's being sent to the printer ──
    debugPrint('===== RECEIPT CONTENT (Bill #${bill.billNumber}) =====');
    debugPrint('Shop: $shopName');
    debugPrint('Date: ${_formatDate(bill.createdAt)}');
    if (bill.tableId?.isNotEmpty ?? false) debugPrint('Table: ${bill.tableId}');
    if (bill.customerName?.isNotEmpty ?? false)
      debugPrint('Customer: ${bill.customerName}');
    for (final item in bill.items) {
      debugPrint(
        '  ${item.name} x${item.qty}  =  ${item.total.toStringAsFixed(2)}',
      );
    }
    debugPrint('Subtotal: ${bill.subtotal.toStringAsFixed(2)}');
    if (bill.discount > 0)
      debugPrint('Discount: -${bill.discount.toStringAsFixed(2)}');
    debugPrint('TOTAL: ${(bill.subtotal - bill.discount).toStringAsFixed(2)}');
    debugPrint('Payment: ${bill.paymentMethod}');
    debugPrint('Raw bytes length: ${bytes.length}');
    debugPrint('=======================================');

    return bytes;
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
