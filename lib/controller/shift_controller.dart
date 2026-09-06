import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/service/print_service.dart';

class ShiftController extends GetxController {
  final _box = GetStorage();

  var isShiftOpen = false.obs;
  var openingCash = 0.0.obs;
  var openingBank = 0.0.obs;
  var shiftStartTime = Rxn<DateTime>();
  var cashDrops = <Map<String, dynamic>>[].obs;
  var shiftHistory = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadState();
  }

  void _loadState() {
    isShiftOpen.value = _box.read<bool>('shift_is_open') ?? true; // Default shift is open
    openingCash.value = (_box.read<num>('shift_opening_cash') ?? 0.0).toDouble();
    openingBank.value = (_box.read<num>('shift_opening_bank') ?? 0.0).toDouble();

    final startStr = _box.read<String>('shift_start_time');
    if (startStr != null) {
      shiftStartTime.value = DateTime.tryParse(startStr);
    } else {
      shiftStartTime.value = DateTime.now();
    }

    final savedDrops = _box.read<List>('shift_cash_drops');
    if (savedDrops != null) {
      cashDrops.assignAll(savedDrops.cast<Map<String, dynamic>>());
    }

    final savedHistory = _box.read<List>('shift_history');
    if (savedHistory != null) {
      shiftHistory.assignAll(savedHistory.cast<Map<String, dynamic>>());
    }
  }

  void saveInitialFloat({required double cash, required double bank}) {
    openingCash.value = cash;
    openingBank.value = bank;
    if (shiftStartTime.value == null) {
      shiftStartTime.value = DateTime.now();
      _box.write('shift_start_time', shiftStartTime.value!.toIso8601String());
    }
    isShiftOpen.value = true;

    _box.write('shift_is_open', true);
    _box.write('shift_opening_cash', cash);
    _box.write('shift_opening_bank', bank);
  }

  void addCashDrop({required double amount, required String note}) {
    final entry = {
      'amount': amount,
      'note': note,
      'time': DateTime.now().toIso8601String(),
    };
    cashDrops.add(entry);
    _box.write('shift_cash_drops', cashDrops.toList());
  }

  double get totalCashDrops => cashDrops.fold(0.0, (s, d) => s + (d['amount'] as num).toDouble());

  bool _isBillInCurrentShift(Bill b) {
    // 1. Must be PAID (unpaid, pending, and cancelled bills do NOT count as money received)
    if (b.status != BillStatus.paid) return false;

    final now = DateTime.now();
    final billDt = b.createdAt.toLocal();

    // 2. Must be from today
    final isToday = billDt.year == now.year && billDt.month == now.month && billDt.day == now.day;
    if (!isToday) return false;

    // 3. If shift start time is set today, must be after shift start time
    if (shiftStartTime.value != null) {
      final shiftStart = shiftStartTime.value!.toLocal();
      if (shiftStart.year == now.year && shiftStart.month == now.month && shiftStart.day == now.day) {
        return billDt.isAfter(shiftStart) || billDt.isAtSameMomentAs(shiftStart);
      }
    }

    return true;
  }

  /// Calculates Expected Cash Sales for current active shift
  double getShiftCashSales(List<Bill> bills) {
    return bills.where((b) {
      if (!_isBillInCurrentShift(b)) return false;
      final method = b.paymentMethod.toLowerCase().trim();
      return method == 'cash';
    }).fold(0.0, (s, b) => s + b.grandTotal);
  }

  /// Calculates Expected Online / UPI / Card Sales for current active shift
  double getShiftOnlineSales(List<Bill> bills) {
    return bills.where((b) {
      if (!_isBillInCurrentShift(b)) return false;
      final method = b.paymentMethod.toLowerCase().trim();
      return method == 'upi' || method == 'online' || method == 'card';
    }).fold(0.0, (s, b) => s + b.grandTotal);
  }

  /// Get list of cash bills for current active shift (for transparency)
  List<Bill> getShiftCashBills(List<Bill> bills) {
    return bills.where((b) {
      if (!_isBillInCurrentShift(b)) return false;
      final method = b.paymentMethod.toLowerCase().trim();
      return method == 'cash';
    }).toList();
  }

  /// Get list of online bills for current active shift (for transparency)
  List<Bill> getShiftOnlineBills(List<Bill> bills) {
    return bills.where((b) {
      if (!_isBillInCurrentShift(b)) return false;
      final method = b.paymentMethod.toLowerCase().trim();
      return method == 'upi' || method == 'online' || method == 'card';
    }).toList();
  }

  /// Expected Cash in Register = Opening Cash Float + Cash Sales - Cash Drops
  double getExpectedCash(List<Bill> bills) {
    return openingCash.value + getShiftCashSales(bills) - totalCashDrops;
  }

  /// Expected Bank / Account Balance = Opening Bank + Online/UPI Sales
  double getExpectedBank(List<Bill> bills) {
    return openingBank.value + getShiftOnlineSales(bills);
  }

  /// Close Shift & Save Settlement Record ("End the Day & Settle")
  Future<Map<String, dynamic>> closeShift({
    required double actualCash,
    required double actualBank,
    required String notes,
    required List<Bill> bills,
    bool printReport = true,
  }) async {
    final cashSales = getShiftCashSales(bills);
    final onlineSales = getShiftOnlineSales(bills);
    final expCash = getExpectedCash(bills);
    final expBank = getExpectedBank(bills);
    final cashVar = actualCash - expCash;
    final bankVar = actualBank - expBank;

    final record = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'startTime': (shiftStartTime.value ?? DateTime.now()).toIso8601String(),
      'endTime': DateTime.now().toIso8601String(),
      'openingCash': openingCash.value,
      'openingBank': openingBank.value,
      'cashSales': cashSales,
      'onlineSales': onlineSales,
      'totalExpenses': totalCashDrops,
      'expectedCash': expCash,
      'actualCash': actualCash,
      'cashVariance': cashVar,
      'expectedBank': expBank,
      'actualBank': actualBank,
      'bankVariance': bankVar,
      'notes': notes,
    };

    shiftHistory.insert(0, record);
    _box.write('shift_history', shiftHistory.toList());

    if (printReport) {
      try {
        final startDt = shiftStartTime.value ?? DateTime.now();
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final label = '${startDt.day} ${months[startDt.month - 1]} ${startDt.hour}:${startDt.minute.toString().padLeft(2, '0')} to NOW';

        await PrintService.instance.printShiftSettlementReport(
          shiftLabel: label,
          openingCash: openingCash.value,
          openingBank: openingBank.value,
          cashSales: cashSales,
          onlineSales: onlineSales,
          totalExpenses: totalCashDrops,
          expectedCash: expCash,
          actualCash: actualCash,
          cashVariance: cashVar,
          expectedBank: expBank,
          actualBank: actualBank,
          bankVariance: bankVar,
        );
      } catch (e) {
        debugPrint('Thermal print warning on shift close: $e');
      }
    }

    // Reset current shift float for next day/shift
    isShiftOpen.value = false;
    _box.write('shift_is_open', false);
    cashDrops.clear();
    _box.remove('shift_cash_drops');

    return record;
  }

  void startNewShift({required double cash, required double bank}) {
    openingCash.value = cash;
    openingBank.value = bank;
    shiftStartTime.value = DateTime.now();
    isShiftOpen.value = true;
    cashDrops.clear();

    _box.write('shift_is_open', true);
    _box.write('shift_opening_cash', cash);
    _box.write('shift_opening_bank', bank);
    _box.write('shift_start_time', shiftStartTime.value!.toIso8601String());
    _box.remove('shift_cash_drops');
  }
}
