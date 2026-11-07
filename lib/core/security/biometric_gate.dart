import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Déverrouillage par empreinte (ou visage), séparé de `local_auth` pour
/// pouvoir le simuler dans les tests.
abstract interface class BiometricGate {
  /// Le téléphone a au moins une empreinte ou un visage enregistré.
  Future<bool> isAvailable();

  /// Demande l'empreinte ; `false` si la personne annule ou échoue.
  Future<bool> authenticate(String reason);
}

class DeviceBiometricGate implements BiometricGate {
  DeviceBiometricGate([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // biometricOnly : le code de l'écran de verrouillage du téléphone est
      // souvent connu de toute la famille, il ne doit pas ouvrir un profil.
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } on PlatformException {
      return false;
    }
  }
}
