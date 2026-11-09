import 'package:flutter/widgets.dart';

import '../../../app/theme/palier_accent.dart';

/// Devises proposées. Le F CFA (XOF) est la devise par défaut.
enum PalierCurrency {
  xof('F CFA', 0),
  eur('€', 2),
  usd(r'$', 2);

  const PalierCurrency(this.symbol, this.decimals);

  final String symbol;

  /// Chiffres après la virgule : les montants sont enregistrés en unités
  /// mineures (le franc CFA n'en a pas, l'euro compte en centimes).
  final int decimals;

  /// Code ISO 4217 enregistré en base.
  String get code => name.toUpperCase();

  static PalierCurrency fromCode(String? code) {
    return PalierCurrency.values.firstWhere((c) => c.code == code, orElse: () => PalierCurrency.xof);
  }
}

/// Un membre de la famille, tel que l'application le manipule.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.accent,
    required this.currency,
    required this.isMinor,
    required this.expensesEnabled,
    required this.sportEnabled,
    required this.hasPin,
    required this.biometricEnabled,
    required this.createdAt,
  });

  final String id;
  final String name;
  final PalierAccent accent;
  final PalierCurrency currency;
  final bool isMinor;
  final bool expensesEnabled;
  final bool sportEnabled;
  final bool hasPin;
  final bool biometricEnabled;
  final DateTime createdAt;

  /// Initiale affichée dans la pastille du profil.
  String get initial => name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.name == name &&
      other.accent == accent &&
      other.currency == currency &&
      other.isMinor == isMinor &&
      other.expensesEnabled == expensesEnabled &&
      other.sportEnabled == sportEnabled &&
      other.hasPin == hasPin &&
      other.biometricEnabled == biometricEnabled;

  @override
  int get hashCode =>
      Object.hash(id, name, accent, currency, isMinor, expensesEnabled, sportEnabled, hasPin, biometricEnabled);
}

/// Ce que l'on saisit pour créer ou modifier un profil.
@immutable
class ProfileDraft {
  const ProfileDraft({
    required this.name,
    this.accent = PalierAccent.cyan,
    this.currency = PalierCurrency.xof,
    this.isMinor = false,
    this.expensesEnabled = true,
    this.sportEnabled = true,
  });

  factory ProfileDraft.of(Profile profile) => ProfileDraft(
    name: profile.name,
    accent: profile.accent,
    currency: profile.currency,
    isMinor: profile.isMinor,
    expensesEnabled: profile.expensesEnabled,
    sportEnabled: profile.sportEnabled,
  );

  final String name;
  final PalierAccent accent;
  final PalierCurrency currency;
  final bool isMinor;
  final bool expensesEnabled;
  final bool sportEnabled;

  /// Longueur maximale d'un prénom (contrainte aussi en base).
  static const int maxNameLength = 40;

  ProfileDraft copyWith({
    String? name,
    PalierAccent? accent,
    PalierCurrency? currency,
    bool? isMinor,
    bool? expensesEnabled,
    bool? sportEnabled,
  }) {
    return ProfileDraft(
      name: name ?? this.name,
      accent: accent ?? this.accent,
      currency: currency ?? this.currency,
      isMinor: isMinor ?? this.isMinor,
      expensesEnabled: expensesEnabled ?? this.expensesEnabled,
      sportEnabled: sportEnabled ?? this.sportEnabled,
    );
  }
}
