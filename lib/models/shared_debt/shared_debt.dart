// lib/models/shared_debt/shared_debt.dart

import 'dart:convert';
import 'user_dto.dart';

// JSON siyahısını SharedDebt siyahısına çevirən funksiya
List<SharedDebt> sharedDebtListFromJson(String str) =>
    List<SharedDebt>.from(json.decode(str).map((x) => SharedDebt.fromJson(x)));

class SharedDebt {
  final int id;
  final double debtAmount;
  final String debtorName;
  final String? description;
  final String? notes;
  final String status; // PENDING_APPROVAL, CONFIRMED
  final DateTime? requestExpiryTime; // Sorğunun bitmə vaxtı
  final UserDto user; // Borcun sahibi (sorğunu göndərən)
  final UserDto counterpartyUser; // Qarşı tərəf

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
  });

  factory SharedDebt.fromJson(Map<String, dynamic> json) {
    return SharedDebt(
      id: json['id'],
      debtAmount: (json['debtAmount'] as num).toDouble(),
      debtorName: json['debtorName'],
      description: json['description'],
      notes: json['notes'],
      status: json['status'],
      // Tarix null gələ bilər, ona görə yoxlayırıq
      requestExpiryTime: json['requestExpiryTime'] != null
          ? DateTime.parse(json['requestExpiryTime'])
          : null,
      user: UserDto.fromJson(json['user']),
      counterpartyUser: UserDto.fromJson(json['counterpartyUser']),
    );
  }
}