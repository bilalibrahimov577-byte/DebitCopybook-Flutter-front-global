import 'package:http/http.dart' as http;

import '../models/debt.dart';

import '../models/debt_request.dart';

import 'auth_service.dart'; // Əlavə olaraq AuthService-i import edirik
import 'dart:convert';
class DebtService {
// Backend-in deploy olunmuş URL-i.

  final String baseUrl =
      "https://debitcopybook-backend-global-c9pw.onrender.com/api/v1/debts";

// AuthService-in bir instance-ını yaradırıq.

  final AuthService _authService = AuthService();

// JWT tokeni ilə bütün borcları gətirir.

  Future<List<Debt>> getAllDebts() async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return []; // Token yoxdursa, boş siyahı qaytar

    var url = Uri.parse('$baseUrl/findAllDebts');

    try {
      var response = await http.get(
        url,

        headers: {
          'Authorization': 'Bearer $jwtToken'
        }, // JWT tokeni başlığa əlavə edirik
      );

      if (response.statusCode == 200) return debtListFromJson(response.body);

      return [];
    } catch (e) {
      return [];
    }
  }

// ID-yə görə borcu gətirir.

  Future<Debt?> getDebtById(int id) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return null;

    var url = Uri.parse('$baseUrl/findDebtById/$id');

    try {
      var response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        return Debt.fromJson(json.decode(response.body));
      }

      return null;
    } catch (e) {
      return null;
    }
  }

// Yeni borc yaradır.

// Future<Map<String, dynamic>> createDebt(DebtRequest newDebt) async {

// final String? jwtToken = await _authService.getJwtToken();

// if (jwtToken == null) {

// return {'success': false, 'message': 'Autentifikasiya tokeni yoxdur.'};

// }

//

// var url = Uri.parse(baseUrl);

// try {

// var response = await http.post(

// url,

// headers: {

// 'Authorization': 'Bearer $jwtToken',

// 'Content-Type': 'application/json; charset=UTF-8',

// },

// body: jsonEncode(newDebt.toJson()),

// );

//

// if (response.statusCode == 201) {

// return {'success': true, 'message': 'Borc uğurla yaradıldı!'};

// } else if (response.statusCode == 400) {

// final errorBody = json.decode(utf8.decode(response.bodyBytes));

// return {'success': false, 'message': errorBody['message'] ?? 'Yanlış sorğu göndərildi.'};

// } else {

// return {'success': false, 'message': 'Server xətası: ${response.statusCode}'};

// }

// } catch (e) {

// return {'success': false, 'message': 'Sistem xətası baş verdi. İnternet bağlantınızı yoxlayın.'};

// }

// }

  Future<Map<String, dynamic>> createDebt(DebtRequest newDebt) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) {
      return {'success': false, 'message': 'Autentifikasiya tokeni yoxdur.'};
    }

    var url = Uri.parse(baseUrl);

    try {
      var response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(newDebt.toJson()),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Borc uğurla yaradıldı!'};
      } else if (response.statusCode == 400) {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));

// 400 Bad Request üçün spesifik mesajı göstər

        return {
          'success': false,
          'message': errorBody['message'] ?? 'Yanlış sorğu göndərildi.'
        };
      } else if (response.statusCode == 500) {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));

// 500 Internal Server Error üçün xüsusi mesajı idarə et

// Bu, sizin serverinizdəki IllegalStateException-dən gələn mesaj olmalıdır

        return {
          'success': false,
          'message': errorBody['message'] ??
              'Gözlənilməz server xətası baş verdi. Zəhmət olmasa, daha sonra yenidən cəhd edin.'
        };
      } else {
// Digər status kodları üçün ümumi xəta mesajı

        return {
          'success': false,
          'message': 'Server xətası: ${response.statusCode}'
        };
      }
    } catch (e) {
// İnternet bağlantısı və ya digər sistem xətaları

      return {
        'success': false,
        'message': 'Sistem xətası baş verdi. İnternet bağlantınızı yoxlayın.'
      };
    }
  }

// Borcu yeniləyir.

  Future<Map<String, dynamic>> updateDebt(
      int id, DebtRequest debtToUpdate) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) {
      return {'success': false, 'message': 'Autentifikasiya tokeni yoxdur.'};
    }

    var url = Uri.parse('$baseUrl/updateDebt/$id');

    try {
      var response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(debtToUpdate.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Borc uğurla yeniləndi!'};
      } else if (response.statusCode == 400) {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));

        return {
          'success': false,
          'message': errorBody['message'] ?? 'Yanlış sorğu göndərildi.'
        };
      } else {
        return {
          'success': false,
          'message': 'Server xətası: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

// Ödəniş edir.

  Future<Debt?> makePayment(int id, double amount) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return null;

    var url = Uri.parse('$baseUrl/payDebt/$id?amount=$amount');

    try {
      var response = await http.patch(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200)
        return Debt.fromJson(json.decode(response.body));

      return null;
    } catch (e) {
      return null;
    }
  }

// Borcu artırır.

  Future<Debt?> increaseDebt(int id, double amount) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return null;

    var url = Uri.parse('$baseUrl/increaseDebt/$id?amount=$amount');

    try {
      var response = await http.patch(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200)
        return Debt.fromJson(json.decode(response.body));

      return null;
    } catch (e) {
      return null;
    }
  }

// Borcu silir.

  Future<bool> deleteDebt(int id) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return false;

    var url = Uri.parse('$baseUrl/deleteDebt/$id');

    try {
      var response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

// Ada görə borcları axtarır.

  Future<List<Debt>> searchDebtsByName(String name) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return [];

    if (name.isEmpty) return getAllDebts();

    var url = Uri.parse('$baseUrl/searchByDebtorName?debtorName=$name');

    try {
      var response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) return debtListFromJson(response.body);

      return [];
    } catch (e) {
      return [];
    }
  }

// İlə və aya görə borcları axtarır.

  Future<List<Debt>> getDebtsByYearAndMonth(int year, int month) async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return [];

    var url = Uri.parse('$baseUrl/findByYearAndMonth?year=$year&month=$month');

    try {
      var response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) return debtListFromJson(response.body);

      return [];
    } catch (e) {
      return [];
    }
  }

// Müddəti uzadıla bilən borcları axtarır.

  Future<List<Debt>> getFlexibleDebts() async {
    final String? jwtToken = await _authService.getJwtToken();

    if (jwtToken == null) return [];

    var url = Uri.parse('$baseUrl/findFlexibleDebts');

    try {
      var response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) return debtListFromJson(response.body);

      return [];
    } catch (e) {
      return [];
    }
  }
}
