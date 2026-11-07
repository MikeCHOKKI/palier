import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Empreinte d'un code de profil, telle qu'elle est enregistrée.
class PinHash {
  const PinHash({required this.hash, required this.salt, required this.iterations});

  /// Empreinte et sel en Base64.
  final String hash;
  final String salt;
  final int iterations;
}

/// Transforme le code d'un profil en empreinte PBKDF2-HMAC-SHA256.
///
/// Un code de 4 à 6 chiffres reste devinable par force brute si quelqu'un
/// copie la base : la vraie protection est le blocage progressif après des
/// essais manqués (voir [PinLockout]) et le dossier privé de l'application.
/// L'empreinte évite seulement que le code soit lisible en clair. Le nombre
/// d'itérations est enregistré avec elle, pour pouvoir l'augmenter plus tard.
class PinHasher {
  const PinHasher({this.iterations = defaultIterations});

  static const int defaultIterations = 60000;
  static const int minLength = 4;
  static const int maxLength = 6;

  final int iterations;

  /// Un code valide : 4 à 6 chiffres.
  static bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  Future<PinHash> hash(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final bytes = await _derive(pin, salt, iterations);
    return PinHash(hash: base64Encode(bytes), salt: base64Encode(salt), iterations: iterations);
  }

  /// Compare le code saisi à l'empreinte, en temps constant.
  Future<bool> verify(String pin, PinHash stored) async {
    final bytes = await _derive(pin, base64Decode(stored.salt), stored.iterations);
    final expected = base64Decode(stored.hash);
    if (bytes.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < bytes.length; i++) {
      diff |= bytes[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// Le calcul tourne dans un isolat pour ne pas figer l'écran de saisie.
  static Future<List<int>> _derive(String pin, List<int> salt, int iterations) {
    return Isolate.run(() async {
      final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
      final key = await pbkdf2.deriveKeyFromPassword(password: pin, nonce: salt);
      return key.extractBytes();
    });
  }
}

/// Blocage progressif après des codes manqués.
abstract final class PinLockout {
  /// Essais libres avant le premier blocage.
  static const int freeAttempts = 5;

  static const Duration firstLock = Duration(seconds: 30);
  static const Duration maxLock = Duration(minutes: 15);

  /// Durée de blocage après [failedAttempts] échecs d'affilée : rien pendant
  /// les essais libres, puis 30 s, doublées à chaque nouvel échec jusqu'à 15 min.
  static Duration durationAfter(int failedAttempts) {
    if (failedAttempts < freeAttempts) return Duration.zero;
    final doublings = failedAttempts - freeAttempts;
    final seconds = firstLock.inSeconds * pow(2, min(doublings, 10));
    return Duration(seconds: min(seconds.toInt(), maxLock.inSeconds));
  }
}
