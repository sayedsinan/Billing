import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/controller/transaction_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/models/transaction_model.dart';
import 'package:test_bill/theme/colors.dart';
import 'package:test_bill/view/reports/reports_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final BillController _billController = Get.find<BillController>();
  late final TransactionController _transactionController;

  String _search = '';
  String _typeFilter = 'ALL'; // ALL, BILLS, EXPENSES, CASH_OUT

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      _transactionController = Get.put(TransactionController());
    } else {
      _transactionController = Get.find<TransactionController>();
    }

    if (_billController.bills.isEmpty) {
      _billController.fetchBills();
    }
  }

  void _addExpenseDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General Expense');
    final noteCtrl = TextEditingController();
    String paymentMethod = 'cash';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.remove_circle_outline_rounded, color: kRed, size: 22),
              SizedBox(width: 8),
              Text('Record Shop Expense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInput('Expense Title / Reason *', titleCtrl, 'e.g. Vegetables, Electricity bill, Tea/Snacks'),
                const SizedBox(height: 12),
                _buildInput('Amount (₹) *', amountCtrl, 'e.g. 500', isNumber: true),
                const SizedBox(height: 12),
                _buildInput('Category / Vendor', categoryCtrl, 'e.g. Dairy, Supplies, Utility, Rent'),
                const SizedBox(height: 12),
                const Text('Payment Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextGray)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['cash', 'upi', 'card', 'bank'].map((m) {
                    final active = paymentMethod == m;
                    return ChoiceChip(
                      label: Text(m.toUpperCase(), style: TextStyle(color: active ? kWhite : kTextDark, fontSize: 11, fontWeight: FontWeight.w700)),
                      selected: active,
                      selectedColor: kRed,
                      onSelected: (val) {
                        if (val) setDState(() => paymentMethod = m);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _buildInput('Notes / Remark (Optional)', noteCtrl, 'Any extra detail...'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: kWhite, elevation: 0),
              onPressed: isSaving
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (title.isEmpty || amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid title and amount'), backgroundColor: kRed),
                        );
                        return;
                      }

                      setDState(() => isSaving = true);
                      final isOnlineSaved = await _transactionController.addExpense(
                        title: title,
                        amount: amt,
                        category: categoryCtrl.text.trim(),
                        paymentMethod: paymentMethod,
                        note: noteCtrl.text.trim(),
                      );

                      if (mounted) {
                        Navigator.pop(dCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isOnlineSaved
                                  ? 'Saved Expense to DB: ₹${amt.toStringAsFixed(0)}'
                                  : 'Saved Expense (Local): ₹${amt.toStringAsFixed(0)}',
                            ),
                            backgroundColor: kRed,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                  : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCashOutDialog(BuildContext context) {
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: kOrange, size: 22),
              SizedBox(width: 8),
              Text('Record Counter Cash Withdrawal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInput('Person Name (Who took cash) *', personCtrl, 'e.g. Owner John, Manager Alex'),
                const SizedBox(height: 12),
                _buildInput('Amount Taken (₹) *', amountCtrl, 'e.g. 1000', isNumber: true),
                const SizedBox(height: 12),
                _buildInput('Purpose / Reason *', reasonCtrl, 'e.g. Personal draw, Cash payment to vendor, Emergency'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: kWhite, elevation: 0),
              onPressed: isSaving
                  ? null
                  : () async {
                      final person = personCtrl.text.trim();
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      final reason = reasonCtrl.text.trim();

                      if (person.isEmpty || amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter person name and valid amount'), backgroundColor: kRed),
                        );
                        return;
                      }

                      setDState(() => isSaving = true);
                      final isOnlineSaved = await _transactionController.addCashOut(
                        person: person,
                        amount: amt,
                        reason: reason,
                      );

                      if (mounted) {
                        Navigator.pop(dCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isOnlineSaved
                                  ? 'Saved Cash Out to DB: ₹${amt.toStringAsFixed(0)} by $person'
                                  : 'Saved Cash Out (Local): ₹${amt.toStringAsFixed(0)} by $person',
                            ),
                            backgroundColor: kOrange,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                  : const Text('Record Cash Out'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCustomTransaction(CustomTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete "${tx.title}" (₹${tx.amount.toStringAsFixed(0)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: kWhite, elevation: 0),
            onPressed: () async {
              Navigator.pop(ctx);
              await _transactionController.deleteTransaction(tx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  Widget _buildInput(String label, TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextGray)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kTextGray, fontSize: 12.5),
            filled: true,
            fillColor: kBgGray,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgGray,
      body: Obx(() {
        final allBills = _billController.bills;
        final customTransactions = _transactionController.transactions;
        final loading = _billController.isLoadingBills.value || _transactionController.isLoading.value;

        // Calculate Totals
        final totalSalesIncome = allBills
            .where((b) => b.status != BillStatus.cancelled)
            .fold(0.0, (s, b) => s + b.grandTotal);

        final totalExpenses = _transactionController.totalExpenses;
        final totalCashOut = _transactionController.totalCashOut;
        final netBalance = totalSalesIncome - (totalExpenses + totalCashOut);

        // Build Combined Display List
        final List<dynamic> combinedList = [];

        if (_typeFilter == 'ALL' || _typeFilter == 'BILLS') {
          combinedList.addAll(allBills);
        }
        if (_typeFilter == 'ALL' || _typeFilter == 'EXPENSES') {
          combinedList.addAll(customTransactions.where((t) => t.type == TransactionType.expense));
        }
        if (_typeFilter == 'ALL' || _typeFilter == 'CASH_OUT') {
          combinedList.addAll(customTransactions.where((t) => t.type == TransactionType.counterWithdrawal));
        }

        // Apply Search Filter
        final filteredList = combinedList.where((item) {
          final q = _search.toLowerCase();
          if (q.isEmpty) return true;

          if (item is Bill) {
            return item.billNumber.toLowerCase().contains(q) ||
                (item.customerName ?? '').toLowerCase().contains(q) ||
                (item.tableId ?? '').toLowerCase().contains(q);
          } else if (item is CustomTransaction) {
            return item.title.toLowerCase().contains(q) ||
                item.categoryOrPerson.toLowerCase().contains(q) ||
                item.note.toLowerCase().contains(q);
          }
          return false;
        }).toList();

        // Sort by Date Descending
        filteredList.sort((a, b) {
          final dtA = a is Bill ? a.createdAt : (a as CustomTransaction).createdAt;
          final dtB = b is Bill ? b.createdAt : (b as CustomTransaction).createdAt;
          return dtB.compareTo(dtA);
        });

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Header & Action Buttons
              Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 28, color: kBlue),
                  const SizedBox(width: 12),
                  const Text('Transactions & Cash Flow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: -0.3)),
                  const Spacer(),
                  // Add Expense Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRed,
                      side: const BorderSide(color: kRed, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _addExpenseDialog(context),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                    label: const Text('Record Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  // Add Counter Cash Out Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: kWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _addCashOutDialog(context),
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                    label: const Text('Counter Cash Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      _billController.fetchBills();
                      _transactionController.loadTransactions();
                    },
                    icon: const Icon(Icons.refresh_rounded, color: kTextGray),
                    tooltip: 'Refresh data',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Summary Cards Strip
              Row(
                children: [
                  _SummaryCard(title: 'Sales Income (Bills)', amount: '₹${totalSalesIncome.toStringAsFixed(0)}', sub: '${allBills.length} bills paid', color: kGreen, icon: Icons.trending_up_rounded),
                  const SizedBox(width: 14),
                  _SummaryCard(title: 'Shop Expenses', amount: '₹${totalExpenses.toStringAsFixed(0)}', sub: '${_transactionController.expenseCount} expense entries', color: kRed, icon: Icons.shopping_bag_outlined),
                  const SizedBox(width: 14),
                  _SummaryCard(title: 'Counter Cash Out', amount: '₹${totalCashOut.toStringAsFixed(0)}', sub: '${_transactionController.cashOutCount} withdrawals', color: kOrange, icon: Icons.account_balance_wallet_rounded),
                  const SizedBox(width: 14),
                  _SummaryCard(title: 'Net Cash Balance', amount: '₹${netBalance.toStringAsFixed(0)}', sub: 'Income - Expenses & Draws', color: kBlue, icon: Icons.account_balance_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Filter Tabs
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(11)),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search bill #, customer, expense title, or person name…',
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
                    children: [
                      _FilterChip(label: 'ALL', active: _typeFilter == 'ALL', onTap: () => setState(() => _typeFilter = 'ALL')),
                      _FilterChip(label: 'BILLS (INCOME)', active: _typeFilter == 'BILLS', onTap: () => setState(() => _typeFilter = 'BILLS')),
                      _FilterChip(label: 'EXPENSES', active: _typeFilter == 'EXPENSES', onTap: () => setState(() => _typeFilter = 'EXPENSES')),
                      _FilterChip(label: 'CASH OUT', active: _typeFilter == 'CASH_OUT', onTap: () => setState(() => _typeFilter = 'CASH_OUT')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Transaction List
              Expanded(
                child: loading && filteredList.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: kBlue))
                    : filteredList.isEmpty
                        ? const Center(child: Text('No transactions found in this category.', style: TextStyle(color: kTextGray)))
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final item = filteredList[i];

                              if (item is Bill) {
                                final isPaid = item.status == BillStatus.paid;
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
                                          isPaid ? Icons.add_circle_outline_rounded : Icons.pending_rounded,
                                          color: isPaid ? kGreen : kOrange,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('Bill #${item.billNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextDark)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: kGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                                child: const Text('BILL INCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGreen)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${ReportsPageTimeFormatter.formatFull(item.createdAt)} · Customer: ${item.customerName?.isNotEmpty == true ? item.customerName : "Walk-in"}',
                                            style: const TextStyle(color: kTextGray, fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          item.paymentMethod.toUpperCase(),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text('+₹${item.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kGreen)),
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
                                          onPressed: () => _showPaymentDialog(ctx, item),
                                          child: const Text('Pay Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                );
                              } else {
                                final tx = item as CustomTransaction;
                                final isExpense = tx.type == TransactionType.expense;
                                final themeColor = isExpense ? kRed : kOrange;

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
                                        backgroundColor: themeColor.withOpacity(0.12),
                                        child: Icon(
                                          isExpense ? Icons.remove_circle_outline_rounded : Icons.account_balance_wallet_outlined,
                                          color: themeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextDark)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: themeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                                child: Text(
                                                  isExpense ? 'SHOP EXPENSE' : 'CASH OUT (${tx.categoryOrPerson})',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: themeColor),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${ReportsPageTimeFormatter.formatFull(tx.createdAt)} ${tx.note.isNotEmpty ? "· ${tx.note}" : ""}',
                                            style: const TextStyle(color: kTextGray, fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          tx.paymentMethod.toUpperCase(),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text('-₹${tx.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: themeColor)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _deleteCustomTransaction(tx),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kTextGray),
                                        tooltip: 'Delete Entry',
                                      ),
                                    ],
                                  ),
                                );
                              }
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

class _SummaryCard extends StatelessWidget {
  final String title, amount, sub;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextGray)),
                  const SizedBox(height: 2),
                  Text(amount, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kBlue : kWhite,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kWhite : kTextDark,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
