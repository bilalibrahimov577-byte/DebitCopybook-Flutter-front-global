// lib/services/debt_service.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/debt.dart';
import '../models/debt_request.dart';
import '../models/debt_history.dart';
import 'api_service.dart';

class DebtService {
  final String _endpoint = "/api/v1/debts";

  // === OPTİMALLAŞDIRMA: Təkrarlanan kodu bir köməkçi metoda çıxardıq ===
  // Bu metod endpoint-i parametr olaraq alır və borc siyahısını qaytarır.
  Future<List<Debt>> _fetchDebtList(BuildContext context, String specificEndpoint) async {
    try {
      final response = await ApiService.get(context, specificEndpoint);
      if (response.statusCode == 200) {
        // Bütün metodlarda eyni standart JSON çevirmə funksiyasını istifadə edirik
        return debtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      print("Xəta baş verdi ($specificEndpoint): $e");
      // Xəta halında UI-da göstərmək üçün exception atmaq daha yaxşıdır
      throw Exception('Məlumatları yükləmək alınmadı.');
    }
  }

  // Bütün borcları gətirir
  Future<List<Debt>> getAllDebts(BuildContext context) async {
    return _fetchDebtList(context, _endpoint);
  }

  // Ada görə axtarış edir
  Future<List<Debt>> searchDebtsByName(BuildContext context, String name) async {
    if (name.isEmpty) return getAllDebts(context);
    return _fetchDebtList(context, '$_endpoint/search?name=$name');
  }

  // İl və aya görə filtrləyir
  Future<List<Debt>> getDebtsByYearAndMonth(BuildContext context, int year, int month) async {
    return _fetchDebtList(context, '$_endpoint/filter/by-date?year=$year&month=$month');
  }

  // "Çevik" borcları gətirir
  Future<List<Debt>> getFlexibleDebts(BuildContext context) async {
    return _fetchDebtList(context, '$_endpoint/filter/flexible');
  }

  // === YENİ METOD 1 (daha təmiz versiya) ===
  Future<List<Debt>> getMyDebts(BuildContext context) async {
    return _fetchDebtList(context, '$_endpoint/my-debts');
  }

  // === YENİ METOD 2 (daha təmiz versiya) ===
  Future<List<Debt>> getDebtsToMe(BuildContext context) async {
    return _fetchDebtList(context, '$_endpoint/debts-to-me');
  }

  // --- Qalan metodlar olduğu kimi qalır, çünki onlar fərqli məntiqə sahibdir ---

  Future<Debt?> getDebtById(BuildContext context, int id) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/$id');
      if (response.statusCode == 200) {
        // Burada tək bir obyekt olduğu üçün manual çevirmə normaldır
        return Debt.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      return null;
    } catch (e) {
      print("getDebtById xətası: $e");
      return null;
    }
  }

  Future<List<DebtHistory>> getDebtHistory(BuildContext context, int debtId) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/$debtId/history');
      if (response.statusCode == 200) {
        return debtHistoryListFromJson(response.body);
      }
      return [];
    } catch (e) {
      print("getDebtHistory xətası: $e");
      return [];
    }
  }

  // POST, PUT, DELETE metodları olduğu kimi qalır...
  Future<Map<String, dynamic>> createDebt(BuildContext context, DebtRequest newDebt) async {
    try {
      final response = await ApiService.post(context, _endpoint, body: newDebt.toJson());
      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Borc uğurla yaradıldı!'};
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      print("createDebt xətası: $e");
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  Future<Map<String, dynamic>> updateDebt(BuildContext context, int id, DebtRequest debtToUpdate) async {
    try {
      final response = await ApiService.put(context, '$_endpoint/$id', body: debtToUpdate.toJson());
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Borc uğurla yeniləndi!'};
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      print("updateDebt xətası: $e");
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  Future<Map<String, dynamic>> makePayment(BuildContext context, int id, double amount) async {
    try {
      final response = await ApiService.post(context, '$_endpoint/$id/payments', body: {'amount': amount});
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Ödəniş uğurla qəbul edildi!'};
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      print("makePayment xətası: $e");
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  Future<Map<String, dynamic>> increaseDebt(BuildContext context, int id, double amount) async {
    try {
      final response = await ApiService.post(context, '$_endpoint/$id/increase', body: {'amount': amount});
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Borc uğurla artırıldı!'};
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      print("increaseDebt xətası: $e");
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  Future<bool> deleteDebt(BuildContext context, int id) async {
    try {
      final response = await ApiService.delete(context, '$_endpoint/$id');
      return response.statusCode == 204;
    } catch (e) {
      print("deleteDebt xətası: $e");
      return false;
    }
  }
}