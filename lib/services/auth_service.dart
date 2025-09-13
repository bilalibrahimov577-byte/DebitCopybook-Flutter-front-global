import 'package:google_sign_in/google_sign_in.dart';

import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// BILAL, bu sinif Google ilə daxil olma və JWT tokeni idarə etmək üçün MÜTLƏQDİR.

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(

// Android Client ID-ni burada təyin etmək lazım deyil,

// lakin web tətbiqi üçün istifadə olunan serverClientId Flutter-in

// Android tətbiqindən də gələ bilər.

// Əgər spesifik bir Android Client ID təyin etmək lazım olarsa:

// serverClientId: "YOUR_FLUTTER_ANDROID_CLIENT_ID.apps.googleusercontent.com",

      );

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

// Backend-in deploy olunmuş URL-i.

// BILAL, bunu öz Render.com URL-inlə ƏVƏZ ET!

  final String _baseUrl =
      'https://debitcopybook-backend-global-c9pw.onrender.com';

//'https://debitcopybook-backend-global-q1n3.onrender.com';

// Google ilə daxil olma prosesini idarə edir.

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
// İstifadəçi daxil olmanı ləğv etdi

        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

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

// JWT tokeni təhlükəsiz şəkildə yadda saxla

          await _secureStorage.write(key: 'jwt_token', value: jwtToken);

          print('Daxil oldu! JWT Token: $jwtToken');

// İstifadəçi ID, Ad, Email də yadda saxlaya bilərsən

          await _secureStorage.write(
              key: 'user_id', value: responseBody['userId'].toString());

          await _secureStorage.write(
              key: 'user_name', value: responseBody['userName']);

          await _secureStorage.write(
              key: 'user_email', value: responseBody['userEmail']);

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

// İstifadəçini çıxarır (logout)

  Future<void> signOut() async {
    await _googleSignIn.signOut();

    await _secureStorage.delete(key: 'jwt_token');

    await _secureStorage.delete(key: 'user_id');

    await _secureStorage.delete(key: 'user_name');

    await _secureStorage.delete(key: 'user_email');
  }

// İstifadəçinin daxil olub-olmadığını yoxlayır

  Future<bool> isSignedIn() async {
    final String? token = await getJwtToken();

    return token != null && token.isNotEmpty;
  }
}
