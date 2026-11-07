import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/theme/palier_accent.dart';
import 'package:palier/core/security/pin_hasher.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../../helpers/test_database.dart';

void main() {
  late PalierDatabase db;
  late ProfilesRepository repo;
  late DateTime now;

  setUp(() {
    db = openTestDatabase();
    now = DateTime.utc(2026, 11, 7, 9);
    repo = ProfilesRepository(db, hasher: const PinHasher(iterations: 1000), clock: () => now);
  });

  tearDown(() => db.close());

  test('crée un profil avec ses réglages', () async {
    final profile = await repo.create(
      const ProfileDraft(name: '  Ama ', accent: PalierAccent.menthe, currency: PalierCurrency.eur, isMinor: true),
    );

    expect(profile.name, 'Ama');
    expect(profile.accent, PalierAccent.menthe);
    expect(profile.currency, PalierCurrency.eur);
    expect(profile.isMinor, isTrue);
    expect(profile.hasPin, isFalse);
    expect(profile.initial, 'A');
  });

  test('liste les profils du plus ancien au plus récent, sans les supprimés', () async {
    final first = await repo.create(const ProfileDraft(name: 'Ama'));
    now = now.add(const Duration(minutes: 1));
    await repo.create(const ProfileDraft(name: 'Kofi'));
    now = now.add(const Duration(minutes: 1));
    final third = await repo.create(const ProfileDraft(name: 'Esi'));

    await repo.delete(first.id);

    final names = (await repo.watchAll().first).map((p) => p.name);
    expect(names, ['Kofi', 'Esi']);
    expect(await repo.find(first.id), isNull);
    expect(await repo.find(third.id), isNotNull);
  });

  test('modifie un profil et date la modification', () async {
    final profile = await repo.create(const ProfileDraft(name: 'Ama'));
    now = now.add(const Duration(hours: 1));

    await repo.update(profile.id, ProfileDraft.of(profile).copyWith(name: 'Ama K.', sportEnabled: false));

    final updated = (await repo.find(profile.id))!;
    expect(updated.name, 'Ama K.');
    expect(updated.sportEnabled, isFalse);
    final row = await (db.select(db.profiles)..where((p) => p.id.equals(profile.id))).getSingle();
    expect(row.updatedAt, now);
    expect(row.createdAt, isNot(now));
  });

  group('code du profil', () {
    late Profile profile;

    setUp(() async {
      profile = await repo.create(const ProfileDraft(name: 'Ama'));
      await repo.setPin(profile.id, '2468');
    });

    test('enregistre une empreinte, jamais le code', () async {
      final row = await (db.select(db.profiles)..where((p) => p.id.equals(profile.id))).getSingle();

      expect((await repo.find(profile.id))!.hasPin, isTrue);
      expect(row.pinHash, isNot(contains('2468')));
      expect(row.pinIterations, 1000);
    });

    test('refuse un code qui n’a pas 4 à 6 chiffres', () {
      expect(() => repo.setPin(profile.id, '12'), throwsArgumentError);
    });

    test('accepte le bon code et remet le compteur à zéro', () async {
      await repo.checkPin(profile.id, '0000');
      expect(await repo.checkPin(profile.id, '2468'), isA<PinAccepted>());

      final rejected = await repo.checkPin(profile.id, '0000');
      expect((rejected as PinRejected).failedAttempts, 1);
    });

    test('bloque après 5 échecs, puis refuse même le bon code', () async {
      PinCheck last = const PinAccepted();
      for (var i = 0; i < 5; i++) {
        last = await repo.checkPin(profile.id, '0000');
      }

      final rejected = last as PinRejected;
      expect(rejected.remainingBeforeLock, 0);
      expect(rejected.lockedUntil, now.add(const Duration(seconds: 30)));
      expect(await repo.checkPin(profile.id, '2468'), isA<PinLocked>());

      now = now.add(const Duration(seconds: 31));
      expect(await repo.checkPin(profile.id, '2468'), isA<PinAccepted>());
    });

    test('retirer le code désactive aussi l’empreinte digitale', () async {
      await repo.setBiometric(profile.id, enabled: true);
      await repo.clearPin(profile.id);

      final updated = (await repo.find(profile.id))!;
      expect(updated.hasPin, isFalse);
      expect(updated.biometricEnabled, isFalse);
      expect(await repo.checkPin(profile.id, '9999'), isA<PinAccepted>());
    });
  });
}
