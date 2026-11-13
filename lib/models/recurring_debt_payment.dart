import 'dart:convert';

class RecurringDebtPayment {
  final int id;
  final double amount;
  final double remainingAfter;
  final DateTime? paidAt;

  RecurringDebtPayment({
    required this.id,
    required this.amount,
    required this.remainingAfter,
    this.paidAt,
  });

  factory RecurringDebtPayment.fromJson(Map<String, dynamic> json) {
    return RecurringDebtPayment(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      remainingAfter: (json['remainingAfter'] as num).toDouble(),
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
    );
  }
}

List<RecurringDebtPayment> recurringPaymentListFromJson(String str) {
  final data = json.decode(str) as List<dynamic>;
  return data
      .map((e) => RecurringDebtPayment.fromJson(e as Map<String, dynamic>))
      .toList();
}