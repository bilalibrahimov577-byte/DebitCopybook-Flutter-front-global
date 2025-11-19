// lib/models/shared_debt/shared_debt_request.dart

class SharedDebtRequest {
  final String counterpartyDebtId;
  final String debtorName;
  final double debtAmount;
  final String? description;
  final String? notes;
  // Backend-dəki DTO ilə eyni olması üçün bu sahələr də lazımdır
  final int? dueYear;
  final int? dueMonth;
  final bool isFlexibleDueDate;

  SharedDebtRequest({
    required this.counterpartyDebtId,
    required this.debtorName,
    required this.debtAmount,
    this.description,
    this.notes,
    this.dueYear,
    this.dueMonth,
    required this.isFlexibleDueDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'counterpartyDebtId': counterpartyDebtId,
      'debtorName': debtorName,
      'debtAmount': debtAmount,
      'description': description,
      'notes': notes,
      'dueYear': dueYear,
      'dueMonth': dueMonth,
      'isFlexibleDueDate': isFlexibleDueDate,
    };
  }
}