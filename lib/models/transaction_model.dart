enum TransactionType { incomeBill, expense, counterWithdrawal }

class CustomTransaction {
  final String id;
  final TransactionType type;
  final String title;
  final double amount;
  final String categoryOrPerson;
  final String paymentMethod;
  final String note;
  final DateTime createdAt;

  CustomTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.categoryOrPerson,
    required this.paymentMethod,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        '_id': id,
        'type': type == TransactionType.counterWithdrawal
            ? 'counterWithdrawal'
            : 'expense',
        'title': title,
        'amount': amount,
        'categoryOrPerson': categoryOrPerson,
        'paymentMethod': paymentMethod,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomTransaction.fromJson(Map<String, dynamic> json) =>
      CustomTransaction(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        type: json['type'] == 'counterWithdrawal'
            ? TransactionType.counterWithdrawal
            : TransactionType.expense,
        title: json['title'] ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        categoryOrPerson: json['categoryOrPerson'] ?? '',
        paymentMethod: json['paymentMethod'] ?? 'cash',
        note: json['note'] ?? '',
        createdAt: json['createdAt'] is DateTime
            ? json['createdAt'] as DateTime
            : json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
      );
}
