import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/product_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/models/product_model.dart';
import 'package:test_bill/models/table_model.dart'; // for OrderItem
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/service/print_service.dart';
import 'package:test_bill/theme/colors.dart';
import 'package:test_bill/view/widgets/bill_receipt_preview.dart';

/// A takeout / counter bill: no table involved. Browse the product catalog
/// as tappable blocks (same UI as the table order dialog), generate + print
/// directly via ApiService.createDirectBill.
class TakeoutBillDialog extends StatefulWidget {
  const TakeoutBillDialog({super.key});

  @override
  State<TakeoutBillDialog> createState() => _TakeoutBillDialogState();
}

class _TakeoutBillDialogState extends State<TakeoutBillDialog> {
  final ProductController _productController = Get.find<ProductController>();
  final TextEditingController _productSearchCtrl = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();
  String _productQuery = '';

  List<OrderItem> _items = [];
  bool _generating = false;
  bool _printing = false;
  Bill? _generatedBill;
  bool _previewKOT = false;

  @override
  void initState() {
    super.initState();
    if (_productController.products.isEmpty) {
      _productController.fetchProducts();
    }
  }

  @override
  void dispose() {
    _productSearchCtrl.dispose();
    _customerNameCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (s, i) => s + i.total);

  /// Adds a product from the catalog to the current order immediately.
  /// If the product is already on the bill, its quantity is bumped by 1
  /// instead of creating a duplicate line.
  void _addProductToOrder(Product p) {
    setState(() {
      final idx = _items.indexWhere((i) => i.name == p.name && i.rate == p.price);
      if (idx >= 0) {
        _items[idx] = OrderItem(
          name: p.name,
          qty: _items[idx].qty + 1,
          rate: p.price,
        );
      } else {
        _items.add(OrderItem(name: p.name, qty: 1, rate: p.price));
      }
    });
  }

