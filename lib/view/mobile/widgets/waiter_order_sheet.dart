import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/controller/table_controller.dart';
import 'package:test_bill/core/constants/colors.dart';
import 'package:test_bill/models/table_model.dart';
import 'package:test_bill/service/print_service.dart';
import 'package:test_bill/view/widgets/bill_receipt_preview.dart';

class WaiterOrderSheet extends StatefulWidget {
  final DiningTable table;

  const WaiterOrderSheet({super.key, required this.table});

  @override
  State<WaiterOrderSheet> createState() => _WaiterOrderSheetState();
}

class _WaiterOrderSheetState extends State<WaiterOrderSheet> {
  final TableController _tableController = Get.find<TableController>();
  final AuthController _authController = Get.find<AuthController>();

  late List<OrderItem> _items;
  late TextEditingController _waiterController;
  bool _isSubmitting = false;
  bool _isPrintingKOT = false;
  int _viewMode = 0; // 0: Edit Items, 1: Receipt Preview, 2: KOT Preview

  @override
  void initState() {
    super.initState();
    _items = widget.table.items.map((i) => OrderItem(name: i.name, qty: i.qty, rate: i.rate)).toList();
    final loggedInUser = _authController.currentUser.value?['name']?.toString();
    _waiterController = TextEditingController(
      text: widget.table.waiter ?? loggedInUser ?? 'Waiter 1',
    );
  }

  @override
  void dispose() {
    _waiterController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.total);

  void _updateQuantity(int index, double delta) {
    setState(() {
      final updated = _items[index].qty + delta;
      if (updated <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].qty = updated;
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_items.isEmpty) {
      Get.snackbar('Cart Empty', 'Please add items before submitting order', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isSubmitting = true);

    final updatedTable = widget.table.copyWith(
      status: widget.table.status == TableStatus.empty ? TableStatus.occupied : widget.table.status,
      waiter: _waiterController.text.trim(),
      items: _items,
      occupiedSince: widget.table.occupiedSince ?? DateTime.now(),
    );

    final success = await _tableController.saveTable(updatedTable);

    if (success) {
      // Auto-trigger KOT print on order submit
      try {
        await PrintService.instance.printKOT(
          tableId: widget.table.tableId,
          waiter: _waiterController.text.trim(),
          items: _items,
        );
      } catch (e) {
        debugPrint("Auto-print KOT note: $e");
      }

      if (mounted) Navigator.pop(context, _items);
      Get.snackbar(
        'Order Sent & KOT Printed',
        'Order for Table ${widget.table.tableId} sent to Kitchen & Billing Desk!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.kGreen,
        colorText: Colors.white,
      );
    } else {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _printKOT() async {
    if (_items.isEmpty) {
      Get.snackbar('Cart Empty', 'Please add items before printing KOT', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isPrintingKOT = true);

    try {
      // Sync table order with central backend
      final updatedTable = widget.table.copyWith(
        status: widget.table.status == TableStatus.empty ? TableStatus.occupied : widget.table.status,
        waiter: _waiterController.text.trim(),
        items: _items,
        occupiedSince: widget.table.occupiedSince ?? DateTime.now(),
      );
      await _tableController.saveTable(updatedTable);

      // Invoke KOT printer service
      await PrintService.instance.printKOT(
        tableId: widget.table.tableId,
        waiter: _waiterController.text.trim(),
        items: _items,
      );

      final isMobile = !GetPlatform.isWindows;
      Get.snackbar(
        isMobile ? 'KOT Dispatched' : 'KOT Printed',
        isMobile
            ? 'Order for Table ${widget.table.tableId} sent to Kitchen & Billing Desk!'
            : 'Kitchen Order Ticket sent to printer for Table ${widget.table.tableId}!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Print Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isPrintingKOT = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        Navigator.pop(context, _items);
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: AppColors.kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header handle
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),

            // Title & Table info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.kBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.kBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table ${widget.table.tableId} Order',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kTextDark,
                          ),
                        ),
                        Text(
                          '${_items.length} items • Subtotal: ₹${_subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.kSubtext),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _items),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // View Mode Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.kBgGray,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == 0 ? AppColors.kBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Order Items',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _viewMode == 0 ? Colors.white : AppColors.kSubtext,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == 1 ? AppColors.kBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Bill Preview',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _viewMode == 1 ? Colors.white : AppColors.kSubtext,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == 2 ? Colors.purple : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'KOT Preview',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _viewMode == 2 ? Colors.white : AppColors.kSubtext,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Waiter Name Input (only show on Order Items tab)
          if (_viewMode == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _waiterController,
                decoration: InputDecoration(
                  labelText: 'Assigned Waiter',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

          if (_viewMode == 0) const SizedBox(height: 12),

          // Main View Content
          Expanded(
            child: _viewMode > 0
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Center(
                      child: BillReceiptPreview(
                        tableId: widget.table.tableId,
                        waiter: _waiterController.text.trim(),
                        items: _items,
                        subtotal: _subtotal,
                        grandTotal: _subtotal,
                        isKOT: _viewMode == 2,
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.remove_shopping_cart_rounded, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No items added to this table yet',
                              style: TextStyle(color: AppColors.kSubtext, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.kBgGray,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.kTextDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${item.rate.toStringAsFixed(2)} each',
                                        style: const TextStyle(fontSize: 12, color: AppColors.kSubtext),
                                      ),
                                    ],
                                  ),
                                ),

                                // Quantity Selector
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.remove_rounded, size: 16, color: AppColors.kRed),
                                        onPressed: () => _updateQuantity(i, -1),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '${item.qty.toInt()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.kGreen),
                                        onPressed: () => _updateQuantity(i, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Total
                                SizedBox(
                                  width: 65,
                                  child: Text(
                                    '₹${item.total.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.kBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(fontSize: 14, color: AppColors.kSubtext),
                    ),
                    Text(
                      '₹${_subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Print KOT Button
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: (_isSubmitting || _isPrintingKOT) ? null : _printKOT,
                          icon: _isPrintingKOT
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade800),
                                )
                              : const Icon(Icons.print_rounded, size: 20),
                          label: Text(
                            _isPrintingKOT ? 'Printing...' : 'Print KOT',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Send Order Button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: (_isSubmitting || _isPrintingKOT) ? null : _submitOrder,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(
                            _isSubmitting ? 'Sending...' : 'Send Order',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      )
    );
  }
}
