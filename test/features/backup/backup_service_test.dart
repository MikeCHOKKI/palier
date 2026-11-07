import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/core/security/pin_hasher.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/backup/data/backup_service.dart';
import 'package:palier/features/backup/domain/backup_codec.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../../helpers/test_database.dart';

/// Section factice, pour vérifier que les modules partent et reviennent.
class _NotesSection implements BackupSection {
  final Map<String, List<Map<String, Object?>>> store = {};

  @override
  String get key => 'notes';

  @override
  Future<List<Map<String, Object?>>> export(String profileId) async => store[profileId] ?? const [];

  @override
  Future<void> restore(String profileId, List<Map<String, Object?>> rows) async => store[profileId] = rows;
}

void main() {
  const password = 'lune-baobab-42';
  late PalierDatabase phone;
  late ProfilesRepository profiles;

  setUp(() {
    phone = openTestDatabase();
    profiles = ProfilesRepository(phone, hasher: const PinHasher(iterations: 1000));
  });

  tearDown(() => phone.close());

  BackupService serviceFor(PalierDatabase db, [List<BackupSection> sections = const []]) =>
      BackupService(db, codec: const BackupCodec(iterations: 1000), sections: sections);

  test('restaure un profil, son code et ses sections sur un autre téléphone', () async {
    final notes = _NotesSection();
    final ama = await profiles.create(const ProfileDraft(name: 'Ama', currency: PalierCurrency.eur));
    await profiles.setPin(ama.id, '2468');
    notes.store[ama.id] = [
      {'texte': 'courir 5 km'},
    ];

    final file = await serviceFor(phone, [notes]).exportProfile(ama.id, password);

    final newPhone = openTestDatabase();
    addTearDown(newPhone.close);
    final newNotes = _NotesSection();
    final service = serviceFor(newPhone, [newNotes]);
    final preview = await service.open(file, password);
    expect(preview.profile.name, 'Ama');
    expect(preview.existsOnDevice, isFalse);

    await service.import(preview);

    final restored = ProfilesRepository(newPhone, hasher: const PinHasher(iterations: 1000));
    expect((await restored.find(ama.id))!.currency, PalierCurrency.eur);
    expect(await restored.checkPin(ama.id, '2468'), isA<PinAccepted>());
    expect(newNotes.store[ama.id], [
      {'texte': 'courir 5 km'},
    ]);
  });

  test('signale qu’un profil existe déjà, puis le remplace', () async {
    final ama = await profiles.create(const ProfileDraft(name: 'Ama'));
    final file = await serviceFor(phone).exportProfile(ama.id, password);
    await profiles.update(ama.id, const ProfileDraft(name: 'Ama modifiée'));

    final preview = await serviceFor(phone).open(file, password);
    expect(preview.existsOnDevice, isTrue);
    await serviceFor(phone).import(preview);

    expect((await profiles.find(ama.id))!.name, 'Ama');
    expect(await profiles.watchAll().first, hasLength(1));
  });

  test('fait revenir un profil supprimé et lève son blocage', () async {
    final ama = await profiles.create(const ProfileDraft(name: 'Ama'));
    final file = await serviceFor(phone).exportProfile(ama.id, password);
    await profiles.delete(ama.id);
    await (phone.update(
      phone.profiles,
    )..where((p) => p.id.equals(ama.id))).write(const ProfilesCompanion(failedPinAttempts: Value(7)));

    final preview = await serviceFor(phone).open(file, password);
    expect(preview.existsOnDevice, isFalse);
    await serviceFor(phone).import(preview);

    final row = await (phone.select(phone.profiles)..where((p) => p.id.equals(ama.id))).getSingle();
    expect(row.deletedAt, isNull);
    expect(row.failedPinAttempts, 0);
  });

  test('un mauvais mot de passe n’écrit rien', () async {
    final ama = await profiles.create(const ProfileDraft(name: 'Ama'));
    final file = await serviceFor(phone).exportProfile(ama.id, password);

    final newPhone = openTestDatabase();
    addTearDown(newPhone.close);
    await expectLater(
      serviceFor(newPhone).open(file, 'faux-mot-de-passe'),
      throwsA(isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.wrongPassword)),
    );
    expect(await newPhone.select(newPhone.profiles).get(), isEmpty);
  });
}
