class DebtRequest {
  final String debtorName;

  final String? description;

  final double debtAmount;

  final String? notes;

  final int? dueYear;

  final int? dueMonth;

  final bool isFlexibleDueDate;

  DebtRequest({
    required this.debtorName,
    this.description,
    required this.debtAmount,
    this.notes,

// YENİ SAHƏLƏRİ KONSTRUKTORA ƏLAVƏ ETDİK

    this.dueYear,
    this.dueMonth,
    required this.isFlexibleDueDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'debtorName': debtorName,
      'description': description,
      'debtAmount': debtAmount,
      'notes': notes,
      'dueYear': dueYear,
      'dueMonth': dueMonth,
      'isFlexibleDueDate': isFlexibleDueDate,
    };
  }
}
