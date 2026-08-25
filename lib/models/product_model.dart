class Product {
  final String id;
  String name;
  String category;
  double price;
  String unit;
  String? description;
  bool active;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.unit = 'pcs',
    this.description,
    this.active = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['_id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'General',
        price: (json['price'] as num).toDouble(),
        unit: json['unit'] as String? ?? 'pcs',
        description: json['description'] as String?,
        active: json['active'] as bool? ?? true,
      );

  /// Payload for create/update requests (id is in the URL, not the body).
  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'price': price,
        'unit': unit,
        'description': description,
      };
}