  /// Decreases a product's quantity by 1. Removes the line entirely once
  /// it hits 0, so the block goes back to its normal "tap to add" state.
  void _decreaseProductFromOrder(Product p) {
    setState(() {
      final idx = _items.indexWhere((i) => i.name == p.name && i.rate == p.price);
      if (idx < 0) return;
      final newQty = _items[idx].qty - 1;
      if (newQty <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx] = OrderItem(name: p.name, qty: newQty, rate: p.price);
      }
    });
  }

  /// Resets the dialog back to a blank slate so the next takeout order can
  /// be built without closing and reopening the dialog.
  void _resetForNewOrder() {
    setState(() {
      _items = [];
      _generatedBill = null;
      _customerNameCtrl.clear();
    });
  }

  bool _busyPrinting = false;

  Future<Bill?> _createDirectBill(List<OrderItem> validItems) async {
    try {
      final data = await ApiService.instance.createDirectBill(
        items: validItems
            .map((i) => {'name': i.name, 'qty': i.qty, 'rate': i.rate})
            .toList(),
        customerName: _customerNameCtrl.text.trim().isEmpty
            ? null
            : _customerNameCtrl.text.trim(),
      );
      return Bill.fromJson(data);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kRed),
        );
      }
      return null;
    }
  }

  /// 1. Print KOT Only (Sends Kitchen ticket to printer)
  Future<void> _handlePrintKOT() async {
    final validItems = _items
        .where((i) => i.name.trim().isNotEmpty && i.qty > 0)
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    setState(() => _busyPrinting = true);
    try {
      final bill = _generatedBill ?? await _createDirectBill(validItems);
      if (bill != null) {
        _generatedBill = bill;
        await PrintService.instance.printKitchenBill(bill);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('KOT sent to printer'),
              backgroundColor: kGreen,
            ),
          );
        }
      }
    } on PrintException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPrinting = false);
    }
  }

  /// 2. Print Bill Only (Generates bill, prints customer receipt, clears items for next customer)
  Future<void> _handlePrintBill() async {
    final validItems = _items
        .where((i) => i.name.trim().isNotEmpty && i.qty > 0)
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    setState(() => _busyPrinting = true);
    try {
      final bill = _generatedBill ?? await _createDirectBill(validItems);
      if (bill != null) {
        _generatedBill = bill;
        await ApiService.instance.markBillPaid(bill.id, paymentMethod: 'cash');
        await PrintService.instance.printBill(bill);
        _resetForNewOrder();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Bill #${bill.billNumber} printed & cleared for next customer!',
              ),
              backgroundColor: kGreen,
            ),
          );
        }
      }
    } on PrintException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPrinting = false);
    }
  }

  /// 3. KOT & Bill Combo (Generates bill, prints KOT + Customer Receipt, clears items for next customer)
  Future<void> _handleKOTAndBill() async {
    final validItems = _items
        .where((i) => i.name.trim().isNotEmpty && i.qty > 0)
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    setState(() => _busyPrinting = true);
    try {
      final bill = _generatedBill ?? await _createDirectBill(validItems);
      if (bill != null) {
        _generatedBill = bill;
        await ApiService.instance.markBillPaid(bill.id, paymentMethod: 'cash');
        await PrintService.instance.printBillWithKOT(bill);
        _resetForNewOrder();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'KOT & Bill #${bill.billNumber} printed & cleared for next customer!',
              ),
              backgroundColor: kGreen,
            ),
          );
        }
      }
    } on PrintException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 1160,
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: kOrange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_rounded, color: kWhite),
                  const SizedBox(width: 10),
                  const Text(
                    'Takeout Bill',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: kWhite),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Takeout Builder
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Customer Name (optional)',
                              style: TextStyle(
                                color: kTextGray,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _customerNameCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. Walk-in / Ravi',
                                hintStyle: const TextStyle(
                                  color: kTextGray,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: kBgGray,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'Order Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextDark,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ── Optional search to narrow the block grid below ──
                            TextField(
                              controller: _productSearchCtrl,
                              decoration: InputDecoration(
                                hintText:
                                    'Search products (optional) — or just tap a block below...',
                                hintStyle: const TextStyle(
                                  color: kTextGray,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: kTextGray,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: kBgGray,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (v) => setState(() => _productQuery = v),
                            ),
                            const SizedBox(height: 10),

                            // ── Tappable product blocks — browse & tap, no typing needed ──
                            Obx(() {
                              final products = _productController.products;
                              final q = _productQuery.toLowerCase();
                              final matches = q.isEmpty
                                  ? products
                                  : products
                                        .where((p) => p.name.toLowerCase().contains(q))
                                        .toList();

                              if (_productController.isLoading.value &&
                                  products.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(color: kOrange),
                                  ),
                                );
                              }

                              if (matches.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    products.isEmpty
                                        ? 'No products in catalog yet'
                                        : 'No products match "$_productQuery"',
                                    style: const TextStyle(
                                      color: kTextGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }

                              return Container(
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(maxHeight: 280),
                                decoration: BoxDecoration(
                                  color: kBgGray,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: matches
                                        .map(
                                          (p) => _TakeoutProductBlock(
                                            product: p,
                                            qtyInOrder: _items
                                                .where((i) => i.name == p.name && i.rate == p.price)
                                                .fold(0.0, (s, i) => s + i.qty),
                                            onTap: () => _addProductToOrder(p),
                                            onDecrease: () =>
                                                _decreaseProductFromOrder(p),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                const Text(
                                  'Bill Lines',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: kTextDark,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _items.add(
                                      OrderItem(name: '', qty: 1, rate: 0),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Custom Item'),
                                  style: TextButton.styleFrom(foregroundColor: kOrange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (_items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No items ordered yet — tap a product block above to add',
                                  style: TextStyle(color: kTextGray, fontSize: 13),
                                ),
                              )
                            else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: kBgGray,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        'Item Name',
                                        style: TextStyle(
                                          color: kTextGray,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        'Qty',
                                        style: TextStyle(
                                          color: kTextGray,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        'Rate (₹)',
                                        style: TextStyle(
                                          color: kTextGray,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        'Total',
                                        style: TextStyle(
                                          color: kTextGray,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 32),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...List.generate(
                                _items.length,
                                (i) => _TakeoutItemRow(
                                  key: ValueKey('takeout_item_$i-${_items[i].name}'),
                                  item: _items[i],
                                  onChanged: (item) => setState(() => _items[i] = item),
                                  onDelete: () => setState(() => _items.removeAt(i)),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: kLightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Order Total',
                                    style: TextStyle(
                                      color: kTextGray,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '₹${_subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: kTextDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (_generatedBill != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kGreen.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: kGreen,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Bill #${_generatedBill!.billNumber} generated. You can print again or start a new one.',
                                        style: const TextStyle(
                                          color: kGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Right Column: Live Thermal Receipt Preview
                    Container(
                      width: 340,
                      height: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kBgGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Switcher: [Receipt Preview] | [KOT Preview]
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _previewKOT = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: !_previewKOT ? kOrange : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Receipt Preview',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: !_previewKOT ? kWhite : kTextGray,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _previewKOT = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _previewKOT ? kPurple : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'KOT Preview',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _previewKOT ? kWhite : kTextGray,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            BillReceiptPreview(
                              customerName: _customerNameCtrl.text.trim(),
                              billNumber: _generatedBill?.billNumber,
                              items: _items,
                              subtotal: _subtotal,
                              grandTotal: _subtotal,
                              isKOT: _previewKOT,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_items.isNotEmpty) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPurple,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _busyPrinting ? null : _handlePrintKOT,
                      icon: const Icon(Icons.restaurant_rounded, size: 18),
                      label: const Text(
                        'Print KOT',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _busyPrinting ? null : _handlePrintBill,
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text(
                        'Print Bill',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _busyPrinting ? null : _handleKOTAndBill,
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text(
                        'KOT & Bill',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Product Block (tappable card, no typing needed) ──────────────────────────
// Same look & behavior as the table order dialog's product block: tap to add,
// then a − qty + control appears once it's on the bill.
class _TakeoutProductBlock extends StatelessWidget {
  final Product product;
  final double qtyInOrder;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  const _TakeoutProductBlock({
    required this.product,
    required this.qtyInOrder,
    required this.onTap,
    required this.onDecrease,
  });

  String get _qtyLabel => qtyInOrder == qtyInOrder.toInt()
      ? '${qtyInOrder.toInt()}'
      : '$qtyInOrder';

  @override
  Widget build(BuildContext context) {
    final inOrder = qtyInOrder > 0;
    return Container(
      width: 140,
      height: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: inOrder ? kOrange.withOpacity(0.10) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inOrder ? kOrange : kBgGray,
          width: inOrder ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        // Tapping anywhere else on the card (when not yet ordered) still adds it.
        onTap: inOrder ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kDarkBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!inOrder)
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(20),
                    child: const Icon(
                      Icons.add_circle_rounded,
                      color: kGreen,
                      size: 20,
                    ),
                  )
                else
                  // ── − qty + control, replaces the plain add icon once ordered ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onDecrease,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.remove_circle_rounded,
                              color: kRed,
                              size: 20,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _qtyLabel,
                            style: const TextStyle(
                              color: kOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.add_circle_rounded,
                              color: kGreen,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Takeout Item Row (same shape as the table dialog's row) ──────────────────
class _TakeoutItemRow extends StatefulWidget {
  final OrderItem item;
  final Function(OrderItem) onChanged;
  final VoidCallback onDelete;
  const _TakeoutItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_TakeoutItemRow> createState() => _TakeoutItemRowState();
}

class _TakeoutItemRowState extends State<_TakeoutItemRow> {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _qtyCtrl = TextEditingController(
      text: widget.item.qty == widget.item.qty.toInt()
          ? widget.item.qty.toInt().toString()
          : widget.item.qty.toString(),
    );
    _rateCtrl = TextEditingController(
      text: widget.item.rate == 0 ? '' : widget.item.rate.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(covariant _TakeoutItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the text fields in sync if the item was updated from outside
    // (e.g. tapping the same product block again bumps qty).
    if (oldWidget.item != widget.item) {
      final newQty = widget.item.qty == widget.item.qty.toInt()
          ? widget.item.qty.toInt().toString()
          : widget.item.qty.toString();
      if (_nameCtrl.text != widget.item.name) _nameCtrl.text = widget.item.name;
      if (_qtyCtrl.text != newQty) _qtyCtrl.text = newQty;
      final newRate = widget.item.rate == 0
          ? ''
          : widget.item.rate.toStringAsFixed(0);
      if (_rateCtrl.text != newRate) _rateCtrl.text = newRate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      OrderItem(
        name: _nameCtrl.text,
        qty: double.tryParse(_qtyCtrl.text) ?? 1,
        rate: double.tryParse(_rateCtrl.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total =
        (double.tryParse(_qtyCtrl.text) ?? 0) *
        (double.tryParse(_rateCtrl.text) ?? 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: _nameCtrl,
              onChanged: (_) => _notify(),
              decoration: _inputDec('Item name'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _qtyCtrl,
              onChanged: (_) {
                _notify();
                setState(() {});
              },
              decoration: _inputDec('1'),
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _rateCtrl,
              onChanged: (_) {
                _notify();
                setState(() {});
              },
              decoration: _inputDec('0.00'),
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: kLightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: kDarkBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(
                Icons.remove_circle_rounded,
                color: kRed,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextGray, fontSize: 12),
    filled: true,
    fillColor: kBgGray,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );
}
