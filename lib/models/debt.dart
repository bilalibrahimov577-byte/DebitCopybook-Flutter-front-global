import 'dart:convert'; // JSON ilə işləmək üçün lazımdır

// Bu klas bizim Java-dakı DebtResponseDto-nun Flutter qarşılığıdır

class Debt {
  final int id;

  final String debtorName;

  final String?
      description; // Sual işarəsi o deməkdir ki, bu məlumat "null" ola bilər

  final double debtAmount;

  final String createdAt;

  final int? dueYear;

  final int? dueMonth;

  final bool isFlexibleDueDate;

  final String? notes;

// Konstruktor: Yeni bir Debt obyekti yaradarkən bu məlumatları tələb edir

  Debt({
    required this.id,
    required this.debtorName,
    this.description,
    required this.debtAmount,
    required this.createdAt,
    this.dueYear,
    this.dueMonth,
    required this.isFlexibleDueDate,
    this.notes,
  });

// Bu, bizim "tərcüməçi" funksiyamızdır.

// JSON formatında bir "xəritə" (Map) alır və onu bizim Debt obyektimizə çevirir.

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'],

      debtorName: json['debtorName'],

      description: json['description'],

// JSON-dakı rəqəmlər bəzən tam (integer), bəzən kəsr (double) olur.

// Hər iki halda da işləməsi üçün belə yazırıq.

      debtAmount: (json['debtAmount'] as num).toDouble(),

      createdAt: json['createdAt'],

      dueYear: json['dueYear'],

      dueMonth: json['dueMonth'],

     // isFlexibleDueDate: json['isFlexibleDueDate'],
      isFlexibleDueDate: json['isFlexibleDueDate'] ?? false,
      notes: json['notes'],
    );
  }
}

// Bu funksiya isə JSON formatında bütöv bir siyahı (string) alır

// və onu Debt obyektlərindən ibarət bir siyahıya (List<Debt>) çevirir.

List<Debt> debtListFromJson(String str) {
  final jsonData = json.decode(str); // Əvvəlcə mətni JSON-a çeviririk

// Sonra hər bir JSON obyektini götürüb Debt.fromJson ilə Debt obyektinə çeviririk

  return List<Debt>.from(jsonData.map((item) => Debt.fromJson(item)));
}
