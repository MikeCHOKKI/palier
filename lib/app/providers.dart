import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security/biometric_gate.dart';
import '../data/database.dart';
import '../features/backup/data/backup_files.dart';
import '../features/backup/data/backup_service.dart';
import '../features/expenses/data/expenses_backup_section.dart';
import '../features/expenses/data/expenses_repository.dart';
import '../features/profiles/data/profiles_repository.dart';
import '../features/profiles/domain/profile.dart';

/// La base SQLite ; remplacée dans `main` (téléphone) et dans les tests (mémoire).
/// Les réglages propres à ce téléphone, lus avant le premier affichage.
final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('préférences chargées au démarrage, dans main()'),
);

/// L'heure du téléphone. Les tests et les captures la figent : un écran qui
/// affiche « aujourd'hui » ou le mois en cours ne change plus d'un jour à l'autre.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final databaseProvider = Provider<PalierDatabase>((ref) {
  throw UnimplementedError('databaseProvider doit être remplacé au démarrage');
});

final profilesRepositoryProvider = Provider<ProfilesRepository>(
  (ref) => ProfilesRepository(ref.watch(databaseProvider)),
);

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(databaseProvider)),
);

/// Les modules dont les données partent dans l'export d'un profil.
List<BackupSection> backupSections(PalierDatabase db) => [ExpensesBackupSection(db)];

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupService(db, sections: backupSections(db));
});

final backupFilesProvider = Provider<BackupFiles>((ref) => const DeviceBackupFiles());

final biometricGateProvider = Provider<BiometricGate>((ref) => DeviceBiometricGate());

/// Les profils de la famille, tenus à jour par la base.
final profilesProvider = StreamProvider<List<Profile>>((ref) => ref.watch(profilesRepositoryProvider).watchAll());

/// Qui utilise l'application en ce moment.
class Session {
  const Session({this.activeProfileId, this.lastProfileId});

  /// Profil ouvert (déverrouillé), ou `null` sur l'écran de choix.
  final String? activeProfileId;

  /// Dernier profil ouvert : après un verrouillage, on lui redemande son code
  /// directement plutôt que de repasser par le choix du profil.
  final String? lastProfileId;
}

class SessionController extends Notifier<Session> {
  @override
  Session build() => const Session();

  void open(String profileId) => state = Session(activeProfileId: profileId, lastProfileId: profileId);

  /// Retour à l'écran de choix, sans viser de profil.
  void signOut() => state = const Session();

  /// Verrouille le profil ouvert : son code sera redemandé.
  void lock() => state = Session(lastProfileId: state.activeProfileId ?? state.lastProfileId);
}

final sessionProvider = NotifierProvider<SessionController, Session>(SessionController.new);

/// Le profil ouvert, ou `null`.
final activeProfileProvider = Provider<Profile?>((ref) {
  final id = ref.watch(sessionProvider).activeProfileId;
  final profiles = ref.watch(profilesProvider).value ?? const [];
  for (final profile in profiles) {
    if (profile.id == id) return profile;
  }
  return null;
});
