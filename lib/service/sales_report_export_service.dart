import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:test_bill/core/utils/portion_helper.dart';
import 'package:test_bill/models/bill_model.dart';

/// Generates genuine, dependency-free PDF (.pdf) and Excel (.xls SpreadsheetML)
/// files for Sales Summary Reports and saves them via the native Save dialog.
class SalesReportExportService {
  static String _fmtQty(num q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

  static String _xmlEsc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _pdfEsc(String s) {
    // Keep strictly printable ASCII for built-in PDF Helvetica font
    final clean = s.replaceAll('₹', 'Rs.').replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');
    return clean
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  static String _safeSlug(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');

  static String _fmtDateTime(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  /// Builds a valid multi-sheet Excel Workbook (.xls SpreadsheetML) containing:
  ///   1. Sales Summary (KPIs, Most Sold Item, Payment Breakdown)
  ///   2. Items Sold Breakdown (ranked by quantity)
  ///   3. Orders List (every bill in the selected date range)
  static Uint8List buildExcelBytes({
    required String shopName,
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
    required List<Bill> bills,
  }) {
    final avgBill = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    final topItem = itemSales.isNotEmpty ? itemSales.first : null;

    String cellStr(String val, {String? style}) =>
        '<Cell${style != null ? ' ss:StyleID="$style"' : ''}><Data ss:Type="String">${_xmlEsc(val)}</Data></Cell>';

    String cellNum(num val, {String? style}) =>
        '<Cell${style != null ? ' ss:StyleID="$style"' : ''}><Data ss:Type="Number">${val.toStringAsFixed(val == val.roundToDouble() ? 0 : 2)}</Data></Cell>';

    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<?mso-application progid="Excel.Sheet"?>');
    sb.writeln(
      '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
      'xmlns:o="urn:schemas-microsoft-com:office:office" '
      'xmlns:x="urn:schemas-microsoft-com:office:excel" '
      'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
    );
    sb.writeln('<Styles>');
    sb.writeln('<Style ss:ID="Title"><Font ss:Bold="1" ss:Size="14" ss:Color="#1E3A8A"/></Style>');
    sb.writeln('<Style ss:ID="Section"><Font ss:Bold="1" ss:Size="11" ss:Color="#1E3A8A"/><Interior ss:Color="#EFF6FF" ss:Pattern="Solid"/></Style>');
    sb.writeln('<Style ss:ID="Header"><Font ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#2563EB" ss:Pattern="Solid"/></Style>');
    sb.writeln('<Style ss:ID="Bold"><Font ss:Bold="1"/></Style>');
    sb.writeln('<Style ss:ID="Highlight"><Font ss:Bold="1" ss:Color="#7E22CE"/><Interior ss:Color="#FAF5FF" ss:Pattern="Solid"/></Style>');
    sb.writeln('</Styles>');

    // ── Sheet 1: Sales Summary ──
    sb.writeln('<Worksheet ss:Name="Sales Summary"><Table>');
    sb.writeln('<Column ss:Width="200"/><Column ss:Width="180"/><Column ss:Width="140"/>');
    sb.writeln('<Row>${cellStr('$shopName - Sales Summary Report', style: 'Title')}</Row>');
    sb.writeln('<Row>${cellStr('Period', style: 'Bold')}${cellStr('$periodLabel ($dateRangeLabel)')}</Row>');
    sb.writeln('<Row>${cellStr('Generated At', style: 'Bold')}${cellStr(_fmtDateTime(DateTime.now()))}</Row>');
    sb.writeln('<Row/>');

    sb.writeln('<Row>${cellStr('Metric', style: 'Header')}${cellStr('Value', style: 'Header')}</Row>');
    sb.writeln('<Row>${cellStr('Total Sales (Orders)')}${cellNum(totalOrders)}</Row>');
    sb.writeln('<Row>${cellStr('Paid Orders')}${cellNum(paidOrders)}</Row>');
    sb.writeln('<Row>${cellStr('Pending Orders')}${cellNum(pendingOrders)}</Row>');
    sb.writeln('<Row>${cellStr('Cancelled Orders')}${cellNum(cancelledOrders)}</Row>');
    sb.writeln('<Row>${cellStr('Total Revenue (Rs.)', style: 'Bold')}${cellNum(totalRevenue, style: 'Bold')}</Row>');
    sb.writeln('<Row>${cellStr('Total Discount (Rs.)')}${cellNum(totalDiscount)}</Row>');
    sb.writeln('<Row>${cellStr('Average Bill Value (Rs.)')}${cellNum(avgBill)}</Row>');
    sb.writeln('<Row>${cellStr('Total Items Sold')}${cellNum(totalItemsSold)}</Row>');
    sb.writeln('<Row/>');

    sb.writeln('<Row>${cellStr('Most Sold Item', style: 'Section')}${cellStr('', style: 'Section')}${cellStr('', style: 'Section')}</Row>');
    if (topItem != null) {
      final topName = topItem['name']?.toString() ?? '-';
      final topQtyNum = (topItem['qty'] as num?) ?? 0;
      final topQtyLabel = PortionHelper.formatQtyForItem(topName, topQtyNum.toDouble());
      sb.writeln('<Row>${cellStr(topName, style: 'Highlight')}${cellStr('$topQtyLabel sold', style: 'Highlight')}${cellNum((topItem['total'] as num?) ?? 0, style: 'Highlight')}</Row>');
    } else {
      sb.writeln('<Row>${cellStr('No item sales in this period')}</Row>');
    }
    sb.writeln('<Row/>');

    sb.writeln('<Row>${cellStr('Payment Method', style: 'Header')}${cellStr('Amount (Rs.)', style: 'Header')}</Row>');
    if (paymentBreakdown.isEmpty) {
      sb.writeln('<Row>${cellStr('No payment data')}${cellNum(0)}</Row>');
    } else {
      paymentBreakdown.forEach((method, amt) {
        if (amt > 0) {
          final label = method.isEmpty ? 'Other' : '${method[0].toUpperCase()}${method.substring(1)}';
          sb.writeln('<Row>${cellStr(label)}${cellNum(amt)}</Row>');
        }
      });
    }
    sb.writeln('</Table></Worksheet>');

    // ── Sheet 2: Items Sold ──
    sb.writeln('<Worksheet ss:Name="Items Sold"><Table>');
    sb.writeln('<Column ss:Width="50"/><Column ss:Width="220"/><Column ss:Width="100"/><Column ss:Width="120"/>');
    sb.writeln('<Row>${cellStr('Rank', style: 'Header')}${cellStr('Item Name', style: 'Header')}${cellStr('Qty Sold', style: 'Header')}${cellStr('Total Sales (Rs.)', style: 'Header')}</Row>');
    for (int i = 0; i < itemSales.length; i++) {
      final item = itemSales[i];
      final name = item['name']?.toString() ?? 'Item';
      final qty = (item['qty'] as num?) ?? 0;
      final total = (item['total'] as num?) ?? 0;
      final qtyStr = PortionHelper.formatQtyForItem(name, qty.toDouble());
      sb.writeln('<Row>${cellNum(i + 1)}${cellStr(name)}${cellStr(qtyStr)}${cellNum(total)}</Row>');
    }
    sb.writeln('</Table></Worksheet>');

    // ── Sheet 3: Orders ──
    sb.writeln('<Worksheet ss:Name="Orders"><Table>');
    sb.writeln('<Column ss:Width="110"/><Column ss:Width="130"/><Column ss:Width="110"/><Column ss:Width="90"/><Column ss:Width="90"/><Column ss:Width="110"/>');
    sb.writeln('<Row>${cellStr('Bill #', style: 'Header')}${cellStr('Date & Time', style: 'Header')}${cellStr('Source', style: 'Header')}${cellStr('Payment', style: 'Header')}${cellStr('Status', style: 'Header')}${cellStr('Total (Rs.)', style: 'Header')}</Row>');
    for (final b in bills) {
      final src = b.source == 'table' ? 'Table ${b.tableId ?? ''}'.trim() : (b.customerName?.isNotEmpty == true ? b.customerName! : 'Takeout');
      sb.writeln(
        '<Row>${cellStr(b.billNumber)}${cellStr(_fmtDateTime(b.createdAt))}${cellStr(src)}${cellStr(b.paymentMethod.toUpperCase())}${cellStr(b.status.name.toUpperCase())}${cellNum(b.subtotal - b.discount)}</Row>',
      );
    }
    sb.writeln('</Table></Worksheet>');
    sb.writeln('</Workbook>');

    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  /// Builds a genuine multi-page PDF 1.4 document with Helvetica & Helvetica-Bold.
  static Uint8List buildPdfBytes({
    required String shopName,
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
  }) {
    final avgBill = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    final topItem = itemSales.isNotEmpty ? itemSales.first : null;

    final pages = <StringBuffer>[];
    StringBuffer current = StringBuffer();
    double y = 790;

    void startNewPage({bool isFirst = false}) {
      current = StringBuffer();
      pages.add(current);
      y = 795;

      if (isFirst) {
        // Blue header bar
        current.writeln('0.145 0.388 0.922 rg 40 748 515 56 re f');
        current.writeln('1 1 1 rg');
        current.writeln('BT /F2 17 Tf 54 780 Td (${_pdfEsc(shopName)}) Tj ET');
        current.writeln('BT /F1 10 Tf 54 761 Td (${_pdfEsc('SALES SUMMARY REPORT  |  $periodLabel ($dateRangeLabel)')}) Tj ET');
        current.writeln('0.35 0.38 0.44 rg');
        current.writeln('BT /F1 8.5 Tf 40 734 Td (${_pdfEsc('Generated: ${_fmtDateTime(DateTime.now())}')}) Tj ET');
        current.writeln('0 0 0 rg');
        y = 714;
      } else {
        current.writeln('0.4 0.45 0.52 rg');
        current.writeln('BT /F2 10 Tf 40 806 Td (${_pdfEsc('$shopName - Sales Summary ($dateRangeLabel)  [Continued]')}) Tj ET');
        current.writeln('0.85 0.88 0.92 RG 0.7 w 40 798 m 555 798 l S');
        current.writeln('0 0 0 rg');
        y = 778;
      }
    }

    void drawText(double x, double yy, String text, {bool bold = false, double size = 10, String rgb = '0.06 0.09 0.16'}) {
      current.writeln('$rgb rg');
      current.writeln('BT /${bold ? 'F2' : 'F1'} ${size.toStringAsFixed(1)} Tf ${x.toStringAsFixed(1)} ${yy.toStringAsFixed(1)} Td (${_pdfEsc(text)}) Tj ET');
    }

    void drawItemsHeader() {
      current.writeln('0.94 0.96 0.98 rg 40 ${(y - 5).toStringAsFixed(1)} 515 20 re f');
      drawText(48, y + 1, '#', bold: true, size: 9.5, rgb: '0.28 0.33 0.41');
      drawText(80, y + 1, 'ITEM NAME', bold: true, size: 9.5, rgb: '0.28 0.33 0.41');
      drawText(365, y + 1, 'QTY SOLD', bold: true, size: 9.5, rgb: '0.28 0.33 0.41');
      drawText(460, y + 1, 'TOTAL SALES', bold: true, size: 9.5, rgb: '0.28 0.33 0.41');
      y -= 22;
    }

    startNewPage(isFirst: true);

    // ── Overview Box ──
    current.writeln('0.97 0.98 0.99 rg 40 ${(y - 84).toStringAsFixed(1)} 515 96 re f');
    current.writeln('0.88 0.91 0.94 RG 0.8 w 40 ${(y - 84).toStringAsFixed(1)} 515 96 re S');
    drawText(52, y - 4, 'SALES OVERVIEW', bold: true, size: 10.5, rgb: '0.145 0.388 0.922');

    drawText(52, y - 24, 'Total Sales (Orders):', bold: false, size: 10);
    drawText(190, y - 24, '$totalOrders  ($paidOrders paid / $pendingOrders pending${cancelledOrders > 0 ? ' / $cancelledOrders cancelled' : ''})', bold: true, size: 10);

    drawText(52, y - 42, 'Total Revenue:', bold: false, size: 10);
    drawText(190, y - 42, 'Rs.${totalRevenue.round()}', bold: true, size: 12, rgb: '0.09 0.64 0.29');

    drawText(330, y - 42, 'Avg Bill Value:', bold: false, size: 10);
    drawText(420, y - 42, 'Rs.${avgBill.round()}', bold: true, size: 10);

    drawText(52, y - 60, 'Total Items Sold:', bold: false, size: 10);
    drawText(190, y - 60, '${_fmtQty(totalItemsSold)} units (${itemSales.length} menu items)', bold: true, size: 10);

    if (totalDiscount > 0) {
      drawText(330, y - 60, 'Discounts Given:', bold: false, size: 10);
      drawText(420, y - 60, 'Rs.${totalDiscount.round()}', bold: true, size: 10);
    }

    y -= 104;

    // ── Most Sold Highlight Box ──
    current.writeln('0.98 0.96 1.0 rg 40 ${(y - 40).toStringAsFixed(1)} 515 52 re f');
    current.writeln('0.84 0.72 0.96 RG 0.8 w 40 ${(y - 40).toStringAsFixed(1)} 515 52 re S');
    drawText(52, y - 4, 'MOST SOLD ITEM', bold: true, size: 9.5, rgb: '0.49 0.13 0.81');
    if (topItem != null) {
      final topName = topItem['name']?.toString() ?? '-';
      final topQty = PortionHelper.formatQtyForItem(topName, ((topItem['qty'] as num?) ?? 0).toDouble());
      final topRev = ((topItem['total'] as num?) ?? 0).round();
      drawText(52, y - 24, topName, bold: true, size: 13);
      drawText(350, y - 24, '$topQty sold  |  Rs.$topRev', bold: true, size: 11, rgb: '0.49 0.13 0.81');
    } else {
      drawText(52, y - 24, 'No item sales in this period', size: 10.5, rgb: '0.4 0.45 0.52');
    }
    y -= 64;

    // ── Payment Breakdown ──
    final nonZeroPayments = paymentBreakdown.entries.where((e) => e.value > 0).toList();
    if (nonZeroPayments.isNotEmpty) {
      drawText(40, y, 'PAYMENT BREAKDOWN', bold: true, size: 10.5, rgb: '0.145 0.388 0.922');
      y -= 16;
      double px = 40;
      for (final entry in nonZeroPayments) {
        final label = entry.key.isEmpty ? 'Other' : '${entry.key[0].toUpperCase()}${entry.key.substring(1)}';
        final text = '$label: Rs.${entry.value.round()}';
        if (px + 135 > 555) {
          px = 40;
          y -= 18;
        }
        drawText(px, y, text, bold: true, size: 10);
        px += 135;
      }
      y -= 26;
    }

    // ── Items Sold Table ──
    drawText(40, y, 'ITEMS SOLD BREAKDOWN (${itemSales.length} ITEMS)', bold: true, size: 10.5, rgb: '0.145 0.388 0.922');
    y -= 20;
    drawItemsHeader();

    if (itemSales.isEmpty) {
      drawText(48, y, 'No item sales found for this date range.', size: 10, rgb: '0.4 0.45 0.52');
    } else {
      for (int i = 0; i < itemSales.length; i++) {
        if (y < 60) {
          startNewPage(isFirst: false);
          drawItemsHeader();
        }
        final item = itemSales[i];
        final rawName = item['name']?.toString() ?? 'Item';
        final name = rawName.length > 42 ? '${rawName.substring(0, 41)}.' : rawName;
        final qtyStr = PortionHelper.formatQtyForItem(rawName, ((item['qty'] as num?) ?? 0).toDouble());
        final rev = ((item['total'] as num?) ?? 0).round();

        drawText(48, y, '${i + 1}', bold: i < 3, size: 9.5, rgb: i == 0 ? '0.49 0.13 0.81' : '0.28 0.33 0.41');
        drawText(80, y, name, bold: i == 0, size: 9.5);
        drawText(365, y, qtyStr, bold: true, size: 9.5, rgb: '0.145 0.388 0.922');
        drawText(460, y, 'Rs.$rev', bold: true, size: 9.5, rgb: '0.09 0.64 0.29');

        current.writeln('0.91 0.93 0.95 RG 0.5 w 40 ${(y - 5).toStringAsFixed(1)} m 555 ${(y - 5).toStringAsFixed(1)} l S');
        y -= 18;
      }
    }

    // ── Assemble PDF 1.4 binary with exact byte offsets ──
    // Object layout:
    //   1: Catalog
    //   2: Pages
    //   3: Font Helvetica (/F1)
    //   4: Font Helvetica-Bold (/F2)
    //   For each page i (0..P-1):
    //     contentObj = 5 + i*2
    //     pageObj    = 6 + i*2
    final objects = <int, List<int>>{};
    final pageIds = <int>[];

    for (int i = 0; i < pages.length; i++) {
      final contentId = 5 + i * 2;
      final pageId = 6 + i * 2;
      pageIds.add(pageId);
      final streamBytes = utf8.encode(pages[i].toString());
      objects[contentId] = [
        ...utf8.encode('<< /Length ${streamBytes.length} >>\nstream\n'),
        ...streamBytes,
        ...utf8.encode('\nendstream'),
      ];
      objects[pageId] = utf8.encode(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $contentId 0 R >>',
      );
    }

    objects[1] = utf8.encode('<< /Type /Catalog /Pages 2 0 R >>');
    objects[2] = utf8.encode(
      '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] /Count ${pageIds.length} >>',
    );
    objects[3] = utf8.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    objects[4] = utf8.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

    final out = BytesBuilder();
    out.add(utf8.encode('%PDF-1.4\n'));
    final maxId = 4 + pages.length * 2;
    final offsets = List<int>.filled(maxId + 1, 0);

    for (int id = 1; id <= maxId; id++) {
      offsets[id] = out.length;
      out.add(utf8.encode('$id 0 obj\n'));
      out.add(objects[id]!);
      out.add(utf8.encode('\nendobj\n'));
    }

    final xrefPos = out.length;
    out.add(utf8.encode('xref\n0 ${maxId + 1}\n'));
    out.add(utf8.encode('0000000000 65535 f \n'));
    for (int id = 1; id <= maxId; id++) {
      out.add(utf8.encode('${offsets[id].toString().padLeft(10, '0')} 00000 n \n'));
    }
    out.add(utf8.encode('trailer\n<< /Size ${maxId + 1} /Root 1 0 R >>\nstartxref\n$xrefPos\n%%EOF\n'));

    return out.toBytes();
  }

  /// Opens the native Save File dialog and writes the bytes to disk.
  /// Returns the saved file path, or `null` if the user cancelled.
  static Future<String?> saveReportFile({
    required Uint8List bytes,
    required String dateRangeLabel,
    required String extension, // 'pdf' or 'xls'
  }) async {
    final slug = _safeSlug(dateRangeLabel);
    final fileName = 'sales_report_${slug.isEmpty ? 'report' : slug}.$extension';

    final outputPath = await FilePicker.saveFile(
      dialogTitle: extension == 'pdf'
          ? 'Save Sales Report as PDF'
          : 'Save Sales Report as Excel',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );

    if (outputPath == null || outputPath.trim().isEmpty) {
      return null;
    }

    final finalPath = outputPath.toLowerCase().endsWith('.$extension')
        ? outputPath
        : '$outputPath.$extension';

    final file = File(finalPath);
    await file.writeAsBytes(bytes, flush: true);
    return finalPath;
  }
}
