// lib/main.dart
import 'package:flutter/material.dart';
import 'package:borc_defteri/screens/login_page.dart';
import 'package:borc_defteri/screens/home_screen.dart';
import 'package:borc_defteri/services/auth_service.dart';
import 'package:borc_defteri/services/biometric_service.dart';
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
        showIgnore: false,       // "İqnor et" görünməsin
        showLater: false,        // "Sonra" görünməsin
        dialogStyle: UpgradeDialogStyle.material, // Dizayn

        upgrader: Upgrader(),

        child: FutureBuilder<bool>(
          future: AuthService().isSignedIn(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            } else if (snapshot.hasData && snapshot.data == true) {
              // İstifadəçi daxil olubsa, BiometricGuard vasitəsilə yoxlayırıq
              return const BiometricGuard();
            } else {
              return const LoginPage();
            }
          },
        ),
      ),
    );
  }
}

// Biometriya yoxlanışını idarə edən Widget
class BiometricGuard extends StatefulWidget {
  const BiometricGuard({super.key});

  @override
  State<BiometricGuard> createState() => _BiometricGuardState();
}

class _BiometricGuardState extends State<BiometricGuard> {
  final BiometricService _biometricService = BiometricService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkAndAuthenticate();
  }

  Future<void> _checkAndAuthenticate() async {
    setState(() => _isLoading = true);

    bool enabled = await _biometricService.isBiometricEnabled();
    _isBiometricEnabled = enabled;

    if (enabled) {
      bool authSuccess = await _biometricService.authenticate();
      if (mounted) {
        setState(() {
          _isAuthenticated = authSuccess;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isAuthenticated = true; // Biometriya aktiv deyilsə birbaşa keç
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated || !_isBiometricEnabled) {
      return const HomeScreen();
    }

    // Doğrulama uğursuz olduqda və ya ləğv edildikdə görünən ekran
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 80,
                color: Color(0xFF6A1B9A),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tətbiq Kilidlənib',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Davam etmək üçün təhlükəsizlik doğrulamasından keçin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _checkAndAuthenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Yenidən Cəhd Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




// // lib/main.dart
// import 'package:flutter/material.dart';
// import 'package:borc_defteri/screens/login_page.dart';
// import 'package:borc_defteri/screens/home_screen.dart';
// import 'package:borc_defteri/services/auth_service.dart';
// import 'package:upgrader/upgrader.dart';
//
// void main() async {
//   // Tətbiq başlamazdan əvvəl lazımi yükləmələri edir
//   WidgetsFlutterBinding.ensureInitialized();
//
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Borc Dəftəri',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//         useMaterial3: true,
//       ),
//       // UpgradeAlert bütün tətbiqi qoruyur.
//       home: UpgradeAlert(
//         // --- DÜZƏLİŞ BURADADIR ---
//         // Parametrlər birbaşa UpgradeAlert-in içinə yazılır
//
//         showIgnore: false,       // "İqnor et" görünməsin
//         showLater: false,        // "Sonra" görünməsin
//         dialogStyle: UpgradeDialogStyle.material, // Dizayn
//
//         upgrader: Upgrader(
//           // Bura boş qala bilər və ya debug ayarları yazıla bilər
//           // debugLogging: true,
//         ),
//         // --------------------------
//
//         child: FutureBuilder<bool>(
//           future: AuthService().isSignedIn(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Scaffold(body: Center(child: CircularProgressIndicator()));
//             } else if (snapshot.hasData && snapshot.data == true) {
//               return const HomeScreen();
//             } else {
//               return const LoginPage();
//             }
//           },
//         ),
//       ),
//     );
//   }
// }