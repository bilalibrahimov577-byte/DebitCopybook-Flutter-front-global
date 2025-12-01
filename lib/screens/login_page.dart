// lib/screens/login_page.dart

import 'package:flutter/material.dart';
import 'package:borc_defteri/services/auth_service.dart';
import 'package:borc_defteri/screens/home_screen.dart';
import 'package:upgrader/upgrader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      // --- DÜZƏLİŞ BURADADIR ---
      // Parametrləri Upgrader()-in içindən çıxarıb, UpgradeAlert-in içinə qoyduq
      upgrader: Upgrader(
        // Bura yalnız debug və ya vaxt ayarları yazılır
        // debugLogging: true, // Test edəndə aça bilərsən
      ),

      // Məcburi yeniləmə parametrləri burada olmalıdır:

      showIgnore: false,       // "İqnor et" görünməsin
      showLater: false,        // "Sonra" görünməsin
      dialogStyle: UpgradeDialogStyle.material, // Dizayn
      // --------------------------

      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF6A1B9A),
                Color(0xFFAB47BC),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Borc Dəftərinizə Xoş Gəlmisiniz!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                const Text(
                  'Daxil olmaq üçün Google hesabınızdan istifadə edin',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    bool success = await _authService.signInWithGoogle();

                    if (!context.mounted) return;

                    if (success) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Daxil olma uğursuz oldu.')),
                      );
                    }
                  },
                  icon: Image.asset('assets/google_logo.png', height: 24.0),
                  label: const Text('Google ilə daxil ol',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}