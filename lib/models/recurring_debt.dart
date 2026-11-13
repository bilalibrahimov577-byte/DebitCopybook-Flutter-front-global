import 'dart:convert';

double _toDouble(dynamic v) => v == null ? 0.0 : (v as num).toDouble();

// 50 -> "50 ₼", 50.5 -> "50.50 ₼"
String formatAzn(double value) {
  final cents = (value * 100).round();
  return cents % 100 == 0
      ? '${cents ~/ 100} ₼'
      : '${(cents / 100).toStringAsFixed(2)} ₼';
}

class RecurringDebt {
  final int id;
  final String debtorName;
  final String direction; // 'mənim borcum' | 'mənə olan borclar'
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final double installmentAmount;
  final int dueDay;
  final DateTime? nextDueDate;
  final double amountDueNow;
  final double overdueAmount;
  final double nextPaymentAmount;
  final String dueState; // OK | DUE_TODAY | OVERDUE | COMPLETED
  final String status; // ACTIVE | COMPLETED
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  RecurringDebt({
    required this.id,
    required this.debtorName,
    required this.direction,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.installmentAmount,
    required this.dueDay,
    this.nextDueDate,
    required this.amountDueNow,
    required this.overdueAmount,
    required this.nextPaymentAmount,
    required this.dueState,
    required this.status,
    this.notes,
    required this.createdAt,
    this.completedAt,
  });

  factory RecurringDebt.fromJson(Map<String, dynamic> json) {
    return RecurringDebt(
      id: json['id'],
      debtorName: json['debtorName'] ?? '',
      direction: json['direction'] ?? '',
      totalAmount: _toDouble(json['totalAmount']),
      paidAmount: _toDouble(json['paidAmount']),
      remainingAmount: _toDouble(json['remainingAmount']),
      installmentAmount: _toDouble(json['installmentAmount']),
      dueDay: json['dueDay'] ?? 1,
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.tryParse(json['nextDueDate'].toString())
          : null,
      amountDueNow: _toDouble(json['amountDueNow']),
      overdueAmount: _toDouble(json['overdueAmount']),
      nextPaymentAmount: _toDouble(json['nextPaymentAmount']),
      dueState: json['dueState'] ?? 'OK',
      status: json['status'] ?? 'ACTIVE',
      notes: json['notes'],
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  bool get isCompleted => status == 'COMPLETED' || dueState == 'COMPLETED';
  bool get isOverdue => !isCompleted && dueState == 'OVERDUE';
  bool get isDueToday => !isCompleted && dueState == 'DUE_TODAY';
}

List<RecurringDebt> recurringDebtListFromJson(String str) {
  final data = json.decode(str) as List<dynamic>;
  return data
      .map((e) => RecurringDebt.fromJson(e as Map<String, dynamic>))
      .toList();
}