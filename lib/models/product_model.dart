class Product {
  final String id;
  String name;
  String category;
  double price;
  double? quarterPrice;
  double? halfPrice;
  double? fullPrice;
  String unit;
  String? description;
  bool active;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.quarterPrice,
    this.halfPrice,
    this.fullPrice,
    this.unit = 'pcs',
    this.description,
    this.active = true,
  });

  /// True when the item has explicit Q / H / F portion prices configured.
  bool get hasPortionPrices => halfPrice != null || fullPrice != null;

  /// Effective Quarter price (defaults to base [price]).
  double get effectiveQuarterPrice => quarterPrice ?? price;

  /// Effective Half price (defaults to 2x quarter price).
  double get effectiveHalfPrice => halfPrice ?? (effectiveQuarterPrice * 2);

  /// Effective Full price (defaults to 2x half price).
  double get effectiveFullPrice => fullPrice ?? (effectiveHalfPrice * 2);

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['_id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'General',
        price: (json['price'] as num).toDouble(),
        quarterPrice: (json['quarterPrice'] as num?)?.toDouble(),
        halfPrice: (json['halfPrice'] as num?)?.toDouble(),
        fullPrice: (json['fullPrice'] as num?)?.toDouble(),
        unit: json['unit'] as String? ?? 'pcs',
        description: json['description'] as String?,
        active: json['active'] as bool? ?? true,
      );

  /// Payload for create/update requests (id is in the URL, not the body).
  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'price': price,
        'quarterPrice': quarterPrice,
        'halfPrice': halfPrice,
        'fullPrice': fullPrice,
        'unit': unit,
        'description': description ?? '',
        'active': active,
      };
}
