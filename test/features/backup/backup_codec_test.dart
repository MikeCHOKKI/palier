import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/backup/domain/backup_codec.dart';

Matcher _fails(BackupFailure failure) => throwsA(isA<BackupException>().having((e) => e.failure, 'failure', failure));

void main() {
  const codec = BackupCodec(iterations: 1000);
  const password = 'lune-baobab-42';
  final payload = {
    'profile': {'name': 'Ama'},
    'sections': <String, Object?>{},
  };

  test('rouvre ce qu’il a chiffré avec le bon mot de passe', () async {
    final bytes = await codec.encrypt(payload, password);

    expect(await codec.decrypt(bytes, password), payload);
  });

  test('ne laisse rien en clair dans le fichier', () async {
    final text = utf8.decode(await codec.encrypt(payload, password));

    expect(text, isNot(contains('Ama')));
    expect(text, contains('"format":"palier-export"'));
  });

  test('refuse un mauvais mot de passe', () async {
    final bytes = await codec.encrypt(payload, password);

    await expectLater(codec.decrypt(bytes, 'autre-mot-de-passe'), _fails(BackupFailure.wrongPassword));
  });

  test('refuse un fichier modifié, contenu ou en-tête', () async {
    final envelope = jsonDecode(utf8.decode(await codec.encrypt(payload, password))) as Map<String, dynamic>;

    final data = base64Decode(envelope['data'] as String)..[0] ^= 1;
    final tamperedData = {...envelope, 'data': base64Encode(data)};
    await expectLater(
      codec.decrypt(utf8.encode(jsonEncode(tamperedData)), password),
      _fails(BackupFailure.wrongPassword),
    );

    final kdf = Map<String, dynamic>.of(envelope['kdf'] as Map<String, dynamic>)..['iterations'] = 999;
    await expectLater(
      codec.decrypt(utf8.encode(jsonEncode({...envelope, 'kdf': kdf})), password),
      _fails(BackupFailure.wrongPassword),
    );
  });

  test('reconnaît un fichier qui n’est pas un export Palier', () async {
    await expectLater(codec.decrypt(utf8.encode('bonjour'), password), _fails(BackupFailure.invalidFile));
    await expectLater(
      codec.decrypt(utf8.encode('{"format":"autre","version":1}'), password),
      _fails(BackupFailure.invalidFile),
    );
    await expectLater(
      codec.decrypt(utf8.encode('{"format":"palier-export","version":1}'), password),
      _fails(BackupFailure.invalidFile),
    );
  });

  test('signale un export d’une version plus récente', () async {
    final envelope = jsonDecode(utf8.decode(await codec.encrypt(payload, password))) as Map<String, dynamic>;

    await expectLater(
      codec.decrypt(utf8.encode(jsonEncode({...envelope, 'version': 2})), password),
      _fails(BackupFailure.newerVersion),
    );
  });
}
