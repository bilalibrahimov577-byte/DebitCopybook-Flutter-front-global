// lib/main.dart
import 'package:flutter/material.dart';
import 'package:borc_defteri/screens/login_page.dart'; // Login səhifəsi importu
import 'package:borc_defteri/screens/home_screen.dart'; // Home Screen importu
import 'package:borc_defteri/services/auth_service.dart'; // AuthService importu

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Borc Dəftəri',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // BILAL, YENİ: Tətbiqin ilk başladığı səhifəni yoxlayırıq
      home: FutureBuilder<bool>(
        future: AuthService().isSignedIn(), // İstifadəçinin daxil olub-olmadığını yoxlayırıq
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator())); // Yüklənir ekranı
          } else if (snapshot.hasData && snapshot.data == true) {
            return const HomeScreen(); // Əgər daxil olubsa, birbaşa Ana Səhifəyə
          } else {
            return const LoginPage(); // Əks halda Login səhifəsinə
          }
        },
      ),
    );
  }
}