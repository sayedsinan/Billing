import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/theme/colors.dart';
import 'package:test_bill/view/reports/reports_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final BillController _billController = Get.find<BillController>();
  String _search = '';
  String _paymentFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    if (_billController.bills.isEmpty) {
      _billController.fetchBills();
    }
  }

  void _showPaymentDialog(BuildContext ctx, Bill bill) {
    String selectedMethod = 'cash';
    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Collect Payment for #${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount Due: ₹${bill.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kGreen)),
              const SizedBox(height: 16),
              const Text('Select Payment Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextGray)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['cash', 'upi', 'card', 'wallet'].map((method) {
                  final active = selectedMethod == method;
                  return ChoiceChip(
                    label: Text(method.toUpperCase(), style: TextStyle(color: active ? kWhite : kTextDark, fontWeight: FontWeight.w700, fontSize: 12)),
                    selected: active,
                    selectedColor: kBlue,
                    onSelected: (val) {
                      if (val) setDState(() => selectedMethod = method);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: kWhite, elevation: 0),
              onPressed: () async {
                Navigator.pop(dCtx);
                final ok = await _billController.payBill(bill.id, selectedMethod);
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bill #${bill.billNumber} marked as Paid via ${selectedMethod.toUpperCase()}'), backgroundColor: kGreen),
                  );
                }
              },
              child: const Text('Mark Paid'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgGray,
      body: Obx(() {
        final all = _billController.bills;
        final loading = _billController.isLoadingBills.value;

        final filtered = all.where((b) {
          final q = _search.toLowerCase();
          final matchSearch = q.isEmpty ||
              b.billNumber.toLowerCase().contains(q) ||
              (b.customerName ?? '').toLowerCase().contains(q) ||
              (b.tableId ?? '').toLowerCase().contains(q);

          final matchPayment = switch (_paymentFilter) {
            'CASH' => b.paymentMethod.toLowerCase() == 'cash',
            'UPI' => b.paymentMethod.toLowerCase() == 'upi',
            'CARD' => b.paymentMethod.toLowerCase() == 'card',
            'WALLET' => b.paymentMethod.toLowerCase() == 'wallet',
            'PENDING' => b.status == BillStatus.pending || b.status == BillStatus.unpaid,
            _ => true,
          };
          return matchSearch && matchPayment;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final totalAmount = filtered.fold(0.0, (s, b) => s + b.grandTotal);

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 28, color: kBlue),
                  const SizedBox(width: 12),
                  const Text('Transactions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: -0.3)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${filtered.length} transactions · ₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _billController.fetchBills(),
                    icon: const Icon(Icons.refresh_rounded, color: kTextGray),
                    tooltip: 'Refresh transactions',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Bar + Search
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(11)),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search bill #, customer, table…',
                          hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 6,
                    children: ['ALL', 'CASH', 'UPI', 'CARD', 'WALLET', 'PENDING'].map((method) {
                      final active = _paymentFilter == method;
                      return ChoiceChip(
                        label: Text(method, style: TextStyle(color: active ? kBlue : kTextGray, fontSize: 12, fontWeight: FontWeight.w700)),
                        selected: active,
                        selectedColor: kBlue.withOpacity(0.12),
                        backgroundColor: kWhite,
                        side: BorderSide(color: active ? kBlue : Colors.transparent),
                        onSelected: (val) {
                          if (val) setState(() => _paymentFilter = method);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // List
              Expanded(
                child: loading && all.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: kBlue))
                    : filtered.isEmpty
                        ? const Center(child: Text('No transactions match the selected filter.', style: TextStyle(color: kTextGray)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final bill = filtered[i];
                              final isPaid = bill.status == BillStatus.paid;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isPaid ? kGreen.withOpacity(0.12) : kOrange.withOpacity(0.12),
                                      child: Icon(
                                        isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                        color: isPaid ? kGreen : kOrange,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Bill #${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextDark)),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${ReportsPageTimeFormatter.formatFull(bill.createdAt)} · ${bill.items.length} items',
                                          style: const TextStyle(color: kTextGray, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: kBgGray,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        bill.paymentMethod.toUpperCase(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text('₹${bill.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextDark)),
                                    const SizedBox(width: 12),
                                    if (!isPaid)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kGreen,
                                          foregroundColor: kWhite,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _showPaymentDialog(ctx, bill),
                                        child: const Text('Pay Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
