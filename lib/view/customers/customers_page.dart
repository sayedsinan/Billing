import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/theme/colors.dart';

class CustomerSummary {
  final String name;
  final int orderCount;
  final double totalSpent;
  final DateTime lastVisit;
  final List<Bill> bills;

  CustomerSummary({
    required this.name,
    required this.orderCount,
    required this.totalSpent,
    required this.lastVisit,
    required this.bills,
  });

  double get avgSpent => orderCount == 0 ? 0.0 : totalSpent / orderCount;
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final BillController _billController = Get.find<BillController>();
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (_billController.bills.isEmpty) {
      _billController.fetchBills();
    }
  }

  List<CustomerSummary> _buildCustomerSummaries(List<Bill> bills) {
    final Map<String, List<Bill>> grouped = {};
    for (final b in bills) {
      final cName = b.customerName?.trim();
      final key = (cName == null || cName.isEmpty) ? 'Walk-in Customer' : cName;
      grouped.putIfAbsent(key, () => []).add(b);
    }

    final summaries = <CustomerSummary>[];
    grouped.forEach((name, customerBills) {
      customerBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final totalSpent = customerBills.fold(0.0, (s, b) => s + b.grandTotal);
      summaries.add(
        CustomerSummary(
          name: name,
          orderCount: customerBills.length,
          totalSpent: totalSpent,
          lastVisit: customerBills.first.createdAt,
          bills: customerBills,
        ),
      );
    });

    summaries.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return summaries;
  }

  void _showCustomerDetail(BuildContext ctx, CustomerSummary summary) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: kBlue.withOpacity(0.15),
                    radius: 22,
                    child: Text(
                      summary.name[0].toUpperCase(),
                      style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(summary.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kTextDark)),
                        Text('${summary.orderCount} total orders · Spent ₹${summary.totalSpent.toStringAsFixed(0)}', style: const TextStyle(color: kTextGray, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),
              const Text('Recent Bills', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark)),
              const SizedBox(height: 10),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  itemCount: summary.bills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final b = summary.bills[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Text('#${b.billNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark)),
                          const SizedBox(width: 8),
                          Text('${b.items.length} items', style: const TextStyle(color: kTextGray, fontSize: 11)),
                          const Spacer(),
                          Text('₹${b.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: kTextDark, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgGray,
      body: Obx(() {
        final allBills = _billController.bills;
        final loading = _billController.isLoadingBills.value;
        final customers = _buildCustomerSummaries(allBills);

        final filtered = customers.where((c) {
          final q = _search.toLowerCase();
          return q.isEmpty || c.name.toLowerCase().contains(q);
        }).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.people_rounded, size: 28, color: kBlue),
                  const SizedBox(width: 12),
                  const Text('Customers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: -0.3)),
                  const SizedBox(width: 10),
                  Text('${customers.length} profiles', style: const TextStyle(fontSize: 13, color: kTextGray, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _billController.fetchBills(),
                    icon: const Icon(Icons.refresh_rounded, color: kTextGray),
                    tooltip: 'Refresh customers',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                height: 42,
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(11)),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search customer name…',
                    hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 18),

              // Customer List Grid
              Expanded(
                child: loading && allBills.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: kBlue))
                    : filtered.isEmpty
                        ? const Center(child: Text('No customers found', style: TextStyle(color: kTextGray)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final c = filtered[i];
                              return Material(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () => _showCustomerDetail(ctx, c),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: kBlue.withOpacity(0.12),
                                          child: Text(c.name[0].toUpperCase(), style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 14),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextDark)),
                                            const SizedBox(height: 3),
                                            Text('${c.orderCount} order${c.orderCount == 1 ? '' : 's'} · Avg ₹${c.avgSpent.toStringAsFixed(0)}', style: const TextStyle(color: kTextGray, fontSize: 11.5)),
                                          ],
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('Total: ₹${c.totalSpent.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kGreen)),
                                            const SizedBox(height: 2),
                                            const Text('Tap to view history', style: TextStyle(fontSize: 10, color: kBlue, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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