import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Pourquoi un fichier de sauvegarde n'a pas pu être ouvert.
enum BackupFailure {
  /// Pas un export Palier (autre fichier, JSON incomplet).
  invalidFile,

  /// Mot de passe faux, ou fichier modifié depuis l'export.
  wrongPassword,

  /// Export produit par une version plus récente de l'application.
  newerVersion,
}

class BackupException implements Exception {
  const BackupException(this.failure);

  final BackupFailure failure;

  @override
  String toString() => 'BackupException(${failure.name})';
}

/// Chiffre et déchiffre un export Palier.
///
/// Format (version 1) : un JSON lisible qui décrit comment il a été chiffré,
/// pour qu'une version future sache le relire.
///
/// ```json
/// {"format": "palier-export", "version": 1,
///  "kdf": {"name": "pbkdf2-hmac-sha256", "iterations": 210000, "salt": "…"},
///  "cipher": {"name": "aes-256-gcm", "nonce": "…", "mac": "…"},
///  "data": "…"}
/// ```
///
/// La clé AES-256 est dérivée du mot de passe par PBKDF2-HMAC-SHA256. GCM
/// authentifie les données **et** l'en-tête (passé en données associées) :
/// changer le nombre d'itérations ou un octet du contenu fait échouer
/// l'ouverture, comme un mauvais mot de passe.
class BackupCodec {
  const BackupCodec({this.iterations = defaultIterations});

  static const String format = 'palier-export';
  static const int version = 1;

  /// Recommandation OWASP 2023 pour PBKDF2-HMAC-SHA256.
  static const int defaultIterations = 210000;

  static const int minPasswordLength = 10;

  /// Extension des fichiers d'export.
  static const String extension = 'palier';

  final int iterations;

  Future<Uint8List> encrypt(Map<String, Object?> payload, String password) {
    final iterations = this.iterations;
    return Isolate.run(() async {
      final random = Random.secure();
      final salt = List<int>.generate(16, (_) => random.nextInt(256));
      final header = _header(iterations, salt);

      final key = await _deriveKey(password, salt, iterations);
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode(payload)),
        secretKey: key,
        aad: _aad(header),
      );

      final envelope = {
        ...header,
        'cipher': {'name': 'aes-256-gcm', 'nonce': base64Encode(box.nonce), 'mac': base64Encode(box.mac.bytes)},
        'data': base64Encode(box.cipherText),
      };
      return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    });
  }

  /// Ouvre un export ; lève [BackupException] s'il ne peut pas l'être.
  Future<Map<String, Object?>> decrypt(List<int> bytes, String password) {
    return Isolate.run(() async {
      final envelope = _parseEnvelope(bytes);
      final kdf = envelope.kdf;
      final header = _header(kdf.iterations, kdf.salt);
      final key = await _deriveKey(password, kdf.salt, kdf.iterations);

      final List<int> clear;
      try {
        clear = await AesGcm.with256bits().decrypt(
          SecretBox(envelope.data, nonce: envelope.nonce, mac: Mac(envelope.mac)),
          secretKey: key,
          aad: _aad(header),
        );
      } on SecretBoxAuthenticationError {
        throw const BackupException(BackupFailure.wrongPassword);
      }

      try {
        return (jsonDecode(utf8.decode(clear)) as Map).cast<String, Object?>();
      } on FormatException {
        throw const BackupException(BackupFailure.invalidFile);
      }
    });
  }

  static Map<String, Object?> _header(int iterations, List<int> salt) => {
    'format': format,
    'version': version,
    'kdf': {'name': 'pbkdf2-hmac-sha256', 'iterations': iterations, 'salt': base64Encode(salt)},
  };

  /// L'en-tête sérialisé tel quel, authentifié par GCM.
  static List<int> _aad(Map<String, Object?> header) => utf8.encode(jsonEncode(header));

  static Future<SecretKey> _deriveKey(String password, List<int> salt, int iterations) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  static _Envelope _parseEnvelope(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map || json['format'] != format) throw const BackupException(BackupFailure.invalidFile);

      final fileVersion = json['version'];
      if (fileVersion is! int) throw const BackupException(BackupFailure.invalidFile);
      if (fileVersion > version) throw const BackupException(BackupFailure.newerVersion);

      final kdf = json['kdf'] as Map;
      final cipher = json['cipher'] as Map;
      if (kdf['name'] != 'pbkdf2-hmac-sha256' || cipher['name'] != 'aes-256-gcm') {
        throw const BackupException(BackupFailure.invalidFile);
      }
      return _Envelope(
        kdf: (iterations: kdf['iterations'] as int, salt: base64Decode(kdf['salt'] as String)),
        nonce: base64Decode(cipher['nonce'] as String),
        mac: base64Decode(cipher['mac'] as String),
        data: base64Decode(json['data'] as String),
      );
    } on BackupException {
      rethrow;
    } on Object {
      // JSON illisible, champ manquant ou mal typé, Base64 invalide.
      throw const BackupException(BackupFailure.invalidFile);
    }
  }
}

class _Envelope {
  const _Envelope({required this.kdf, required this.nonce, required this.mac, required this.data});

  final ({int iterations, List<int> salt}) kdf;
  final List<int> nonce;
  final List<int> mac;
  final List<int> data;
}
