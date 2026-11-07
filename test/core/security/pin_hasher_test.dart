import 'package:flutter_test/flutter_test.dart';
import 'package:palier/core/security/pin_hasher.dart';

void main() {
  // Peu d'itérations : on teste le comportement, pas la résistance.
  const hasher = PinHasher(iterations: 1000);

  group('PinHasher', () {
    test('accepte le bon code et refuse un autre', () async {
      final stored = await hasher.hash('2468');

      expect(await hasher.verify('2468', stored), isTrue);
      expect(await hasher.verify('2469', stored), isFalse);
    });

    test('ne garde jamais le code en clair, et sale chaque empreinte', () async {
      final a = await hasher.hash('2468');
      final b = await hasher.hash('2468');

      expect(a.hash, isNot(contains('2468')));
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(a.iterations, 1000);
    });

    test('vérifie avec le nombre d’itérations enregistré', () async {
      final stored = await const PinHasher(iterations: 1500).hash('1357');

      expect(await hasher.verify('1357', stored), isTrue);
    });

    test('un code fait 4 à 6 chiffres', () {
      expect(PinHasher.isValidPin('1234'), isTrue);
      expect(PinHasher.isValidPin('123456'), isTrue);
      expect(PinHasher.isValidPin('123'), isFalse);
      expect(PinHasher.isValidPin('1234567'), isFalse);
      expect(PinHasher.isValidPin('12a4'), isFalse);
    });
  });

  group('PinLockout', () {
    test('laisse 5 essais libres', () {
      for (var i = 0; i < 5; i++) {
        expect(PinLockout.durationAfter(i), Duration.zero);
      }
    });

    test('bloque 30 s, double à chaque échec, plafonne à 15 min', () {
      expect(PinLockout.durationAfter(5), const Duration(seconds: 30));
      expect(PinLockout.durationAfter(6), const Duration(minutes: 1));
      expect(PinLockout.durationAfter(7), const Duration(minutes: 2));
      expect(PinLockout.durationAfter(10), const Duration(minutes: 15));
      expect(PinLockout.durationAfter(40), const Duration(minutes: 15));
    });
  });
}
