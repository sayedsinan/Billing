import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/controller/shift_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/theme/colors.dart';

class CashRegisterPage extends StatefulWidget {
  const CashRegisterPage({super.key});

  @override
  State<CashRegisterPage> createState() => _CashRegisterPageState();
}

class _CashRegisterPageState extends State<CashRegisterPage> {
  late ShiftController _shiftController;
  late BillController _billController;

  final TextEditingController _openingCashCtrl = TextEditingController();
  final TextEditingController _openingBankCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ShiftController>()) {
      Get.put(ShiftController());
    }
    if (!Get.isRegistered<BillController>()) {
      Get.put(BillController());
    }
    _shiftController = Get.find<ShiftController>();
    _billController = Get.find<BillController>();

    _openingCashCtrl.text = _shiftController.openingCash.value.toStringAsFixed(0);
    _openingBankCtrl.text = _shiftController.openingBank.value.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _openingCashCtrl.dispose();
    _openingBankCtrl.dispose();
    super.dispose();
  }

  void _saveFloats() {
    final cash = double.tryParse(_openingCashCtrl.text.trim()) ?? 0.0;
    final bank = double.tryParse(_openingBankCtrl.text.trim()) ?? 0.0;
    _shiftController.saveInitialFloat(cash: cash, bank: bank);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Initial register floats updated successfully'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openCashDropDialog() {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Record Petty Expense / Cash Drop',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount Taken (₹)',
                  hintText: 'e.g. 500',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Reason / Note',
                  hintText: 'e.g. Vendor payout / Milk purchase',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
              final note = noteCtrl.text.trim();
              if (amt <= 0) return;
              _shiftController.addCashDrop(amount: amt, note: note.isEmpty ? 'Petty Expense' : note);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Recorded expense of ₹${amt.toStringAsFixed(0)}'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save Expense'),
          ),
        ],
      ),
    );
  }

  void _openCloseShiftDialog(List<Bill> bills) {
    final expCash = _shiftController.getExpectedCash(bills);
    final expBank = _shiftController.getExpectedBank(bills);

    final actualCashCtrl = TextEditingController(text: expCash.toStringAsFixed(0));
    final actualBankCtrl = TextEditingController(text: expBank.toStringAsFixed(0));
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final actCash = double.tryParse(actualCashCtrl.text.trim()) ?? 0.0;
          final actBank = double.tryParse(actualBankCtrl.text.trim()) ?? 0.0;
          final cashVar = actCash - expCash;
          final bankVar = actBank - expBank;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'End Day & Settle Register',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF0F172A)),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reconcile actual counted cash and bank totals before closing current billing shift:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // Expected Cash vs Counted Cash
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Expected Cash in Till', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                              Text('₹${expCash.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: actualCashCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Counted Cash (₹)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Variance', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text(
                                '₹${cashVar >= 0 ? "+" : ""}${cashVar.toStringAsFixed(0)} ${cashVar == 0 ? "(Exact)" : (cashVar > 0 ? "(Over)" : "(Short)")}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: cashVar == 0 ? const Color(0xFF10B981) : (cashVar > 0 ? const Color(0xFF2563EB) : const Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Expected Bank vs Counted Bank
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Expected Bank Account Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                              Text('₹${expBank.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: actualBankCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Counted Bank Total (₹)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Variance', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text(
                                '₹${bankVar >= 0 ? "+" : ""}${bankVar.toStringAsFixed(0)} ${bankVar == 0 ? "(Exact)" : (bankVar > 0 ? "(Over)" : "(Short)")}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: bankVar == 0 ? const Color(0xFF10B981) : (bankVar > 0 ? const Color(0xFF2563EB) : const Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Shift Notes (Optional)',
                        hintText: 'e.g. Shift closed by Manager',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () async {
                  final actCash = double.tryParse(actualCashCtrl.text.trim()) ?? 0.0;
                  final actBank = double.tryParse(actualBankCtrl.text.trim()) ?? 0.0;
                  final notes = notesCtrl.text.trim();

                  Navigator.pop(dialogCtx);

                  await _shiftController.closeShift(
                    actualCash: actCash,
                    actualBank: actBank,
                    notes: notes,
                    bills: bills,
                    printReport: true,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Shift closed & Z-Report printed successfully'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Settle & Print Z-Report'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Obx(() {
        final bills = _billController.bills;
        final isShiftOpen = _shiftController.isShiftOpen.value;

        final cashSales = _shiftController.getShiftCashSales(bills);
        final onlineSales = _shiftController.getShiftOnlineSales(bills);
        final cashBills = _shiftController.getShiftCashBills(bills);
        final onlineBills = _shiftController.getShiftOnlineBills(bills);
        final totalExpenses = _shiftController.totalCashDrops;

        final expCash = _shiftController.getExpectedCash(bills);
        final expBank = _shiftController.getExpectedBank(bills);
        final netTotalMoney = expCash + expBank;

        final history = _shiftController.shiftHistory;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Section ───────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Register & Cash Float',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isShiftOpen ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isShiftOpen ? const Color(0xFF166534) : const Color(0xFF64748B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isShiftOpen ? 'ACTIVE SHIFT' : 'SHIFT CLOSED',
                                  style: TextStyle(
                                    color: isShiftOpen ? const Color(0xFF166534) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Track initial till float, cash drops, and settle daily sales money.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _openCashDropDialog,
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    label: const Text('Record Expense', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _openCloseShiftDialog(bills),
                    icon: const Icon(Icons.lock_outline_rounded, size: 16),
                    label: const Text('End Day & Settle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Section 1: Initial Opening Balances Setup ─────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Opening Balances (Initial Float)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Set physical cash in till drawer & starting bank balance at start of day.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _openingCashCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Opening Cash Float (₹)',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _openingBankCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Opening Bank Total (₹)',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _saveFloats,
                            child: const Text('Save Float', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Section 2: Clean 4-Metric Grid ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _CleanMetricTile(
                      label: 'Opening Cash Float',
                      value: '₹${_shiftController.openingCash.value.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _CleanMetricTile(
                      label: 'Cash Sales Today',
                      value: '₹${cashSales.toStringAsFixed(0)}',
                      subtitle: '${cashBills.length} paid cash bills today',
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _CleanMetricTile(
                      label: 'Online / UPI Sales',
                      value: '₹${onlineSales.toStringAsFixed(0)}',
                      subtitle: '${onlineBills.length} online bills today',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _CleanMetricTile(
                      label: 'Petty Expenses',
                      value: '₹${totalExpenses.toStringAsFixed(0)}',
                      subtitle: '${_shiftController.cashDrops.length} recorded drops',
                      icon: Icons.remove_circle_outline_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Section 3: Clean Money Balance Cards ─────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _HeroBalanceTile(
                      title: 'EXPECTED CASH IN DRAWER',
                      amount: '₹${expCash.toStringAsFixed(0)}',
                      subtitle: 'Opening Float + Cash Sales - Expenses',
                      icon: Icons.point_of_sale_rounded,
                      accentColor: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _HeroBalanceTile(
                      title: 'EXPECTED BANK BALANCE',
                      amount: '₹${expBank.toStringAsFixed(0)}',
                      subtitle: 'Opening Bank + Online/UPI Sales',
                      icon: Icons.account_balance_outlined,
                      accentColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _HeroBalanceTile(
                      title: 'NET REVENUE (COMBINED)',
                      amount: '₹${netTotalMoney.toStringAsFixed(0)}',
                      subtitle: 'Total Cash in Hand + Account Balance',
                      icon: Icons.savings_outlined,
                      accentColor: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Section 4: Settlement Log Table ──────────────────────────────
              const Text(
                'Settlement & Day Close History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: history.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'No shift settlement records recorded yet.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('CLOSED AT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                Expanded(flex: 2, child: Text('CASH SALES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                Expanded(flex: 2, child: Text('ONLINE SALES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                Expanded(flex: 2, child: Text('COUNTED CASH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                Expanded(flex: 2, child: Text('VARIANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                              ],
                            ),
                          ),
                          // List Rows
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: history.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, idx) {
                              final rec = history[idx];
                              final end = DateTime.tryParse(rec['endTime']?.toString() ?? '') ?? DateTime.now();
                              final actCashRec = (rec['actualCash'] as num).toDouble();
                              final cashVarRec = (rec['cashVariance'] as num).toDouble();

                              const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                              final dateStr = '${end.day} ${months[end.month - 1]} ${end.year} · ${end.hour}:${end.minute.toString().padLeft(2, '0')}';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('₹${(rec['cashSales'] as num).toInt()}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('₹${(rec['onlineSales'] as num).toInt()}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('₹${actCashRec.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: cashVarRec == 0 ? const Color(0xFFDCFCE7) : (cashVarRec > 0 ? const Color(0xFFDBEAFE) : const Color(0xFFFEE2E2)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '₹${cashVarRec >= 0 ? "+" : ""}${cashVarRec.toInt()}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: cashVarRec == 0 ? const Color(0xFF166534) : (cashVarRec > 0 ? const Color(0xFF1E40AF) : const Color(0xFF991B1B)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CleanMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;

  const _CleanMetricTile({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ],
      ),
    );
  }
}

class _HeroBalanceTile extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _HeroBalanceTile({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
