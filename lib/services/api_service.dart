// lib/services/api_service.dart

import 'package:flutter/foundation.dart'; // <-- YENİ İMPORT
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:borc_defteri/services/auth_service.dart';
import 'package:borc_defteri/screens/login_page.dart';

class ApiService {
  // --- BÜTÜN DƏYİŞİKLİK BURADADIR ---

  // 1. Production (əsas) servisinizin URL-i
  static const String _productionBaseUrl = "https://debitcopybook-backend-global-c9pw.onrender.com";
  // 2. Yeni yaratdığınız test servisinizin URL-i
  static const String _testBaseUrl = "https://debitcopybook-backend-global-test1.onrender.com";

  // 3. Tətbiq debug rejimdədirsə test URL-ni, deyilsə production URL-ni avtomatik seç
  static String get _baseUrl {
    return kDebugMode ? _testBaseUrl : _productionBaseUrl;
  }
  // ------------------------------------


  static final AuthService _authService = AuthService();

  static Future<http.Response> get(BuildContext context, String endpoint) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    // --- Diaqnostika üçün əlavə edilib ---
    debugPrint("GET Request to: $url");
    // ------------------------------------

    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      throw Exception('Unauthorized');
    }
    return response;
  }

  static Future<http.Response> post(BuildContext context, String endpoint, {Object? body}) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    // --- Diaqnostika üçün əlavə edilib ---
    debugPrint("POST Request to: $url");
    // ------------------------------------

    final response = await http.post(
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

  static Future<http.Response> put(BuildContext context, String endpoint, {Object? body}) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    debugPrint("PUT Request to: $url");

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

  static Future<http.Response> delete(BuildContext context, String endpoint) async {
    final token = await _authService.getJwtToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    debugPrint("DELETE Request to: $url");

    final response = await http.delete(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      throw Exception('Unauthorized');
    }
    return response;
  }

  static void _handleUnauthorized(BuildContext context) async {
    if (!context.mounted) return;

    debugPrint("ApiService: 401 Unauthorized xətası alındı. İstifadəçi çıxış edilir.");
    await _authService.signOut();

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }
}