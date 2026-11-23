import 'package:get/get.dart';
import 'package:test_bill/controller/product_controller.dart';
import 'package:test_bill/models/product_model.dart';

/// Utilities for Mandi / F-H-Q portion quantities & 3-tier pricing:
///   1 = Q (Quarter)          -> quarterPrice
///   2 = H (Half)             -> halfPrice
///   3 = H+Q (Half + Quarter) -> halfPrice + quarterPrice
///   4 = F (Full)             -> fullPrice
///   5 = F+Q, 6 = F+H, 7 = F+H+Q, 8 = 2F, ...
class PortionHelper {
  static const _portionUnits = {'qtr', 'quarter', 'portion', 'fhq', 'mandi'};

  /// Returns true if a product uses quarter-based F/H/Q portions.
  static bool isPortionProduct(Product p) =>
      p.hasPortionPrices ||
      isPortionItem(
        p.name,
        category: p.category,
        unit: p.unit,
      );

  /// Checks name, category, and unit for portion-based items (e.g. Mandi).
  static bool isPortionItem(
    String name, {
    String? category,
    String? unit,
  }) {
    final lowerName = name.toLowerCase();
    final lowerCat = (category ?? '').toLowerCase();
    final lowerUnit = (unit ?? '').trim().toLowerCase();

    if (lowerName.contains('mandi') || lowerCat.contains('mandi')) {
      return true;
    }
    if (_portionUnits.contains(lowerUnit)) {
      return true;
    }
    return false;
  }

  /// Finds a matching catalog [Product] by name if [ProductController] is registered.
  static Product? findProductByName(String name) {
    if (!Get.isRegistered<ProductController>()) return null;
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return null;
    for (final p in Get.find<ProductController>().products) {
      if (p.name.trim().toLowerCase() == lower) {
        return p;
      }
    }
    return null;
  }

  /// Checks whether an order/bill line item is portion-based by name, also
  /// looking up the catalog in [ProductController] when available.
  static bool isPortionItemByName(String name) {
    if (isPortionItem(name)) return true;
    final p = findProductByName(name);
    if (p != null) return isPortionProduct(p);
    return false;
  }

  /// Calculates the exact line total for [product] at [qty]:
  /// - If [product] has Q/H/F prices configured:
  ///   1(Q) -> qtr, 2(H) -> half, 3(H+Q) -> half+qtr, 4(F) -> full,
  ///   5(F+Q) -> full+qtr, 6(F+H) -> full+half, 7(F+H+Q) -> full+half+qtr, 8(2F) -> 2*full.
  /// - Otherwise: `qty * product.price`.
  static double calculatePortionTotal(Product product, double qty) {
    if (qty <= 0) return 0;
    if (!product.hasPortionPrices) {
      return qty * product.price;
    }
    final rounded = qty.round();
    if ((qty - rounded).abs() > 0.001) {
      return qty * product.effectiveQuarterPrice;
    }
    final qPrice = product.effectiveQuarterPrice;
    final hPrice = product.effectiveHalfPrice;
    final fPrice = product.effectiveFullPrice;

    final fulls = rounded ~/ 4;
    final rem = rounded % 4;
    final remCost = switch (rem) {
      1 => qPrice,
      2 => hPrice,
      3 => hPrice + qPrice,
      _ => 0.0,
    };
    return fulls * fPrice + remCost;
  }

  /// Returns the effective per-unit rate so `qty * rate == calculatePortionTotal(product, qty)`.
  static double effectiveRateForQty(Product product, double qty) {
    if (qty <= 0) return product.effectiveQuarterPrice;
    return calculatePortionTotal(product, qty) / qty;
  }

  /// Formats a numeric quarter count into F / H / Q notation:
  ///   1 -> Q, 2 -> H, 3 -> H+Q, 4 -> F, 5 -> F+Q, 6 -> F+H, 7 -> F+H+Q, 8 -> 2F
  static String formatPortionQty(double qty) {
    if (qty <= 0) return '0';
    final rounded = qty.round();
    if ((qty - rounded).abs() > 0.001) {
      return qty.toStringAsFixed(1);
    }

    final fulls = rounded ~/ 4;
    final rem = rounded % 4;
    final parts = <String>[];

    if (fulls == 1) {
      parts.add('F');
    } else if (fulls > 1) {
      parts.add('${fulls}F');
    }

    if (rem == 1) {
      parts.add('Q');
    } else if (rem == 2) {
      parts.add('H');
    } else if (rem == 3) {
      parts.add('H+Q');
    }

    return parts.isEmpty ? '0' : parts.join('+');
  }

  /// Formats a standard numeric quantity cleanly (e.g. 2.0 -> "2", 1.5 -> "1.5").
  static String formatPlainQty(double qty) =>
      qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

  /// Formats quantity for display/printing given an item name (uses F/H/Q for
  /// Ma