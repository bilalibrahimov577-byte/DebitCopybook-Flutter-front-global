import 'dart:convert';

// JSON siyahısını DebtHistory siyahısına çevirən funksiya
List<DebtHistory> debtHistoryListFromJson(String str) =>
    List<DebtHistory>.from(json.decode(str).map((x) => DebtHistory.fromJson(x)));

class DebtHistory {
  final int id;
  final String eventType;
  final String description;
  final double? amount; // Məbləğ null ola bilər
  final DateTime eventDate;

  DebtHistory({
    required this.id,
    required this.eventType,
    required this.description,
    this.amount,
    required this.eventDate,
  });

  factory DebtHistory.fromJson(Map<String, dynamic> json) => DebtHistory(
    id: json["id"],
    eventType: json["eventType"],
    description: json["description"],
    amount: json["amount"]?.toDouble(), // JSON-dan gələn dəyəri double-a çeviririk
    eventDate: DateTime.parse(json["eventDate"]),
  );
}