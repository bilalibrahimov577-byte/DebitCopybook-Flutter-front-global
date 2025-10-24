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

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final String _baseUrl = 'https://debitcopybook-backend-global-c9pw.onrender.com';

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
          await _secureStorage.write(key: 'jwt_token_created_at', value: DateTime.now().toIso8601String());

          print('Daxil oldu! JWT Token: $jwtToken');

          // İstifadəçi məlumatlarını da yadda saxla
          await _secureStorage.write(key: 'user_id', value: responseBody['userId'].toString());
          await _secureStorage.write(key: 'user_name', value: responseBody['userName']);
          await _secureStorage.write(key: 'user_email', value: responseBody['userEmail']);

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
    await _secureStorage.delete(key: 'jwt_token_created_at'); // <-- BU ƏLAVƏ OLUNDU
    await _secureStorage.delete(key: 'user_id');
    await _secureStorage.delete(key: 'user_name');
    await _secureStorage.delete(key: 'user_email');
    print("İstifadəçi çıxış etdi və bütün məlumatlar təmizləndi.");
  }

  // İstifadəçinin daxil olub-olmadığını yoxlayır
  Future<bool> isSignedIn() async {
    final String? token = await getJwtToken();
    return token != null && token.isNotEmpty;
  }

  // Bu funksiya əvvəllər `getTokenCreatedAt` adlanırdı, amma artıq istifadə edilmir.
  // İstəsən saxlaya, istəsən silə bilərsən. Zərəri yoxdur.
  Future<DateTime?> getTokenCreatedAt() async {
    final createdAtStr = await _secureStorage.read(key: 'jwt_token_created_at');
    if (createdAtStr == null) return null;
    return DateTime.tryParse(createdAtStr);
  }

  // === YENİ FUNKSİYA: Tokenin vaxtının keçib-keçmədiyini yoxlayır ===
  Future<bool> isTokenExpired() async {
    final createdAtStr = await _secureStorage.read(key: 'jwt_token_created_at');

    // Əgər yaradılma tarixi yoxdursa, token də yoxdur, deməli "vaxtı keçmiş" hesab edirik
    if (createdAtStr == null) {
      return true;
    }

    final createdAt = DateTime.tryParse(createdAtStr);
    if (createdAt == null) {
      return true;
    }

    // İndiki vaxtla yaradılma vaxtı arasındakı fərqi saatla hesablayırıq
    final differenceInMinutes = DateTime.now().difference(createdAt).inMinutes;

    // Əgər fərq 24 saatdan çoxdursa və ya bərabərdirsə, vaxtı keçmişdir (true)
    print("Tokenin yaranmasından $differenceInMinutes saat keçib.");
    return differenceInMinutes >= 10;
  }
}