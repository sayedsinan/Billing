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

/// A takeout / counter bill: no table involved. Search the product catalog,
/// tap to add, generate + print directly via ApiService.createDirectBill.
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

  void _addProductToOrder(Product p) {
    setState(() {
      final idx = _items.indexWhere((i) => i.name == p.name);
      if (idx >= 0) {
        _items[idx] = OrderItem(name: p.name, qty: _items[idx].qty + 1, rate: p.price);
      } else {
        _items.add(OrderItem(name: p.name, qty: 1, rate: p.price));
      }
      _productSearchCtrl.clear();
      _productQuery = '';
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

  Future<void> _generateAndPrint() async {
    final validItems = _items.where((i) => i.name.trim().isNotEmpty && i.qty > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item'), backgroundColor: kRed),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final data = await ApiService.instance.createDirectBill(
        items: validItems
            .map((i) => {'name': i.name, 'qty': i.qty, 'rate': i.rate})
            .toList(),
        customerName: _customerNameCtrl.text.trim().isEmpty ? null : _customerNameCtrl.text.trim(),
      );
      final bill = Bill.fromJson(data);
      setState(() {
        _generating = false;
        _generatedBill = bill;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill generated · Total ₹${bill.grandTotal.toStringAsFixed(2)}'), backgroundColor: kGreen),
      );

      await _printBill(bill);
    } on ApiException catch (e) {
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: kRed));
      }
    }
  }

  Future<void> _printBill(Bill bill) async {
    setState(() => _printing = true);
    try {
      await PrintService.instance.printBill(bill);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent to printer'), backgroundColor: kGreen),
        );
      }
    } on PrintException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(color: kOrange, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_rounded, color: kWhite),
                  const SizedBox(width: 10),
                  const Text('Takeout Bill', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kWhite), padding: EdgeInsets.zero),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer Name (optional)', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _customerNameCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Walk-in / Ravi',
                            hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                            filled: true,
                            fillColor: kBgGray,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text('Order Items', style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 14)),
                    const SizedBox(height: 8),

                    // ── Search products, tap to add straight to the bill ──
                    TextField(
                      controller: _productSearchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search products to add to bill...',
                        hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                        filled: true,
                        fillColor: kBgGray,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setState(() => _productQuery = v),
                    ),
                    if (_productQuery.trim().isNotEmpty)
                      Obx(() {
                        final q = _productQuery.toLowerCase();
                        final matches = _productController.products
                            .where((p) => p.name.toLowerCase().contains(q))
                            .take(6)
                            .toList();
                        if (matches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No products match "$_productQuery"',
                                style: const TextStyle(color: kTextGray, fontSize: 12)),
                          );
                        }
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBgGray, width: 1.5),
                          ),
                          child: Column(
                            children: matches.map((p) {
                              return InkWell(
                                onTap: () => _addProductToOrder(p),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(p.name,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
                                      ),
                                      Text('₹${p.price.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.add_circle_rounded, color: kGreen, size: 18),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Text('Bill Lines', style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 13)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() => _items.add(OrderItem(name: '', qty: 1, rate: 0))),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Custom Item'),
                          style: TextButton.styleFrom(foregroundColor: kBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No items yet — search above to add products', style: TextStyle(color: kTextGray, fontSize: 13)),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Expanded(flex: 5, child: Text('Item Name', style: TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w600))),
                            SizedBox(width: 8),
                            SizedBox(width: 70, child: Text('Qty', style: TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w600))),
                            SizedBox(width: 8),
                            SizedBox(width: 90, child: Text('Rate (₹)', style: TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w600))),
                            SizedBox(width: 8),
                            SizedBox(width: 90, child: Text('Total', style: TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w600))),
                            SizedBox(width: 32),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(_items.length, (i) => _TakeoutItemRow(
                        key: ValueKey('takeout_item_$i-${_items[i].name}'),
                        item: _items[i],
                        onChanged: (item) => setState(() => _items[i] = item),
                        onDelete: () => setState(() => _items.removeAt(i)),
                      )),
                    ],

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: kLightBlue, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Order Total', style: TextStyle(color: kTextGray, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('₹${_subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(color: kTextDark, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),

                    if (_generatedBill != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: kGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: kGreen, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bill #${_generatedBill!.billNumber} generated. You can print again or start a new one.',
                                style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w600),
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

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_generatedBill == null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _generating ? null : _generateAndPrint,
                      icon: _generating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                          : const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Generate & Print', style: TextStyle(fontWeight: FontWeight.w600)),
                    )
                  else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kBlue,
                        side: const BorderSide(color: kBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _printing ? null : () => _printBill(_generatedBill!),
                      icon: _printing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kBlue))
                          : const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Again', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _resetForNewOrder,
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('New Bill', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
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

// ─── Takeout Item Row (same shape as the table dialog's row) ──────────────────
class _TakeoutItemRow extends StatefulWidget {
  final OrderItem item;
  final Function(OrderItem) onChanged;
  final VoidCallback onDelete;
  const _TakeoutItemRow({super.key, required this.item, required this.onChanged, required this.onDelete});

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
    _qtyCtrl = TextEditingController(text: widget.item.qty == widget.item.qty.toInt() ? widget.item.qty.toInt().toString() : widget.item.qty.toString());
    _rateCtrl = TextEditingController(text: widget.item.rate == 0 ? '' : widget.item.rate.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(covariant _TakeoutItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      final newQty = widget.item.qty == widget.item.qty.toInt()
          ? widget.item.qty.toInt().toString()
          : widget.item.qty.toString();
      if (_nameCtrl.text != widget.item.name) _nameCtrl.text = widget.item.name;
      if (_qtyCtrl.text != newQty) _qtyCtrl.text = newQty;
      final newRate = widget.item.rate == 0 ? '' : widget.item.rate.toStringAsFixed(0);
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
    widget.onChanged(OrderItem(
      name: _nameCtrl.text,
      qty: double.tryParse(_qtyCtrl.text) ?? 1,
      rate: double.tryParse(_rateCtrl.text) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final total = (double.tryParse(_qtyCtrl.text) ?? 0) * (double.tryParse(_rateCtrl.text) ?? 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(controller: _nameCtrl, onChanged: (_) => _notify(), decoration: _inputDec('Item name'), style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _qtyCtrl,
              onChanged: (_) { _notify(); setState(() {}); },
              decoration: _inputDec('1'),
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _rateCtrl,
              onChanged: (_) { _notify(); setState(() {}); },
              decoration: _inputDec('0.00'),
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: kLightBlue, borderRadius: BorderRadius.circular(10)),
              child: Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: kDarkBlue, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.remove_circle_rounded, color: kRed, size: 20),
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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  );
}