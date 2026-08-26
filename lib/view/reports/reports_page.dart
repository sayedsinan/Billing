import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/theme/colors.dart';

// ─── Reports Page — today's orders, reprint & delete ──────────────────────────
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _selectedDate = DateTime.now();
  String _search = '';
  BillStatus? _filterStatus;

  DateTime get _dayStart => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  DateTime get _dayEnd => _dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<BillController>()) {
      Get.put(BillController());
    }
    _load();
  }

  void _load() {
    Get.find<BillController>().fetchBills(from: _dayStart, to: _dayEnd);
  }

  void _changeDay(int deltaDays) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: deltaDays)));
    _load();
  }

  void _goToday() {
    setState(() => _selectedDate = DateTime.now());
    _load();
  }

  String get _dateLabel {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  static String formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h24 = local.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$mm $ampm';
  }

  void _openDetail(BuildContext ctx, BillController controller, Bill bill) {
    showDialog(
      context: ctx,
      builder: (_) => _BillDetailDialog(bill: bill, controller: controller),
    );
  }

  void _confirmDelete(BuildContext ctx, BillController controller, Bill bill) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete order?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Bill #${bill.billNumber} (₹${bill.grandTotal.toStringAsFixed(0)}) will be permanently removed. '
          'This also updates today\'s revenue on the dashboard.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: kWhite, elevation: 0),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await controller.deleteBill(bill.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BillController>();

    return Scaffold(
      backgroundColor: kBgGray,
      body: Obx(() {
        final allBills = controller.bills;
        final loading = controller.isLoadingBills.value;
        final deleting = controller.isDeleting.value;

        final filtered = allBills.where((b) {
          final q = _search.toLowerCase();
          final matchSearch = q.isEmpty ||
              b.billNumber.toLowerCase().contains(q) ||
              (b.customerName ?? '').toLowerCase().contains(q) ||
              (b.waiter ?? '').toLowerCase().contains(q) ||
              (b.tableId ?? '').toLowerCase().contains(q);
          final matchStatus = _filterStatus == null || b.status == _filterStatus;
          return matchSearch && matchStatus;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final pendingCount = allBills.where((b) => b.status == BillStatus.pending || b.status == BillStatus.unpaid).length;
        final cancelledCount = allBills.where((b) => b.status == BillStatus.cancelled).length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: title + date navigator ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: -0.3)),
                  const SizedBox(width: 10),
                  Text(
                    '${allBills.length} order${allBills.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, color: kTextGray, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  _DateNav(
                    label: _dateLabel,
                    isToday: _isToday,
                    onPrev: () => _changeDay(-1),
                    onNext: _isToday ? null : () => _changeDay(1),
                    onToday: _isToday ? null : _goToday,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2, color: kBlue),
                          )
                        : IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded, size: 20, color: kTextGray),
                            tooltip: 'Refresh',
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(backgroundColor: kWhite, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Summary strip ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    _StatCell('Revenue', '₹${controller.totalRevenue.value.toStringAsFixed(0)}', kGreen, filled: true),
                    _statDivider(),
                    _StatCell('Orders', '${allBills.length}', kBlue),
                    _statDivider(),
                    _StatCell('Pending', '$pendingCount', kOrange),
                    _statDivider(),
                    _StatCell('Cancelled', '$cancelledCount', kTextGray),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Toolbar ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(11)),
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search bill no, table, customer, waiter…',
                          hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusFilterBar(
                    selected: _filterStatus,
                    onSelect: (s) => setState(() => _filterStatus = s),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Bill list ────────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: kBlue,
                  onRefresh: () async => _load(),
                  child: loading && allBills.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: kBlue))
                      : filtered.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 90),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, color: kTextGray, size: 44),
                                    SizedBox(height: 12),
                                    Text('No orders for this day', style: TextStyle(color: kTextGray, fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) => _BillRow(
                                bill: filtered[i],
                                deleting: deleting,
                                onTap: () => _openDetail(ctx, controller, filtered[i]),
                                onPrint: () async {
                                  final ok = await controller.printBill(filtered[i]);
                                  if (ok && ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Sent to printer'), backgroundColor: kGreen),
                                    );
                                  }
                                },
                                onDelete: () => _confirmDelete(ctx, controller, filtered[i]),
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

  Widget _statDivider() => Container(width: 1, height: 40, color: kBgGray);
}

