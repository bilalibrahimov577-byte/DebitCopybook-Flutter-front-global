import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/debt.dart';
import '../models/debt_request.dart';
import '../models/debt_history.dart'; // YENİ: Tarixçə modeli üçün import
import 'auth_service.dart';

class DebtService {
  final String baseUrl = "https://debitcopybook-backend-global-c9pw.onrender.com/api/v1/debts";
  final AuthService _authService = AuthService();

  // Helper funksiya: Başlıqları hazırlamaq üçün
  Future<Map<String, String>?> _getHeaders({bool includeContentType = false}) async {
    final String? jwtToken = await _authService.getJwtToken();
    if (jwtToken == null) return null;

    final headers = {'Authorization': 'Bearer $jwtToken'};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    return headers;
  }

  // YENİLƏNDİ: URL daha sadə oldu
  Future<List<Debt>> getAllDebts() async {
    final headers = await _getHeaders();
    if (headers == null) return [];

    final url = Uri.parse(baseUrl); // URL: .../api/v1/debts
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) return debtListFromJson(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // YENİLƏNDİ: URL daha sadə oldu
  Future<Debt?> getDebtById(int id) async {
    final headers = await _getHeaders();
    if (headers == null) return null;

    final url = Uri.parse('$baseUrl/$id'); // URL: .../api/v1/debts/5
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return Debt.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // DƏYİŞMƏDİ: Bu metodun məntiqi düzgün idi
  Future<Map<String, dynamic>> createDebt(DebtRequest newDebt) async {
    final headers = await _getHeaders(includeContentType: true);
    if (headers == null) {
      return {'success': false, 'message': 'Autentifikasiya tokeni yoxdur.'};
    }

    final url = Uri.parse(baseUrl); // URL: POST .../api/v1/debts
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(newDebt.toJson()),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Borc uğurla yaradıldı!'};
      } else {
        // Xəta mesajlarını idarə etmək üçün mərkəzləşdirilmiş yanaşma
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Sistem xətası baş verdi. İnternet bağlantınızı yoxlayın.'};
    }
  }

  // YENİLƏNDİ: URL və metod növü (PUT) dəyişdi
  Future<Map<String, dynamic>> updateDebt(int id, DebtRequest debtToUpdate) async {
    final headers = await _getHeaders(includeContentType: true);
    if (headers == null) {
      return {'success': false, 'message': 'Autentifikasiya tokeni yoxdur.'};
    }

    final url = Uri.parse('$baseUrl/$id'); // URL: PUT .../api/v1/debts/5
    try {
      final response = await http.put( // http.patch -> http.put
        url,
        headers: headers,
        body: jsonEncode(debtToUpdate.toJson()),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Borc uğurla yeniləndi!'};
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  // YENİLƏNDİ: URL, metod növü (POST) və body-də məbləğ göndərilməsi
  Future<Map<String, dynamic>> makePayment(int id, double amount) async {
    final headers = await _getHeaders(includeContentType: true);
    if (headers == null) return {'success': false, 'message': 'Autentifikasiya tokeni yoxdur.'};

    final url = Uri.parse('$baseUrl/$id/payments'); // URL: POST .../api/v1/debts/5/payments
    try {
      final body = jsonEncode({'amount': amount}); // Məbləği JSON body olaraq göndəririk
      final response = await http.post(url, headers: headers, body: body); // http.patch -> http.post

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Ödəniş uğurla qəbul edildi!'};
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  // YENİLƏNDİ: URL, metod növü (POST) və body-də məbləğ göndərilməsi
  Future<Map<String, dynamic>> increaseDebt(int id, double amount) async {
    final headers = await _getHeaders(includeContentType: true);
    if (headers == null) return {'success': false, 'message': 'Autentifikasiya tokeni yoxdur.'};

    final url = Uri.parse('$baseUrl/$id/increase'); // URL: POST .../api/v1/debts/5/increase
    try {
      final body = jsonEncode({'amount': amount});
      final response = await http.post(url, headers: headers, body: body); // http.patch -> http.post

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Borc uğurla artırıldı!'};
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorBody['message'] ?? 'Bilinməyən xəta baş verdi.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  // YENİLƏNDİ: URL daha sadə oldu
  Future<bool> deleteDebt(int id) async {
    final headers = await _getHeaders();
    if (headers == null) return false;

    final url = Uri.parse('$baseUrl/$id'); // URL: .../api/v1/debts/5
    try {
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // === YENİ FUNKSİYA: Borcun tarixçəsini gətirmək üçün ===
  Future<List<DebtHistory>> getDebtHistory(int debtId) async {
    final headers = await _getHeaders();
    if (headers == null) return [];

    final url = Uri.parse('$baseUrl/$debtId/history'); // URL: GET .../api/v1/debts/5/history
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return debtHistoryListFromJson(response.body); // debtHistoryListFromJson funksiyasını yaratmalıyıq
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // YENİLƏNDİ: URL daha standart oldu
  Future<List<Debt>> searchDebtsByName(String name) async {
    final headers = await _getHeaders();
    if (headers == null) return [];
    if (name.isEmpty) return getAllDebts();

    final url = Uri.parse('$baseUrl/search?name=$name'); // URL: .../api/v1/debts/search?name=...
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) return debtListFromJson(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // YENİLƏNDİ: URL daha standart oldu
  Future<List<Debt>> getDebtsByYearAndMonth(int year, int month) async {
    final headers = await _getHeaders();
    if (headers == null) return [];

    final url = Uri.parse('$baseUrl/filter/by-date?year=$year&month=$month'); // URL: .../api/v1/debts/filter/by-date?...
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) return debtListFromJson(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // YENİLƏNDİ: URL daha standart oldu
  Future<List<Debt>> getFlexibleDebts() async {
    final headers = await _getHeaders();
    if (headers == null) return [];

    final url = Uri.parse('$baseUrl/filter/flexible'); // URL: .../api/v1/debts/filter/flexible
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) return debtListFromJson(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }
}