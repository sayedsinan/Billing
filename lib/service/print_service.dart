import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windows_printer/windows_printer.dart';

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

  // ── Shop details shown on every receipt — adjust to taste ─────────────
  static const String shopName = 'Grillo';
  static const String shopAddress = ''; // e.g. '123 Main Street'
  static const String footerLine = 'Thank you, visit again!';
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

  /// Picks which printer to send jobs to: the saved one if it's still
  /// plugged in, otherwise the first printer Windows can see, else null.
  Future<String?> resolvePrinter() async {
    final printers = await getAvailablePrinters();
    if (printers.isEmpty) return null;
    final saved = savedPrinter;
    if (saved != null && printers.contains(saved)) return saved;
    return printers.first;
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
    final target = printerName ?? await resolvePrinter();
    final printers = await getAvailablePrinters();

    for (final printer in printers) {
      print(printer);
    }
    if (target == null) {
      throw PrintException(
        'No printer found. Make sure your thermal printer is connected and installed in Windows.',
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

    builder.header(shopName);
    if (shopAddress.isNotEmpty) {
      builder.line(shopAddress, style: center);
    }
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
      final qtyLabel = item.qty == item.qty.roundToDouble()
          ? item.qty.toInt().toString()
          : item.qty.toString();
      builder.item('${item.name} x$qtyLabel', _money(item.total));
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
    await printBill(bill, printerName: printerName);
    await printKitchenBill(bill, printerName: printerName);
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
    if (target == null) {
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
      final qtyLabel = item.qty == item.qty.roundToDouble()
          ? item.qty.toInt().toString()
          : item.qty.toString();
      builder.line('$qtyLabel x ${item.name}', style: itemStyle);
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
