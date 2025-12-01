// lib/main.dart
import 'package:flutter/material.dart';
import 'package:borc_defteri/screens/login_page.dart';
import 'package:borc_defteri/screens/home_screen.dart';
import 'package:borc_defteri/services/auth_service.dart';
import 'package:upgrader/upgrader.dart';

void main() async {
  // Tətbiq başlamazdan əvvəl lazımi yükləmələri edir
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Borc Dəftəri',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // UpgradeAlert bütün tətbiqi qoruyur.
      home: UpgradeAlert(
        // --- DÜZƏLİŞ BURADADIR ---
        // Parametrlər birbaşa UpgradeAlert-in içinə yazılır

        showIgnore: false,       // "İqnor et" görünməsin
        showLater: false,        // "Sonra" görünməsin
        dialogStyle: UpgradeDialogStyle.material, // Dizayn

        upgrader: Upgrader(
          // Bura boş qala bilər və ya debug ayarları yazıla bilər
          // debugLogging: true,
        ),
        // --------------------------

        child: FutureBuilder<bool>(
          future: AuthService().isSignedIn(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            } else if (snapshot.hasData && snapshot.data == true) {
              return const HomeScreen();
            } else {
              return const LoginPage();
            }
          },
        ),
      ),
    );
  }
}