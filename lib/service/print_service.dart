import 'dart:typed_data';

import 'package:get_storage/get_storage.dart';
import 'package:windows_printer/windows_printer.dart';

import 'package:test_bill/models/bill_model.dart';

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

  // ── Printer selection ──────────────────────────────────────────────
  Future<List<String>> getAvailablePrinters() =>
      WindowsPrinter.getAvailablePrinters();

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
    final target = printerName ?? await resolvePrinter();
    // final target = printerName ?? await resolvePrinter();
    final printers = await WindowsPrinter.getAvailablePrinters();

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
    builder.blank();
    for (final item in bill.items) {
      final qtyLabel = item.qty == item.qty.roundToDouble()
          ? item.qty.toInt().toString()
          : item.qty.toString();
      builder.item('${item.name} x$qtyLabel', item.total.toStringAsFixed(2));
    }
    builder.blank();

    builder.separator();
    builder.item('Subtotal', bill.subtotal.toStringAsFixed(2));

    if (bill.discount > 0) {
      builder.item('Discount', '-${bill.discount.toStringAsFixed(2)}');
    }

    final noTaxTotal = bill.subtotal - bill.discount;

    builder.separator();
    builder.line('TOTAL: ${noTaxTotal.toStringAsFixed(2)}', style: totalStyle);
    builder.item('Payment', bill.paymentMethod);
    builder.separator();
    builder.line(footerLine, style: centerBold);
    builder.line('Please visit again', style: centerItalic);
    builder.blank();

    // Hardware actions — uncomment what your printer supports.
    // builder.drawer(); // open cash drawer
    // builder.beep();
    builder.cut();

    return Uint8List.fromList(builder.build());
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