// ─── Date navigator ─────────────────────────────────────────────────────────
class _DateNav extends StatelessWidget {
  final String label;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onToday;
  const _DateNav({required this.label, required this.isToday, required this.onPrev, this.onNext, this.onToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded, size: 20, color: kTextDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: kBlue),
              const SizedBox(width: 7),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark)),
              if (isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Today', style: TextStyle(color: kBlue, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.chevron_right_rounded, size: 20, color: onNext == null ? kTextGray.withOpacity(0.3) : kTextDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Stat cell (used inside the summary strip) ───────────────────────────────
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool filled;
  const _StatCell(this.label, this.value, this.color, {this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: filled ? 22 : 19, fontWeight: FontWeight.w800, color: filled ? color : kTextDark, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextGray, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

// ─── Status filter bar ────────────────────────────────────────────────────────
class _StatusFilterBar extends StatelessWidget {
  final BillStatus? selected;
  final ValueChanged<BillStatus?> onSelect;
  const _StatusFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, BillStatus? value, Color color) {
      final active = selected == value;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GestureDetector(
          onTap: () => onSelect(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.12) : kWhite,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: active ? color : Colors.transparent, width: 1.2),
            ),
            child: Text(label, style: TextStyle(color: active ? color : kTextGray, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('All', null, kBlue),
        chip('Paid', BillStatus.paid, kGreen),
        chip('Pending', BillStatus.pending, kOrange),
        chip('Cancelled', BillStatus.cancelled, kTextGray),
      ],
    );
  }
}

// ─── Bill Row ─────────────────────────────────────────────────────────────────
class _BillRow extends StatelessWidget {
  final Bill bill;
  final bool deleting;
  final VoidCallback onTap;
  final Future<void> Function() onPrint;
  final VoidCallback onDelete;

  const _BillRow({
    required this.bill,
    required this.deleting,
    required this.onTap,
    required this.onPrint,
    required this.onDelete,
  });

  Color get _statusColor => switch (bill.status) {
    BillStatus.paid => kGreen,
    BillStatus.pending => kOrange,
    BillStatus.unpaid => kOrange,
    BillStatus.overdue => kRed,
    BillStatus.cancelled => kTextGray,
  };

  String get _statusLabel => switch (bill.status) {
    BillStatus.paid => 'Paid',
    BillStatus.pending => 'Pending',
    BillStatus.unpaid => 'Unpaid',
    BillStatus.overdue => 'Overdue',
    BillStatus.cancelled => 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final itemCount = bill.items.fold(0.0, (s, i) => s + i.qty);
    final firstItems = bill.items.take(3).map((i) => i.name).join(', ');
    final extra = bill.items.length > 3 ? ' +${bill.items.length - 3} more' : '';

    return Material(
      color: kWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Status accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Bill # + time + source tag
                        SizedBox(
                          width: 118,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('#${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextDark)),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    bill.source == 'table' ? Icons.table_restaurant_rounded : Icons.shopping_bag_rounded,
                                    size: 11, color: kTextGray,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    bill.source == 'table' ? (bill.tableId ?? 'Table') : 'Takeout',
                                    style: const TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(ReportsPageTimeFormatter.format(bill.createdAt), style: const TextStyle(color: kTextGray, fontSize: 11)),
                            ],
                          ),
                        ),

                        // Divider
                        Container(width: 1, height: 40, color: kBgGray, margin: const EdgeInsets.symmetric(horizontal: 14)),

                        // Items summary + waiter/customer
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bill.items.isEmpty ? 'No items' : '$firstItems$extra',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: kTextDark, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${itemCount == itemCount.toInt() ? itemCount.toInt() : itemCount} item${itemCount == 1 ? '' : 's'}',
                                      style: const TextStyle(color: kTextGray, fontSize: 11.5)),
                                  if (bill.waiter != null) ...[
                                    const SizedBox(width: 10),
                                    const Icon(Icons.badge_rounded, size: 11, color: kTextGray),
                                    const SizedBox(width: 3),
                                    Text(bill.waiter!, style: const TextStyle(color: kTextGray, fontSize: 11.5)),
                                  ],
                                  if (bill.customerName != null) ...[
                                    const SizedBox(width: 10),
                                    const Icon(Icons.person_rounded, size: 11, color: kTextGray),
                                    const SizedBox(width: 3),
                                    Text(bill.customerName!, style: const TextStyle(color: kTextGray, fontSize: 11.5)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                       
                        const SizedBox(width: 16),

                        // Total
                        SizedBox(
                          width: 76,
                          child: Text('₹${bill.grandTotal.toStringAsFixed(0)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kTextDark)),
                        ),

                        const SizedBox(width: 4),

                        // Actions
                        IconButton(
                          onPressed: () => onPrint(),
                          icon: const Icon(Icons.print_rounded, size: 19, color: kBlue),
                          tooltip: 'Reprint bill',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        ),
                        IconButton(
                          onPressed: deleting ? null : onDelete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: kRed),
                          tooltip: 'Delete order',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared time formatter so the detail dialog and row use identical formatting.
class ReportsPageTimeFormatter {
  static String format(DateTime dt) {
    final local = dt.toLocal();
    final h24 = local.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$mm $ampm';
  }

  static String formatFull(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = dt.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year} · ${format(dt)}';
  }
}

// ─── Bill Detail Dialog ─────────────────────────────────────────────────────
class _BillDetailDialog extends StatefulWidget {
  final Bill bill;
  final BillController controller;
  const _BillDetailDialog({required this.bill, required this.controller});

  @override
  State<_BillDetailDialog> createState() => _BillDetailDialogState();
}

class _BillDetailDialogState extends State<_BillDetailDialog> {
  bool _printing = false;

  Color _statusColor(BillStatus s) => switch (s) {
    BillStatus.paid => kGreen,
    BillStatus.pending => kOrange,
    BillStatus.unpaid => kOrange,
    BillStatus.overdue => kRed,
    BillStatus.cancelled => kTextGray,
  };

  String _statusLabel(BillStatus s) => switch (s) {
    BillStatus.paid => 'Paid',
    BillStatus.pending => 'Pending',
    BillStatus.unpaid => 'Unpaid',
    BillStatus.overdue => 'Overdue',
    BillStatus.cancelled => 'Cancelled',
  };

  Future<void> _print() async {
    setState(() => _printing = true);
    final ok = await widget.controller.printBill(widget.bill);
    if (mounted) setState(() => _printing = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent to printer'), backgroundColor: kGreen),
      );
    }
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete order?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Bill #${widget.bill.billNumber} (₹${widget.bill.grandTotal.toStringAsFixed(0)}) will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: kWhite, elevation: 0),
            onPressed: () async {
              Navigator.pop(dialogCtx); // close confirm
              await widget.controller.deleteBill(widget.bill.id);
              if (mounted) Navigator.pop(context); // close detail dialog
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final color = _statusColor(bill.status);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
              decoration: BoxDecoration(
                color: kBlue,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill #${bill.billNumber}', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(ReportsPageTimeFormatter.formatFull(bill.createdAt), style: TextStyle(color: kWhite.withOpacity(0.85), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kWhite), padding: EdgeInsets.zero),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta row: status, source, waiter/customer
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(_statusLabel(bill.status), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
                        ),
                        _MetaChip(
                          icon: bill.source == 'table' ? Icons.table_restaurant_rounded : Icons.shopping_bag_rounded,
                          label: bill.source == 'table' ? (bill.tableId ?? 'Table') : 'Takeout',
                        ),
                        if (bill.waiter != null) _MetaChip(icon: Icons.badge_rounded, label: bill.waiter!),
                        if (bill.customerName != null) _MetaChip(icon: Icons.person_rounded, label: bill.customerName!),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Text('Items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kTextDark)),
                    const SizedBox(height: 10),

                    if (bill.items.isEmpty)
                      const Text('No items on this bill', style: TextStyle(color: kTextGray, fontSize: 13))
                    else
                      Container(
                        decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Column(
                          children: [
                            for (int i = 0; i < bill.items.length; i++) ...[
                              if (i > 0) const Divider(height: 1, color: kWhite),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(bill.items[i].name, style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w600)),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${bill.items[i].qty == bill.items[i].qty.toInt() ? bill.items[i].qty.toInt() : bill.items[i].qty} × ₹${bill.items[i].rate.toStringAsFixed(0)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12, color: kTextGray),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text('₹${bill.items[i].total.toStringAsFixed(0)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    const SizedBox(height: 18),

                    _totalRow('Subtotal', bill.subtotal),
                    _totalRow('Tax (${bill.taxRate.toStringAsFixed(0)}%)', bill.taxAmount),
                    if (bill.discount > 0) _totalRow('Discount', -bill.discount, color: kRed),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                    _totalRow('Grand Total', bill.grandTotal, bold: true, large: true),

                    if (bill.paymentMethod != 'pending') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.payments_rounded, size: 14, color: kTextGray),
                          const SizedBox(width: 6),
                          Text('Paid via ${bill.paymentMethod}', style: const TextStyle(color: kTextGray, fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kRed,
                        side: const BorderSide(color: kRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _printing ? null : _print,
                      icon: _printing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                          : const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Reprint bill', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false, bool large = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: kTextGray, fontSize: large ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(
            '${value < 0 ? '-' : ''}₹${value.abs().toStringAsFixed(2)}',
            style: TextStyle(color: color ?? (bold ? kTextDark : kTextGray), fontSize: large ? 17 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: kTextGray),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: kTextDark, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}