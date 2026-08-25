enum TableStatus { empty, occupied, reserved, billing, cleaning }

TableStatus tableStatusFromString(String? s) {
  switch (s) {
    case 'occupied':
      return TableStatus.occupied;
    case 'reserved':
      return TableStatus.reserved;
    case 'billing':
      return TableStatus.billing;
    case 'cleaning':
      return TableStatus.cleaning;
    case 'empty':
    default:
      return TableStatus.empty;
  }
}

String tableStatusToString(TableStatus s) => s.name; // empty | occupied | reserved | billing | cleaning

class OrderItem {
  String name;
  double qty;
  double rate;
  double get total => qty * rate;

  OrderItem({required this.name, required this.qty, required this.rate});

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        name: json['name']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toDouble() ?? 1,
        rate: (json['rate'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'rate': rate};
}

class DiningTable {
  /// Backend Mongo _id. Empty until the table has been created on the server.
  final String id;

  /// Human-facing label, e.g. "T1". Set once at creation, immutable after.
  final String tableId;

  int seats;
  TableStatus status;
  String? waiter;
  List<OrderItem> items;
  DateTime? occupiedSince;

  DiningTable({
    this.id = '',
    required this.tableId,
    required this.seats,
    this.status = TableStatus.empty,
    this.waiter,
    List<OrderItem>? items,
    this.occupiedSince,
  }) : items = items ?? [];

  double get subtotal => items.fold(0, (s, i) => s + i.total);

  factory DiningTable.fromJson(Map<String, dynamic> json) => DiningTable(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        tableId: (json['tableId'] ?? json['id'] ?? '').toString(),
        seats: (json['seats'] as num?)?.toInt() ?? 4,
        status: tableStatusFromString(json['status']?.toString()),
        waiter: json['waiter']?.toString(),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        occupiedSince: json['occupiedSince'] != null
            ? DateTime.tryParse(json['occupiedSince'].toString())
            : null,
      );

  /// Payload for PUT /tables/:id. `tableId` is intentionally left out by
  /// TableController.saveTable since it's set once at creation.
  Map<String, dynamic> toJson() => {
        'tableId': tableId,
        'seats': seats,
        'status': tableStatusToString(status),
        'waiter': waiter,
        'items': items.map((i) => i.toJson()).toList(),
        if (occupiedSince != null) 'occupiedSince': occupiedSince!.toIso8601String(),
      };

  DiningTable copyWith({
    String? id,
    String? tableId,
    int? seats,
    TableStatus? status,
    String? waiter,
    List<OrderItem>? items,
    DateTime? occupiedSince,
    bool clearWaiter = false,
    bool clearOccupiedSince = false,
  }) =>
      DiningTable(
        id: id ?? this.id,
        tableId: tableId ?? this.tableId,
        seats: seats ?? this.seats,
        status: status ?? this.status,
        waiter: clearWaiter ? null : (waiter ?? this.waiter),
        items: items ?? this.items,
        occupiedSince: clearOccupiedSince ? null : (occupiedSince ?? this.occupiedSince),
      );
}