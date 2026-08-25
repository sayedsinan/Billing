import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/table_controller.dart';
import 'package:test_bill/controller/product_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/models/table_model.dart';
import 'package:test_bill/models/product_model.dart';
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/service/print_service.dart';
import 'package:test_bill/theme/colors.dart';
import 'package:test_bill/view/billing/takeout_bill_dialog.dart';

// ─── Table Order Page ──────────────────────────────────────────────────────────
class TableOrderPage extends StatefulWidget {
  const TableOrderPage({super.key});

  @override
  State<TableOrderPage> createState() => _TableOrderPageState();
}

class _TableOrderPageState extends State<TableOrderPage> {
  String _search = '';
  TableStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TableController>();

    return Scaffold(
      backgroundColor: kBgGray,
      body: Obx(() {
        final tables = controller.tables;
        final loading = controller.isLoading.value;
        final err = controller.error.value;

        final filtered = tables.where((t) {
          final q = _search.toLowerCase();
          final matchSearch = q.isEmpty ||
              t.tableId.toLowerCase().contains(q) ||
              (t.waiter ?? '').toLowerCase().contains(q);
          final matchStatus = _filterStatus == null || t.status == _filterStatus;
          return matchSearch && matchStatus;
        }).toList()
          ..sort((a, b) => a.tableId.compareTo(b.tableId));

        final empty = tables.where((t) => t.status == TableStatus.empty).length;
        final occupied = tables.where((t) => t.status == TableStatus.occupied).length;
        final reserved = tables.where((t) => t.status == TableStatus.reserved).length;
        final billing = tables.where((t) => t.status == TableStatus.billing).length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary cards ────────────────────────────────────────────
              Row(
                children: [
                  _SummaryCard('Total Tables', '${tables.length}', Icons.table_restaurant_rounded, kBlue),
                  const SizedBox(width: 16),
                  _SummaryCard('Empty', '$empty', Icons.event_available_rounded, kGreen),
                  const SizedBox(width: 16),
                  _SummaryCard('Occupied', '$occupied', Icons.people_alt_rounded, kOrange),
                  const SizedBox(width: 16),
                  _SummaryCard('Reserved', '$reserved', Icons.bookmark_rounded, kPurple),
                  const SizedBox(width: 16),
                  _SummaryCard('Billing', '$billing', Icons.receipt_long_rounded, kRed),
                ],
              ),

              const SizedBox(height: 24),

              // ── Toolbar ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by table number or waiter...',
                          hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                          filled: true,
                          fillColor: kBgGray,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _FilterChip('All', _filterStatus == null, () => setState(() => _filterStatus = null)),
                    const SizedBox(width: 6),
                    _FilterChip('Empty', _filterStatus == TableStatus.empty, () => setState(() => _filterStatus = TableStatus.empty), color: kGreen),
                    const SizedBox(width: 6),
                    _FilterChip('Occupied', _filterStatus == TableStatus.occupied, () => setState(() => _filterStatus = TableStatus.occupied), color: kOrange),
                    const SizedBox(width: 6),
                    _FilterChip('Reserved', _filterStatus == TableStatus.reserved, () => setState(() => _filterStatus = TableStatus.reserved), color: kPurple),
                    const SizedBox(width: 6),
                    _FilterChip('Billing', _filterStatus == TableStatus.billing, () => setState(() => _filterStatus = TableStatus.billing), color: kRed),
                    const SizedBox(width: 6),
                    _FilterChip('Cleaning', _filterStatus == TableStatus.cleaning, () => setState(() => _filterStatus = TableStatus.cleaning), color: kTextGray),
                    const Spacer(),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kBlue)),
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: kWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Table', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => _addTable(context, controller),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kOrange,
                        side: const BorderSide(color: kOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                      label: const Text('Takeout Bill', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const TakeoutBillDialog(),
                      ),
                    ),
                  ],
                ),
              ),

              if (err.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: kRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(err, style: const TextStyle(color: kRed, fontSize: 12))),
                      TextButton(
                        onPressed: () => controller.fetchTables(),
                        child: const Text('Retry', style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ),

              const SizedBox(height: 16),

              // ── Table grid ───────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: kBlue,
                  onRefresh: () => controller.fetchTables(),
                  child: loading && tables.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: kBlue))
                      : filtered.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.table_restaurant_outlined, color: kTextGray, size: 48),
                                    SizedBox(height: 12),
                                    Text('No tables found', style: TextStyle(color: kTextGray, fontSize: 15)),
                                  ],
                                ),
                              ),
                            ])
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.15,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) => _TableCard(
                                table: filtered[i],
                                onTap: () => _openTable(context, controller, filtered[i]),
                                onDelete: () => _confirmDelete(context, controller, filtered[i]),
                                onPrint: () => _printTableBill(context, filtered[i]),
                              ),
                            ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _addTable(BuildContext ctx, TableController controller) async {
    final idCtrl = TextEditingController();
    final seatsCtrl = TextEditingController(text: '4');
    await showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Table', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: idCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Table label (e.g. T9)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: seatsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Seats'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          Obx(() => ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: kWhite, elevation: 0),
                onPressed: controller.isSaving.value
                    ? null
                    : () async {
                        final label = idCtrl.text.trim();
                        if (label.isEmpty) return;
                        final seats = int.tryParse(seatsCtrl.text) ?? 4;
                        final ok = await controller.addTable(label, seats);
                        if (ok && dialogCtx.mounted) Navigator.pop(dialogCtx);
                      },
                child: controller.isSaving.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                    : const Text('Add'),
              )),
        ],
      ),
    );
  }

  void _openTable(BuildContext ctx, TableController controller, DiningTable table) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => TableOrderDialog(table: table, controller: controller),
    );
  }

  /// Fetches this table's most recent bill and sends it straight to the
  /// printer — no dialog needed. Used by the print icon on each table card.
  Future<void> _printTableBill(BuildContext ctx, DiningTable table) async {
    try {
      final data = await ApiService.instance.getBills(tableId: table.id);
      if (data.isEmpty) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('No bill found for this table yet. Generate one first.')),
          );
        }
        return;
      }
      final bills = data.map((e) => Bill.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = bills.first;

      await PrintService.instance.printBill(latest);

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Bill #${latest.billNumber} sent to printer'), backgroundColor: kGreen),
        );
      }
    } on ApiException catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: kRed));
      }
    } on PrintException catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: kRed));
      }
    }
  }

  void _confirmDelete(BuildContext ctx, TableController controller, DiningTable table) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Table?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Table ${table.tableId} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: kWhite, elevation: 0),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await controller.removeTable(table.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────
Widget _SummaryCard(String label, String value, IconData icon, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: kTextGray, fontSize: 11)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(color: kTextDark, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
Widget _FilterChip(String label, bool active, VoidCallback onTap, {Color color = kBlue}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : kBgGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? color : Colors.transparent),
      ),
      child: Text(label, style: TextStyle(color: active ? color : kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

// ─── Table Card ───────────────────────────────────────────────────────────────
class _TableCard extends StatefulWidget {
  final DiningTable table;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<void> Function() onPrint;
  const _TableCard({
    required this.table,
    required this.onTap,
    required this.onDelete,
    required this.onPrint,
  });

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  bool _printing = false;

  Color get _color => switch (widget.table.status) {
    TableStatus.empty => kGreen,
    TableStatus.occupied => kOrange,
    TableStatus.reserved => kPurple,
    TableStatus.billing => kRed,
    TableStatus.cleaning => kTextGray,
  };

  String get _label => switch (widget.table.status) {
    TableStatus.empty => 'Empty',
    TableStatus.occupied => 'Occupied',
    TableStatus.reserved => 'Reserved',
    TableStatus.billing => 'Billing',
    TableStatus.cleaning => 'Cleaning',
  };

  String? get _timeStr {
    if (widget.table.occupiedSince == null) return null;
    final diff = DateTime.now().difference(widget.table.occupiedSince!);
    return diff.inHours >= 1 ? '${diff.inHours}h ${diff.inMinutes % 60}m' : '${diff.inMinutes}m';
  }

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    await widget.onPrint();
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onDelete,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withOpacity(0.35), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_restaurant_rounded, color: _color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(table.tableId,
                      style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                ),
                if (table.items.isNotEmpty) ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: _printing
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(strokeWidth: 2, color: kBlue),
                          )
                        : IconButton(
                            onPressed: _handlePrint,
                            icon: const Icon(Icons.print_rounded, size: 16, color: kBlue),
                            tooltip: 'Print last bill',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(_label, style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${table.seats} seats', style: const TextStyle(color: kTextGray, fontSize: 12)),
            const Spacer(),
            if (table.waiter != null)
              Text('Waiter: ${table.waiter}', style: const TextStyle(color: kTextGray, fontSize: 11)),
            if (table.items.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${table.items.length} item${table.items.length > 1 ? 's' : ''} · ₹${table.subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
            if (_timeStr != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: kTextGray),
                  const SizedBox(width: 3),
                  Text(_timeStr!, style: const TextStyle(color: kTextGray, fontSize: 11)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Table Order Dialog (view + edit order + status) ──────────────────────────
class TableOrderDialog extends StatefulWidget {
  final DiningTable table;
  final TableController controller;
  const TableOrderDialog({super.key, required this.table, required this.controller});

  @override
  State<TableOrderDialog> createState() => _TableOrderDialogState();
}

class _TableOrderDialogState extends State<TableOrderDialog> {
  late TextEditingController _waiterCtrl;
  late TextEditingController _seatsCtrl;
  late List<OrderItem> _items;
  late TableStatus _status;
  DateTime? _occupiedSince;
  bool _generatingBill = false;
  bool _printing = false;

  /// Set once "Generate Bill" succeeds. While this is non-null the footer
  /// switches from "Generate Bill" to "Print Bill" / "New Bill".
  Bill? _generatedBill;

  // ── Product picker (tap a block → add straight to the bill) ──
  final ProductController _productController = Get.find<ProductController>();
  final TextEditingController _productSearchCtrl = TextEditingController();
  String _productQuery = '';

  @override
  void initState() {
    super.initState();
    _waiterCtrl = TextEditingController(text: widget.table.waiter ?? '');
    _seatsCtrl = TextEditingController(text: widget.table.seats.toString());
    _items = widget.table.items.map((i) => OrderItem(name: i.name, qty: i.qty, rate: i.rate)).toList();
    _status = widget.table.status;
    _occupiedSince = widget.table.occupiedSince;

    // Make sure the product catalog is loaded so the block grid has data.
    if (_productController.products.isEmpty) {
      _productController.fetchProducts();
    }
  }

  @override
  void dispose() {
    _waiterCtrl.dispose();
    _seatsCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (s, i) => s + i.total);

  /// Adds a product from the catalog to the current order immediately.
  /// If the product is already on the bill, its quantity is bumped by 1
  /// instead of creating a duplicate line.
  void _addProductToOrder(Product p) {
    setState(() {
      final idx = _items.indexWhere((i) => i.name == p.name);
      if (idx >= 0) {
        _items[idx] = OrderItem(name: p.name, qty: _items[idx].qty + 1, rate: p.price);
      } else {
        _items.add(OrderItem(name: p.name, qty: 1, rate: p.price));
      }
    });
  }

  /// Decreases a product's quantity by 1. Removes the line entirely once
  /// it hits 0, so the block goes back to its normal "tap to add" state.
  void _decreaseProductFromOrder(Product p) {
    setState(() {
      final idx = _items.indexWhere((i) => i.name == p.name);
      if (idx < 0) return;
      final newQty = _items[idx].qty - 1;
      if (newQty <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx] = OrderItem(name: p.name, qty: newQty, rate: p.price);
      }
    });
  }

  Future<void> _save() async {
    if (_status != TableStatus.empty && _status != TableStatus.cleaning && _waiterCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assign a waiter'), backgroundColor: kRed));
      return;
    }
    final updated = widget.table.copyWith(
      seats: int.tryParse(_seatsCtrl.text) ?? widget.table.seats,
      status: _status,
      waiter: _waiterCtrl.text.trim().isEmpty ? null : _waiterCtrl.text.trim(),
      clearWaiter: _waiterCtrl.text.trim().isEmpty,
      items: _items.where((i) => i.name.trim().isNotEmpty).toList(),
      occupiedSince: _status == TableStatus.empty ? null : (_occupiedSince ?? DateTime.now()),
      clearOccupiedSince: _status == TableStatus.empty,
    );
    final ok = await widget.controller.saveTable(updated);
    if (ok && mounted) Navigator.pop(context);
  }

  /// Generates the bill on the server, then immediately sends it to the
  /// thermal printer. The dialog stays open afterwards so the user can
  /// re-print, or tap "New Bill" to close and start the next order.
  Future<void> _generateBill() async {
    setState(() => _generatingBill = true);
    final bill = await widget.controller.generateBill(widget.table.id);
    setState(() {
      _generatingBill = false;
      _generatedBill = bill;
    });

    if (bill == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bill generated · Total ₹${bill.grandTotal.toStringAsFixed(2)}'), backgroundColor: kGreen),
    );

    // Auto-print right away; the Print Bill button lets them reprint if needed.
    await _printBill(bill);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  /// Resets the dialog back to a blank order for this table so the next
  /// customer can be served immediately, without closing and reopening it.
  /// (Previously this just called Navigator.pop, which closed the dialog
  /// but left it looking like nothing happened.)
  void _startNewBill() {
    setState(() {
      _items = [];
      _generatedBill = null;
      _waiterCtrl.clear();
      _occupiedSince = null;
      _status = TableStatus.empty;
    });
    // Refresh the table list in the background so the card behind this
    // dialog reflects the now-billed table (status/items cleared server-side
    // by generateBill).
    widget.controller.fetchTables();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 820,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(color: kBlue, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(
                children: [
                  const Icon(Icons.table_restaurant_rounded, color: kWhite),
                  const SizedBox(width: 10),
                  Text('Table ${widget.table.tableId}', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kWhite), padding: EdgeInsets.zero),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Items', style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 14)),
                    const SizedBox(height: 8),

                    // ── Optional search to narrow the block grid below ──
                    TextField(
                      controller: _productSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search products (optional) — or just tap a block below...',
                        hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                        filled: true,
                        fillColor: kBgGray,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                          : products.where((p) => p.name.toLowerCase().contains(q)).toList();

                      if (_productController.isLoading.value && products.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator(color: kBlue)),
                        );
                      }

                      if (matches.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            products.isEmpty ? 'No products in catalog yet' : 'No products match "$_productQuery"',
                            style: const TextStyle(color: kTextGray, fontSize: 12),
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxHeight: 320),
                        decoration: BoxDecoration(
                          color: kBgGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: matches.map((p) => _ProductBlock(
                              product: p,
                              qtyInOrder: _items
                                  .where((i) => i.name == p.name)
                                  .fold(0.0, (s, i) => s + i.qty),
                              onTap: () => _addProductToOrder(p),
                              onDecrease: () => _decreaseProductFromOrder(p),
                            )).toList(),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(child: _Field('Seats', _seatsCtrl, hint: '4', keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _Field('Waiter', _waiterCtrl, hint: 'e.g. Anil')),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Status', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<TableStatus>(
                                value: _status,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: kBgGray,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                                items: TableStatus.values.map((s) {
                                  final l = switch (s) {
                                    TableStatus.empty => 'Empty',
                                    TableStatus.occupied => 'Occupied',
                                    TableStatus.reserved => 'Reserved',
                                    TableStatus.billing => 'Billing',
                                    TableStatus.cleaning => 'Cleaning',
                                  };
                                  return DropdownMenuItem(value: s, child: Text(l, style: const TextStyle(fontSize: 13)));
                                }).toList(),
                                onChanged: (s) => setState(() {
                                  _status = s!;
                                  if (_status != TableStatus.empty) _occupiedSince ??= DateTime.now();
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                        child: Text('No items ordered yet — tap a product block above to add', style: TextStyle(color: kTextGray, fontSize: 13)),
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
                      ...List.generate(_items.length, (i) => _OrderItemRow(
                        key: ValueKey('item_$i-${_items[i].name}'),
                        item: _items[i],
                        onChanged: (item) => setState(() => _items[i] = item),
                        onDelete: () => setState(() => _items.removeAt(i)),
                      )),
                    ],

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: kLightBlue, borderRadius: BorderRadius.circular(12)),
                      child: _TotalRow('Order Total', '₹${_subtotal.toStringAsFixed(2)}', bold: true, large: true),
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
                                'Bill #${_generatedBill!.billNumber} generated. You can print again or start a new bill.',
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
                  if (widget.table.id.isNotEmpty && _items.isNotEmpty && _status != TableStatus.empty) ...[
                    if (_generatedBill == null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kGreen,
                          side: const BorderSide(color: kGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _generatingBill ? null : _generateBill,
                        icon: _generatingBill
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kGreen))
                            : const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('Generate Bill', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        label: const Text('Print Bill', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kOrange,
                          side: const BorderSide(color: kOrange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _startNewBill,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('New Bill', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Obx(() => ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBlue, foregroundColor: kWhite, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: widget.controller.isSaving.value
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: widget.controller.isSaving.value ? null : _save,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _TotalRow(String label, String value, {Color? color, bool bold = false, bool large = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: kTextGray, fontSize: large ? 14 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        Text(value, style: TextStyle(color: color ?? (bold ? kTextDark : kTextGray), fontSize: large ? 16 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ],
    ),
  );
}

// ─── Product Block (tappable card, no typing needed) ──────────────────────────
class _ProductBlock extends StatelessWidget {
  final Product product;
  final double qtyInOrder;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  const _ProductBlock({
    required this.product,
    required this.qtyInOrder,
    required this.onTap,
    required this.onDecrease,
  });

  String get _qtyLabel => qtyInOrder == qtyInOrder.toInt() ? '${qtyInOrder.toInt()}' : '$qtyInOrder';

  @override
  Widget build(BuildContext context) {
    final inOrder = qtyInOrder > 0;
    return Container(
      width: 140,
      height: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: inOrder ? kBlue.withOpacity(0.10) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inOrder ? kBlue : kBgGray, width: inOrder ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, color: kDarkBlue, fontWeight: FontWeight.w700)),
                if (!inOrder)
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(20),
                    child: const Icon(Icons.add_circle_rounded, color: kGreen, size: 20),
                  )
                else
                  // ── − qty + control, replaces the plain add icon once ordered ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onDecrease,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.remove_circle_rounded, color: kRed, size: 20),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(_qtyLabel,
                              style: const TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.add_circle_rounded, color: kGreen, size: 20),
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

// ─── Order Item Row ────────────────────────────────────────────────────────────
class _OrderItemRow extends StatefulWidget {
  final OrderItem item;
  final Function(OrderItem) onChanged;
  final VoidCallback onDelete;
  const _OrderItemRow({super.key, required this.item, required this.onChanged, required this.onDelete});

  @override
  State<_OrderItemRow> createState() => _OrderItemRowState();
}

class _OrderItemRowState extends State<_OrderItemRow> {
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
  void didUpdateWidget(covariant _OrderItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the text fields in sync if the item was updated from outside
    // (e.g. tapping the same product block again bumps qty).
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

// ─── Field Helper ─────────────────────────────────────────────────────────────
Widget _Field(String label, TextEditingController ctrl, {
  String hint = '',
  TextInputType keyboardType = TextInputType.text,
  Function(String)? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
          filled: true,
          fillColor: kBgGray,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue, width: 1.5)),
        ),
      ),
    ],
  );
}