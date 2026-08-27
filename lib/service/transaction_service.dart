import 'package:test_bill/models/transaction_model.dart';
import 'package:test_bill/service/api_service.dart';

class TransactionService {
  TransactionService._internal();
  static final TransactionService instance = TransactionService._internal();
  factory TransactionService() => instance;

  final ApiService _api = ApiService.instance;

  /// Fetches expenses & cash withdrawals from the backend API.
  Future<List<CustomTransaction>> fetchTransactions({
    String? type,
    DateTime? from,
    DateTime? to,
  }) async {
    final rawList = await _api.getExpenses(type: type, from: from, to: to);
    final List<CustomTransaction> transactions = [];
    for (final item in rawList) {
      if (item is Map) {
        transactions.add(
          CustomTransaction.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return transactions;
  }

  /// Records a new expense or counter cash withdrawal on the backend.
  Future<CustomTransaction> createTransaction({
    required String type,
    required String title,
    required double amount,
    String? categoryOrPerson,
    String? paymentMethod,
    String? note,
  }) async {
    final res = await _api.createExpense(
      type: type,
      title: title,
      amount: amount,
      categoryOrPerson: categoryOrPerson,
      paymentMethod: paymentMethod,
      note: note,
    );
    return CustomTransaction.fromJson(res);
  }

  /// Deletes an expense / cash withdrawal entry from the backend.
  Future<void> deleteTransaction(String id) async {
    await _api.deleteExpense(id);
  }
}
