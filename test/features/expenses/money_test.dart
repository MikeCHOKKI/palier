import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:palier/features/expenses/domain/money.dart';
import 'package:palier/features/profiles/domain/profile.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  /// Les espaces de groupement varient (U+202F, U+00A0) : on les compare comme des espaces.
  String plain(String s) => s.replaceAll(RegExp('[  ]'), ' ');

  group('formatMoney', () {
    test('écrit le F CFA sans décimales, groupé par milliers', () {
      expect(plain(formatMoney(12500, PalierCurrency.xof)), '12 500 F CFA');
      expect(plain(formatMoney(0, PalierCurrency.xof)), '0 F CFA');
    });

    test('écrit l’euro avec ses centimes et une virgule', () {
      expect(plain(formatMoney(1250, PalierCurrency.eur)), '12,50 €');
      expect(plain(formatMoney(123456789, PalierCurrency.eur)), '1 234 567,89 €');
    });

    test('signe les montants avec un vrai signe moins', () {
      expect(plain(formatMoney(-2500, PalierCurrency.xof, signed: true)), '−2 500 F CFA');
      expect(plain(formatMoney(15000, PalierCurrency.xof, signed: true)), '+15 000 F CFA');
      expect(plain(formatMoney(0, PalierCurrency.xof, signed: true)), '0 F CFA');
    });

    test('peut omettre le symbole', () {
      expect(plain(formatMoney(2500, PalierCurrency.xof, withSymbol: false)), '2 500');
    });
  });

  group('AmountEntry en F CFA', () {
    const xof = AmountEntry.empty(PalierCurrency.xof);

    test('se tape chiffre après chiffre, sans zéro en tête', () {
      final entry = xof.digit('0').digit('2').digit('5').digit('0').digit('0');
      expect(entry.minor, 2500);
      expect(plain(entry.display), '2 500');
    });

    test('la touche 000 multiplie par mille, pas sur une saisie vide', () {
      expect(xof.thousands().isZero, isTrue);
      expect(xof.digit('1').digit('2').thousands().minor, 12000);
    });

    test('n’a pas de virgule', () {
      expect(xof.allowsDecimals, isFalse);
      expect(xof.digit('5').separator(), xof.digit('5'));
    });

    test('s’efface chiffre par chiffre et plafonne à dix chiffres', () {
      expect(xof.digit('1').digit('2').backspace().minor, 1);
      expect(xof.backspace(), xof);
      var big = xof;
      for (var i = 0; i < 12; i++) {
        big = big.digit('9');
      }
      expect(big.whole.length, AmountEntry.maxWholeDigits);
      expect(big.thousands(), big);
    });

    test('reprend un montant enregistré', () {
      expect(AmountEntry.fromMinor(15000, PalierCurrency.xof).minor, 15000);
      expect(AmountEntry.fromMinor(0, PalierCurrency.xof).isZero, isTrue);
    });
  });

  group('AmountEntry en euros', () {
    const eur = AmountEntry.empty(PalierCurrency.eur);

    test('compte en centimes, deux décimales au plus', () {
      final entry = eur.digit('1').digit('2').separator().digit('5');
      expect(entry.minor, 1250);
      expect(entry.display, '12,5');
      expect(entry.digit('0').digit('9').minor, 1250, reason: 'troisième décimale ignorée');
    });

    test('une virgule en premier vaut « 0, »', () {
      final entry = eur.separator().digit('5');
      expect(entry.minor, 50);
      expect(entry.display, '0,5');
      expect(entry.backspace().backspace().isZero, isTrue);
      expect(entry.backspace().backspace().hasSeparator, isFalse);
    });

    test('reprend un montant enregistré sans zéros inutiles', () {
      expect(AmountEntry.fromMinor(1250, PalierCurrency.eur).display, '12,5');
      expect(AmountEntry.fromMinor(1200, PalierCurrency.eur).display, '12');
      expect(AmountEntry.fromMinor(1205, PalierCurrency.eur).minor, 1205);
    });
  });

  group('parseMoney', () {
    test('lit les montants tapés au clavier', () {
      expect(parseMoney('12 500', PalierCurrency.xof), 12500);
      expect(parseMoney('', PalierCurrency.xof), 0);
      expect(parseMoney('12,5', PalierCurrency.eur), 1250);
      expect(parseMoney('12.05', PalierCurrency.eur), 1205);
      expect(parseMoney('12,', PalierCurrency.eur), 1200);
    });

    test('refuse ce qui n’est pas un montant', () {
      expect(parseMoney('12,5', PalierCurrency.xof), isNull, reason: 'pas de centimes en F CFA');
      expect(parseMoney('1,234', PalierCurrency.eur), isNull);
      expect(parseMoney('-500', PalierCurrency.xof), isNull);
      expect(parseMoney('abc', PalierCurrency.xof), isNull);
    });
  });

  test('un solde négatif garde son signe, un positif n’en a pas', () {
    expect(formatBalance(-10000, PalierCurrency.xof), formatMoney(-10000, PalierCurrency.xof, signed: true));
    expect(formatBalance(-10000, PalierCurrency.xof), startsWith('−'));
    expect(formatBalance(25000, PalierCurrency.xof), formatMoney(25000, PalierCurrency.xof));
  });
}
