import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/palier_accent.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../data/database.dart';
import '../domain/profile.dart';

/// Résultat d'une saisie de code.
sealed class PinCheck {
  const PinCheck();
}

final class PinAccepted extends PinCheck {
  const PinAccepted();
}

/// Code faux : [lockedUntil] est renseigné si ce dernier échec bloque le profil.
final class PinRejected extends PinCheck {
  const PinRejected({required this.failedAttempts, this.lockedUntil});

  final int failedAttempts;
  final DateTime? lockedUntil;

  /// Essais restants avant le prochain blocage (0 une fois le seuil franchi).
  int get remainingBeforeLock =>
      failedAttempts >= PinLockout.freeAttempts ? 0 : PinLockout.freeAttempts - failedAttempts;
}

/// Profil bloqué : aucun code n'est vérifié avant [until].
final class PinLocked extends PinCheck {
  const PinLocked(this.until);

  final DateTime until;
}

/// Lecture et écriture des profils de la famille.
class ProfilesRepository {
  ProfilesRepository(this._db, {this._hasher = const PinHasher(), DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _uuid = uuid ?? const Uuid();

  final PalierDatabase _db;
  final PinHasher _hasher;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// Les profils actifs, du plus ancien au plus récent.
  Stream<List<Profile>> watchAll() {
    final query = _db.select(_db.profiles)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]);
    return query.watch().map((rows) => rows.map(_toProfile).toList(growable: false));
  }

  Future<Profile?> find(String id) async {
    final row = await _row(id);
    return row == null ? null : _toProfile(row);
  }

  Future<Profile> create(ProfileDraft draft) async {
    final now = _clock();
    final id = _uuid.v4();
    await _db
        .into(_db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            name: draft.name.trim(),
            accent: draft.accent.name,
            currency: Value(draft.currency.code),
            isMinor: Value(draft.isMinor),
            expensesEnabled: Value(draft.expensesEnabled),
            sportEnabled: Value(draft.sportEnabled),
          ),
        );
    return (await find(id))!;
  }

  Future<void> update(String id, ProfileDraft draft) {
    return _write(
      id,
      ProfilesCompanion(
        name: Value(draft.name.trim()),
        accent: Value(draft.accent.name),
        currency: Value(draft.currency.code),
        isMinor: Value(draft.isMinor),
        expensesEnabled: Value(draft.expensesEnabled),
        sportEnabled: Value(draft.sportEnabled),
      ),
    );
  }

  /// Suppression douce : le profil disparaît de l'application.
  Future<void> delete(String id) => _write(id, ProfilesCompanion(deletedAt: Value(_clock())));

  Future<void> setPin(String id, String pin) async {
    if (!PinHasher.isValidPin(pin)) {
      throw ArgumentError.value(pin.length, 'pin', 'Le code doit compter 4 à 6 chiffres');
    }
    final hashed = await _hasher.hash(pin);
    await _write(
      id,
      ProfilesCompanion(
        pinHash: Value(hashed.hash),
        pinSalt: Value(hashed.salt),
        pinIterations: Value(hashed.iterations),
        failedPinAttempts: const Value(0),
        lockedUntil: const Value(null),
      ),
    );
  }

  /// Retire le code ; l'empreinte n'a plus de sens sans lui.
  Future<void> clearPin(String id) {
    return _write(
      id,
      const ProfilesCompanion(
        pinHash: Value(null),
        pinSalt: Value(null),
        pinIterations: Value(null),
        biometricEnabled: Value(false),
        failedPinAttempts: Value(0),
        lockedUntil: Value(null),
      ),
    );
  }

  Future<void> setBiometric(String id, {required bool enabled}) {
    return _write(id, ProfilesCompanion(biometricEnabled: Value(enabled)));
  }

  /// Vérifie un code et tient le compte des échecs.
  Future<PinCheck> checkPin(String id, String pin) async {
    final row = await _row(id);
    if (row == null || row.pinHash == null) return const PinAccepted();

    final now = _clock();
    final lockedUntil = row.lockedUntil;
    if (lockedUntil != null && lockedUntil.isAfter(now)) return PinLocked(lockedUntil);

    final stored = PinHash(hash: row.pinHash!, salt: row.pinSalt!, iterations: row.pinIterations!);
    if (await _hasher.verify(pin, stored)) {
      await _resetAttempts(id);
      return const PinAccepted();
    }

    final failed = row.failedPinAttempts + 1;
    final lock = PinLockout.durationAfter(failed);
    final until = lock == Duration.zero ? null : now.add(lock);
    await (_db.update(_db.profiles)..where((p) => p.id.equals(id))).write(
      ProfilesCompanion(failedPinAttempts: Value(failed), lockedUntil: Value(until)),
    );
    return PinRejected(failedAttempts: failed, lockedUntil: until);
  }

  /// Déverrouillage par empreinte réussi : le compteur d'échecs repart à zéro.
  Future<void> recordBiometricUnlock(String id) => _resetAttempts(id);

  /// Fin du blocage en cours, s'il y en a un.
  Future<DateTime?> lockedUntil(String id) async {
    final until = (await _row(id))?.lockedUntil;
    return until != null && until.isAfter(_clock()) ? until : null;
  }

  Future<void> _resetAttempts(String id) {
    return (_db.update(_db.profiles)..where((p) => p.id.equals(id))).write(
      const ProfilesCompanion(failedPinAttempts: Value(0), lockedUntil: Value(null)),
    );
  }

  Future<ProfileRow?> _row(String id) {
    return (_db.select(_db.profiles)..where((p) => p.id.equals(id) & p.deletedAt.isNull())).getSingleOrNull();
  }

  /// Toute modification met à jour [updatedAt], repère de la future synchronisation.
  Future<void> _write(String id, ProfilesCompanion changes) async {
    await (_db.update(_db.profiles)..where((p) => p.id.equals(id))).write(changes.copyWith(updatedAt: Value(_clock())));
  }

  static Profile _toProfile(ProfileRow row) {
    return Profile(
      id: row.id,
      name: row.name,
      accent: PalierAccent.fromName(row.accent),
      currency: PalierCurrency.fromCode(row.currency),
      isMinor: row.isMinor,
      expensesEnabled: row.expensesEnabled,
      sportEnabled: row.sportEnabled,
      hasPin: row.pinHash != null,
      biometricEnabled: row.biometricEnabled,
      createdAt: row.createdAt,
    );
  }
}
