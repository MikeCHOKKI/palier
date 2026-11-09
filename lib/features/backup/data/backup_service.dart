import 'package:drift/drift.dart';

import '../../../data/database.dart';
import '../../../data/utc_serializer.dart';
import '../domain/backup_codec.dart';

/// Les données d'un module (dépenses, sport…) qui partent dans l'export d'un
/// profil. Chaque module en déclare une ; le profil lui-même est toujours exporté.
abstract interface class BackupSection {
  /// Clé de la section dans le fichier ; ne jamais la renommer.
  String get key;

  Future<List<Map<String, Object?>>> export(String profileId);

  /// Remplace les données du profil par celles du fichier.
  Future<void> restore(String profileId, List<Map<String, Object?>> rows);
}

/// Un export ouvert, prêt à être importé.
class BackupPreview {
  const BackupPreview({required this.profile, required this.sections, required this.existsOnDevice});

  final ProfileRow profile;
  final Map<String, List<Map<String, Object?>>> sections;

  /// Le profil existe déjà ici : l'import le remplacera.
  final bool existsOnDevice;
}

/// Exporte et importe un profil complet, chiffré.
class BackupService {
  BackupService(this._db, {this._codec = const BackupCodec(), this._sections = const [], DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final PalierDatabase _db;
  final BackupCodec _codec;
  final List<BackupSection> _sections;
  final DateTime Function() _clock;

  Future<Uint8List> exportProfile(String profileId, String password) async {
    final row = await (_db.select(_db.profiles)..where((p) => p.id.equals(profileId))).getSingle();
    final payload = <String, Object?>{
      'exportedAt': _clock().toIso8601String(),
      'profile': row.toJson(),
      'sections': {for (final section in _sections) section.key: await section.export(profileId)},
    };
    return _codec.encrypt(payload, password);
  }

  /// Ouvre un fichier sans rien écrire ; lève [BackupException] en cas d'échec.
  Future<BackupPreview> open(List<int> bytes, String password) async {
    final payload = await _codec.decrypt(bytes, password);
    try {
      final profile = ProfileRow.fromJson(
        (payload['profile']! as Map).cast<String, Object?>(),
        serializer: const UtcValueSerializer(),
      );
      final rawSections = (payload['sections'] as Map?)?.cast<String, Object?>() ?? const {};
      final sections = {
        for (final entry in rawSections.entries)
          entry.key: (entry.value! as List).map((row) => (row as Map).cast<String, Object?>()).toList(),
      };
      final existing = await (_db.select(_db.profiles)..where((p) => p.id.equals(profile.id))).getSingleOrNull();
      return BackupPreview(
        profile: profile,
        sections: sections,
        existsOnDevice: existing != null && existing.deletedAt == null,
      );
    } on Object {
      throw const BackupException(BackupFailure.invalidFile);
    }
  }

  /// Écrit le profil et ses sections, en une seule transaction.
  Future<void> import(BackupPreview preview) {
    return _db.transaction(() async {
      final restored = preview.profile.copyWith(
        deletedAt: const Value(null),
        failedPinAttempts: 0,
        lockedUntil: const Value(null),
        updatedAt: _clock(),
      );
      // toCompanion(false) : les valeurs nulles (deletedAt, lockedUntil) sont
      // écrites aussi, sinon un profil supprimé resterait supprimé.
      await _db.into(_db.profiles).insertOnConflictUpdate(restored.toCompanion(false));
      for (final section in _sections) {
        await section.restore(restored.id, preview.sections[section.key] ?? const []);
      }
    });
  }
}
