// lib/models/shared_debt/shared_debt.dart

import 'dart:convert';
import 'user_dto.dart';

List<SharedDebt> sharedDebtListFromJson(String str) =>
    List<SharedDebt>.from(json.decode(str).map((x) => SharedDebt.fromJson(x)));

class SharedDebt {
  final int id;
  final double debtAmount;
  final String debtorName;
  final String? description;
  final String? notes;
  final String status;
  final DateTime? requestExpiryTime;
  final UserDto user;
  final UserDto counterpartyUser;

  // --- YENİ ƏLAVƏLƏR (Backend göndərir, biz tutmalıyıq) ---
  final String? createdAt; // Backend bunu String göndərir (məs: "2025-11-19")
  final int? dueYear;
  final int? dueMonth;
  final bool isFlexibleDueDate;
  // --------------------------------------------------------

  SharedDebt({
    required this.id,
    required this.debtAmount,
    required this.debtorName,
    this.description,
    this.notes,
    required this.status,
    this.requestExpiryTime,
    required this.user,
    required this.counterpartyUser,

    // Constructor-a əlavə edirik
    this.createdAt,
    this.dueYear,
    this.dueMonth,
    required this.isFlexibleDueDate,
  });

  factory SharedDebt.fromJson(Map<String, dynamic> json) {
    return SharedDebt(
      id: json['id'],
      debtAmount: (json['debtAmount'] as num).toDouble(),
      debtorName: json['debtorName'],
      description: json['description'],
      notes: json['notes'],
      status: json['status'],
      requestExpiryTime: json['requestExpiryTime'] != null
          ? DateTime.parse(json['requestExpiryTime'])
          : null,
      user: UserDto.fromJson(json['user']),
      counterpartyUser: UserDto.fromJson(json['counterpartyUser']),

      // JSON-dan oxuyuruq
      createdAt: json['createdAt'],
      dueYear: json['dueYear'],
      dueMonth: json['dueMonth'],
      // isFlexibleDueDate null gələrsə false qəbul edirik
      isFlexibleDueDate: json['isFlexibleDueDate'] ?? false,
    );
  }
}