/// Types enregistrés en base par leur nom (`textEnum`) : ne jamais renommer une
/// valeur, sinon les lignes déjà écrites ne se relisent plus.
library;

/// Où se trouve l'argent.
enum AccountKind { cash, mobileMoney, bank }

/// Une catégorie classe soit des dépenses, soit des revenus.
enum CategoryKind { expense, income }

/// Une opération sort de l'argent d'un compte, en fait entrer, ou le déplace
/// d'un compte à un autre (retrait au guichet, dépôt Mobile Money…).
enum OperationKind {
  expense,
  income,
  transfer;

  /// La catégorie qui convient, ou `null` pour un virement (il n'en a pas).
  CategoryKind? get categoryKind => switch (this) {
    OperationKind.expense => CategoryKind.expense,
    OperationKind.income => CategoryKind.income,
    OperationKind.transfer => null,
  };
}
