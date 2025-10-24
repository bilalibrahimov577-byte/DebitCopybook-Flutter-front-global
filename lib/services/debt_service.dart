// lib/services/debt_service.dart

import 'package:flutter/material.dart'; // YENİ: BuildContext üçün lazımdır
import 'dart:convert';
import '../models/debt.dart';
import '../models/debt_request.dart';
import '../models/debt_history.dart';
import 'api_service.dart'; // YENİ: Artıq birbaşa ApiService-dən istifadə edirik

class DebtService {
  // Bütün endpoint-lər üçün əsas hissə. ApiService-dəki baseUrl-ə əlavə olunacaq.
  final String _endpoint = "/api/v1/debts";

  // Bütün borcları gətirir
  Future<List<Debt>> getAllDebts(BuildContext context) async {
    try {
      final response = await ApiService.get(context, _endpoint);
      if (response.statusCode == 200) {
        return debtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      // ApiService 401 xətasını özü idarə edir. Bu hissə digər xətalar üçündür.
      print("getAllDebts xətası: $e");
      return [];
    }
  }

  // ID-yə görə bir borcu gətirir
  Future<Debt?> getDebtById(BuildContext context, int id) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/$id');
      if (response.statusCode == 200) {
        return Debt.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print("getDebtById xətası: $e");
      return null;
    }
  }

  // Yeni borc yaradır
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

  // Mövcud borcu yeniləyir
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

  // Ödəniş edir
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

  // Borcu artırır
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

  // Borcu silir
  Future<bool> deleteDebt(BuildContext context, int id) async {
    try {
      final response = await ApiService.delete(context, '$_endpoint/$id');
      return response.statusCode == 204;
    } catch (e) {
      print("deleteDebt xətası: $e");
      return false;
    }
  }

  // Borcun tarixçəsini gətirir
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

  // Ada görə axtarış edir
  Future<List<Debt>> searchDebtsByName(BuildContext context, String name) async {
    if (name.isEmpty) return getAllDebts(context); // Axtarış boşdursa, bütün borcları gətir
    try {
      final response = await ApiService.get(context, '$_endpoint/search?name=$name');
      if (response.statusCode == 200) {
        return debtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      print("searchDebtsByName xətası: $e");
      return [];
    }
  }

  // İl və aya görə filtrləyir
  Future<List<Debt>> getDebtsByYearAndMonth(BuildContext context, int year, int month) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/filter/by-date?year=$year&month=$month');
      if (response.statusCode == 200) {
        return debtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      print("getDebtsByYearAndMonth xətası: $e");
      return [];
    }
  }

  // "Çevik" borcları gətirir
  Future<List<Debt>> getFlexibleDebts(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/filter/flexible');
      if (response.statusCode == 200) {
        return debtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      print("getFlexibleDebts xətası: $e");
      return [];
    }
  }

//24 oktyabr 2025-ci il
  Future<List<Debt>> getMyDebts(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '/api/v1/debts/my-debts');

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        List<Debt> debts = body.map((dynamic item) => Debt.fromJson(item)).toList();
        return debts;
      } else {
        // Xəta halında boş siyahı qaytar və ya xəta mesajı göstər
        throw Exception('Mənim borclarımı yükləmək alınmadı');
      }
    } catch (e) {
      // "Unauthorized" xətası ApiService tərəfindən idarə olunur, digər xətalar üçün
      print(e.toString());
      throw Exception('Bir xəta baş verdi: $e');
    }
  }

  // === YENİ METOD 2: "Mənə olan borclar" üçün ===
  Future<List<Debt>> getDebtsToMe(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '/api/v1/debts/debts-to-me');

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        List<Debt> debts = body.map((dynamic item) => Debt.fromJson(item)).toList();
        return debts;
      } else {
        throw Exception('Mənə olan borcları yükləmək alınmadı');
      }
    } catch (e) {
      print(e.toString());
      throw Exception('Bir xəta baş verdi: $e');
    }
  }





}