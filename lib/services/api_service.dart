import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:borc_defteri/services/auth_service.dart';
import 'package:borc_defteri/screens/login_page.dart';

class ApiService {
  // Backend-in əsas URL-i bir yerdə saxlanılır ki, təkrar-təkrar yazmayaq
  static const String _baseUrl = 'https://debitcopybook-backend-global-c9pw.onrender.com';

  // Bu AuthService obyekti tokeni almaq və çıxış etmək üçün lazımdır
  static final AuthService _authService = AuthService();

  // BÜTÜN GET sorğuları bu mərkəzi funksiyadan keçəcək
  static Future<http.Response> get(BuildContext context, String endpoint) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    // ƏN VACİB HİSSƏ: TOKEN YOXLAMASI
    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      // Xəta halında sonrakı kodun işləməməsi üçün istisna (exception) atırıq
      throw Exception('Unauthorized');
    }
    return response;
  }

  // BÜTÜN POST sorğuları bu mərkəzi funksiyadan keçəcək
  static Future<http.Response> post(BuildContext context, String endpoint, {Object? body}) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    // ƏN VACİB HİSSƏ: TOKEN YOXLAMASI
    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      throw Exception('Unauthorized');
    }
    return response;
  }

  // BÜTÜN PUT sorğuları bu mərkəzi funksiyadan keçəcək (update üçün)
  static Future<http.Response> put(BuildContext context, String endpoint, {Object? body}) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      throw Exception('Unauthorized');
    }
    return response;
  }

  // BÜTÜN DELETE sorğuları bu mərkəzi funksiyadan keçəcək
  static Future<http.Response> delete(BuildContext context, String endpoint) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    final response = await http.delete(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      throw Exception('Unauthorized');
    }
    return response;
  }


  // 401 XƏTASI BAŞ VERDİKDƏ İŞƏ DÜŞƏN MƏNTİQ
  static void _handleUnauthorized(BuildContext context) async {
    // Naviqatorun mövcud olub-olmadığını yoxlayırıq. Bu, xətaların qarşısını alır.
    if (!context.mounted) return;

    print("ApiService: 401 Unauthorized xətası alındı. İstifadəçi çıxış edilir.");
    // Əvvəlcə bütün lokal məlumatları təmizlə
    await _authService.signOut();

    // Sonra istifadəçini giriş səhifəsinə yönləndir və bütün əvvəlki səhifələri sil
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }
}
