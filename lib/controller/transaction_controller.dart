import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:test_bill/models/transaction_model.dart';
import 'package:test_bill/service/transaction_service.dart';

class TransactionController extends GetxController {
  final TransactionService _service = TransactionService.instance;
  final GetStorage _box = GetStorage();
  static const String _storageKey = 'custom_transactions';

  final RxList<CustomTransaction> transactions = <CustomTransaction>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadTransactions();
  }

  /// Loads transactions from API with GetStorage offline fallback.
  Future<void> loadTransactions({String? type, DateTime? from, DateTime? to}) async {
    isLoading.value = true;
    try {
      final list = await _service.fetchTransactions(type: type, from: from, to: to);
      transactions.assignAll(list);
      _saveToLocalStorage();
    } catch (_) {
      // Fallback to local storage if network is offline
      final raw = _box.read<List>(_storageKey);
      if (raw != null) {
        final List<CustomTransaction> loaded = [];
        for (final item in raw) {
          if (item is Map) {
            loaded.add(CustomTransaction.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        transactions.assignAll(loaded);
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _saveToLocalStorage() {
    final list = transactions.map((e) => e.toJson()).toList();
    _box.write(_storageKey, list);
  }

  /// Adds a new Shop Expense
  Future<bool> addExpense({
    required String title,
    required double amount,
    required String category,
    required String paymentMethod,
    required String note,
  }) async {
    try {
      final newTx = await _service.createTransaction(
        type: 'expense',
        title: title,
        amount: amount,
        categoryOrPerson: category.isEmpty ? 'General' : category,
        paymentMethod: paymentMethod,
        note: note,
      );
      transactions.insert(0, newTx);
      _saveToLocalStorage();
      return true;
    } catch (e) {
      // Fallback for offline saving
      final fallbackTx = CustomTransaction(
        id: 'EXP_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.expense,
        title: title,
        amount: amount,
        categoryOrPerson: category.isEmpty ? 'General' : category,
        paymentMethod: paymentMethod,
        note: note,
        createdAt: DateTime.now(),
      );
      transactions.insert(0, fallbackTx);
      _saveToLocalStorage();
      return false; // saved locally
    }
  }

  /// Adds a new Counter Cash Withdrawal
  Future<bool> addCashOut({
    required String person,
    required double amount,
    required String reason,
  }) async {
    final title = reason.isEmpty ? 'Counter Cash Withdrawal' : reason;
    final note = 'Taken by $person';
    try {
      final newTx = await _service.createTransaction(
        type: 'counterWithdrawal',
        title: title,
        amount: amount,
        categoryOrPerson: person,
        paymentMethod: 'cash',
        note: note,
      );
      transactions.insert(0, newTx);
      _saveToLocalStorage();
      return true;
    } catch (e) {
      final fallbackTx = CustomTransaction(
        id: 'CASHOUT_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.counterWithdrawal,
        title: title,
        amount: amount,
        categoryOrPerson: person,
        paymentMethod: 'cash',
        note: note,
        createdAt: DateTime.now(),
      );
      transactions.insert(0, fallbackTx);
      _saveToLocalStorage();
      return false; // saved locally
    }
  }

  /// Deletes a transaction entry
  Future<void> deleteTransaction(CustomTransaction tx) async {
    try {
      if (tx.id.isNotEmpty && !tx.id.startsWith('EXP_') && !tx.id.startsWith('CASHOUT_')) {
        await _service.deleteTransaction(tx.id);
      }
    } catch (_) {}
    transactions.removeWhere((item) => item.id == tx.id);
    _saveToLocalStorage();
  }

  // Computed Totals
  double get totalExpenses => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalCashOut => transactions
      .where((t) => t.type == TransactionType.counterWithdrawal)
      .fold(0.0, (sum, t) => sum + t.amount);

  int get expenseCount => transactions.where((t) => t.type == TransactionType.expense).length;
  int get cashOutCount => transactions.where((t) => t.type == TransactionType.counterWithdrawal).length;
}
