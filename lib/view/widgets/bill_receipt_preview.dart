import 'package:flutter/material.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/models/table_model.dart';
import 'package:test_bill/theme/colors.dart';

/// A widget that renders a live visual representation of an ESC/POS thermal receipt.
class BillReceiptPreview extends StatelessWidget {
  final String shopName;
  final String? tableId;
  final String? waiter;
  final String? customerName;
  final String? billNumber;
  final List<dynamic> items; // List<OrderItem> or List<BillItem>
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discount;
  final double grandTotal;
  final DateTime? createdAt;
  final bool isKOT;

  const BillReceiptPreview({
    super.key,
    this.shopName = 'G R I L L O',
    this.tableId,
    this.waiter,
    this.customerName,
    this.billNumber,
    required this.items,
    required this.subtotal,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.discount = 0.0,
    required this.grandTotal,
    this.createdAt,
    this.isKOT = false,
  });

  factory BillReceiptPreview.fromBill(Bill bill, {bool isKOT = false}) {
    return BillReceiptPreview(
      shopName: 'G R I L L O',
      tableId: bill.tableId,
      waiter: bill.waiter,
      customerName: bill.customerName,
      billNumber: bill.billNumber,
      items: bill.items,
      subtotal: bill.subtotal,
      taxRate: bill.taxRate,
      taxAmount: bill.taxAmount,
      discount: bill.discount,
      grandTotal: bill.grandTotal,
      createdAt: bill.createdAt,
      isKOT: isKOT,
    );
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hourInt = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day-$month-$year $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(createdAt ?? DateTime.now());
    final bNum = billNumber ?? (tableId != null ? 'TBL-$tableId' : '001');

    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Thermal Header Badge ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isKOT ? kPurple.withOpacity(0.12) : kBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isKOT ? '🔪 KITCHEN ORDER TICKET (KOT) PREVIEW' : '🧾 THERMAL RECEIPT PREVIEW',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isKOT ? kPurple : kBlue,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Shop Name ──
          Text(
            isKOT ? 'KITCHEN ORDER' : shopName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: 1.5,
            ),
          ),
          if (!isKOT) ...[
            const SizedBox(height: 2),
            const Text(
              'Restaurant & Fine Dining',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // ── Receipt Details ──
          Text(
            'Bill #: $bNum',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            dateStr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.black54,
            ),
          ),

          if (tableId != null && tableId!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Table: $tableId ${waiter != null && waiter!.isNotEmpty ? ' | Waiter: $waiter' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],

          if (customerName != null && customerName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Customer: $customerName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black87,
              ),
            ),
          ],

          const SizedBox(height: 10),
          const _DashedLine(),
          const SizedBox(height: 8),

          // ── Items Table Header ──
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'ITEM',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'QTY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (!isKOT) ...[
                Expanded(
                  flex: 2,
                  child: Text(
                    'RATE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const _DashedLine(),
          const SizedBox(height: 8),

          // ── Items List ──
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '-- No Items --',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.black38,
                ),
              ),
            )
          else
            ...items.map((item) {
              final String name = item is OrderItem
                  ? item.name
                  : (item is BillItem ? item.name : item['name']?.toString() ?? '');
              final double qty = item is OrderItem
                  ? item.qty
                  : (item is BillItem ? item.qty : (item['qty'] as num?)?.toDouble() ?? 1.0);
              final double rate = item is OrderItem
                  ? item.rate
                  : (item is BillItem ? item.rate : (item['rate'] as num?)?.toDouble() ?? 0.0);
              final double total = item is OrderItem
                  ? item.total
                  : (item is BillItem ? item.total : (item['total'] as num?)?.toDouble() ?? (qty * rate));

              final qtyLabel = qty == qty.toInt() ? '${qty.toInt()}' : '$qty';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        name.isEmpty ? 'Item' : name,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        qtyLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (!isKOT) ...[
                      Expanded(
                        flex: 2,
                        child: Text(
                          rate.round().toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          total.round().toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

          const SizedBox(height: 8),
          const _DashedLine(),
          const SizedBox(height: 8),

          // ── Totals (Only for Bill, omitted for KOT) ──
          if (!isKOT) ...[
            _ReceiptTotalLine(label: 'Subtotal:', value: '₹${subtotal.round()}'),
            if (discount > 0)
              _ReceiptTotalLine(label: 'Discount:', value: '-₹${discount.round()}'),
            if (taxAmount > 0)
              _ReceiptTotalLine(label: 'Tax (${taxRate.round()}%):', value: '₹${taxAmount.round()}'),
            const SizedBox(height: 6),
            const _DashedLine(),
            const SizedBox(height: 6),
            _ReceiptTotalLine(
              label: 'GRAND TOTAL:',
              value: '₹${grandTotal.round()}',
              isGrandTotal: true,
            ),
            const SizedBox(height: 8),
            const _DashedLine(),
          ],

          const SizedBox(height: 12),

          // ── Footer ──
          Text(
            isKOT ? '*** END OF KOT ***' : '*** THANK YOU! VISIT AGAIN ***',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTotalLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isGrandTotal;

  const _ReceiptTotalLine({
    required this.label,
    required this.value,
    this.isGrandTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: isGrandTotal ? 13 : 11,
              fontWeight: isGrandTotal ? FontWeight.w900 : FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: isGrandTotal ? 14 : 11,
              fontWeight: isGrandTotal ? FontWeight.w900 : FontWeight.bold,
              color: isGrandTotal ? kGreen : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
              ),
            );
          }),
        );
      },
    );
  }
}
