import 'package:test_bill/models/product_model.dart';

class BillItem {
  final String? productId;
  final String name;
  final double qty;
  final double rate;
  final double total;

  BillItem({
    this.productId,
    required this.name,
    required this.qty,
    required this.rate,
    required this.total,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    productId: json['product'] as String?,
    name: json['name'] as String,
    qty: (json['qty'] as num).toDouble(),
    rate: (json['rate'] as num).toDouble(),
    total: (json['total'] as num).toDouble(),
  );
}

enum BillStatus { unpaid, paid, cancelled, pending, overdue }

BillStatus _statusFromString(String s) => BillStatus.values.firstWhere(
  (e) =>
      e.name ==
      s.trim().toLowerCase(), // guards against case/whitespace mismatches
  orElse: () => BillStatus.unpaid, // ← change back from BillStatus.paid
);

class Bill {
  final String id;
  final String billNumber;
  final String source; // "table" or "direct"
  final String? tableId;
  final String? customerName;
  final String? waiter;
  final List<BillItem> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discount;
  final double grandTotal;
  final String paymentMethod;
  final BillStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;

  Bill({
    required this.id,
    required this.billNumber,
    required this.source,
    this.tableId,
    this.customerName,
    this.waiter,
    required this.items,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.discount,
    required this.grandTotal,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['_id'] as String,
    billNumber: json['billNumber'] as String,
    source: json['source'] as String? ?? 'direct',
    tableId: json['tableId'] as String?,
    customerName: json['customerName'] as String?,
    waiter: json['waiter'] as String?,
    items: (json['items'] as List)
        .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    subtotal: (json['subtotal'] as num).toDouble(),
    taxRate: (json['taxRate'] as num).toDouble(),
    taxAmount: (json['taxAmount'] as num).toDouble(),
    discount: (json['discount'] as num).toDouble(),
    grandTotal: (json['grandTotal'] as num).toDouble(),
    paymentMethod: json['paymentMethod'] as String? ?? 'pending',
    status: _statusFromString(json['status'] as String? ?? 'unpaid'),
    createdAt: DateTime.parse(json['createdAt'] as String),
    paidAt: json['paidAt'] != null
        ? DateTime.parse(json['paidAt'] as String)
        : null,
  );
}

/// A line in the in-memory cart, before checkout turns it into a BillItem.
class CartItem {
  final Product product;
  double qty;

  CartItem({required this.product, this.qty = 1});

  double get total => product.price * qty;
}
