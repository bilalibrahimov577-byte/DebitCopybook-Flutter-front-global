// lib/services/auth_service.dart

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    serverClientId: '1073865818355-am5kd3qm1otm22f6htt3n8h0ogq753fv.apps.googleusercontent.com',
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // URL-ləri bir mərkəzdən idarə etmək daha yaxşıdır, amma hələlik belə qalsın
  //final String _baseUrl = 'https://debitcopybook-backend-global-c9pw.onrender.com';
  final String _baseUrl = 'https://debitcopybook-backend-global-test1.onrender.com';

  // Google ilə daxil olma prosesini idarə edir.
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // İstifadəçi daxil olmanı ləğv etdi
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        // ID tokeni backend-ə göndər
        final response = await http.post(
          Uri.parse('$_baseUrl/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseBody = jsonDecode(response.body);
          final String jwtToken = responseBody['token'];

          // JWT tokeni və yaradılma tarixini təhlükəsiz şəkildə yadda saxla
          await _secureStorage.write(key: 'jwt_token', value: jwtToken);
         // await _secureStorage.write(key: 'jwt_token_created_at', value: DateTime.now().toIso8G01String());
          await _secureStorage.write(key: 'jwt_token_created_at', value: DateTime.now().toIso8601String());
          print('Daxil oldu! JWT Token: $jwtToken');

          // İstifadəçi məlumatlarını da yadda saxla
          await _secureStorage.write(key: 'user_id', value: responseBody['userId'].toString());
          await _secureStorage.write(key: 'user_name', value: responseBody['userName']);
          await _secureStorage.write(key: 'user_email', value: responseBody['userEmail']);

          // --- ƏSAS DƏYİŞİKLİK BURADADIR ---
          // Backend-dən gələn 'userDebtId' sahəsini yoxlayıb yadda saxlayırıq
          if (responseBody.containsKey('userDebtId') && responseBody['userDebtId'] != null) {
            await _secureStorage.write(key: 'user_debt_id', value: responseBody['userDebtId']);
            print("İstifadəçi daxil oldu və Borc ID-si yadda saxlandı: ${responseBody['userDebtId']}");
          } else {
            print("XƏBƏRDARLIQ: Backend cavabında 'userDebtId' tapılmadı!");
          }
          // ---------------------------------

          return true; // Uğurlu daxil oldu
        } else {
          // Backend xətası
          print('Backend-dən xəta: ${response.statusCode} - ${response.body}');
          return false;
        }
      }
    } catch (error) {
      print('Google ilə daxil olma xətası: $error');
      return false;
    }
    return false;
  }

  // Yaddaşdan JWT tokeni oxuyur.
  Future<String?> getJwtToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  // İstifadəçini çıxarır (logout) və bütün saxlanmış məlumatları təmizləyir
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    // Bütün təhlükəsiz yaddaşı təmizləyirik
    await _secureStorage.delete(key: 'jwt_token');
    await _secureStorage.delete(key: 'jwt_token_created_at');
    await _secureStorage.delete(key: 'user_id');
    await _secureStorage.delete(key: 'user_name');
    await _secureStorage.delete(key: 'user_email');

    // --- ƏSAS DƏYİŞİKLİK BURADADIR ---
    await _secureStorage.delete(key: 'user_debt_id');
    // ---------------------------------

    print("İstifadəçi çıxış etdi və bütün məlumatlar təmizləndi.");
  }

  // İstifadəçinin daxil olub-olmadığını yoxlayır
  Future<bool> isSignedIn() async {
    final String? token = await getJwtToken();
    return token != null && token.isNotEmpty;
  }

  Future<DateTime?> getTokenCreatedAt() async {
    final createdAtStr = await _secureStorage.read(key: 'jwt_token_created_at');
    if (createdAtStr == null) return null;
    return DateTime.tryParse(createdAtStr);
  }

  Future<bool> isTokenExpired() async {
    final createdAtStr = await _secureStorage.read(key: 'jwt_token_created_at');
    if (createdAtStr == null) {
      return true;
    }
    final createdAt = DateTime.tryParse(createdAtStr);
    if (createdAt == null) {
      return true;
    }
    final differenceInMinutes = DateTime.now().difference(createdAt).inMinutes;
    print("Tokenin yaranmasından $differenceInMinutes dəqiqə keçib.");
    // Tokenin vaxtını dəqiqə ilə yoxlayırıq, məsələn 1 gün = 1440 dəqiqə
    return differenceInMinutes >= 1440; // 24 saat
  }

  Future<String?> getUserDebtId() async {
    return await _secureStorage.read(key: 'user_debt_id');
  }

  // Bu metoda ehtiyac yox idi, amma zərər verməməsi üçün saxlayıram
  Future<String?> getUserUniqueId() async {
    return await _secureStorage.read(key: 'user_id');
  }
}