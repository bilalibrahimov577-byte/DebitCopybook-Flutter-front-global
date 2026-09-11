import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 1. Cihazda biometriya (və ya PIN) dəstəyi var? (Xətanı verən metod budur)
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // 2. Biometriyanın istifadəçi tərəfindən aktiv edilib-edilmədiyini oxumaq
  Future<bool> isBiometricEnabled() async {
    String? enabled = await _storage.read(key: 'biometric_enabled');
    return enabled == 'true';
  }

  // 3. Barmaq izi / PIN pəncərəsini açmaq və təsdiqləmək
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Tətbiqə daxil olmaq üçün barmaq izini və ya şifrəni təsdiqləyin',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  // 4. Switch dəyişəndə çağırılan funksiya
  Future<bool> toggleBiometric(bool value) async {
    if (value) {
      bool authenticated = await authenticate();
      if (authenticated) {
        await _storage.write(key: 'biometric_enabled', value: 'true');
        return true;
      }
      return false;
    } else {
      await _storage.write(key: 'biometric_enabled', value: 'false');
      return false;
    }
  }
}