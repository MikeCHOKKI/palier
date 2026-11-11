import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../profiles/domain/profile.dart';

/// « 12 500 F CFA », « 12,50 € » : un montant en unités mineures, à la française.
///
/// [signed] ajoute « + » ou « − » (le vrai signe moins, plus lisible que le tiret).
String formatMoney(int minor, PalierCurrency currency, {bool signed = false, bool withSymbol = true}) {
  final format = NumberFormat.decimalPatternDigits(locale: 'fr', decimalDigits: currency.decimals);
  final value = minor.abs() / _scale(currency);
  final sign = !signed || minor == 0 ? '' : (minor < 0 ? '−' : '+');
  final number = '$sign${format.format(value)}';
  // Espace insécable : le symbole ne part jamais seul à la ligne.
  return withSymbol ? '$number ${currency.symbol}' : number;
}

/// Un solde : sans signe quand il est positif, avec « − » quand il est négatif.
/// La couleur rouge ne suffit pas : elle disparaît quand les montants sont
/// masqués, et ne se lit pas sans les couleurs.
String formatBalance(int minor, PalierCurrency currency) => formatMoney(minor, currency, signed: minor < 0);

/// Un montant masqué : la devise reste, pour reconnaître la ligne.
String maskedMoney(PalierCurrency currency) => '••• ${currency.symbol}';

int _scale(PalierCurrency currency) {
  var scale = 1;
  for (var i = 0; i < currency.decimals; i++) {
    scale *= 10;
  }
  return scale;
}

/// Ce que l'on tape au pavé : une partie entière et, pour les devises à
/// centimes, une partie décimale. Immuable : chaque touche rend une nouvelle saisie.
@immutable
class AmountEntry {
  const AmountEntry._(this.currency, this.whole, this.fraction);

  const AmountEntry.empty(PalierCurrency currency) : this._(currency, '', null);

  /// Reprend un montant enregistré (modification d'une opération).
  factory AmountEntry.fromMinor(int minor, PalierCurrency currency) {
    if (minor <= 0) return AmountEntry.empty(currency);
    final scale = _scale(currency);
    final whole = (minor ~/ scale).toString();
    if (currency.decimals == 0) return AmountEntry._(currency, whole, null);
    final cents = (minor % scale).toString().padLeft(currency.decimals, '0');
    final trimmed = cents.replaceFirst(RegExp(r'0+$'), '');
    return AmountEntry._(currency, whole, trimmed.isEmpty ? null : trimmed);
  }

  /// Dix chiffres avant la virgule : bien assez pour un foyer, et loin des limites d'un entier.
  static const int maxWholeDigits = 10;

  final PalierCurrency currency;
  final String whole;

  /// `null` tant que la virgule n'est pas tapée.
  final String? fraction;

  bool get hasSeparator => fraction != null;

  /// La devise a des centimes : le pavé montre une virgule (sinon « 000 »).
  bool get allowsDecimals => currency.decimals > 0;

  int get minor {
    final scale = _scale(currency);
    final wholeValue = whole.isEmpty ? 0 : int.parse(whole);
    final cents = (fraction ?? '').padRight(currency.decimals, '0');
    return wholeValue * scale + (cents.isEmpty ? 0 : int.parse(cents));
  }

  bool get isZero => minor == 0;

  AmountEntry digit(String d) {
    assert(RegExp(r'^\d$').hasMatch(d), 'un seul chiffre');
    if (fraction != null) {
      if (fraction!.length >= currency.decimals) return this;
      return AmountEntry._(currency, whole, fraction! + d);
    }
    if (whole.isEmpty && d == '0') return this; // pas de zéro en tête
    if (whole.length >= maxWholeDigits) return this;
    return AmountEntry._(currency, whole + d, null);
  }

  /// La touche « 000 » du F CFA : les prix se comptent en milliers.
  AmountEntry thousands() {
    if (fraction != null || whole.isEmpty || whole.length + 3 > maxWholeDigits) return this;
    return AmountEntry._(currency, '${whole}000', null);
  }

  AmountEntry separator() {
    if (!allowsDecimals || fraction != null) return this;
    return AmountEntry._(currency, whole.isEmpty ? '0' : whole, '');
  }

  AmountEntry backspace() {
    if (fraction != null) {
      if (fraction!.isEmpty) return AmountEntry._(currency, whole == '0' ? '' : whole, null);
      return AmountEntry._(currency, whole, fraction!.substring(0, fraction!.length - 1));
    }
    if (whole.isEmpty) return this;
    return AmountEntry._(currency, whole.substring(0, whole.length - 1), null);
  }

  /// Ce que montre l'écran pendant la frappe : « 12 500 », « 12,5 », « 0 ».
  String get display {
    final grouped = NumberFormat.decimalPattern('fr').format(whole.isEmpty ? 0 : int.parse(whole));
    return fraction == null ? grouped : '$grouped,$fraction';
  }

  @override
  bool operator ==(Object other) =>
      other is AmountEntry && other.currency == currency && other.whole == whole && other.fraction == fraction;

  @override
  int get hashCode => Object.hash(currency, whole, fraction);
}

/// Lit un montant tapé au clavier (« 12 500 », « 12,50 », « 12.5 ») en unités
/// mineures ; vide vaut zéro, `null` si ce n'est pas un montant valide.
int? parseMoney(String input, PalierCurrency currency) {
  final cleaned = input.replaceAll(RegExp(r'[\s  ]'), '');
  if (cleaned.isEmpty) return 0;
  final match = RegExp(r'^(\d{1,10})(?:[.,](\d*))?$').firstMatch(cleaned);
  if (match == null) return null;
  final fraction = match.group(2) ?? '';
  if (fraction.length > currency.decimals) return null;
  return int.parse(match.group(1)!) * _scale(currency) +
      int.parse(fraction.padRight(currency.decimals, '0').padLeft(1, '0'));
}
